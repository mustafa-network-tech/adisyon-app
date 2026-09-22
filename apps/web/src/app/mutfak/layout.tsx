import { redirect } from "next/navigation";
import { getSessionContext } from "@/lib/auth/session";
import { SignOutButton } from "@/components/sign-out-button";

// Faz 13 (production web routing): Kitchen Web is retired in favor of
// the Android app -- section 1/11 of the production architecture make
// KITCHEN an Android-only role. This route is intentionally never
// rendered for anyone any more (not even KITCHEN itself); the board
// component and its data logic are left untouched in kitchen-board.tsx
// rather than deleted, in case Kitchen Web is ever revived.
export default async function MutfakLayout(_props: { children: React.ReactNode }) {
  const ctx = await getSessionContext();
  if (!ctx) {
    redirect("/giris?next=/hesabim");
  }

  return (
    <div className="flex flex-1 items-center justify-center px-6 py-16">
      <div className="w-full max-w-md rounded-xl border border-zinc-200 bg-white p-6 text-center shadow-sm">
        <h1 className="text-xl font-semibold tracking-tight text-zinc-900">
          Mutfak Ekranı Mobil Uygulamaya Taşındı
        </h1>
        <p className="mt-2 text-sm leading-6 text-zinc-600">
          Bu web ekranı artık kullanılmıyor. Lütfen MK Adisyon mobil uygulamasını kullanın.
        </p>
        <div className="mt-6">
          <SignOutButton className="inline-flex h-10 items-center justify-center rounded-lg border border-zinc-300 bg-white px-5 text-sm font-medium text-zinc-900 hover:bg-zinc-50" />
        </div>
      </div>
    </div>
  );
}
