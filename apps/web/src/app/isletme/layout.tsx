import { redirect } from "next/navigation";
import Link from "next/link";
import { getSessionContext, getBusinessAdminContext } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { SignOutButton } from "@/components/sign-out-button";

const navLinks = [
  { href: "/isletme", label: "Genel Bakış" },
  { href: "/kasa", label: "Kasa" },
  { href: "/mutfak", label: "Mutfak" },
  { href: "/isletme/alanlar", label: "Alanlar" },
  { href: "/isletme/masalar", label: "Masalar" },
  { href: "/isletme/kategoriler", label: "Kategoriler" },
  { href: "/isletme/urunler", label: "Ürünler" },
  { href: "/isletme/personel", label: "Personel" },
  { href: "/isletme/qr-menu", label: "QR Menü" },
  { href: "/raporlar", label: "Raporlar" },
  { href: "/isletme/abonelik", label: "Abonelik" },
  { href: "/isletme/destek", label: "Destek" },
  { href: "/isletme/audit", label: "Denetim Kaydı" },
  { href: "/isletme/ayarlar", label: "Ayarlar" },
];

export default async function IsletmeLayout({ children }: { children: React.ReactNode }) {
  const ctx = await getSessionContext();
  if (!ctx) {
    redirect("/giris?next=/isletme");
  }

  const businessCtx = await getBusinessAdminContext();

  if (!businessCtx) {
    return (
      <div className="flex flex-1 items-center justify-center px-6 py-16">
        <div className="w-full max-w-md rounded-xl border border-zinc-200 bg-white p-6 text-center shadow-sm">
          <h1 className="text-xl font-semibold tracking-tight text-zinc-900">Erişim Yok</h1>
          <p className="mt-2 text-sm leading-6 text-zinc-600">
            Bu panele erişim yetkiniz bulunmuyor. Bu alan yalnızca işletme yöneticileri
            içindir.
          </p>
          <div className="mt-6">
            <SignOutButton className="inline-flex h-10 items-center justify-center rounded-lg border border-zinc-300 bg-white px-5 text-sm font-medium text-zinc-900 hover:bg-zinc-50" />
          </div>
        </div>
      </div>
    );
  }

  const supabase = await createClient();
  const { data: business } = await supabase
    .from("businesses")
    .select("subscription_status, trial_ends_at")
    .eq("id", businessCtx.businessId)
    .single();

  return (
    <div className="flex min-h-screen flex-1">
      <aside className="hidden w-60 shrink-0 border-r border-zinc-200 bg-white sm:flex sm:flex-col">
        <div className="px-5 py-5">
          <p className="text-sm font-semibold tracking-tight text-zinc-900">
            {businessCtx.businessName}
          </p>
          <p className="text-xs text-zinc-500">İşletme Yönetimi</p>
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
          <p className="text-sm font-semibold text-zinc-900">{businessCtx.businessName}</p>
          <SignOutButton className="text-sm font-medium text-zinc-700" />
        </header>
        <main className="flex-1 px-6 py-8 sm:px-10">
          {business && <SubscriptionBanner business={business} />}
          {children}
        </main>
      </div>
    </div>
  );
}

// Pulled out of the component body (rather than calling Date.now()
// inline in the render) so it reads as an ordinary pure-in/pure-out
// helper, not a component computing an impure value during render.
function daysUntil(dateIso: string): number {
  return Math.ceil((new Date(dateIso).getTime() - Date.now()) / (1000 * 60 * 60 * 24));
}

// "Kullanıcıya anlaşılır abonelik ekranı göster" (section 8). A trial
// countdown once it's getting close, and a clear explanation whenever
// the business can't open new orders -- never a raw status enum.
function SubscriptionBanner({
  business,
}: {
  business: { subscription_status: string; trial_ends_at: string };
}) {
  if (business.subscription_status === "SUSPENDED") {
    return (
      <div className="mb-6 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
        Hesabınız askıya alındı. Yeni sipariş oluşturma gibi işlemler kısıtlanmıştır. Lütfen
        destek ile iletişime geçin.
      </div>
    );
  }
  if (business.subscription_status === "EXPIRED" || business.subscription_status === "CANCELLED") {
    return (
      <div className="mb-6 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
        Aboneliğinizin süresi doldu. Yeni sipariş oluşturma gibi işlemler kısıtlanmıştır. Planları{" "}
        <Link href="/isletme/abonelik" className="font-medium underline underline-offset-4">
          Abonelik
        </Link>{" "}
        sayfasında inceleyebilir veya destek ile iletişime geçebilirsiniz.
      </div>
    );
  }
  if (business.subscription_status === "GRACE_PERIOD") {
    return (
      <div className="mb-6 rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
        Google Play ödemeniz alınamadı. Erişiminiz şimdilik devam ediyor; lütfen Google Play
        hesabınızdaki ödeme yöntemini güncelleyin.
      </div>
    );
  }
  if (business.subscription_status === "TRIAL") {
    const daysLeft = daysUntil(business.trial_ends_at);
    if (daysLeft <= 0) {
      return (
        <div className="mb-6 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          Ücretsiz deneme süreniz doldu. Yeni sipariş oluşturma gibi işlemler kısıtlanmıştır;
          açık adisyonlarınızı kapatabilirsiniz. Planları{" "}
          <Link href="/isletme/abonelik" className="font-medium underline underline-offset-4">
            Abonelik
          </Link>{" "}
          sayfasında inceleyebilirsiniz.
        </div>
      );
    }
    return (
      <div className="mb-6 rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
        Ücretsiz deneme sürenizin bitmesine {daysLeft} gün kaldı.
      </div>
    );
  }
  return null;
}
