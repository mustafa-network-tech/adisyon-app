-- Faz 12: Google Play subscription backend model (Android purchases are
-- bought through Google Play and verified server-side; Super Admin is
-- never a manual part of that approval). This migration only lays the
-- data model + a locked-down verification entry point -- it deliberately
-- does NOT implement real Google Play Developer API verification, since
-- no service-account credential exists in this environment yet. See the
-- comment on public.apply_google_play_verification_result below for the
-- exact integration point a future phase must fill in.

-- 1) GRACE_PERIOD: Google Play subscriptions have a billing grace period
-- (payment failed but Google is still retrying) distinct from EXPIRED/
-- SUSPENDED. Widen both status check constraints to allow it. Constraint
-- names are looked up dynamically (rather than assumed) since they were
-- originally created unnamed by inline `check (...)` clauses.
do $$
declare
  v_constraint_name text;
begin
  select con.conname into v_constraint_name
  from pg_constraint con
  join pg_class rel on rel.oid = con.conrelid
  join pg_namespace nsp on nsp.oid = rel.relnamespace
  where nsp.nspname = 'public'
    and rel.relname = 'businesses'
    and con.contype = 'c'
    and pg_get_constraintdef(con.oid) ilike '%subscription_status%';

  if v_constraint_name is not null then
    execute format('alter table public.businesses drop constraint %I', v_constraint_name);
  end if;

  alter table public.businesses
    add constraint businesses_subscription_status_check
    check (subscription_status in ('TRIAL', 'ACTIVE', 'GRACE_PERIOD', 'EXPIRED', 'SUSPENDED', 'CANCELLED'));
end $$;

do $$
declare
  v_constraint_name text;
begin
  select con.conname into v_constraint_name
  from pg_constraint con
  join pg_class rel on rel.oid = con.conrelid
  join pg_namespace nsp on nsp.oid = rel.relnamespace
  where nsp.nspname = 'public'
    and rel.relname = 'subscriptions'
    and con.contype = 'c'
    and pg_get_constraintdef(con.oid) ilike '%status%'
    and pg_get_constraintdef(con.oid) ilike '%TRIAL%';

  if v_constraint_name is not null then
    execute format('alter table public.subscriptions drop constraint %I', v_constraint_name);
  end if;

  alter table public.subscriptions
    add constraint subscriptions_status_check
    check (status in ('TRIAL', 'ACTIVE', 'GRACE_PERIOD', 'EXPIRED', 'SUSPENDED', 'CANCELLED'));
end $$;

-- 2) plans: fields to map a plan to its Google Play Console product /
-- base plan, so the mobile client (or a future admin job) can resolve
-- "which Play subscription does this plan correspond to" without any
-- hardcoded ids in application code. Nullable + unique-when-present: a
-- plan doesn't have to have Play products configured (e.g. an
-- enterprise/manually-managed plan), and two plans can never point at
-- the same Play product by accident.
alter table public.plans
  add column google_play_product_id text,
  add column google_play_monthly_base_plan_id text,
  add column google_play_yearly_base_plan_id text;

create unique index uq_plans_google_play_monthly_base_plan
  on public.plans (google_play_monthly_base_plan_id)
  where google_play_monthly_base_plan_id is not null;

create unique index uq_plans_google_play_yearly_base_plan
  on public.plans (google_play_yearly_base_plan_id)
  where google_play_yearly_base_plan_id is not null;

-- 3) google_play_purchases: one row per Play subscription purchase
-- Google reports for a business. This is the ledger a server-side
-- verification job (not built yet) writes to; nothing here is ever
-- reachable by a plain authenticated client -- see the RLS policy and
-- the grants on apply_google_play_verification_result below.
--
-- purchase_token is exactly the sensitive value the master prompt says
-- must never reach the client: it's the credential Google's API uses to
-- look up/ack a purchase, so if it leaked, a third party could query (or
-- in some flows, acknowledge/consume) that purchase. It is stored here,
-- selectable by nobody except the platform admin, and never selected by
-- the business-facing status view (see get_own_business_subscription
-- below, which is the only read surface a business admin gets).
create table public.google_play_purchases (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  plan_id uuid references public.plans (id),
  product_id text not null,
  base_plan_id text,
  purchase_token text not null,
  order_id text,
  purchase_state text not null default 'PENDING'
    check (purchase_state in ('PENDING', 'ACTIVE', 'GRACE_PERIOD', 'ON_HOLD', 'CANCELLED', 'EXPIRED', 'REVOKED')),
  auto_renewing boolean not null default true,
  start_time timestamptz,
  expiry_time timestamptz,
  last_verified_at timestamptz,
  raw_verification_response jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (purchase_token)
);

create index idx_google_play_purchases_business on public.google_play_purchases (business_id);

create trigger trg_google_play_purchases_updated_at
  before update on public.google_play_purchases
  for each row execute function public.set_updated_at();

alter table public.google_play_purchases enable row level security;
alter table public.google_play_purchases force row level security;

-- Only the platform admin can read raw purchase rows (purchase_token
-- included) -- a business admin gets status only, via the SECURITY
-- DEFINER projection function below, never this table directly.
create policy google_play_purchases_select_platform_admin
  on public.google_play_purchases for select
  to authenticated
  using (public.is_platform_admin());

