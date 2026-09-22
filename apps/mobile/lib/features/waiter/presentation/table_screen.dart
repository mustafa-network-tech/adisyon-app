import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/utils/audit.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/errors.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/application/role_context.dart';
import '../application/waiter_providers.dart';
import '../domain/models.dart';
import 'widgets/order_item_row.dart';

class TableScreen extends ConsumerStatefulWidget {
  const TableScreen({super.key, required this.tableId});

  final String tableId;

  @override
  ConsumerState<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends ConsumerState<TableScreen> {
  bool _busy = false;

  Future<void> _openTable() async {
    final role = ref.read(roleContextProvider).value;
    if (role?.businessId == null) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(waiterRepositoryProvider)
          .openTable(businessId: role!.businessId!, tableId: widget.tableId);
      ref.invalidate(openOrderProvider(widget.tableId));
    } on PostgrestException catch (e) {
      _showError(
        e.code == '23505'
            ? 'Bu masa az önce başka biri tarafından açıldı. Sayfa yenileniyor.'
            : friendlyWriteErrorMessage(
                e,
                'Masa açılamadı. Lütfen tekrar deneyin.',
              ),
      );
      ref.invalidate(openOrderProvider(widget.tableId));
    } catch (_) {
      _showError('Masa açılamadı. İnternet bağlantınızı kontrol edin.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestCheck(String orderId) async {
    setState(() => _busy = true);
    try {
      await ref.read(waiterRepositoryProvider).requestCheck(orderId);
    } catch (_) {
      _showError('Hesap talebi gönderilemedi. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _voidItem(OrderItemModel item) async {
    final reason = await _askVoidReason();
    if (reason == null || reason.trim().isEmpty) return;

    try {
      await ref
          .read(waiterRepositoryProvider)
          .voidOrderItem(itemId: item.id, reason: reason.trim());
      final businessId = ref.read(roleContextProvider).value?.businessId;
      if (businessId != null) {
        await logAuditEvent(
          ref.read(supabaseClientProvider),
          businessId: businessId,
          action: 'ORDER_ITEM_VOIDED',
          entity: 'order_items',
          entityId: item.id,
          metadata: {'reason': reason.trim()},
        );
      }
    } catch (_) {
      _showError('Ürün iptal edilemedi. Lütfen tekrar deneyin.');
    }
  }

  Future<String?> _askVoidReason() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İptal Nedeni'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Örn. müşteri vazgeçti'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(openOrderProvider(widget.tableId));

    return Scaffold(
      appBar: AppBar(title: const Text('Masa')),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: OutlinedButton(
            onPressed: () => ref.invalidate(openOrderProvider(widget.tableId)),
            child: const Text('Tekrar Dene'),
          ),
        ),
        data: (order) {
          if (order == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.table_bar_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Bu masa şu anda boş',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _busy ? null : _openTable,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Masayı Aç'),
                    ),
                  ],
                ),
              ),
            );
          }

          return _OpenOrderView(
            order: order,
            busy: _busy,
            onAddProducts: () =>
                context.push(AppRoutes.waiterMenu(widget.tableId)),
            onRequestCheck: () => _requestCheck(order.id),
            onVoidItem: _voidItem,
          );
        },
      ),
    );
  }
}

class _OpenOrderView extends ConsumerWidget {
  const _OpenOrderView({
    required this.order,
    required this.busy,
    required this.onAddProducts,
    required this.onRequestCheck,
    required this.onVoidItem,
  });

  final OrderModel order;
  final bool busy;
  final VoidCallback onAddProducts;
  final VoidCallback onRequestCheck;
  final ValueChanged<OrderItemModel> onVoidItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(orderItemsStreamProvider(order.id));

    return Column(
      children: [
        Expanded(
          child: itemsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                const Center(child: Text('Sipariş yüklenemedi.')),
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    'Henüz ürün eklenmedi',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                );
              }
              final activeTotal = items
                  .where((i) => i.status != 'VOID')
                  .fold<double>(0, (sum, i) => sum + i.lineTotal);

              return Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return OrderItemRow(
                          item: item,
                          onVoid: item.status == 'NEW'
                              ? () => onVoidItem(item)
                              : null,
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Toplam',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          formatTry(activeTotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onAddProducts,
                    child: const Text('Ürün Ekle'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (busy || order.checkRequested)
                        ? null
                        : onRequestCheck,
                    child: Text(
                      order.checkRequested ? 'Hesap İstendi' : 'Hesap İste',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
