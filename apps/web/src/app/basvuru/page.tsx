import { redirect } from "next/navigation";

// Faz 12: this public application form is retired -- businesses no
// longer open via Super Admin approval, they self-register at /kayit
// (see public.create_own_business). business_applications_insert_public
// was dropped in 20260922000025_self_service_business_signup.sql, so
// this route could no longer accept a submission even if rendered;
// redirect straight to the flow that replaced it.
export default function BasvuruPage() {
  redirect("/kayit");
}
