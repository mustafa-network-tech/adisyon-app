import Link from "next/link";
import { SignupForm } from "./signup-form";
import { createClient } from "@/lib/supabase/server";
import { getTrialSettings } from "@/lib/plans";

// Faz 12: self-service signup. Replaces the old /basvuru (public
// application -> manual Super Admin approval) flow entirely -- a
// business now comes into existence the moment its owner creates their
// own account here, with an automatic app trial whose length comes from
// subscription_settings (see public.create_own_business).
export default async function KayitPage() {
  const supabase = await createClient();
  const trial = await getTrialSettings(supabase);

  return (
    <div className="flex flex-1 items-center justify-center px-6 py-16">
      <div className="w-full max-w-md">
        <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">
          Ücretsiz Başlayın
        </h1>
        <p className="mt-2 text-sm leading-6 text-zinc-600">
          {trial.appTrialDays > 0
            ? `Hesabınızı ve işletmenizi oluşturun — ${trial.appTrialDays} gün boyunca tüm özellikler ücretsiz.`
            : "Hesabınızı ve işletmenizi oluşturun, ardından Android uygulamasından aboneliğinizi başlatın."}
        </p>

        <div className="mt-8 rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
          <SignupForm />
        </div>

        <p className="mt-4 text-center text-sm text-zinc-500">
          Zaten hesabınız var mı?{" "}
          <Link href="/giris" className="font-medium text-zinc-900 hover:underline">
            Giriş yapın
          </Link>
        </p>
      </div>
    </div>
  );
}