-- Deliberately no insert/update/delete policy for any client role --
-- rows are only ever written by apply_google_play_verification_result
-- (SECURITY DEFINER, granted to nobody yet -- see below), which itself
-- will only ever be called from a trusted server context (a Next.js
-- Route Handler using the service-role key, exactly like
-- src/lib/supabase/admin.ts already does for auth.admin operations).

-- 4) Safe, business-scoped projection: what a business's own admin (or
-- the platform admin) is allowed to know about its Play subscription --
-- status/expiry, never the purchase token or the raw API response.
create or replace function public.get_own_business_subscription(p_business_id uuid)
returns table (
  product_id text,
  base_plan_id text,
  purchase_state text,
  auto_renewing boolean,
  start_time timestamptz,
  expiry_time timestamptz,
  last_verified_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select gp.product_id, gp.base_plan_id, gp.purchase_state, gp.auto_renewing,
         gp.start_time, gp.expiry_time, gp.last_verified_at
  from public.google_play_purchases gp
  where gp.business_id = p_business_id
    and (public.is_platform_admin() or public.is_business_member(p_business_id))
  order by gp.updated_at desc
  limit 1;
$$;

grant execute on function public.get_own_business_subscription(uuid) to authenticated;

-- 5) Verification write path -- INTEGRATION POINT, NOT WIRED UP YET.
--
-- This function is the only way a google_play_purchases row (and the
-- resulting businesses.subscription_status/plan_id) can be written. It
-- takes an already-verified result as input rather than a raw purchase
-- token, because the actual verification call -- Google Play Developer
-- API, `purchases.subscriptionsv2.get`, authenticated with a Google
-- Cloud service-account credential -- cannot be made from Postgres. That
-- call must happen in a trusted server context (a Next.js Route Handler
-- or scheduled job, using the service-role Supabase client from
-- src/lib/supabase/admin.ts, exactly like the existing
-- auth.admin.inviteUserByEmail calls), which then calls this RPC with
-- the verified result to persist it.
--
-- No EXECUTE grant is given to `authenticated` here on purpose -- an
-- ordinary client must never be able to claim "my purchase is verified"
-- for itself. Once the real verification job exists, grant EXECUTE to
-- the service role only (service_role already bypasses RLS/grants by
-- default in Supabase, so today this function is effectively
-- unreachable from anywhere until that job is written and calls it with
-- the service-role key -- which is the intended state until Google Play
-- credentials are configured).
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
  v_new_subscription_status text;
begin
  insert into public.google_play_purchases (
    business_id, plan_id, product_id, base_plan_id, purchase_token, order_id,
    purchase_state, auto_renewing, start_time, expiry_time, last_verified_at,
    raw_verification_response
  )
  values (
    p_business_id, p_plan_id, p_product_id, p_base_plan_id, p_purchase_token, p_order_id,
    p_purchase_state, p_auto_renewing, p_start_time, p_expiry_time, now(),
    coalesce(p_raw_verification_response, '{}'::jsonb)
  )
  on conflict (purchase_token) do update set
    plan_id = excluded.plan_id,
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
    when 'ON_HOLD' then 'GRACE_PERIOD'
    when 'CANCELLED' then 'CANCELLED'
    when 'EXPIRED' then 'EXPIRED'
    when 'REVOKED' then 'EXPIRED'
    else null
  end;

  if v_new_subscription_status is not null then
    update public.businesses
    set subscription_status = v_new_subscription_status,
        plan_id = coalesce(p_plan_id, plan_id)
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

-- No grant statement here on purpose -- see the comment above the
-- function. Add `grant execute on function
-- public.apply_google_play_verification_result(...) to service_role;`
-- (service_role already has it implicitly via Supabase's default
-- privileges, so this is documentation, not a required step) once the
-- verification job that calls it exists.

comment on function public.apply_google_play_verification_result is
  'Google Play integration point: called only from a trusted server-side '
  'verification job (not implemented yet -- requires a Google Cloud '
  'service-account credential and the Play Developer API '
  'purchases.subscriptionsv2.get call) with an already-verified result. '
  'Never called directly by client code.';

-- 6) apply_google_play_verification_result's businesses UPDATE will (once
-- wired up) run under the service role, with no end-user session -- but
-- Faz 3's admin-only guard trigger (restrict_business_update_to_admin_safe_fields,
-- 20260922000018) only exempts public.is_platform_admin(), which reads
-- auth.uid() and is false when auth.uid() is null. service_role already
-- bypasses RLS/FORCE ROW LEVEL SECURITY entirely (see
-- src/lib/supabase/admin.ts's doc comment) but NOT triggers, so without
-- this the future verification job would be blocked by its own subscription
-- update. auth.uid() being null here can only mean a service-role/superuser
-- caller -- every RLS policy that could otherwise reach this table requires
-- `to authenticated`, so no signed-in end user can trigger this branch --
-- this does not weaken the guard against a business admin editing their
-- own subscription fields.
create or replace function public.restrict_business_update_to_admin_safe_fields()
returns trigger
language plpgsql
as $$
begin
  if public.is_platform_admin() or auth.uid() is null then
    return new;
  end if;
  if new.subscription_status is distinct from old.subscription_status
    or new.plan_id is distinct from old.plan_id
    or new.trial_started_at is distinct from old.trial_started_at
    or new.trial_ends_at is distinct from old.trial_ends_at
    or new.active is distinct from old.active then
    raise exception 'Only a platform admin may change subscription, plan, trial, or active status';
  end if;
  return new;
end;
$$;
