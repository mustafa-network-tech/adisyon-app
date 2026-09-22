import { redirect } from "next/navigation";
import { getSessionContext, getReportsContext } from "@/lib/auth/session";
import { SignOutButton } from "@/components/sign-out-button";

export default async function RaporlarLayout({ children }: { children: React.ReactNode }) {
  const ctx = await getSessionContext();
  if (!ctx) {
    redirect("/giris?next=/raporlar");
  }

  const reportsCtx = await getReportsContext();

  if (!reportsCtx) {
    return (
      <div className="flex flex-1 items-center justify-center px-6 py-16">
        <div className="w-full max-w-md rounded-xl border border-zinc-200 bg-white p-6 text-center shadow-sm">
          <h1 className="text-xl font-semibold tracking-tight text-zinc-900">Erişim Yok</h1>
          <p className="mt-2 text-sm leading-6 text-zinc-600">
            Bu panele erişim yetkiniz bulunmuyor. Raporlar yalnızca işletme yöneticileri ve
            kasa personeli içindir.
          </p>
          <div className="mt-6">
            <SignOutButton className="inline-flex h-10 items-center justify-center rounded-lg border border-zinc-300 bg-white px-5 text-sm font-medium text-zinc-900 hover:bg-zinc-50" />
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen flex-1 flex-col bg-zinc-50">
      <header className="flex items-center justify-between border-b border-zinc-200 bg-white px-6 py-4">
        <p className="text-base font-semibold text-zinc-900">{reportsCtx.businessName} · Raporlar</p>
        <SignOutButton className="text-sm font-medium text-zinc-600 hover:text-zinc-900" />
      </header>
      <main className="flex-1">{children}</main>
    </div>
  );
}
