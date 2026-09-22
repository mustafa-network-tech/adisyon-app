import Link from "next/link";
import { SignupForm } from "./signup-form";

// Faz 12: self-service signup. Replaces the old /basvuru (public
// application -> manual Super Admin approval) flow entirely -- a
// business now comes into existence the moment its owner creates their
// own account here, with an automatic 7-day trial (see
// public.create_own_business).
export default function KayitPage() {
  return (
    <div className="flex flex-1 items-center justify-center px-6 py-16">
      <div className="w-full max-w-md">
        <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">
          Ücretsiz Başlayın
        </h1>
        <p className="mt-2 text-sm leading-6 text-zinc-600">
          Hesabınızı ve işletmenizi oluşturun — 7 gün boyunca tüm özellikler ücretsiz.
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
