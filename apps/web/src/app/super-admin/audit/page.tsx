import { createClient } from "@/lib/supabase/server";

const actionLabels: Record<string, string> = {
  BUSINESS_APPLICATION_APPROVED: "Başvuru Onaylandı",
  BUSINESS_APPLICATION_REJECTED: "Başvuru Reddedildi",
  BUSINESS_SUSPENDED: "İşletme Askıya Alındı",
  BUSINESS_REACTIVATED: "İşletme Tekrar Aktif Edildi",
  BUSINESS_TRIAL_EXTENDED: "Deneme Süresi Uzatıldı",
  BUSINESS_PLAN_ASSIGNED: "Plan Atandı",
  STAFF_INVITED: "Personel Davet Edildi",
  STAFF_ROLE_CHANGED: "Personel Rolü Değiştirildi",
  STAFF_REACTIVATED: "Personel Tekrar Aktif Edildi",
  STAFF_DEACTIVATED: "Personel Pasif Edildi",
  ORDER_CANCELLED: "Sipariş İptal Edildi",
  ORDER_ITEM_VOIDED: "Ürün İptal Edildi",
  PAYMENT_VOIDED: "Ödeme İptal Edildi",
};

export default async function SuperAdminAuditPage() {
  const supabase = await createClient();
  const { data: logs } = await supabase
    .from("audit_logs")
    .select("id, action, entity, entity_id, metadata, created_at, profiles(full_name, email), businesses(name)")
    .order("created_at", { ascending: false })
    .limit(200);

  return (
    <div>
      <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">Denetim Kaydı</h1>
      <p className="mt-1 text-sm text-zinc-600">
        Platformdaki kritik işlemlerin geçmişi (en son 200 kayıt). Bu kayıtlar değiştirilemez.
      </p>

      <div className="mt-6 overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-sm">
        {!logs || logs.length === 0 ? (
          <p className="px-5 py-10 text-center text-sm text-zinc-500">Henüz kayıt yok.</p>
        ) : (
          <table className="w-full text-left text-sm">
            <thead className="border-b border-zinc-200 bg-zinc-50 text-xs uppercase tracking-wide text-zinc-500">
              <tr>
                <th className="px-5 py-3 font-medium">İşlem</th>
                <th className="px-5 py-3 font-medium">İşletme</th>
                <th className="px-5 py-3 font-medium">Yapan</th>
                <th className="px-5 py-3 font-medium">Tarih</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-100">
              {logs.map((log) => {
                const actor = log.profiles as { full_name: string | null; email: string | null } | null;
                const business = log.businesses as { name: string } | null;
                return (
                  <tr key={log.id}>
                    <td className="px-5 py-3 font-medium text-zinc-900">
                      {actionLabels[log.action] ?? log.action}
                    </td>
                    <td className="px-5 py-3 text-zinc-600">{business?.name ?? "—"}</td>
                    <td className="px-5 py-3 text-zinc-600">
                      {actor?.full_name ?? actor?.email ?? "—"}
                    </td>
                    <td className="px-5 py-3 text-zinc-500">
                      {new Date(log.created_at).toLocaleString("tr-TR")}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
