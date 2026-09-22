"use client";

import { useActionState } from "react";
import { suspendBusiness, reactivateBusiness, extendTrial } from "./actions";
import type { SubscriptionStatus } from "@/lib/supabase/database.types";

interface ActionState {
  error: string | null;
}

const initialState: ActionState = { error: null };

export function BusinessActions({
  businessId,
  subscriptionStatus,
}: {
  businessId: string;
  subscriptionStatus: SubscriptionStatus;
}) {
  const suspendWithId = suspendBusiness.bind(null, businessId);
  const reactivateWithId = reactivateBusiness.bind(null, businessId);
  const extendWithId = extendTrial.bind(null, businessId);

  const [suspendState, suspendAction, suspendPending] = useActionState<ActionState, FormData>(
    suspendWithId,
    initialState
  );
  const [reactivateState, reactivateAction, reactivatePending] = useActionState<
    ActionState,
    FormData
  >(reactivateWithId, initialState);
  const [extendState, extendAction, extendPending] = useActionState<ActionState, FormData>(
    extendWithId,
    initialState
  );

  const error = suspendState.error ?? reactivateState.error ?? extendState.error;
  const isSuspended = subscriptionStatus === "SUSPENDED";

  return (
    <div className="space-y-4 rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
      <h2 className="text-sm font-semibold text-zinc-900">İşletme Durumu</h2>

      {error && (
        <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      <div className="flex flex-wrap gap-3">
        {isSuspended ? (
          <form action={reactivateAction}>
            <button
              type="submit"
              disabled={reactivatePending}
              className="inline-flex h-10 items-center justify-center rounded-lg bg-emerald-600 px-5 text-sm font-medium text-white hover:bg-emerald-500 disabled:opacity-60"
            >
              {reactivatePending ? "İşleniyor..." : "Tekrar Aktif Et"}
            </button>
          </form>
        ) : (
          <form action={suspendAction}>
            <button
              type="submit"
              disabled={suspendPending}
              className="inline-flex h-10 items-center justify-center rounded-lg bg-red-600 px-5 text-sm font-medium text-white hover:bg-red-500 disabled:opacity-60"
            >
              {suspendPending ? "İşleniyor..." : "Askıya Al"}
            </button>
          </form>
        )}
      </div>

      <div className="border-t border-zinc-100 pt-4">
        <p className="mb-2 text-xs font-medium uppercase tracking-wide text-zinc-500">
          Deneme Süresini Uzat
        </p>
        <form action={extendAction} className="flex items-end gap-3">
          <div>
            <label className="mb-1 block text-xs text-zinc-600" htmlFor="days">
              Gün
            </label>
            <input
              id="days"
              name="days"
              type="number"
              min={1}
              defaultValue={7}
              className="w-24 rounded-lg border border-zinc-300 bg-white px-3 py-2 text-sm outline-none focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500"
            />
          </div>
          <button
            type="submit"
            disabled={extendPending}
            className="inline-flex h-10 items-center justify-center rounded-lg border border-zinc-300 bg-white px-4 text-sm font-medium text-zinc-900 hover:bg-zinc-50 disabled:opacity-60"
          >
            {extendPending ? "İşleniyor..." : "Uzat"}
          </button>
        </form>
      </div>
    </div>
  );
}
