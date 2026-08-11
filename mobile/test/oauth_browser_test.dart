import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:split_nfc_payment/google_web_signin.dart';
import 'package:split_nfc_payment/oauth_browser.dart';

void main() {
  group('redirect parsing', () {
    // `Uri.parse` throws FormatException on this redirect: the package name
    // contains underscores and RFC 3986 forbids them in a scheme. Android is
    // lenient, Dart is not — so the query is read without full URI parsing.
    const redirect = 'com.example.split_nfc_payment:/oauth2redirect';

    test('reads the code from a scheme Uri.parse rejects', () {
      expect(() => Uri.parse('$redirect?code=abc'), throwsFormatException);
      expect(
        GoogleWebSignInService.queryOf('$redirect?code=abc&scope=openid'),
        containsPair('code', 'abc'),
      );
    });

    test('reads an error and ignores a trailing fragment', () {
      expect(
        GoogleWebSignInService.queryOf('$redirect?error=access_denied#frag'),
        containsPair('error', 'access_denied'),
      );
    });

    test('a redirect with no query yields nothing rather than throwing', () {
      expect(GoogleWebSignInService.queryOf(redirect), isEmpty);
    });
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('patela/oauth');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Stands in for MainActivity.kt.
  void mockPlatform({
    String? heldRedirect,
    String? redirectAfterOpen,
    bool openThrows = false,
  }) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'open':
          if (openThrows) {
            throw PlatformException(code: 'no_browser', message: 'no browser');
          }
          if (redirectAfterOpen != null) {
            // The browser bounces straight back, as it does when Chrome still
            // has a live Google session.
            await messenger.handlePlatformMessage(
              channel.name,
              channel.codec
                  .encodeMethodCall(MethodCall('onRedirect', redirectAfterOpen)),
              (_) {},
            );
          }
          return true;
        case 'consumePendingRedirect':
          return heldRedirect;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }

  test('completes with the redirect the platform delivers', () async {
    mockPlatform(
      redirectAfterOpen: 'com.example.split_nfc_payment:/oauth2redirect?code=abc',
    );

    final result = await OAuthBrowser().authenticate(url: 'https://example.test');

    // Not Uri.parse: the package name has underscores, which are illegal in a
    // URI scheme, so parsing the whole redirect throws.
    expect(result, endsWith('?code=abc'));
  });

  test('picks up a redirect that landed before Dart was listening', () async {
    // The engine can still be starting when Google bounces back; MainActivity
    // holds the redirect until Dart asks for it.
    mockPlatform(
      heldRedirect: 'com.example.split_nfc_payment:/oauth2redirect?code=held',
    );

    final result = await OAuthBrowser().authenticate(url: 'https://example.test');

    expect(result, endsWith('?code=held'));
  });

  test('times out as a cancellation when nothing comes back', () async {
    mockPlatform();

    expect(
      () => OAuthBrowser().authenticate(
        url: 'https://example.test',
        timeout: const Duration(milliseconds: 50),
      ),
      throwsA(isA<OAuthCancelled>()),
    );
  });

  test('a browser that will not open surfaces the platform error', () async {
    mockPlatform(openThrows: true);

    expect(
      () => OAuthBrowser().authenticate(url: 'https://example.test'),
      throwsA(isA<PlatformException>()),
    );
  });
}
