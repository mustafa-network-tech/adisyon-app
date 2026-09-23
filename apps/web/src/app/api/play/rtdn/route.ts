import { getPlayConfig } from "@/lib/play/config";
import { PlayApiError } from "@/lib/play/google-api";
import { verifyPubSubToken } from "@/lib/play/pubsub-auth";
import { RTDN_SUBSCRIPTION_REVOKED } from "@/lib/play/state";
import { PlaySyncError, syncPlayPurchase } from "@/lib/play/sync";

// POST /api/play/rtdn -- Google Play Real-time Developer Notifications,
// delivered by a Pub/Sub push subscription with OIDC authentication.
//
// The notification is only a hint: every subscription notification is
// re-read from the Play Developer API before anything is written.
// Response codes drive Pub/Sub retries: 2xx = done (or intentionally
// ignored), 5xx = retry later.

export const runtime = "nodejs";

interface RtdnPayload {
  packageName?: string;
  subscriptionNotification?: { notificationType?: number; purchaseToken?: string; subscriptionId?: string };
  testNotification?: unknown;
}

export async function POST(request: Request) {
  const config = getPlayConfig();
  if (!config || !config.rtdnAudience || !config.rtdnServiceAccountEmail) {
    return new Response("billing not configured", { status: 503 });
  }

  const authorized = await verifyPubSubToken(request.headers.get("authorization"), {
    audience: config.rtdnAudience,
    serviceAccountEmail: config.rtdnServiceAccountEmail,
  });
  if (!authorized) return new Response("unauthorized", { status: 401 });

  let payload: RtdnPayload;
  try {
    const body = (await request.json()) as { message?: { data?: string } };
    payload = JSON.parse(Buffer.from(body.message?.data ?? "", "base64").toString("utf8")) as RtdnPayload;
  } catch {
    // Malformed message: acknowledge so Pub/Sub doesn't retry forever.
    return new Response("ignored: malformed", { status: 200 });
  }

  if (payload.packageName !== config.packageName) {
    return new Response("ignored: other package", { status: 200 });
  }
  if (payload.testNotification) {
    return new Response("ok: test notification", { status: 200 });
  }

  const notification = payload.subscriptionNotification;
  if (!notification?.purchaseToken) {
    // One-time products / voided purchases aren't used by this app.
    return new Response("ignored: not a subscription notification", { status: 200 });
  }

  try {
    await syncPlayPurchase(config, {
      purchaseToken: notification.purchaseToken,
      revoked: notification.notificationType === RTDN_SUBSCRIPTION_REVOKED,
    });
    return new Response("ok", { status: 200 });
  } catch (error) {
    if (error instanceof PlaySyncError && error.code !== "DATABASE_ERROR") {
      // Permanent: e.g. a purchase not made through this app's flow.
      console.warn("RTDN ignored", error.code);
      return new Response(`ignored: ${error.code}`, { status: 200 });
    }
    if (error instanceof PlayApiError && error.status >= 400 && error.status < 500 && error.status !== 429) {
      console.warn("RTDN token rejected by Play", error.status);
      return new Response("ignored: invalid token", { status: 200 });
    }
    console.error("RTDN processing failed; Pub/Sub will retry", error);
    return new Response("retry", { status: 500 });
  }
}
