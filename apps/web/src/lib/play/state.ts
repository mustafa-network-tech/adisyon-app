// Pure mapping from a Google Play Developer API `purchases.subscriptionsv2`
// response to the states stored in google_play_purchases. No imports so
// it can be unit-tested with `node --test` directly (see state.test.ts).

export type PurchaseState =
  | "PENDING"
  | "ACTIVE"
  | "GRACE_PERIOD"
  | "ON_HOLD"
  | "CANCELLED"
  | "EXPIRED"
  | "REVOKED";

export interface SubscriptionLineItem {
  productId?: string;
  expiryTime?: string;
  autoRenewingPlan?: { autoRenewEnabled?: boolean };
  offerDetails?: { basePlanId?: string; offerId?: string; offerTags?: string[] };
  // Present while the line item is in a given pricing phase; `freeTrial`
  // is set during a free-trial offer phase.
  offerPhase?: {
    freeTrial?: Record<string, unknown>;
    introductoryPrice?: Record<string, unknown>;
    basePrice?: Record<string, unknown>;
    prorationPeriod?: Record<string, unknown>;
  };
  latestSuccessfulOrderId?: string;
}

export interface SubscriptionPurchaseV2 {
  subscriptionState?: string;
  latestOrderId?: string;
  startTime?: string;
  linkedPurchaseToken?: string;
  acknowledgementState?: string;
  externalAccountIdentifiers?: { obfuscatedExternalAccountId?: string };
  testPurchase?: Record<string, unknown>;
  lineItems?: SubscriptionLineItem[];
}

export interface NormalizedSubscription {
  state: PurchaseState;
  productId: string;
  basePlanId: string | null;
  orderId: string | null;
  linkedPurchaseToken: string | null;
  startTime: string | null;
  expiryTime: string | null;
  autoRenewing: boolean;
  inFreeTrial: boolean;
  obfuscatedAccountId: string | null;
  needsAcknowledgement: boolean;
  isTestPurchase: boolean;
}

// RTDN SubscriptionNotification.notificationType values we act on.
export const RTDN_SUBSCRIPTION_REVOKED = 12;

const STATE_MAP: Record<string, PurchaseState> = {
  SUBSCRIPTION_STATE_PENDING: "PENDING",
  SUBSCRIPTION_STATE_ACTIVE: "ACTIVE",
  SUBSCRIPTION_STATE_IN_GRACE_PERIOD: "GRACE_PERIOD",
  SUBSCRIPTION_STATE_ON_HOLD: "ON_HOLD",
  // Pausing should be disabled in Play Console; if it happens anyway the
  // user has no entitlement while paused, same as account hold.
  SUBSCRIPTION_STATE_PAUSED: "ON_HOLD",
  SUBSCRIPTION_STATE_CANCELED: "CANCELLED",
  SUBSCRIPTION_STATE_EXPIRED: "EXPIRED",
  SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED: "EXPIRED",
};

export function mapSubscriptionState(state: string | undefined): PurchaseState | null {
  return (state && STATE_MAP[state]) || null;
}

export function normalizeSubscription(
  purchase: SubscriptionPurchaseV2,
  options: { revoked?: boolean } = {}
): NormalizedSubscription {
  const mapped = mapSubscriptionState(purchase.subscriptionState);
  if (!mapped) {
    throw new Error(`UNKNOWN_SUBSCRIPTION_STATE: ${purchase.subscriptionState ?? "missing"}`);
  }

  // One subscription per purchase in this app; if Play ever returns more
  // line items, the one that runs longest is the current entitlement.
  const lineItem = [...(purchase.lineItems ?? [])].sort(
    (a, b) => Date.parse(b.expiryTime ?? "") - Date.parse(a.expiryTime ?? "")
  )[0];
  if (!lineItem?.productId) {
    throw new Error("MISSING_LINE_ITEM");
  }

  const state: PurchaseState = options.revoked ? "REVOKED" : mapped;

  return {
    state,
    productId: lineItem.productId,
    basePlanId: lineItem.offerDetails?.basePlanId ?? null,
    orderId: purchase.latestOrderId ?? lineItem.latestSuccessfulOrderId ?? null,
    linkedPurchaseToken: purchase.linkedPurchaseToken ?? null,
    startTime: purchase.startTime ?? null,
    expiryTime: lineItem.expiryTime ?? null,
    autoRenewing: lineItem.autoRenewingPlan?.autoRenewEnabled ?? false,
    inFreeTrial: Boolean(lineItem.offerPhase?.freeTrial),
    obfuscatedAccountId: purchase.externalAccountIdentifiers?.obfuscatedExternalAccountId ?? null,
    needsAcknowledgement:
      purchase.acknowledgementState === "ACKNOWLEDGEMENT_STATE_PENDING" &&
      (state === "ACTIVE" || state === "GRACE_PERIOD" || state === "CANCELLED"),
    isTestPurchase: purchase.testPurchase !== undefined,
  };
}

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isUuid(value: string | null | undefined): value is string {
  return typeof value === "string" && UUID_PATTERN.test(value);
}
