-- Faz 10: QR Menü (section 21). Public, unauthenticated visitors need to
-- read a business's menu -- but categories/products/businesses RLS
-- (Faz 1) intentionally has no anon policy at all, and that stays true;
-- opening those tables to anon would leak every column (including
-- businesses.email/phone/trial_ends_at/subscription_status, which are
-- not meant to be public) since RLS is row-level, not column-level.
--
-- Instead, two SECURITY DEFINER functions expose exactly the safe,
-- read-only projection a public menu needs, and only for a business
-- whose *plan* has qr_menu_enabled (section 9's feature-flag gate).
-- Zero rows back means "not found or QR menu not available for this
-- business" -- deliberately indistinguishable from the caller's side,
-- so this can't be used to probe which businesses exist.

create or replace function public.get_qr_menu_business(p_business_id uuid)
returns table (
  name text,
  logo_url text,
  business_type text,
  city text
)
language sql
security definer
set search_path = public
stable
as $$
  select b.name, b.logo_url, b.business_type, b.city
  from public.businesses b
  join public.plans p on p.id = b.plan_id
  where b.id = p_business_id
    and b.active
    and p.qr_menu_enabled;
$$;

grant execute on function public.get_qr_menu_business(uuid) to anon, authenticated;

create or replace function public.get_qr_menu_items(p_business_id uuid)
returns table (
  category_id uuid,
  category_name text,
  category_sort_order integer,
  product_id uuid,
  product_name text,
  product_description text,
  product_price numeric,
  product_image_url text
)
language sql
security definer
set search_path = public
stable
as $$
  select
    c.id, c.name, c.sort_order,
    pr.id, pr.name, pr.description, pr.price, pr.image_url
  from public.categories c
  join public.businesses b on b.id = c.business_id
  join public.plans p on p.id = b.plan_id
  left join public.products pr on pr.category_id = c.id and pr.active
  where c.business_id = p_business_id
    and c.active
    and b.active
    and p.qr_menu_enabled
  order by c.sort_order, pr.name;
$$;

grant execute on function public.get_qr_menu_items(uuid) to anon, authenticated;
