import { redirect } from "next/navigation";
import QRCode from "qrcode";
import { createClient } from "@/lib/supabase/server";
import { getBusinessAdminContext } from "@/lib/auth/session";

export default async function QrMenuAdminPage() {
  const ctx = await getBusinessAdminContext();
  if (!ctx) redirect("/hesabim");

  const supabase = await createClient();
  const { data: business } = await supabase
    .from("businesses")
    .select("plans(qr_menu_enabled)")
    .eq("id", ctx.businessId)
    .single();

  const qrMenuEnabled = (business?.plans as { qr_menu_enabled: boolean } | null)?.qr_menu_enabled ?? false;

  if (!qrMenuEnabled) {
    return (
      <div className="max-w-xl">
        <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">QR Menü</h1>
        <div className="mt-6 rounded-xl border border-amber-200 bg-amber-50 px-5 py-4 text-sm text-amber-800">
          QR Menü özelliği mevcut planınıza dahil değil. Etkinleştirmek için işletmenize destek
          talebi oluşturabilir veya bizimle iletişime geçebilirsiniz.
        </div>
      </div>
    );
  }

  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000";
  const menuUrl = `${siteUrl}/menu/${ctx.businessId}`;
  const qrSvg = await QRCode.toString(menuUrl, { type: "svg", margin: 1, width: 240 });

  return (
    <div className="max-w-xl">
      <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">QR Menü</h1>
      <p className="mt-1 text-sm text-zinc-600">
        Müşterileriniz bu kodu okutarak menünüzü görüntüleyebilir.
      </p>

      <div className="mt-6 rounded-xl border border-zinc-200 bg-white p-6 text-center shadow-sm">
        <div
          className="mx-auto w-60 [&>svg]:mx-auto"
          // Generated locally by the `qrcode` package from a URL this
          // server itself constructed -- not user-supplied HTML.
          dangerouslySetInnerHTML={{ __html: qrSvg }}
        />
        <p className="mt-4 break-all text-sm text-zinc-600">{menuUrl}</p>
        <a
          href={menuUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="mt-4 inline-flex h-10 items-center justify-center rounded-lg border border-zinc-300 bg-white px-5 text-sm font-medium text-zinc-900 hover:bg-zinc-50"
        >
          Menüyü Görüntüle
        </a>
      </div>
    </div>
  );
}
