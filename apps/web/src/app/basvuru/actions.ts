"use server";

import { createClient as createSupabaseClient } from "@supabase/supabase-js";
import { redirect } from "next/navigation";
import type { Database } from "@/lib/supabase/database.types";

// Note: a "use server" file may only export async functions, so this
// type is intentionally not exported -- application-form.tsx redeclares
// it locally.
interface ApplicationFormState {
  error: string | null;
}

// Public form, no signed-in user. We talk to Supabase with the anon key
// directly (not the cookie-aware server client) so this runs as the
// `anon` role for RLS purposes -- exactly what
// business_applications_insert_public expects. No service role, no
// elevated privilege: an anonymous visitor can only ever create a
// PENDING application, nothing else (see the migration's WITH CHECK).
function createAnonClient() {
  return createSupabaseClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}

export async function submitApplication(
  _prevState: ApplicationFormState,
  formData: FormData
): Promise<ApplicationFormState> {
  const businessName = String(formData.get("business_name") ?? "").trim();
  const contactName = String(formData.get("contact_name") ?? "").trim();
  const phone = String(formData.get("phone") ?? "").trim();
  const email = String(formData.get("email") ?? "").trim();
  const businessType = String(formData.get("business_type") ?? "").trim();
  const city = String(formData.get("city") ?? "").trim();
  const address = String(formData.get("address") ?? "").trim();
  const estimatedTablesRaw = String(formData.get("estimated_tables") ?? "").trim();
  const description = String(formData.get("description") ?? "").trim();
  const consentsAccepted = formData.get("consents_accepted") === "on";

  if (!businessName || !contactName || !phone || !email) {
    return { error: "Lütfen zorunlu alanları (işletme adı, yetkili, telefon, e-posta) doldurun." };
  }
  if (!consentsAccepted) {
    return { error: "Devam edebilmek için kullanım/gizlilik onayını kabul etmelisiniz." };
  }

  const estimatedTables = estimatedTablesRaw ? Number.parseInt(estimatedTablesRaw, 10) : null;
  if (estimatedTablesRaw && (!Number.isFinite(estimatedTables) || (estimatedTables ?? 0) < 0)) {
    return { error: "Tahmini masa sayısı geçerli bir sayı olmalıdır." };
  }

  const supabase = createAnonClient();

  const { error } = await supabase.from("business_applications").insert({
    business_name: businessName,
    contact_name: contactName,
    phone,
    email,
    business_type: businessType || null,
    city: city || null,
    address: address || null,
    estimated_tables: estimatedTables,
    description: description || null,
    consents_accepted: true,
  });

  if (error) {
    return { error: "Başvurunuz gönderilemedi. Lütfen daha sonra tekrar deneyin." };
  }

  redirect("/basvuru/basarili");
}
