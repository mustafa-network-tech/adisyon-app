create table public.support_requests (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  requester_id uuid not null references public.profiles (id),
  type text not null check (type in ('TECHNICAL_SUPPORT', 'FEATURE_REQUEST', 'OTHER')),
  subject text not null,
  description text not null,
  status text not null default 'OPEN' check (status in ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_support_requests_business on public.support_requests (business_id);

create trigger trg_support_requests_updated_at
  before update on public.support_requests
  for each row execute function public.set_updated_at();

create table public.custom_software_requests (
  id uuid primary key default gen_random_uuid(),
  business_id uuid references public.businesses (id) on delete set null,
  requester_name text not null,
  phone text not null,
  email text not null,
  branch_count integer,
  need text not null,
  description text,
  status text not null default 'PENDING' check (status in ('PENDING', 'IN_REVIEW', 'CLOSED')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_custom_software_requests_business on public.custom_software_requests (business_id);

create trigger trg_custom_software_requests_updated_at
  before update on public.custom_software_requests
  for each row execute function public.set_updated_at();

alter table public.support_requests enable row level security;
alter table public.support_requests force row level security;
alter table public.custom_software_requests enable row level security;
alter table public.custom_software_requests force row level security;

-- support_requests: business admin of the owning business + platform
-- admin. Not exposed to WAITER/CASHIER/KITCHEN.
create policy support_requests_select
  on public.support_requests for select
  to authenticated
  using (
    public.is_platform_admin()
    or public.has_business_role(business_id, array['BUSINESS_ADMIN'])
  );

create policy support_requests_insert
  on public.support_requests for insert
  to authenticated
  with check (public.has_business_role(business_id, array['BUSINESS_ADMIN']));

create policy support_requests_update
  on public.support_requests for update
  to authenticated
  using (
    public.is_platform_admin()
    or public.has_business_role(business_id, array['BUSINESS_ADMIN'])
  )
  with check (
    public.is_platform_admin()
    or public.has_business_role(business_id, array['BUSINESS_ADMIN'])
  );

-- custom_software_requests: same access shape as support_requests.
-- business_id may be null (e.g. a prospect without an account yet) --
-- those rows are only ever inserted/read by the platform admin.
create policy custom_software_requests_select
  on public.custom_software_requests for select
  to authenticated
  using (
    public.is_platform_admin()
    or (business_id is not null and public.has_business_role(business_id, array['BUSINESS_ADMIN']))
  );

create policy custom_software_requests_insert
  on public.custom_software_requests for insert
  to authenticated
  with check (
    public.is_platform_admin()
    or (business_id is not null and public.has_business_role(business_id, array['BUSINESS_ADMIN']))
  );

create policy custom_software_requests_update_platform_admin
  on public.custom_software_requests for update
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());
