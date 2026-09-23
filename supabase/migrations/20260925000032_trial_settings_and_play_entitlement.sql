-- Two-stage trial model + Google Play entitlement.
--
-- 1) subscription_settings: one-row, platform-admin-managed settings.
--    app_trial_days (default 3) replaces the hardcoded 7-day trial in
--    create_own_business; trial_plan_code names the plan whose rights a
--    business gets while on a free trial (default: ultra_super, the top
--    plan). Changing the setting only affects businesses created later --
--    existing trial_ends_at values are never recomputed.
-- 2) business_effective_plan_id(): the plan whose limits/features apply
--    right now. During the MK Adisyon app trial and during a Google Play
--    free-trial phase this is the trial plan (all top-plan rights);
--    otherwise the subscribed plan. enforce_plan_limit and the QR menu use
--    it, so "trial = top plan" is enforced in the database, not the UI.
-- 3) get_business_entitlement(): server-computed status for web/mobile
--    (days left use the database clock, never the device clock).
-- 4) record_google_play_subscription(): service-role-only write path for
--    the /api/play/verify, /api/play/rtdn and reconcile jobs. It stores
--    the free-trial flag and linked (replaced) purchase token, refuses a
--    token that already belongs to another business, and derives the
--    business status from ALL of the business's purchases, so an old
--    replaced subscription expiring can't switch off a newer one.
--
-- Builds on 029-031 (app_private.write_audit_event, trusted subscription
-- update context). No existing function/grant is loosened; nothing is
-- dropped; no data is deleted.

-- ---------------------------------------------------------------------------
-- 1) Settings
-- ---------------------------------------------------------------------------
create table public.subscription_settings (
  id boolean primary key default true check (id),
  app_trial_days integer not null default 3
    check (app_trial_days between 0 and 90),
  trial_plan_code text not null default 'ultra_super'
    references public.plans (code),
  updated_at timestamptz not null default now()
);

insert into public.subscription_settings (id) values (true)
on conflict (id) do nothing;

create trigger trg_subscription_settings_updated_at
  before update on public.subscription_settings
  for each row execute function public.set_updated_at();

alter table public.subscription_settings enable row level security;
alter table public.subscription_settings force row level security;

-- Readable by everyone: the public pricing page shows the trial length.
create policy subscription_settings_select_all
  on public.subscription_settings for select
  to anon, authenticated
  using (true);

create policy subscription_settings_update_platform_admin
  on public.subscription_settings for update
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- Single row: nobody inserts or deletes through the API.
revoke insert, delete, truncate on public.subscription_settings from anon, authenticated;
revoke update on public.subscription_settings from anon;

create or replace function public.audit_subscription_settings_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app_private.write_audit_event(
    null,
    'SUBSCRIPTION_SETTINGS_UPDATED',
    'subscription_settings',
    null,
    jsonb_build_object(
      'app_trial_days', jsonb_build_object('old', old.app_trial_days, 'new', new.app_trial_days),
      'trial_plan_code', jsonb_build_object('old', old.trial_plan_code, 'new', new.trial_plan_code)
    )
  );
  return new;
end;
$$;

alter function public.audit_subscription_settings_update() owner to postgres;

create trigger trg_subscription_settings_audit
  after update on public.subscription_settings
  for each row execute function public.audit_subscription_settings_update();

-- ---------------------------------------------------------------------------
-- 2) Play purchase columns
-- ---------------------------------------------------------------------------
alter table public.google_play_purchases
  add column in_free_trial boolean not null default false,
  add column linked_purchase_token text;

create index idx_google_play_purchases_linked_token
  on public.google_play_purchases (linked_purchase_token)
  where linked_purchase_token is not null;

