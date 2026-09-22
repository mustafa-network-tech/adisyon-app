import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getSessionContext, getBusinessAdminContext, getKitchenContext } from "@/lib/auth/session";
import { SignOutButton } from "@/components/sign-out-button";

// Generic post-login landing page: routes a platform admin, business
// admin, or kitchen staff straight to their panel; everyone else
// (CASHIER/WAITER) lands here with a clear status message, since those
// web dashboards are built in later phases (their primary surface is
// the Flutter app).
export default async function HesabimPage() {
  const ctx = await getSessionContext();
  if (!ctx) redirect("/giris");
  if (ctx.isPlatformAdmin) redirect("/super-admin");

  const businessAdminCtx = await getBusinessAdminContext();
  if (businessAdminCtx) redirect("/isletme");

  const kitchenCtx = await getKitchenContext();
  if (kitchenCtx) redirect("/mutfak");

  const supabase = await createClient();
  const { data: memberships } = await supabase
    .from("business_memberships")
    .select("role, active, businesses(name)")
    .eq("user_id", ctx.userId);

  return (
    <div className="flex flex-1 items-center justify-center px-6 py-16">
      <div className="w-full max-w-md rounded-xl border border-zinc-200 bg-white p-6 text-center shadow-sm">
        <h1 className="text-xl font-semibold tracking-tight text-zinc-900">
          Hesabınız Hazır
        </h1>
        <p className="mt-2 text-sm leading-6 text-zinc-600">
          {memberships && memberships.length > 0
            ? "Bu rol için web paneli yakında aktif olacak. Şimdilik MK Adisyon mobil uygulamasını kullanabilirsiniz."
            : "Hesabınız henüz bir işletmeye tanımlanmamış. Lütfen işletme yöneticinizle iletişime geçin."}
        </p>
        <div className="mt-6">
          <SignOutButton className="inline-flex h-10 items-center justify-center rounded-lg border border-zinc-300 bg-white px-5 text-sm font-medium text-zinc-900 hover:bg-zinc-50" />
        </div>
      </div>
    </div>
  );
}
