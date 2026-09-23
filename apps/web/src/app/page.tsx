import Link from "next/link";

export default function Home() {
  return (
    <div className="flex flex-1 flex-col items-center justify-center px-6 py-24">
      <div className="w-full max-w-lg text-center">
        <h1 className="text-3xl font-semibold tracking-tight text-zinc-900">MK Adisyon</h1>
        <p className="mt-3 text-base leading-7 text-zinc-600">
          Restoran ve kafeler için adisyon, sipariş ve kasa platformu.
        </p>

        <div className="mt-10 flex flex-col gap-3 sm:flex-row sm:justify-center">
          <Link
            href="/kayit"
            className="inline-flex h-11 items-center justify-center rounded-lg bg-zinc-900 px-6 text-sm font-medium text-white transition-colors hover:bg-zinc-800"
          >
            Ücretsiz Başlayın
          </Link>
          <Link
            href="/giris"
            className="inline-flex h-11 items-center justify-center rounded-lg border border-zinc-300 bg-white px-6 text-sm font-medium text-zinc-900 transition-colors hover:bg-zinc-50"
          >
            Giriş Yap
          </Link>
        </div>

        <Link
          href="/fiyatlandirma"
          className="mt-6 inline-block text-sm font-medium text-zinc-600 underline-offset-4 hover:text-zinc-900 hover:underline"
        >
          Planları ve fiyatları inceleyin
        </Link>
      </div>
    </div>
  );
}
