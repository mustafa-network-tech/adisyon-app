"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getBusinessAdminContext } from "@/lib/auth/session";

interface TableActionState {
  error: string | null;
}

function isForeignKeyViolation(error: { code?: string } | null): boolean {
  return error?.code === "23503";
}

export async function createTable(
  _prevState: TableActionState,
  formData: FormData
): Promise<TableActionState> {
  const ctx = await getBusinessAdminContext();
  if (!ctx) return { error: "Bu işlem için yetkiniz yok." };

  const name = String(formData.get("name") ?? "").trim();
  const areaId = String(formData.get("area_id") ?? "").trim();
  if (!name) return { error: "Masa adı boş olamaz." };
  if (!areaId) return { error: "Lütfen bir alan seçin." };

  const supabase = await createClient();
  const { error } = await supabase.from("restaurant_tables").insert({
    business_id: ctx.businessId,
    area_id: areaId,
    name,
  });

  if (error) return { error: "Masa eklenemedi. Lütfen tekrar deneyin." };

  revalidatePath("/isletme/masalar");
  return { error: null };
}

export async function updateTable(
  id: string,
  _prevState: TableActionState,
  formData: FormData
): Promise<TableActionState> {
  const ctx = await getBusinessAdminContext();
  if (!ctx) return { error: "Bu işlem için yetkiniz yok." };

  const name = String(formData.get("name") ?? "").trim();
  const areaId = String(formData.get("area_id") ?? "").trim();
  if (!name) return { error: "Masa adı boş olamaz." };
  if (!areaId) return { error: "Lütfen bir alan seçin." };

  const supabase = await createClient();
  const { error } = await supabase
    .from("restaurant_tables")
    .update({ name, area_id: areaId })
    .eq("id", id)
    .eq("business_id", ctx.businessId);

  if (error) return { error: "Masa güncellenemedi. Lütfen tekrar deneyin." };

  revalidatePath("/isletme/masalar");
  return { error: null };
}

export async function toggleTableActive(id: string, nextActive: boolean): Promise<void> {
  const ctx = await getBusinessAdminContext();
  if (!ctx) return;

  const supabase = await createClient();
  await supabase
    .from("restaurant_tables")
    .update({ active: nextActive })
    .eq("id", id)
    .eq("business_id", ctx.businessId);

  revalidatePath("/isletme/masalar");
}

export async function deleteTable(
  id: string,
  _prevState: TableActionState,
  _formData: FormData
): Promise<TableActionState> {
  const ctx = await getBusinessAdminContext();
  if (!ctx) return { error: "Bu işlem için yetkiniz yok." };

  const supabase = await createClient();
  const { error } = await supabase
    .from("restaurant_tables")
    .delete()
    .eq("id", id)
    .eq("business_id", ctx.businessId);

  if (error) {
    if (isForeignKeyViolation(error)) {
      return {
        error: "Bu masa silinemedi çünkü sipariş geçmişi var. Bunun yerine pasif hale getirin.",
      };
    }
    return { error: "Silinemedi. Lütfen tekrar deneyin." };
  }

  revalidatePath("/isletme/masalar");
  return { error: null };
}
