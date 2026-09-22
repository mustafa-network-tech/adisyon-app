"use client";

import { useActionState, useEffect, useRef, useState, useTransition } from "react";
import { createProduct, updateProduct, toggleProductActive, deleteProduct } from "./actions";

interface ActionState {
  error: string | null;
}

const initialState: ActionState = { error: null };

const inputClass =
  "w-full rounded-lg border border-zinc-300 bg-white px-3.5 py-2.5 text-sm text-zinc-900 outline-none placeholder:text-zinc-400 focus:border-zinc-500 focus:ring-1 focus:ring-zinc-500";

const currencyFormatter = new Intl.NumberFormat("tr-TR", {
  style: "currency",
  currency: "TRY",
});

export interface CategoryOption {
  id: string;
  name: string;
}

export interface ProductItem {
  id: string;
  name: string;
  description: string | null;
  price: number;
  active: boolean;
  category_id: string | null;
  category_name: string;
}

export function ProductManager({
  categories,
  products,
}: {
  categories: CategoryOption[];
  products: ProductItem[];
}) {
  const [createState, createAction, createPending] = useActionState<ActionState, FormData>(
    createProduct,
    initialState
  );

  return (
    <div>
      <form action={createAction} className="grid gap-3 rounded-xl border border-zinc-200 bg-white p-5 shadow-sm sm:grid-cols-2">
        <div>
          <label className="mb-1.5 block text-sm font-medium text-zinc-800" htmlFor="new-product-name">
            Ürün Adı
          </label>
          <input id="new-product-name" name="name" required className={inputClass} />
        </div>
        <div>
          <label className="mb-1.5 block text-sm font-medium text-zinc-800" htmlFor="new-product-price">
            Fiyat (₺)
          </label>
          <input
            id="new-product-price"
            name="price"
            type="number"
            step="0.01"
            min={0}
            required
            className={inputClass}
          />
        </div>
        <div>
          <label className="mb-1.5 block text-sm font-medium text-zinc-800" htmlFor="new-product-category">
            Kategori
          </label>
          <select id="new-product-category" name="category_id" className={inputClass}>
            <option value="">Kategorisiz</option>
            {categories.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        </div>
        <div>
          <label className="mb-1.5 block text-sm font-medium text-zinc-800" htmlFor="new-product-description">
            Açıklama
          </label>
          <input id="new-product-description" name="description" className={inputClass} />
        </div>
        <div className="sm:col-span-2">
          <button
            type="submit"
            disabled={createPending}
            className="inline-flex h-10 items-center justify-center rounded-lg bg-zinc-900 px-5 text-sm font-medium text-white hover:bg-zinc-800 disabled:opacity-60"
          >
            {createPending ? "Ekleniyor..." : "Ürün Ekle"}
          </button>
        </div>
      </form>
      {createState.error && <p className="mt-2 text-sm text-red-700">{createState.error}</p>}

      <ul className="mt-6 divide-y divide-zinc-100 overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-sm">
        {products.length === 0 ? (
          <li className="px-5 py-10 text-center text-sm text-zinc-500">Henüz ürün eklenmemiş.</li>
        ) : (
          products.map((product) => (
            <ProductRow key={product.id} product={product} categories={categories} />
          ))
        )}
      </ul>
    </div>
  );
}

function ProductRow({
  product,
  categories,
}: {
  product: ProductItem;
  categories: CategoryOption[];
}) {
  const [editing, setEditing] = useState(false);
  const [confirmingDelete, setConfirmingDelete] = useState(false);
  const [isPending, startTransition] = useTransition();

  const updateWithId = updateProduct.bind(null, product.id);
  const deleteWithId = deleteProduct.bind(null, product.id);

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
      <li className="px-5 py-4">
        <form
          action={updateAction}
          onSubmit={() => {
            submitted.current = true;
          }}
          className="grid gap-3 sm:grid-cols-2"
        >
          <input name="name" defaultValue={product.name} required autoFocus className={inputClass} />
          <input
            name="price"
            type="number"
            step="0.01"
            min={0}
            defaultValue={product.price}
            required
            className={inputClass}
          />
          <select name="category_id" defaultValue={product.category_id ?? ""} className={inputClass}>
            <option value="">Kategorisiz</option>
            {categories.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
          <input name="description" defaultValue={product.description ?? ""} className={inputClass} />
          <div className="flex gap-3 sm:col-span-2">
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
          </div>
        </form>
        {updateState.error && <p className="mt-2 text-sm text-red-700">{updateState.error}</p>}
      </li>
    );
  }

  return (
    <li className="flex flex-wrap items-center justify-between gap-3 px-5 py-3">
      <div>
        <div className="flex items-center gap-2.5">
          <span className={`text-sm font-medium ${product.active ? "text-zinc-900" : "text-zinc-400"}`}>
            {product.name}
          </span>
          <span className="text-xs text-zinc-500">{product.category_name}</span>
          {!product.active && (
            <span className="rounded-full border border-zinc-200 bg-zinc-100 px-2 py-0.5 text-xs text-zinc-500">
              pasif
            </span>
          )}
        </div>
        {product.description && <p className="mt-0.5 text-xs text-zinc-500">{product.description}</p>}
      </div>

      <div className="flex items-center gap-3">
        <span className="text-sm font-semibold text-zinc-900">
          {currencyFormatter.format(product.price)}
        </span>

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
                  toggleProductActive(product.id, !product.active);
                })
              }
              disabled={isPending}
              className="text-sm font-medium text-zinc-600 hover:text-zinc-900 disabled:opacity-60"
            >
              {product.active ? "Pasif Yap" : "Aktif Yap"}
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
