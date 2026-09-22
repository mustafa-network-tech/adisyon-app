import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around Supabase Auth. No business logic here -- role
/// resolution lives in role_context_provider.dart, and it always
/// re-derives from the database rather than trusting anything cached
/// client-side, the same principle the web app follows.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> updatePassword(String newPassword) {
    return _client.auth.updateUser(UserAttributes(password: newPassword));
  }
}
