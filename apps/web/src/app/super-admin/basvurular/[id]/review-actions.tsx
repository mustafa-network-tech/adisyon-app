"use client";

import { useActionState, useState } from "react";
import { rejectApplication } from "./actions";

interface ReviewActionState {
  error: string | null;
}

const initialState: ReviewActionState = { error: null };

// Faz 12: no more "Onayla" (approve) action -- approving would create a
// business, which is no longer allowed outside the self-service flow.
// This form only lets a platform admin close out a legacy PENDING
// application by rejecting it.
export function ReviewActions({ applicationId }: { applicationId: string }) {
  const [mode, setMode] = useState<"idle" | "reject">("idle");

  const rejectWithId = rejectApplication.bind(null, applicationId);
  const [rejectState, rejectAction, rejectPending] = useActionState<
    ReviewActionState,
    FormData
  >(rejectWithId, initialState);

  return (
    <div className="space-y-4">
      {rejectState.error && (
        <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {rejectState.error}
        </div>
      )}

      {mode === "idle" ? (
        <button
          type="button"
          onClick={() => setMode("reject")}
          className="inline-flex h-10 items-center justify-center rounded-lg border border-zinc-300 bg-white px-5 text-sm font-medium text-zinc-900 hover:bg-zinc-50"
        >
          Başvuruyu Reddet / Kapat
        </button>
      ) : (
        <form action={rejectAction} className="space-y-3">
          <div>
            <label className="mb-1.5 block text-sm font-medium text-zinc-800" htmlFor="rejection_reason">
              Not (opsiyonel)
            </label>
            <textarea
              id="rejection_reason"
              name="rejection_reason"
              rows={3}
              className="w-full rounded-lg border border-zinc-300 bg-white px-3.5 py-2.5 text-sm text-zinc-900 outline-none focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500"
            />
          </div>
          <div className="flex gap-3">
            <button
              type="submit"
              disabled={rejectPending}
              className="inline-flex h-10 items-center justify-center rounded-lg bg-red-600 px-5 text-sm font-medium text-white transition-colors hover:bg-red-500 disabled:cursor-not-allowed disabled:opacity-60"
            >
              {rejectPending ? "Kapatılıyor..." : "Reddi Onayla"}
            </button>
            <button
              type="button"
              onClick={() => setMode("idle")}
              className="inline-flex h-10 items-center justify-center rounded-lg border border-zinc-300 bg-white px-5 text-sm font-medium text-zinc-900 hover:bg-zinc-50"
            >
              Vazgeç
            </button>
          </div>
        </form>
      )}
    </div>
  );
}
