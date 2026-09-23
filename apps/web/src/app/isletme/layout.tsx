import { redirect } from "next/navigation";
import Link from "next/link";
import { getSessionContext, getBusinessAdminContext } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import { SignOutButton } from "@/components/sign-out-button";
import type { BusinessEntitlement } from "@/lib/supabase/database.types";

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
  // Status and remaining trial days are computed by the database (server
  // clock), never from the browser's clock.
  const { data: entitlementRows } = await supabase.rpc("get_business_entitlement", {
    p_business_id: businessCtx.businessId,
  });
  const entitlement = entitlementRows?.[0] ?? null;

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
          {entitlement && <SubscriptionBanner entitlement={entitlement} />}
          {children}
        </main>
      </div>
    </div>
  );
}

function SubscriptionLink() {
  return (
    <Link href="/isletme/abonelik" className="font-medium underline underline-offset-4">
      Abonelik
    </Link>
  );
}

// A clear explanation of the business's access state -- never a raw enum.
function SubscriptionBanner({ entitlement }: { entitlement: BusinessEntitlement }) {
  if (entitlement.access_source === "SUSPENDED") {
    return (
      <div className="mb-6 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
        Hesabınız askıya alındı. Yeni sipariş oluşturma gibi işlemler kısıtlanmıştır. Lütfen
        destek ile iletişime geçin.
      </div>
    );
  }
  if (entitlement.access_source === "APP_TRIAL") {
    return (
      <div className="mb-6 rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
        Ücretsiz denemenizin {entitlement.app_trial_days_left} günü kaldı. Deneme süresince{" "}
        {entitlement.effective_plan_name} planının tüm özellikleri açık.
      </div>
    );
  }
  if (entitlement.subscription_status === "GRACE_PERIOD") {
    return (
      <div className="mb-6 rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
        Google Play ödemeniz alınamadı. Erişiminiz şimdilik devam ediyor; lütfen Google Play
        hesabınızdaki ödeme yöntemini güncelleyin.
      </div>
    );
  }
  if (entitlement.access_source === "PLAY_TRIAL") {
    return (
      <div className="mb-6 rounded-lg border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-800">
        Google Play ücretsiz döneminiz sürüyor. Bu süre boyunca {entitlement.effective_plan_name}{" "}
        planının tüm özellikleri açık.
      </div>
    );
  }
  if (!entitlement.is_operational) {
    const reason =
      entitlement.subscription_status === "TRIAL"
        ? "Ücretsiz deneme süreniz doldu."
        : "Aktif bir aboneliğiniz bulunmuyor.";
    return (
      <div className="mb-6 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
        {reason} Yeni adisyon açılamaz; açık adisyonlarınızı kapatabilirsiniz ve verileriniz
        silinmez. Devam etmek için <SubscriptionLink /> sayfasındaki adımları izleyin.
      </div>
    );
  }
  return null;
}
