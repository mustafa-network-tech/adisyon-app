class AreaModel {
  const AreaModel({required this.id, required this.name});

  factory AreaModel.fromRow(Map<String, dynamic> row) {
    return AreaModel(id: row['id'] as String, name: row['name'] as String);
  }

  final String id;
  final String name;
}

class TableModel {
  const TableModel({
    required this.id,
    required this.name,
    required this.status,
    required this.areaId,
  });

  factory TableModel.fromRow(Map<String, dynamic> row) {
    return TableModel(
      id: row['id'] as String,
      name: row['name'] as String,
      status: row['status'] as String,
      areaId: row['area_id'] as String,
    );
  }

  final String id;
  final String name;
  final String status;
  final String areaId;
}

class CategoryModel {
  const CategoryModel({required this.id, required this.name});

  factory CategoryModel.fromRow(Map<String, dynamic> row) {
    return CategoryModel(id: row['id'] as String, name: row['name'] as String);
  }

  final String id;
  final String name;
}

class ProductModel {
  const ProductModel({
    required this.id,
    required this.name,
    required this.price,
    required this.categoryId,
  });

  factory ProductModel.fromRow(Map<String, dynamic> row) {
    return ProductModel(
      id: row['id'] as String,
      name: row['name'] as String,
      price: (row['price'] as num).toDouble(),
      categoryId: row['category_id'] as String?,
    );
  }

  final String id;
  final String name;
  final double price;
  final String? categoryId;
}

class OrderModel {
  const OrderModel({
    required this.id,
    required this.tableId,
    required this.status,
    required this.checkRequested,
  });

  factory OrderModel.fromRow(Map<String, dynamic> row) {
    return OrderModel(
      id: row['id'] as String,
      tableId: row['table_id'] as String,
      status: row['status'] as String,
      checkRequested: row['check_requested'] as bool,
    );
  }

  final String id;
  final String tableId;
  final String status;
  final bool checkRequested;
}

class OrderItemModel {
  const OrderItemModel({
    required this.id,
    required this.orderId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.note,
    required this.status,
  });

  factory OrderItemModel.fromRow(Map<String, dynamic> row) {
    return OrderItemModel(
      id: row['id'] as String,
      orderId: row['order_id'] as String,
      productName: row['product_name_snapshot'] as String,
      unitPrice: (row['unit_price_snapshot'] as num).toDouble(),
      quantity: row['quantity'] as int,
      note: row['note'] as String?,
      status: row['status'] as String,
    );
  }

  final String id;
  final String orderId;
  final String productName;
  final double unitPrice;
  final int quantity;
  final String? note;
  final String status;

  double get lineTotal => unitPrice * quantity;
}

/// A product the waiter has picked but not yet sent to the kitchen --
/// purely local UI state until "Mutfağa Gönder" submits it as real
/// order_items rows.
class CartItem {
  const CartItem({required this.product, required this.quantity, this.note});

  final ProductModel product;
  final int quantity;
  final String? note;

  double get lineTotal => product.price * quantity;

  CartItem copyWith({int? quantity, String? note}) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
    );
  }
}
