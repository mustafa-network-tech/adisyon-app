import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getBusinessAdminContext } from "@/lib/auth/session";
import { SimpleEntityManager } from "../_shared/simple-entity-manager";

export default async function KategorilerPage() {
  const ctx = await getBusinessAdminContext();
  if (!ctx) redirect("/hesabim");

  const supabase = await createClient();
  const { data: categories } = await supabase
    .from("categories")
    .select("id, name, active")
    .eq("business_id", ctx.businessId)
    .order("sort_order", { ascending: true })
    .order("created_at", { ascending: true });

  return (
    <div className="max-w-2xl">
      <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">Kategoriler</h1>
      <p className="mt-1 text-sm text-zinc-600">Menü kategorilerinizi yönetin.</p>

      <div className="mt-6">
        <SimpleEntityManager table="categories" entityLabel="Kategori" items={categories ?? []} />
      </div>
    </div>
  );
}
