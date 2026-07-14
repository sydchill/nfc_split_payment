/// Supabase project connection details.
///
/// Paste your project's values below (Supabase dashboard → Project Settings →
/// API). Use the anon / public key — newer dashboards label it the
/// "publishable" key (may start with `sb_publishable_`); either form works. It
/// is safe to ship in a client app: on its own it can only do what your Row
/// Level Security policies allow. NEVER put the `service_role` (secret) key
/// here; that key bypasses RLS and must stay server-side.
///
/// You can also override these at run time without editing the file:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class SupabaseConfig {
  SupabaseConfig._();

  static const String url =
      String.fromEnvironment('SUPABASE_URL', defaultValue: _urlLiteral);
  static const String anonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: _anonKeyLiteral);

  // 👇 Paste your values between the quotes.
  static const String _urlLiteral = 'https://nuzfkevvykxsrcpgsuuo.supabase.co';
  static const String _anonKeyLiteral = 'sb_publishable_xKAxCQ3FUDNhGqV_rjEXCw_W6YzfmQR';

  /// Deep link the Google OAuth flow returns to. Must be listed under
  /// Supabase → Authentication → URL Configuration → Redirect URLs, and match
  /// the intent-filter in android/app/src/main/AndroidManifest.xml.
  static const String oauthRedirect = 'io.supabase.tandem://login-callback';

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
