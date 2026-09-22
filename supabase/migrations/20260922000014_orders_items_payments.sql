-- orders: represents an open "check"/tab on a table, from open to close.
create table public.orders (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  table_id uuid not null references public.restaurant_tables (id),
  status text not null default 'OPEN' check (status in ('OPEN', 'CLOSED', 'CANCELLED')),
  opened_by uuid not null references public.profiles (id),
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  check_requested boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_orders_business on public.orders (business_id);
create index idx_orders_table on public.orders (table_id);
create index idx_orders_business_open on public.orders (business_id) where status = 'OPEN';

create trigger trg_orders_updated_at
  before update on public.orders
  for each row execute function public.set_updated_at();

-- order_items: individual line items. Price/product are snapshotted at
-- insert time so historical sales are immune to later price changes
-- (section 19). Kitchen lifecycle is tracked via status.
create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  business_id uuid not null references public.businesses (id),
  product_id uuid not null references public.products (id),
  product_name_snapshot text not null,
  unit_price_snapshot numeric(10, 2) not null check (unit_price_snapshot >= 0),
  quantity integer not null check (quantity > 0),
  note text,
  status text not null default 'NEW'
    check (status in ('NEW', 'PREPARING', 'READY', 'SERVED', 'VOID')),
  voided_by uuid references public.profiles (id),
  voided_at timestamptz,
  void_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_order_items_order on public.order_items (order_id);
create index idx_order_items_business on public.order_items (business_id);

create trigger trg_order_items_updated_at
  before update on public.order_items
  for each row execute function public.set_updated_at();

-- payments: split/partial payments against an order. Never deleted;
-- corrections go through status = 'VOID'.
create table public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id),
  business_id uuid not null references public.businesses (id),
  method text not null check (method in ('CASH', 'CARD', 'OTHER')),
  amount numeric(10, 2) not null check (amount > 0),
  status text not null default 'COMPLETED' check (status in ('COMPLETED', 'VOID')),
  received_by uuid not null references public.profiles (id),
  voided_by uuid references public.profiles (id),
  voided_at timestamptz,
  void_reason text,
  created_at timestamptz not null default now()
);

create index idx_payments_order on public.payments (order_id);
create index idx_payments_business on public.payments (business_id);

-- ---------------------------------------------------------------------
-- Consistency triggers: business_id on orders must match its table's
-- business, and business_id on order_items/payments must match their
-- parent order's business. These are denormalized columns purely so
-- RLS policies can filter with a single indexed equality instead of a
-- join; the trigger keeps them from ever drifting.
-- ---------------------------------------------------------------------
create or replace function public.check_order_table_business()
returns trigger
language plpgsql
as $$
declare
  v_table_business_id uuid;
begin
  select business_id into v_table_business_id from public.restaurant_tables where id = new.table_id;
  if v_table_business_id is null or v_table_business_id <> new.business_id then
    raise exception 'orders.business_id must match restaurant_tables.business_id';
  end if;
  return new;
end;
$$;

create trigger trg_orders_check_business
  before insert or update on public.orders
  for each row execute function public.check_order_table_business();

create or replace function public.populate_order_item_snapshot()
returns trigger
language plpgsql
as $$
declare
  v_order_business_id uuid;
  v_product record;
begin
  select business_id into v_order_business_id from public.orders where id = new.order_id;
  if v_order_business_id is null then
    raise exception 'order_items.order_id does not reference an existing order';
  end if;
  new.business_id := v_order_business_id;

  select id, business_id, name, price into v_product from public.products where id = new.product_id;
  if v_product.id is null or v_product.business_id <> v_order_business_id then
    raise exception 'order_items.product_id must belong to the same business as the order';
  end if;
  if new.product_name_snapshot is null then
    new.product_name_snapshot := v_product.name;
  end if;
  if new.unit_price_snapshot is null then
    new.unit_price_snapshot := v_product.price;
  end if;
  return new;
end;
$$;

create trigger trg_order_items_populate_snapshot
  before insert on public.order_items
  for each row execute function public.populate_order_item_snapshot();

