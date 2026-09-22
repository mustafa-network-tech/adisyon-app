"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { getBusinessAdminContext } from "@/lib/auth/session";
import { friendlyWriteErrorMessage } from "@/lib/supabase/errors";
import type { MembershipRole } from "@/lib/supabase/database.types";

interface StaffActionState {
  error: string | null;
}

const validRoles: MembershipRole[] = ["BUSINESS_ADMIN", "CASHIER", "WAITER", "KITCHEN"];

export async function inviteStaff(
  _prevState: StaffActionState,
  formData: FormData
): Promise<StaffActionState> {
  const ctx = await getBusinessAdminContext();
  if (!ctx) return { error: "Bu işlem için yetkiniz yok." };

  const email = String(formData.get("email") ?? "").trim();
  const fullName = String(formData.get("full_name") ?? "").trim();
  const role = String(formData.get("role") ?? "") as MembershipRole;

  if (!email) return { error: "E-posta boş olamaz." };
  if (!validRoles.includes(role)) return { error: "Geçerli bir rol seçin." };

  const admin = createAdminClient();
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000";

  const { data: invited, error: inviteError } = await admin.auth.admin.inviteUserByEmail(email, {
    redirectTo: `${siteUrl}/auth/callback?next=/davet/sifre-olustur`,
    data: fullName ? { full_name: fullName } : undefined,
  });

  let newUserId: string;

  if (inviteError || !invited?.user) {
    const { data: existing } = await admin.auth.admin.listUsers();
    const existingUser = existing?.users.find((u) => u.email?.toLowerCase() === email.toLowerCase());
    if (!existingUser) {
      return { error: "Kullanıcı davet edilemedi. E-posta adresini kontrol edip tekrar deneyin." };
    }
    newUserId = existingUser.id;
  } else {
    newUserId = invited.user.id;
  }

  const supabase = await createClient();
  const { error: membershipError } = await supabase.from("business_memberships").insert({
    user_id: newUserId,
    business_id: ctx.businessId,
    role,
  });

  if (membershipError) {
    if (membershipError.code === "23505") {
      return { error: "Bu kullanıcı zaten işletmenizin personeli." };
    }
    return {
      error: friendlyWriteErrorMessage(membershipError, "Personel eklenemedi. Lütfen tekrar deneyin."),
    };
  }

  await supabase.rpc("log_audit_event", {
    p_business_id: ctx.businessId,
    p_action: "STAFF_INVITED",
    p_entity: "business_memberships",
    p_entity_id: newUserId,
    p_metadata: { email, role },
  });

  revalidatePath("/isletme/personel");
  return { error: null };
}

export async function updateStaffRole(
  membershipId: string,
  targetUserId: string,
  _prevState: StaffActionState,
  formData: FormData
): Promise<StaffActionState> {
  const ctx = await getBusinessAdminContext();
  if (!ctx) return { error: "Bu işlem için yetkiniz yok." };
  if (targetUserId === ctx.userId) {
    return { error: "Kendi rolünüzü buradan değiştiremezsiniz." };
  }

  const role = String(formData.get("role") ?? "") as MembershipRole;
  if (!validRoles.includes(role)) return { error: "Geçerli bir rol seçin." };

  const supabase = await createClient();
  const { error } = await supabase
    .from("business_memberships")
    .update({ role })
    .eq("id", membershipId)
    .eq("business_id", ctx.businessId);

  if (error) return { error: "Rol güncellenemedi. Lütfen tekrar deneyin." };

  await supabase.rpc("log_audit_event", {
    p_business_id: ctx.businessId,
    p_action: "STAFF_ROLE_CHANGED",
    p_entity: "business_memberships",
    p_entity_id: membershipId,
    p_metadata: { role },
  });

  revalidatePath("/isletme/personel");
  return { error: null };
}

export async function toggleStaffActive(
  membershipId: string,
  targetUserId: string,
  nextActive: boolean
): Promise<{ error: string | null }> {
  const ctx = await getBusinessAdminContext();
  if (!ctx) return { error: "Bu işlem için yetkiniz yok." };
  if (targetUserId === ctx.userId) {
    return { error: "Kendi üyeliğinizi buradan pasif hale getiremezsiniz." };
  }

  const supabase = await createClient();
  const { error } = await supabase
    .from("business_memberships")
    .update({ active: nextActive })
    .eq("id", membershipId)
    .eq("business_id", ctx.businessId);

  if (error) return { error: "Güncellenemedi. Lütfen tekrar deneyin." };

  await supabase.rpc("log_audit_event", {
    p_business_id: ctx.businessId,
    p_action: nextActive ? "STAFF_REACTIVATED" : "STAFF_DEACTIVATED",
    p_entity: "business_memberships",
    p_entity_id: membershipId,
    p_metadata: {},
  });

  revalidatePath("/isletme/personel");
  return { error: null };
}
