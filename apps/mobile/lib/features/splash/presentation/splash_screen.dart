import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../auth/application/role_context.dart';

/// Reached only once the router already knows the user is signed in.
/// Resolves their role (platform admin / business role / none) and
/// hands off to the matching home screen. Kept deliberately dumb: all
/// the actual authorization logic lives in roleContextProvider, which
/// re-reads from Supabase every time rather than trusting anything
/// cached.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleAsync = ref.watch(roleContextProvider);

    return roleAsync.when(
      data: (roleContext) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          context.go(_locationFor(roleContext.role));
        });
        return const _SplashBody();
      },
      loading: () => const _SplashBody(),
      error: (error, _) =>
          _SplashError(onRetry: () => ref.invalidate(roleContextProvider)),
    );
  }

  String _locationFor(AppRole role) {
    return switch (role) {
      AppRole.platformAdmin => AppRoutes.platformAdminInfo,
      AppRole.businessAdmin => AppRoutes.businessAdminHome,
      AppRole.cashier => AppRoutes.cashierHome,
      AppRole.waiter => AppRoutes.waiterHome,
      AppRole.kitchen => AppRoutes.kitchenHome,
      AppRole.none => AppRoutes.noAccess,
    };
  }
}

class _SplashBody extends StatelessWidget {
  const _SplashBody();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _SplashError extends StatelessWidget {
  const _SplashError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Bağlantı kurulamadı',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'İnternet bağlantınızı kontrol edip tekrar deneyin.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: onRetry,
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
