/// Konfigurasi dari `--dart-define-from-file=env.json`.
/// Pakai publishable key (atau anon key lama). Jangan pernah `service_role`/secret key.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get isConfigured =>
      supabaseUrl.startsWith('https://') && supabasePublishableKey.isNotEmpty;
}
