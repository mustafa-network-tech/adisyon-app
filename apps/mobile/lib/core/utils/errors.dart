import 'package:supabase_flutter/supabase_flutter.dart';

/// Postgres RAISE EXCEPTION messages from the plan-limit / trial
/// triggers (20260922000022) carry a machine-checkable prefix.
/// Translate those into a plain-language message (section 26 of the
/// architecture doc) instead of a raw error code; anything else falls
/// back to the given default.
String friendlyWriteErrorMessage(Object error, String fallback) {
  final message = error is PostgrestException
      ? error.message
      : error.toString();

  if (message.contains('PLAN_LIMIT_EXCEEDED')) {
    return 'Planınızın izin verdiği sınıra ulaşıldı. Lütfen işletme yöneticinizle iletişime geçin.';
  }
  if (message.contains('TRIAL_OR_SUBSCRIPTION_INACTIVE')) {
    return 'Deneme süreniz sona erdi veya aboneliğiniz aktif değil. Lütfen işletme yöneticinizle iletişime geçin.';
  }
  return fallback;
}
