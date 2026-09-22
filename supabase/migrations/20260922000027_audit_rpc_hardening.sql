-- Faz 12: fixes the general-purpose audit RPC problem flagged by the
-- independent (Codex) security audit.
--
-- The bug: public.log_audit_event was `grant execute ... to authenticated`
-- with only one check -- that the caller is a member of p_business_id (or
-- a platform admin). action/entity/entity_id/metadata were otherwise
-- completely free-form client input, never derived from anything that
-- actually happened in the database. Concretely, any WAITER or CASHIER
-- (both pass is_business_member) could open devtools and call
-- `supabase.rpc('log_audit_event', { p_business_id: <their business>,
-- p_action: 'ANYTHING', p_entity: 'anything', p_entity_id: <any uuid,
-- not even checked against business_id>, p_metadata: {...} })` and write
-- a fabricated audit entry -- indistinguishable in the UI from a real
-- one -- for an event that never happened. That undermines the entire
-- point of an audit log (section 30: "kim, ne zaman, ne yaptı").
--
-- The fix: every sensitive action that used to log itself via a second,
-- separately-trusted RPC call now gets its audit entry written
-- automatically by a trigger on the row that actually changed, deriving
-- action/entity/metadata from the real OLD/NEW values -- so forging an
-- entry now requires actually performing (and having permission for) the
-- underlying state change, not just calling a logging function. Client
-- code can no longer log anything at all: log_audit_event's EXECUTE
-- grant to `authenticated` is revoked; it's still used internally by the
-- triggers below (they're SECURITY DEFINER, so they call it as their
-- owner, unaffected by the revoke -- same mechanism Postgres already
-- uses for every other SECURITY DEFINER helper in this schema).

-- Also widen log_audit_event's own authorization check: it currently
-- requires is_platform_admin() or is_business_member(p_business_id),
-- both of which read auth.uid() and are false when there's no end-user
-- session -- which is exactly the case for the future Google Play
-- verification job (service_role, no JWT; see
-- 20260922000026_google_play_subscriptions.sql) and for the AFTER
-- UPDATE trigger on businesses firing as a side effect of that same
-- service-role write. Without this, every trigger-driven audit entry
-- for that flow would itself raise "Not authorized". auth.uid() is null
-- can only happen for a service-role/superuser caller here -- no RLS
-- policy that could reach these tables permits an unauthenticated write
-- -- so this does not let a signed-in user log on another business's
-- behalf.
create or replace function public.log_audit_event(
  p_business_id uuid,
  p_action text,
  p_entity text,
  p_entity_id uuid,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if p_business_id is not null
    and auth.uid() is not null
    and not (public.is_platform_admin() or public.is_business_member(p_business_id)) then
    raise exception 'Not authorized to log an audit event for this business';
  end if;

  insert into public.audit_logs (actor_id, business_id, action, entity, entity_id, metadata)
  values (auth.uid(), p_business_id, p_action, p_entity, p_entity_id, coalesce(p_metadata, '{}'::jsonb))
  returning id into v_id;

  return v_id;
end;
$$;

revoke execute on function public.log_audit_event(uuid, text, text, uuid, jsonb) from authenticated;

comment on function public.log_audit_event is
  'Internal audit-write helper. No longer directly callable by client '
  'code (EXECUTE revoked from authenticated) -- only the SECURITY '
  'DEFINER triggers in 20260922000027_audit_rpc_hardening.sql call it, '
  'each deriving action/entity/metadata from a real row change rather '
  'than trusting client-supplied strings.';

-- 1) payments: void -> PAYMENT_VOIDED (used to be logged from
-- payment-panel.tsx's browser-side rpc call after the fact; the trigger
-- fires on the same UPDATE that restrict_payment_void already validates,
-- so the two can never disagree).
create or replace function public.audit_payment_void()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status is distinct from old.status and new.status = 'VOID' then
    perform public.log_audit_event(
      new.business_id, 'PAYMENT_VOIDED', 'payments', new.id,
      jsonb_build_object('amount', new.amount, 'method', new.method, 'reason', new.void_reason)
    );
  end if;
  return new;
end;
$$;

create trigger trg_payments_audit_void
  after update on public.payments
  for each row execute function public.audit_payment_void();

-- 2) order_items: void -> ORDER_ITEM_VOIDED
create or replace function public.audit_order_item_void()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status is distinct from old.status and new.status = 'VOID' then
    perform public.log_audit_event(
      new.business_id, 'ORDER_ITEM_VOIDED', 'order_items', new.id,
      jsonb_build_object('reason', new.void_reason)
    );
  end if;
  return new;
end;
$$;

create trigger trg_order_items_audit_void
  after update on public.order_items
  for each row execute function public.audit_order_item_void();

-- 3) orders: cancel -> ORDER_CANCELLED
create or replace function public.audit_order_cancel()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status is distinct from old.status and new.status = 'CANCELLED' then
    perform public.log_audit_event(
      new.business_id, 'ORDER_CANCELLED', 'orders', new.id, '{}'::jsonb
    );
  end if;
  return new;
