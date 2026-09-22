import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getBusinessAdminContext } from "@/lib/auth/session";
import { StaffManager } from "./staff-manager";

export default async function PersonelPage() {
  const ctx = await getBusinessAdminContext();
  if (!ctx) redirect("/hesabim");

  const supabase = await createClient();
  const { data: memberships } = await supabase
    .from("business_memberships")
    .select("id, user_id, role, active, profiles(full_name, email)")
    .eq("business_id", ctx.businessId)
    .order("created_at", { ascending: true });

  const staff = (memberships ?? []).map((m) => {
    const profile = m.profiles as { full_name: string | null; email: string | null } | null;
    return {
      membershipId: m.id,
      userId: m.user_id,
      fullName: profile?.full_name ?? null,
      email: profile?.email ?? null,
      role: m.role,
      active: m.active,
    };
  });

  return (
    <div className="max-w-3xl">
      <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">Personel</h1>
      <p className="mt-1 text-sm text-zinc-600">
        Personelinizi davet edin, rollerini yönetin. Yeni davet edilen kişi e-posta ile şifre
        belirleyip giriş yapabilir.
      </p>

      <div className="mt-6">
        <StaffManager staff={staff} currentUserId={ctx.userId} />
      </div>
    </div>
  );
}
