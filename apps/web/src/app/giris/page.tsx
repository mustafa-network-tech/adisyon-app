import { LoginForm } from "./login-form";

export default async function GirisPage({
  searchParams,
}: {
  searchParams: Promise<{ next?: string }>;
}) {
  const { next } = await searchParams;

  return (
    <div className="flex flex-1 items-center justify-center px-6 py-16">
      <div className="w-full max-w-sm">
        <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">Giriş Yap</h1>
        <p className="mt-2 text-sm leading-6 text-zinc-600">
          MK Adisyon hesabınızla giriş yapın.
        </p>

        <div className="mt-8 rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
          <LoginForm next={next && next.startsWith("/") ? next : "/hesabim"} />
        </div>
      </div>
    </div>
  );
}
