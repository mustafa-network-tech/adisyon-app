"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { getSessionContext } from "@/lib/auth/session";

// Note: a "use server" file may only export async functions, so the
// shared ReviewActionState type/initial value live in review-actions.tsx
// (the client component that calls these) instead of being exported here.
interface ReviewActionState {
  error: string | null;
}

export async function approveApplication(
  applicationId: string,
  _prevState: ReviewActionState,
  _formData: FormData
): Promise<ReviewActionState> {
  const ctx = await getSessionContext();
  if (!ctx?.isPlatformAdmin) {
    return { error: "Bu işlem için yetkiniz yok." };
  }

  const supabase = await createClient();

  const { data: application, error: fetchError } = await supabase
    .from("business_applications")
    .select("*")
    .eq("id", applicationId)
    .single();

  if (fetchError || !application) {
    return { error: "Başvuru bulunamadı." };
  }
  if (application.status !== "PENDING") {
    return { error: "Bu başvuru zaten değerlendirilmiş." };
  }

  const admin = createAdminClient();
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000";

  const { data: invited, error: inviteError } = await admin.auth.admin.inviteUserByEmail(
    application.email,
    {
      redirectTo: `${siteUrl}/auth/callback?next=/davet/sifre-olustur`,
      data: { full_name: application.contact_name, phone: application.phone },
    }
  );

  let newAdminUserId: string;

  if (inviteError || !invited?.user) {
    // Most common cause: this email already has an account (e.g. a
    // repeat applicant). Look the existing user up instead of failing
    // the whole approval -- they get added as BUSINESS_ADMIN on the new
    // business without a second invite email.
    const { data: existing } = await admin.auth.admin.listUsers();
    const existingUser = existing?.users.find(
      (u) => u.email?.toLowerCase() === application.email.toLowerCase()
    );
    if (!existingUser) {
      return {
        error: "Kullanıcı davet edilemedi. E-posta adresini kontrol edip tekrar deneyin.",
      };
    }
    newAdminUserId = existingUser.id;
  } else {
    newAdminUserId = invited.user.id;
  }

  const { data: business, error: businessError } = await supabase
    .from("businesses")
    .insert({
      name: application.business_name,
      business_type: application.business_type,
      city: application.city,
      address: application.address,
      phone: application.phone,
      email: application.email,
    })
    .select("id")
    .single();

  if (businessError || !business) {
    return { error: "İşletme oluşturulamadı. Lütfen tekrar deneyin." };
  }

  const { error: membershipError } = await supabase.from("business_memberships").insert({
    user_id: newAdminUserId,
    business_id: business.id,
    role: "BUSINESS_ADMIN",
  });

  if (membershipError) {
    return { error: "İşletme oluşturuldu ancak yönetici üyeliği eklenemedi." };
  }

  await supabase
    .from("business_applications")
    .update({
      status: "APPROVED",
      reviewed_by: ctx.userId,
      reviewed_at: new Date().toISOString(),
      resulting_business_id: business.id,
    })
    .eq("id", applicationId);

  await supabase.rpc("log_audit_event", {
    p_business_id: business.id,
    p_action: "BUSINESS_APPLICATION_APPROVED",
    p_entity: "business_applications",
    p_entity_id: applicationId,
    p_metadata: { business_name: application.business_name },
  });

  revalidatePath("/super-admin/basvurular");
  revalidatePath("/super-admin/isletmeler");
  revalidatePath(`/super-admin/basvurular/${applicationId}`);

  return { error: null };
}

export async function rejectApplication(
  applicationId: string,
  _prevState: ReviewActionState,
  formData: FormData
): Promise<ReviewActionState> {
  const ctx = await getSessionContext();
  if (!ctx?.isPlatformAdmin) {
    return { error: "Bu işlem için yetkiniz yok." };
  }

  const reason = String(formData.get("rejection_reason") ?? "").trim();
  const supabase = await createClient();

  const { data: application } = await supabase
    .from("business_applications")
    .select("id, status")
    .eq("id", applicationId)
    .single();

  if (!application) {
    return { error: "Başvuru bulunamadı." };
  }
  if (application.status !== "PENDING") {
    return { error: "Bu başvuru zaten değerlendirilmiş." };
  }

  const { error } = await supabase
    .from("business_applications")
    .update({
      status: "REJECTED",
      reviewed_by: ctx.userId,
      reviewed_at: new Date().toISOString(),
      rejection_reason: reason || null,
    })
    .eq("id", applicationId);

  if (error) {
    return { error: "Başvuru reddedilemedi. Lütfen tekrar deneyin." };
  }

  await supabase.rpc("log_audit_event", {
    p_business_id: null,
    p_action: "BUSINESS_APPLICATION_REJECTED",
    p_entity: "business_applications",
    p_entity_id: applicationId,
    p_metadata: { reason: reason || null },
  });

  revalidatePath("/super-admin/basvurular");
  revalidatePath(`/super-admin/basvurular/${applicationId}`);

  return { error: null };
}
