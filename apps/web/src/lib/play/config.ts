import "server-only";

// Google Play server configuration. Every value comes from server-only
// environment variables; nothing here may ever be NEXT_PUBLIC_. When the
// credentials aren't configured yet, getPlayConfig() returns null and the
// /api/play/* routes answer 503 instead of pretending a purchase worked.

export interface ServiceAccountKey {
  client_email: string;
  private_key: string;
  token_uri?: string;
}

export interface PlayConfig {
  packageName: string;
  serviceAccount: ServiceAccountKey;
  // Pub/Sub push authentication (RTDN). Both must be set for /api/play/rtdn.
  rtdnAudience: string | null;
  rtdnServiceAccountEmail: string | null;
}

function parseServiceAccount(raw: string): ServiceAccountKey | null {
  const text = raw.trim().startsWith("{") ? raw : Buffer.from(raw, "base64").toString("utf8");
  try {
    const parsed = JSON.parse(text) as Partial<ServiceAccountKey>;
    if (typeof parsed.client_email === "string" && typeof parsed.private_key === "string") {
      return {
        client_email: parsed.client_email,
        private_key: parsed.private_key,
        token_uri: parsed.token_uri,
      };
    }
  } catch {
    // fall through
  }
  return null;
}

export function getPlayConfig(): PlayConfig | null {
  const packageName = process.env.GOOGLE_PLAY_PACKAGE_NAME?.trim();
  const rawKey = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON;
  if (!packageName || !rawKey) return null;

  const serviceAccount = parseServiceAccount(rawKey);
  if (!serviceAccount) return null;

  return {
    packageName,
    serviceAccount,
    rtdnAudience: process.env.GOOGLE_PLAY_RTDN_AUDIENCE?.trim() || null,
    rtdnServiceAccountEmail: process.env.GOOGLE_PLAY_RTDN_SERVICE_ACCOUNT_EMAIL?.trim() || null,
  };
}
