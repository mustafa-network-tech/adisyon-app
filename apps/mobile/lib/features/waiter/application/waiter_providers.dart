import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../auth/application/auth_providers.dart';
import '../../auth/application/role_context.dart';
import '../data/waiter_repository.dart';
import '../domain/models.dart';

final waiterRepositoryProvider = Provider<WaiterRepository>((ref) {
  return WaiterRepository(ref.watch(supabaseClientProvider));
});

/// The waiter's business id, resolved once via roleContextProvider. Every
/// provider below depends on this rather than re-resolving it, so a
/// missing/failed role lookup surfaces once instead of scattered
/// null-checks everywhere.
final _businessIdProvider = Provider<String?>((ref) {
  return ref.watch(roleContextProvider).value?.businessId;
});

final areasProvider = FutureProvider.autoDispose<List<AreaModel>>((ref) async {
  final businessId = ref.watch(_businessIdProvider);
  if (businessId == null) return const [];
  return ref.watch(waiterRepositoryProvider).fetchAreas(businessId);
});

final tablesStreamProvider = StreamProvider.autoDispose<List<TableModel>>((
  ref,
) {
  final businessId = ref.watch(_businessIdProvider);
  if (businessId == null) return const Stream.empty();
  return ref.watch(waiterRepositoryProvider).watchTables(businessId);
});

final selectedAreaIdProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final categoriesProvider = FutureProvider.autoDispose<List<CategoryModel>>((
  ref,
) async {
  final businessId = ref.watch(_businessIdProvider);
  if (businessId == null) return const [];
  return ref.watch(waiterRepositoryProvider).fetchCategories(businessId);
});

final productsProvider = FutureProvider.autoDispose<List<ProductModel>>((
  ref,
) async {
  final businessId = ref.watch(_businessIdProvider);
  if (businessId == null) return const [];
  return ref.watch(waiterRepositoryProvider).fetchProducts(businessId);
});

final openOrderProvider = FutureProvider.autoDispose
    .family<OrderModel?, String>((ref, tableId) async {
      return ref.watch(waiterRepositoryProvider).fetchOpenOrder(tableId);
    });

final orderItemsStreamProvider = StreamProvider.autoDispose
    .family<List<OrderItemModel>, String>((ref, orderId) {
      return ref.watch(waiterRepositoryProvider).watchOrderItems(orderId);
    });
