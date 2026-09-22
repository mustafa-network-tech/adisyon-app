import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { SetPasswordForm } from "./set-password-form";

export default async function SifreOlusturPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/giris?error=davet-linki-gecersiz");
  }

  return (
    <div className="flex flex-1 items-center justify-center px-6 py-16">
      <div className="w-full max-w-sm">
        <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">
          Hesabınıza Hoş Geldiniz
        </h1>
        <p className="mt-2 text-sm leading-6 text-zinc-600">
          Devam etmek için bir şifre belirleyin.
        </p>

        <div className="mt-8 rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
          <SetPasswordForm />
        </div>
      </div>
    </div>
  );
}
