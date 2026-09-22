-- Policies that depend on the helper functions from
-- 20260922000008_helper_functions.sql, for tables created earlier
-- (profiles, plans, businesses, business_memberships).

-- profiles: business admins may see the profiles of their own staff
-- (needed to render a staff list with names), platform admin sees all.
create policy profiles_select_business_admin
  on public.profiles for select
  to authenticated
  using (
    public.is_platform_admin()
    or exists (
      select 1
      from public.business_memberships bm_target
      join public.business_memberships bm_self
        on bm_self.business_id = bm_target.business_id
      where bm_target.user_id = public.profiles.id
        and bm_self.user_id = auth.uid()
        and bm_self.active
        and bm_self.role = 'BUSINESS_ADMIN'
    )
  );

-- plans: only the platform admin may write.
create policy plans_write_platform_admin
  on public.plans for insert
  to authenticated
  with check (public.is_platform_admin());

create policy plans_update_platform_admin
  on public.plans for update
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

create policy plans_delete_platform_admin
  on public.plans for delete
  to authenticated
  using (public.is_platform_admin());

-- businesses: members of the business can read it; only the platform
-- admin can create/suspend/reactivate businesses (business creation is
-- always a side effect of application approval, see business_applications);
-- a business admin can update their own business's profile fields, but
-- not subscription_status/plan_id/active (enforced by revoking those
-- columns from the update check below is not expressible in a simple
-- USING/CHECK, so BUSINESS_ADMIN updates go through a restricted set of
-- columns at the application layer; the RLS layer still guarantees they
-- can only ever touch their own business row).
create policy businesses_select_member_or_platform_admin
  on public.businesses for select
  to authenticated
  using (public.is_platform_admin() or public.is_business_member(id));

create policy businesses_insert_platform_admin
  on public.businesses for insert
  to authenticated
  with check (public.is_platform_admin());

create policy businesses_update_platform_admin
  on public.businesses for update
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

create policy businesses_update_business_admin
  on public.businesses for update
  to authenticated
  using (public.has_business_role(id, array['BUSINESS_ADMIN']))
  with check (public.has_business_role(id, array['BUSINESS_ADMIN']));

-- business_memberships: business admins manage staff of their own
-- business; platform admin can see/manage all.
create policy business_memberships_select_admin
  on public.business_memberships for select
  to authenticated
  using (
    public.is_platform_admin()
    or public.has_business_role(business_id, array['BUSINESS_ADMIN'])
  );

create policy business_memberships_insert_admin
  on public.business_memberships for insert
  to authenticated
  with check (
    public.is_platform_admin()
    or public.has_business_role(business_id, array['BUSINESS_ADMIN'])
  );

create policy business_memberships_update_admin
  on public.business_memberships for update
  to authenticated
  using (
    public.is_platform_admin()
    or public.has_business_role(business_id, array['BUSINESS_ADMIN'])
  )
  with check (
    public.is_platform_admin()
    or public.has_business_role(business_id, array['BUSINESS_ADMIN'])
  );

create policy business_memberships_delete_admin
  on public.business_memberships for delete
  to authenticated
  using (
    public.is_platform_admin()
    or public.has_business_role(business_id, array['BUSINESS_ADMIN'])
  );