-- Once created, a line item's financial facts are immutable: only
-- quantity, note, status and the void_* fields may ever change.
create or replace function public.restrict_order_item_update()
returns trigger
language plpgsql
as $$
begin
  if new.order_id is distinct from old.order_id
    or new.business_id is distinct from old.business_id
    or new.product_id is distinct from old.product_id
    or new.product_name_snapshot is distinct from old.product_name_snapshot
    or new.unit_price_snapshot is distinct from old.unit_price_snapshot then
    raise exception 'order_items financial fields are immutable after creation';
  end if;
  return new;
end;
$$;

create trigger trg_order_items_restrict_update
  before update on public.order_items
  for each row execute function public.restrict_order_item_update();

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
  return new;
end;
$$;

create trigger trg_payments_check_business
  before insert on public.payments
  for each row execute function public.check_payment_order_business();

-- A payment's financial facts are immutable: only status and the void_*
-- fields may ever change (correction is VOID, never edit-in-place).
create or replace function public.restrict_payment_update()
returns trigger
language plpgsql
as $$
begin
  if new.order_id is distinct from old.order_id
    or new.business_id is distinct from old.business_id
    or new.method is distinct from old.method
    or new.amount is distinct from old.amount
    or new.received_by is distinct from old.received_by then
    raise exception 'payments financial fields are immutable after creation';
  end if;
  return new;
end;
$$;

create trigger trg_payments_restrict_update
  before update on public.payments
  for each row execute function public.restrict_payment_update();

-- ---------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------
alter table public.orders enable row level security;
alter table public.orders force row level security;
alter table public.order_items enable row level security;
alter table public.order_items force row level security;
alter table public.payments enable row level security;
alter table public.payments force row level security;

-- orders: all active staff can read/open/update (waiter opens, cashier
-- closes, kitchen never touches orders directly -- only order_items).
create policy orders_select_member
  on public.orders for select
  to authenticated
  using (public.is_platform_admin() or public.is_business_member(business_id));

create policy orders_insert_staff
  on public.orders for insert
  to authenticated
  with check (public.has_business_role(business_id, array['BUSINESS_ADMIN', 'CASHIER', 'WAITER']));

create policy orders_update_staff
  on public.orders for update
  to authenticated
  using (public.has_business_role(business_id, array['BUSINESS_ADMIN', 'CASHIER', 'WAITER']))
  with check (public.has_business_role(business_id, array['BUSINESS_ADMIN', 'CASHIER', 'WAITER']));

-- order_items: all active staff can read (kitchen needs this); waiter/
-- cashier/admin can insert; kitchen can update (status transitions)
-- alongside waiter/cashier/admin. No delete policy -- ever (VOID instead).
create policy order_items_select_member
  on public.order_items for select
  to authenticated
  using (public.is_platform_admin() or public.is_business_member(business_id));

create policy order_items_insert_staff
  on public.order_items for insert
  to authenticated
  with check (public.has_business_role(business_id, array['BUSINESS_ADMIN', 'CASHIER', 'WAITER']));

create policy order_items_update_staff
  on public.order_items for update
  to authenticated
  using (public.has_business_role(business_id, array['BUSINESS_ADMIN', 'CASHIER', 'WAITER', 'KITCHEN']))
  with check (public.has_business_role(business_id, array['BUSINESS_ADMIN', 'CASHIER', 'WAITER', 'KITCHEN']));

-- payments: deliberately excludes WAITER and KITCHEN entirely -- not a
-- UI-level hide, they have no row-level access at all.
create policy payments_select_cashier
  on public.payments for select
  to authenticated
  using (
    public.is_platform_admin()
    or public.has_business_role(business_id, array['BUSINESS_ADMIN', 'CASHIER'])
  );

create policy payments_insert_cashier
  on public.payments for insert
  to authenticated
  with check (public.has_business_role(business_id, array['BUSINESS_ADMIN', 'CASHIER']));

create policy payments_update_cashier
  on public.payments for update
  to authenticated
  using (public.has_business_role(business_id, array['BUSINESS_ADMIN', 'CASHIER']))
  with check (public.has_business_role(business_id, array['BUSINESS_ADMIN', 'CASHIER']));
