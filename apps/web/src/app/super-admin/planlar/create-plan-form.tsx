"use client";

import { useActionState, useState } from "react";
import { createPlan } from "./actions";

interface ActionState {
  error: string | null;
}

const initialState: ActionState = { error: null };

const inputClass =
  "w-full rounded-lg border border-zinc-300 bg-white px-3.5 py-2.5 text-sm text-zinc-900 outline-none placeholder:text-zinc-400 focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500";
const labelClass = "mb-1.5 block text-sm font-medium text-zinc-800";

export function CreatePlanForm() {
  const [state, formAction, pending] = useActionState<ActionState, FormData>(
    createPlan,
    initialState
  );
  const [open, setOpen] = useState(false);

  if (!open) {
    return (
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="inline-flex h-10 items-center justify-center rounded-lg bg-zinc-900 px-5 text-sm font-medium text-white hover:bg-zinc-800"
      >
        Yeni Plan Oluştur
      </button>
    );
  }

  return (
    <form
      action={formAction}
      className="grid gap-4 rounded-xl border border-zinc-200 bg-white p-6 shadow-sm sm:grid-cols-2"
    >
      {state.error && (
        <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700 sm:col-span-2">
          {state.error}
        </div>
      )}

      <div className="sm:col-span-2">
        <label className={labelClass} htmlFor="name">
          Plan Adı
        </label>
        <input id="name" name="name" required className={inputClass} />
      </div>

      <div>
        <label className={labelClass} htmlFor="monthly_price">
          Aylık Fiyat (₺)
        </label>
        <input id="monthly_price" name="monthly_price" type="number" step="0.01" min={0} className={inputClass} />
      </div>
      <div>
        <label className={labelClass} htmlFor="yearly_price">
          Yıllık Fiyat (₺)
        </label>
        <input id="yearly_price" name="yearly_price" type="number" step="0.01" min={0} className={inputClass} />
      </div>
      <div>
        <label className={labelClass} htmlFor="yearly_discount">
          Yıllık İndirim (%)
        </label>
        <input id="yearly_discount" name="yearly_discount" type="number" step="0.01" min={0} className={inputClass} />
      </div>
      <div>
        <label className={labelClass} htmlFor="reporting_level">
          Raporlama Seviyesi
        </label>
        <input id="reporting_level" name="reporting_level" defaultValue="BASIC" className={inputClass} />
      </div>

      <div>
        <label className={labelClass} htmlFor="max_tables">
          Maks. Masa <span className="text-zinc-400">(boş = sınırsız)</span>
        </label>
        <input id="max_tables" name="max_tables" type="number" min={0} className={inputClass} />
      </div>
      <div>
        <label className={labelClass} htmlFor="max_waiters">
          Maks. Garson <span className="text-zinc-400">(boş = sınırsız)</span>
        </label>
        <input id="max_waiters" name="max_waiters" type="number" min={0} className={inputClass} />
      </div>
      <div>
        <label className={labelClass} htmlFor="max_users">
          Maks. Kullanıcı <span className="text-zinc-400">(boş = sınırsız)</span>
        </label>
        <input id="max_users" name="max_users" type="number" min={0} className={inputClass} />
      </div>
      <div>
        <label className={labelClass} htmlFor="max_areas">
          Maks. Alan <span className="text-zinc-400">(boş = sınırsız)</span>
        </label>
        <input id="max_areas" name="max_areas" type="number" min={0} className={inputClass} />
      </div>
      <div>
        <label className={labelClass} htmlFor="max_branches">
          Maks. Şube <span className="text-zinc-400">(boş = sınırsız)</span>
        </label>
        <input id="max_branches" name="max_branches" type="number" min={0} className={inputClass} />
      </div>

      <label className="flex items-center gap-2.5 text-sm text-zinc-700 sm:col-span-2">
        <input type="checkbox" name="qr_menu_enabled" className="h-4 w-4 rounded border-zinc-300" />
        QR Menü özelliği açık
      </label>

      <div className="flex gap-3 sm:col-span-2">
        <button
          type="submit"
          disabled={pending}
          className="inline-flex h-10 items-center justify-center rounded-lg bg-zinc-900 px-5 text-sm font-medium text-white hover:bg-zinc-800 disabled:opacity-60"
        >
          {pending ? "Oluşturuluyor..." : "Planı Oluştur"}
        </button>
        <button
          type="button"
          onClick={() => setOpen(false)}
          className="inline-flex h-10 items-center justify-center rounded-lg border border-zinc-300 bg-white px-5 text-sm font-medium text-zinc-900 hover:bg-zinc-50"
        >
          Vazgeç
        </button>
      </div>
    </form>
  );
}
