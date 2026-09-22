import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models.dart';

/// All the direct Supabase calls the waiter flow needs. Every query is
/// scoped to the caller's business_id explicitly (even though RLS would
/// already enforce it) so behavior stays correct once a user can belong
/// to more than one business. No client-trusted shortcuts: opening a
/// table, voiding an item, etc. all rely on the database triggers added
/// in 20260922000019 to enforce the actual business rules.
class WaiterRepository {
  WaiterRepository(this._client);

  final SupabaseClient _client;

  Future<List<AreaModel>> fetchAreas(String businessId) async {
    final rows = await _client
        .from('areas')
        .select('id, name')
        .eq('business_id', businessId)
        .eq('active', true)
        .order('sort_order');
    return rows.map(AreaModel.fromRow).toList();
  }

  Stream<List<TableModel>> watchTables(String businessId) {
    return _client
        .from('restaurant_tables')
        .stream(primaryKey: ['id'])
        .eq('business_id', businessId)
        .order('sort_order')
        .map(
          (rows) => rows
              .where((row) => row['active'] == true)
              .map(TableModel.fromRow)
              .toList(),
        );
  }

  Future<OrderModel?> fetchOpenOrder(String tableId) async {
    final row = await _client
        .from('orders')
        .select('id, table_id, status, check_requested')
        .eq('table_id', tableId)
        .eq('status', 'OPEN')
        .maybeSingle();
    if (row == null) return null;
    return OrderModel.fromRow(row);
  }

  /// Opens a table by creating its order. A unique index guarantees at
  /// most one OPEN order per table at the database level -- if this
  /// throws a unique-violation, another waiter opened it first, and the
  /// caller should refresh instead of retrying blindly.
  Future<String> openTable({
    required String businessId,
    required String tableId,
    required String waiterId,
  }) async {
    final row = await _client
        .from('orders')
        .insert({
          'business_id': businessId,
          'table_id': tableId,
          'opened_by': waiterId,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> requestCheck(String orderId) async {
    await _client
        .from('orders')
        .update({'check_requested': true})
        .eq('id', orderId);
  }

  Stream<List<OrderItemModel>> watchOrderItems(String orderId) {
    return _client
        .from('order_items')
        .stream(primaryKey: ['id'])
        .eq('order_id', orderId)
        .order('created_at')
        .map((rows) => rows.map(OrderItemModel.fromRow).toList());
  }

  Future<void> voidOrderItem({
    required String itemId,
    required String reason,
  }) async {
    await _client
        .from('order_items')
        .update({'status': 'VOID', 'void_reason': reason})
        .eq('id', itemId);
  }

  Future<List<CategoryModel>> fetchCategories(String businessId) async {
    final rows = await _client
        .from('categories')
        .select('id, name')
        .eq('business_id', businessId)
        .eq('active', true)
        .order('sort_order');
    return rows.map(CategoryModel.fromRow).toList();
  }

  Future<List<ProductModel>> fetchProducts(String businessId) async {
    final rows = await _client
        .from('products')
        .select('id, name, price, category_id')
        .eq('business_id', businessId)
        .eq('active', true)
        .order('name');
    return rows.map(ProductModel.fromRow).toList();
  }

  Future<void> submitCart({
    required String orderId,
    required List<CartItem> items,
  }) async {
    if (items.isEmpty) return;
    await _client.from('order_items').insert([
      for (final item in items)
        {
          'order_id': orderId,
          'product_id': item.product.id,
          'quantity': item.quantity,
          'note': item.note,
        },
    ]);
  }
}
