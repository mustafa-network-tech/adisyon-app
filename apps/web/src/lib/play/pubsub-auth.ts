import "server-only";
import { createPublicKey, verify, type JsonWebKey } from "node:crypto";

// Verifies the OIDC token Google Cloud Pub/Sub attaches to push requests
// (push subscription with authentication enabled). Without this anyone
// could POST a fake RTDN -- although every notification is re-verified
// against the Play API anyway, we don't let unauthenticated callers make
// us spend API quota.

const GOOGLE_CERTS_URL = "https://www.googleapis.com/oauth2/v3/certs";
const GOOGLE_ISSUERS = new Set(["https://accounts.google.com", "accounts.google.com"]);

let cachedKeys: { keys: (JsonWebKey & { kid?: string })[]; fetchedAt: number } | null = null;

async function getGoogleKeys(forceRefresh = false) {
  if (!forceRefresh && cachedKeys && Date.now() - cachedKeys.fetchedAt < 60 * 60 * 1000) {
    return cachedKeys.keys;
  }
  const response = await fetch(GOOGLE_CERTS_URL, { cache: "no-store" });
  if (!response.ok) throw new Error(`GOOGLE_CERTS_FAILED: ${response.status}`);
  const body = (await response.json()) as { keys: (JsonWebKey & { kid?: string })[] };
  cachedKeys = { keys: body.keys, fetchedAt: Date.now() };
  return body.keys;
}

export async function verifyPubSubToken(
  authorizationHeader: string | null,
  expected: { audience: string; serviceAccountEmail: string }
): Promise<boolean> {
  const match = authorizationHeader?.match(/^Bearer\s+(.+)$/i);
  if (!match) return false;
  const [encodedHeader, encodedPayload, encodedSignature] = match[1].split(".");
  if (!encodedHeader || !encodedPayload || !encodedSignature) return false;

  let header: { alg?: string; kid?: string };
  let payload: { iss?: string; aud?: string; exp?: number; email?: string; email_verified?: boolean };
  try {
    header = JSON.parse(Buffer.from(encodedHeader, "base64url").toString("utf8"));
    payload = JSON.parse(Buffer.from(encodedPayload, "base64url").toString("utf8"));
  } catch {
    return false;
  }
  if (header.alg !== "RS256" || !header.kid) return false;

  let jwk = (await getGoogleKeys()).find((key) => key.kid === header.kid);
  if (!jwk) jwk = (await getGoogleKeys(true)).find((key) => key.kid === header.kid);
  if (!jwk) return false;

  const signatureValid = verify(
    "RSA-SHA256",
    Buffer.from(`${encodedHeader}.${encodedPayload}`),
    createPublicKey({ key: jwk, format: "jwk" }),
    Buffer.from(encodedSignature, "base64url")
  );
  if (!signatureValid) return false;

  return (
    GOOGLE_ISSUERS.has(payload.iss ?? "") &&
    payload.aud === expected.audience &&
    typeof payload.exp === "number" &&
    payload.exp * 1000 > Date.now() &&
    payload.email === expected.serviceAccountEmail &&
    payload.email_verified === true
  );
}
