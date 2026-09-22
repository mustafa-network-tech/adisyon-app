import { ApplicationForm } from "./application-form";

export default function BasvuruPage() {
  return (
    <div className="flex flex-1 justify-center px-6 py-16">
      <div className="w-full max-w-xl">
        <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">İşletme Başvurusu</h1>
        <p className="mt-2 text-sm leading-6 text-zinc-600">
          Formu doldurun, ekibimiz başvurunuzu inceleyip en kısa sürede size dönüş yapsın.
          Onaylanan işletmeler 7 gün ücretsiz deneme ile başlar.
        </p>

        <div className="mt-8 rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
          <ApplicationForm />
        </div>
      </div>
    </div>
  );
}
