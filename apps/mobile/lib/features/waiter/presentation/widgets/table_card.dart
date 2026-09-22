import 'package:flutter/material.dart';

import '../../domain/models.dart';

const Map<String, String> tableStatusLabels = {
  'AVAILABLE': 'Boş',
  'OCCUPIED': 'Dolu',
  'CHECK_REQUESTED': 'Hesap İstendi',
};

const Map<String, Color> tableStatusColors = {
  'AVAILABLE': Color(0xFF16A34A), // green-600
  'OCCUPIED': Color(0xFFD97706), // amber-600
  'CHECK_REQUESTED': Color(0xFFDC2626), // red-600
};

class TableCard extends StatelessWidget {
  const TableCard({super.key, required this.table, required this.onTap});

  final TableModel table;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = tableStatusColors[table.status] ?? Colors.grey;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                table.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tableStatusLabels[table.status] ?? table.status,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
