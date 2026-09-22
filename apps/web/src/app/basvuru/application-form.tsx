"use client";

import { useActionState } from "react";
import { submitApplication } from "./actions";

interface ApplicationFormState {
  error: string | null;
}

const initialState: ApplicationFormState = { error: null };

const inputClass =
  "w-full rounded-lg border border-zinc-300 bg-white px-3.5 py-2.5 text-sm text-zinc-900 outline-none placeholder:text-zinc-400 focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500";
const labelClass = "mb-1.5 block text-sm font-medium text-zinc-800";

export function ApplicationForm() {
  const [state, formAction, pending] = useActionState(submitApplication, initialState);

  return (
    <form action={formAction} className="space-y-5">
      {state.error && (
        <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {state.error}
        </div>
      )}

      <div>
        <label className={labelClass} htmlFor="business_name">
          İşletme Adı *
        </label>
        <input id="business_name" name="business_name" required className={inputClass} />
      </div>

      <div>
        <label className={labelClass} htmlFor="business_type">
          İşletme Türü
        </label>
        <input
          id="business_type"
          name="business_type"
          placeholder="Kafe, restoran, pastane..."
          className={inputClass}
        />
      </div>

      <div className="grid gap-5 sm:grid-cols-2">
        <div>
          <label className={labelClass} htmlFor="contact_name">
            Yetkili Adı Soyadı *
          </label>
          <input id="contact_name" name="contact_name" required className={inputClass} />
        </div>
        <div>
          <label className={labelClass} htmlFor="phone">
            Telefon *
          </label>
          <input id="phone" name="phone" type="tel" required className={inputClass} />
        </div>
      </div>

      <div>
        <label className={labelClass} htmlFor="email">
          E-posta *
        </label>
        <input id="email" name="email" type="email" required className={inputClass} />
      </div>

      <div className="grid gap-5 sm:grid-cols-2">
        <div>
          <label className={labelClass} htmlFor="city">
            Şehir
          </label>
          <input id="city" name="city" className={inputClass} />
        </div>
        <div>
          <label className={labelClass} htmlFor="estimated_tables">
            Tahmini Masa Sayısı
          </label>
          <input
            id="estimated_tables"
            name="estimated_tables"
            type="number"
            min={0}
            className={inputClass}
          />
        </div>
      </div>

      <div>
        <label className={labelClass} htmlFor="address">
          Adres (opsiyonel)
        </label>
        <input id="address" name="address" className={inputClass} />
      </div>

      <div>
        <label className={labelClass} htmlFor="description">
          Açıklama
        </label>
        <textarea id="description" name="description" rows={4} className={inputClass} />
      </div>

      <label className="flex items-start gap-2.5 text-sm text-zinc-700">
        <input
          type="checkbox"
          name="consents_accepted"
          required
          className="mt-0.5 h-4 w-4 rounded border-zinc-300"
        />
        <span>
          Kullanım koşullarını ve gizlilik politikasını okudum, kabul ediyorum. *
        </span>
      </label>

      <button
        type="submit"
        disabled={pending}
        className="inline-flex h-11 w-full items-center justify-center rounded-lg bg-zinc-900 px-6 text-sm font-medium text-white transition-colors hover:bg-zinc-800 disabled:cursor-not-allowed disabled:opacity-60 sm:w-auto"
      >
        {pending ? "Gönderiliyor..." : "Başvuruyu Gönder"}
      </button>
    </form>
  );
}
