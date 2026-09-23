import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getBusinessAdminContext } from "@/lib/auth/session";
import { getCatalogPlans } from "@/lib/plans";
import { PlanComparison } from "@/components/plan-comparison";
import type { SubscriptionStatus } from "@/lib/supabase/database.types";

const statusLabels: Record<SubscriptionStatus, string> = {
  TRIAL: "Ücretsiz deneme",
  ACTIVE: "Aktif",
  GRACE_PERIOD: "Ödeme bekleniyor",
  EXPIRED: "Süresi doldu",
  SUSPENDED: "Askıya alındı",
  CANCELLED: "İptal edildi",
};

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString("tr-TR", { day: "numeric", month: "long", year: "numeric" });
}

function daysUntil(dateIso: string): number {
  return Math.ceil((new Date(dateIso).getTime() - Date.now()) / (1000 * 60 * 60 * 24));
}

export default async function AbonelikPage() {
  const ctx = await getBusinessAdminContext();
  if (!ctx) redirect("/hesabim");

  const supabase = await createClient();

  const [{ data: business }, plans, tables, areas, waiters, { data: playRows }] = await Promise.all([
    supabase
      .from("businesses")
      .select("subscription_status, trial_ends_at, plan_id, plans(name, max_tables, max_waiters, max_areas)")
      .eq("id", ctx.businessId)
      .single(),
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
    supabase.rpc("get_own_business_subscription", { p_business_id: ctx.businessId }),
  ]);

  if (!business) redirect("/isletme");

  const plan = business.plans as {
    name: string;
    max_tables: number | null;
    max_waiters: number | null;
    max_areas: number | null;
  } | null;
  const play = playRows?.[0] ?? null;
  const status = business.subscription_status;
  const trialDaysLeft = status === "TRIAL" ? daysUntil(business.trial_ends_at) : null;

  const usage = [
    { label: "Masa", used: tables.count ?? 0, limit: plan?.max_tables ?? null },
    { label: "Garson", used: waiters.count ?? 0, limit: plan?.max_waiters ?? null },
    { label: "Alan", used: areas.count ?? 0, limit: plan?.max_areas ?? null },
  ];

  return (
    <div className="max-w-5xl">
      <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">Abonelik</h1>
      <p className="mt-1 text-sm text-zinc-600">Planınız, kullanımınız ve abonelik durumunuz.</p>

      <div className="mt-6 grid gap-4 md:grid-cols-2">
        <div className="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
          <p className="text-sm text-zinc-500">Durum</p>
          <p className="mt-1 text-xl font-semibold tracking-tight text-zinc-900">{statusLabels[status]}</p>
          <p className="mt-1 text-sm text-zinc-600">
            Plan: <span className="font-medium text-zinc-900">{plan?.name ?? "Plan atanmadı"}</span>
          </p>

          {trialDaysLeft !== null && (
            <p className="mt-3 text-sm text-zinc-600">
              {trialDaysLeft > 0
                ? `Deneme ${formatDate(business.trial_ends_at)} tarihinde bitiyor (${trialDaysLeft} gün kaldı). Deneme süresince limitler uygulanmaz; QR Menü planla birlikte açılır.`
                : "Deneme süreniz doldu. Yeni adisyon açılamaz; açık adisyonlarınızı kapatabilirsiniz. Verileriniz silinmez."}
            </p>
          )}

          {play?.expiry_time && (
            <p className="mt-3 text-sm text-zinc-600">
              {play.auto_renewing
                ? `Google Play aboneliği ${formatDate(play.expiry_time)} tarihinde yenilenecek.`
                : `Otomatik yenileme kapalı. Abonelik ${formatDate(play.expiry_time)} tarihine kadar geçerli.`}
            </p>
          )}
          {status === "GRACE_PERIOD" && (
            <p className="mt-3 text-sm text-amber-700">
              Google Play ödemenizi alamadı. Erişiminiz şimdilik devam ediyor; lütfen Google Play
              hesabınızdaki ödeme yöntemini güncelleyin.
            </p>
          )}
        </div>

        <div className="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
          <p className="text-sm text-zinc-500">Kullanım</p>
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

      <h2 className="mt-10 text-lg font-semibold tracking-tight text-zinc-900">Planlar</h2>
      <div className="mt-4">
        <PlanComparison plans={plans} currentPlanId={business.plan_id} />
      </div>

      <div className="mt-6 rounded-lg border border-zinc-200 bg-zinc-50 px-4 py-3 text-sm text-zinc-600">
        Abonelik satın alma ve plan değişikliği MK Adisyon Android uygulamasından Google Play ile
        yapılacak. Google Play ödemeleri henüz aktif değildir; bu süreçte plan değişikliği için{" "}
        <Link href="/isletme/destek" className="font-medium text-zinc-900 underline underline-offset-4">
          destek
        </Link>{" "}
        ile iletişime geçebilirsiniz. Birden fazla şube için{" "}
        <Link href="/isletme/destek#teklif" className="font-medium text-zinc-900 underline underline-offset-4">
          teklif alın
        </Link>
        .
      </div>
    </div>
  );
}
