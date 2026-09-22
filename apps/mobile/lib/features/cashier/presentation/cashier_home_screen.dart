import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/utils/currency.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/application/role_context.dart';
import '../application/cashier_providers.dart';

class CashierHomeScreen extends ConsumerWidget {
  const CashierHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessName =
        ref.watch(roleContextProvider).value?.businessName ?? 'MK Adisyon';
    final ticketsAsync = ref.watch(cashierTicketsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('$businessName · Kasa'),
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
          child: Text(
            'Açık masalar yüklenemedi.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
        data: (tickets) {
          if (tickets.isEmpty) {
            return Center(
              child: Text(
                'Açık masa yok',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 140,
            ),
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: ticket.checkRequested
                        ? const Color(0xFFDC2626)
                        : const Color(0xFFE4E4E7),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () =>
                      context.push(AppRoutes.cashierOrder(ticket.orderId)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ticket.tableName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (ticket.checkRequested)
                          const Text(
                            'Hesap İstendi',
                            style: TextStyle(
                              color: Color(0xFFDC2626),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        Text(
                          formatTry(ticket.total),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
