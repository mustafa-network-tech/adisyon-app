"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getBusinessAdminContext } from "@/lib/auth/session";

interface ProductActionState {
  error: string | null;
}

function isForeignKeyViolation(error: { code?: string } | null): boolean {
  return error?.code === "23503";
}

function parsePrice(raw: FormDataEntryValue | null): number | null {
  const value = Number.parseFloat(String(raw ?? "").replace(",", "."));
  if (!Number.isFinite(value) || value < 0) return null;
  return Math.round(value * 100) / 100;
}

export async function createProduct(
  _prevState: ProductActionState,
  formData: FormData
): Promise<ProductActionState> {
  const ctx = await getBusinessAdminContext();
  if (!ctx) return { error: "Bu işlem için yetkiniz yok." };

  const name = String(formData.get("name") ?? "").trim();
  const categoryId = String(formData.get("category_id") ?? "").trim();
  const description = String(formData.get("description") ?? "").trim();
  const price = parsePrice(formData.get("price"));

  if (!name) return { error: "Ürün adı boş olamaz." };
  if (price === null) return { error: "Geçerli bir fiyat girin." };

  const supabase = await createClient();
  const { error } = await supabase.from("products").insert({
    business_id: ctx.businessId,
    category_id: categoryId || null,
    name,
    description: description || null,
    price,
  });

  if (error) return { error: "Ürün eklenemedi. Lütfen tekrar deneyin." };

  revalidatePath("/isletme/urunler");
  return { error: null };
}

export async function updateProduct(
  id: string,
  _prevState: ProductActionState,
  formData: FormData
): Promise<ProductActionState> {
  const ctx = await getBusinessAdminContext();
  if (!ctx) return { error: "Bu işlem için yetkiniz yok." };

  const name = String(formData.get("name") ?? "").trim();
  const categoryId = String(formData.get("category_id") ?? "").trim();
  const description = String(formData.get("description") ?? "").trim();
  const price = parsePrice(formData.get("price"));

  if (!name) return { error: "Ürün adı boş olamaz." };
  if (price === null) return { error: "Geçerli bir fiyat girin." };

  const supabase = await createClient();
  const { error } = await supabase
    .from("products")
    .update({ name, category_id: categoryId || null, description: description || null, price })
    .eq("id", id)
    .eq("business_id", ctx.businessId);

  if (error) return { error: "Ürün güncellenemedi. Lütfen tekrar deneyin." };

  revalidatePath("/isletme/urunler");
  return { error: null };
}

export async function toggleProductActive(id: string, nextActive: boolean): Promise<void> {
  const ctx = await getBusinessAdminContext();
  if (!ctx) return;

  const supabase = await createClient();
  await supabase
    .from("products")
    .update({ active: nextActive })
    .eq("id", id)
    .eq("business_id", ctx.businessId);

  revalidatePath("/isletme/urunler");
}

export async function deleteProduct(
  id: string,
  _prevState: ProductActionState,
  _formData: FormData
): Promise<ProductActionState> {
  const ctx = await getBusinessAdminContext();
  if (!ctx) return { error: "Bu işlem için yetkiniz yok." };

  const supabase = await createClient();
  const { error } = await supabase
    .from("products")
    .delete()
    .eq("id", id)
    .eq("business_id", ctx.businessId);

  if (error) {
    if (isForeignKeyViolation(error)) {
      return {
        error: "Bu ürün silinemedi çünkü satış geçmişi var. Bunun yerine pasif hale getirin.",
      };
    }
    return { error: "Silinemedi. Lütfen tekrar deneyin." };
  }

  revalidatePath("/isletme/urunler");
  return { error: null };
}
