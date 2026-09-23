"use client";

import { useTransition } from "react";
import Link from "next/link";
import { togglePlanActive } from "./actions";

export interface PlanRow {
  id: string;
  code: string | null;
  name: string;
  monthly_price: number;
  max_tables: number | null;
  max_waiters: number | null;
  max_users: number | null;
  max_areas: number | null;
  active: boolean;
}

const currencyFormatter = new Intl.NumberFormat("tr-TR", { style: "currency", currency: "TRY" });

function limitLabel(value: number | null) {
  return value === null ? "Sınırsız" : String(value);
}

export function PlanList({ plans }: { plans: PlanRow[] }) {
  const [isPending, startTransition] = useTransition();

  if (plans.length === 0) {
    return (
      <p className="rounded-xl border border-zinc-200 bg-white px-5 py-10 text-center text-sm text-zinc-500">
        Henüz plan oluşturulmadı.
      </p>
    );
  }

  return (
    <div className="overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-sm">
      <table className="w-full text-left text-sm">
        <thead className="border-b border-zinc-200 bg-zinc-50 text-xs uppercase tracking-wide text-zinc-500">
          <tr>
            <th className="px-5 py-3 font-medium">Plan</th>
            <th className="px-5 py-3 font-medium">Aylık Fiyat</th>
            <th className="px-5 py-3 font-medium">Masa / Garson / Kullanıcı / Alan</th>
            <th className="px-5 py-3 font-medium">Durum</th>
            <th className="px-5 py-3 font-medium" />
          </tr>
        </thead>
        <tbody className="divide-y divide-zinc-100">
          {plans.map((plan) => (
            <tr key={plan.id} className="hover:bg-zinc-50">
              <td className="px-5 py-3">
                <Link
                  href={`/super-admin/planlar/${plan.id}`}
                  className="font-medium text-zinc-900 hover:underline"
                >
                  {plan.name}
                </Link>
                {plan.code && <p className="text-xs text-zinc-400">{plan.code}</p>}
              </td>
              <td className="px-5 py-3 text-zinc-600">{currencyFormatter.format(plan.monthly_price)}</td>
              <td className="px-5 py-3 text-zinc-600">
                {limitLabel(plan.max_tables)} / {limitLabel(plan.max_waiters)} /{" "}
                {limitLabel(plan.max_users)} / {limitLabel(plan.max_areas)}
              </td>
              <td className="px-5 py-3">
                <span
                  className={`inline-flex rounded-full border px-2.5 py-0.5 text-xs font-medium ${
                    plan.active
                      ? "border-emerald-200 bg-emerald-50 text-emerald-700"
                      : "border-zinc-200 bg-zinc-100 text-zinc-500"
                  }`}
                >
                  {plan.active ? "Aktif" : "Pasif"}
                </span>
              </td>
              <td className="px-5 py-3 text-right">
                <button
                  type="button"
                  disabled={isPending}
                  onClick={() =>
                    startTransition(() => {
                      togglePlanActive(plan.id, !plan.active);
                    })
                  }
                  className="text-sm font-medium text-zinc-600 hover:text-zinc-900 disabled:opacity-50"
                >
                  {plan.active ? "Pasif Yap" : "Aktif Yap"}
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
