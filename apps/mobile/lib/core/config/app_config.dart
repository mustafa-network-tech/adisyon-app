/// Supabase project credentials, provided at build/run time via
/// `--dart-define` (see README.md) -- never hard-coded, never the
/// service role key (that must never exist in a mobile build at all).
class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
