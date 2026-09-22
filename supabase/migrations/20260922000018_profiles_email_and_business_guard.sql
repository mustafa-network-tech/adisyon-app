-- Two small hardening/usability additions surfaced while building the
-- Business Admin web panel (Faz 3):

-- 1) profiles.email: denormalized from auth.users so a business admin
-- can see a staff directory (name + email) through ordinary RLS-safe
-- reads, without needing the service role just to list their own staff.
-- Safe to expose under the same policies as full_name/phone -- it's
-- already restricted to "yourself", "a business admin who shares a
-- business with you", or the platform admin (see profiles_select_own /
-- profiles_select_business_admin in earlier migrations).
alter table public.profiles add column email text;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, phone, email)
  values (
    new.id,
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'phone',
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- 2) businesses RLS gap: businesses_update_business_admin (Faz 1) lets a
-- BUSINESS_ADMIN update any column of their own business row, including
-- subscription_status/plan_id/trial dates/active -- fields that should
-- only ever be changed by the platform admin (approving, suspending,
-- extending a trial, assigning a plan). The Faz 3 "Ayarlar" page only
-- ever sends profile fields (name/type/city/address/phone/email/logo),
-- but RLS must enforce this at the database, not trust the UI: a
-- business admin could otherwise PATCH those columns directly against
-- PostgREST with their own session.
create or replace function public.restrict_business_update_to_admin_safe_fields()
returns trigger
language plpgsql
as $$
begin
  if public.is_platform_admin() then
    return new;
  end if;
  if new.subscription_status is distinct from old.subscription_status
    or new.plan_id is distinct from old.plan_id
    or new.trial_started_at is distinct from old.trial_started_at
    or new.trial_ends_at is distinct from old.trial_ends_at
    or new.active is distinct from old.active then
    raise exception 'Only a platform admin may change subscription, plan, trial, or active status';
  end if;
  return new;
end;
$$;

create trigger trg_businesses_restrict_admin_update
  before update on public.businesses
  for each row execute function public.restrict_business_update_to_admin_safe_fields();
