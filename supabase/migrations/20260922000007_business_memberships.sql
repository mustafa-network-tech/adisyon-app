-- business_memberships: user <-> business <-> role. A user may belong to
-- multiple businesses (future multi-branch/multi-tenant staff), but has
-- at most one role per business. PLATFORM_SUPER_ADMIN is intentionally
-- NOT a valid value here -- see platform_admins.
create table public.business_memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  business_id uuid not null references public.businesses (id) on delete cascade,
  role text not null check (role in ('BUSINESS_ADMIN', 'CASHIER', 'WAITER', 'KITCHEN')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, business_id)
);

create index idx_business_memberships_user on public.business_memberships (user_id) where active;
create index idx_business_memberships_business on public.business_memberships (business_id) where active;

create trigger trg_business_memberships_updated_at
  before update on public.business_memberships
  for each row execute function public.set_updated_at();

alter table public.business_memberships enable row level security;
alter table public.business_memberships force row level security;

-- A user may always see their own memberships (needed for client-side
-- role routing at login). Broader/admin policies are added in
-- 20260922000009_core_rls_policies.sql once has_business_role() exists.
create policy business_memberships_select_own
  on public.business_memberships for select
  to authenticated
  using (user_id = auth.uid());
