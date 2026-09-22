"use client";

import { useActionState, useRef, useState, useTransition } from "react";
import { inviteStaff, updateStaffRole, toggleStaffActive } from "./actions";
import type { MembershipRole } from "@/lib/supabase/database.types";

interface ActionState {
  error: string | null;
}

const initialState: ActionState = { error: null };

const inputClass =
  "w-full rounded-lg border border-zinc-300 bg-white px-3.5 py-2.5 text-sm text-zinc-900 outline-none placeholder:text-zinc-400 focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500";

const roleLabels: Record<MembershipRole, string> = {
  BUSINESS_ADMIN: "İşletme Yöneticisi",
  CASHIER: "Kasiyer",
  WAITER: "Garson",
  KITCHEN: "Mutfak",
};

const roleOptions: MembershipRole[] = ["BUSINESS_ADMIN", "CASHIER", "WAITER", "KITCHEN"];

export interface StaffItem {
  membershipId: string;
  userId: string;
  fullName: string | null;
  email: string | null;
  role: MembershipRole;
  active: boolean;
}

export function StaffManager({
  staff,
  currentUserId,
}: {
  staff: StaffItem[];
  currentUserId: string;
}) {
  const [inviteState, inviteAction, invitePending] = useActionState<ActionState, FormData>(
    inviteStaff,
    initialState
  );
  const formRef = useRef<HTMLFormElement>(null);

  return (
    <div>
      <form
        ref={formRef}
        action={async (formData) => {
          await inviteAction(formData);
          formRef.current?.reset();
        }}
        className="grid gap-3 rounded-xl border border-zinc-200 bg-white p-5 shadow-sm sm:grid-cols-3"
      >
        <div>
          <label className="mb-1.5 block text-sm font-medium text-zinc-800" htmlFor="invite-email">
            E-posta
          </label>
          <input id="invite-email" name="email" type="email" required className={inputClass} />
        </div>
        <div>
          <label className="mb-1.5 block text-sm font-medium text-zinc-800" htmlFor="invite-name">
            Ad Soyad
          </label>
          <input id="invite-name" name="full_name" className={inputClass} />
        </div>
        <div>
          <label className="mb-1.5 block text-sm font-medium text-zinc-800" htmlFor="invite-role">
            Rol
          </label>
          <select id="invite-role" name="role" defaultValue="WAITER" className={inputClass}>
            {roleOptions.map((role) => (
              <option key={role} value={role}>
                {roleLabels[role]}
              </option>
            ))}
          </select>
        </div>
        <div className="sm:col-span-3">
          <button
            type="submit"
            disabled={invitePending}
            className="inline-flex h-10 items-center justify-center rounded-lg bg-zinc-900 px-5 text-sm font-medium text-white hover:bg-zinc-800 disabled:opacity-60"
          >
            {invitePending ? "Davet Gönderiliyor..." : "Personel Davet Et"}
          </button>
        </div>
      </form>
      {inviteState.error && <p className="mt-2 text-sm text-red-700">{inviteState.error}</p>}

      <ul className="mt-6 divide-y divide-zinc-100 overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-sm">
        {staff.length === 0 ? (
          <li className="px-5 py-10 text-center text-sm text-zinc-500">Henüz personel eklenmemiş.</li>
        ) : (
          staff.map((member) => (
            <StaffRow key={member.membershipId} member={member} isSelf={member.userId === currentUserId} />
          ))
        )}
      </ul>
    </div>
  );
}

function StaffRow({ member, isSelf }: { member: StaffItem; isSelf: boolean }) {
  const [rowError, setRowError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  const updateRoleWithIds = updateStaffRole.bind(null, member.membershipId, member.userId);
  const [roleState, roleAction] = useActionState<ActionState, FormData>(
    updateRoleWithIds,
    initialState
  );

  const formRef = useRef<HTMLFormElement>(null);

  return (
    <li className="flex flex-wrap items-center justify-between gap-3 px-5 py-3">
      <div>
        <div className="flex items-center gap-2">
          <span className="text-sm font-medium text-zinc-900">
            {member.fullName || member.email || "İsimsiz kullanıcı"}
          </span>
          {isSelf && (
            <span className="rounded-full border border-zinc-200 bg-zinc-100 px-2 py-0.5 text-xs text-zinc-500">
              siz
            </span>
          )}
          {!member.active && (
            <span className="rounded-full border border-zinc-200 bg-zinc-100 px-2 py-0.5 text-xs text-zinc-500">
              pasif
            </span>
          )}
        </div>
        {member.email && member.fullName && (
          <p className="text-xs text-zinc-500">{member.email}</p>
        )}
      </div>

      <div className="flex items-center gap-3">
        <form ref={formRef} action={roleAction}>
          <select
            name="role"
            defaultValue={member.role}
            disabled={isSelf}
            onChange={() => formRef.current?.requestSubmit()}
            className="rounded-lg border border-zinc-300 bg-white px-3 py-1.5 text-sm text-zinc-900 outline-none focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500 disabled:cursor-not-allowed disabled:bg-zinc-50 disabled:text-zinc-400"
          >
            {roleOptions.map((role) => (
              <option key={role} value={role}>
                {roleLabels[role]}
              </option>
            ))}
          </select>
        </form>

        <button
          type="button"
          disabled={isSelf || isPending}
          onClick={() =>
            startTransition(async () => {
              const result = await toggleStaffActive(member.membershipId, member.userId, !member.active);
              setRowError(result.error);
            })
          }
          className="text-sm font-medium text-zinc-600 hover:text-zinc-900 disabled:cursor-not-allowed disabled:opacity-40"
        >
          {member.active ? "Pasif Yap" : "Aktif Yap"}
        </button>
      </div>

      {(roleState.error || rowError) && (
        <p className="w-full text-sm text-red-700">{roleState.error || rowError}</p>
      )}
    </li>
  );
}
