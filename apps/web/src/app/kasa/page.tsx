import { redirect } from "next/navigation";
import { getCashierContext } from "@/lib/auth/session";
import { PosBoard } from "./pos-board";

export default async function KasaPage() {
  const ctx = await getCashierContext();
  if (!ctx) redirect("/hesabim");

  return <PosBoard businessId={ctx.businessId} />;
}
