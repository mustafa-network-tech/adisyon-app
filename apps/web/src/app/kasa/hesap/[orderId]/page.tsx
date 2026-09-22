import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getCashierContext } from "@/lib/auth/session";
import { PaymentPanel } from "./payment-panel";

export default async function HesapPage({
  params,
}: {
  params: Promise<{ orderId: string }>;
}) {
  const { orderId } = await params;
  const ctx = await getCashierContext();
  if (!ctx) redirect("/hesabim");

  const supabase = await createClient();
  const { data: order } = await supabase
    .from("orders")
    .select("id, status, table_id, restaurant_tables(name)")
    .eq("id", orderId)
    .eq("business_id", ctx.businessId)
    .single();

  if (!order) notFound();

  const tableName =
    (order.restaurant_tables as { name: string } | null)?.name ?? "Masa";

  return (
    <PaymentPanel
      orderId={order.id}
      businessId={ctx.businessId}
      tableName={tableName}
      initialStatus={order.status}
    />
  );
}
