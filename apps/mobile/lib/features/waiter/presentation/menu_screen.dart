import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency.dart';
import '../application/cart_controller.dart';
import '../application/waiter_providers.dart';
import '../domain/models.dart';
import 'widgets/quantity_note_sheet.dart';

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key, required this.tableId});

  final String tableId;

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  bool _submitting = false;

  Future<void> _addToCart(ProductModel product) async {
    final result = await showQuantityNoteSheet(context, product: product);
    if (result == null) return;
    ref
        .read(cartControllerProvider.notifier)
        .add(product, quantity: result.quantity, note: result.note);
  }

  Future<void> _submitCart() async {
    final cart = ref.read(cartControllerProvider);
    if (cart.isEmpty) return;

    final order = await ref.read(openOrderProvider(widget.tableId).future);
    if (order == null) {
      _showError('Sipariş bulunamadı. Lütfen masayı yeniden açın.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref
          .read(waiterRepositoryProvider)
          .submitCart(orderId: order.id, items: cart);
      ref.read(cartControllerProvider.notifier).clear();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      _showError('Sipariş mutfağa gönderilemedi. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _cartButtonLabel(List<CartItem> cart) {
    final itemCount = cart.fold<int>(0, (sum, item) => sum + item.quantity);
    final total = cart.fold<double>(0, (sum, item) => sum + item.lineTotal);
    return '$itemCount ürün · ${formatTry(total)} · Mutfağa Gönder';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final productsAsync = ref.watch(productsProvider);
    final cart = ref.watch(cartControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ürün Ekle')),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            const Center(child: Text('Kategoriler yüklenemedi.')),
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(child: Text('Henüz kategori eklenmemiş.'));
          }
          return DefaultTabController(
            length: categories.length,
            child: Column(
              children: [
                TabBar(
                  isScrollable: true,
                  tabs: [for (final c in categories) Tab(text: c.name)],
                ),
                const Divider(height: 1),
                Expanded(
                  child: productsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) =>
                        const Center(child: Text('Ürünler yüklenemedi.')),
                    data: (products) {
                      return TabBarView(
                        children: [
                          for (final category in categories)
                            _ProductList(
                              products: products
                                  .where((p) => p.categoryId == category.id)
                                  .toList(),
                              onTap: _addToCart,
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submitCart,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(_cartButtonLabel(cart)),
                ),
              ),
            ),
    );
  }
}

class _ProductList extends StatelessWidget {
  const _ProductList({required this.products, required this.onTap});

  final List<ProductModel> products;
  final ValueChanged<ProductModel> onTap;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Center(
        child: Text(
          'Bu kategoride ürün yok',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final product = products[index];
        return Card(
          child: ListTile(
            title: Text(product.name),
            trailing: Text(
              formatTry(product.price),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onTap: () => onTap(product),
          ),
        );
      },
    );
  }
}
