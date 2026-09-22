import "server-only";
import { createClient as createSupabaseClient } from "@supabase/supabase-js";
import type { Database } from "./database.types";

// Service-role client. Bypasses RLS entirely -- this is the ONLY place
// in the codebase the service role key may be used. `import "server-only"`
// makes any accidental client-component import a build error.
//
// Use this ONLY for operations that legitimately require elevated
// privilege and cannot be expressed as "the signed-in user acting within
// their own RLS-granted permissions", e.g. inviting a new staff member's
// auth user (src/app/isletme/personel/actions.ts). Business creation
// itself no longer needs this -- it's fully self-service via
// public.create_own_business (src/app/kayit), called by the signed-in
// owner's own session, no service role involved.
// Every other read/write should go through server.ts or client.ts so RLS
// stays the enforcement point.
export function createAdminClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceRoleKey) {
    throw new Error(
      "SUPABASE_SERVICE_ROLE_KEY / NEXT_PUBLIC_SUPABASE_URL is not configured on the server."
    );
  }

  return createSupabaseClient<Database>(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}
