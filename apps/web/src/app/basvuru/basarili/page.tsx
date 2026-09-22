import Link from "next/link";

export default function BasvuruBasariliPage() {
  return (
    <div className="flex flex-1 items-center justify-center px-6 py-24">
      <div className="w-full max-w-md text-center">
        <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">
          Başvurunuz Alındı
        </h1>
        <p className="mt-3 text-sm leading-6 text-zinc-600">
          Başvurunuzu inceledikten sonra size e-posta veya telefon ile dönüş yapacağız.
        </p>
        <Link
          href="/"
          className="mt-8 inline-flex h-11 items-center justify-center rounded-lg border border-zinc-300 bg-white px-6 text-sm font-medium text-zinc-900 hover:bg-zinc-50"
        >
          Ana Sayfaya Dön
        </Link>
      </div>
    </div>
  );
}
