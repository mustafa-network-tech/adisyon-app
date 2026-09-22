// Postgres RAISE EXCEPTION messages from the plan-limit / trial triggers
// (20260922000022) carry a machine-checkable prefix. Translate those into
// the plain-language message section 26 of the architecture doc asks
// for; anything else falls back to a generic message.
export function friendlyWriteErrorMessage(
  error: { message?: string } | null,
  fallback: string
): string {
  const message = error?.message ?? "";

  if (message.includes("PLAN_LIMIT_EXCEEDED")) {
    return "Planınızın izin verdiği sınıra ulaştınız. Daha fazlası için işletme yöneticinizle veya destek ile iletişime geçin.";
  }
  if (message.includes("TRIAL_OR_SUBSCRIPTION_INACTIVE")) {
    return "Deneme süreniz sona erdi veya aboneliğiniz aktif değil. Lütfen destek ile iletişime geçin.";
  }
  return fallback;
}
