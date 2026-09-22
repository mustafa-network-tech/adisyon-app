import { createClient } from "@/lib/supabase/server";
import { SupportRequestList, CustomRequestList } from "./request-lists";

export default async function SuperAdminDestekPage() {
  const supabase = await createClient();

  const [{ data: supportRequests }, { data: customRequests }] = await Promise.all([
    supabase
      .from("support_requests")
      .select("id, type, subject, description, status, created_at, businesses(name)")
      .order("created_at", { ascending: false }),
    supabase
      .from("custom_software_requests")
      .select("id, requester_name, phone, email, need, description, status, created_at, businesses(name)")
      .order("created_at", { ascending: false }),
  ]);

  const supportRows = (supportRequests ?? []).map((r) => ({
    ...r,
    business_name: (r.businesses as { name: string } | null)?.name ?? "—",
  }));
  const customRows = (customRequests ?? []).map((r) => ({
    ...r,
    business_name: (r.businesses as { name: string } | null)?.name ?? null,
  }));

  return (
    <div className="max-w-4xl">
      <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">Destek</h1>
      <p className="mt-1 text-sm text-zinc-600">İşletmelerden gelen destek ve özel yazılım talepleri.</p>

      <div className="mt-8">
        <h2 className="text-sm font-semibold text-zinc-900">Destek Talepleri</h2>
        <div className="mt-3 overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-sm">
          <SupportRequestList requests={supportRows} />
        </div>
      </div>

      <div className="mt-8">
        <h2 className="text-sm font-semibold text-zinc-900">Özel Yazılım Talepleri</h2>
        <div className="mt-3 overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-sm">
          <CustomRequestList requests={customRows} />
        </div>
      </div>
    </div>
  );
}
