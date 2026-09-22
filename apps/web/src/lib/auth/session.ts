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

export interface BusinessAdminContext {
  userId: string;
  businessId: string;
  businessName: string;
}

// Resolves the business a BUSINESS_ADMIN manages. A user could in
// principle hold BUSINESS_ADMIN in more than one business (multi-tenant
// staff, section 5 of the architecture doc); for now we just take the
// first active one -- a business switcher is future work once that's a
// real scenario, not a guess worth building ahead of need.
export async function getBusinessAdminContext(): Promise<BusinessAdminContext | null> {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return null;

  const { data } = await supabase
    .from("business_memberships")
    .select("business_id, businesses(name)")
    .eq("user_id", user.id)
    .eq("role", "BUSINESS_ADMIN")
    .eq("active", true)
    .limit(1)
    .maybeSingle();

  if (!data) return null;

  return {
    userId: user.id,
    businessId: data.business_id,
    businessName: (data.businesses as { name: string } | null)?.name ?? "İşletme",
  };
}
