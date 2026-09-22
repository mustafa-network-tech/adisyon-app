import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_providers.dart';

/// A full-screen "here's your status" message with an optional sign-out
/// button. Used for the no-access state, the platform-admin-on-mobile
/// notice, and each role's not-yet-built placeholder home -- never a raw
/// error code or stack trace, always a plain-language explanation
/// (section 26 of the architecture doc).
class InfoScreen extends ConsumerWidget {
  const InfoScreen({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.showSignOut = true,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool showSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                ),
                if (showSignOut) ...[
                  const SizedBox(height: 28),
                  OutlinedButton(
                    onPressed: () => ref.read(authRepositoryProvider).signOut(),
                    child: const Text('Çıkış Yap'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
