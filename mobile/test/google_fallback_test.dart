import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:split_nfc_payment/google_signin_service.dart';

/// Stands in for the browser flow.
class FakeBrowserAuth implements GoogleAuthService {
  FakeBrowserAuth({this.configured = true});

  final bool configured;
  int signInCalls = 0;
  int signOutCalls = 0;

  @override
  bool get isConfigured => configured;

  @override
  Future<GoogleSignInResult> signIn() async {
    signInCalls++;
    return const GoogleSignInResult.token('browser-id-token');
  }

  @override
  Future<void> signOut() async => signOutCalls++;
}

void main() {
  // The trigger for handing over to the browser. Play Services gives no error
  // code for "device has no account" — only this description prefix — so pin it
  // down: if the plugin ever rewords it, this test fails instead of the
  // fallback silently never running.
  test('a missing device account is recognised, other failures are not', () {
    expect(
      GoogleSignInService.isNoDeviceAccountError(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.unknownError,
          description: 'No credential available: No credentials available',
        ),
      ),
      isTrue,
    );
    expect(
      GoogleSignInService.isNoDeviceAccountError(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.providerConfigurationError,
          description: 'Something else went wrong',
        ),
      ),
      isFalse,
    );
  });

  // The dart-defines are empty under `flutter test`, so the native path is
  // treated as unconfigured and the fallback carries the sign-in. That is the
  // same branch a device with no GOOGLE_SERVER_CLIENT_ID would take.
  test('browser fallback carries sign-in when native is unconfigured', () async {
    final browser = FakeBrowserAuth();
    final service = GoogleSignInService(fallback: browser);

    final result = await service.signIn();

    expect(browser.signInCalls, 1);
    expect(result.ok, isTrue);
    expect(result.idToken, 'browser-id-token');
  });

  test('without a configured fallback the setup hint is returned', () async {
    final browser = FakeBrowserAuth(configured: false);
    final service = GoogleSignInService(fallback: browser);

    final result = await service.signIn();

    expect(browser.signInCalls, 0);
    expect(result.ok, isFalse);
    expect(result.error, contains('GOOGLE_SERVER_CLIENT_ID'));
  });

  test('isConfigured is true when only the fallback is available', () {
    expect(GoogleSignInService(fallback: FakeBrowserAuth()).isConfigured, isTrue);
    expect(
      GoogleSignInService(fallback: FakeBrowserAuth(configured: false)).isConfigured,
      isFalse,
    );
  });

  test('signing out also clears the fallback', () async {
    final browser = FakeBrowserAuth();
    await GoogleSignInService(fallback: browser).signOut();
    expect(browser.signOutCalls, 1);
  });
}
