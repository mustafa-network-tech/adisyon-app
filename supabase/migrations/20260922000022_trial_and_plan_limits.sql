-- Faz 9: trial/subscription enforcement + dynamic plan limits (sections
-- 8/9/12 of the master prompt). Both were explicitly deferred in Faz 1
-- ("plan limiti enforcement ve trial/expired erişim engeli ... Faz 9'a
-- bırakıldı") -- this is that follow-through.

-- 1) Whether a business may still open NEW orders. Deliberately does
-- NOT block closing/paying an already-open order -- a trial expiring
-- (or a business being suspended) mid-service must never strand a
-- customer's open bill; it only stops *new* day-to-day operations
-- ("yeni operasyon oluşturma", section 8), which in this schema means
-- opening a new order. Config actions (adding products/staff/etc.) are
-- deliberately left alone too -- section 8 only calls out operations,
-- and blocking admin setup during a trial would make the trial useless.
create or replace function public.business_is_operational(p_business_id uuid)
returns boolean
language sql
stable
as $$
  select b.active
    and (
      b.subscription_status = 'ACTIVE'
      or (b.subscription_status = 'TRIAL' and b.trial_ends_at > now())
    )
  from public.businesses b
  where b.id = p_business_id;
$$;

grant execute on function public.business_is_operational(uuid) to authenticated;

create or replace function public.enforce_business_operational_for_new_order()
returns trigger
language plpgsql
as $$
begin
  if not coalesce(public.business_is_operational(new.business_id), false) then
    raise exception 'TRIAL_OR_SUBSCRIPTION_INACTIVE: business % cannot open new orders', new.business_id;
  end if;
  return new;
end;
$$;

create trigger trg_orders_enforce_operational
  before insert on public.orders
  for each row execute function public.enforce_business_operational_for_new_order();

-- 2) Dynamic plan limits (max_areas/max_tables/max_waiters/max_users).
-- No plan assigned (plan_id is null) means unlimited -- a business
-- shouldn't be blocked by limits nobody set. A null limit on an
-- assigned plan also means unlimited for that specific dimension.
-- Only checked on INSERT (creating a new row); a role change on an
-- existing membership isn't re-checked against max_waiters, which is
-- an intentional scope limit, not an oversight.
create or replace function public.enforce_plan_limit()
returns trigger
language plpgsql
as $$
declare
  v_plan_id uuid;
  v_max_areas integer;
  v_max_tables integer;
  v_max_waiters integer;
  v_max_users integer;
  v_current_count integer;
begin
  select b.plan_id, p.max_areas, p.max_tables, p.max_waiters, p.max_users
    into v_plan_id, v_max_areas, v_max_tables, v_max_waiters, v_max_users
  from public.businesses b
  left join public.plans p on p.id = b.plan_id
  where b.id = new.business_id;

  if v_plan_id is null then
    return new;
  end if;

  if TG_TABLE_NAME = 'areas' then
    if v_max_areas is not null then
      select count(*) into v_current_count
        from public.areas where business_id = new.business_id and active;
      if v_current_count >= v_max_areas then
        raise exception 'PLAN_LIMIT_EXCEEDED: max_areas (%) reached for business %', v_max_areas, new.business_id;
      end if;
    end if;
  elsif TG_TABLE_NAME = 'restaurant_tables' then
    if v_max_tables is not null then
      select count(*) into v_current_count
        from public.restaurant_tables where business_id = new.business_id and active;
      if v_current_count >= v_max_tables then
        raise exception 'PLAN_LIMIT_EXCEEDED: max_tables (%) reached for business %', v_max_tables, new.business_id;
      end if;
    end if;
  elsif TG_TABLE_NAME = 'business_memberships' then
    if v_max_users is not null then
      select count(*) into v_current_count
        from public.business_memberships where business_id = new.business_id and active;
      if v_current_count >= v_max_users then
        raise exception 'PLAN_LIMIT_EXCEEDED: max_users (%) reached for business %', v_max_users, new.business_id;
      end if;
    end if;
    if new.role = 'WAITER' and v_max_waiters is not null then
      select count(*) into v_current_count
        from public.business_memberships
        where business_id = new.business_id and active and role = 'WAITER';
      if v_current_count >= v_max_waiters then
        raise exception 'PLAN_LIMIT_EXCEEDED: max_waiters (%) reached for business %', v_max_waiters, new.business_id;
      end if;
    end if;
  end if;

  return new;
end;
$$;

create trigger trg_areas_enforce_plan_limit
  before insert on public.areas
  for each row execute function public.enforce_plan_limit();

create trigger trg_restaurant_tables_enforce_plan_limit
  before insert on public.restaurant_tables
  for each row execute function public.enforce_plan_limit();

create trigger trg_business_memberships_enforce_plan_limit
  before insert on public.business_memberships
  for each row execute function public.enforce_plan_limit();
