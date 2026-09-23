import { createAdminClient } from "@/lib/supabase/admin";
import { getPlayConfig } from "@/lib/play/config";
import { PlayApiError } from "@/lib/play/google-api";
import { PlaySyncError, syncPlayPurchase } from "@/lib/play/sync";

// POST /api/play/verify
// Called by the Android app right after a Google Play purchase.
// Authorization: Bearer <Supabase access token of the signed-in user>
// Body: { "purchaseToken": "..." }
//
// The client only supplies the token. Product, base plan, state, expiry,
// free-trial phase and the business it was bought for all come from the
// Google Play Developer API; the plan is resolved in the database.

export const runtime = "nodejs";

function json(status: number, body: Record<string, unknown>) {
  return Response.json(body, { status, headers: { "Cache-Control": "no-store" } });
}

export async function POST(request: Request) {
  const config = getPlayConfig();
  if (!config) return json(503, { error: "BILLING_NOT_CONFIGURED" });

  const accessToken = request.headers.get("authorization")?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!accessToken) return json(401, { error: "UNAUTHENTICATED" });

  let purchaseToken: unknown;
  try {
    ({ purchaseToken } = (await request.json()) as { purchaseToken?: unknown });
  } catch {
    return json(400, { error: "INVALID_BODY" });
  }
  if (typeof purchaseToken !== "string" || purchaseToken.length < 10 || purchaseToken.length > 2048) {
    return json(400, { error: "INVALID_PURCHASE_TOKEN" });
  }

  const admin = createAdminClient();
  const { data: userData, error: userError } = await admin.auth.getUser(accessToken);
  if (userError || !userData.user) return json(401, { error: "UNAUTHENTICATED" });

  // Only a business admin may attach a subscription to their business.
  const { data: membership } = await admin
    .from("business_memberships")
    .select("business_id")
    .eq("user_id", userData.user.id)
    .eq("role", "BUSINESS_ADMIN")
    .eq("active", true)
    .limit(1)
    .maybeSingle();
  if (!membership) return json(403, { error: "NOT_BUSINESS_ADMIN" });

  try {
    const result = await syncPlayPurchase(config, {
      purchaseToken,
      expectedBusinessId: membership.business_id,
    });
    return json(200, {
      purchaseState: result.purchaseState,
      subscriptionStatus: result.businessStatus,
      planCode: result.subscribedPlanCode,
      inFreeTrial: result.inFreeTrial,
    });
  } catch (error) {
    if (error instanceof PlaySyncError) {
      const status = error.code === "DATABASE_ERROR" ? 500 : 409;
      if (status === 500) console.error("Play verify database error", error);
      return json(status, { error: error.code });
    }
    if (error instanceof PlayApiError) {
      // 4xx from Google: not a valid purchase for this app.
      if (error.status >= 400 && error.status < 500) return json(400, { error: "INVALID_PURCHASE" });
      console.error("Play verify upstream error", error);
      return json(502, { error: "PLAY_UNAVAILABLE" });
    }
    console.error("Play verify failed", error);
    return json(500, { error: "VERIFY_FAILED" });
  }
}
