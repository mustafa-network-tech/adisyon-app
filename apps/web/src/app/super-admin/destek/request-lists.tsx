"use client";

import { useTransition } from "react";
import { updateSupportRequestStatus, updateCustomSoftwareRequestStatus } from "./actions";
import type { SupportRequestStatus, CustomSoftwareRequestStatus } from "@/lib/supabase/database.types";

export interface SupportRequestRow {
  id: string;
  type: string;
  subject: string;
  description: string;
  status: SupportRequestStatus;
  created_at: string;
  business_name: string;
}

export interface CustomRequestRow {
  id: string;
  requester_name: string;
  phone: string;
  email: string;
  need: string;
  description: string | null;
  status: CustomSoftwareRequestStatus;
  created_at: string;
  business_name: string | null;
}

const typeLabels: Record<string, string> = {
  TECHNICAL_SUPPORT: "Teknik Destek",
  FEATURE_REQUEST: "Özellik Talebi",
  OTHER: "Diğer",
};

const supportStatuses: SupportRequestStatus[] = ["OPEN", "IN_PROGRESS", "RESOLVED", "CLOSED"];
const supportStatusLabels: Record<SupportRequestStatus, string> = {
  OPEN: "Açık",
  IN_PROGRESS: "İnceleniyor",
  RESOLVED: "Çözüldü",
  CLOSED: "Kapatıldı",
};

const customStatuses: CustomSoftwareRequestStatus[] = ["PENDING", "IN_REVIEW", "CLOSED"];
const customStatusLabels: Record<CustomSoftwareRequestStatus, string> = {
  PENDING: "Bekliyor",
  IN_REVIEW: "İnceleniyor",
  CLOSED: "Kapatıldı",
};

const selectClass =
  "rounded-lg border border-zinc-300 bg-white px-3 py-1.5 text-sm text-zinc-900 outline-none focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500";

export function SupportRequestList({ requests }: { requests: SupportRequestRow[] }) {
  const [isPending, startTransition] = useTransition();

  if (requests.length === 0) {
    return <p className="px-5 py-8 text-center text-sm text-zinc-500">Destek talebi yok.</p>;
  }

  return (
    <ul className="divide-y divide-zinc-100">
      {requests.map((request) => (
        <li key={request.id} className="px-5 py-4">
          <div className="flex items-start justify-between gap-3">
            <div>
              <p className="font-medium text-zinc-900">{request.subject}</p>
              <p className="text-xs text-zinc-500">
                {request.business_name} · {typeLabels[request.type]} ·{" "}
                {new Date(request.created_at).toLocaleDateString("tr-TR")}
              </p>
              <p className="mt-2 text-sm text-zinc-600">{request.description}</p>
            </div>
            <select
              defaultValue={request.status}
              disabled={isPending}
              onChange={(e) =>
                startTransition(() => {
                  updateSupportRequestStatus(request.id, e.target.value as SupportRequestStatus);
                })
              }
              className={selectClass}
            >
              {supportStatuses.map((status) => (
                <option key={status} value={status}>
                  {supportStatusLabels[status]}
                </option>
              ))}
            </select>
          </div>
        </li>
      ))}
    </ul>
  );
}

export function CustomRequestList({ requests }: { requests: CustomRequestRow[] }) {
  const [isPending, startTransition] = useTransition();

  if (requests.length === 0) {
    return <p className="px-5 py-8 text-center text-sm text-zinc-500">Özel yazılım talebi yok.</p>;
  }

  return (
    <ul className="divide-y divide-zinc-100">
      {requests.map((request) => (
        <li key={request.id} className="px-5 py-4">
          <div className="flex items-start justify-between gap-3">
            <div>
              <p className="font-medium text-zinc-900">{request.business_name ?? request.requester_name}</p>
              <p className="text-xs text-zinc-500">
                {request.requester_name} · {request.phone} · {request.email} ·{" "}
                {new Date(request.created_at).toLocaleDateString("tr-TR")}
              </p>
              <p className="mt-2 text-sm text-zinc-600">{request.need}</p>
              {request.description && <p className="mt-1 text-sm text-zinc-500">{request.description}</p>}
            </div>
            <select
              defaultValue={request.status}
              disabled={isPending}
              onChange={(e) =>
                startTransition(() => {
                  updateCustomSoftwareRequestStatus(
                    request.id,
                    e.target.value as CustomSoftwareRequestStatus
                  );
                })
              }
              className={selectClass}
            >
              {customStatuses.map((status) => (
                <option key={status} value={status}>
                  {customStatusLabels[status]}
                </option>
              ))}
            </select>
          </div>
        </li>
      ))}
    </ul>
  );
}
