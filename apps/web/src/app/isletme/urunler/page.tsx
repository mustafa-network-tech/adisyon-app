import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getBusinessAdminContext } from "@/lib/auth/session";
import { ProductManager } from "./product-manager";

export default async function UrunlerPage() {
  const ctx = await getBusinessAdminContext();
  if (!ctx) redirect("/hesabim");

  const supabase = await createClient();

  const [{ data: categories }, { data: products }] = await Promise.all([
    supabase
      .from("categories")
      .select("id, name")
      .eq("business_id", ctx.businessId)
      .eq("active", true)
      .order("sort_order", { ascending: true }),
    supabase
      .from("products")
      .select("id, name, description, price, active, category_id, categories(name)")
      .eq("business_id", ctx.businessId)
      .order("created_at", { ascending: false }),
  ]);

  const productItems = (products ?? []).map((p) => ({
    id: p.id,
    name: p.name,
    description: p.description,
    price: p.price,
    active: p.active,
    category_id: p.category_id,
    category_name: (p.categories as { name: string } | null)?.name ?? "Kategorisiz",
  }));

  return (
    <div className="max-w-3xl">
      <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">Ürünler</h1>
      <p className="mt-1 text-sm text-zinc-600">Menünüzdeki ürünleri ve fiyatlarını yönetin.</p>

      <div className="mt-6">
        <ProductManager categories={categories ?? []} products={productItems} />
      </div>
    </div>
  );
}
