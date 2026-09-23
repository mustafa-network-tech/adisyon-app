import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getBusinessAdminContext } from "@/lib/auth/session";
import { getCatalogPlans } from "@/lib/plans";
import { PlanComparison } from "@/components/plan-comparison";
import type { AccessSource, SubscriptionStatus } from "@/lib/supabase/database.types";

const statusLabels: Record<SubscriptionStatus, string> = {
  TRIAL: "Ücretsiz deneme",
  ACTIVE: "Aktif",
  GRACE_PERIOD: "Ödeme bekleniyor",
  EXPIRED: "Süresi doldu",
  SUSPENDED: "Askıya alındı",
  CANCELLED: "İptal edildi",
};

const sourceLabels: Record<AccessSource, string> = {
  APP_TRIAL: "MK Adisyon ücretsiz denemesi",
  PLAY_TRIAL: "Google Play ücretsiz dönemi",
  PLAY_SUBSCRIPTION: "Google Play aboneliği",
  MANUAL: "Yönetici tarafından tanımlı",
  SUSPENDED: "Askıda",
  NONE: "Aktif erişim yok",
};

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString("tr-TR", { day: "numeric", month: "long", year: "numeric" });
}

export default async function AbonelikPage() {
  const ctx = await getBusinessAdminContext();
  if (!ctx) redirect("/hesabim");

  const supabase = await createClient();

  const [{ data: entitlementRows }, plans, tables, areas, waiters] = await Promise.all([
    supabase.rpc("get_business_entitlement", { p_business_id: ctx.businessId }),
    getCatalogPlans(supabase),
    supabase
      .from("restaurant_tables")
      .select("id", { count: "exact", head: true })
      .eq("business_id", ctx.businessId)
      .eq("active", true),
    supabase
      .from("areas")
      .select("id", { count: "exact", head: true })
      .eq("business_id", ctx.businessId)
      .eq("active", true),
    supabase
      .from("business_memberships")
      .select("id", { count: "exact", head: true })
      .eq("business_id", ctx.businessId)
      .eq("active", true)
      .eq("role", "WAITER"),
  ]);

  const entitlement = entitlementRows?.[0];
  if (!entitlement) redirect("/isletme");

  const usage = [
    { label: "Masa", used: tables.count ?? 0, limit: entitlement.max_tables },
    { label: "Garson", used: waiters.count ?? 0, limit: entitlement.max_waiters },
    { label: "Alan", used: areas.count ?? 0, limit: entitlement.max_areas },
  ];
  const onFreePeriod = entitlement.access_source === "APP_TRIAL" || entitlement.access_source === "PLAY_TRIAL";

  return (
    <div className="max-w-5xl">
      <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">Abonelik</h1>
      <p className="mt-1 text-sm text-zinc-600">Planınız, kullanımınız ve abonelik durumunuz.</p>

      <div className="mt-6 grid gap-4 md:grid-cols-2">
        <div className="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
          <p className="text-sm text-zinc-500">Durum</p>
          <p className="mt-1 text-xl font-semibold tracking-tight text-zinc-900">
            {statusLabels[entitlement.subscription_status]}
          </p>
          <p className="mt-1 text-sm text-zinc-600">{sourceLabels[entitlement.access_source]}</p>
          <p className="mt-3 text-sm text-zinc-600">
            Abone olunan plan:{" "}
            <span className="font-medium text-zinc-900">{entitlement.subscribed_plan_name ?? "—"}</span>
          </p>
          <p className="text-sm text-zinc-600">
            Şu an geçerli haklar:{" "}
            <span className="font-medium text-zinc-900">
              {entitlement.effective_plan_name ?? "Plan atanmadı"}
            </span>
          </p>

          {entitlement.access_source === "APP_TRIAL" && (
            <p className="mt-3 text-sm text-zinc-600">
              Ücretsiz denemenizin {entitlement.app_trial_days_left} günü kaldı (bitiş:{" "}
              {formatDate(entitlement.app_trial_ends_at)}). Deneme süresince {entitlement.effective_plan_name}{" "}
              planının tüm özellikleri açık.
            </p>
          )}
          {entitlement.access_source === "PLAY_TRIAL" && entitlement.play_expiry_time && (
            <p className="mt-3 text-sm text-zinc-600">
              Google Play ücretsiz döneminiz {formatDate(entitlement.play_expiry_time)} tarihine kadar
              sürüyor. Bu süre boyunca {entitlement.effective_plan_name} planının tüm özellikleri açık;
              sonrasında abone olduğunuz planın limitleri geçerli olur.
            </p>
          )}
          {entitlement.access_source === "PLAY_SUBSCRIPTION" && entitlement.play_expiry_time && (
            <p className="mt-3 text-sm text-zinc-600">
              {entitlement.play_auto_renewing
                ? `Google Play aboneliğiniz ${formatDate(entitlement.play_expiry_time)} tarihinde yenilenecek.`
                : `Otomatik yenileme kapalı. Aboneliğiniz ${formatDate(entitlement.play_expiry_time)} tarihine kadar geçerli.`}
            </p>
          )}
          {entitlement.subscription_status === "GRACE_PERIOD" && (
            <p className="mt-3 text-sm text-amber-700">
              Google Play ödemenizi alamadı. Erişiminiz şimdilik devam ediyor; lütfen Google Play
              hesabınızdaki ödeme yöntemini güncelleyin.
            </p>
          )}
          {!entitlement.is_operational && entitlement.access_source !== "SUSPENDED" && (
            <p className="mt-3 text-sm text-red-700">
              Aktif bir deneme veya aboneliğiniz yok. Yeni adisyon açılamaz; açık adisyonlarınızı
              kapatabilirsiniz ve verileriniz silinmez.
            </p>
          )}
        </div>

        <div className="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
          <p className="text-sm text-zinc-500">Kullanım {onFreePeriod && "(ücretsiz dönem limitleri)"}</p>
          <ul className="mt-3 space-y-3">
            {usage.map((item) => {
              const ratio = item.limit ? Math.min(item.used / item.limit, 1) : 0;
              return (
                <li key={item.label}>
                  <div className="flex justify-between text-sm">
                    <span className="text-zinc-700">{item.label}</span>
                    <span className="font-medium text-zinc-900">
                      {item.used} / {item.limit ?? "Sınırsız"}
                    </span>
                  </div>
                  {item.limit !== null && (
                    <div className="mt-1.5 h-1.5 overflow-hidden rounded-full bg-zinc-100">
                      <div
                        className={`h-full rounded-full ${ratio >= 1 ? "bg-amber-500" : "bg-zinc-900"}`}
                        style={{ width: `${ratio * 100}%` }}
                      />
                    </div>
                  )}
                </li>
              );
            })}
          </ul>
        </div>
      </div>

      <div className="mt-6 rounded-lg border border-zinc-200 bg-zinc-50 px-4 py-3 text-sm text-zinc-600">
        <p className="font-medium text-zinc-900">Aboneliği nasıl başlatırım?</p>
        <p className="mt-1">
          MK Adisyon Android uygulamasına işletme yöneticisi hesabınızla giriş yapın ve
          <span className="font-medium"> Abonelik ve Planlar</span> ekranından bir plan seçin. Ödeme
          Google Play üzerinden alınır; geçerli bir kampanya varsa (örneğin ücretsiz dönem) orada
          gösterilir. Aboneliği iptal etmek veya ödeme yöntemini değiştirmek için Google Play &gt;
          Ödemeler ve abonelikler bölümünü kullanın.
        </p>
      </div>

      <h2 className="mt-10 text-lg font-semibold tracking-tight text-zinc-900">Planlar</h2>
      <div className="mt-4">
        <PlanComparison plans={plans} currentPlanId={entitlement.subscribed_plan_id} />
      </div>

      <p className="mt-6 text-sm text-zinc-600">
        Birden fazla şube için{" "}
        <Link href="/isletme/destek#teklif" className="font-medium text-zinc-900 underline underline-offset-4">
          teklif alın
        </Link>
        .
      </p>
    </div>
  );
}
