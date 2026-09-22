import Link from "next/link";
import { createClient } from "@/lib/supabase/server";

async function getCounts() {
  const supabase = await createClient();

  const [
    pendingApplications,
    totalBusinesses,
    activeBusinesses,
    trialBusinesses,
    gracePeriodBusinesses,
    expiredBusinesses,
    suspendedBusinesses,
    totalUsers,
    plansWithBusinesses,
  ] = await Promise.all([
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
    supabase
      .from("businesses")
      .select("id", { count: "exact", head: true })
      .eq("subscription_status", "GRACE_PERIOD"),
    supabase
      .from("businesses")
      .select("id", { count: "exact", head: true })
      .eq("subscription_status", "EXPIRED"),
    supabase
      .from("businesses")
      .select("id", { count: "exact", head: true })
      .eq("subscription_status", "SUSPENDED"),
    supabase.from("profiles").select("id", { count: "exact", head: true }),
    supabase.from("businesses").select("plan_id, plans(name)"),
  ]);

  const planDistribution = new Map<string, number>();
  for (const row of plansWithBusinesses.data ?? []) {
    const planName = (row.plans as { name: string } | null)?.name ?? "Plan Atanmamış";
    planDistribution.set(planName, (planDistribution.get(planName) ?? 0) + 1);
  }

  return {
    pendingApplications: pendingApplications.count ?? 0,
    totalBusinesses: totalBusinesses.count ?? 0,
    activeBusinesses: activeBusinesses.count ?? 0,
    trialBusinesses: trialBusinesses.count ?? 0,
    gracePeriodBusinesses: gracePeriodBusinesses.count ?? 0,
    expiredBusinesses: expiredBusinesses.count ?? 0,
    suspendedBusinesses: suspendedBusinesses.count ?? 0,
    totalUsers: totalUsers.count ?? 0,
    planDistribution: Array.from(planDistribution.entries()).sort((a, b) => b[1] - a[1]),
  };
}

export default async function SuperAdminDashboardPage() {
  const counts = await getCounts();

  const cards = [
    { label: "Toplam İşletme", value: counts.totalBusinesses, href: "/super-admin/isletmeler" },
    { label: "Toplam Kullanıcı", value: counts.totalUsers, href: "/super-admin/isletmeler" },
    {
      label: "Deneme Sürecinde",
      value: counts.trialBusinesses,
      href: "/super-admin/isletmeler?status=TRIAL",
    },
    {
      label: "Aktif Abonelik",
      value: counts.activeBusinesses,
      href: "/super-admin/isletmeler?status=ACTIVE",
    },
    {
      label: "Ödeme Bekliyor (Grace)",
      value: counts.gracePeriodBusinesses,
      href: "/super-admin/isletmeler?status=GRACE_PERIOD",
    },
    {
      label: "Süresi Dolmuş",
      value: counts.expiredBusinesses,
      href: "/super-admin/isletmeler?status=EXPIRED",
    },
    {
      label: "Askıya Alınmış",
      value: counts.suspendedBusinesses,
      href: "/super-admin/isletmeler?status=SUSPENDED",
    },
    {
      label: "Bekleyen Başvurular (Arşiv)",
      value: counts.pendingApplications,
      href: "/super-admin/basvurular?status=PENDING",
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

      <div className="mt-8 rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
        <h2 className="text-sm font-semibold text-zinc-900">Plana Göre İşletme Dağılımı</h2>
        {counts.planDistribution.length === 0 ? (
          <p className="mt-3 text-sm text-zinc-500">Henüz işletme yok.</p>
        ) : (
          <ul className="mt-3 divide-y divide-zinc-100">
            {counts.planDistribution.map(([planName, count]) => (
              <li key={planName} className="flex items-center justify-between py-2.5 text-sm">
                <span className="text-zinc-900">{planName}</span>
                <span className="font-medium text-zinc-600">{count}</span>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
