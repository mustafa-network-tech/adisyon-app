-- platform_admins: membership in this table grants PLATFORM_SUPER_ADMIN.
-- Deliberately separate from business_memberships (a platform admin is
-- not scoped to any business) and deliberately has NO client-facing
-- write policy: a user can never make themselves a platform admin.
-- Bootstrap the first row manually via the Supabase SQL editor / service role:
--   insert into public.platform_admins (user_id) values ('<auth-user-uuid>');
create table public.platform_admins (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.platform_admins enable row level security;
alter table public.platform_admins force row level security;

-- A user may check whether *they themselves* are a platform admin
-- (used by client-side role routing); no broader select is exposed.
create policy platform_admins_select_self
  on public.platform_admins for select
  to authenticated
  using (user_id = auth.uid());

-- No insert/update/delete policy: only the service role (or a Supabase
-- Dashboard SQL editor session, which runs as postgres) can write here.
