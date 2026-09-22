"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getSessionContext } from "@/lib/auth/session";

interface PlanActionState {
  error: string | null;
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

export async function createPlan(
  _prevState: PlanActionState,
  formData: FormData
): Promise<PlanActionState> {
  const ctx = await getSessionContext();
  if (!ctx?.isPlatformAdmin) return { error: "Bu işlem için yetkiniz yok." };

  const name = String(formData.get("name") ?? "").trim();
  if (!name) return { error: "Plan adı boş olamaz." };

  const supabase = await createClient();
  const { error } = await supabase.from("plans").insert({
    name,
    monthly_price: parseDecimal(formData.get("monthly_price")),
    yearly_price: parseDecimal(formData.get("yearly_price")),
    yearly_discount: parseDecimal(formData.get("yearly_discount")),
    max_tables: parseNullableInt(formData.get("max_tables")),
    max_waiters: parseNullableInt(formData.get("max_waiters")),
    max_users: parseNullableInt(formData.get("max_users")),
    max_areas: parseNullableInt(formData.get("max_areas")),
    max_branches: parseNullableInt(formData.get("max_branches")),
    qr_menu_enabled: formData.get("qr_menu_enabled") === "on",
    reporting_level: String(formData.get("reporting_level") ?? "BASIC").trim() || "BASIC",
  });

  if (error) return { error: "Plan oluşturulamadı. Lütfen tekrar deneyin." };

  revalidatePath("/super-admin/planlar");
  return { error: null };
}

export async function togglePlanActive(planId: string, nextActive: boolean): Promise<void> {
  const ctx = await getSessionContext();
  if (!ctx?.isPlatformAdmin) return;

  const supabase = await createClient();
  await supabase.from("plans").update({ active: nextActive }).eq("id", planId);

  revalidatePath("/super-admin/planlar");
}
