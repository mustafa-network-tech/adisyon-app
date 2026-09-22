class CashierOrderItem {
  const CashierOrderItem({
    required this.id,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.note,
    required this.status,
  });

  factory CashierOrderItem.fromRow(Map<String, dynamic> row) {
    return CashierOrderItem(
      id: row['id'] as String,
      productName: row['product_name_snapshot'] as String,
      unitPrice: (row['unit_price_snapshot'] as num).toDouble(),
      quantity: row['quantity'] as int,
      note: row['note'] as String?,
      status: row['status'] as String,
    );
  }

  final String id;
  final String productName;
  final double unitPrice;
  final int quantity;
  final String? note;
  final String status;

  double get lineTotal => unitPrice * quantity;
}

class CashierPayment {
  const CashierPayment({
    required this.id,
    required this.method,
    required this.amount,
    required this.status,
  });

  factory CashierPayment.fromRow(Map<String, dynamic> row) {
    return CashierPayment(
      id: row['id'] as String,
      method: row['method'] as String,
      amount: (row['amount'] as num).toDouble(),
      status: row['status'] as String,
    );
  }

  final String id;
  final String method;
  final double amount;
  final String status;
}

class CashierTicket {
  const CashierTicket({
    required this.orderId,
    required this.tableName,
    required this.checkRequested,
    required this.openedAt,
    required this.total,
  });

  final String orderId;
  final String tableName;
  final bool checkRequested;
  final DateTime openedAt;
  final double total;
}
