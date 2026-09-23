-- Separate trusted, database-derived audit writes from the legacy public
-- helper's end-user authorization check.
--
-- The audited DML is already authorized by its table policy / guard trigger.
-- Re-checking membership inside an AFTER trigger made the audit side effect a
-- second authorization gate that depended on ambient JWT state.  A stale SQL
-- Editor claim (and any future difference in helper visibility) could therefore
-- roll back an otherwise legitimate staff change with:
--   Not authorized to log an audit event for this business
--
-- Trusted trigger/RPC code now writes through a capability that no API role can
-- execute.  public.log_audit_event remains protected and is deliberately not
-- weakened or granted back to PUBLIC/anon/authenticated.

create schema if not exists app_private authorization postgres;

revoke all on schema app_private from public, anon, authenticated, service_role;

create or replace function app_private.write_audit_event(
  p_business_id uuid,
  p_action text,
  p_entity text,
  p_entity_id uuid,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  insert into public.audit_logs (
    actor_id, business_id, action, entity, entity_id, metadata
  )
  values (
    auth.uid(), p_business_id, p_action, p_entity, p_entity_id,
    coalesce(p_metadata, '{}'::jsonb)
  )
  returning id into v_id;

  return v_id;
end;
$$;

alter function app_private.write_audit_event(uuid, text, text, uuid, jsonb)
  owner to postgres;

revoke all on function app_private.write_audit_event(uuid, text, text, uuid, jsonb)
  from public, anon, authenticated, service_role;

comment on function app_private.write_audit_event(uuid, text, text, uuid, jsonb) is
  'Internal audit capability for trusted SECURITY DEFINER triggers/RPCs. No API role has USAGE/EXECUTE.';

-- ---------------------------------------------------------------------------
-- Audit triggers: the triggering row change is the source of truth.  The
-- client cannot choose action/entity/metadata and cannot call the writer.
-- ---------------------------------------------------------------------------
create or replace function public.audit_payment_void()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status is distinct from old.status and new.status = 'VOID' then
    perform app_private.write_audit_event(
      new.business_id, 'PAYMENT_VOIDED', 'payments', new.id,
      jsonb_build_object('amount', new.amount, 'method', new.method, 'reason', new.void_reason)
    );
  end if;
  return new;
end;
$$;

create or replace function public.audit_order_item_void()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status is distinct from old.status and new.status = 'VOID' then
    perform app_private.write_audit_event(
      new.business_id, 'ORDER_ITEM_VOIDED', 'order_items', new.id,
      jsonb_build_object('reason', new.void_reason)
    );
  end if;
  return new;
end;
$$;

create or replace function public.audit_order_cancel()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status is distinct from old.status and new.status = 'CANCELLED' then
    perform app_private.write_audit_event(
      new.business_id, 'ORDER_CANCELLED', 'orders', new.id, '{}'::jsonb
    );
  end if;
  return new;
end;
$$;

create or replace function public.audit_business_membership_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app_private.write_audit_event(
    new.business_id, 'STAFF_INVITED', 'business_memberships', new.id,
    jsonb_build_object('user_id', new.user_id, 'role', new.role)
  );
  return new;
end;
$$;

create or replace function public.audit_business_membership_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.role is distinct from old.role then
    perform app_private.write_audit_event(
      new.business_id, 'STAFF_ROLE_CHANGED', 'business_memberships', new.id,
      jsonb_build_object('user_id', new.user_id, 'old_role', old.role, 'new_role', new.role)
    );
  end if;
  if new.active is distinct from old.active then
    perform app_private.write_audit_event(
      new.business_id,
      case when new.active then 'STAFF_REACTIVATED' else 'STAFF_DEACTIVATED' end,
      'business_memberships', new.id,
      jsonb_build_object('user_id', new.user_id)
    );
  end if;
  return new;
end;
$$;

create or replace function public.audit_business_admin_fields_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_action text;
begin
  if new.subscription_status is distinct from old.subscription_status then
    if new.subscription_status = 'SUSPENDED' then
      v_action := 'BUSINESS_SUSPENDED';
    elsif old.subscription_status = 'SUSPENDED' and new.subscription_status = 'ACTIVE' then
      v_action := 'BUSINESS_REACTIVATED';
    else
      v_action := 'BUSINESS_SUBSCRIPTION_STATUS_CHANGED';
    end if;
    perform app_private.write_audit_event(
      new.id, v_action, 'businesses', new.id,
      jsonb_build_object('old_status', old.subscription_status, 'new_status', new.subscription_status)
    );
  end if;

  if new.plan_id is distinct from old.plan_id then
    perform app_private.write_audit_event(
      new.id, 'BUSINESS_PLAN_ASSIGNED', 'businesses', new.id,
      jsonb_build_object('old_plan_id', old.plan_id, 'new_plan_id', new.plan_id)
    );
  end if;

  if new.trial_ends_at is distinct from old.trial_ends_at
    and new.trial_ends_at > old.trial_ends_at then
    perform app_private.write_audit_event(
      new.id, 'BUSINESS_TRIAL_EXTENDED', 'businesses', new.id,
      jsonb_build_object('old_trial_ends_at', old.trial_ends_at, 'new_trial_ends_at', new.trial_ends_at)
    );
  end if;

  if new.active is distinct from old.active then
    perform app_private.write_audit_event(
      new.id,
      case when new.active then 'BUSINESS_ACTIVATED' else 'BUSINESS_DEACTIVATED' end,
      'businesses', new.id, '{}'::jsonb
    );
  end if;

  return new;
end;
$$;

create or replace function public.restrict_business_application_review()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status is distinct from old.status and old.status = 'PENDING'
    and new.status in ('APPROVED', 'REJECTED') then
    new.reviewed_by := auth.uid();
    new.reviewed_at := now();

    perform app_private.write_audit_event(
      new.resulting_business_id,
      case when new.status = 'APPROVED' then 'BUSINESS_APPLICATION_APPROVED' else 'BUSINESS_APPLICATION_REJECTED' end,
      'business_applications', new.id,
      jsonb_build_object('business_name', new.business_name, 'rejection_reason', new.rejection_reason)
    );
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Trusted RPCs also use the private capability. Their own EXECUTE grants remain
-- the outer security boundary (create_own_business: authenticated;
-- apply_google_play_verification_result: service_role only).
-- ---------------------------------------------------------------------------
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
set search_path = ''
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
        and p_base_plan_id in (
          p.google_play_monthly_base_plan_id,
          p.google_play_yearly_base_plan_id
        )
      limit 1
    )
  );

  insert into public.google_play_purchases (
    business_id, plan_id, product_id, base_plan_id, purchase_token, order_id,
    purchase_state, auto_renewing, start_time, expiry_time, last_verified_at,
    raw_verification_response
  )
  values (
    p_business_id, v_plan_id, p_product_id, p_base_plan_id, p_purchase_token,
    p_order_id, p_purchase_state, p_auto_renewing, p_start_time,
    p_expiry_time, now(), coalesce(p_raw_verification_response, '{}'::jsonb)
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

  perform app_private.write_audit_event(
    p_business_id,
    'GOOGLE_PLAY_SUBSCRIPTION_VERIFIED',
    'google_play_purchases',
    v_id,
    jsonb_build_object('product_id', p_product_id, 'purchase_state', p_purchase_state)
  );

  return v_id;
end;
$$;

revoke execute on function public.apply_google_play_verification_result(
  uuid, uuid, text, text, text, text, text, boolean, timestamptz, timestamptz, jsonb
) from public, anon, authenticated;
grant execute on function public.apply_google_play_verification_result(
  uuid, uuid, text, text, text, text, text, boolean, timestamptz, timestamptz, jsonb
) to service_role;

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

  perform app_private.write_audit_event(
    v_business_id,
    'BUSINESS_SELF_REGISTERED',
    'businesses',
    v_business_id,
    jsonb_build_object('name', trim(p_name))
  );

  return v_business_id;
end;
$$;

-- CREATE OR REPLACE keeps existing grants, but make the intended boundaries
-- explicit so this migration is safe even if defaults changed independently.
revoke execute on function public.create_own_business(text, text, text, text, text, text)
  from public, anon;
grant execute on function public.create_own_business(text, text, text, text, text, text)
  to authenticated;

revoke execute on function public.log_audit_event(uuid, text, text, uuid, jsonb)
  from public, anon, authenticated;
