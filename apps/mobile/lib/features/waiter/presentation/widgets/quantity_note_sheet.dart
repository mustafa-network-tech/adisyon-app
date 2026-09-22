import 'package:flutter/material.dart';

import '../../domain/models.dart';

class QuantityNoteResult {
  const QuantityNoteResult({required this.quantity, this.note});

  final int quantity;
  final String? note;
}

Future<QuantityNoteResult?> showQuantityNoteSheet(
  BuildContext context, {
  required ProductModel product,
}) {
  return showModalBottomSheet<QuantityNoteResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _QuantityNoteSheet(product: product),
  );
}

class _QuantityNoteSheet extends StatefulWidget {
  const _QuantityNoteSheet({required this.product});

  final ProductModel product;

  @override
  State<_QuantityNoteSheet> createState() => _QuantityNoteSheetState();
}

class _QuantityNoteSheetState extends State<_QuantityNoteSheet> {
  int _quantity = 1;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.product.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '$_quantity',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => setState(() => _quantity++),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Not (opsiyonel)'),
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(
              QuantityNoteResult(
                quantity: _quantity,
                note: _noteController.text.trim().isEmpty
                    ? null
                    : _noteController.text.trim(),
              ),
            ),
            child: const Text('Sepete Ekle'),
          ),
        ],
      ),
    );
  }
}
