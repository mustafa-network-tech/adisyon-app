"use client";

import { useActionState } from "react";
import { createCustomSoftwareRequest } from "./actions";

interface ActionState {
  error: string | null;
}

const initialState: ActionState = { error: null };

const inputClass =
  "w-full rounded-lg border border-zinc-300 bg-white px-3.5 py-2.5 text-sm text-zinc-900 outline-none placeholder:text-zinc-400 focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500";
const labelClass = "mb-1.5 block text-sm font-medium text-zinc-800";

export function CustomSoftwareForm() {
  const [state, formAction, pending] = useActionState<ActionState, FormData>(
    createCustomSoftwareRequest,
    initialState
  );

  return (
    <form action={formAction} className="space-y-4 rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
      {state.error && (
        <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {state.error}
        </div>
      )}
      <div className="grid gap-4 sm:grid-cols-2">
        <div>
          <label className={labelClass} htmlFor="requester_name">
            Yetkili Adı Soyadı
          </label>
          <input id="requester_name" name="requester_name" required className={inputClass} />
        </div>
        <div>
          <label className={labelClass} htmlFor="phone">
            Telefon
          </label>
          <input id="phone" name="phone" required className={inputClass} />
        </div>
        <div>
          <label className={labelClass} htmlFor="email">
            E-posta
          </label>
          <input id="email" name="email" type="email" required className={inputClass} />
        </div>
        <div>
          <label className={labelClass} htmlFor="branch_count">
            Şube Sayısı
          </label>
          <input id="branch_count" name="branch_count" type="number" min={0} className={inputClass} />
        </div>
      </div>
      <div>
        <label className={labelClass} htmlFor="need">
          İhtiyacınız Nedir?
        </label>
        <textarea id="need" name="need" rows={3} required className={inputClass} />
      </div>
      <div>
        <label className={labelClass} htmlFor="description">
          Ek Açıklama
        </label>
        <textarea id="description" name="description" rows={3} className={inputClass} />
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