end;
$$;

create trigger trg_orders_audit_cancel
  after update on public.orders
  for each row execute function public.audit_order_cancel();

-- 4) business_memberships: insert -> STAFF_INVITED, role/active change ->
-- STAFF_ROLE_CHANGED / STAFF_(DE)ACTIVATED. Covers both the business
-- admin's staff management (isletme/personel) and the initial
-- BUSINESS_ADMIN row create_own_business inserts for a brand-new
-- business (a reasonable "who was granted access" entry either way).
create or replace function public.audit_business_membership_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.log_audit_event(
    new.business_id, 'STAFF_INVITED', 'business_memberships', new.id,
    jsonb_build_object('user_id', new.user_id, 'role', new.role)
  );
  return new;
end;
$$;

create trigger trg_business_memberships_audit_insert
  after insert on public.business_memberships
  for each row execute function public.audit_business_membership_insert();

create or replace function public.audit_business_membership_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.role is distinct from old.role then
    perform public.log_audit_event(
      new.business_id, 'STAFF_ROLE_CHANGED', 'business_memberships', new.id,
      jsonb_build_object('user_id', new.user_id, 'old_role', old.role, 'new_role', new.role)
    );
  end if;
  if new.active is distinct from old.active then
    perform public.log_audit_event(
      new.business_id,
      case when new.active then 'STAFF_REACTIVATED' else 'STAFF_DEACTIVATED' end,
      'business_memberships', new.id,
      jsonb_build_object('user_id', new.user_id)
    );
  end if;
  return new;
end;
$$;

create trigger trg_business_memberships_audit_update
  after update on public.business_memberships
  for each row execute function public.audit_business_membership_update();

-- 5) businesses: platform-admin-only field changes -> BUSINESS_SUSPENDED
-- / BUSINESS_REACTIVATED / BUSINESS_SUBSCRIPTION_STATUS_CHANGED /
-- BUSINESS_PLAN_ASSIGNED / BUSINESS_TRIAL_EXTENDED / BUSINESS_ACTIVATED /
-- BUSINESS_DEACTIVATED. restrict_business_update_to_admin_safe_fields
-- (Faz 3, widened in 20260922000026) only lets these columns change via
-- a platform admin or a service-role caller (no end-user session), so
-- whoever/whatever triggered this update is always legitimate -- never a
-- business's own staff.
create or replace function public.audit_business_admin_fields_update()
returns trigger
language plpgsql
security definer
set search_path = public
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
    perform public.log_audit_event(
      new.id, v_action, 'businesses', new.id,
      jsonb_build_object('old_status', old.subscription_status, 'new_status', new.subscription_status)
    );
  end if;

  if new.plan_id is distinct from old.plan_id then
    perform public.log_audit_event(
      new.id, 'BUSINESS_PLAN_ASSIGNED', 'businesses', new.id,
      jsonb_build_object('old_plan_id', old.plan_id, 'new_plan_id', new.plan_id)
    );
  end if;

  if new.trial_ends_at is distinct from old.trial_ends_at and new.trial_ends_at > old.trial_ends_at then
    perform public.log_audit_event(
      new.id, 'BUSINESS_TRIAL_EXTENDED', 'businesses', new.id,
      jsonb_build_object('old_trial_ends_at', old.trial_ends_at, 'new_trial_ends_at', new.trial_ends_at)
    );
  end if;

  if new.active is distinct from old.active then
    perform public.log_audit_event(
      new.id,
      case when new.active then 'BUSINESS_ACTIVATED' else 'BUSINESS_DEACTIVATED' end,
      'businesses', new.id, '{}'::jsonb
    );
  end if;

  return new;
end;
$$;

create trigger trg_businesses_audit_admin_fields
  after update on public.businesses
  for each row execute function public.audit_business_admin_fields_update();

-- 6) business_applications: force reviewed_by/reviewed_at server-side
-- (same class of client-forgery gap as voided_by/received_by/opened_by,
-- Faz 5/7/11 -- surfaced here while touching this table for the audit
-- fix) and log the outcome automatically instead of trusting the
-- server action's own rpc call.
create or replace function public.restrict_business_application_review()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status is distinct from old.status and old.status = 'PENDING'
    and new.status in ('APPROVED', 'REJECTED') then
    new.reviewed_by := auth.uid();
    new.reviewed_at := now();

    perform public.log_audit_event(
      new.resulting_business_id,
      case when new.status = 'APPROVED' then 'BUSINESS_APPLICATION_APPROVED' else 'BUSINESS_APPLICATION_REJECTED' end,
      'business_applications', new.id,
      jsonb_build_object('business_name', new.business_name, 'rejection_reason', new.rejection_reason)
    );
  end if;
  return new;
end;
$$;

create trigger trg_business_applications_restrict_review
  before update on public.business_applications
  for each row execute function public.restrict_business_application_review();
