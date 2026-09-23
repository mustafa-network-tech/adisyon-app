import "server-only";
import { createSign } from "node:crypto";
import type { PlayConfig, ServiceAccountKey } from "./config";
import type { SubscriptionPurchaseV2 } from "./state";

// Minimal Google Play Developer API client: service-account OAuth (JWT
// bearer grant, signed with node:crypto) + the two calls we need.

const ANDROID_PUBLISHER_SCOPE = "https://www.googleapis.com/auth/androidpublisher";
const API_BASE = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications";

export class PlayApiError extends Error {
  constructor(
    message: string,
    readonly status: number
  ) {
    super(message);
  }
}

let cachedToken: { value: string; expiresAt: number; email: string } | null = null;

async function getAccessToken(serviceAccount: ServiceAccountKey): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.email === serviceAccount.client_email && cachedToken.expiresAt - 60 > now) {
    return cachedToken.value;
  }

  const tokenUri = serviceAccount.token_uri ?? "https://oauth2.googleapis.com/token";
  const header = Buffer.from(JSON.stringify({ alg: "RS256", typ: "JWT" })).toString("base64url");
  const claims = Buffer.from(
    JSON.stringify({
      iss: serviceAccount.client_email,
      scope: ANDROID_PUBLISHER_SCOPE,
      aud: tokenUri,
      iat: now,
      exp: now + 3600,
    })
  ).toString("base64url");
  const signer = createSign("RSA-SHA256");
  signer.update(`${header}.${claims}`);
  const signature = signer.sign(serviceAccount.private_key).toString("base64url");

  const response = await fetch(tokenUri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${header}.${claims}.${signature}`,
    }),
    cache: "no-store",
  });
  if (!response.ok) {
    throw new PlayApiError(`GOOGLE_OAUTH_FAILED: ${response.status}`, 502);
  }
  const body = (await response.json()) as { access_token: string; expires_in: number };
  cachedToken = { value: body.access_token, expiresAt: now + body.expires_in, email: serviceAccount.client_email };
  return body.access_token;
}

export async function getSubscriptionV2(config: PlayConfig, purchaseToken: string): Promise<SubscriptionPurchaseV2> {
  const token = await getAccessToken(config.serviceAccount);
  const url = `${API_BASE}/${encodeURIComponent(config.packageName)}/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;
  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
    cache: "no-store",
  });
  if (!response.ok) {
    // 400/404/410: the token is not a valid purchase for this package.
    throw new PlayApiError(`PLAY_GET_FAILED: ${response.status}`, response.status);
  }
  return (await response.json()) as SubscriptionPurchaseV2;
}

export async function acknowledgeSubscription(
  config: PlayConfig,
  productId: string,
  purchaseToken: string
): Promise<void> {
  const token = await getAccessToken(config.serviceAccount);
  const url = `${API_BASE}/${encodeURIComponent(config.packageName)}/purchases/subscriptions/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}:acknowledge`;
  const response = await fetch(url, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: "{}",
    cache: "no-store",
  });
  if (!response.ok) {
    throw new PlayApiError(`PLAY_ACK_FAILED: ${response.status}`, response.status);
  }
}
