import { redirect } from "next/navigation";
import { getKasaContext } from "@/lib/auth/session";
import { PosBoard } from "./pos-board";

export default async function KasaPage() {
  const ctx = await getKasaContext();
  if (!ctx) redirect("/hesabim");

  return <PosBoard businessId={ctx.businessId} />;
}
