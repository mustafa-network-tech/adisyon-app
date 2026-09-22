import { createClient } from "@/lib/supabase/server";

const currencyFormatter = new Intl.NumberFormat("tr-TR", { style: "currency", currency: "TRY" });

// Public, unauthenticated page -- no layout guard. Reads only through
// the two SECURITY DEFINER RPCs (20260922000023), which already encode
// "business active + plan has qr_menu_enabled"; this page does no
// authorization of its own, it just renders what they return (or a
// not-available message when they return nothing).
export default async function QrMenuPage({
  params,
}: {
  params: Promise<{ businessId: string }>;
}) {
  const { businessId } = await params;
  const supabase = await createClient();

  const [businessRes, itemsRes] = await Promise.all([
    supabase.rpc("get_qr_menu_business", { p_business_id: businessId }),
    supabase.rpc("get_qr_menu_items", { p_business_id: businessId }),
  ]);

  const business = businessRes.data?.[0];

  if (!business) {
    return (
      <div className="flex min-h-screen flex-1 items-center justify-center bg-zinc-50 px-6">
        <p className="text-center text-sm text-zinc-600">Bu menü şu anda kullanılamıyor.</p>
      </div>
    );
  }

  const items = itemsRes.data ?? [];
  const categories = new Map<
    string,
    { name: string; products: { id: string; name: string; description: string | null; price: number }[] }
  >();
  for (const row of items) {
    const category = categories.get(row.category_id) ?? { name: row.category_name, products: [] };
    if (row.product_id) {
      category.products.push({
        id: row.product_id,
        name: row.product_name!,
        description: row.product_description,
        price: row.product_price!,
      });
    }
    categories.set(row.category_id, category);
  }

  return (
    <div className="min-h-screen bg-zinc-50">
      <header className="border-b border-zinc-200 bg-white px-6 py-8 text-center">
        <h1 className="text-2xl font-bold text-zinc-900">{business.name}</h1>
        {business.city && <p className="mt-1 text-sm text-zinc-500">{business.city}</p>}
      </header>

      <main className="mx-auto max-w-lg px-6 py-8">
        {categories.size === 0 ? (
          <p className="text-center text-sm text-zinc-500">Menü henüz hazırlanmadı.</p>
        ) : (
          <div className="space-y-8">
            {[...categories.values()].map((category) => (
              <section key={category.name}>
                <h2 className="text-lg font-bold text-zinc-900">{category.name}</h2>
                <div className="mt-3 divide-y divide-zinc-200 rounded-xl border border-zinc-200 bg-white">
                  {category.products.length === 0 ? (
                    <p className="px-4 py-4 text-sm text-zinc-400">Bu kategoride ürün yok.</p>
                  ) : (
                    category.products.map((product) => (
                      <div key={product.id} className="flex items-start justify-between gap-4 px-4 py-3">
                        <div>
                          <p className="font-medium text-zinc-900">{product.name}</p>
                          {product.description && (
                            <p className="mt-0.5 text-sm text-zinc-500">{product.description}</p>
                          )}
                        </div>
                        <span className="shrink-0 font-semibold text-zinc-900">
                          {currencyFormatter.format(product.price)}
                        </span>
                      </div>
                    ))
                  )}
                </div>
              </section>
            ))}
          </div>
        )}
      </main>
    </div>
  );
}
