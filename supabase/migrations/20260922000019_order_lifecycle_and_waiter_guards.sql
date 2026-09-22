-- Faz 5 (Flutter Garson) exercises the order-open/close and item-void
-- paths for the first time, surfacing three real gaps left open in
-- Faz 1 ("full lifecycle enforcement deferred"):

-- 1) Nothing kept restaurant_tables.status in sync with its order. A
-- client opening an order had to remember to also set the table to
-- OCCUPIED, and nothing stopped it drifting. Move this into the
-- database: table status is now fully derived from its OPEN order.
create or replace function public.sync_table_status_from_order()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'OPEN' then
    update public.restaurant_tables
    set status = case when new.check_requested then 'CHECK_REQUESTED' else 'OCCUPIED' end
    where id = new.table_id;
  elsif new.status in ('CLOSED', 'CANCELLED') then
    update public.restaurant_tables
    set status = 'AVAILABLE'
    where id = new.table_id
      and not exists (
        select 1 from public.orders o
        where o.table_id = new.table_id and o.status = 'OPEN' and o.id <> new.id
      );
  end if;
  return new;
end;
$$;

create trigger trg_orders_sync_table_status
  after insert or update of status, check_requested on public.orders
  for each row execute function public.sync_table_status_from_order();

-- 2) Nothing stopped two waiters opening the same table at once (race
-- condition -> two OPEN orders on one table, double-billing risk). At
-- most one OPEN order per table, enforced by the database, not app logic.
create unique index uq_orders_one_open_per_table
  on public.orders (table_id)
  where status = 'OPEN';

-- 3) order_items_update_staff (Faz 1) lets WAITER/CASHIER/BUSINESS_ADMIN
-- set status = 'VOID' freely, including forging voided_by to someone
-- else's user id and skipping void_reason entirely -- an audit-integrity
-- gap (section 19/30 of the architecture doc). Tightened now that the
-- waiter's "iptal" action actually exercises this path:
--   - voided_by/voided_at are always taken from auth.uid()/now(),
--     never from client input;
--   - void_reason is required;
--   - WAITER may only void an item that is still NEW (hasn't started
--     preparing yet) -- matches "izin verilen koşullarda iptal talebi
--     oluşturur" in the master prompt; CASHIER/BUSINESS_ADMIN may void
--     from any status; KITCHEN may never void (no financial actions).
create or replace function public.restrict_order_item_void()
returns trigger
language plpgsql
as $$
begin
  if new.status is distinct from old.status and new.status = 'VOID' then
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

create trigger trg_order_items_restrict_void
  before update on public.order_items
  for each row execute function public.restrict_order_item_void();

-- Realtime: waiters need the table grid to reflect other staff's
-- changes live (another waiter opening/closing a table, cashier closing
-- out a check), same as orders/order_items already do (Faz 1).
alter publication supabase_realtime add table public.restaurant_tables;
