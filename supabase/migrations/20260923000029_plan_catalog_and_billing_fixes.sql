-- Plan catalog (Standart / Süper / Ultra Süper) + Google Play readiness
-- fixes. Builds on the existing plans/subscription model (Faz 9 + Faz 12)
-- rather than replacing it -- no new tables.
--
-- 1) plans.code / sort_order: stable internal identifiers so web, mobile
--    and the (future) Play verification job can refer to a plan without
--    hardcoding uuids or prices.
-- 2) yearly_price is always derived from monthly_price and
--    yearly_discount (monthly x 12, minus the discount) -- one formula,
--    in the database, instead of every surface doing its own math.
-- 3) The three launch plans are seeded (codes only; Play ids stay null
--    until they exist in Play Console).
-- 4) plan_billing_options: flattened (plan, billing period) -> price /
--    Play product / base plan mapping.
-- 5) Play base plan ids are unique per product, not globally -- the
--    Faz 12 unique indexes wrongly assumed the latter.
-- 6) GRACE_PERIOD keeps a business operational (Play's grace period
--    promises continued access while Google retries the payment).
-- 7) apply_google_play_verification_result: correct Play-state mapping
--    (CANCELLED keeps access until expiry; ON_HOLD removes it) and
--    server-side plan resolution from product/base plan.
-- 8) enforce_plan_limit also covers reactivating a row and changing a
--    member's role to WAITER (both previously bypassed the limits).
-- 9) create_own_business: one self-service business per user (otherwise
--    each extra call opened a fresh 7-day trial).
-- 10) QR menu is only public while the business is operational.

-- ---------------------------------------------------------------------------
-- 1) Plan codes
-- ---------------------------------------------------------------------------
alter table public.plans
  add column code text,
  add column sort_order integer not null default 0;

alter table public.plans
  add constraint plans_code_key unique (code),
  add constraint plans_code_format check (code is null or code ~ '^[a-z][a-z0-9_]{1,39}$'),
  add constraint plans_monthly_price_non_negative check (monthly_price >= 0),
  add constraint plans_yearly_discount_range check (yearly_discount >= 0 and yearly_discount < 100);

-- ---------------------------------------------------------------------------
-- 2) Derived yearly price
-- ---------------------------------------------------------------------------
-- numeric arithmetic (not float): 399 x 12 x 90 / 100 = 4309.20 exactly.
create or replace function public.compute_plan_yearly_price()
returns trigger
language plpgsql
as $$
begin
  new.yearly_price := round(new.monthly_price * 12 * (100 - new.yearly_discount) / 100, 2);
  return new;
end;
$$;

create trigger trg_plans_compute_yearly_price
  before insert or update on public.plans
  for each row execute function public.compute_plan_yearly_price();

-- Backfill existing rows through the trigger.
update public.plans set yearly_price = yearly_price;

-- ---------------------------------------------------------------------------
-- 3) Launch plans
-- ---------------------------------------------------------------------------
-- max_users stays null (unlimited): the plans cap waiters, not other
-- roles. max_branches = 1 documents "1 işletme"; the actual one-business
-- rule is enforced in create_own_business (section 9). Multi-branch and
-- custom software are quote-based and deliberately not plans.
insert into public.plans (
  code, name, sort_order, monthly_price, yearly_discount,
  max_tables, max_waiters, max_users, max_areas, max_branches,
  qr_menu_enabled, active
)
values
  ('standard',    'Standart',    10,  399, 10, 10,  2, null, 1, 1, false, true),
  ('super',       'Süper',       20,  799, 10, 20,  5, null, 3, 1, false, true),
  ('ultra_super', 'Ultra Süper', 30, 1899, 10, 35, 10, null, 5, 1, true,  true)
on conflict (code) do nothing;

