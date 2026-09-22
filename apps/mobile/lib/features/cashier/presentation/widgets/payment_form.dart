import 'package:flutter/material.dart';

class PaymentForm extends StatefulWidget {
  const PaymentForm({
    super.key,
    required this.remaining,
    required this.busy,
    required this.onSubmit,
  });

  final double remaining;
  final bool busy;
  final void Function(String method, double amount) onSubmit;

  @override
  State<PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<PaymentForm> {
  String _method = 'CASH';
  late final TextEditingController _amountController;

  static const _methods = [
    ('CASH', 'Nakit'),
    ('CARD', 'Kart'),
    ('OTHER', 'Diğer'),
  ];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.remaining.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) return;
    widget.onSubmit(_method, amount);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (final (value, label) in _methods)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: _method == value,
                        onSelected: (_) => setState(() => _method = value),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Tutar'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: widget.busy ? null : _submit,
              child: const Text('Ödeme Al'),
            ),
          ],
        ),
      ),
    );
  }
}
