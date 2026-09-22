-- Faz 13 (production hardening): closes the idempotency gap flagged as
-- a pre-production blocker in docs/SECURITY_REVIEW.md ("İdempotency key
-- yok ... Üretime çıkmadan önce ele alınmalı"). A double-tap on "Ödeme
-- Al" in the PC Kasa UI, or a client retry after a dropped response
-- (network blip is the realistic case on restaurant wifi), could
-- previously insert two payments rows for what was really one payment --
-- silently overcharging the recorded total. There was no unique
-- constraint of any kind on payments besides its own generated id.
--
-- Fix: an optional client-supplied idempotency key, unique per order.
-- The client generates one UUID per "attempt" (kept stable across
-- retries of that same attempt) and includes it on insert; a genuine
-- duplicate submission then hits a unique-violation instead of creating
-- a second row, and the client treats that specific error as success
-- rather than a failure (see payment-panel.tsx). Nullable + partial
-- index so it's opt-in -- nothing else that writes to payments (there
-- is no other write path today) is forced to supply one.
alter table public.payments add column client_request_id uuid;

create unique index uq_payments_order_client_request
  on public.payments (order_id, client_request_id)
  where client_request_id is not null;
