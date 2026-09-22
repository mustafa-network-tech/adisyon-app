/// Active statuses shown on the kitchen board, in lifecycle order.
/// SERVED/VOID items fall off the board -- a kitchen display exists to
/// show what still needs attention, not a full history (that's the
/// waiter's/cashier's screens).
const List<String> kitchenActiveStatuses = ['NEW', 'PREPARING', 'READY'];

/// The status a tap on an item's action button moves it to. null means
/// there is no further kitchen action (already at the last stage).
String? nextKitchenStatus(String status) {
  switch (status) {
    case 'NEW':
      return 'PREPARING';
    case 'PREPARING':
      return 'READY';
    case 'READY':
      return 'SERVED';
    default:
      return null;
  }
}

class KitchenItem {
  const KitchenItem({
    required this.id,
    required this.orderId,
    required this.productName,
    required this.quantity,
    required this.note,
    required this.status,
    required this.createdAt,
  });

  factory KitchenItem.fromRow(Map<String, dynamic> row) {
    return KitchenItem(
      id: row['id'] as String,
      orderId: row['order_id'] as String,
      productName: row['product_name_snapshot'] as String,
      quantity: row['quantity'] as int,
      note: row['note'] as String?,
      status: row['status'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  final String id;
  final String orderId;
  final String productName;
  final int quantity;
  final String? note;
  final String status;
  final DateTime createdAt;
}

class OpenOrderInfo {
  const OpenOrderInfo({
    required this.id,
    required this.tableId,
    required this.openedAt,
  });

  factory OpenOrderInfo.fromRow(Map<String, dynamic> row) {
    return OpenOrderInfo(
      id: row['id'] as String,
      tableId: row['table_id'] as String,
      openedAt: DateTime.parse(row['opened_at'] as String),
    );
  }

  final String id;
  final String tableId;
  final DateTime openedAt;
}

/// One "ticket" on the kitchen board -- everything still active for a
/// single table's open order, grouped together the way a physical
/// kitchen ticket would be.
class KitchenTicket {
  const KitchenTicket({
    required this.orderId,
    required this.tableName,
    required this.openedAt,
    required this.items,
  });

  final String orderId;
  final String tableName;
  final DateTime openedAt;
  final List<KitchenItem> items;
}
