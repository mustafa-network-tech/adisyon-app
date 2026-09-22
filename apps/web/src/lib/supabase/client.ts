import { createBrowserClient } from "@supabase/ssr";
import type { Database } from "./database.types";

// Browser-side client: uses only the public anon key. Every query made
// through this client is subject to RLS as the signed-in user (or as
// `anon` when signed out) -- it never bypasses tenant isolation.
export function createClient() {
  return createBrowserClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}
