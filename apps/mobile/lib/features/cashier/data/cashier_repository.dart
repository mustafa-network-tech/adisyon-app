import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models.dart';

/// Cashier board + per-order payment data. Amounts/method are the only
/// financial writes this app makes -- received_by/voided_by/voided_at
/// are always server-derived (see migration 20260922000020), never sent
/// from here, so this repository never even tries to set them.
class CashierRepository {
  CashierRepository(this._client);

  final SupabaseClient _client;

  Stream<List<Map<String, dynamic>>> watchOpenOrders(String businessId) {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('business_id', businessId)
        .map((rows) => rows.where((r) => r['status'] == 'OPEN').toList());
  }

  Stream<List<Map<String, dynamic>>> watchActiveOrderItems(String businessId) {
    return _client
        .from('order_items')
        .stream(primaryKey: ['id'])
        .eq('business_id', businessId)
        .map((rows) => rows.where((r) => r['status'] != 'VOID').toList());
  }

  Future<Map<String, String>> fetchTableNames(String businessId) async {
    final rows = await _client
        .from('restaurant_tables')
        .select('id, name')
        .eq('business_id', businessId);
    return {for (final row in rows) row['id'] as String: row['name'] as String};
  }

  Stream<String> watchOrderStatus(String orderId) {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .map(
          (rows) => rows.isEmpty ? 'CLOSED' : rows.first['status'] as String,
        );
  }

  Stream<List<CashierOrderItem>> watchOrderItems(String orderId) {
    return _client
        .from('order_items')
        .stream(primaryKey: ['id'])
        .eq('order_id', orderId)
        .order('created_at')
        .map((rows) => rows.map(CashierOrderItem.fromRow).toList());
  }

  Stream<List<CashierPayment>> watchPayments(String orderId) {
    return _client
        .from('payments')
        .stream(primaryKey: ['id'])
        .eq('order_id', orderId)
        .order('created_at')
        .map((rows) => rows.map(CashierPayment.fromRow).toList());
  }

  Future<void> addPayment({
    required String orderId,
    required String method,
    required double amount,
  }) async {
    await _client.from('payments').insert({
      'order_id': orderId,
      'method': method,
      'amount': amount,
    });
  }

  Future<void> voidPayment({
    required String paymentId,
    required String reason,
  }) async {
    await _client
        .from('payments')
        .update({'status': 'VOID', 'void_reason': reason})
        .eq('id', paymentId);
  }

  Future<void> voidItem({
    required String itemId,
    required String reason,
  }) async {
    await _client
        .from('order_items')
        .update({'status': 'VOID', 'void_reason': reason})
        .eq('id', itemId);
  }

  Future<void> closeOrder(String orderId) async {
    await _client.from('orders').update({'status': 'CLOSED'}).eq('id', orderId);
  }

  Future<void> cancelOrder(String orderId) async {
    await _client
        .from('orders')
        .update({'status': 'CANCELLED'})
        .eq('id', orderId);
  }
}
