import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import type { SubscriptionStatus } from "@/lib/supabase/database.types";

const statusTabs: { value: SubscriptionStatus | "ALL"; label: string }[] = [
  { value: "ALL", label: "Tümü" },
  { value: "TRIAL", label: "Deneme" },
  { value: "ACTIVE", label: "Aktif" },
  { value: "GRACE_PERIOD", label: "Ödeme Bekliyor" },
  { value: "SUSPENDED", label: "Askıda" },
  { value: "EXPIRED", label: "Süresi Doldu" },
  { value: "CANCELLED", label: "İptal" },
];

const statusLabels: Record<SubscriptionStatus, string> = {
  TRIAL: "Deneme",
  ACTIVE: "Aktif",
  GRACE_PERIOD: "Ödeme Bekliyor",
  EXPIRED: "Süresi Doldu",
  SUSPENDED: "Askıda",
  CANCELLED: "İptal",
};

const statusBadgeClass: Record<SubscriptionStatus, string> = {
  TRIAL: "bg-blue-50 text-blue-700 border-blue-200",
  ACTIVE: "bg-emerald-50 text-emerald-700 border-emerald-200",
  GRACE_PERIOD: "bg-amber-50 text-amber-700 border-amber-200",
  EXPIRED: "bg-zinc-100 text-zinc-600 border-zinc-200",
  SUSPENDED: "bg-red-50 text-red-700 border-red-200",
  CANCELLED: "bg-zinc-100 text-zinc-600 border-zinc-200",
};

export default async function IsletmelerPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const { status } = await searchParams;
  const activeStatus: SubscriptionStatus | "ALL" =
    status === "TRIAL" ||
    status === "ACTIVE" ||
    status === "GRACE_PERIOD" ||
    status === "SUSPENDED" ||
    status === "EXPIRED" ||
    status === "CANCELLED"
      ? status
      : "ALL";

  const supabase = await createClient();
  let query = supabase
    .from("businesses")
    .select("id, name, city, subscription_status, active, trial_ends_at, created_at")
    .order("created_at", { ascending: false });

  if (activeStatus !== "ALL") {
    query = query.eq("subscription_status", activeStatus);
  }

  const { data: businesses } = await query;

  const businessIds = (businesses ?? []).map((b) => b.id);
  const { data: membershipCounts } = businessIds.length
    ? await supabase.from("business_memberships").select("business_id").in("business_id", businessIds).eq("active", true)
    : { data: [] as { business_id: string }[] };

  const userCountByBusiness = new Map<string, number>();
  for (const row of membershipCounts ?? []) {
    userCountByBusiness.set(row.business_id, (userCountByBusiness.get(row.business_id) ?? 0) + 1);
  }

  return (
    <div>
      <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">İşletmeler</h1>
      <p className="mt-1 text-sm text-zinc-600">Platformdaki tüm işletmeler.</p>

      <div className="mt-6 flex flex-wrap gap-1 border-b border-zinc-200">
        {statusTabs.map((tab) => (
          <Link
            key={tab.value}
            href={tab.value === "ALL" ? "/super-admin/isletmeler" : `/super-admin/isletmeler?status=${tab.value}`}
            className={`border-b-2 px-3 py-2 text-sm font-medium ${
              activeStatus === tab.value
                ? "border-zinc-900 text-zinc-900"
                : "border-transparent text-zinc-500 hover:text-zinc-800"
            }`}
          >
            {tab.label}
          </Link>
        ))}
      </div>

      <div className="mt-6 overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-sm">
        {!businesses || businesses.length === 0 ? (
          <p className="px-5 py-10 text-center text-sm text-zinc-500">Kayıt bulunamadı.</p>
        ) : (
          <table className="w-full text-left text-sm">
            <thead className="border-b border-zinc-200 bg-zinc-50 text-xs uppercase tracking-wide text-zinc-500">
              <tr>
                <th className="px-5 py-3 font-medium">İşletme</th>
                <th className="px-5 py-3 font-medium">Şehir</th>
                <th className="px-5 py-3 font-medium">Durum</th>
                <th className="px-5 py-3 font-medium">Kullanıcı</th>
                <th className="px-5 py-3 font-medium">Deneme Bitiş</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-100">
              {businesses.map((biz) => (
                <tr key={biz.id} className="hover:bg-zinc-50">
                  <td className="px-5 py-3">
                    <Link
                      href={`/super-admin/isletmeler/${biz.id}`}
                      className="font-medium text-zinc-900 hover:underline"
                    >
                      {biz.name}
                    </Link>
                    {!biz.active && (
                      <span className="ml-2 text-xs font-medium text-red-600">(pasif)</span>
                    )}
                  </td>
                  <td className="px-5 py-3 text-zinc-600">{biz.city ?? "—"}</td>
                  <td className="px-5 py-3">
                    <span
                      className={`inline-flex rounded-full border px-2.5 py-0.5 text-xs font-medium ${statusBadgeClass[biz.subscription_status]}`}
                    >
                      {statusLabels[biz.subscription_status]}
                    </span>
                  </td>
                  <td className="px-5 py-3 text-zinc-600">
                    {userCountByBusiness.get(biz.id) ?? 0}
                  </td>
                  <td className="px-5 py-3 text-zinc-500">
                    {biz.subscription_status === "TRIAL"
                      ? new Date(biz.trial_ends_at).toLocaleDateString("tr-TR")
                      : "—"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
