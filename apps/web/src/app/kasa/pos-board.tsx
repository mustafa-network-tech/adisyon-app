"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

interface OpenTicket {
  orderId: string;
  tableName: string;
  checkRequested: boolean;
  openedAt: string;
  total: number;
}

const currencyFormatter = new Intl.NumberFormat("tr-TR", { style: "currency", currency: "TRY" });

export function PosBoard({ businessId }: { businessId: string }) {
  const supabase = useMemo(() => createClient(), []);
  const [tickets, setTickets] = useState<OpenTicket[] | null>(null);
  const [error, setError] = useState(false);

  const refresh = useCallback(async () => {
    const [ordersRes, itemsRes, tablesRes] = await Promise.all([
      supabase
        .from("orders")
        .select("id, table_id, check_requested, opened_at")
        .eq("business_id", businessId)
        .eq("status", "OPEN"),
      supabase
        .from("order_items")
        .select("order_id, unit_price_snapshot, quantity, status")
        .eq("business_id", businessId),
      supabase.from("restaurant_tables").select("id, name").eq("business_id", businessId),
    ]);

    if (ordersRes.error || itemsRes.error || tablesRes.error) {
      setError(true);
      return;
    }
    setError(false);

    const tableNames = new Map(tablesRes.data.map((t) => [t.id, t.name]));
    const totalsByOrder = new Map<string, number>();
    for (const item of itemsRes.data) {
      if (item.status === "VOID") continue;
      const current = totalsByOrder.get(item.order_id) ?? 0;
      totalsByOrder.set(item.order_id, current + item.unit_price_snapshot * item.quantity);
    }

    const result: OpenTicket[] = ordersRes.data.map((order) => ({
      orderId: order.id,
      tableName: tableNames.get(order.table_id) ?? "—",
      checkRequested: order.check_requested,
      openedAt: order.opened_at,
      total: totalsByOrder.get(order.id) ?? 0,
    }));
    result.sort((a, b) => {
      if (a.checkRequested !== b.checkRequested) return a.checkRequested ? -1 : 1;
      return a.openedAt.localeCompare(b.openedAt);
    });
    setTickets(result);
  }, [supabase, businessId]);

  useEffect(() => {
    const initialLoad = setTimeout(refresh, 0);

    const channel = supabase
      .channel(`kasa-${businessId}`)
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "orders", filter: `business_id=eq.${businessId}` },
        () => refresh()
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "order_items", filter: `business_id=eq.${businessId}` },
        () => refresh()
      )
      .subscribe();

    // Realtime postgres_changes doesn't replay events missed while the
    // websocket was disconnected (PC sleep, wifi drop -- a real
    // restaurant PC scenario), so the board can go stale until the next
    // live event happens to arrive. Two cheap safety nets: refetch when
    // the tab regains focus/visibility, and a slow poll as a backstop
    // even if that never fires.
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

  if (error) {
    return (
      <div className="flex h-full items-center justify-center px-6 py-16">
        <p className="text-sm text-zinc-600">Açık masalar yüklenemedi. Sayfayı yenileyin.</p>
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
        <p className="text-lg text-zinc-500">Açık masa yok</p>
      </div>
    );
  }

  return (
    <div className="grid grid-cols-2 gap-4 p-6 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5">
      {tickets.map((ticket) => (
        <Link
          key={ticket.orderId}
          href={`/kasa/hesap/${ticket.orderId}`}
          className={`rounded-2xl border bg-white p-5 shadow-sm transition-colors hover:border-zinc-400 ${
            ticket.checkRequested ? "border-red-400" : "border-zinc-200"
          }`}
        >
          <p className="text-lg font-bold text-zinc-900">{ticket.tableName}</p>
          {ticket.checkRequested && (
            <span className="mt-1 inline-flex rounded-full border border-red-200 bg-red-50 px-2 py-0.5 text-xs font-semibold text-red-700">
              Hesap İstendi
            </span>
          )}
          <p className="mt-4 text-2xl font-bold text-zinc-900">
            {currencyFormatter.format(ticket.total)}
          </p>
        </Link>
      ))}
    </div>
  );
}
