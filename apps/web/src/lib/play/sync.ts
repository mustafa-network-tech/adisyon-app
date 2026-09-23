import "server-only";
import { createAdminClient } from "@/lib/supabase/admin";
import type { PlayConfig } from "./config";
import { acknowledgeSubscription, getSubscriptionV2 } from "./google-api";
import { isUuid, normalizeSubscription, type PurchaseState } from "./state";

// The one place a Play purchase turns into database state. Always re-reads
// the purchase from Google -- the caller only supplies a token -- and
// writes through record_google_play_subscription (service role only),
// which resolves the plan from product/base plan and refuses a token
// that already belongs to another business.

export class PlaySyncError extends Error {
  constructor(
    readonly code:
      | "ACCOUNT_MISMATCH"
      | "UNLINKED_PURCHASE"
      | "UNKNOWN_PLAY_PRODUCT"
      | "TOKEN_OWNED_BY_OTHER_BUSINESS"
      | "DATABASE_ERROR",
    message?: string
  ) {
    super(message ?? code);
  }
}

export interface PlaySyncResult {
  businessId: string;
  purchaseState: PurchaseState;
  businessStatus: string | null;
  subscribedPlanCode: string | null;
  inFreeTrial: boolean;
}

export async function syncPlayPurchase(
  config: PlayConfig,
  params: { purchaseToken: string; expectedBusinessId?: string; revoked?: boolean }
): Promise<PlaySyncResult> {
  const purchase = await getSubscriptionV2(config, params.purchaseToken);
  const normalized = normalizeSubscription(purchase, { revoked: params.revoked });

  const admin = createAdminClient();
  const { data: existing } = await admin
    .from("google_play_purchases")
    .select("business_id")
    .eq("purchase_token", params.purchaseToken)
    .maybeSingle();

  // The app launches the billing flow with obfuscatedAccountId = business
  // id; Google returns it signed inside the purchase. A verify request
  // must match it exactly, so a token bought for business A can never be
  // presented by business B.
  let businessId: string | null;
  if (params.expectedBusinessId) {
    if (normalized.obfuscatedAccountId !== params.expectedBusinessId) {
      throw new PlaySyncError("ACCOUNT_MISMATCH");
    }
    if (existing && existing.business_id !== params.expectedBusinessId) {
      throw new PlaySyncError("TOKEN_OWNED_BY_OTHER_BUSINESS");
    }
    businessId = params.expectedBusinessId;
  } else {
    businessId = existing?.business_id ?? (isUuid(normalized.obfuscatedAccountId) ? normalized.obfuscatedAccountId : null);
  }
  if (!businessId) {
    throw new PlaySyncError("UNLINKED_PURCHASE");
  }

  const { data, error } = await admin.rpc("record_google_play_subscription", {
    p_business_id: businessId,
    p_product_id: normalized.productId,
    p_base_plan_id: normalized.basePlanId,
    p_purchase_token: params.purchaseToken,
    p_linked_purchase_token: normalized.linkedPurchaseToken,
    p_order_id: normalized.orderId,
    p_purchase_state: normalized.state,
    p_auto_renewing: normalized.autoRenewing,
    p_in_free_trial: normalized.inFreeTrial,
    p_start_time: normalized.startTime,
    p_expiry_time: normalized.expiryTime,
    // The full Google response is kept for audit/debugging; it is only
    // readable by platform admins (google_play_purchases RLS).
    p_raw_verification_response: purchase as unknown as Record<string, unknown>,
  });

  if (error) {
    if (error.message.includes("UNKNOWN_PLAY_PRODUCT")) throw new PlaySyncError("UNKNOWN_PLAY_PRODUCT");
    if (error.message.includes("PURCHASE_TOKEN_BELONGS_TO_OTHER_BUSINESS")) {
      throw new PlaySyncError("TOKEN_OWNED_BY_OTHER_BUSINESS");
    }
    throw new PlaySyncError("DATABASE_ERROR", error.message);
  }

  // Acknowledge only after the entitlement is stored. Google refunds
  // purchases that stay unacknowledged for 3 days; the reconcile job
  // retries if this call fails.
  if (normalized.needsAcknowledgement) {
    try {
      await acknowledgeSubscription(config, normalized.productId, params.purchaseToken);
    } catch (ackError) {
      console.error("Play acknowledge failed; reconcile will retry", ackError);
    }
  }

  const row = data?.[0];
  return {
    businessId,
    purchaseState: normalized.state,
    businessStatus: row?.business_status ?? null,
    subscribedPlanCode: row?.subscribed_plan_code ?? null,
    inFreeTrial: normalized.inFreeTrial,
  };
}
