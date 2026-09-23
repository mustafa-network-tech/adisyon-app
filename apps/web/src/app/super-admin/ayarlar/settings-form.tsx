"use client";

import { useActionState } from "react";
import { updateSubscriptionSettings } from "./actions";
import { APP_TRIAL_DAY_OPTIONS } from "./options";

interface ActionState {
  error: string | null;
  success: boolean;
}

const initialState: ActionState = { error: null, success: false };

function optionLabel(days: number): string {
  return days === 0 ? "Deneme yok (0 gün)" : `${days} gün`;
}

export function SubscriptionSettingsForm({ appTrialDays }: { appTrialDays: number }) {
  const [state, formAction, pending] = useActionState<ActionState, FormData>(
    updateSubscriptionSettings,
    initialState
  );
  // Show the stored value even if it isn't one of the current options.
  const options = APP_TRIAL_DAY_OPTIONS.includes(appTrialDays)
    ? APP_TRIAL_DAY_OPTIONS
    : [...APP_TRIAL_DAY_OPTIONS, appTrialDays].sort((a, b) => a - b);

  return (
    <form action={formAction} className="space-y-4 rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
      {state.error && (
        <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">{state.error}</div>
      )}
      {state.success && (
        <div className="rounded-lg border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">
          Kaydedildi. Yeni süre bundan sonra oluşturulan işletmelere uygulanır.
        </div>
      )}

      <div>
        <label htmlFor="app_trial_days" className="mb-1.5 block text-sm font-medium text-zinc-800">
          Ücretsiz Uygulama Deneme Süresi
        </label>
        <select
          id="app_trial_days"
          name="app_trial_days"
          defaultValue={appTrialDays}
          className="w-full rounded-lg border border-zinc-300 bg-white px-3.5 py-2.5 text-sm text-zinc-900 outline-none focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500"
        >
          {options.map((days) => (
            <option key={days} value={days}>
              {optionLabel(days)}
            </option>
          ))}
        </select>
        <p className="mt-1.5 text-xs leading-5 text-zinc-500">
          Kayıt sırasında ödeme yöntemi istenmeden verilen MK Adisyon denemesi. Değişiklik mevcut
          işletmelerin deneme bitiş tarihini değiştirmez. 0 seçilirse yeni işletmeler aboneliği
          başlatmadan adisyon açamaz.
        </p>
      </div>

      <button
        type="submit"
        disabled={pending}
        className="inline-flex h-10 items-center justify-center rounded-lg bg-zinc-900 px-5 text-sm font-medium text-white hover:bg-zinc-800 disabled:opacity-60"
      >
        {pending ? "Kaydediliyor..." : "Kaydet"}
      </button>
    </form>
  );
}
