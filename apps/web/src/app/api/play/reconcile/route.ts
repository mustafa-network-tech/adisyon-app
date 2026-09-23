import { timingSafeEqual } from "node:crypto";
import { createAdminClient } from "@/lib/supabase/admin";
import { getPlayConfig } from "@/lib/play/config";
import { syncPlayPurchase } from "@/lib/play/sync";

// GET /api/play/reconcile -- safety net for missed RTDN messages. Run
// daily by Vercel Cron (vercel.json), which sends
// "Authorization: Bearer $CRON_SECRET". Re-verifies every purchase that
// is still considered live and either expired or hasn't been verified in
// the last day, and retries acknowledgements that failed earlier.

export const runtime = "nodejs";
export const maxDuration = 60;

const BATCH_SIZE = 100;

function isAuthorizedCron(header: string | null): boolean {
  const secret = process.env.CRON_SECRET;
  if (!secret || !header) return false;
  const expected = Buffer.from(`Bearer ${secret}`);
  const actual = Buffer.from(header);
  return expected.length === actual.length && timingSafeEqual(expected, actual);
}

export async function GET(request: Request) {
  if (!isAuthorizedCron(request.headers.get("authorization"))) {
    return new Response("unauthorized", { status: 401 });
  }
  const config = getPlayConfig();
  if (!config) return Response.json({ skipped: "BILLING_NOT_CONFIGURED" }, { status: 503 });

  const now = new Date();
  const staleBefore = new Date(now.getTime() - 20 * 60 * 60 * 1000).toISOString();

  const admin = createAdminClient();
  const { data: purchases, error } = await admin
    .from("google_play_purchases")
    .select("purchase_token")
    .not("purchase_state", "in", "(EXPIRED,REVOKED)")
    .or(`expiry_time.lt.${now.toISOString()},last_verified_at.lt.${staleBefore},last_verified_at.is.null`)
    .order("last_verified_at", { ascending: true, nullsFirst: true })
    .limit(BATCH_SIZE);

  if (error) {
    console.error("Reconcile query failed", error);
    return Response.json({ error: "QUERY_FAILED" }, { status: 500 });
  }

  let synced = 0;
  let failed = 0;
  for (const { purchase_token } of purchases ?? []) {
    try {
      await syncPlayPurchase(config, { purchaseToken: purchase_token });
      synced += 1;
    } catch (syncError) {
      failed += 1;
      console.error("Reconcile sync failed", syncError);
    }
  }

  return Response.json({ checked: purchases?.length ?? 0, synced, failed });
}
