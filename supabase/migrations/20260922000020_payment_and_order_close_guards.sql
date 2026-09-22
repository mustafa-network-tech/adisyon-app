-- Faz 7 (Kasa/POS) is the first thing to actually close and cancel
-- orders and record/void payments, surfacing gaps Faz 1 deliberately
-- left for "later phases":

-- 1) orders_update_staff (Faz 1) lets WAITER update any column of an
-- OPEN order, including status -- but closing/cancelling a bill is the
-- cashier's/admin's job (section 17), not the waiter's (section 14
-- lists opening a table, adding items, requesting a check, and
-- cancellation requests -- never closing or cancelling the order
-- itself). WAITER may still update check_requested (that policy is
-- unchanged); only status changes are gated here.
--
-- 2) Nothing stopped closing a bill before it was fully paid, or
-- cancelling an order that already had money against it -- a direct
-- hole in "finansal veri bütünlüğü" (section 38 priority #3). Both are
-- now enforced in the database, not just the POS UI.
create or replace function public.enforce_order_status_change_rules()
returns trigger
language plpgsql
as $$
declare
  v_active_total numeric(10, 2);
  v_paid_total numeric(10, 2);
begin
  if new.status is distinct from old.status then
    if not public.has_business_role(new.business_id, array['BUSINESS_ADMIN', 'CASHIER']) then
      raise exception 'Only a cashier or business admin may close or cancel an order';
    end if;

    if new.status = 'CLOSED' then
      select coalesce(sum(unit_price_snapshot * quantity), 0) into v_active_total
        from public.order_items
        where order_id = new.id and status <> 'VOID';
      select coalesce(sum(amount), 0) into v_paid_total
        from public.payments
        where order_id = new.id and status = 'COMPLETED';

      if v_paid_total < v_active_total then
        raise exception 'Cannot close an order before it is fully paid';
      end if;
      new.closed_at := now();
    elsif new.status = 'CANCELLED' then
      if exists (
        select 1 from public.payments where order_id = new.id and status = 'COMPLETED'
      ) then
        raise exception 'Cannot cancel an order that already has completed payments';
      end if;
      new.closed_at := now();
    end if;
  end if;
  return new;
end;
$$;

create trigger trg_orders_enforce_status_change_rules
  before update on public.orders
  for each row execute function public.enforce_order_status_change_rules();

-- 3) payments.received_by (Faz 1) was client-supplied and trusted --
-- any cashier could credit a payment to a different staff member's id.
-- Same class of gap as voided_by below; same fix: always server-derived.
create or replace function public.check_payment_order_business()
returns trigger
language plpgsql
as $$
declare
  v_order_business_id uuid;
begin
  select business_id into v_order_business_id from public.orders where id = new.order_id;
  if v_order_business_id is null then
    raise exception 'payments.order_id does not reference an existing order';
  end if;
  new.business_id := v_order_business_id;
  new.received_by := auth.uid();
  return new;
end;
$$;

-- 4) payments had the same audit-forgery gap order_items had before
-- Faz 5: voided_by/voided_at were never enforced server-side and
-- void_reason was never required. Same fix, same reasoning. Voiding is
-- also restricted to while the order is still OPEN -- correcting a
-- payment after the bill is already closed needs a real reopen flow,
-- which is out of scope here; that stays a manual/admin operation for
-- now rather than a half-built self-service path.
create or replace function public.restrict_payment_void()
returns trigger
language plpgsql
as $$
declare
  v_order_status text;
begin
  if new.status is distinct from old.status and new.status = 'VOID' then
    select status into v_order_status from public.orders where id = new.order_id;
    if v_order_status <> 'OPEN' then
      raise exception 'Cannot void a payment on an order that is not open';
    end if;
    if new.void_reason is null or length(trim(new.void_reason)) = 0 then
      raise exception 'A void_reason is required when voiding a payment';
    end if;
    new.voided_by := auth.uid();
    new.voided_at := now();
  end if;
  return new;
end;
$$;

create trigger trg_payments_restrict_void
  before update on public.payments
  for each row execute function public.restrict_payment_void();

-- 5) Extend Faz 5's order_items void guard the same way: voiding an
-- item (by anyone, including BUSINESS_ADMIN/CASHIER) only makes sense
-- while the order is still open.
create or replace function public.restrict_order_item_void()
returns trigger
language plpgsql
as $$
declare
  v_order_status text;
begin
  if new.status is distinct from old.status and new.status = 'VOID' then
    select status into v_order_status from public.orders where id = new.order_id;
    if v_order_status <> 'OPEN' then
      raise exception 'Cannot void an item on an order that is not open';
    end if;

    if new.void_reason is null or length(trim(new.void_reason)) = 0 then
      raise exception 'A void_reason is required when voiding an order item';
    end if;
    new.voided_by := auth.uid();
    new.voided_at := now();

    if public.has_business_role(new.business_id, array['BUSINESS_ADMIN', 'CASHIER']) then
      return new;
    end if;
    if public.has_business_role(new.business_id, array['WAITER']) and old.status = 'NEW' then
      return new;
    end if;
    raise exception 'Not authorized to void this order item';
  end if;
  return new;
end;
$$;
