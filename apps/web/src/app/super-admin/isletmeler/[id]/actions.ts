"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getSessionContext } from "@/lib/auth/session";

interface BusinessActionState {
  error: string | null;
}

export async function suspendBusiness(
  businessId: string,
  _prevState: BusinessActionState,
  _formData: FormData
): Promise<BusinessActionState> {
  const ctx = await getSessionContext();
  if (!ctx?.isPlatformAdmin) return { error: "Bu işlem için yetkiniz yok." };

  const supabase = await createClient();
  const { error } = await supabase
    .from("businesses")
    .update({ subscription_status: "SUSPENDED" })
    .eq("id", businessId);

  if (error) return { error: "İşletme askıya alınamadı." };

  await supabase.rpc("log_audit_event", {
    p_business_id: businessId,
    p_action: "BUSINESS_SUSPENDED",
    p_entity: "businesses",
    p_entity_id: businessId,
    p_metadata: {},
  });

  revalidatePath(`/super-admin/isletmeler/${businessId}`);
  revalidatePath("/super-admin/isletmeler");
  return { error: null };
}

export async function reactivateBusiness(
  businessId: string,
  _prevState: BusinessActionState,
  _formData: FormData
): Promise<BusinessActionState> {
  const ctx = await getSessionContext();
  if (!ctx?.isPlatformAdmin) return { error: "Bu işlem için yetkiniz yok." };

  const supabase = await createClient();
  const { error } = await supabase
    .from("businesses")
    .update({ subscription_status: "ACTIVE" })
    .eq("id", businessId);

  if (error) return { error: "İşletme tekrar aktif edilemedi." };

  await supabase.rpc("log_audit_event", {
    p_business_id: businessId,
    p_action: "BUSINESS_REACTIVATED",
    p_entity: "businesses",
    p_entity_id: businessId,
    p_metadata: {},
  });

  revalidatePath(`/super-admin/isletmeler/${businessId}`);
  revalidatePath("/super-admin/isletmeler");
  return { error: null };
}

export async function extendTrial(
  businessId: string,
  _prevState: BusinessActionState,
  formData: FormData
): Promise<BusinessActionState> {
  const ctx = await getSessionContext();
  if (!ctx?.isPlatformAdmin) return { error: "Bu işlem için yetkiniz yok." };

  const days = Number.parseInt(String(formData.get("days") ?? ""), 10);
  if (!Number.isFinite(days) || days <= 0) {
    return { error: "Geçerli bir gün sayısı girin." };
  }

  const supabase = await createClient();
  const { data: business } = await supabase
    .from("businesses")
    .select("trial_ends_at")
    .eq("id", businessId)
    .single();

  if (!business) return { error: "İşletme bulunamadı." };

  const base = new Date(business.trial_ends_at) > new Date() ? new Date(business.trial_ends_at) : new Date();
  base.setDate(base.getDate() + days);

  const { error } = await supabase
    .from("businesses")
    .update({ trial_ends_at: base.toISOString(), subscription_status: "TRIAL" })
    .eq("id", businessId);

  if (error) return { error: "Deneme süresi uzatılamadı." };

  await supabase.rpc("log_audit_event", {
    p_business_id: businessId,
    p_action: "BUSINESS_TRIAL_EXTENDED",
    p_entity: "businesses",
    p_entity_id: businessId,
    p_metadata: { days, new_trial_ends_at: base.toISOString() },
  });

  revalidatePath(`/super-admin/isletmeler/${businessId}`);
  revalidatePath("/super-admin/isletmeler");
  return { error: null };
}

export async function assignPlan(
  businessId: string,
  _prevState: BusinessActionState,
  formData: FormData
): Promise<BusinessActionState> {
  const ctx = await getSessionContext();
  if (!ctx?.isPlatformAdmin) return { error: "Bu işlem için yetkiniz yok." };

  const planId = String(formData.get("plan_id") ?? "").trim();

  const supabase = await createClient();
  const { error } = await supabase
    .from("businesses")
    .update({ plan_id: planId || null })
    .eq("id", businessId);

  if (error) return { error: "Plan atanamadı. Lütfen tekrar deneyin." };

  await supabase.rpc("log_audit_event", {
    p_business_id: businessId,
    p_action: "BUSINESS_PLAN_ASSIGNED",
    p_entity: "businesses",
    p_entity_id: businessId,
    p_metadata: { plan_id: planId || null },
  });

  revalidatePath(`/super-admin/isletmeler/${businessId}`);
  return { error: null };
}
