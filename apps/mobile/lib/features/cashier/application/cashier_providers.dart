import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../auth/application/role_context.dart';
import '../data/cashier_repository.dart';
import '../domain/models.dart';

final cashierRepositoryProvider = Provider<CashierRepository>((ref) {
  return CashierRepository(ref.watch(supabaseClientProvider));
});

final _businessIdProvider = Provider.autoDispose<String?>((ref) {
  return ref.watch(roleContextProvider).value?.businessId;
});

final _openOrdersStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final businessId = ref.watch(_businessIdProvider);
      if (businessId == null) return const Stream.empty();
      return ref.watch(cashierRepositoryProvider).watchOpenOrders(businessId);
    });

final _activeItemsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final businessId = ref.watch(_businessIdProvider);
      if (businessId == null) return const Stream.empty();
      return ref
          .watch(cashierRepositoryProvider)
          .watchActiveOrderItems(businessId);
    });

final _tableNamesProvider = FutureProvider.autoDispose<Map<String, String>>((
  ref,
) async {
  final businessId = ref.watch(_businessIdProvider);
  if (businessId == null) return const {};
  return ref.watch(cashierRepositoryProvider).fetchTableNames(businessId);
});

/// Same three-source-join approach as the kitchen board (Faz 6): orders
/// and order_items streams can't be joined server-side, so they're
/// combined here once all three have data.
final cashierTicketsProvider =
    Provider.autoDispose<AsyncValue<List<CashierTicket>>>((ref) {
      final ordersAsync = ref.watch(_openOrdersStreamProvider);
      final itemsAsync = ref.watch(_activeItemsStreamProvider);
      final tableNamesAsync = ref.watch(_tableNamesProvider);

      if (ordersAsync.hasError) {
        return AsyncValue.error(ordersAsync.error!, ordersAsync.stackTrace!);
      }
      if (itemsAsync.hasError) {
        return AsyncValue.error(itemsAsync.error!, itemsAsync.stackTrace!);
      }
      if (tableNamesAsync.hasError) {
        return AsyncValue.error(
          tableNamesAsync.error!,
          tableNamesAsync.stackTrace!,
        );
      }

      final orders = ordersAsync.value;
      final items = itemsAsync.value;
      final tableNames = tableNamesAsync.value;
      if (orders == null || items == null || tableNames == null) {
        return const AsyncValue.loading();
      }

      final totalsByOrder = <String, double>{};
      for (final item in items) {
        final orderId = item['order_id'] as String;
        final lineTotal =
            (item['unit_price_snapshot'] as num).toDouble() *
            (item['quantity'] as num);
        totalsByOrder[orderId] = (totalsByOrder[orderId] ?? 0) + lineTotal;
      }

      final tickets = orders.map((order) {
        final tableId = order['table_id'] as String;
        return CashierTicket(
          orderId: order['id'] as String,
          tableName: tableNames[tableId] ?? '—',
          checkRequested: order['check_requested'] as bool,
          openedAt: DateTime.parse(order['opened_at'] as String),
          total: totalsByOrder[order['id']] ?? 0,
        );
      }).toList();

      tickets.sort((a, b) {
        if (a.checkRequested != b.checkRequested) {
          return a.checkRequested ? -1 : 1;
        }
        return a.openedAt.compareTo(b.openedAt);
      });

      return AsyncValue.data(tickets);
    });

final orderStatusStreamProvider = StreamProvider.autoDispose
    .family<String, String>((ref, orderId) {
      return ref.watch(cashierRepositoryProvider).watchOrderStatus(orderId);
    });

final cashierOrderItemsStreamProvider = StreamProvider.autoDispose
    .family<List<CashierOrderItem>, String>((ref, orderId) {
      return ref.watch(cashierRepositoryProvider).watchOrderItems(orderId);
    });

final cashierPaymentsStreamProvider = StreamProvider.autoDispose
    .family<List<CashierPayment>, String>((ref, orderId) {
      return ref.watch(cashierRepositoryProvider).watchPayments(orderId);
    });
