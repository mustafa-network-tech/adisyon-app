import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges a Stream (Supabase's auth state changes) to a Listenable, so
/// GoRouter re-evaluates its `redirect` callback whenever auth state
/// changes -- otherwise a sign-in/sign-out wouldn't trigger navigation
/// until some unrelated rebuild happened to occur.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
