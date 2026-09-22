import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getReportsContext } from "@/lib/auth/session";

type RangeKey = "today" | "7d" | "30d";

const rangeTabs: { value: RangeKey; label: string }[] = [
  { value: "today", label: "Bugün" },
  { value: "7d", label: "Son 7 Gün" },
  { value: "30d", label: "Son 30 Gün" },
];

// Server-local day boundaries -- there's no per-business timezone
// setting in the schema yet (a known simplification; fine for a single
// -timezone deployment, would need revisiting for multi-region use).
function rangeToDates(range: RangeKey): { start: Date; end: Date } {
  const end = new Date();
  end.setHours(24, 0, 0, 0); // midnight tonight (exclusive upper bound)

  const start = new Date(end);
  if (range === "today") start.setDate(start.getDate() - 1);
  else if (range === "7d") start.setDate(start.getDate() - 7);
  else start.setDate(start.getDate() - 30);

  return { start, end };
}

const currencyFormatter = new Intl.NumberFormat("tr-TR", { style: "currency", currency: "TRY" });

export default async function RaporlarPage({
  searchParams,
}: {
  searchParams: Promise<{ range?: string }>;
}) {
  const { range: rawRange } = await searchParams;
  const range: RangeKey = rawRange === "7d" || rawRange === "30d" ? rawRange : "today";

  const ctx = await getReportsContext();
  if (!ctx) redirect("/hesabim");

  const { start, end } = rangeToDates(range);
  const supabase = await createClient();

  const [summaryRes, topProductsRes, recentOrdersRes] = await Promise.all([
    supabase.rpc("get_revenue_summary", {
      p_business_id: ctx.businessId,
      p_start: start.toISOString(),
      p_end: end.toISOString(),
    }),
    supabase.rpc("get_top_products", {
      p_business_id: ctx.businessId,
      p_start: start.toISOString(),
      p_end: end.toISOString(),
      p_limit: 10,
    }),
    supabase
      .from("orders")
      .select("id, closed_at, table_id, restaurant_tables(name)")
      .eq("business_id", ctx.businessId)
      .eq("status", "CLOSED")
      .gte("closed_at", start.toISOString())
      .lt("closed_at", end.toISOString())
      .order("closed_at", { ascending: false })
      .limit(50),
  ]);

  const summary = summaryRes.data?.[0] ?? {
    total_revenue: 0,
    cash_total: 0,
    card_total: 0,
    other_total: 0,
    order_count: 0,
    average_order: 0,
  };
  const topProducts = topProductsRes.data ?? [];
  const recentOrders = recentOrdersRes.data ?? [];

  // Payment totals per order, for the transaction history list.
  const orderIds = recentOrders.map((o) => o.id);
  const { data: paymentsForOrders } = orderIds.length
    ? await supabase
        .from("payments")
        .select("order_id, amount, method")
        .in("order_id", orderIds)
        .eq("status", "COMPLETED")
    : { data: [] as { order_id: string; amount: number; method: string }[] };

  const totalsByOrder = new Map<string, number>();
  const methodsByOrder = new Map<string, Set<string>>();
  for (const payment of paymentsForOrders ?? []) {
    totalsByOrder.set(payment.order_id, (totalsByOrder.get(payment.order_id) ?? 0) + payment.amount);
    const set = methodsByOrder.get(payment.order_id) ?? new Set<string>();
    set.add(payment.method);
    methodsByOrder.set(payment.order_id, set);
  }

  const methodLabels: Record<string, string> = { CASH: "Nakit", CARD: "Kart", OTHER: "Diğer" };

  const cards = [
    { label: "Toplam Ciro", value: currencyFormatter.format(summary.total_revenue) },
    { label: "Nakit", value: currencyFormatter.format(summary.cash_total) },
    { label: "Kart", value: currencyFormatter.format(summary.card_total) },
    { label: "Diğer", value: currencyFormatter.format(summary.other_total) },
    { label: "Toplam Sipariş", value: String(summary.order_count) },
    { label: "Ortalama Hesap", value: currencyFormatter.format(summary.average_order) },
  ];

  return (
    <div className="mx-auto max-w-5xl px-6 py-8">
      <div className="flex flex-wrap gap-1 border-b border-zinc-200">
        {rangeTabs.map((tab) => (
          <Link
            key={tab.value}
            href={tab.value === "today" ? "/raporlar" : `/raporlar?range=${tab.value}`}
            className={`border-b-2 px-3 py-2 text-sm font-medium ${
              range === tab.value
                ? "border-zinc-900 text-zinc-900"
                : "border-transparent text-zinc-500 hover:text-zinc-800"
            }`}
          >
            {tab.label}
          </Link>
        ))}
      </div>

      <div className="mt-6 grid grid-cols-2 gap-4 sm:grid-cols-3">
        {cards.map((card) => (
          <div key={card.label} className="rounded-xl border border-zinc-200 bg-white p-5 shadow-sm">
            <p className="text-sm text-zinc-500">{card.label}</p>
            <p className="mt-2 text-2xl font-semibold tracking-tight text-zinc-900">{card.value}</p>
          </div>
        ))}
      </div>

      <div className="mt-8 grid grid-cols-1 gap-6 lg:grid-cols-2">
        <div>
          <h2 className="text-sm font-semibold text-zinc-900">En Çok Satılan Ürünler</h2>
          <div className="mt-3 overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-sm">
            {topProducts.length === 0 ? (
              <p className="px-5 py-8 text-center text-sm text-zinc-500">Bu aralıkta satış yok.</p>
            ) : (
              <table className="w-full text-left text-sm">
                <thead className="border-b border-zinc-200 bg-zinc-50 text-xs uppercase tracking-wide text-zinc-500">
                  <tr>
                    <th className="px-4 py-2.5 font-medium">Ürün</th>
                    <th className="px-4 py-2.5 font-medium">Adet</th>
                    <th className="px-4 py-2.5 font-medium">Ciro</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-zinc-100">
                  {topProducts.map((product) => (
                    <tr key={product.product_name}>
                      <td className="px-4 py-2.5 font-medium text-zinc-900">{product.product_name}</td>
                      <td className="px-4 py-2.5 text-zinc-600">{product.total_quantity}</td>
                      <td className="px-4 py-2.5 text-zinc-600">
                        {currencyFormatter.format(product.total_revenue)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>

        <div>
          <h2 className="text-sm font-semibold text-zinc-900">Geçmiş İşlemler</h2>
          <div className="mt-3 max-h-96 overflow-y-auto rounded-xl border border-zinc-200 bg-white shadow-sm">
            {recentOrders.length === 0 ? (
              <p className="px-5 py-8 text-center text-sm text-zinc-500">Bu aralıkta kapanan hesap yok.</p>
            ) : (
              <ul className="divide-y divide-zinc-100">
                {recentOrders.map((order) => {
                  const tableName =
                    (order.restaurant_tables as { name: string } | null)?.name ?? "Masa";
                  const methods = [...(methodsByOrder.get(order.id) ?? [])]
                    .map((m) => methodLabels[m] ?? m)
                    .join(", ");
                  return (
                    <li key={order.id} className="flex items-center justify-between px-4 py-2.5 text-sm">
                      <div>
                        <p className="font-medium text-zinc-900">{tableName}</p>
                        <p className="text-xs text-zinc-500">
                          {order.closed_at ? new Date(order.closed_at).toLocaleString("tr-TR") : "—"}
                          {methods && ` · ${methods}`}
                        </p>
                      </div>
                      <span className="font-semibold text-zinc-900">
                        {currencyFormatter.format(totalsByOrder.get(order.id) ?? 0)}
                      </span>
                    </li>
                  );
                })}
              </ul>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
