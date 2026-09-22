import "server-only";
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import type { Database } from "./database.types";

// Server-side client for Server Components / Server Actions / Route
// Handlers. Reads the caller's session from cookies, so every query
// still runs as that authenticated user and is still subject to RLS --
// this is NOT a privilege-escalation path, just SSR-safe session access.
export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            for (const { name, value, options } of cookiesToSet) {
              cookieStore.set(name, value, options);
            }
          } catch {
            // Called from a Server Component that can't set cookies
            // (e.g. during static rendering). Safe to ignore as long as
            // middleware.ts is refreshing the session on navigation.
          }
        },
      },
    }
  );
}
