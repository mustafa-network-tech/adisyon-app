-- Core authorization helper functions used by every tenant-scoped RLS
-- policy. SECURITY DEFINER + fixed search_path so they can read
-- platform_admins / business_memberships regardless of the caller's own
-- RLS visibility into those tables, without being hijackable via a
-- search_path attack.

create or replace function public.is_platform_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.platform_admins pa where pa.user_id = auth.uid()
  );
$$;

create or replace function public.has_business_role(p_business_id uuid, p_roles text[])
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.business_memberships bm
    where bm.business_id = p_business_id
      and bm.user_id = auth.uid()
      and bm.active
      and bm.role = any (p_roles)
  );
$$;

-- True if the current user has ANY active role in the given business
-- (used for read policies where every staff role may view the row).
create or replace function public.is_business_member(p_business_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.business_memberships bm
    where bm.business_id = p_business_id
      and bm.user_id = auth.uid()
      and bm.active
  );
$$;

grant execute on function public.is_platform_admin() to authenticated;
grant execute on function public.has_business_role(uuid, text[]) to authenticated;
grant execute on function public.is_business_member(uuid) to authenticated;
