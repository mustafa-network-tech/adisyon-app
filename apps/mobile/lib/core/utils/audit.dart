import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around the log_audit_event RPC (see
/// supabase/migrations/20260922000016_audit_logs.sql). Used for the
/// "iptal" actions section 30 of the architecture doc calls out
/// explicitly (order cancellation, item/payment void) -- routine
/// creates (opening a table, adding an item, taking a payment) are not
/// logged here; the orders/order_items/payments rows are already that
/// record.
Future<void> logAuditEvent(
  SupabaseClient client, {
  required String businessId,
  required String action,
  required String entity,
  String? entityId,
  Map<String, dynamic> metadata = const {},
}) {
  return client.rpc(
    'log_audit_event',
    params: {
      'p_business_id': businessId,
      'p_action': action,
      'p_entity': entity,
      'p_entity_id': entityId,
      'p_metadata': metadata,
    },
  );
}