-- ---------------------------------------------------------------------------
-- 4) Billing catalog view
-- ---------------------------------------------------------------------------
-- One row per (plan, billing period). Prices here are the catalog/list
-- price; in the Android app the price actually charged and displayed at
-- checkout is always the localized price Google Play Billing returns.
create view public.plan_billing_options
with (security_invoker = true)
as
select
  p.id as plan_id,
  p.code as plan_code,
  p.name as plan_name,
  p.sort_order,
  o.billing_period,
  o.price,
  'TRY'::text as currency,
  p.google_play_product_id,
  o.google_play_base_plan_id
from public.plans p
cross join lateral (
  values
    ('MONTHLY'::text, p.monthly_price, p.google_play_monthly_base_plan_id),
    ('YEARLY'::text, p.yearly_price, p.google_play_yearly_base_plan_id)
) as o (billing_period, price, google_play_base_plan_id)
where p.active and p.code is not null;

grant select on public.plan_billing_options to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5) Play base plan uniqueness is per product
-- ---------------------------------------------------------------------------
drop index if exists public.uq_plans_google_play_monthly_base_plan;
drop index if exists public.uq_plans_google_play_yearly_base_plan;

create unique index uq_plans_google_play_product
  on public.plans (google_play_product_id)
  where google_play_product_id is not null;

alter table public.plans
  add constraint plans_google_play_base_plans_distinct check (
    google_play_monthly_base_plan_id is null
    or google_play_yearly_base_plan_id is null
    or google_play_monthly_base_plan_id <> google_play_yearly_base_plan_id
  );

-- ---------------------------------------------------------------------------
-- 6) Grace period stays operational
-- ---------------------------------------------------------------------------
create or replace function public.business_is_operational(p_business_id uuid)
returns boolean
language sql
stable
as $$
  select b.active
    and (
      b.subscription_status in ('ACTIVE', 'GRACE_PERIOD')
      or (b.subscription_status = 'TRIAL' and b.trial_ends_at > now())
    )
  from public.businesses b
  where b.id = p_business_id;
$$;

