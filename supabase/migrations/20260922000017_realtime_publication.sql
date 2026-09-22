-- Expose orders/order_items over Supabase Realtime for the waiter <->
-- kitchen live-update flow (section 16 of the architecture doc). RLS is
-- enforced on Realtime the same as on regular queries, so clients only
-- ever receive change events for businesses they belong to.
alter publication supabase_realtime add table public.orders;
alter publication supabase_realtime add table public.order_items;
