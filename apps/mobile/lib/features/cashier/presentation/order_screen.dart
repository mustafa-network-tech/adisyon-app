import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/audit.dart';
import '../../../core/utils/currency.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/application/role_context.dart';
import '../application/cashier_providers.dart';
import '../domain/models.dart';
import 'widgets/payment_form.dart';

class OrderScreen extends ConsumerStatefulWidget {
  const OrderScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen> {
  bool _busy = false;

  Future<String?> _askReason() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İptal Nedeni'),
        content: TextField(controller: controller, autofocus: true),
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

  String? get _businessId => ref.read(roleContextProvider).value?.businessId;

  Future<void> _voidItem(String itemId) async {
    final reason = await _askReason();
    if (reason == null || reason.trim().isEmpty) return;
    try {
      await ref
          .read(cashierRepositoryProvider)
          .voidItem(itemId: itemId, reason: reason.trim());
      final businessId = _businessId;
      if (businessId != null) {
        await logAuditEvent(
          ref.read(supabaseClientProvider),
          businessId: businessId,
          action: 'ORDER_ITEM_VOIDED',
          entity: 'order_items',
          entityId: itemId,
          metadata: {'reason': reason.trim()},
        );
      }
    } catch (_) {
      _showError('Ürün iptal edilemedi.');
    }
  }

  Future<void> _voidPayment(String paymentId) async {
    final reason = await _askReason();
    if (reason == null || reason.trim().isEmpty) return;
    try {
      await ref
          .read(cashierRepositoryProvider)
          .voidPayment(paymentId: paymentId, reason: reason.trim());
      final businessId = _businessId;
      if (businessId != null) {
        await logAuditEvent(
          ref.read(supabaseClientProvider),
          businessId: businessId,
          action: 'PAYMENT_VOIDED',
          entity: 'payments',
          entityId: paymentId,
          metadata: {'reason': reason.trim()},
        );
      }
    } catch (_) {
      _showError('Ödeme iptal edilemedi.');
    }
  }

  Future<void> _addPayment(String method, double amount) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(cashierRepositoryProvider)
          .addPayment(orderId: widget.orderId, method: method, amount: amount);
    } catch (_) {
      _showError('Ödeme kaydedilemedi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _closeOrder() async {
    setState(() => _busy = true);
    try {
      await ref.read(cashierRepositoryProvider).closeOrder(widget.orderId);
      if (mounted) context.pop();
    } catch (_) {
      _showError('Hesap kapatılamadı. Tüm tutarın ödendiğinden emin olun.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Siparişi İptal Et'),
        content: const Text(
          'Bu siparişi tamamen iptal etmek istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(cashierRepositoryProvider).cancelOrder(widget.orderId);
      final businessId = _businessId;
      if (businessId != null) {
        await logAuditEvent(
          ref.read(supabaseClientProvider),
          businessId: businessId,
          action: 'ORDER_CANCELLED',
          entity: 'orders',
          entityId: widget.orderId,
        );
      }
      if (mounted) context.pop();
    } catch (_) {
      _showError('Sipariş iptal edilemedi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(orderStatusStreamProvider(widget.orderId));
    final itemsAsync = ref.watch(
      cashierOrderItemsStreamProvider(widget.orderId),
    );
    final paymentsAsync = ref.watch(
      cashierPaymentsStreamProvider(widget.orderId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Hesap')),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const Center(child: Text('Hesap yüklenemedi.')),
        data: (status) {
          if (status != 'OPEN') {
            return Center(
              child: Text(
                status == 'CLOSED'
                    ? 'Bu hesap kapatıldı'
                    : 'Bu sipariş iptal edildi',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            );
          }

          return itemsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                const Center(child: Text('Ürünler yüklenemedi.')),
            data: (items) {
              return paymentsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    const Center(child: Text('Ödemeler yüklenemedi.')),
                data: (payments) {
                  final activeTotal = items
                      .where((i) => i.status != 'VOID')
                      .fold<double>(0, (sum, i) => sum + i.lineTotal);
                  final paidTotal = payments
                      .where((p) => p.status == 'COMPLETED')
                      .fold<double>(0, (sum, p) => sum + p.amount);
                  final remaining = (activeTotal - paidTotal).clamp(
                    0,
                    double.infinity,
                  );
                  final hasAnyPayment = payments.any(
                    (p) => p.status == 'COMPLETED',
                  );

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final item in items)
                                _ItemLine(
                                  item: item,
                                  onVoid: () => _voidItem(item.id),
                                ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Toplam',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    formatTry(activeTotal),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Ödenen'),
                                  Text(formatTry(paidTotal)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Kalan',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    formatTry(remaining.toDouble()),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                      color: remaining > 0
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF16A34A),
                                    ),
                                  ),
                                ],
                              ),
                              if (payments.isNotEmpty) ...[
                                const Divider(height: 24),
                                for (final payment in payments)
                                  _PaymentLine(
                                    payment: payment,
                                    onVoid: payment.status == 'COMPLETED'
                                        ? () => _voidPayment(payment.id)
                                        : null,
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (remaining > 0) ...[
                        const SizedBox(height: 16),
                        PaymentForm(
                          remaining: remaining.toDouble(),
                          busy: _busy,
                          onSubmit: _addPayment,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: (_busy || remaining > 0)
                                  ? null
                                  : _closeOrder,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                              ),
                              child: const Text('Hesabı Kapat'),
                            ),
                          ),
                          if (!hasAnyPayment) ...[
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: _busy ? null : _cancelOrder,
                              // The theme's full-width minimumSize can't be
                              // laid out inside a Row (unbounded width) and
                              // blanked the whole screen.
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 52),
                              ),
                              child: const Text('İptal Et'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ItemLine extends StatelessWidget {
  const _ItemLine({required this.item, required this.onVoid});

  final CashierOrderItem item;
  final VoidCallback onVoid;

  @override
  Widget build(BuildContext context) {
    final voided = item.status == 'VOID';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${item.quantity}x ${item.productName}',
              style: TextStyle(
                decoration: voided ? TextDecoration.lineThrough : null,
                color: voided ? Colors.grey : null,
              ),
            ),
          ),
          Text(
            formatTry(item.lineTotal),
            style: TextStyle(
              decoration: voided ? TextDecoration.lineThrough : null,
              color: voided ? Colors.grey : null,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!voided)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: onVoid,
            ),
        ],
      ),
    );
  }
}

class _PaymentLine extends StatelessWidget {
  const _PaymentLine({required this.payment, this.onVoid});

  final CashierPayment payment;
  final VoidCallback? onVoid;

  static const _methodLabels = {
    'CASH': 'Nakit',
    'CARD': 'Kart',
    'OTHER': 'Diğer',
  };

  @override
  Widget build(BuildContext context) {
    final voided = payment.status == 'VOID';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_methodLabels[payment.method] ?? payment.method} · ${formatTry(payment.amount)}',
              style: TextStyle(
                decoration: voided ? TextDecoration.lineThrough : null,
                color: voided ? Colors.grey : null,
              ),
            ),
          ),
          if (onVoid != null)
            TextButton(onPressed: onVoid, child: const Text('İptal')),
        ],
      ),
    );
  }
}