-- ---------------------------------------------------------------------------
-- 7) Play verification result mapping
-- ---------------------------------------------------------------------------
-- Google Play semantics (subscriptionsv2):
--   CANCELED  = auto-renew turned off, user keeps access until expiry.
--   ON_HOLD   = payment failed after grace period, access must be removed.
--   EXPIRED / REVOKED = no access.
-- The expiry of a CANCELLED subscription is picked up when the
-- verification job re-verifies it (RTDN SUBSCRIPTION_EXPIRED or its
-- periodic sweep) -- see docs/GOOGLE_PLAY_BILLING.md.
--
-- p_plan_id may be null: the plan is then resolved here from the
-- product/base plan Google reported, so the caller never has to (and a
-- client never can) choose which plan a purchase unlocks.
create or replace function public.apply_google_play_verification_result(
  p_business_id uuid,
  p_plan_id uuid,
  p_product_id text,
  p_base_plan_id text,
  p_purchase_token text,
  p_order_id text,
  p_purchase_state text,
  p_auto_renewing boolean,
  p_start_time timestamptz,
  p_expiry_time timestamptz,
  p_raw_verification_response jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_plan_id uuid;
  v_new_subscription_status text;
begin
  v_plan_id := coalesce(
    p_plan_id,
    (
      select p.id
      from public.plans p
      where p.google_play_product_id = p_product_id
        and p_base_plan_id in (p.google_play_monthly_base_plan_id, p.google_play_yearly_base_plan_id)
      limit 1
    )
  );

  insert into public.google_play_purchases (
    business_id, plan_id, product_id, base_plan_id, purchase_token, order_id,
    purchase_state, auto_renewing, start_time, expiry_time, last_verified_at,
    raw_verification_response
  )
  values (
    p_business_id, v_plan_id, p_product_id, p_base_plan_id, p_purchase_token, p_order_id,
    p_purchase_state, p_auto_renewing, p_start_time, p_expiry_time, now(),
    coalesce(p_raw_verification_response, '{}'::jsonb)
  )
  on conflict (purchase_token) do update set
    plan_id = excluded.plan_id,
    base_plan_id = excluded.base_plan_id,
    order_id = excluded.order_id,
    purchase_state = excluded.purchase_state,
    auto_renewing = excluded.auto_renewing,
    start_time = excluded.start_time,
    expiry_time = excluded.expiry_time,
    last_verified_at = now(),
    raw_verification_response = excluded.raw_verification_response
  returning id into v_id;

  v_new_subscription_status := case p_purchase_state
    when 'ACTIVE' then 'ACTIVE'
    when 'GRACE_PERIOD' then 'GRACE_PERIOD'
    when 'ON_HOLD' then 'EXPIRED'
    when 'CANCELLED' then
      case when p_expiry_time > now() then 'ACTIVE' else 'CANCELLED' end
    when 'EXPIRED' then 'EXPIRED'
    when 'REVOKED' then 'EXPIRED'
    else null
  end;

  if v_new_subscription_status is not null then
    update public.businesses
    set subscription_status = v_new_subscription_status,
        plan_id = coalesce(v_plan_id, plan_id)
    where id = p_business_id;
  end if;

  perform public.log_audit_event(
    p_business_id,
    'GOOGLE_PLAY_SUBSCRIPTION_VERIFIED',
    'google_play_purchases',
    v_id,
    jsonb_build_object('product_id', p_product_id, 'purchase_state', p_purchase_state)
  );

  return v_id;
end;
$$;

-- SECURITY FIX. Postgres grants EXECUTE on every new function to PUBLIC
-- (and Supabase's default privileges add anon/authenticated on top), so
-- "no grant statement" in 20260922000026 did NOT make this unreachable:
-- any signed-in user could call
--   rpc('apply_google_play_verification_result', {p_business_id: <any>,
--       p_plan_id: <ultra>, p_purchase_state: 'ACTIVE', ...})
-- and activate a paid plan for free. Only the service-role verification
-- job may call it.
revoke execute on function public.apply_google_play_verification_result(
  uuid, uuid, text, text, text, text, text, boolean, timestamptz, timestamptz, jsonb
) from public, anon, authenticated;
grant execute on function public.apply_google_play_verification_result(
  uuid, uuid, text, text, text, text, text, boolean, timestamptz, timestamptz, jsonb
) to service_role;

-- Same PUBLIC-grant gap for log_audit_event: 20260922000027 revoked it
-- from `authenticated` only, which still left it callable through PUBLIC
-- -- and by anon, whose null auth.uid() skips the membership check, so a
-- signed-out visitor could write audit rows for any business. All real
-- callers are SECURITY DEFINER functions and are unaffected.
revoke execute on function public.log_audit_event(uuid, text, text, uuid, jsonb)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 8) Plan limits on reactivation / role change
-- ---------------------------------------------------------------------------
-- Before: only INSERT was checked, so "deactivate one table, add a new
-- one, reactivate the old one" (or invite as CASHIER, then switch the
-- role to WAITER) went past the limit. On UPDATE we only re-check when
-- the row starts counting toward a limit it didn't count toward before.
-- Downgrades never deactivate existing rows; they only block new ones.
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
  v_becomes_active boolean;
  v_becomes_waiter boolean;
begin
  if not new.active then
    return new;
  end if;

  v_becomes_active := TG_OP = 'INSERT' or not old.active;

  if TG_TABLE_NAME = 'business_memberships' then
    v_becomes_waiter := new.role = 'WAITER'
      and (v_becomes_active or old.role is distinct from 'WAITER');
    if not v_becomes_active and not v_becomes_waiter then
      return new;
    end if;
  elsif not v_becomes_active then
    return new;
  end if;

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
    if v_becomes_active and v_max_users is not null then
      select count(*) into v_current_count
        from public.business_memberships where business_id = new.business_id and active;
      if v_current_count >= v_max_users then
        raise exception 'PLAN_LIMIT_EXCEEDED: max_users (%) reached for business %', v_max_users, new.business_id;
      end if;
    end if;
    if v_becomes_waiter and v_max_waiters is not null then
      select count(*) into v_current_count
        from public.business_memberships
        where business_id = new.business_id and active and role = 'WAITER'
          and id <> new.id;
      if v_current_count >= v_max_waiters then
        raise exception 'PLAN_LIMIT_EXCEEDED: max_waiters (%) reached for business %', v_max_waiters, new.business_id;
      end if;
    end if;
  end if;

  return new;
