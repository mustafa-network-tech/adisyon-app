import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getBusinessAdminContext } from "@/lib/auth/session";
import { TableManager } from "./table-manager";

export default async function MasalarPage() {
  const ctx = await getBusinessAdminContext();
  if (!ctx) redirect("/hesabim");

  const supabase = await createClient();

  const [{ data: areas }, { data: tables }] = await Promise.all([
    supabase
      .from("areas")
      .select("id, name")
      .eq("business_id", ctx.businessId)
      .eq("active", true)
      .order("sort_order", { ascending: true }),
    supabase
      .from("restaurant_tables")
      .select("id, name, active, status, area_id, areas(name)")
      .eq("business_id", ctx.businessId)
      .order("sort_order", { ascending: true })
      .order("created_at", { ascending: true }),
  ]);

  const tableItems = (tables ?? []).map((t) => ({
    id: t.id,
    name: t.name,
    active: t.active,
    status: t.status,
    area_id: t.area_id,
    area_name: (t.areas as { name: string } | null)?.name ?? "—",
  }));

  return (
    <div className="max-w-3xl">
      <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">Masalar</h1>
      <p className="mt-1 text-sm text-zinc-600">Masalarınızı ve bağlı oldukları alanları yönetin.</p>

      <div className="mt-6">
        <TableManager areas={areas ?? []} tables={tableItems} />
      </div>
    </div>
  );
}
