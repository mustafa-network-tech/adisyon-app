"use client";

import { useState } from "react";
import { formatPercent, formatTl, planFeatures, type CatalogPlan } from "@/lib/plans";

type Period = "MONTHLY" | "YEARLY";

export function PlanComparison({
  plans,
  currentPlanId = null,
}: {
  plans: CatalogPlan[];
  currentPlanId?: string | null;
}) {
  const [period, setPeriod] = useState<Period>("MONTHLY");

  if (plans.length === 0) {
    return (
      <p className="rounded-xl border border-zinc-200 bg-white px-5 py-10 text-center text-sm text-zinc-500">
        Planlar şu an görüntülenemiyor.
      </p>
    );
  }

  // Plans normally share one yearly discount; only name it in the toggle
  // when that's actually true.
  const discounts = [...new Set(plans.map((plan) => plan.yearlyDiscount))];
  const sharedDiscount = discounts.length === 1 && discounts[0] > 0 ? discounts[0] : null;

  const toggleClass = (active: boolean) =>
    `rounded-md px-4 py-2 text-sm font-medium transition-colors ${
      active ? "bg-white text-zinc-900 shadow-sm" : "text-zinc-600 hover:text-zinc-900"
    }`;

  return (
    <div>
      <div className="flex justify-center">
        <div className="inline-flex rounded-lg bg-zinc-100 p-1" role="group" aria-label="Ödeme dönemi">
          <button
            type="button"
            aria-pressed={period === "MONTHLY"}
            onClick={() => setPeriod("MONTHLY")}
            className={toggleClass(period === "MONTHLY")}
          >
            Aylık
          </button>
          <button
            type="button"
            aria-pressed={period === "YEARLY"}
            onClick={() => setPeriod("YEARLY")}
            className={toggleClass(period === "YEARLY")}
          >
            Yıllık
            {sharedDiscount !== null && (
              <span className="ml-2 rounded-full bg-emerald-100 px-2 py-0.5 text-xs font-semibold text-emerald-700">
                {formatPercent(sharedDiscount)} indirim
              </span>
            )}
          </button>
        </div>
      </div>

      <div className="mt-8 grid gap-4 md:grid-cols-3">
        {plans.map((plan) => {
          const isCurrent = plan.id === currentPlanId;
          const fullYear = plan.monthlyPrice * 12;
          return (
            <div
              key={plan.id}
              className={`flex flex-col rounded-xl border bg-white p-6 shadow-sm ${
                isCurrent ? "border-zinc-900 ring-1 ring-zinc-900" : "border-zinc-200"
              }`}
            >
              <div className="flex items-center justify-between gap-2">
                <h3 className="text-lg font-semibold tracking-tight text-zinc-900">{plan.name}</h3>
                {isCurrent && (
                  <span className="rounded-full bg-zinc-900 px-2.5 py-0.5 text-xs font-medium text-white">
                    Mevcut plan
                  </span>
                )}
              </div>

              {period === "MONTHLY" ? (
                <p className="mt-4">
                  <span className="text-3xl font-semibold tracking-tight text-zinc-900">
                    {formatTl(plan.monthlyPrice)}
                  </span>
                  <span className="text-sm text-zinc-500"> / ay</span>
                </p>
              ) : (
                <div className="mt-4">
                  <p>
                    <span className="text-3xl font-semibold tracking-tight text-zinc-900">
                      {formatTl(plan.yearlyPrice)}
                    </span>
                    <span className="text-sm text-zinc-500"> / yıl</span>
                  </p>
                  {plan.yearlyDiscount > 0 && (
                    <p className="mt-1 text-sm text-zinc-500">
                      <span className="line-through">{formatTl(fullYear)}</span>{" "}
                      <span className="font-medium text-emerald-700">
                        {formatPercent(plan.yearlyDiscount)} indirim
                      </span>
                    </p>
                  )}
                </div>
              )}

              <ul className="mt-6 space-y-2 text-sm text-zinc-700">
                {planFeatures(plan).map((feature) => (
                  <li key={feature} className="flex gap-2">
                    <span aria-hidden className="text-emerald-600">
                      ✓
                    </span>
                    {feature}
                  </li>
                ))}
              </ul>
            </div>
          );
        })}
      </div>
    </div>
  );
}
