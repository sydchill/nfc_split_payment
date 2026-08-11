/// Backend connection details.
///
/// Patela talks to its own Flask API. Point this at wherever that API runs:
///
///   flutter run --dart-define-from-file=env/dev.json
///   flutter build apk --dart-define-from-file=env/prod.json
///
/// Android emulator note: `localhost` on the emulator is the emulator itself.
/// Use `10.0.2.2` to reach a server running on your development machine, or
/// your machine's LAN IP (e.g. 192.168.x.x) when testing on a physical phone.
class ApiConfig {
  ApiConfig._();

  /// 'dev' | 'qa' | 'prod' — informational; logged at startup.
  static const String environment =
      String.fromEnvironment('APP_ENV', defaultValue: 'dev');

  /// Base URL of the Flask API, without a trailing slash.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );

  /// Google Sign-In: the **Web** OAuth client id from Google Cloud Console.
  /// The mobile app requests an ID token for this audience and the Flask backend
  /// verifies it against the same value (its `GOOGLE_CLIENT_ID`). Empty disables
  /// the Google button.
  static const String googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID', defaultValue: '');

  static bool get isProd => environment == 'prod';

  static bool get isConfigured => baseUrl.isNotEmpty;

  static bool get googleEnabled => googleServerClientId.isNotEmpty;
}
