"use client";

import { useActionState } from "react";
import { updatePlan } from "./actions";

interface ActionState {
  error: string | null;
  success: boolean;
}

const initialState: ActionState = { error: null, success: false };

const inputClass =
  "w-full rounded-lg border border-zinc-300 bg-white px-3.5 py-2.5 text-sm text-zinc-900 outline-none placeholder:text-zinc-400 focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500";
const labelClass = "mb-1.5 block text-sm font-medium text-zinc-800";

export interface PlanDetail {
  id: string;
  name: string;
  monthly_price: number;
  yearly_price: number;
  yearly_discount: number;
  max_tables: number | null;
  max_waiters: number | null;
  max_users: number | null;
  max_areas: number | null;
  max_branches: number | null;
  qr_menu_enabled: boolean;
  reporting_level: string;
  google_play_product_id: string | null;
  google_play_monthly_base_plan_id: string | null;
  google_play_yearly_base_plan_id: string | null;
}

export function EditPlanForm({ plan }: { plan: PlanDetail }) {
  const updateWithId = updatePlan.bind(null, plan.id);
  const [state, formAction, pending] = useActionState<ActionState, FormData>(
    updateWithId,
    initialState
  );

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
      {state.success && (
        <div className="rounded-lg border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700 sm:col-span-2">
          Değişiklikler kaydedildi.
        </div>
      )}

      <div className="sm:col-span-2">
        <label className={labelClass} htmlFor="name">
          Plan Adı
        </label>
        <input id="name" name="name" defaultValue={plan.name} required className={inputClass} />
      </div>

      <div>
        <label className={labelClass} htmlFor="monthly_price">
          Aylık Fiyat (₺)
        </label>
        <input
          id="monthly_price"
          name="monthly_price"
          type="number"
          step="0.01"
          min={0}
          defaultValue={plan.monthly_price}
          className={inputClass}
        />
      </div>
      <div>
        <label className={labelClass} htmlFor="yearly_price">
          Yıllık Fiyat (₺)
        </label>
        <input
          id="yearly_price"
          name="yearly_price"
          type="number"
          step="0.01"
          min={0}
          defaultValue={plan.yearly_price}
          className={inputClass}
        />
      </div>
      <div>
        <label className={labelClass} htmlFor="yearly_discount">
          Yıllık İndirim (%)
        </label>
        <input
          id="yearly_discount"
          name="yearly_discount"
          type="number"
          step="0.01"
          min={0}
          defaultValue={plan.yearly_discount}
          className={inputClass}
        />
      </div>
      <div>
        <label className={labelClass} htmlFor="reporting_level">
          Raporlama Seviyesi
        </label>
        <input
          id="reporting_level"
          name="reporting_level"
          defaultValue={plan.reporting_level}
          className={inputClass}
        />
      </div>

      <div>
        <label className={labelClass} htmlFor="max_tables">
          Maks. Masa <span className="text-zinc-400">(boş = sınırsız)</span>
        </label>
        <input
          id="max_tables"
          name="max_tables"
          type="number"
          min={0}
          defaultValue={plan.max_tables ?? ""}
          className={inputClass}
        />
      </div>
      <div>
        <label className={labelClass} htmlFor="max_waiters">
          Maks. Garson <span className="text-zinc-400">(boş = sınırsız)</span>
        </label>
        <input
          id="max_waiters"
          name="max_waiters"
          type="number"
          min={0}
          defaultValue={plan.max_waiters ?? ""}
          className={inputClass}
        />
      </div>
      <div>
        <label className={labelClass} htmlFor="max_users">
          Maks. Kullanıcı <span className="text-zinc-400">(boş = sınırsız)</span>
        </label>
        <input
          id="max_users"
          name="max_users"
          type="number"
          min={0}
          defaultValue={plan.max_users ?? ""}
          className={inputClass}
        />
      </div>
      <div>
        <label className={labelClass} htmlFor="max_areas">
          Maks. Alan <span className="text-zinc-400">(boş = sınırsız)</span>
        </label>
        <input
          id="max_areas"
          name="max_areas"
          type="number"
          min={0}
          defaultValue={plan.max_areas ?? ""}
          className={inputClass}
        />
      </div>
      <div>
        <label className={labelClass} htmlFor="max_branches">
          Maks. Şube <span className="text-zinc-400">(boş = sınırsız)</span>
        </label>
        <input
          id="max_branches"
          name="max_branches"
          type="number"
          min={0}
          defaultValue={plan.max_branches ?? ""}
          className={inputClass}
        />
      </div>

      <label className="flex items-center gap-2.5 text-sm text-zinc-700 sm:col-span-2">
        <input
          type="checkbox"
          name="qr_menu_enabled"
          defaultChecked={plan.qr_menu_enabled}
          className="h-4 w-4 rounded border-zinc-300"
        />
        QR Menü özelliği açık
      </label>

      <div className="sm:col-span-2">
        <p className="mb-3 text-xs font-semibold uppercase tracking-wide text-zinc-500">
          Google Play Eşleştirme <span className="normal-case text-zinc-400">(opsiyonel)</span>
        </p>
        <div className="grid gap-4 sm:grid-cols-3">
          <div>
            <label className={labelClass} htmlFor="google_play_product_id">
              Ürün Kimliği
            </label>
            <input
              id="google_play_product_id"
              name="google_play_product_id"
              defaultValue={plan.google_play_product_id ?? ""}
              className={inputClass}
            />
          </div>
          <div>
            <label className={labelClass} htmlFor="google_play_monthly_base_plan_id">
              Aylık Base Plan
            </label>
            <input
              id="google_play_monthly_base_plan_id"
              name="google_play_monthly_base_plan_id"
              defaultValue={plan.google_play_monthly_base_plan_id ?? ""}
              className={inputClass}
            />
          </div>
          <div>
            <label className={labelClass} htmlFor="google_play_yearly_base_plan_id">
              Yıllık Base Plan
            </label>
            <input
              id="google_play_yearly_base_plan_id"
              name="google_play_yearly_base_plan_id"
              defaultValue={plan.google_play_yearly_base_plan_id ?? ""}
              className={inputClass}
            />
          </div>
        </div>
      </div>

      <button
        type="submit"
        disabled={pending}
        className="inline-flex h-10 w-fit items-center justify-center rounded-lg bg-zinc-900 px-5 text-sm font-medium text-white hover:bg-zinc-800 disabled:opacity-60 sm:col-span-2"
      >
        {pending ? "Kaydediliyor..." : "Kaydet"}
      </button>
    </form>
  );
}
