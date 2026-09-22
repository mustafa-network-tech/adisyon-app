import { redirect } from "next/navigation";
import Link from "next/link";
import { getSessionContext } from "@/lib/auth/session";
import { SignOutButton } from "@/components/sign-out-button";

const navLinks = [
  { href: "/super-admin", label: "Genel Bakış" },
  { href: "/super-admin/basvurular", label: "Başvurular (Arşiv)" },
  { href: "/super-admin/isletmeler", label: "İşletmeler" },
  { href: "/super-admin/abonelikler", label: "Abonelikler" },
  { href: "/super-admin/planlar", label: "Planlar" },
  { href: "/super-admin/destek", label: "Destek" },
  { href: "/super-admin/audit", label: "Denetim Kaydı" },
];

export default async function SuperAdminLayout({ children }: { children: React.ReactNode }) {
  const ctx = await getSessionContext();

  if (!ctx) {
    redirect("/giris?next=/super-admin");
  }

  if (!ctx.isPlatformAdmin) {
    return (
      <div className="flex flex-1 items-center justify-center px-6 py-16">
        <div className="w-full max-w-md rounded-xl border border-zinc-200 bg-white p-6 text-center shadow-sm">
          <h1 className="text-xl font-semibold tracking-tight text-zinc-900">Erişim Yok</h1>
          <p className="mt-2 text-sm leading-6 text-zinc-600">
            Bu panele erişim yetkiniz bulunmuyor. Bu alan yalnızca platform yöneticileri
            içindir.
          </p>
          <div className="mt-6">
            <SignOutButton className="inline-flex h-10 items-center justify-center rounded-lg border border-zinc-300 bg-white px-5 text-sm font-medium text-zinc-900 hover:bg-zinc-50" />
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen flex-1">
      <aside className="hidden w-60 shrink-0 border-r border-zinc-200 bg-white sm:flex sm:flex-col">
        <div className="px-5 py-5">
          <p className="text-sm font-semibold tracking-tight text-zinc-900">MK Adisyon</p>
          <p className="text-xs text-zinc-500">Platform Yönetimi</p>
        </div>
        <nav className="flex-1 space-y-0.5 px-3">
          {navLinks.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              className="block rounded-lg px-3 py-2 text-sm font-medium text-zinc-700 hover:bg-zinc-100"
            >
              {link.label}
            </Link>
          ))}
        </nav>
        <div className="border-t border-zinc-200 px-3 py-3">
          <SignOutButton className="w-full rounded-lg px-3 py-2 text-left text-sm font-medium text-zinc-700 hover:bg-zinc-100" />
        </div>
      </aside>

      <div className="flex flex-1 flex-col">
        <header className="flex items-center justify-between border-b border-zinc-200 bg-white px-6 py-4 sm:hidden">
          <p className="text-sm font-semibold text-zinc-900">MK Adisyon — Platform Yönetimi</p>
          <SignOutButton className="text-sm font-medium text-zinc-700" />
        </header>
        <main className="flex-1 px-6 py-8 sm:px-10">{children}</main>
      </div>
    </div>
  );
}
