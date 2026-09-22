"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { OrderStatus, PaymentMethod } from "@/lib/supabase/database.types";

interface ItemRow {
  id: string;
  productName: string;
  unitPrice: number;
  quantity: number;
  note: string | null;
  status: string;
}

interface PaymentRow {
  id: string;
  method: PaymentMethod;
  amount: number;
  status: string;
  createdAt: string;
}

const currencyFormatter = new Intl.NumberFormat("tr-TR", { style: "currency", currency: "TRY" });

const methodLabels: Record<PaymentMethod, string> = {
  CASH: "Nakit",
  CARD: "Kart",
  OTHER: "Diğer",
};

export function PaymentPanel({
  orderId,
  tableName,
  initialStatus,
}: {
  orderId: string;
  tableName: string;
  initialStatus: OrderStatus;
}) {
  const supabase = useMemo(() => createClient(), []);
  const router = useRouter();

  const [items, setItems] = useState<ItemRow[] | null>(null);
  const [payments, setPayments] = useState<PaymentRow[] | null>(null);
  const [orderStatus, setOrderStatus] = useState<OrderStatus>(initialStatus);
  const [error, setError] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const [method, setMethod] = useState<PaymentMethod>("CASH");
  const [amount, setAmount] = useState("");

  // Idempotency (20260922000028_payment_idempotency.sql): a double-tap
  // on "Ödeme Al", or a client retry after a dropped response, must
  // never insert two payment rows for what the cashier intended as one
  // payment. submittingRef blocks the synchronous double-click (state-
  // based `disabled` only takes effect on the next render, which is too
  // late for two clicks in the same tick); pendingRequestIdRef is a
  // stable key reused across retries of the *same* attempt so a
  // duplicate insert hits the DB's unique constraint instead of
  // succeeding twice -- cleared on success, or whenever the cashier
  // changes the amount/method (a genuinely new attempt gets a new key).
  const submittingRef = useRef(false);
  const pendingRequestIdRef = useRef<string | null>(null);

  const refresh = useCallback(async () => {
    const [orderRes, itemsRes, paymentsRes] = await Promise.all([
      supabase.from("orders").select("status").eq("id", orderId).single(),
      supabase
        .from("order_items")
        .select("id, product_name_snapshot, unit_price_snapshot, quantity, note, status")
        .eq("order_id", orderId)
        .order("created_at"),
      supabase
        .from("payments")
        .select("id, method, amount, status, created_at")
        .eq("order_id", orderId)
        .order("created_at"),
    ]);

    if (orderRes.error || itemsRes.error || paymentsRes.error) {
      setError(true);
      return;
    }
    setError(false);
    setOrderStatus(orderRes.data.status);
    setItems(
      itemsRes.data.map((row) => ({
        id: row.id,
        productName: row.product_name_snapshot,
        unitPrice: row.unit_price_snapshot,
        quantity: row.quantity,
        note: row.note,
        status: row.status,
      }))
    );
    setPayments(
      paymentsRes.data.map((row) => ({
        id: row.id,
        method: row.method,
        amount: row.amount,
        status: row.status,
        createdAt: row.created_at,
      }))
    );
  }, [supabase, orderId]);

  useEffect(() => {
    const initialLoad = setTimeout(refresh, 0);

    const channel = supabase
      .channel(`kasa-order-${orderId}`)
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "order_items", filter: `order_id=eq.${orderId}` },
        () => refresh()
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "payments", filter: `order_id=eq.${orderId}` },
        () => refresh()
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "orders", filter: `id=eq.${orderId}` },
        () => refresh()
      )
      .subscribe();

    // Same reconnect/staleness safety net as pos-board.tsx -- realtime
    // doesn't replay events missed while disconnected.
    function handleVisibility() {
      if (document.visibilityState === "visible") refresh();
    }
    document.addEventListener("visibilitychange", handleVisibility);
    window.addEventListener("focus", refresh);
    const pollInterval = setInterval(refresh, 30000);

    return () => {
      clearTimeout(initialLoad);
      supabase.removeChannel(channel);
      document.removeEventListener("visibilitychange", handleVisibility);
      window.removeEventListener("focus", refresh);
      clearInterval(pollInterval);
    };
  }, [refresh, supabase, orderId]);

  const activeTotal =
    items?.filter((i) => i.status !== "VOID").reduce((sum, i) => sum + i.unitPrice * i.quantity, 0) ?? 0;
  const paidTotal =
    payments?.filter((p) => p.status === "COMPLETED").reduce((sum, p) => sum + p.amount, 0) ?? 0;
  const remaining = Math.round((activeTotal - paidTotal) * 100) / 100;
  const hasAnyPayment = (payments ?? []).some((p) => p.status === "COMPLETED");

  async function submitPayment(event: React.FormEvent) {
    event.preventDefault();
    setActionError(null);

    if (submittingRef.current) return;

    const parsed = Number.parseFloat(amount.replace(",", "."));
    if (!Number.isFinite(parsed) || parsed <= 0) {
      setActionError("Geçerli bir tutar girin.");
      return;
    }

    submittingRef.current = true;
    setBusy(true);

    if (!pendingRequestIdRef.current) {
      pendingRequestIdRef.current = crypto.randomUUID();
    }

    const { error: insertError } = await supabase
      .from("payments")
      .insert({ order_id: orderId, method, amount: parsed, client_request_id: pendingRequestIdRef.current });

    submittingRef.current = false;
    setBusy(false);

    if (insertError) {
      if (insertError.code === "23505") {
        // Unique violation on our own idempotency key: this exact
        // payment attempt already succeeded (the first response was
        // lost), not a failure -- treat it as success rather than
        // risking a real duplicate on a second retry.
        pendingRequestIdRef.current = null;
        setAmount("");
        refresh();
        return;
      }
      setActionError("Ödeme kaydedilemedi. Lütfen tekrar deneyin.");
      return;
    }
    pendingRequestIdRef.current = null;
    setAmount("");
    refresh();
  }

  async function voidPayment(paymentId: string) {
    const reason = window.prompt("İptal nedeni:");
    if (!reason || !reason.trim()) return;

    setBusy(true);
    const { error: voidError } = await supabase
      .from("payments")
      .update({ status: "VOID", void_reason: reason.trim() })
      .eq("id", paymentId);
    setBusy(false);

    if (voidError) {
      setActionError("Ödeme iptal edilemedi.");
      return;
    }
    // Audit entry (PAYMENT_VOIDED) is written automatically by a DB
    // trigger on this same UPDATE -- see
    // 20260922000027_audit_rpc_hardening.sql. Client code can no longer
    // log its own audit events (log_audit_event's grant to authenticated
    // was revoked).
    refresh();
  }

  async function voidItem(itemId: string) {
    const reason = window.prompt("İptal nedeni:");
    if (!reason || !reason.trim()) return;

    setBusy(true);
    const { error: voidError } = await supabase
      .from("order_items")
      .update({ status: "VOID", void_reason: reason.trim() })
      .eq("id", itemId);
    setBusy(false);

    if (voidError) {
      setActionError("Ürün iptal edilemedi.");
      return;
    }
    // Audit entry (ORDER_ITEM_VOIDED) is written automatically by a DB
    // trigger -- see 20260922000027_audit_rpc_hardening.sql.
    refresh();
  }

  async function closeOrder() {
    setBusy(true);
    const { error: closeError } = await supabase
      .from("orders")
      .update({ status: "CLOSED" })
      .eq("id", orderId);
    setBusy(false);

    if (closeError) {
      setActionError("Hesap kapatılamadı. Tüm tutarın ödendiğinden emin olun.");
      return;
    }
    router.push("/kasa");
  }

  async function cancelOrder() {
    if (!window.confirm("Bu siparişi tamamen iptal etmek istediğinize emin misiniz?")) return;

    setBusy(true);
    const { error: cancelError } = await supabase
      .from("orders")
      .update({ status: "CANCELLED" })
      .eq("id", orderId);
    setBusy(false);

    if (cancelError) {
      setActionError("Sipariş iptal edilemedi.");
      return;
    }
    // Audit entry (ORDER_CANCELLED) is written automatically by a DB
    // trigger -- see 20260922000027_audit_rpc_hardening.sql.
    router.push("/kasa");
  }

  if (error) {
    return <p className="p-6 text-sm text-zinc-600">Hesap yüklenemedi. Sayfayı yenileyin.</p>;
  }
  if (!items || !payments) {
    return <p className="p-6 text-sm text-zinc-500">Yükleniyor...</p>;
  }

  if (orderStatus !== "OPEN") {
    return (
      <div className="p-6">
        <p className="text-sm text-zinc-600">
          Bu hesap {orderStatus === "CLOSED" ? "kapatıldı" : "iptal edildi"}.
        </p>
      </div>
    );
  }

  return (
    <div className="mx-auto grid max-w-4xl grid-cols-1 gap-6 p-6 lg:grid-cols-2">
      <div className="rounded-2xl border border-zinc-200 bg-white p-5 shadow-sm">
        <h2 className="text-lg font-bold text-zinc-900">{tableName}</h2>
        <div className="mt-4 divide-y divide-zinc-100">
          {items.map((item) => (
            <div key={item.id} className="flex items-center justify-between gap-3 py-2.5">
              <div>
                <p
                  className={`text-sm font-semibold ${item.status === "VOID" ? "text-zinc-400 line-through" : "text-zinc-900"}`}
                >
                  {item.quantity}x {item.productName}
                </p>
                {item.note && <p className="text-xs text-zinc-500">{item.note}</p>}
              </div>
              <div className="flex items-center gap-3">
                <span
                  className={`text-sm font-medium ${item.status === "VOID" ? "text-zinc-400 line-through" : "text-zinc-900"}`}
                >
                  {currencyFormatter.format(item.unitPrice * item.quantity)}
                </span>
                {item.status !== "VOID" && (
                  <button
                    type="button"
                    onClick={() => voidItem(item.id)}
                    disabled={busy}
                    className="text-xs font-medium text-red-600 hover:text-red-500 disabled:opacity-50"
                  >
                    İptal
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
        <div className="mt-4 flex items-center justify-between border-t border-zinc-200 pt-3">
          <span className="text-sm font-semibold text-zinc-900">Toplam</span>
          <span className="text-xl font-bold text-zinc-900">{currencyFormatter.format(activeTotal)}</span>
        </div>
      </div>

      <div className="space-y-4">
        <div className="rounded-2xl border border-zinc-200 bg-white p-5 shadow-sm">
          <div className="flex items-center justify-between">
            <span className="text-sm text-zinc-600">Ödenen</span>
            <span className="font-semibold text-zinc-900">{currencyFormatter.format(paidTotal)}</span>
          </div>
          <div className="mt-1 flex items-center justify-between">
            <span className="text-sm text-zinc-600">Kalan</span>
            <span className={`text-lg font-bold ${remaining > 0 ? "text-red-600" : "text-emerald-600"}`}>
              {currencyFormatter.format(Math.max(remaining, 0))}
            </span>
          </div>

          {payments.length > 0 && (
            <div className="mt-4 space-y-1.5 border-t border-zinc-100 pt-3">
              {payments.map((payment) => (
                <div key={payment.id} className="flex items-center justify-between text-sm">
                  <span
                    className={payment.status === "VOID" ? "text-zinc-400 line-through" : "text-zinc-700"}
                  >
                    {methodLabels[payment.method]} · {currencyFormatter.format(payment.amount)}
                  </span>
                  {payment.status === "COMPLETED" && (
                    <button
                      type="button"
                      onClick={() => voidPayment(payment.id)}
                      disabled={busy}
                      className="text-xs font-medium text-red-600 hover:text-red-500 disabled:opacity-50"
                    >
                      İptal
                    </button>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>

        {remaining > 0 && (
          <form
            onSubmit={submitPayment}
            className="space-y-3 rounded-2xl border border-zinc-200 bg-white p-5 shadow-sm"
          >
            <div className="flex gap-2">
              {(["CASH", "CARD", "OTHER"] as PaymentMethod[]).map((m) => (
                <button
                  key={m}
                  type="button"
                  onClick={() => {
                    pendingRequestIdRef.current = null;
                    setMethod(m);
                  }}
                  className={`flex-1 rounded-lg border px-3 py-2.5 text-sm font-semibold ${
                    method === m
                      ? "border-zinc-900 bg-zinc-900 text-white"
                      : "border-zinc-300 bg-white text-zinc-900 hover:bg-zinc-50"
                  }`}
                >
                  {methodLabels[m]}
                </button>
              ))}
            </div>
            <div className="flex gap-2">
              <input
                type="number"
                step="0.01"
                min={0}
                placeholder={remaining.toFixed(2)}
                value={amount}
                onChange={(e) => {
                  pendingRequestIdRef.current = null;
                  setAmount(e.target.value);
                }}
                className="flex-1 rounded-lg border border-zinc-300 px-3.5 py-2.5 text-sm outline-none focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500"
              />
              <button
                type="button"
                onClick={() => {
                  pendingRequestIdRef.current = null;
                  setAmount(remaining.toFixed(2));
                }}
                className="rounded-lg border border-zinc-300 bg-white px-3 text-xs font-medium text-zinc-700 hover:bg-zinc-50"
              >
                Tam Tutar
              </button>
            </div>
            <button
              type="submit"
              disabled={busy}
              className="w-full rounded-lg bg-zinc-900 px-4 py-3 text-sm font-semibold text-white hover:bg-zinc-800 disabled:opacity-60"
            >
              Ödeme Al
            </button>
          </form>
        )}

        {actionError && (
          <p className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
            {actionError}
          </p>
        )}

        <div className="flex gap-3">
          <button
            type="button"
            onClick={closeOrder}
            disabled={busy || remaining > 0}
            className="flex-1 rounded-lg bg-emerald-600 px-4 py-3 text-sm font-semibold text-white hover:bg-emerald-500 disabled:cursor-not-allowed disabled:opacity-50"
          >
            Hesabı Kapat
          </button>
          {!hasAnyPayment && (
            <button
              type="button"
              onClick={cancelOrder}
              disabled={busy}
              className="rounded-lg border border-zinc-300 bg-white px-4 py-3 text-sm font-semibold text-zinc-900 hover:bg-zinc-50 disabled:opacity-50"
            >
              Siparişi İptal Et
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
