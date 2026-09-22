import 'package:flutter/material.dart';

import '../../../core/widgets/info_screen.dart';

/// Faz 4 only wired up auth/session/role-routing -- each role's real
/// screen is built in its own later phase. The waiter's real home now
/// lives in features/waiter/presentation/waiter_home_screen.dart (Faz 5);
/// kitchen (Faz 6) and cashier (Faz 7) are still placeholders below.

class KitchenHomeScreen extends StatelessWidget {
  const KitchenHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoScreen(
      icon: Icons.soup_kitchen_outlined,
      title: 'Mutfak',
      message: 'Canlı sipariş ekranı Faz 6\'da burada olacak.',
    );
  }
}

class CashierHomeScreen extends StatelessWidget {
  const CashierHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoScreen(
      icon: Icons.point_of_sale_outlined,
      title: 'Kasa',
      message: 'Ödeme ve hesap kapatma ekranı Faz 7\'de burada olacak.',
    );
  }
}

class BusinessAdminHomeScreen extends StatelessWidget {
  const BusinessAdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoScreen(
      icon: Icons.storefront_outlined,
      title: 'İşletme Yöneticisi',
      message:
          'Tam yönetim paneli web üzerinden kullanılabilir. Mobil takip ekranı ileride eklenecek.',
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

class PlatformAdminInfoScreen extends StatelessWidget {
  const PlatformAdminInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoScreen(
      icon: Icons.admin_panel_settings_outlined,
      title: 'Platform Yönetimi',
      message:
          'Bu hesap platform yönetimi içindir. Lütfen web panelini kullanın.',
    );
  }
}
