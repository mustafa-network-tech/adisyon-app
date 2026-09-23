import type { createClient } from "@/lib/supabase/server";

// The plans table is the single source of plan names, prices and limits
// (managed from Super Admin → Planlar). yearly_price is computed by the
// database (monthly × 12 − yearly_discount), so nothing here does its own
// price math beyond display helpers. In the Android app the price charged
// at checkout is always Google Play's localized price, not these values.

type ServerSupabase = Awaited<ReturnType<typeof createClient>>;

export interface CatalogPlan {
  id: string;
  code: string;
  name: string;
  monthlyPrice: number;
  yearlyPrice: number;
  yearlyDiscount: number;
  maxTables: number | null;
  maxWaiters: number | null;
  maxAreas: number | null;
  maxBranches: number | null;
  qrMenuEnabled: boolean;
}

export interface TrialSettings {
  appTrialDays: number;
  trialPlanName: string | null;
}

// The MK Adisyon app trial length and the plan whose rights apply during
// any free period both live in subscription_settings (Super Admin →
// Ayarlar); create_own_business reads the same row. Display only here.
export async function getTrialSettings(supabase: ServerSupabase): Promise<TrialSettings> {
  const { data } = await supabase
    .from("subscription_settings")
    .select("app_trial_days, trial_plan_code")
    .maybeSingle();
  const { data: plan } = data
    ? await supabase.from("plans").select("name").eq("code", data.trial_plan_code).maybeSingle()
    : { data: null };
  return { appTrialDays: data?.app_trial_days ?? 0, trialPlanName: plan?.name ?? null };
}

export async function getCatalogPlans(supabase: ServerSupabase): Promise<CatalogPlan[]> {
  const { data } = await supabase
    .from("plans")
    .select(
      "id, code, name, monthly_price, yearly_price, yearly_discount, max_tables, max_waiters, max_areas, max_branches, qr_menu_enabled"
    )
    .eq("active", true)
    .not("code", "is", null)
    .order("sort_order", { ascending: true });

  return (data ?? []).map((row) => ({
    id: row.id,
    code: row.code as string,
    name: row.name,
    monthlyPrice: Number(row.monthly_price),
    yearlyPrice: Number(row.yearly_price),
    yearlyDiscount: Number(row.yearly_discount),
    maxTables: row.max_tables,
    maxWaiters: row.max_waiters,
    maxAreas: row.max_areas,
    maxBranches: row.max_branches,
    qrMenuEnabled: row.qr_menu_enabled,
  }));
}

const wholeFormatter = new Intl.NumberFormat("tr-TR", { maximumFractionDigits: 0 });
const decimalFormatter = new Intl.NumberFormat("tr-TR", {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

/** 1899 -> "1.899 TL", 4309.2 -> "4.309,20 TL" */
export function formatTl(value: number): string {
  const formatter = Number.isInteger(value) ? wholeFormatter : decimalFormatter;
  return `${formatter.format(value)} TL`;
}

/** 10 -> "%10" (Turkish puts the sign first) */
export function formatPercent(value: number): string {
  return `%${wholeFormatter.format(value)}`;
}

function limitText(value: number | null, unit: string): string {
  return value === null ? `Sınırsız ${unit}` : `${value} ${unit}`;
}

/** Feature bullets derived only from real plan columns / existing modules. */
export function planFeatures(plan: CatalogPlan): string[] {
  const features = [
    limitText(plan.maxBranches ?? 1, "işletme"),
    limitText(plan.maxTables, "masa"),
    limitText(plan.maxWaiters, "garson"),
    limitText(plan.maxAreas, "alan"),
    "Adisyon, kasa ve mutfak ekranları",
    "Satış raporları",
  ];
  if (plan.qrMenuEnabled) features.push("QR Menü");
  return features;
}
