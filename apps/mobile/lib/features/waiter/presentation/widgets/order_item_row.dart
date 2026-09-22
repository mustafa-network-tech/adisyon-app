import 'package:flutter/material.dart';

import '../../../../core/utils/currency.dart';
import '../../domain/models.dart';

const Map<String, String> orderItemStatusLabels = {
  'NEW': 'Yeni',
  'PREPARING': 'Hazırlanıyor',
  'READY': 'Hazır',
  'SERVED': 'Servis Edildi',
  'VOID': 'İptal',
};

const Map<String, Color> orderItemStatusColors = {
  'NEW': Color(0xFF2563EB), // blue-600
  'PREPARING': Color(0xFFD97706), // amber-600
  'READY': Color(0xFF16A34A), // green-600
  'SERVED': Color(0xFF52525B), // zinc-600
  'VOID': Color(0xFFDC2626), // red-600
};

class OrderItemRow extends StatelessWidget {
  const OrderItemRow({super.key, required this.item, this.onVoid});

  final OrderItemModel item;
  final VoidCallback? onVoid;

  @override
  Widget build(BuildContext context) {
    final voided = item.status == 'VOID';
    final color = orderItemStatusColors[item.status] ?? Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${item.quantity}x ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Expanded(
                      child: Text(
                        item.productName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          decoration: voided
                              ? TextDecoration.lineThrough
                              : null,
                          color: voided ? Colors.grey : null,
                        ),
                      ),
                    ),
                  ],
                ),
                if (item.note != null && item.note!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, left: 20),
                    child: Text(
                      item.note!,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      orderItemStatusLabels[item.status] ?? item.status,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatTry(item.lineTotal),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  decoration: voided ? TextDecoration.lineThrough : null,
                  color: voided ? Colors.grey : null,
                ),
              ),
              if (onVoid != null && item.status == 'NEW')
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'İptal Et',
                  onPressed: onVoid,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
