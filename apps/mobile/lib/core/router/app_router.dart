import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/home/presentation/role_placeholder_screens.dart';
import '../../features/kitchen/presentation/kitchen_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/waiter/presentation/menu_screen.dart';
import '../../features/waiter/presentation/table_screen.dart';
import '../../features/waiter/presentation/waiter_home_screen.dart';
import 'app_routes.dart';
import 'go_router_refresh_stream.dart';

/// Auth-gate only: signed out -> /giris, signed in -> splash (which
/// resolves role and navigates onward). Role-based destinations are
/// reachable directly too (so e.g. a deep link works once signed in),
/// but nothing here trusts a role without re-checking auth state first.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: GoRouterRefreshStream(authRepository.onAuthStateChange),
    redirect: (context, state) {
      final signedIn = authRepository.currentSession != null;
      final onLoginPage = state.matchedLocation == AppRoutes.login;

      if (!signedIn) {
        return onLoginPage ? null : AppRoutes.login;
      }
      if (onLoginPage) return AppRoutes.splash;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.noAccess,
        builder: (context, state) => const NoAccessScreen(),
      ),
      GoRoute(
        path: AppRoutes.platformAdminInfo,
        builder: (context, state) => const PlatformAdminInfoScreen(),
      ),
      GoRoute(
        path: AppRoutes.waiterHome,
        builder: (context, state) => const WaiterHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.waiterTablePattern,
        builder: (context, state) =>
            TableScreen(tableId: state.pathParameters['tableId']!),
      ),
      GoRoute(
        path: AppRoutes.waiterMenuPattern,
        builder: (context, state) =>
            MenuScreen(tableId: state.pathParameters['tableId']!),
      ),
      GoRoute(
        path: AppRoutes.kitchenHome,
        builder: (context, state) => const KitchenScreen(),
      ),
      GoRoute(
        path: AppRoutes.cashierHome,
        builder: (context, state) => const CashierHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.businessAdminHome,
        builder: (context, state) => const BusinessAdminHomeScreen(),
      ),
    ],
  );
});
