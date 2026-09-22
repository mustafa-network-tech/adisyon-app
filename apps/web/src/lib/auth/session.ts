import "server-only";
import { createClient } from "@/lib/supabase/server";

export interface SessionContext {
  userId: string;
  email: string | null;
  isPlatformAdmin: boolean;
}

// Resolves who the current request's user is and whether they are a
// platform admin. Deliberately does NOT trust anything client-supplied --
// it re-derives everything from the session cookie + a fresh DB read,
// both of which are subject to RLS (platform_admins_select_self only
// ever lets a user see their own row, so this can't be spoofed to
// impersonate a different admin).
export async function getSessionContext(): Promise<SessionContext | null> {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return null;

  const { data: adminRow } = await supabase
    .from("platform_admins")
    .select("user_id")
    .eq("user_id", user.id)
    .maybeSingle();

  return {
    userId: user.id,
    email: user.email ?? null,
    isPlatformAdmin: Boolean(adminRow),
  };
}
