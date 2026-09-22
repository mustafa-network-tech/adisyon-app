-- Faz 8: revenue/report queries (section 20 of the architecture doc).
-- Both functions are plain SQL (NOT SECURITY DEFINER), so they run with
-- the caller's own privileges -- the existing RLS policies on
-- payments/order_items are what actually make this tenant-safe. A
-- caller passing someone else's business_id gets zero rows back (RLS
-- still filters on is_business_member(row.business_id)), never another
-- tenant's data, so there's no need to duplicate that check here.

create or replace function public.get_revenue_summary(
  p_business_id uuid,
  p_start timestamptz,
  p_end timestamptz
)
returns table (
  total_revenue numeric,
  cash_total numeric,
  card_total numeric,
  other_total numeric,
  order_count bigint,
  average_order numeric
)
language sql
stable
as $$
  with paid as (
    select p.method, p.amount
    from public.payments p
    where p.business_id = p_business_id
      and p.status = 'COMPLETED'
      and p.created_at >= p_start
      and p.created_at < p_end
  ),
  closed as (
    select o.id
    from public.orders o
    where o.business_id = p_business_id
      and o.status = 'CLOSED'
      and o.closed_at >= p_start
      and o.closed_at < p_end
  )
  select
    coalesce((select sum(amount) from paid), 0) as total_revenue,
    coalesce((select sum(amount) from paid where method = 'CASH'), 0) as cash_total,
    coalesce((select sum(amount) from paid where method = 'CARD'), 0) as card_total,
    coalesce((select sum(amount) from paid where method = 'OTHER'), 0) as other_total,
    (select count(*) from closed) as order_count,
    case
      when (select count(*) from closed) = 0 then 0
      else round(coalesce((select sum(amount) from paid), 0) / (select count(*) from closed), 2)
    end as average_order;
$$;

grant execute on function public.get_revenue_summary(uuid, timestamptz, timestamptz) to authenticated;

create or replace function public.get_top_products(
  p_business_id uuid,
  p_start timestamptz,
  p_end timestamptz,
  p_limit int default 10
)
returns table (
  product_name text,
  total_quantity bigint,
  total_revenue numeric
)
language sql
stable
as $$
  select
    oi.product_name_snapshot as product_name,
    sum(oi.quantity) as total_quantity,
    sum(oi.unit_price_snapshot * oi.quantity) as total_revenue
  from public.order_items oi
  where oi.business_id = p_business_id
    and oi.status <> 'VOID'
    and oi.created_at >= p_start
    and oi.created_at < p_end
  group by oi.product_name_snapshot
  order by total_quantity desc
  limit p_limit;
$$;

grant execute on function public.get_top_products(uuid, timestamptz, timestamptz, int) to authenticated;
