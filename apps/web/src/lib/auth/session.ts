import "server-only";
import { createClient } from "@/lib/supabase/server";
import type { MembershipRole } from "@/lib/supabase/database.types";

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

export interface MembershipContext {
  userId: string;
  businessId: string;
  businessName: string;
}

// Resolves the business a user holds one of the given roles in. A user
// could in principle hold the same role in more than one business
// (multi-tenant staff, section 5 of the architecture doc); for now we
// just take the first active match -- a business switcher is future
// work once that's a real scenario, not a guess worth building ahead of
// need.
async function getMembershipContext(
  roles: MembershipRole | MembershipRole[]
): Promise<MembershipContext | null> {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return null;

  const { data } = await supabase
    .from("business_memberships")
    .select("business_id, businesses(name)")
    .eq("user_id", user.id)
    .in("role", Array.isArray(roles) ? roles : [roles])
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

export type BusinessAdminContext = MembershipContext;
export function getBusinessAdminContext() {
  return getMembershipContext("BUSINESS_ADMIN");
}

// Kitchen Web: KITCHEN is the primary role, BUSINESS_ADMIN may also
// open the board (order_items_update already covers both roles).
export type KitchenContext = MembershipContext;
export function getKitchenContext() {
  return getMembershipContext(["KITCHEN", "BUSINESS_ADMIN"]);
}

export type CashierContext = MembershipContext;
export function getCashierContext() {
  return getMembershipContext("CASHIER");
}

// Reports (section 20 of the architecture doc) are available to both
// the business admin and cashier roles.
export type ReportsContext = MembershipContext;
export function getReportsContext() {
  return getMembershipContext(["BUSINESS_ADMIN", "CASHIER"]);
}

// PC Kasa/POS (production web routing, Faz 13): CASHIER is the primary
// role, but BUSINESS_ADMIN is also allowed to operate the till -- every
// orders/order_items/payments RLS write policy already includes
// BUSINESS_ADMIN alongside CASHIER (see 20260922000014_orders_items_payments.sql),
// so this only widens who can reach the UI, not what the database lets
// them do once there. WAITER and KITCHEN are deliberately excluded --
// their production surface is the Android app, not this screen.
export type KasaContext = MembershipContext;
export function getKasaContext() {
  return getMembershipContext(["CASHIER", "BUSINESS_ADMIN"]);
}
