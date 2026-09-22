import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getBusinessAdminContext } from "@/lib/auth/session";

export default async function IsletmeDashboardPage() {
  const ctx = await getBusinessAdminContext();
  if (!ctx) redirect("/hesabim");

  const supabase = await createClient();

  const [areas, tables, categories, products, staff] = await Promise.all([
    supabase
      .from("areas")
      .select("id", { count: "exact", head: true })
      .eq("business_id", ctx.businessId)
      .eq("active", true),
    supabase
      .from("restaurant_tables")
      .select("id", { count: "exact", head: true })
      .eq("business_id", ctx.businessId)
      .eq("active", true),
    supabase
      .from("categories")
      .select("id", { count: "exact", head: true })
      .eq("business_id", ctx.businessId)
      .eq("active", true),
    supabase
      .from("products")
      .select("id", { count: "exact", head: true })
      .eq("business_id", ctx.businessId)
      .eq("active", true),
    supabase
      .from("business_memberships")
      .select("id", { count: "exact", head: true })
      .eq("business_id", ctx.businessId)
      .eq("active", true),
  ]);

  const cards = [
    { label: "Alan", value: areas.count ?? 0, href: "/isletme/alanlar" },
    { label: "Masa", value: tables.count ?? 0, href: "/isletme/masalar" },
    { label: "Kategori", value: categories.count ?? 0, href: "/isletme/kategoriler" },
    { label: "Ürün", value: products.count ?? 0, href: "/isletme/urunler" },
    { label: "Personel", value: staff.count ?? 0, href: "/isletme/personel" },
  ];

  return (
    <div>
      <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">Genel Bakış</h1>
      <p className="mt-1 text-sm text-zinc-600">{ctx.businessName} — güncel durum.</p>

      <div className="mt-8 grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-5">
        {cards.map((card) => (
          <Link
            key={card.label}
            href={card.href}
            className="rounded-xl border border-zinc-200 bg-white p-5 shadow-sm transition-colors hover:border-zinc-300"
          >
            <p className="text-sm text-zinc-500">{card.label}</p>
            <p className="mt-2 text-3xl font-semibold tracking-tight text-zinc-900">
              {card.value}
            </p>
          </Link>
        ))}
      </div>
    </div>
  );
}
