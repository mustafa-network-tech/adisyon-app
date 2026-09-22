"use client";

import { useActionState, useEffect, useRef, useState, useTransition } from "react";
import {
  createSimpleEntity,
  renameSimpleEntity,
  toggleSimpleEntityActive,
  deleteSimpleEntity,
  type SimpleEntityTable,
} from "./simple-entity-actions";

interface ActionState {
  error: string | null;
}

const initialState: ActionState = { error: null };

const inputClass =
  "w-full rounded-lg border border-zinc-300 bg-white px-3.5 py-2.5 text-sm text-zinc-900 outline-none placeholder:text-zinc-400 focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500";

export interface SimpleEntityItem {
  id: string;
  name: string;
  active: boolean;
}

export function SimpleEntityManager({
  table,
  entityLabel,
  items,
}: {
  table: SimpleEntityTable;
  entityLabel: string;
  items: SimpleEntityItem[];
}) {
  const createWithTable = createSimpleEntity.bind(null, table);
  const [createState, createAction, createPending] = useActionState<ActionState, FormData>(
    createWithTable,
    initialState
  );

  return (
    <div>
      <form action={createAction} className="flex flex-wrap items-end gap-3">
        <div className="min-w-56 flex-1">
          <label className="mb-1.5 block text-sm font-medium text-zinc-800" htmlFor="new-name">
            Yeni {entityLabel}
          </label>
          <input
            id="new-name"
            name="name"
            required
            placeholder={`${entityLabel} adı`}
            className={inputClass}
          />
        </div>
        <button
          type="submit"
          disabled={createPending}
          className="inline-flex h-10 items-center justify-center rounded-lg bg-zinc-900 px-5 text-sm font-medium text-white hover:bg-zinc-800 disabled:opacity-60"
        >
          {createPending ? "Ekleniyor..." : "Ekle"}
        </button>
      </form>
      {createState.error && (
        <p className="mt-2 text-sm text-red-700">{createState.error}</p>
      )}

      <ul className="mt-6 divide-y divide-zinc-100 overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-sm">
        {items.length === 0 ? (
          <li className="px-5 py-10 text-center text-sm text-zinc-500">
            Henüz {entityLabel.toLowerCase()} eklenmemiş.
          </li>
        ) : (
          items.map((item) => <EntityRow key={item.id} table={table} item={item} />)
        )}
      </ul>
    </div>
  );
}

function EntityRow({ table, item }: { table: SimpleEntityTable; item: SimpleEntityItem }) {
  const [editing, setEditing] = useState(false);
  const [confirmingDelete, setConfirmingDelete] = useState(false);
  const [isPending, startTransition] = useTransition();

  const renameWithArgs = renameSimpleEntity.bind(null, table, item.id);
  const deleteWithArgs = deleteSimpleEntity.bind(null, table, item.id);

  const [renameState, renameAction, renamePending] = useActionState<ActionState, FormData>(
    renameWithArgs,
    initialState
  );
  const [deleteState, deleteAction, deletePending] = useActionState<ActionState, FormData>(
    deleteWithArgs,
    initialState
  );

  const renameSubmitted = useRef(false);
  useEffect(() => {
    if (renameSubmitted.current && !renamePending && !renameState.error) {
      setEditing(false);
      renameSubmitted.current = false;
    }
  }, [renamePending, renameState]);

  if (editing) {
    return (
      <li className="px-5 py-3">
        <form
          action={renameAction}
          onSubmit={() => {
            renameSubmitted.current = true;
          }}
          className="flex flex-wrap items-center gap-3"
        >
          <input
            name="name"
            defaultValue={item.name}
            required
            autoFocus
            className={`${inputClass} max-w-xs`}
          />
          <button
            type="submit"
            disabled={renamePending}
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
        {renameState.error && <p className="mt-2 text-sm text-red-700">{renameState.error}</p>}
      </li>
    );
  }

  return (
    <li className="flex items-center justify-between gap-3 px-5 py-3">
      <div className="flex items-center gap-2.5">
        <span className={`text-sm font-medium ${item.active ? "text-zinc-900" : "text-zinc-400"}`}>
          {item.name}
        </span>
        {!item.active && (
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
                  toggleSimpleEntityActive(table, item.id, !item.active);
                })
              }
              disabled={isPending}
              className="text-sm font-medium text-zinc-600 hover:text-zinc-900 disabled:opacity-60"
            >
              {item.active ? "Pasif Yap" : "Aktif Yap"}
            </button>
            <button
              type="button"
              onClick={() => setEditing(true)}
              className="text-sm font-medium text-zinc-600 hover:text-zinc-900"
            >
              Yeniden Adlandır
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
