import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/widgets/info_screen.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/application/role_context.dart';
import '../../subscription/application/subscription_providers.dart';
import '../../subscription/domain/models.dart';

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
    // Keeps the Google Play purchase listener alive for the admin so a
    // purchase whose verification was interrupted is re-verified.
    ref.watch(purchaseControllerProvider);
    final entitlement = ref.watch(entitlementProvider).value;

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
          if (entitlement != null) ...[
            _AccessBanner(entitlement: entitlement),
            const SizedBox(height: 12),
          ],
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

/// Server-computed access state (days left use the database clock).
/// Without an active trial or subscription the admin is pointed straight
/// to the subscription screen.
class _AccessBanner extends StatelessWidget {
  const _AccessBanner({required this.entitlement});

  final Entitlement entitlement;

  @override
  Widget build(BuildContext context) {
    final (
      String? text,
      Color background,
      Color foreground,
    ) = switch (entitlement.accessSource) {
      AccessSource.appTrial => (
        'Ücretsiz denemenizin ${entitlement.appTrialDaysLeft} günü kaldı. '
            'Tüm özellikler açık.',
        Colors.amber.shade50,
        Colors.amber.shade900,
      ),
      AccessSource.playTrial => (
        'Google Play ücretsiz döneminiz sürüyor. Tüm özellikler açık.',
        Colors.green.shade50,
        Colors.green.shade900,
      ),
      AccessSource.suspended => (
        'Hesabınız askıya alındı. Lütfen destek ile iletişime geçin.',
        Colors.red.shade50,
        Colors.red.shade900,
      ),
      _ when !entitlement.isOperational => (
        'Aktif bir deneme veya aboneliğiniz yok; yeni adisyon açılamaz. '
            'Devam etmek için bir plan seçin.',
        Colors.red.shade50,
        Colors.red.shade900,
      ),
      _ => (null, Colors.transparent, Colors.transparent),
    };
    if (text == null) return const SizedBox.shrink();

    final needsAction =
        !entitlement.isOperational &&
        entitlement.accessSource != AccessSource.suspended;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: TextStyle(color: foreground)),
          if (needsAction) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () =>
                  context.push(AppRoutes.businessAdminSubscription),
              child: const Text('Planları Gör'),
            ),
          ],
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
