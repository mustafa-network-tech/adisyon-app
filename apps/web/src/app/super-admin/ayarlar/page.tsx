import { createClient } from "@/lib/supabase/server";
import { getTrialSettings } from "@/lib/plans";
import { SubscriptionSettingsForm } from "./settings-form";

export default async function SubscriptionSettingsPage() {
  const supabase = await createClient();
  const trial = await getTrialSettings(supabase);

  return (
    <div className="max-w-2xl">
      <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">Abonelik Ayarları</h1>
      <p className="mt-1 text-sm text-zinc-600">
        Yeni işletmelerin ücretsiz deneme süresi. Google Play ücretsiz kampanyaları (süre, uygunluk)
        Play Console&apos;daki abonelik tekliflerinden yönetilir; uygulama her zaman Play&apos;in
        döndürdüğü teklifi gösterir.
      </p>

      <div className="mt-6">
        <SubscriptionSettingsForm appTrialDays={trial.appTrialDays} />
      </div>

      <div className="mt-6 rounded-lg border border-zinc-200 bg-zinc-50 px-4 py-3 text-sm text-zinc-600">
        Ücretsiz dönemlerde (uygulama denemesi ve Google Play ücretsiz dönemi) geçerli haklar:{" "}
        <span className="font-medium text-zinc-900">{trial.trialPlanName ?? "—"}</span> planının tüm
        özellikleri ve limitleri.
      </div>
    </div>
  );
}
