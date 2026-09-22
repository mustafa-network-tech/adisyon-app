import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

/// Live auth state stream (SIGNED_IN / SIGNED_OUT / TOKEN_REFRESHED / ...).
/// Everything else (router redirects, role resolution) watches this
/// rather than reading `Supabase.instance.client.auth.currentUser`
/// directly, so the whole app reacts consistently to sign-in/out.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider).value;
  return authState?.session?.user ??
      ref.watch(supabaseClientProvider).auth.currentUser;
});
