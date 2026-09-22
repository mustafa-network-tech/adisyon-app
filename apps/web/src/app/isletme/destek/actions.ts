"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getBusinessAdminContext } from "@/lib/auth/session";
import type { SupportRequestType } from "@/lib/supabase/database.types";

interface ActionState {
  error: string | null;
}

const validTypes: SupportRequestType[] = ["TECHNICAL_SUPPORT", "FEATURE_REQUEST", "OTHER"];

export async function createSupportRequest(
  _prevState: ActionState,
  formData: FormData
): Promise<ActionState> {
  const ctx = await getBusinessAdminContext();
  if (!ctx) return { error: "Bu işlem için yetkiniz yok." };

  const type = String(formData.get("type") ?? "") as SupportRequestType;
  const subject = String(formData.get("subject") ?? "").trim();
  const description = String(formData.get("description") ?? "").trim();

  if (!validTypes.includes(type)) return { error: "Geçerli bir talep türü seçin." };
  if (!subject) return { error: "Konu boş olamaz." };
  if (!description) return { error: "Açıklama boş olamaz." };

  const supabase = await createClient();
  const { error } = await supabase.from("support_requests").insert({
    business_id: ctx.businessId,
    requester_id: ctx.userId,
    type,
    subject,
    description,
  });

  if (error) return { error: "Talep gönderilemedi. Lütfen tekrar deneyin." };

  revalidatePath("/isletme/destek");
  return { error: null };
}

export async function createCustomSoftwareRequest(
  _prevState: ActionState,
  formData: FormData
): Promise<ActionState> {
  const ctx = await getBusinessAdminContext();
  if (!ctx) return { error: "Bu işlem için yetkiniz yok." };

  const requesterName = String(formData.get("requester_name") ?? "").trim();
  const phone = String(formData.get("phone") ?? "").trim();
  const email = String(formData.get("email") ?? "").trim();
  const need = String(formData.get("need") ?? "").trim();
  const description = String(formData.get("description") ?? "").trim();
  const branchCountRaw = String(formData.get("branch_count") ?? "").trim();
  const branchCount = branchCountRaw ? Number.parseInt(branchCountRaw, 10) : null;

  if (!requesterName) return { error: "Yetkili adı boş olamaz." };
  if (!phone) return { error: "Telefon boş olamaz." };
  if (!email) return { error: "E-posta boş olamaz." };
  if (!need) return { error: "İhtiyaç açıklaması boş olamaz." };

  const supabase = await createClient();
  const { error } = await supabase.from("custom_software_requests").insert({
    business_id: ctx.businessId,
    requester_name: requesterName,
    phone,
    email,
    branch_count: Number.isFinite(branchCount) ? branchCount : null,
    need,
    description: description || null,
  });

  if (error) return { error: "Talep gönderilemedi. Lütfen tekrar deneyin." };

  revalidatePath("/isletme/destek");
  return { error: null };
}
