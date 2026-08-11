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

/// Wraps `google_sign_in` (v7) so the rest of the app only deals with an ID
/// token, which the Flask backend verifies.
class GoogleSignInService {
  GoogleSignInService({GoogleSignIn? signIn})
      : _signIn = signIn ?? GoogleSignIn.instance;

  final GoogleSignIn _signIn;
  bool _initialized = false;

  bool get isConfigured => ApiConfig.googleServerClientId.isNotEmpty;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _signIn.initialize(
      // The backend verifies the ID token against this same (web) client id.
      serverClientId: ApiConfig.googleServerClientId,
    );
    _initialized = true;
  }

  /// Runs the native account picker and returns Google's ID token.
  Future<GoogleSignInResult> signIn() async {
    if (!isConfigured) {
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
        return const GoogleSignInResult.userCancelled();
      }
      debugPrint('GoogleSignInException(${e.code}): ${e.description}');
      return GoogleSignInResult.failed(
        e.description ?? 'Google sign-in failed. Please try again.',
      );
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      return const GoogleSignInResult.failed(
        'Google sign-in failed. Please try again.',
      );
    }
  }

  /// Clears the cached Google account so the next sign-in shows the picker.
  Future<void> signOut() async {
    if (!_initialized) return;
    try {
      await _signIn.signOut();
    } catch (_) {
      // Non-fatal: the Patela session is cleared regardless.
    }
  }
}
