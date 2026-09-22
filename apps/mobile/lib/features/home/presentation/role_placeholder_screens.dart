import 'package:flutter/material.dart';

import '../../../core/widgets/info_screen.dart';

/// Faz 4 only wired up auth/session/role-routing -- each role's real
/// screen is built in its own later phase. The waiter's real home lives
/// in features/waiter (Faz 5), kitchen's in features/kitchen (Faz 6),
/// cashier's in features/cashier (Faz 7). BUSINESS_ADMIN's mobile view
/// stays a placeholder -- section 10 of the architecture doc scopes
/// their mobile role to "basic tracking", and full management is
/// already covered by the web panel.

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
