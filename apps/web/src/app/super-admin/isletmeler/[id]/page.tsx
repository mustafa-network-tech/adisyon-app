import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { BusinessActions } from "./business-actions";

const statusLabels = {
  TRIAL: "Deneme",
  ACTIVE: "Aktif",
  GRACE_PERIOD: "Ödeme Bekliyor",
  EXPIRED: "Süresi Doldu",
  SUSPENDED: "Askıda",
  CANCELLED: "İptal",
} as const;

const roleLabels = {
  BUSINESS_ADMIN: "İşletme Yöneticisi",
  CASHIER: "Kasiyer",
  WAITER: "Garson",
  KITCHEN: "Mutfak",
} as const;

function Field({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div>
      <dt className="text-xs font-medium uppercase tracking-wide text-zinc-500">{label}</dt>
      <dd className="mt-1 text-sm text-zinc-900">{value || "—"}</dd>
    </div>
  );
}

export default async function IsletmeDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();

  const { data: business } = await supabase
    .from("businesses")
    .select("*, plans(name)")
    .eq("id", id)
    .single();
  if (!business) notFound();

  const planName = (business.plans as { name: string } | null)?.name ?? null;

  const [{ data: memberships }, { data: plans }, { count: tableCount }, { data: lastActivity }] =
    await Promise.all([
      supabase
        .from("business_memberships")
        .select("id, role, active, user_id, profiles(full_name, phone)")
        .eq("business_id", id),
      supabase.from("plans").select("id, name").eq("active", true).order("created_at"),
      supabase
        .from("restaurant_tables")
        .select("id", { count: "exact", head: true })
        .eq("business_id", id)
        .eq("active", true),
      supabase
        .from("audit_logs")
        .select("created_at")
        .eq("business_id", id)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle(),
    ]);

  const owner = memberships?.find((m) => m.role === "BUSINESS_ADMIN" && m.active);
  const ownerName = (owner?.profiles as { full_name: string | null } | null)?.full_name ?? null;
  const activeUserCount = memberships?.filter((m) => m.active).length ?? 0;

  return (
    <div className="max-w-2xl">
      <Link href="/super-admin/isletmeler" className="text-sm text-zinc-500 hover:text-zinc-800">
        ← İşletmelere Dön
      </Link>

      <div className="mt-3 flex items-center justify-between">
        <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">{business.name}</h1>
        <span className="text-sm font-medium text-zinc-600">
          {statusLabels[business.subscription_status]}
        </span>
      </div>

      <dl className="mt-6 grid grid-cols-1 gap-5 rounded-xl border border-zinc-200 bg-white p-6 shadow-sm sm:grid-cols-2">
        <Field label="Sahibi" value={ownerName} />
        <Field label="İşletme Türü" value={business.business_type} />
        <Field label="Şehir" value={business.city} />
        <Field label="Telefon" value={business.phone} />
        <Field label="E-posta" value={business.email} />
        <Field label="Adres" value={business.address} />
        <Field label="Plan" value={planName ?? "Atanmamış"} />
        <Field label="Kullanıcı Sayısı" value={String(activeUserCount)} />
        <Field label="Masa Sayısı" value={String(tableCount ?? 0)} />
        <Field
          label="Deneme Bitiş Tarihi"
          value={new Date(business.trial_ends_at).toLocaleString("tr-TR")}
        />
        <Field
          label="Oluşturulma Tarihi"
          value={new Date(business.created_at).toLocaleString("tr-TR")}
        />
        <Field
          label="Son Aktivite"
          value={lastActivity ? new Date(lastActivity.created_at).toLocaleString("tr-TR") : "—"}
        />
      </dl>

      <div className="mt-6">
        <BusinessActions
          businessId={business.id}
          subscriptionStatus={business.subscription_status}
          plans={plans ?? []}
          currentPlanId={business.plan_id}
        />
      </div>

      <div className="mt-6 rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
        <h2 className="text-sm font-semibold text-zinc-900">Personel</h2>
        {!memberships || memberships.length === 0 ? (
          <p className="mt-3 text-sm text-zinc-500">Henüz personel eklenmemiş.</p>
        ) : (
          <ul className="mt-3 divide-y divide-zinc-100">
            {memberships.map((m) => (
              <li key={m.id} className="flex items-center justify-between py-2.5 text-sm">
                <span className="text-zinc-900">
                  {(m.profiles as { full_name: string | null } | null)?.full_name ?? "İsimsiz kullanıcı"}
                </span>
                <span className="text-zinc-500">
                  {roleLabels[m.role]} {!m.active && "· pasif"}
                </span>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