-- ---------------------------------------------------------------------------
-- 3) Effective plan
-- ---------------------------------------------------------------------------
create or replace function public.business_effective_plan_id(p_business_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when b.subscription_status = 'TRIAL' and b.trial_ends_at > now()
      then coalesce(tp.id, b.plan_id)
    when b.subscription_status in ('ACTIVE', 'GRACE_PERIOD')
      and exists (
        select 1 from public.google_play_purchases g
        where g.business_id = b.id
          and g.in_free_trial
          and g.purchase_state in ('ACTIVE', 'CANCELLED')
          and g.expiry_time > now()
      )
      then coalesce(tp.id, b.plan_id)
    else b.plan_id
  end
  from public.businesses b
  left join public.subscription_settings s on s.id
  left join public.plans tp on tp.code = s.trial_plan_code
  where b.id = p_business_id;
$$;

alter function public.business_effective_plan_id(uuid) owner to postgres;
-- Internal helper: only other SECURITY DEFINER code calls it.
revoke execute on function public.business_effective_plan_id(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4) Plan limits use the effective plan
-- ---------------------------------------------------------------------------
-- Same rules as 029 (insert + reactivation + role change to WAITER); only
-- the plan lookup changed. SECURITY DEFINER so it can resolve the
-- effective plan (which reads google_play_purchases) without granting
-- clients access to it; it only ever reads and raises.
create or replace function public.enforce_plan_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
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

  v_plan_id := public.business_effective_plan_id(new.business_id);
  if v_plan_id is null then
    return new;
  end if;

  select p.max_areas, p.max_tables, p.max_waiters, p.max_users
    into v_max_areas, v_max_tables, v_max_waiters, v_max_users
  from public.plans p
  where p.id = v_plan_id;

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

alter function public.enforce_plan_limit() owner to postgres;

-- ---------------------------------------------------------------------------
-- 5) QR menu uses the effective plan (trial -> top plan -> QR menu on)
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
set search_path = ''
stable
as $$
  select b.name, b.logo_url, b.business_type, b.city
  from public.businesses b
  join public.plans p on p.id = public.business_effective_plan_id(b.id)
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
set search_path = ''
stable
as $$
  select
    c.id, c.name, c.sort_order,
    pr.id, pr.name, pr.description, pr.price, pr.image_url
  from public.categories c
  join public.businesses b on b.id = c.business_id
  join public.plans p on p.id = public.business_effective_plan_id(b.id)
  left join public.products pr on pr.category_id = c.id and pr.active
  where c.business_id = p_business_id
    and c.active
    and b.active
    and p.qr_menu_enabled
    and public.business_is_operational(b.id)
  order by c.sort_order, pr.name;
$$;

alter function public.get_qr_menu_business(uuid) owner to postgres;
alter function public.get_qr_menu_items(uuid) owner to postgres;

-- ---------------------------------------------------------------------------
-- 6) Server-computed entitlement for web/mobile
-- ---------------------------------------------------------------------------
create or replace function public.get_business_entitlement(p_business_id uuid)
returns table (
  subscription_status text,
  is_operational boolean,
  access_source text,
  app_trial_ends_at timestamptz,
  app_trial_days_left integer,
  subscribed_plan_id uuid,
  subscribed_plan_code text,
  subscribed_plan_name text,
  effective_plan_id uuid,
  effective_plan_code text,
  effective_plan_name text,
  max_tables integer,
  max_waiters integer,
  max_areas integer,
  qr_menu_enabled boolean,
  play_product_id text,
  play_base_plan_id text,
  play_purchase_state text,
  play_expiry_time timestamptz,
  play_auto_renewing boolean,
  play_in_free_trial boolean,
  server_now timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not (public.is_platform_admin() or public.is_business_member(p_business_id)) then
    return;
  end if;

  return query
  with b as (
    select bb.*, public.business_effective_plan_id(bb.id) as eff_plan_id
    from public.businesses bb
    where bb.id = p_business_id
  ),
  play as (
    select g.product_id, g.base_plan_id, g.purchase_state, g.expiry_time,
           g.auto_renewing, g.in_free_trial
    from public.google_play_purchases g
    where g.business_id = p_business_id
      and g.purchase_state <> 'PENDING'
      and not exists (
        select 1 from public.google_play_purchases n
        where n.linked_purchase_token = g.purchase_token
      )
    order by g.expiry_time desc nulls last
    limit 1
  )
  select
    b.subscription_status,
    coalesce(public.business_is_operational(b.id), false),
    case
      when not b.active or b.subscription_status = 'SUSPENDED' then 'SUSPENDED'
      when b.subscription_status = 'TRIAL' and b.trial_ends_at > now() then 'APP_TRIAL'
      when b.subscription_status in ('ACTIVE', 'GRACE_PERIOD') and play.in_free_trial
        and play.expiry_time > now() then 'PLAY_TRIAL'
      when b.subscription_status in ('ACTIVE', 'GRACE_PERIOD') and play.product_id is not null
        then 'PLAY_SUBSCRIPTION'
      when b.subscription_status in ('ACTIVE', 'GRACE_PERIOD') then 'MANUAL'
      else 'NONE'
    end,
    b.trial_ends_at,
    case
      when b.subscription_status = 'TRIAL'
        then greatest(0, ceil(extract(epoch from (b.trial_ends_at - now())) / 86400))::integer
      else null
    end,
    sp.id, sp.code, sp.name,
    ep.id, ep.code, ep.name,
    ep.max_tables, ep.max_waiters, ep.max_areas,
    coalesce(ep.qr_menu_enabled, false),
    play.product_id, play.base_plan_id, play.purchase_state, play.expiry_time,
    play.auto_renewing, play.in_free_trial,
    now()
  from b
  left join public.plans sp on sp.id = b.plan_id
  left join public.plans ep on ep.id = b.eff_plan_id
  left join play on true;
end;
$$;

alter function public.get_business_entitlement(uuid) owner to postgres;
revoke execute on function public.get_business_entitlement(uuid) from public, anon;
grant execute on function public.get_business_entitlement(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 7) App trial length comes from settings
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
set search_path = ''
as $$
declare
  v_business_id uuid;
  v_trial_days integer;
begin
  if auth.uid() is null then
    raise exception 'Must be signed in to create a business';
  end if;

  if p_name is null or length(trim(p_name)) = 0 then
    raise exception 'Business name is required';
  end if;

  perform pg_advisory_xact_lock(hashtext('create_own_business:' || auth.uid()::text));

  if exists (
    select 1
    from public.business_memberships
    where user_id = auth.uid() and role = 'BUSINESS_ADMIN'
  ) then
    raise exception 'BUSINESS_ALREADY_EXISTS: user already administers a business';
  end if;

  -- Server-side setting only; the caller has no say in the trial length.
  select s.app_trial_days into v_trial_days
  from public.subscription_settings s
  where s.id;
  v_trial_days := coalesce(v_trial_days, 0);

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
    -- 0 days: the trial ends immediately, so the business must start a
    -- Google Play subscription before opening orders.
    now() + make_interval(days => v_trial_days),
    true
  )
  returning id into v_business_id;

  insert into public.business_memberships (user_id, business_id, role)
  values (auth.uid(), v_business_id, 'BUSINESS_ADMIN');

  perform app_private.write_audit_event(
    v_business_id,
    'BUSINESS_SELF_REGISTERED',
    'businesses',
    v_business_id,
    jsonb_build_object('name', trim(p_name), 'app_trial_days', v_trial_days)
  );

  return v_business_id;
