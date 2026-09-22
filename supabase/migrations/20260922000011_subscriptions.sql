-- subscriptions: history of plan assignments per business. The
-- business's *current* status/trial dates live on businesses itself
-- (fast to read on every request); this table is the billing-history
-- ledger and is written only by the platform admin.
create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  plan_id uuid not null references public.plans (id),
  status text not null check (status in ('TRIAL', 'ACTIVE', 'EXPIRED', 'SUSPENDED', 'CANCELLED')),
  started_at timestamptz not null default now(),
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_subscriptions_business on public.subscriptions (business_id);

create trigger trg_subscriptions_updated_at
  before update on public.subscriptions
  for each row execute function public.set_updated_at();

alter table public.subscriptions enable row level security;
alter table public.subscriptions force row level security;

create policy subscriptions_select
  on public.subscriptions for select
  to authenticated
  using (public.is_platform_admin() or public.is_business_member(business_id));

create policy subscriptions_write_platform_admin
  on public.subscriptions for insert
  to authenticated
  with check (public.is_platform_admin());

create policy subscriptions_update_platform_admin
  on public.subscriptions for update
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());
