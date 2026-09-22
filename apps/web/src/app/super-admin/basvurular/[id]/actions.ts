"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getSessionContext } from "@/lib/auth/session";

// Note: a "use server" file may only export async functions, so the
// shared ReviewActionState type/initial value live in review-actions.tsx
// (the client component that calls these) instead of being exported here.
interface ReviewActionState {
  error: string | null;
}

// approveApplication was removed in Faz 12: businesses are no longer
// opened via Super Admin approval -- the master prompt now requires a
// fully self-service model (a user creates their own account and
// business via /kayit, which starts an automatic 7-day trial through
// public.create_own_business). This form/table stays only as a
// read-only historical archive; rejectApplication survives purely to
// let a platform admin close out any legacy PENDING rows gracefully
// (it creates nothing, just marks a status).
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
      rejection_reason: reason || null,
    })
    .eq("id", applicationId);

  if (error) {
    return { error: "Başvuru reddedilemedi. Lütfen tekrar deneyin." };
  }

  // reviewed_by/reviewed_at are forced server-side (auth.uid()/now()) and
  // the audit entry (BUSINESS_APPLICATION_REJECTED) is written
  // automatically by a DB trigger on this same update -- see
  // 20260922000027_audit_rpc_hardening.sql.

  revalidatePath("/super-admin/basvurular");
  revalidatePath(`/super-admin/basvurular/${applicationId}`);

  return { error: null };
}
