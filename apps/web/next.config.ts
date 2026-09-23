import type { NextConfig } from "next";

// Baseline security headers for every route. A full Content-Security-Policy
// is deliberately not set here yet: Supabase realtime (wss://) and Next's
// inline bootstrap scripts need a nonce-based policy (see
// node_modules/next/dist/docs/01-app/02-guides/content-security-policy.md),
// which should be rolled out and tested separately. HSTS is added by Vercel.
const securityHeaders = [
  { key: "X-Frame-Options", value: "DENY" },
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=()" },
];

const nextConfig: NextConfig = {
  poweredByHeader: false,
  async headers() {
    return [{ source: "/:path*", headers: securityHeaders }];
  },
};

export default nextConfig;
