import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models.dart';

/// Kitchen board data. Deliberately reads only what the kitchen screen
/// needs to run (product/qty/note/status/table/time) -- no prices, no
/// payments, no totals. `order_items.stream()` can't join across tables,
/// so open orders and table names are streamed/fetched separately and
/// combined client-side in kitchen_providers.dart rather than adding a
/// denormalized column just for this screen's convenience.
class KitchenRepository {
  KitchenRepository(this._client);

  final SupabaseClient _client;

  Stream<List<KitchenItem>> watchActiveItems(String businessId) {
    return _client
        .from('order_items')
        .stream(primaryKey: ['id'])
        .eq('business_id', businessId)
        .order('created_at')
        .map(
          (rows) => rows
              .where((row) => kitchenActiveStatuses.contains(row['status']))
              .map(KitchenItem.fromRow)
              .toList(),
        );
  }

  Stream<List<OpenOrderInfo>> watchOpenOrders(String businessId) {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('business_id', businessId)
        .map(
          (rows) => rows
              .where((row) => row['status'] == 'OPEN')
              .map(OpenOrderInfo.fromRow)
              .toList(),
        );
  }

  Future<Map<String, String>> fetchTableNames(String businessId) async {
    final rows = await _client
        .from('restaurant_tables')
        .select('id, name')
        .eq('business_id', businessId);
    return {for (final row in rows) row['id'] as String: row['name'] as String};
  }

  Future<void> advanceStatus({
    required String itemId,
    required String nextStatus,
  }) async {
    await _client
        .from('order_items')
        .update({'status': nextStatus})
        .eq('id', itemId);
  }
}
