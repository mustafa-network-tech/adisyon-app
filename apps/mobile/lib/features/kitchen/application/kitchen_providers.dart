import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../auth/application/role_context.dart';
import '../data/kitchen_repository.dart';
import '../domain/models.dart';

final kitchenRepositoryProvider = Provider<KitchenRepository>((ref) {
  return KitchenRepository(ref.watch(supabaseClientProvider));
});

final _businessIdProvider = Provider.autoDispose<String?>((ref) {
  return ref.watch(roleContextProvider).value?.businessId;
});

final _activeItemsStreamProvider =
    StreamProvider.autoDispose<List<KitchenItem>>((ref) {
      final businessId = ref.watch(_businessIdProvider);
      if (businessId == null) return const Stream.empty();
      return ref.watch(kitchenRepositoryProvider).watchActiveItems(businessId);
    });

final _openOrdersStreamProvider =
    StreamProvider.autoDispose<List<OpenOrderInfo>>((ref) {
      final businessId = ref.watch(_businessIdProvider);
      if (businessId == null) return const Stream.empty();
      return ref.watch(kitchenRepositoryProvider).watchOpenOrders(businessId);
    });

final _tableNamesProvider = FutureProvider.autoDispose<Map<String, String>>((
  ref,
) async {
  final businessId = ref.watch(_businessIdProvider);
  if (businessId == null) return const {};
  return ref.watch(kitchenRepositoryProvider).fetchTableNames(businessId);
});

/// Combines the three independent realtime/one-shot sources above into
/// per-table tickets. Kept as plain grouping logic (no extra package)
/// since it's just three lists joined by id -- not complex enough to
/// justify a dependency.
final kitchenTicketsProvider =
    Provider.autoDispose<AsyncValue<List<KitchenTicket>>>((ref) {
      final itemsAsync = ref.watch(_activeItemsStreamProvider);
      final ordersAsync = ref.watch(_openOrdersStreamProvider);
      final tableNamesAsync = ref.watch(_tableNamesProvider);

      if (itemsAsync.hasError) {
        return AsyncValue.error(itemsAsync.error!, itemsAsync.stackTrace!);
      }
      if (ordersAsync.hasError) {
        return AsyncValue.error(ordersAsync.error!, ordersAsync.stackTrace!);
      }
      if (tableNamesAsync.hasError) {
        return AsyncValue.error(
          tableNamesAsync.error!,
          tableNamesAsync.stackTrace!,
        );
      }

      final items = itemsAsync.value;
      final orders = ordersAsync.value;
      final tableNames = tableNamesAsync.value;
      if (items == null || orders == null || tableNames == null) {
        return const AsyncValue.loading();
      }

      final ordersById = {for (final order in orders) order.id: order};
      final grouped = <String, List<KitchenItem>>{};
      for (final item in items) {
        grouped.putIfAbsent(item.orderId, () => []).add(item);
      }

      final tickets = <KitchenTicket>[];
      for (final entry in grouped.entries) {
        final order = ordersById[entry.key];
        // Order closed/cancelled between the two streams settling -- its
        // items will disappear from `items` shortly too; skip for now.
        if (order == null) continue;

        final sortedItems = [...entry.value]
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

        tickets.add(
          KitchenTicket(
            orderId: entry.key,
            tableName: tableNames[order.tableId] ?? '—',
            openedAt: order.openedAt,
            items: sortedItems,
          ),
        );
      }
      tickets.sort((a, b) => a.openedAt.compareTo(b.openedAt));

      return AsyncValue.data(tickets);
    });
