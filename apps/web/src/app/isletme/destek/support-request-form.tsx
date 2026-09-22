"use client";

import { useActionState } from "react";
import { createSupportRequest } from "./actions";

interface ActionState {
  error: string | null;
}

const initialState: ActionState = { error: null };

const inputClass =
  "w-full rounded-lg border border-zinc-300 bg-white px-3.5 py-2.5 text-sm text-zinc-900 outline-none placeholder:text-zinc-400 focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500";
const labelClass = "mb-1.5 block text-sm font-medium text-zinc-800";

const typeLabels = {
  TECHNICAL_SUPPORT: "Teknik Destek",
  FEATURE_REQUEST: "Özellik Talebi",
  OTHER: "Diğer",
};

export function SupportRequestForm() {
  const [state, formAction, pending] = useActionState<ActionState, FormData>(
    createSupportRequest,
    initialState
  );

  return (
    <form action={formAction} className="space-y-4 rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
      {state.error && (
        <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {state.error}
        </div>
      )}
      <div>
        <label className={labelClass} htmlFor="type">
          Talep Türü
        </label>
        <select id="type" name="type" defaultValue="TECHNICAL_SUPPORT" className={inputClass}>
          {Object.entries(typeLabels).map(([value, label]) => (
            <option key={value} value={value}>
              {label}
            </option>
          ))}
        </select>
      </div>
      <div>
        <label className={labelClass} htmlFor="subject">
          Konu
        </label>
        <input id="subject" name="subject" required className={inputClass} />
      </div>
      <div>
        <label className={labelClass} htmlFor="description">
          Açıklama
        </label>
        <textarea id="description" name="description" rows={4} required className={inputClass} />
      </div>
      <button
        type="submit"
        disabled={pending}
        className="inline-flex h-10 items-center justify-center rounded-lg bg-zinc-900 px-5 text-sm font-medium text-white hover:bg-zinc-800 disabled:opacity-60"
      >
        {pending ? "Gönderiliyor..." : "Talebi Gönder"}
      </button>
    </form>
  );
}
