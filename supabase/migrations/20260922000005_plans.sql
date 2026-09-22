-- plans: dynamic plan/limit definitions managed by the Super Admin.
-- Nothing here is hard-coded into application logic; limits are read
-- and enforced at runtime against a business's assigned plan.
create table public.plans (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  monthly_price numeric(10, 2) not null default 0,
  yearly_price numeric(10, 2) not null default 0,
  yearly_discount numeric(5, 2) not null default 0,
  max_tables integer,
  max_waiters integer,
  max_users integer,
  max_areas integer,
  max_branches integer,
  qr_menu_enabled boolean not null default false,
  reporting_level text not null default 'BASIC',
  feature_flags jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_plans_updated_at
  before update on public.plans
  for each row execute function public.set_updated_at();

alter table public.plans enable row level security;
alter table public.plans force row level security;

-- Plans are readable by any authenticated user (needed so a business
-- admin can see their own plan's limits and so the public application/
-- pricing flow can list active plans). Only the platform admin can
-- write. is_platform_admin() is defined in 20260922000008_helper_functions.sql;
-- this policy is created there instead of here to keep dependency order
-- correct. Read policy is safe to define now since it needs no helper.
create policy plans_select_all
  on public.plans for select
  to authenticated, anon
  using (true);
