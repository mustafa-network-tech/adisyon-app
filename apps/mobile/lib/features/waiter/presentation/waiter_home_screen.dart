import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/application/role_context.dart';
import '../application/waiter_providers.dart';
import 'widgets/table_card.dart';

class WaiterHomeScreen extends ConsumerWidget {
  const WaiterHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessName =
        ref.watch(roleContextProvider).value?.businessName ?? 'MK Adisyon';
    final areasAsync = ref.watch(areasProvider);
    final tablesAsync = ref.watch(tablesStreamProvider);
    final selectedAreaId = ref.watch(selectedAreaIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(businessName),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Çıkış Yap',
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: areasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            _ErrorState(onRetry: () => ref.invalidate(areasProvider)),
        data: (areas) {
          if (areas.isEmpty) {
            return const _EmptyState(
              message:
                  'İşletme yöneticiniz henüz bir alan eklemedi. Lütfen bekleyin.',
            );
          }

          final effectiveAreaId = selectedAreaId ?? areas.first.id;

          return Column(
            children: [
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: areas.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final area = areas[index];
                    final selected = area.id == effectiveAreaId;
                    return ChoiceChip(
                      label: Text(area.name),
                      selected: selected,
                      onSelected: (_) =>
                          ref.read(selectedAreaIdProvider.notifier).state =
                              area.id,
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: tablesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => _ErrorState(
                    onRetry: () => ref.invalidate(tablesStreamProvider),
                  ),
                  data: (tables) {
                    final areaTables = tables
                        .where((t) => t.areaId == effectiveAreaId)
                        .toList();

                    if (areaTables.isEmpty) {
                      return const _EmptyState(
                        message: 'Bu alanda henüz masa yok.',
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.5,
                          ),
                      itemCount: areaTables.length,
                      itemBuilder: (context, index) {
                        final table = areaTables[index];
                        return TableCard(
                          table: table,
                          onTap: () =>
                              context.push(AppRoutes.waiterTable(table.id)),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'Veriler yüklenemedi.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
        ],
      ),
    );
  }
}
