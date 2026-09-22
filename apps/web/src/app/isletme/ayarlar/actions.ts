"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getBusinessAdminContext } from "@/lib/auth/session";

interface SettingsActionState {
  error: string | null;
  success: boolean;
}

// Deliberately only ever sends these profile-shaped fields. Even if it
// sent more, a DB trigger (20260922000018) rejects a non-platform-admin
// changing subscription_status/plan_id/trial dates/active -- this is
// just keeping the form honest about what it's allowed to do.
export async function updateBusinessProfile(
  _prevState: SettingsActionState,
  formData: FormData
): Promise<SettingsActionState> {
  const ctx = await getBusinessAdminContext();
  if (!ctx) return { error: "Bu işlem için yetkiniz yok.", success: false };

  const name = String(formData.get("name") ?? "").trim();
  if (!name) return { error: "İşletme adı boş olamaz.", success: false };

  const businessType = String(formData.get("business_type") ?? "").trim();
  const city = String(formData.get("city") ?? "").trim();
  const address = String(formData.get("address") ?? "").trim();
  const phone = String(formData.get("phone") ?? "").trim();
  const email = String(formData.get("email") ?? "").trim();
  const logoUrl = String(formData.get("logo_url") ?? "").trim();

  const supabase = await createClient();
  const { error } = await supabase
    .from("businesses")
    .update({
      name,
      business_type: businessType || null,
      city: city || null,
      address: address || null,
      phone: phone || null,
      email: email || null,
      logo_url: logoUrl || null,
    })
    .eq("id", ctx.businessId);

  if (error) return { error: "Kaydedilemedi. Lütfen tekrar deneyin.", success: false };

  revalidatePath("/isletme/ayarlar");
  revalidatePath("/isletme");
  return { error: null, success: true };
}
