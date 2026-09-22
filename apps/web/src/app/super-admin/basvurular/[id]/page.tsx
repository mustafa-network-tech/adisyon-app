import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { ReviewActions } from "./review-actions";

const statusLabels = {
  PENDING: "Bekliyor",
  APPROVED: "Onaylandı",
  REJECTED: "Reddedildi",
} as const;

function Field({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div>
      <dt className="text-xs font-medium uppercase tracking-wide text-zinc-500">{label}</dt>
      <dd className="mt-1 text-sm text-zinc-900">{value || "—"}</dd>
    </div>
  );
}

export default async function BasvuruDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();

  const { data: application } = await supabase
    .from("business_applications")
    .select("*")
    .eq("id", id)
    .single();

  if (!application) notFound();

  return (
    <div className="max-w-2xl">
      <Link href="/super-admin/basvurular" className="text-sm text-zinc-500 hover:text-zinc-800">
        ← Başvurulara Dön
      </Link>

      <div className="mt-3 flex items-center justify-between">
        <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">
          {application.business_name}
        </h1>
        <span className="text-sm font-medium text-zinc-600">
          {statusLabels[application.status]}
        </span>
      </div>

      {application.status === "PENDING" && (
        <div className="mt-4 rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
          Bu başvuru akışı kaldırıldı. Bu kayıt onaylanamaz — işletmeler artık kendi
          hesaplarını oluşturuyor. Yalnızca kaydı kapatmak için reddedebilirsiniz.
        </div>
      )}

      <dl className="mt-6 grid grid-cols-1 gap-5 rounded-xl border border-zinc-200 bg-white p-6 shadow-sm sm:grid-cols-2">
        <Field label="İşletme Türü" value={application.business_type} />
        <Field label="Şehir" value={application.city} />
        <Field label="Yetkili" value={application.contact_name} />
        <Field label="Telefon" value={application.phone} />
        <Field label="E-posta" value={application.email} />
        <Field label="Tahmini Masa Sayısı" value={application.estimated_tables?.toString()} />
        <Field label="Adres" value={application.address} />
        <Field
          label="Başvuru Tarihi"
          value={new Date(application.created_at).toLocaleString("tr-TR")}
        />
        {application.description && (
          <div className="sm:col-span-2">
            <Field label="Açıklama" value={application.description} />
          </div>
        )}
        {application.status === "REJECTED" && application.rejection_reason && (
          <div className="sm:col-span-2">
            <Field label="Red Nedeni" value={application.rejection_reason} />
          </div>
        )}
      </dl>

      {application.status === "PENDING" ? (
        <div className="mt-6">
          <ReviewActions applicationId={application.id} />
        </div>
      ) : application.status === "APPROVED" && application.resulting_business_id ? (
        <div className="mt-6">
          <Link
            href={`/super-admin/isletmeler/${application.resulting_business_id}`}
            className="inline-flex h-10 items-center justify-center rounded-lg border border-zinc-300 bg-white px-5 text-sm font-medium text-zinc-900 hover:bg-zinc-50"
          >
            İşletmeyi Görüntüle
          </Link>
        </div>
      ) : null}
    </div>
  );
}
