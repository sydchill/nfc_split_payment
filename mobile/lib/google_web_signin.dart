import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'google_signin_service.dart';
import 'oauth_browser.dart';

/// Google sign-in through the system browser, for devices with no Google
/// account attached.
///
/// The native picker ([GoogleSignInService]) can only offer accounts already
/// added to the device. This flow opens Google's own sign-in page in a Chrome
/// Custom Tab instead, so any account works without adding it to the phone.
///
/// It is the standard OAuth 2.0 authorization-code flow with PKCE:
///
/// ```
/// browser → accounts.google.com  (user signs in)
///         ← redirect to <package>:/oauth2redirect?code=...
/// app     → oauth2.googleapis.com/token  { code, code_verifier }
///         ← { id_token }                 → same token the native flow returns
/// ```
///
/// PKCE is what makes this safe without a client secret: the app commits to a
/// random `code_verifier` up front, so a code intercepted by another app on the
/// device cannot be redeemed.
///
/// The resulting ID token's audience is the **Android** client id, not the web
/// one, so that id must also be listed in the backend's `GOOGLE_CLIENT_ID`.
class GoogleWebSignInService implements GoogleAuthService {
  GoogleWebSignInService({http.Client? httpClient, OAuthBrowser? browser})
      : _http = httpClient ?? http.Client(),
        _browser = browser ?? OAuthBrowser();

  final http.Client _http;
  final OAuthBrowser _browser;

  static const _authEndpoint = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const _tokenEndpoint = 'https://oauth2.googleapis.com/token';

  /// Google requires an Android client's redirect to use the package name as
  /// its scheme.
  static const _redirectScheme = 'com.example.split_nfc_payment';
  static const _redirectUri = '$_redirectScheme:/oauth2redirect';

  @override
  bool get isConfigured => ApiConfig.googleAndroidClientId.isNotEmpty;

  @override
  Future<GoogleSignInResult> signIn() async {
    if (!isConfigured) {
      return const GoogleSignInResult.failed(
        'Browser sign-in is not configured — set GOOGLE_ANDROID_CLIENT_ID in '
        'env/dev.json.',
      );
    }

    final verifier = _randomVerifier();
    final challenge = _s256(verifier);
    final url = Uri.parse(_authEndpoint).replace(queryParameters: {
      'client_id': ApiConfig.googleAndroidClientId,
      'redirect_uri': _redirectUri,
      'response_type': 'code',
      'scope': 'openid email profile',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      // Always let the user choose, rather than silently reusing a session.
      'prompt': 'select_account',
    }).toString();

    final String redirect;
    try {
      redirect = await _browser.authenticate(url: url);
    } on OAuthCancelled {
      return const GoogleSignInResult.userCancelled();
    } catch (e) {
      debugPrint('Browser sign-in error: $e');
      return const GoogleSignInResult.failed(
        'Google sign-in failed. Please try again.',
      );
    }

    final params = queryOf(redirect);
    // The user can decline on Google's page; that is a cancel, not a failure.
    if (params['error'] == 'access_denied') {
      return const GoogleSignInResult.userCancelled();
    }
    if (params['error'] != null) {
      debugPrint('Google returned error=${params['error']}');
      return const GoogleSignInResult.failed(
        'Google refused the sign-in request. Check the Android OAuth client.',
      );
    }
    final code = params['code'];
    if (code == null || code.isEmpty) {
      return const GoogleSignInResult.failed(
        'Google did not return an authorization code.',
      );
    }

    return _exchange(code: code, verifier: verifier);
  }

  /// Trades the one-time code for tokens. No client secret: PKCE proves the
  /// redemption comes from the app that started the flow.
  Future<GoogleSignInResult> _exchange({
    required String code,
    required String verifier,
  }) async {
    try {
      final res = await _http.post(
        Uri.parse(_tokenEndpoint),
        body: {
          'client_id': ApiConfig.googleAndroidClientId,
          'code': code,
          'code_verifier': verifier,
          'redirect_uri': _redirectUri,
          'grant_type': 'authorization_code',
        },
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode != 200) {
        debugPrint('Token exchange failed (${res.statusCode}): ${res.body}');
        return const GoogleSignInResult.failed(
          'Google would not issue a token for this app. Check that the Android '
          'OAuth client id matches this build.',
        );
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final token = body['id_token'] as String?;
      if (token == null || token.isEmpty) {
        return const GoogleSignInResult.failed(
          'Google did not return an ID token.',
        );
      }
      return GoogleSignInResult.token(token);
    } catch (e) {
      debugPrint('Token exchange error: $e');
      return const GoogleSignInResult.failed(
        "Couldn't reach Google to finish signing in. Check your connection.",
      );
    }
  }

  /// Nothing is cached by this flow — `prompt=select_account` already forces a
  /// fresh choice on the next sign-in.
  @override
  Future<void> signOut() async {}

  /// Reads the query off the redirect without `Uri.parse`.
  ///
  /// The package name contains underscores, which RFC 3986 does not allow in a
  /// scheme — Android accepts it, but `Uri.parse` throws a FormatException on
  /// `com.example.split_nfc_payment:/…`. Only the query is needed here anyway.
  @visibleForTesting
  static Map<String, String> queryOf(String redirect) {
    final start = redirect.indexOf('?');
    if (start < 0) return const {};
    final query = redirect.substring(start + 1).split('#').first;
    return Uri.splitQueryString(query);
  }

  /// 43–128 unreserved characters, per RFC 7636.
  String _randomVerifier() {
    final rng = Random.secure();
    final bytes = List<int>.generate(64, (_) => rng.nextInt(256));
    return _b64url(bytes);
  }

  String _s256(String verifier) => _b64url(sha256.convert(utf8.encode(verifier)).bytes);

  String _b64url(List<int> bytes) =>
      base64UrlEncode(bytes).replaceAll('=', ''); // base64url without padding
}
