import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'api_config.dart';

/// Result of a native Google sign-in attempt.
///
/// Exactly one of [idToken] / [error] is set; [cancelled] means the user backed
/// out and no message should be shown.
class GoogleSignInResult {
  const GoogleSignInResult._({this.idToken, this.error, this.cancelled = false});

  const GoogleSignInResult.token(String token) : this._(idToken: token);
  const GoogleSignInResult.failed(String message) : this._(error: message);
  const GoogleSignInResult.userCancelled() : this._(cancelled: true);

  final String? idToken;
  final String? error;
  final bool cancelled;

  bool get ok => idToken != null;
}

/// What [AppState] needs from Google sign-in. Kept abstract so tests can drive
/// the flow without Google Play Services.
abstract class GoogleAuthService {
  bool get isConfigured;
  Future<GoogleSignInResult> signIn();
  Future<void> signOut();
}

/// Wraps `google_sign_in` (v7) so the rest of the app only deals with an ID
/// token, which the Flask backend verifies.
class GoogleSignInService implements GoogleAuthService {
  GoogleSignInService({GoogleSignIn? signIn, this.fallback})
      : _signIn = signIn ?? GoogleSignIn.instance;

  final GoogleSignIn _signIn;

  /// Used when the device has no Google account for the picker to offer —
  /// normally the browser flow, which accepts any account.
  final GoogleAuthService? fallback;

  bool _initialized = false;

  @override
  bool get isConfigured =>
      ApiConfig.googleServerClientId.isNotEmpty ||
      (fallback?.isConfigured ?? false);

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _signIn.initialize(
      // The backend verifies the ID token against this same (web) client id.
      serverClientId: ApiConfig.googleServerClientId,
    );
    _initialized = true;
  }

  /// Runs the native account picker and returns Google's ID token.
  @override
  Future<GoogleSignInResult> signIn() async {
    final alt = fallback;
    if (ApiConfig.googleServerClientId.isEmpty) {
      // No native config; the browser flow can still carry the whole sign-in.
      if (alt != null && alt.isConfigured) return alt.signIn();
      return const GoogleSignInResult.failed(
        'Google sign-in is not configured — set GOOGLE_SERVER_CLIENT_ID in '
        'env/dev.json.',
      );
    }
    try {
      await _ensureInitialized();
      if (!_signIn.supportsAuthenticate()) {
        return const GoogleSignInResult.failed(
          'Google sign-in is not supported on this platform yet.',
        );
      }
      final account = await _signIn.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        return const GoogleSignInResult.failed(
          'Google did not return an ID token. Check that the server client id '
          'is the Web client id from Google Cloud.',
        );
      }
      return GoogleSignInResult.token(token);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        // Play Services also reports a *configuration* failure as a cancel (an
        // unregistered Android OAuth client shows up as
        // `status=UNREGISTERED_ON_API_CONSOLE` in logcat, tag
        // `Auth.Api.Credentials`), so log it rather than fail silently.
        debugPrint(
          'Google sign-in cancelled (${e.description ?? "no reason given"}). '
          'If the picker was not dismissed by hand, check logcat for tag '
          'Auth.Api.Credentials.',
        );
        return const GoogleSignInResult.userCancelled();
      }
      debugPrint('GoogleSignInException(${e.code}): ${e.description}');
      // No account on the device: hand over to the browser, which accepts any
      // Google account without adding it to the phone.
      if (isNoDeviceAccountError(e) && alt != null && alt.isConfigured) {
        debugPrint('No device account — falling back to browser sign-in.');
        return alt.signIn();
      }
      return GoogleSignInResult.failed(_messageFor(e));
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      return const GoogleSignInResult.failed(
        'Google sign-in failed. Please try again.',
      );
    }
  }

  /// True when Play Services had no account to offer.
  ///
  /// The plugin reports this as an `unknownError` whose description it prefixes
  /// with "No credential available", which is the only signal available here.
  @visibleForTesting
  static bool isNoDeviceAccountError(GoogleSignInException e) =>
      (e.description ?? '').contains('No credential available');

  /// Turns a plugin failure into something a person can act on.
  ///
  /// The raw descriptions are written for developers ("No credential
  /// available: ..."), so the common, recoverable cases get their own copy.
  String _messageFor(GoogleSignInException e) {
    final description = e.description ?? '';
    if (description.contains('No credential available')) {
      return 'No Google account on this device. Add one in Settings → '
          'Passwords & accounts, then try again.';
    }
    switch (e.code) {
      case GoogleSignInExceptionCode.providerConfigurationError:
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'Google sign-in is misconfigured for this build. Check that the '
            'app id and signing certificate match an Android OAuth client.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google sign-in could not open. Please try again.';
      case GoogleSignInExceptionCode.interrupted:
        return 'Google sign-in was interrupted. Please try again.';
      default:
        return description.isEmpty
            ? 'Google sign-in failed. Please try again.'
            : description;
    }
  }

  /// Clears the cached Google account so the next sign-in shows the picker.
  ///
  /// Initializes first: after a restored session the app logs out without ever
  /// having called [signIn], and skipping this would leave Google's cached
  /// account behind.
  @override
  Future<void> signOut() async {
    await fallback?.signOut();
    if (ApiConfig.googleServerClientId.isEmpty) return;
    try {
      await _ensureInitialized();
      await _signIn.signOut();
    } catch (_) {
      // Non-fatal: the Patela session is cleared regardless.
    }
  }
}
