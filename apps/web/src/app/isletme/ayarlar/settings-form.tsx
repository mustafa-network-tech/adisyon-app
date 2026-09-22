"use client";

import { useActionState } from "react";
import { updateBusinessProfile } from "./actions";

interface SettingsActionState {
  error: string | null;
  success: boolean;
}

const initialState: SettingsActionState = { error: null, success: false };

const inputClass =
  "w-full rounded-lg border border-zinc-300 bg-white px-3.5 py-2.5 text-sm text-zinc-900 outline-none placeholder:text-zinc-400 focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500";
const labelClass = "mb-1.5 block text-sm font-medium text-zinc-800";

export interface BusinessProfile {
  name: string;
  business_type: string | null;
  city: string | null;
  address: string | null;
  phone: string | null;
  email: string | null;
  logo_url: string | null;
}

export function SettingsForm({ business }: { business: BusinessProfile }) {
  const [state, formAction, pending] = useActionState<SettingsActionState, FormData>(
    updateBusinessProfile,
    initialState
  );

  return (
    <form
      action={formAction}
      className="max-w-xl space-y-5 rounded-xl border border-zinc-200 bg-white p-6 shadow-sm"
    >
      {state.error && (
        <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {state.error}
        </div>
      )}
      {state.success && (
        <div className="rounded-lg border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">
          Değişiklikler kaydedildi.
        </div>
      )}

      <div>
        <label className={labelClass} htmlFor="name">
          İşletme Adı
        </label>
        <input id="name" name="name" defaultValue={business.name} required className={inputClass} />
      </div>

      <div>
        <label className={labelClass} htmlFor="business_type">
          İşletme Türü
        </label>
        <input
          id="business_type"
          name="business_type"
          defaultValue={business.business_type ?? ""}
          className={inputClass}
        />
      </div>

      <div className="grid gap-5 sm:grid-cols-2">
        <div>
          <label className={labelClass} htmlFor="phone">
            Telefon
          </label>
          <input id="phone" name="phone" defaultValue={business.phone ?? ""} className={inputClass} />
        </div>
        <div>
          <label className={labelClass} htmlFor="email">
            E-posta
          </label>
          <input id="email" name="email" type="email" defaultValue={business.email ?? ""} className={inputClass} />
        </div>
      </div>

      <div className="grid gap-5 sm:grid-cols-2">
        <div>
          <label className={labelClass} htmlFor="city">
            Şehir
          </label>
          <input id="city" name="city" defaultValue={business.city ?? ""} className={inputClass} />
        </div>
        <div>
          <label className={labelClass} htmlFor="logo_url">
            Logo URL
          </label>
          <input id="logo_url" name="logo_url" defaultValue={business.logo_url ?? ""} className={inputClass} />
        </div>
      </div>

      <div>
        <label className={labelClass} htmlFor="address">
          Adres
        </label>
        <input id="address" name="address" defaultValue={business.address ?? ""} className={inputClass} />
      </div>

      <button
        type="submit"
        disabled={pending}
        className="inline-flex h-11 items-center justify-center rounded-lg bg-zinc-900 px-6 text-sm font-medium text-white hover:bg-zinc-800 disabled:opacity-60"
      >
        {pending ? "Kaydediliyor..." : "Kaydet"}
      </button>
    </form>
  );
}
