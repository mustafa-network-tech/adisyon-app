"use client";

import { useActionState, useEffect, useRef, useState, useTransition } from "react";
import { createTable, updateTable, toggleTableActive, deleteTable } from "./actions";
import type { TableStatus } from "@/lib/supabase/database.types";

interface ActionState {
  error: string | null;
}

const initialState: ActionState = { error: null };

const inputClass =
  "w-full rounded-lg border border-zinc-300 bg-white px-3.5 py-2.5 text-sm text-zinc-900 outline-none placeholder:text-zinc-400 focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500";

const statusLabels: Record<TableStatus, string> = {
  AVAILABLE: "Boş",
  OCCUPIED: "Dolu",
  CHECK_REQUESTED: "Hesap İstendi",
};

const statusBadgeClass: Record<TableStatus, string> = {
  AVAILABLE: "bg-emerald-50 text-emerald-700 border-emerald-200",
  OCCUPIED: "bg-amber-50 text-amber-700 border-amber-200",
  CHECK_REQUESTED: "bg-red-50 text-red-700 border-red-200",
};

export interface AreaOption {
  id: string;
  name: string;
}

export interface TableItem {
  id: string;
  name: string;
  active: boolean;
  status: TableStatus;
  area_id: string;
  area_name: string;
}

export function TableManager({ areas, tables }: { areas: AreaOption[]; tables: TableItem[] }) {
  const [createState, createAction, createPending] = useActionState<ActionState, FormData>(
    createTable,
    initialState
  );

  if (areas.length === 0) {
    return (
      <p className="rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
        Masa ekleyebilmek için önce en az bir alan oluşturmalısınız.
      </p>
    );
  }

  return (
    <div>
      <form action={createAction} className="flex flex-wrap items-end gap-3">
        <div className="min-w-48 flex-1">
          <label className="mb-1.5 block text-sm font-medium text-zinc-800" htmlFor="new-table-name">
            Yeni Masa
          </label>
          <input id="new-table-name" name="name" required placeholder="Masa adı" className={inputClass} />
        </div>
        <div className="min-w-44">
          <label className="mb-1.5 block text-sm font-medium text-zinc-800" htmlFor="new-table-area">
            Alan
          </label>
          <select id="new-table-area" name="area_id" required className={inputClass}>
            {areas.map((area) => (
              <option key={area.id} value={area.id}>
                {area.name}
              </option>
            ))}
          </select>
        </div>
        <button
          type="submit"
          disabled={createPending}
          className="inline-flex h-10 items-center justify-center rounded-lg bg-zinc-900 px-5 text-sm font-medium text-white hover:bg-zinc-800 disabled:opacity-60"
        >
          {createPending ? "Ekleniyor..." : "Ekle"}
        </button>
      </form>
      {createState.error && <p className="mt-2 text-sm text-red-700">{createState.error}</p>}

      <ul className="mt-6 divide-y divide-zinc-100 overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-sm">
        {tables.length === 0 ? (
          <li className="px-5 py-10 text-center text-sm text-zinc-500">Henüz masa eklenmemiş.</li>
        ) : (
          tables.map((table) => <TableRow key={table.id} table={table} areas={areas} />)
        )}
      </ul>
    </div>
  );
}

function TableRow({ table, areas }: { table: TableItem; areas: AreaOption[] }) {
  const [editing, setEditing] = useState(false);
  const [confirmingDelete, setConfirmingDelete] = useState(false);
  const [isPending, startTransition] = useTransition();

  const updateWithId = updateTable.bind(null, table.id);
  const deleteWithId = deleteTable.bind(null, table.id);

  const [updateState, updateAction, updatePending] = useActionState<ActionState, FormData>(
    updateWithId,
    initialState
  );
  const [deleteState, deleteAction, deletePending] = useActionState<ActionState, FormData>(
    deleteWithId,
    initialState
  );

  const submitted = useRef(false);
  useEffect(() => {
    if (submitted.current && !updatePending && !updateState.error) {
      setEditing(false);
      submitted.current = false;
    }
  }, [updatePending, updateState]);

  if (editing) {
    return (
      <li className="px-5 py-3">
        <form
          action={updateAction}
          onSubmit={() => {
            submitted.current = true;
          }}
          className="flex flex-wrap items-center gap-3"
        >
          <input name="name" defaultValue={table.name} required autoFocus className={`${inputClass} max-w-xs`} />
          <select name="area_id" defaultValue={table.area_id} className={`${inputClass} max-w-44`}>
            {areas.map((area) => (
              <option key={area.id} value={area.id}>
                {area.name}
              </option>
            ))}
          </select>
          <button
            type="submit"
            disabled={updatePending}
            className="inline-flex h-9 items-center justify-center rounded-lg bg-zinc-900 px-4 text-sm font-medium text-white hover:bg-zinc-800 disabled:opacity-60"
          >
            Kaydet
          </button>
          <button
            type="button"
            onClick={() => setEditing(false)}
            className="inline-flex h-9 items-center justify-center rounded-lg border border-zinc-300 bg-white px-4 text-sm font-medium text-zinc-900 hover:bg-zinc-50"
          >
            Vazgeç
          </button>
        </form>
        {updateState.error && <p className="mt-2 text-sm text-red-700">{updateState.error}</p>}
      </li>
    );
  }

  return (
    <li className="flex flex-wrap items-center justify-between gap-3 px-5 py-3">
      <div className="flex items-center gap-2.5">
        <span className={`text-sm font-medium ${table.active ? "text-zinc-900" : "text-zinc-400"}`}>
          {table.name}
        </span>
        <span className="text-xs text-zinc-500">{table.area_name}</span>
        <span
          className={`inline-flex rounded-full border px-2 py-0.5 text-xs font-medium ${statusBadgeClass[table.status]}`}
        >
          {statusLabels[table.status]}
        </span>
        {!table.active && (
          <span className="rounded-full border border-zinc-200 bg-zinc-100 px-2 py-0.5 text-xs text-zinc-500">
            pasif
          </span>
        )}
      </div>

      <div className="flex items-center gap-2">
        {confirmingDelete ? (
          <>
            <span className="text-sm text-zinc-600">Emin misiniz?</span>
            <form action={deleteAction}>
              <button
                type="submit"
                disabled={deletePending}
                className="text-sm font-medium text-red-600 hover:text-red-500 disabled:opacity-60"
              >
                Evet, sil
              </button>
            </form>
            <button
              type="button"
              onClick={() => setConfirmingDelete(false)}
              className="text-sm font-medium text-zinc-500 hover:text-zinc-800"
            >
              Vazgeç
            </button>
          </>
        ) : (
          <>
            <button
              type="button"
              onClick={() =>
                startTransition(() => {
                  toggleTableActive(table.id, !table.active);
                })
              }
              disabled={isPending}
              className="text-sm font-medium text-zinc-600 hover:text-zinc-900 disabled:opacity-60"
            >
              {table.active ? "Pasif Yap" : "Aktif Yap"}
            </button>
            <button
              type="button"
              onClick={() => setEditing(true)}
              className="text-sm font-medium text-zinc-600 hover:text-zinc-900"
            >
              Düzenle
            </button>
            <button
              type="button"
              onClick={() => setConfirmingDelete(true)}
              className="text-sm font-medium text-red-600 hover:text-red-500"
            >
              Sil
            </button>
          </>
        )}
      </div>
      {deleteState.error && <p className="text-sm text-red-700">{deleteState.error}</p>}
    </li>
  );
}
