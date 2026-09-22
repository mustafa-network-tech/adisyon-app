-- Faz 11: security review findings + performance indexes.
--
-- Systematic re-read of every RLS policy/trigger written so far,
-- checking specifically against the penetration scenarios in section
-- 29 of the master prompt (cross-tenant read/write, role escalation,
-- WAITER/KITCHEN seeing financial data, client-supplied business_id).
-- All of those already hold given the existing design (business_id is
-- always either re-validated against a real relationship or
-- server-overridden, never trusted bare -- see the architecture doc).
-- Two real gaps surfaced on closer inspection, both fixed below.

-- ---------------------------------------------------------------------
-- Finding 1: orders.opened_by was client-supplied and trusted (the same
-- class of audit-forgery gap already fixed for payments.received_by
-- and order_items/payments.voided_by in Faz 5/7) -- a WAITER could open
-- a table and attribute it to a different staff member's user id.
-- orders.table_id/opened_by were also freely mutable via UPDATE with no
-- trigger stopping it, unlike every other "financial fact" column in
-- this schema (order_items/payments already lock theirs down).
-- ---------------------------------------------------------------------
create or replace function public.secure_order_fields()
returns trigger
language plpgsql
as $$
begin
  if TG_OP = 'INSERT' then
    new.opened_by := auth.uid();
  elsif TG_OP = 'UPDATE' then
    if new.table_id is distinct from old.table_id then
      raise exception 'orders.table_id is immutable after creation';
    end if;
    if new.opened_by is distinct from old.opened_by then
      raise exception 'orders.opened_by is immutable after creation';
    end if;
  end if;
  return new;
end;
$$;

create trigger trg_orders_secure_fields
  before insert or update on public.orders
  for each row execute function public.secure_order_fields();

-- ---------------------------------------------------------------------
-- Finding 2: business_memberships_update_admin (Faz 1) only checks the
-- role's business_id, not which columns change. A BUSINESS_ADMIN could
-- take an existing membership row in their own business and repoint its
-- user_id to an arbitrary user, silently granting that user a role
-- without ever going through the invite flow. Never crosses a tenant
-- boundary (business_id reassignment to a business they don't admin
-- was already blocked by the existing WITH CHECK), but user_id
-- reassignment within their own business was not. Application code
-- (personel/actions.ts, the Flutter cashier/waiter screens) never did
-- this anyway -- this closes the raw-API loophole, matching the
-- "financial/identity fields are immutable after creation" pattern
-- already used for orders/order_items/payments.
-- ---------------------------------------------------------------------
create or replace function public.restrict_business_membership_identity_update()
returns trigger
language plpgsql
as $$
begin
  if new.user_id is distinct from old.user_id or new.business_id is distinct from old.business_id then
    raise exception 'business_memberships.user_id and business_id are immutable after creation';
  end if;
  return new;
end;
$$;

create trigger trg_business_memberships_restrict_identity_update
  before update on public.business_memberships
  for each row execute function public.restrict_business_membership_identity_update();

-- ---------------------------------------------------------------------
-- Finding 3: support_requests_insert (Faz 1) only checks business_id;
-- requester_id was client-supplied and trusted, so a BUSINESS_ADMIN
-- could file a support request "as" a different staff member in their
-- own business. Same fix, same reasoning as findings 1/2.
-- ---------------------------------------------------------------------
create or replace function public.secure_support_request_requester()
returns trigger
language plpgsql
as $$
begin
  new.requester_id := auth.uid();
  return new;
end;
$$;

create trigger trg_support_requests_secure_requester
  before insert on public.support_requests
  for each row execute function public.secure_support_request_requester();

-- ---------------------------------------------------------------------
-- Performance: composite indexes for the Faz 8 report queries, which
-- filter by business_id + a date range. The existing single-column
-- business_id indexes still work but force a larger index scan as data
-- grows; these match the actual WHERE clauses in get_revenue_summary /
-- get_top_products / the transaction-history query.
-- ---------------------------------------------------------------------
create index idx_payments_business_created_at on public.payments (business_id, created_at);
create index idx_order_items_business_created_at on public.order_items (business_id, created_at);
create index idx_orders_business_closed_at on public.orders (business_id, closed_at) where status = 'CLOSED';
