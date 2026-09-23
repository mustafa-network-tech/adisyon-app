"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getSessionContext } from "@/lib/auth/session";
import { APP_TRIAL_DAY_OPTIONS } from "./options";

interface SettingsActionState {
  error: string | null;
  success: boolean;
}

export async function updateSubscriptionSettings(
  _prevState: SettingsActionState,
  formData: FormData
): Promise<SettingsActionState> {
  const ctx = await getSessionContext();
  if (!ctx?.isPlatformAdmin) return { error: "Bu işlem için yetkiniz yok.", success: false };

  const days = Number.parseInt(String(formData.get("app_trial_days") ?? ""), 10);
  if (!APP_TRIAL_DAY_OPTIONS.includes(days)) {
    return { error: "Geçerli bir deneme süresi seçin.", success: false };
  }

  // RLS (subscription_settings_update_platform_admin) is the real gate;
  // the check above only gives a friendly message.
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("subscription_settings")
    .update({ app_trial_days: days })
    .eq("id", true)
    .select("app_trial_days");

  if (error || !data?.length) {
    return { error: "Ayar kaydedilemedi. Lütfen tekrar deneyin.", success: false };
  }

  revalidatePath("/super-admin/ayarlar");
  revalidatePath("/fiyatlandirma");
  revalidatePath("/kayit");
  return { error: null, success: true };
}
