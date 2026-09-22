import 'package:flutter/material.dart';

import '../../domain/models.dart';

const Map<String, String> _statusLabels = {
  'NEW': 'Yeni',
  'PREPARING': 'Hazırlanıyor',
  'READY': 'Hazır',
};

const Map<String, Color> _statusColors = {
  'NEW': Color(0xFF2563EB), // blue-600
  'PREPARING': Color(0xFFD97706), // amber-600
  'READY': Color(0xFF16A34A), // green-600
};

const Map<String, String> _nextActionLabels = {
  'NEW': 'Hazırlanıyor',
  'PREPARING': 'Hazır',
  'READY': 'Servis Edildi',
};

class TicketCard extends StatelessWidget {
  const TicketCard({super.key, required this.ticket, required this.onAdvance});

  final KitchenTicket ticket;
  final void Function(KitchenItem item, String nextStatus) onAdvance;

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(ticket.openedAt);
    final urgent = elapsed.inMinutes >= 15;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: urgent ? const Color(0xFFDC2626) : const Color(0xFFE4E4E7),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  ticket.tableName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${elapsed.inMinutes} dk',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: urgent
                        ? const Color(0xFFDC2626)
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            for (final item in ticket.items)
              _ItemRow(item: item, onAdvance: onAdvance),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.onAdvance});

  final KitchenItem item;
  final void Function(KitchenItem item, String nextStatus) onAdvance;

  @override
  Widget build(BuildContext context) {
    final color = _statusColors[item.status] ?? Colors.grey;
    final nextStatus = nextKitchenStatus(item.status);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.quantity}x ${item.productName}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.note != null && item.note!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.note!,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _statusLabels[item.status] ?? item.status,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (nextStatus != null)
                FilledButton(
                  onPressed: () => onAdvance(item, nextStatus),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  child: Text(_nextActionLabels[item.status] ?? nextStatus),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
