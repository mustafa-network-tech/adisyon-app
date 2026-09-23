/// Supabase project credentials, provided at build/run time via
/// `--dart-define` (see README.md) -- never hard-coded, never the
/// service role key (that must never exist in a mobile build at all).
class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// Base URL of the web app (e.g. https://adisyon.example.com). The
  /// Android app posts Google Play purchase tokens to
  /// `$webBaseUrl/api/play/verify`. Empty = subscription purchases are
  /// shown as unavailable (fail-safe), nothing else is affected.
  static const String webBaseUrl = String.fromEnvironment('WEB_BASE_URL');

  /// Must match applicationId in android/app/build.gradle.kts; used for
  /// the Google Play "manage subscription" link.
  static const String androidPackageName = 'com.mkdigitalsystems.adisyon';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