end;
$$;

alter function public.create_own_business(text, text, text, text, text, text) owner to postgres;
revoke execute on function public.create_own_business(text, text, text, text, text, text)
  from public, anon;
grant execute on function public.create_own_business(text, text, text, text, text, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 8) Play write path used by /api/play/* (service role only)
-- ---------------------------------------------------------------------------
create or replace function public.record_google_play_subscription(
  p_business_id uuid,
  p_product_id text,
  p_base_plan_id text,
  p_purchase_token text,
  p_linked_purchase_token text,
  p_order_id text,
  p_purchase_state text,
  p_auto_renewing boolean,
  p_in_free_trial boolean,
  p_start_time timestamptz,
  p_expiry_time timestamptz,
  p_raw_verification_response jsonb
)
returns table (
  purchase_id uuid,
  business_status text,
  subscribed_plan_code text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_plan_id uuid;
  v_existing_business uuid;
  v_current_status text;
  v_best record;
  v_new_status text;
  v_new_plan_id uuid;
  v_previous_update_context text;
begin
  if p_purchase_state not in ('PENDING', 'ACTIVE', 'GRACE_PERIOD', 'ON_HOLD', 'CANCELLED', 'EXPIRED', 'REVOKED') then
    raise exception 'INVALID_PURCHASE_STATE: %', p_purchase_state;
  end if;

  select g.business_id into v_existing_business
  from public.google_play_purchases g
  where g.purchase_token = p_purchase_token;
  if v_existing_business is not null and v_existing_business <> p_business_id then
    raise exception 'PURCHASE_TOKEN_BELONGS_TO_OTHER_BUSINESS';
  end if;

  select b.subscription_status into v_current_status
  from public.businesses b
  where b.id = p_business_id
  for update;
  if not found then
    raise exception 'BUSINESS_NOT_FOUND';
  end if;

  -- The plan always comes from the product/base plan Google reported.
  select p.id into v_plan_id
  from public.plans p
  where p.google_play_product_id = p_product_id
    and p_base_plan_id in (p.google_play_monthly_base_plan_id, p.google_play_yearly_base_plan_id)
  limit 1;
  if v_plan_id is null then
    raise exception 'UNKNOWN_PLAY_PRODUCT: % / %', p_product_id, p_base_plan_id;
  end if;

  insert into public.google_play_purchases as gp (
    business_id, plan_id, product_id, base_plan_id, purchase_token,
    linked_purchase_token, order_id, purchase_state, auto_renewing,
    in_free_trial, start_time, expiry_time, last_verified_at,
    raw_verification_response
  )
  values (
    p_business_id, v_plan_id, p_product_id, p_base_plan_id, p_purchase_token,
    p_linked_purchase_token, p_order_id, p_purchase_state, coalesce(p_auto_renewing, false),
    coalesce(p_in_free_trial, false), p_start_time, p_expiry_time, now(),
    coalesce(p_raw_verification_response, '{}'::jsonb)
  )
  on conflict (purchase_token) do update set
    plan_id = excluded.plan_id,
    product_id = excluded.product_id,
    base_plan_id = excluded.base_plan_id,
    linked_purchase_token = coalesce(excluded.linked_purchase_token, gp.linked_purchase_token),
    order_id = coalesce(excluded.order_id, gp.order_id),
    purchase_state = excluded.purchase_state,
    auto_renewing = excluded.auto_renewing,
    in_free_trial = excluded.in_free_trial,
    start_time = excluded.start_time,
    expiry_time = excluded.expiry_time,
    last_verified_at = now(),
    raw_verification_response = excluded.raw_verification_response
  returning id into v_id;

  -- Business status follows the best current purchase, ignoring ones that
  -- a newer purchase replaced (upgrade/downgrade).
  select g.purchase_state, g.expiry_time, g.plan_id
    into v_best
  from public.google_play_purchases g
  where g.business_id = p_business_id
    and g.purchase_state <> 'PENDING'
    and not exists (
      select 1 from public.google_play_purchases n
      where n.linked_purchase_token = g.purchase_token
    )
  order by
    case
      when g.purchase_state in ('ACTIVE', 'GRACE_PERIOD') then 0
      when g.purchase_state = 'CANCELLED' and g.expiry_time > now() then 0
      else 1
    end,
    g.expiry_time desc nulls last
  limit 1;

  if found then
    v_new_status := case
      when v_best.purchase_state = 'ACTIVE' then 'ACTIVE'
      when v_best.purchase_state = 'GRACE_PERIOD' then 'GRACE_PERIOD'
      when v_best.purchase_state = 'CANCELLED' and v_best.expiry_time > now() then 'ACTIVE'
      when v_best.purchase_state = 'CANCELLED' then 'CANCELLED'
      else 'EXPIRED'
    end;
    v_new_plan_id := v_best.plan_id;
  end if;

  -- A platform-admin suspension is never overridden by Play.
  if v_new_status is not null and v_current_status <> 'SUSPENDED' then
    v_previous_update_context := current_setting('app.trusted_subscription_update_business_id', true);
    perform set_config('app.trusted_subscription_update_business_id', p_business_id::text, true);
    begin
      update public.businesses
      set subscription_status = v_new_status,
          plan_id = coalesce(v_new_plan_id, plan_id)
      where id = p_business_id;
    exception when others then
      perform set_config('app.trusted_subscription_update_business_id', coalesce(v_previous_update_context, ''), true);
      raise;
    end;
    perform set_config('app.trusted_subscription_update_business_id', coalesce(v_previous_update_context, ''), true);
  end if;

  perform app_private.write_audit_event(
    p_business_id,
    'GOOGLE_PLAY_SUBSCRIPTION_VERIFIED',
    'google_play_purchases',
    v_id,
    jsonb_build_object(
      'product_id', p_product_id,
      'base_plan_id', p_base_plan_id,
      'purchase_state', p_purchase_state,
      'in_free_trial', coalesce(p_in_free_trial, false)
    )
  );

  return query
  select v_id, b.subscription_status, p.code
  from public.businesses b
  left join public.plans p on p.id = b.plan_id
  where b.id = p_business_id;
end;
$$;

alter function public.record_google_play_subscription(
  uuid, text, text, text, text, text, text, boolean, boolean, timestamptz, timestamptz, jsonb
) owner to postgres;
revoke execute on function public.record_google_play_subscription(
  uuid, text, text, text, text, text, text, boolean, boolean, timestamptz, timestamptz, jsonb
) from public, anon, authenticated;
grant execute on function public.record_google_play_subscription(
  uuid, text, text, text, text, text, text, boolean, boolean, timestamptz, timestamptz, jsonb
) to service_role;
