-- businesses: the tenant root. Every operational table below hangs off
-- business_id, either directly or transitively.
create table public.businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  business_type text,
  city text,
  address text,
  phone text,
  email text,
  logo_url text,
  plan_id uuid references public.plans (id),
  subscription_status text not null default 'TRIAL'
    check (subscription_status in ('TRIAL', 'ACTIVE', 'EXPIRED', 'SUSPENDED', 'CANCELLED')),
  trial_started_at timestamptz not null default now(),
  trial_ends_at timestamptz not null default (now() + interval '7 days'),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_businesses_updated_at
  before update on public.businesses
  for each row execute function public.set_updated_at();

alter table public.businesses enable row level security;
alter table public.businesses force row level security;

-- Policies depend on has_business_role()/is_platform_admin(), defined in
-- 20260922000008_helper_functions.sql, so they are created in
-- 20260922000009_core_rls_policies.sql instead of here.
