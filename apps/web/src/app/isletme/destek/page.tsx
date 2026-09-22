import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getBusinessAdminContext } from "@/lib/auth/session";
import { SupportRequestForm } from "./support-request-form";
import { CustomSoftwareForm } from "./custom-software-form";

const supportStatusLabels: Record<string, string> = {
  OPEN: "Açık",
  IN_PROGRESS: "İnceleniyor",
  RESOLVED: "Çözüldü",
  CLOSED: "Kapatıldı",
};

const customStatusLabels: Record<string, string> = {
  PENDING: "Bekliyor",
  IN_REVIEW: "İnceleniyor",
  CLOSED: "Kapatıldı",
};

const typeLabels: Record<string, string> = {
  TECHNICAL_SUPPORT: "Teknik Destek",
  FEATURE_REQUEST: "Özellik Talebi",
  OTHER: "Diğer",
};

export default async function DestekPage() {
  const ctx = await getBusinessAdminContext();
  if (!ctx) redirect("/hesabim");

  const supabase = await createClient();
  const [{ data: supportRequests }, { data: customRequests }] = await Promise.all([
    supabase
      .from("support_requests")
      .select("id, type, subject, status, created_at")
      .eq("business_id", ctx.businessId)
      .order("created_at", { ascending: false }),
    supabase
      .from("custom_software_requests")
      .select("id, need, status, created_at")
      .eq("business_id", ctx.businessId)
      .order("created_at", { ascending: false }),
  ]);

  return (
    <div className="max-w-3xl space-y-10">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">Destek Talebi</h1>
        <p className="mt-1 text-sm text-zinc-600">
          Teknik bir sorun mu var, yoksa bir özellik önerisi mi var? Bize yazın.
        </p>
        <div className="mt-6">
          <SupportRequestForm />
        </div>
        {supportRequests && supportRequests.length > 0 && (
          <ul className="mt-6 divide-y divide-zinc-100 overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-sm">
            {supportRequests.map((request) => (
              <li key={request.id} className="flex items-center justify-between px-5 py-3 text-sm">
                <div>
                  <p className="font-medium text-zinc-900">{request.subject}</p>
                  <p className="text-xs text-zinc-500">
                    {typeLabels[request.type]} · {new Date(request.created_at).toLocaleDateString("tr-TR")}
                  </p>
                </div>
                <span className="text-zinc-500">{supportStatusLabels[request.status]}</span>
              </li>
            ))}
          </ul>
        )}
      </div>

      <div>
        <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">Özel Yazılım Talebi</h1>
        <p className="mt-1 text-sm text-zinc-600">
          Standart özellikler ihtiyacınızı karşılamıyorsa özel bir çözüm talebinde bulunun.
        </p>
        <div className="mt-6">
          <CustomSoftwareForm />
        </div>
        {customRequests && customRequests.length > 0 && (
          <ul className="mt-6 divide-y divide-zinc-100 overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-sm">
            {customRequests.map((request) => (
              <li key={request.id} className="flex items-center justify-between px-5 py-3 text-sm">
                <div>
                  <p className="font-medium text-zinc-900">{request.need}</p>
                  <p className="text-xs text-zinc-500">
                    {new Date(request.created_at).toLocaleDateString("tr-TR")}
                  </p>
                </div>
                <span className="text-zinc-500">{customStatusLabels[request.status]}</span>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
