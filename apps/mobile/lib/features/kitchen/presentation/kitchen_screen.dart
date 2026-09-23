import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../auth/application/role_context.dart';
import '../application/kitchen_providers.dart';
import 'widgets/ticket_card.dart';

class KitchenScreen extends ConsumerStatefulWidget {
  const KitchenScreen({super.key});

  @override
  ConsumerState<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends ConsumerState<KitchenScreen> {
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    // Only drives the "X dk" elapsed-time labels forward; ticket data
    // itself is realtime and needs no polling.
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _advance(String itemId, String nextStatus) async {
    try {
      await ref
          .read(kitchenRepositoryProvider)
          .advanceStatus(itemId: itemId, nextStatus: nextStatus);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Durum güncellenemedi. Lütfen tekrar deneyin.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessName =
        ref.watch(roleContextProvider).value?.businessName ?? 'MK Adisyon';
    final ticketsAsync = ref.watch(kitchenTicketsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('$businessName · Mutfak'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Çıkış Yap',
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: ticketsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 40,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                'Sipariş panosu yüklenemedi.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        data: (tickets) {
          if (tickets.isEmpty) {
            return Center(
              child: Text(
                'Bekleyen sipariş yok',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              ),
            );
          }

          // Cards size to their content (a ticket can have many items);
          // one column on phones, more on tablets/kitchen displays.
          return LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 16.0;
              const maxCardWidth = 360.0;
              final available = constraints.maxWidth - 2 * spacing;
              final columns = ((available + spacing) / (maxCardWidth + spacing))
                  .floor()
                  .clamp(1, 6);
              final cardWidth = (available - spacing * (columns - 1)) / columns;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(spacing),
                child: Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final ticket in tickets)
                      SizedBox(
                        width: cardWidth,
                        child: TicketCard(
                          ticket: ticket,
                          onAdvance: (item, nextStatus) =>
                              _advance(item.id, nextStatus),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
