-- business_applications: public onboarding form. Anonymous visitors may
-- INSERT (submit an application) but can never read back applications
-- (avoids leaking other applicants' contact info). Only the platform
-- admin can read/review/approve/reject.
create table public.business_applications (
  id uuid primary key default gen_random_uuid(),
  business_name text not null,
  business_type text,
  contact_name text not null,
  phone text not null,
  email text not null,
  city text,
  address text,
  estimated_tables integer,
  description text,
  consents_accepted boolean not null default false,
  status text not null default 'PENDING' check (status in ('PENDING', 'APPROVED', 'REJECTED')),
  reviewed_by uuid references public.profiles (id),
  reviewed_at timestamptz,
  rejection_reason text,
  resulting_business_id uuid references public.businesses (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_business_applications_updated_at
  before update on public.business_applications
  for each row execute function public.set_updated_at();

alter table public.business_applications enable row level security;
alter table public.business_applications force row level security;

create policy business_applications_insert_public
  on public.business_applications for insert
  to anon, authenticated
  with check (
    status = 'PENDING'
    and reviewed_by is null
    and reviewed_at is null
    and resulting_business_id is null
    and consents_accepted = true
  );

create policy business_applications_select_platform_admin
  on public.business_applications for select
  to authenticated
  using (public.is_platform_admin());

create policy business_applications_update_platform_admin
  on public.business_applications for update
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());
