import { redirect } from "next/navigation";
import { getKitchenContext } from "@/lib/auth/session";
import { KitchenBoard } from "./kitchen-board";

export default async function MutfakPage() {
  const ctx = await getKitchenContext();
  if (!ctx) redirect("/hesabim");

  return <KitchenBoard businessId={ctx.businessId} />;
}
