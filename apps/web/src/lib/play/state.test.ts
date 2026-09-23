// Run: npm run test (node --test with type stripping; no extra deps).
import { test } from "node:test";
import assert from "node:assert/strict";
import { isUuid, mapSubscriptionState, normalizeSubscription } from "./state.ts";

const base = {
  subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
  latestOrderId: "GPA.1234",
  startTime: "2026-10-01T10:00:00Z",
  acknowledgementState: "ACKNOWLEDGEMENT_STATE_PENDING",
  externalAccountIdentifiers: { obfuscatedExternalAccountId: "3f1c2b7e-0000-4000-8000-000000000001" },
  lineItems: [
    {
      productId: "standard",
      expiryTime: "2026-10-16T10:00:00Z",
      autoRenewingPlan: { autoRenewEnabled: true },
      offerDetails: { basePlanId: "monthly", offerId: "launch" },
      offerPhase: { freeTrial: {} },
    },
  ],
};

test("active free-trial purchase", () => {
  const n = normalizeSubscription(base);
  assert.equal(n.state, "ACTIVE");
  assert.equal(n.productId, "standard");
  assert.equal(n.basePlanId, "monthly");
  assert.equal(n.inFreeTrial, true);
  assert.equal(n.autoRenewing, true);
  assert.equal(n.needsAcknowledgement, true);
  assert.equal(n.obfuscatedAccountId, "3f1c2b7e-0000-4000-8000-000000000001");
});

test("paid phase is not a free trial", () => {
  const n = normalizeSubscription({
    ...base,
    acknowledgementState: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
    lineItems: [{ ...base.lineItems[0], offerPhase: { basePrice: {} } }],
  });
  assert.equal(n.inFreeTrial, false);
  assert.equal(n.needsAcknowledgement, false);
});

test("state mapping", () => {
  assert.equal(mapSubscriptionState("SUBSCRIPTION_STATE_IN_GRACE_PERIOD"), "GRACE_PERIOD");
  assert.equal(mapSubscriptionState("SUBSCRIPTION_STATE_ON_HOLD"), "ON_HOLD");
  assert.equal(mapSubscriptionState("SUBSCRIPTION_STATE_PAUSED"), "ON_HOLD");
  assert.equal(mapSubscriptionState("SUBSCRIPTION_STATE_CANCELED"), "CANCELLED");
  assert.equal(mapSubscriptionState("SUBSCRIPTION_STATE_EXPIRED"), "EXPIRED");
  assert.equal(mapSubscriptionState("SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED"), "EXPIRED");
  assert.equal(mapSubscriptionState("SOMETHING_NEW"), null);
});

test("revoked RTDN overrides the API state", () => {
  const n = normalizeSubscription({ ...base, subscriptionState: "SUBSCRIPTION_STATE_EXPIRED" }, { revoked: true });
  assert.equal(n.state, "REVOKED");
  assert.equal(n.needsAcknowledgement, false);
});

test("unknown state and missing line item are rejected", () => {
  assert.throws(() => normalizeSubscription({ ...base, subscriptionState: "X" }), /UNKNOWN_SUBSCRIPTION_STATE/);
  assert.throws(() => normalizeSubscription({ ...base, lineItems: [] }), /MISSING_LINE_ITEM/);
});

test("uuid check", () => {
  assert.equal(isUuid("3f1c2b7e-0000-4000-8000-000000000001"), true);
  assert.equal(isUuid("not-a-uuid"), false);
  assert.equal(isUuid(null), false);
});
