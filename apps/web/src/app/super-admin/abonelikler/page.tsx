import { createClient } from "@/lib/supabase/server";
import type { GooglePlayPurchaseState } from "@/lib/supabase/database.types";

const stateLabels: Record<GooglePlayPurchaseState, string> = {
  PENDING: "Bekliyor",
  ACTIVE: "Aktif",
  GRACE_PERIOD: "Ödeme Bekliyor",
  ON_HOLD: "Askıda (Ödeme)",
  CANCELLED: "İptal Edildi",
  EXPIRED: "Süresi Doldu",
  REVOKED: "İade Edildi",
};

const stateBadgeClass: Record<GooglePlayPurchaseState, string> = {
  PENDING: "bg-zinc-100 text-zinc-600 border-zinc-200",
  ACTIVE: "bg-emerald-50 text-emerald-700 border-emerald-200",
  GRACE_PERIOD: "bg-amber-50 text-amber-700 border-amber-200",
  ON_HOLD: "bg-amber-50 text-amber-700 border-amber-200",
  CANCELLED: "bg-zinc-100 text-zinc-600 border-zinc-200",
  EXPIRED: "bg-zinc-100 text-zinc-600 border-zinc-200",
  REVOKED: "bg-red-50 text-red-700 border-red-200",
};

// Google Play subscriptions are verified server-side and never manually
// approved here -- see 20260922000026_google_play_subscriptions.sql.
// This page only reads what's already been verified and written by that
// (not-yet-implemented) job; purchase_token is deliberately never
// selected, matching the DB policy that hides it from everyone except a
// raw SQL session.
export default async function SuperAdminSubscriptionsPage() {
  const supabase = await createClient();

  const { data: purchases } = await supabase
    .from("google_play_purchases")
    .select(
      "id, product_id, base_plan_id, purchase_state, auto_renewing, start_time, expiry_time, last_verified_at, businesses(id, name), plans(name)"
    )
    .order("updated_at", { ascending: false });

  return (
    <div>
      <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">Abonelikler</h1>
      <p className="mt-1 text-sm text-zinc-600">
        Google Play üzerinden satın alınan abonelikler, sunucu tarafında doğrulandıktan sonra
        burada görünür.
      </p>

      <div className="mt-4 rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
        Google Play Developer API entegrasyonu (service-account kimlik bilgisi gerektirir) henüz
        yapılandırılmadı — bu yüzden liste şu an boş olacaktır. Satın alma doğrulaması hiçbir
        zaman Super Admin tarafından manuel yapılmaz; entegrasyon tamamlandığında satın alma
        kayıtları otomatik olarak burada listelenir. Purchase token gibi hassas veriler bu
        ekranda (veya herhangi bir client&apos;ta) hiçbir zaman gösterilmez.
      </div>

      <div className="mt-6 overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-sm">
        {!purchases || purchases.length === 0 ? (
          <p className="px-5 py-10 text-center text-sm text-zinc-500">
            Henüz doğrulanmış bir Google Play aboneliği yok.
          </p>
        ) : (
          <table className="w-full text-left text-sm">
            <thead className="border-b border-zinc-200 bg-zinc-50 text-xs uppercase tracking-wide text-zinc-500">
              <tr>
                <th className="px-5 py-3 font-medium">İşletme</th>
                <th className="px-5 py-3 font-medium">Plan</th>
                <th className="px-5 py-3 font-medium">Ürün</th>
                <th className="px-5 py-3 font-medium">Durum</th>
                <th className="px-5 py-3 font-medium">Yenileme Tarihi</th>
                <th className="px-5 py-3 font-medium">Son Doğrulama</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-100">
              {purchases.map((purchase) => {
                const business = purchase.businesses as { id: string; name: string } | null;
                const plan = purchase.plans as { name: string } | null;
                return (
                  <tr key={purchase.id} className="hover:bg-zinc-50">
                    <td className="px-5 py-3 font-medium text-zinc-900">
                      {business?.name ?? "—"}
                    </td>
                    <td className="px-5 py-3 text-zinc-600">{plan?.name ?? "—"}</td>
                    <td className="px-5 py-3 text-zinc-600">{purchase.product_id}</td>
                    <td className="px-5 py-3">
                      <span
                        className={`inline-flex rounded-full border px-2.5 py-0.5 text-xs font-medium ${stateBadgeClass[purchase.purchase_state]}`}
                      >
                        {stateLabels[purchase.purchase_state]}
                      </span>
                    </td>
                    <td className="px-5 py-3 text-zinc-500">
                      {purchase.expiry_time ? new Date(purchase.expiry_time).toLocaleString("tr-TR") : "—"}
                    </td>
                    <td className="px-5 py-3 text-zinc-500">
                      {purchase.last_verified_at
                        ? new Date(purchase.last_verified_at).toLocaleString("tr-TR")
                        : "—"}
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
