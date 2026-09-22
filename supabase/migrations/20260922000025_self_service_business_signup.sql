-- Faz 12: self-service business signup. Master prompt now requires that
-- businesses are never opened via Super Admin approval -- a user creates
-- their own account and their own business, which starts an automatic
-- 7-day trial immediately. business_applications / the manual approval
-- flow this replaces is handled in this same migration (see below) --
-- deliberately NOT dropped (may hold real historical data), just closed
-- to new submissions.

-- 1) create_own_business: the only way a business can now come into
-- existence from client code. SECURITY DEFINER so it can insert into
-- businesses/business_memberships despite neither having a direct
-- INSERT policy for a plain authenticated user (businesses only allows
-- platform-admin INSERT, see businesses_insert_platform_admin) -- but
-- unlike a broad policy, this function computes every trial/status field
-- itself and never trusts the caller for them: subscription_status is
-- always 'TRIAL', trial_started_at/trial_ends_at are always server
-- `now()`/`now() + 7 days`, plan_id is always null (no plan assigned
-- yet -- enforce_plan_limit treats a null plan as unlimited, so the
-- business gets full access during its trial per the new architecture,
-- with zero special-casing needed elsewhere), and active is always true.
-- The caller only supplies descriptive profile fields.
create or replace function public.create_own_business(
  p_name text,
  p_business_type text default null,
  p_city text default null,
  p_address text default null,
  p_phone text default null,
  p_email text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_business_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Must be signed in to create a business';
  end if;

  if p_name is null or length(trim(p_name)) = 0 then
    raise exception 'Business name is required';
  end if;

  insert into public.businesses (
    name, business_type, city, address, phone, email,
    plan_id, subscription_status, trial_started_at, trial_ends_at, active
  )
  values (
    trim(p_name),
    nullif(trim(coalesce(p_business_type, '')), ''),
    nullif(trim(coalesce(p_city, '')), ''),
    nullif(trim(coalesce(p_address, '')), ''),
    nullif(trim(coalesce(p_phone, '')), ''),
    nullif(trim(coalesce(p_email, '')), ''),
    null,
    'TRIAL',
    now(),
    now() + interval '7 days',
    true
  )
  returning id into v_business_id;

  -- The creating user is always the business's first BUSINESS_ADMIN.
  -- enforce_plan_limit's max_users check runs on this insert too, but
  -- plan_id is null here so it's a no-op for a brand-new business.
  insert into public.business_memberships (user_id, business_id, role)
  values (auth.uid(), v_business_id, 'BUSINESS_ADMIN');

  perform public.log_audit_event(
    v_business_id,
    'BUSINESS_SELF_REGISTERED',
    'businesses',
    v_business_id,
    jsonb_build_object('name', trim(p_name))
  );

  return v_business_id;
end;
$$;

grant execute on function public.create_own_business(text, text, text, text, text, text) to authenticated;

-- 2) business_applications no longer accepts new submissions -- the
-- public /basvuru form and the admin-approval flow it fed are replaced
-- by create_own_business above. The table, its historical rows, and the
-- platform-admin read/update policies are left exactly as they were so
-- existing records stay reviewable (the Super Admin panel keeps a
-- read-only archive view); only the door for *new* applications is
-- closed.
drop policy if exists business_applications_insert_public on public.business_applications;

comment on table public.business_applications is
  'Legacy manual business-approval flow, retired in favor of self-service '
  'signup (public.create_own_business). No insert policy exists any more '
  '-- kept only for historical/audit reference to businesses approved '
  'before the self-service model.';
