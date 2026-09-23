"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import type { OrderItemStatus } from "@/lib/supabase/database.types";

interface KitchenItem {
  id: string;
  orderId: string;
  productName: string;
  quantity: number;
  note: string | null;
  status: OrderItemStatus;
  createdAt: string;
}

interface Ticket {
  orderId: string;
  tableName: string;
  openedAt: string;
  items: KitchenItem[];
}

const ACTIVE_STATUSES: OrderItemStatus[] = ["NEW", "PREPARING", "READY"];

const statusLabels: Record<string, string> = {
  NEW: "Yeni",
  PREPARING: "Hazırlanıyor",
  READY: "Hazır",
};

const statusBadgeClass: Record<string, string> = {
  NEW: "bg-blue-50 text-blue-700 border-blue-200",
  PREPARING: "bg-amber-50 text-amber-700 border-amber-200",
  READY: "bg-emerald-50 text-emerald-700 border-emerald-200",
};

const nextActionLabel: Record<string, string> = {
  NEW: "Hazırlanıyor",
  PREPARING: "Hazır",
  READY: "Servis Edildi",
};

function nextStatus(status: string): OrderItemStatus | null {
  if (status === "NEW") return "PREPARING";
  if (status === "PREPARING") return "READY";
  if (status === "READY") return "SERVED";
  return null;
}

export function KitchenBoard({ businessId }: { businessId: string }) {
  const supabase = useMemo(() => createClient(), []);
  const [tickets, setTickets] = useState<Ticket[] | null>(null);
  const [error, setError] = useState(false);
  // "Now", captured as state and only updated from the interval effect
  // below -- ticket cards derive elapsed time from this instead of
  // calling Date.now() during render, which would be impure.
  const [now, setNow] = useState(() => Date.now());

  const refresh = useCallback(async () => {
    const [itemsRes, ordersRes, tablesRes] = await Promise.all([
      supabase
        .from("order_items")
        .select("id, order_id, product_name_snapshot, quantity, note, status, created_at")
        .eq("business_id", businessId)
        .in("status", ACTIVE_STATUSES)
        .order("created_at"),
      supabase
        .from("orders")
        .select("id, table_id, opened_at")
        .eq("business_id", businessId)
        .eq("status", "OPEN"),
      supabase.from("restaurant_tables").select("id, name").eq("business_id", businessId),
    ]);

    if (itemsRes.error || ordersRes.error || tablesRes.error) {
      setError(true);
      return;
    }
    setError(false);

    const tableNames = new Map(tablesRes.data.map((t) => [t.id, t.name]));
    const ordersById = new Map(ordersRes.data.map((o) => [o.id, o]));

    const grouped = new Map<string, KitchenItem[]>();
    for (const row of itemsRes.data) {
      const item: KitchenItem = {
        id: row.id,
        orderId: row.order_id,
        productName: row.product_name_snapshot,
        quantity: row.quantity,
        note: row.note,
        status: row.status,
        createdAt: row.created_at,
      };
      const list = grouped.get(item.orderId) ?? [];
      list.push(item);
      grouped.set(item.orderId, list);
    }

    const result: Ticket[] = [];
    for (const [orderId, items] of grouped) {
      const order = ordersById.get(orderId);
      // Order closed/cancelled between reads settling; it'll drop off
      // once order_items catches up too.
      if (!order) continue;
      result.push({
        orderId,
        tableName: tableNames.get(order.table_id) ?? "—",
        openedAt: order.opened_at,
        items: [...items].sort((a, b) => a.createdAt.localeCompare(b.createdAt)),
      });
    }
    result.sort((a, b) => a.openedAt.localeCompare(b.openedAt));
    setTickets(result);
  }, [supabase, businessId]);

  useEffect(() => {
    // Deferred rather than called synchronously in the effect body, so
    // the initial fetch's setState is a genuinely separate task instead
    // of a same-tick cascading render.
    const initialLoad = setTimeout(refresh, 0);

    const channel = supabase
      .channel(`kitchen-${businessId}`)
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "order_items", filter: `business_id=eq.${businessId}` },
        () => refresh()
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "orders", filter: `business_id=eq.${businessId}` },
        () => refresh()
      )
      .subscribe();

    // Same safety net as the Kasa board: realtime doesn't replay events
    // missed while the websocket was down (tablet sleep, wifi drop), so
    // resync when the tab becomes visible again, plus a slow poll.
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
  }, [refresh, supabase, businessId]);

  // Only drives the elapsed-time labels forward; ticket data itself is
  // realtime and needs no polling.
  useEffect(() => {
    const interval = setInterval(() => setNow(Date.now()), 30_000);
    return () => clearInterval(interval);
  }, []);

  async function advance(itemId: string, next: OrderItemStatus) {
    const { error } = await supabase.from("order_items").update({ status: next }).eq("id", itemId);
    if (!error) refresh();
  }

  if (error) {
    return (
      <div className="flex h-full items-center justify-center px-6 py-16">
        <p className="text-sm text-zinc-600">Sipariş panosu yüklenemedi. Sayfayı yenileyin.</p>
      </div>
    );
  }

  if (!tickets) {
    return (
      <div className="flex h-full items-center justify-center px-6 py-16">
        <p className="text-sm text-zinc-500">Yükleniyor...</p>
      </div>
    );
  }

  if (tickets.length === 0) {
    return (
      <div className="flex h-full items-center justify-center px-6 py-24">
        <p className="text-lg text-zinc-500">Bekleyen sipariş yok</p>
      </div>
    );
  }

  return (
    <div className="grid grid-cols-1 gap-4 p-6 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
      {tickets.map((ticket) => (
        <TicketCard key={ticket.orderId} ticket={ticket} now={now} onAdvance={advance} />
      ))}
    </div>
  );
}

function TicketCard({
  ticket,
  now,
  onAdvance,
}: {
  ticket: Ticket;
  now: number;
  onAdvance: (itemId: string, next: OrderItemStatus) => void;
}) {
  const elapsedMinutes = Math.floor((now - new Date(ticket.openedAt).getTime()) / 60_000);
  const urgent = elapsedMinutes >= 15;

  return (
    <div
      className={`rounded-2xl border bg-white p-5 shadow-sm ${urgent ? "border-red-400" : "border-zinc-200"}`}
    >
      <div className="flex items-center justify-between">
        <h2 className="text-xl font-bold text-zinc-900">{ticket.tableName}</h2>
        <span className={`text-sm font-semibold ${urgent ? "text-red-600" : "text-zinc-500"}`}>
          {elapsedMinutes} dk
        </span>
      </div>

      <div className="mt-4 divide-y divide-zinc-100">
        {ticket.items.map((item) => {
          const next = nextStatus(item.status);
          return (
            <div key={item.id} className="flex items-start justify-between gap-3 py-3">
              <div>
                <p className="text-base font-semibold text-zinc-900">
                  {item.quantity}x {item.productName}
                </p>
                {item.note && <p className="mt-0.5 text-sm text-zinc-500">{item.note}</p>}
                <span
                  className={`mt-1.5 inline-flex rounded-full border px-2 py-0.5 text-xs font-semibold ${statusBadgeClass[item.status]}`}
                >
                  {statusLabels[item.status] ?? item.status}
                </span>
              </div>
              {next && (
                <button
                  type="button"
                  onClick={() => onAdvance(item.id, next)}
                  className="shrink-0 rounded-lg bg-zinc-900 px-4 py-2.5 text-sm font-semibold text-white hover:bg-zinc-800"
                >
                  {nextActionLabel[item.status]}
                </button>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
