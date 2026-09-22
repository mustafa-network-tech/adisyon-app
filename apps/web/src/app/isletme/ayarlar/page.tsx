import { redirect, notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getBusinessAdminContext } from "@/lib/auth/session";
import { SettingsForm } from "./settings-form";

export default async function AyarlarPage() {
  const ctx = await getBusinessAdminContext();
  if (!ctx) redirect("/hesabim");

  const supabase = await createClient();
  const { data: business } = await supabase
    .from("businesses")
    .select("name, business_type, city, address, phone, email, logo_url")
    .eq("id", ctx.businessId)
    .single();

  if (!business) notFound();

  return (
    <div>
      <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">Ayarlar</h1>
      <p className="mt-1 text-sm text-zinc-600">İşletme bilgilerinizi güncelleyin.</p>

      <div className="mt-6">
        <SettingsForm business={business} />
      </div>
    </div>
  );
}
