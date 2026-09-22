create table public.areas (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  name text not null,
  sort_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_areas_business on public.areas (business_id);

create trigger trg_areas_updated_at
  before update on public.areas
  for each row execute function public.set_updated_at();

create table public.restaurant_tables (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  area_id uuid not null references public.areas (id) on delete cascade,
  name text not null,
  status text not null default 'AVAILABLE'
    check (status in ('AVAILABLE', 'OCCUPIED', 'CHECK_REQUESTED')),
  sort_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_restaurant_tables_business on public.restaurant_tables (business_id);
create index idx_restaurant_tables_area on public.restaurant_tables (area_id);

create trigger trg_restaurant_tables_updated_at
  before update on public.restaurant_tables
  for each row execute function public.set_updated_at();

-- Guard against area_id belonging to a different business than
-- business_id (denormalized column drifting from its source of truth).
create or replace function public.check_table_area_business()
returns trigger
language plpgsql
as $$
declare
  v_area_business_id uuid;
begin
  select business_id into v_area_business_id from public.areas where id = new.area_id;
  if v_area_business_id is null or v_area_business_id <> new.business_id then
    raise exception 'restaurant_tables.business_id must match areas.business_id';
  end if;
  return new;
end;
$$;

create trigger trg_restaurant_tables_check_business
  before insert or update on public.restaurant_tables
  for each row execute function public.check_table_area_business();

-- Non-admin staff (WAITER/CASHIER) are only allowed to flip a table's
-- status via UPDATE; renaming/moving/deleting a table stays admin-only.
-- RLS alone can't express "this role may update this column but not
-- that one", so it's enforced here.
create or replace function public.restrict_table_update_to_status()
returns trigger
language plpgsql
as $$
begin
  if public.has_business_role(new.business_id, array['BUSINESS_ADMIN']) then
    return new;
  end if;
  if new.name is distinct from old.name
    or new.area_id is distinct from old.area_id
    or new.sort_order is distinct from old.sort_order
    or new.active is distinct from old.active
    or new.business_id is distinct from old.business_id then
    raise exception 'Only a business admin may rename, move, or deactivate a table';
  end if;
  return new;
end;
$$;

create trigger trg_restaurant_tables_restrict_update
  before update on public.restaurant_tables
  for each row execute function public.restrict_table_update_to_status();

alter table public.areas enable row level security;
alter table public.areas force row level security;
alter table public.restaurant_tables enable row level security;
alter table public.restaurant_tables force row level security;

-- areas: any active staff member of the business can read; only
-- BUSINESS_ADMIN can write.
create policy areas_select_member
  on public.areas for select
  to authenticated
  using (public.is_platform_admin() or public.is_business_member(business_id));

create policy areas_insert_admin
  on public.areas for insert
  to authenticated
  with check (public.has_business_role(business_id, array['BUSINESS_ADMIN']));

create policy areas_update_admin
  on public.areas for update
  to authenticated
  using (public.has_business_role(business_id, array['BUSINESS_ADMIN']))
  with check (public.has_business_role(business_id, array['BUSINESS_ADMIN']));

create policy areas_delete_admin
  on public.areas for delete
  to authenticated
  using (public.has_business_role(business_id, array['BUSINESS_ADMIN']));

-- restaurant_tables: any active staff member can read and can update
-- status (WAITER/CASHIER open/close tables as part of daily ops);
-- only BUSINESS_ADMIN can create/delete tables or rename them.
create policy restaurant_tables_select_member
  on public.restaurant_tables for select
  to authenticated
  using (public.is_platform_admin() or public.is_business_member(business_id));

create policy restaurant_tables_insert_admin
  on public.restaurant_tables for insert
  to authenticated
  with check (public.has_business_role(business_id, array['BUSINESS_ADMIN']));

create policy restaurant_tables_update_staff
  on public.restaurant_tables for update
  to authenticated
  using (public.has_business_role(business_id, array['BUSINESS_ADMIN', 'CASHIER', 'WAITER']))
  with check (public.has_business_role(business_id, array['BUSINESS_ADMIN', 'CASHIER', 'WAITER']));

create policy restaurant_tables_delete_admin
  on public.restaurant_tables for delete
  to authenticated
  using (public.has_business_role(business_id, array['BUSINESS_ADMIN']));
