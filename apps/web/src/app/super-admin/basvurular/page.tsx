import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import type { ApplicationStatus } from "@/lib/supabase/database.types";

const statusTabs: { value: ApplicationStatus | "ALL"; label: string }[] = [
  { value: "PENDING", label: "Bekleyen" },
  { value: "APPROVED", label: "Onaylanan" },
  { value: "REJECTED", label: "Reddedilen" },
  { value: "ALL", label: "Tümü" },
];

const statusLabels: Record<ApplicationStatus, string> = {
  PENDING: "Bekliyor",
  APPROVED: "Onaylandı",
  REJECTED: "Reddedildi",
};

const statusBadgeClass: Record<ApplicationStatus, string> = {
  PENDING: "bg-amber-50 text-amber-700 border-amber-200",
  APPROVED: "bg-emerald-50 text-emerald-700 border-emerald-200",
  REJECTED: "bg-red-50 text-red-700 border-red-200",
};

export default async function BasvurularPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const { status } = await searchParams;
  const activeStatus: ApplicationStatus | "ALL" =
    status === "APPROVED" || status === "REJECTED" || status === "ALL" ? status : "PENDING";

  const supabase = await createClient();
  let query = supabase
    .from("business_applications")
    .select("id, business_name, contact_name, city, status, created_at")
    .order("created_at", { ascending: false });

  if (activeStatus !== "ALL") {
    query = query.eq("status", activeStatus);
  }

  const { data: applications } = await query;

  return (
    <div>
      <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">Başvurular</h1>
      <p className="mt-1 text-sm text-zinc-600">İşletme başvurularını inceleyin ve onaylayın.</p>

      <div className="mt-6 flex gap-1 border-b border-zinc-200">
        {statusTabs.map((tab) => (
          <Link
            key={tab.value}
            href={tab.value === "PENDING" ? "/super-admin/basvurular" : `/super-admin/basvurular?status=${tab.value}`}
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
        {!applications || applications.length === 0 ? (
          <p className="px-5 py-10 text-center text-sm text-zinc-500">Kayıt bulunamadı.</p>
        ) : (
          <table className="w-full text-left text-sm">
            <thead className="border-b border-zinc-200 bg-zinc-50 text-xs uppercase tracking-wide text-zinc-500">
              <tr>
                <th className="px-5 py-3 font-medium">İşletme</th>
                <th className="px-5 py-3 font-medium">Yetkili</th>
                <th className="px-5 py-3 font-medium">Şehir</th>
                <th className="px-5 py-3 font-medium">Durum</th>
                <th className="px-5 py-3 font-medium">Tarih</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-100">
              {applications.map((app) => (
                <tr key={app.id} className="hover:bg-zinc-50">
                  <td className="px-5 py-3">
                    <Link
                      href={`/super-admin/basvurular/${app.id}`}
                      className="font-medium text-zinc-900 hover:underline"
                    >
                      {app.business_name}
                    </Link>
                  </td>
                  <td className="px-5 py-3 text-zinc-600">{app.contact_name}</td>
                  <td className="px-5 py-3 text-zinc-600">{app.city ?? "—"}</td>
                  <td className="px-5 py-3">
                    <span
                      className={`inline-flex rounded-full border px-2.5 py-0.5 text-xs font-medium ${statusBadgeClass[app.status]}`}
                    >
                      {statusLabels[app.status]}
                    </span>
                  </td>
                  <td className="px-5 py-3 text-zinc-500">
                    {new Date(app.created_at).toLocaleDateString("tr-TR")}
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