end;
$$;

create trigger trg_areas_enforce_plan_limit_on_update
  before update of active on public.areas
  for each row execute function public.enforce_plan_limit();

create trigger trg_restaurant_tables_enforce_plan_limit_on_update
  before update of active on public.restaurant_tables
  for each row execute function public.enforce_plan_limit();

create trigger trg_business_memberships_enforce_plan_limit_on_update
  before update of active, role on public.business_memberships
  for each row execute function public.enforce_plan_limit();

-- ---------------------------------------------------------------------------
-- 9) One self-service business per user
-- ---------------------------------------------------------------------------
create or replace function public.create_own_business(
  p_name text,
  p_business_type text default null,
  p_city text default null,
  p_address text default null,
  p_phone text default null,
  p_email text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_business_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Must be signed in to create a business';
  end if;

  if p_name is null or length(trim(p_name)) = 0 then
    raise exception 'Business name is required';
  end if;

  -- Serialize concurrent calls from the same user so the check below
  -- can't be raced.
  perform pg_advisory_xact_lock(hashtext('create_own_business:' || auth.uid()::text));

  -- Any BUSINESS_ADMIN membership counts, active or not: a second
  -- business would otherwise mean a second free trial. More businesses
  -- go through the quote-based multi-branch offer.
  if exists (
    select 1 from public.business_memberships
    where user_id = auth.uid() and role = 'BUSINESS_ADMIN'
  ) then
    raise exception 'BUSINESS_ALREADY_EXISTS: user already administers a business';
  end if;

  insert into public.businesses (
    name, business_type, city, address, phone, email,
    plan_id, subscription_status, trial_started_at, trial_ends_at, active
  )
  values (
    trim(p_name),
    nullif(trim(coalesce(p_business_type, '')), ''),
    nullif(trim(coalesce(p_city, '')), ''),
    nullif(trim(coalesce(p_address, '')), ''),
    nullif(trim(coalesce(p_phone, '')), ''),
    nullif(trim(coalesce(p_email, '')), ''),
    null,
    'TRIAL',
    now(),
    now() + interval '7 days',
    true
  )
  returning id into v_business_id;

  insert into public.business_memberships (user_id, business_id, role)
  values (auth.uid(), v_business_id, 'BUSINESS_ADMIN');

  perform public.log_audit_event(
    v_business_id,
    'BUSINESS_SELF_REGISTERED',
    'businesses',
    v_business_id,
    jsonb_build_object('name', trim(p_name))
  );

  return v_business_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 10) QR menu only while operational
-- ---------------------------------------------------------------------------
create or replace function public.get_qr_menu_business(p_business_id uuid)
returns table (
  name text,
  logo_url text,
  business_type text,
  city text
)
language sql
security definer
set search_path = public
stable
as $$
  select b.name, b.logo_url, b.business_type, b.city
  from public.businesses b
  join public.plans p on p.id = b.plan_id
  where b.id = p_business_id
    and b.active
    and p.qr_menu_enabled
    and public.business_is_operational(b.id);
$$;

create or replace function public.get_qr_menu_items(p_business_id uuid)
returns table (
  category_id uuid,
  category_name text,
  category_sort_order integer,
  product_id uuid,
  product_name text,
  product_description text,
  product_price numeric,
  product_image_url text
)
language sql
security definer
set search_path = public
stable
as $$
  select
    c.id, c.name, c.sort_order,
    pr.id, pr.name, pr.description, pr.price, pr.image_url
  from public.categories c
  join public.businesses b on b.id = c.business_id
  join public.plans p on p.id = b.plan_id
  left join public.products pr on pr.category_id = c.id and pr.active
  where c.business_id = p_business_id
    and c.active
    and b.active
    and p.qr_menu_enabled
    and public.business_is_operational(b.id)
  order by c.sort_order, pr.name;
$$;
