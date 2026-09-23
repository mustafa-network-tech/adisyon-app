import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/widgets/info_screen.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/application/role_context.dart';

/// Faz 4 only wired up auth/session/role-routing -- each role's real
/// screen is built in its own later phase. The waiter's real home lives
/// in features/waiter (Faz 5), kitchen's in features/kitchen (Faz 6),
/// cashier's in features/cashier (Faz 7). BUSINESS_ADMIN's mobile view
/// only offers the subscription screen -- section 10 of the architecture
/// doc scopes their mobile role to "basic tracking", and full management
/// is already covered by the web panel.

class BusinessAdminHomeScreen extends ConsumerWidget {
  const BusinessAdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessName =
        ref.watch(roleContextProvider).value?.businessName ?? 'MK Adisyon';

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              leading: const Icon(Icons.workspace_premium_outlined),
              title: const Text('Abonelik ve Planlar'),
              subtitle: const Text('Planınız, kullanımınız ve deneme süreniz'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.businessAdminSubscription),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.storefront_outlined, color: Colors.grey.shade500),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Masa, ürün ve personel yönetimi web panelinden '
                      'yapılır. Mobil takip ekranı ileride eklenecek.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NoAccessScreen extends StatelessWidget {
  const NoAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoScreen(
      icon: Icons.person_off_outlined,
      title: 'Erişim Yok',
      message:
          'Hesabınız henüz bir işletmeye tanımlanmamış. Lütfen işletme yöneticinizle iletişime geçin.',
    );
  }
}
