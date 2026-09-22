import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { EditPlanForm } from "./edit-plan-form";

export default async function PlanDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();

  const { data: plan } = await supabase.from("plans").select("*").eq("id", id).single();
  if (!plan) notFound();

  return (
    <div className="max-w-2xl">
      <Link href="/super-admin/planlar" className="text-sm text-zinc-500 hover:text-zinc-800">
        ← Planlara Dön
      </Link>

      <h1 className="mt-3 text-2xl font-semibold tracking-tight text-zinc-900">{plan.name}</h1>

      <div className="mt-6">
        <EditPlanForm plan={plan} />
      </div>
    </div>
  );
}
