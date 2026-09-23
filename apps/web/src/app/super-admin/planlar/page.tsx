import { createClient } from "@/lib/supabase/server";
import { CreatePlanForm } from "./create-plan-form";
import { PlanList } from "./plan-list";

export default async function PlanlarPage() {
  const supabase = await createClient();
  const { data: plans } = await supabase
    .from("plans")
    .select("id, code, name, monthly_price, max_tables, max_waiters, max_users, max_areas, active")
    .order("sort_order", { ascending: true })
    .order("created_at", { ascending: true });

  return (
    <div className="max-w-4xl">
      <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">Planlar</h1>
      <p className="mt-1 text-sm text-zinc-600">
        Abonelik planlarını oluşturun ve limitlerini yönetin. Bir işletmeye plan atamak için
        işletme detay sayfasını kullanın.
      </p>

      <div className="mt-6">
        <CreatePlanForm />
      </div>

      <div className="mt-6">
        <PlanList plans={plans ?? []} />
      </div>
    </div>
  );
}
