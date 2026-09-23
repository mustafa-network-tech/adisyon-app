import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { getCatalogPlans, getTrialSettings } from "@/lib/plans";
import { PlanComparison } from "@/components/plan-comparison";

export const metadata = {
  title: "Fiyatlandırma | MK Adisyon",
};

// Public page. plans is readable by anon (plans_select_all), so this
// needs no session.
export default async function FiyatlandirmaPage() {
  const supabase = await createClient();
  const [plans, trial] = await Promise.all([getCatalogPlans(supabase), getTrialSettings(supabase)]);

  return (
    <div className="mx-auto w-full max-w-5xl px-6 py-16">
      <div className="text-center">
        <Link href="/" className="text-sm text-zinc-500 hover:text-zinc-800">
          MK Adisyon
        </Link>
        <h1 className="mt-3 text-3xl font-semibold tracking-tight text-zinc-900">Planlar</h1>
        {trial.appTrialDays > 0 && (
          <p className="mx-auto mt-3 max-w-xl text-base leading-7 text-zinc-600">
            Yeni işletmeler {trial.appTrialDays} gün ücretsiz deneme ile başlar; deneme için ödeme
            bilgisi istenmez.
            {trial.trialPlanName && ` Deneme süresince ${trial.trialPlanName} planının tüm özellikleri açıktır.`}
          </p>
        )}
      </div>

      <div className="mt-10">
        <PlanComparison plans={plans} />
      </div>

      <p className="mt-6 text-center text-sm text-zinc-500">
        Abonelikler MK Adisyon Android uygulamasından Google Play ile başlatılır. Google Play&apos;de
        geçerli bir kampanya varsa (örneğin ücretsiz dönem) uygulamada gösterilir; satın alma
        sırasında Google Play&apos;de gösterilen fiyat ve koşullar esastır.
      </p>

      <div className="mt-12 grid gap-4 md:grid-cols-2">
        <div className="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
          <h2 className="text-lg font-semibold tracking-tight text-zinc-900">Çok Şubeli</h2>
          <p className="mt-2 text-sm leading-6 text-zinc-600">
            Birden fazla şubeniz varsa şube sayınıza ve ihtiyacınıza göre özel fiyatlandırma
            yapıyoruz.
          </p>
          <Link
            href="/isletme/destek#teklif"
            className="mt-5 inline-flex h-10 items-center justify-center rounded-lg bg-zinc-900 px-5 text-sm font-medium text-white hover:bg-zinc-800"
          >
            Teklif Al
          </Link>
        </div>
        <div className="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
          <h2 className="text-lg font-semibold tracking-tight text-zinc-900">Özel Yazılım</h2>
          <p className="mt-2 text-sm leading-6 text-zinc-600">
            Standart planların karşılamadığı ihtiyaçlar için işletmenize özel geliştirme talep
            edin.
          </p>
          <Link
            href="/isletme/destek#teklif"
            className="mt-5 inline-flex h-10 items-center justify-center rounded-lg border border-zinc-300 bg-white px-5 text-sm font-medium text-zinc-900 hover:bg-zinc-50"
          >
            Başvuru Yap
          </Link>
        </div>
      </div>
      <p className="mt-3 text-center text-xs text-zinc-500">
        Teklif ve başvuru formları işletme hesabınızla giriş yaptıktan sonra Destek sayfasındadır.
      </p>
    </div>
  );
}
