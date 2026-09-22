import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';

/// Local-only pending order for one table visit. Nothing here touches
/// Supabase -- it exists purely so the waiter can pick several products
/// before a single "Mutfağa Gönder" submits them all as real order_items
/// rows (see WaiterRepository.submitCart). Cleared on submit or when the
/// waiter navigates away without sending.
class CartController extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => const [];

  void add(ProductModel product, {required int quantity, String? note}) {
    state = [
      ...state,
      CartItem(product: product, quantity: quantity, note: note),
    ];
  }

  void removeAt(int index) {
    final next = [...state]..removeAt(index);
    state = next;
  }

  void clear() {
    state = const [];
  }

  int get itemCount => state.fold(0, (sum, item) => sum + item.quantity);

  double get total => state.fold(0, (sum, item) => sum + item.lineTotal);
}

final cartControllerProvider =
    NotifierProvider.autoDispose<CartController, List<CartItem>>(
      CartController.new,
    );
