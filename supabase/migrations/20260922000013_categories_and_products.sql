create table public.categories (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  name text not null,
  sort_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_categories_business on public.categories (business_id);

create trigger trg_categories_updated_at
  before update on public.categories
  for each row execute function public.set_updated_at();

create table public.products (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  category_id uuid references public.categories (id) on delete set null,
  name text not null,
  description text,
  price numeric(10, 2) not null check (price >= 0),
  image_url text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_products_business on public.products (business_id);
create index idx_products_category on public.products (category_id);

create trigger trg_products_updated_at
  before update on public.products
  for each row execute function public.set_updated_at();

alter table public.categories enable row level security;
alter table public.categories force row level security;
alter table public.products enable row level security;
alter table public.products force row level security;

-- categories/products: all active staff can read (waiters/kitchen need
-- the menu); only BUSINESS_ADMIN can write.
create policy categories_select_member
  on public.categories for select
  to authenticated
  using (public.is_platform_admin() or public.is_business_member(business_id));

create policy categories_write_admin
  on public.categories for insert
  to authenticated
  with check (public.has_business_role(business_id, array['BUSINESS_ADMIN']));

create policy categories_update_admin
  on public.categories for update
  to authenticated
  using (public.has_business_role(business_id, array['BUSINESS_ADMIN']))
  with check (public.has_business_role(business_id, array['BUSINESS_ADMIN']));

create policy categories_delete_admin
  on public.categories for delete
  to authenticated
  using (public.has_business_role(business_id, array['BUSINESS_ADMIN']));

create policy products_select_member
  on public.products for select
  to authenticated
  using (public.is_platform_admin() or public.is_business_member(business_id));

create policy products_write_admin
  on public.products for insert
  to authenticated
  with check (public.has_business_role(business_id, array['BUSINESS_ADMIN']));

create policy products_update_admin
  on public.products for update
  to authenticated
  using (public.has_business_role(business_id, array['BUSINESS_ADMIN']))
  with check (public.has_business_role(business_id, array['BUSINESS_ADMIN']));

create policy products_delete_admin
  on public.products for delete
  to authenticated
  using (public.has_business_role(business_id, array['BUSINESS_ADMIN']));

-- QR menu (public, read-only, no prices hidden) will read products for
-- an active business via a SECURITY DEFINER RPC added in a later phase
-- (feature-flagged per plan) rather than a broad anon SELECT policy, so
-- that access can be gated on qr_menu_enabled and business.active.
