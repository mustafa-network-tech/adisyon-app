"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getBusinessAdminContext } from "@/lib/auth/session";
import { friendlyWriteErrorMessage } from "@/lib/supabase/errors";

// Shared CRUD for the two entities that are structurally identical:
// areas and categories (business_id, name, sort_order, active). Tables
// and products have extra fields (area/category pickers, price) and get
// their own bespoke actions instead of being forced into this shape.
export type SimpleEntityTable = "areas" | "categories";

interface SimpleEntityState {
  error: string | null;
}

const paths: Record<SimpleEntityTable, string> = {
  areas: "/isletme/alanlar",
  categories: "/isletme/kategoriler",
};

function isForeignKeyViolation(error: { code?: string } | null): boolean {
  return error?.code === "23503";
}

export async function createSimpleEntity(
  table: SimpleEntityTable,
  _prevState: SimpleEntityState,
  formData: FormData
): Promise<SimpleEntityState> {
  const ctx = await getBusinessAdminContext();
  if (!ctx) return { error: "Bu işlem için yetkiniz yok." };

  const name = String(formData.get("name") ?? "").trim();
  if (!name) return { error: "İsim boş olamaz." };

  const supabase = await createClient();
  const { error } = await supabase.from(table).insert({
    business_id: ctx.businessId,
    name,
  });

  if (error) {
    return { error: friendlyWriteErrorMessage(error, "Eklenemedi. Lütfen tekrar deneyin.") };
  }

  revalidatePath(paths[table]);
  return { error: null };
}

export async function renameSimpleEntity(
  table: SimpleEntityTable,
  id: string,
  _prevState: SimpleEntityState,
  formData: FormData
): Promise<SimpleEntityState> {
  const ctx = await getBusinessAdminContext();
  if (!ctx) return { error: "Bu işlem için yetkiniz yok." };

  const name = String(formData.get("name") ?? "").trim();
  if (!name) return { error: "İsim boş olamaz." };

  const supabase = await createClient();
  const { error } = await supabase
    .from(table)
    .update({ name })
    .eq("id", id)
    .eq("business_id", ctx.businessId);

  if (error) return { error: "Güncellenemedi. Lütfen tekrar deneyin." };

  revalidatePath(paths[table]);
  return { error: null };
}

export async function toggleSimpleEntityActive(
  table: SimpleEntityTable,
  id: string,
  nextActive: boolean
): Promise<void> {
  const ctx = await getBusinessAdminContext();
  if (!ctx) return;

  const supabase = await createClient();
  await supabase
    .from(table)
    .update({ active: nextActive })
    .eq("id", id)
    .eq("business_id", ctx.businessId);

  revalidatePath(paths[table]);
}

export async function deleteSimpleEntity(
  table: SimpleEntityTable,
  id: string,
  _prevState: SimpleEntityState,
  _formData: FormData
): Promise<SimpleEntityState> {
  const ctx = await getBusinessAdminContext();
  if (!ctx) return { error: "Bu işlem için yetkiniz yok." };

  const supabase = await createClient();
  const { error } = await supabase
    .from(table)
    .delete()
    .eq("id", id)
    .eq("business_id", ctx.businessId);

  if (error) {
    if (isForeignKeyViolation(error)) {
      return {
        error:
          "Bu kayıt silinemedi çünkü ilişkili veriler var (ör. masa veya ürün). Bunun yerine pasif hale getirebilirsiniz.",
      };
    }
    return { error: "Silinemedi. Lütfen tekrar deneyin." };
  }

  revalidatePath(paths[table]);
  return { error: null };
}
