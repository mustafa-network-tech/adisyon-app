import Link from "next/link";
import { createClient } from "@/lib/supabase/server";

async function getCounts() {
  const supabase = await createClient();

  const [pendingApplications, totalBusinesses, activeBusinesses, trialBusinesses] =
    await Promise.all([
      supabase
        .from("business_applications")
        .select("id", { count: "exact", head: true })
        .eq("status", "PENDING"),
      supabase.from("businesses").select("id", { count: "exact", head: true }),
      supabase
        .from("businesses")
        .select("id", { count: "exact", head: true })
        .eq("subscription_status", "ACTIVE"),
      supabase
        .from("businesses")
        .select("id", { count: "exact", head: true })
        .eq("subscription_status", "TRIAL"),
    ]);

  return {
    pendingApplications: pendingApplications.count ?? 0,
    totalBusinesses: totalBusinesses.count ?? 0,
    activeBusinesses: activeBusinesses.count ?? 0,
    trialBusinesses: trialBusinesses.count ?? 0,
  };
}

export default async function SuperAdminDashboardPage() {
  const counts = await getCounts();

  const cards = [
    {
      label: "Bekleyen Başvurular",
      value: counts.pendingApplications,
      href: "/super-admin/basvurular?status=PENDING",
    },
    { label: "Toplam İşletme", value: counts.totalBusinesses, href: "/super-admin/isletmeler" },
    {
      label: "Aktif Abonelik",
      value: counts.activeBusinesses,
      href: "/super-admin/isletmeler?status=ACTIVE",
    },
    {
      label: "Deneme Sürecinde",
      value: counts.trialBusinesses,
      href: "/super-admin/isletmeler?status=TRIAL",
    },
  ];

  return (
    <div>
      <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">Genel Bakış</h1>
      <p className="mt-1 text-sm text-zinc-600">Platformun güncel durumu.</p>

      <div className="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
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
