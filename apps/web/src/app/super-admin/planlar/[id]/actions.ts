"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getSessionContext } from "@/lib/auth/session";

interface PlanActionState {
  error: string | null;
  success: boolean;
}

function parseNullableInt(value: FormDataEntryValue | null): number | null {
  const raw = String(value ?? "").trim();
  if (!raw) return null;
  const parsed = Number.parseInt(raw, 10);
  return Number.isFinite(parsed) ? parsed : null;
}

function parseDecimal(value: FormDataEntryValue | null): number {
  const parsed = Number.parseFloat(String(value ?? "").replace(",", "."));
  return Number.isFinite(parsed) ? parsed : 0;
}

function parseNullableText(value: FormDataEntryValue | null): string | null {
  const raw = String(value ?? "").trim();
  return raw || null;
}

export async function updatePlan(
  planId: string,
  _prevState: PlanActionState,
  formData: FormData
): Promise<PlanActionState> {
  const ctx = await getSessionContext();
  if (!ctx?.isPlatformAdmin) return { error: "Bu işlem için yetkiniz yok.", success: false };

  const name = String(formData.get("name") ?? "").trim();
  if (!name) return { error: "Plan adı boş olamaz.", success: false };

  const supabase = await createClient();
  const { error } = await supabase
    .from("plans")
    .update({
      name,
      monthly_price: parseDecimal(formData.get("monthly_price")),
      yearly_discount: parseDecimal(formData.get("yearly_discount")),
      max_tables: parseNullableInt(formData.get("max_tables")),
      max_waiters: parseNullableInt(formData.get("max_waiters")),
      max_users: parseNullableInt(formData.get("max_users")),
      max_areas: parseNullableInt(formData.get("max_areas")),
      max_branches: parseNullableInt(formData.get("max_branches")),
      qr_menu_enabled: formData.get("qr_menu_enabled") === "on",
      reporting_level: String(formData.get("reporting_level") ?? "BASIC").trim() || "BASIC",
      google_play_product_id: parseNullableText(formData.get("google_play_product_id")),
      google_play_monthly_base_plan_id: parseNullableText(formData.get("google_play_monthly_base_plan_id")),
      google_play_yearly_base_plan_id: parseNullableText(formData.get("google_play_yearly_base_plan_id")),
    })
    .eq("id", planId);

  if (error) return { error: "Plan güncellenemedi. Lütfen tekrar deneyin.", success: false };

  revalidatePath(`/super-admin/planlar/${planId}`);
  revalidatePath("/super-admin/planlar");
  return { error: null, success: true };
}
