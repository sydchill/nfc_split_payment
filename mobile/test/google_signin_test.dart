import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:split_nfc_payment/api_client.dart';
import 'package:split_nfc_payment/google_signin_service.dart';
import 'package:split_nfc_payment/shell.dart';
import 'package:split_nfc_payment/state.dart';

/// Stands in for the real Google SDK so the whole frontend flow can be driven
/// without Google Play Services.
class FakeGoogleAuth implements GoogleAuthService {
  FakeGoogleAuth(this.result, {this.configured = true});

  final GoogleSignInResult result;
  final bool configured;
  int signInCalls = 0;
  int signOutCalls = 0;

  @override
  bool get isConfigured => configured;

  @override
  Future<GoogleSignInResult> signIn() async {
    signInCalls++;
    return result;
  }

  @override
  Future<void> signOut() async => signOutCalls++;
}

Future<void> _loadFonts() async {
  final loader = FontLoader('Poppins');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final bytes = File('assets/fonts/Poppins-$w.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

/// Backend stub: records the /api/auth/google request and returns a session.
class FakeBackend {
  final List<Map<String, dynamic>> googleRequests = [];

  http.Client get client => MockClient((req) async {
        if (req.url.path == '/api/auth/google') {
          googleRequests.add(jsonDecode(req.body) as Map<String, dynamic>);
          return http.Response(
            jsonEncode({
              'access_token': 'access-123',
              'refresh_token': 'refresh-123',
              'user': {
                'id': 'u1',
                'email': 'gmail.user@gmail.com',
                'mode': 'personal',
                'display_name': 'Gmail User',
                'has_password': false,
                'google_linked': true,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        // Everything else the home screen loads on sign-in.
        if (req.url.path == '/api/sales/today') {
          return http.Response('{"count":0,"total":0,"average":0}', 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('[]', 200, headers: {'content-type': 'application/json'});
      });
}

Future<AppState> _pump(
  WidgetTester tester, {
  required GoogleAuthService google,
  required FakeBackend backend,
}) async {
  final app = AppState(
    api: ApiClient(httpClient: backend.client, baseUrl: 'http://test.local'),
    google: google,
  );
  addTearDown(app.dispose);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'Poppins'),
      home: AppScope(notifier: app, child: const PatelaShell()),
    ),
  );
  await tester.pump();
  return app;
}

/// Advances a bounded number of frames.
///
/// The home and onboarding screens run endless animations (ripples, float), so
/// `pumpAndSettle` never returns once the app lands there.
Future<void> _pumpAnimated(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(_loadFonts);

  // ApiClient persists its tokens after every sign-in; without an in-memory
  // store that await never completes in a widget test, so the app would never
  // reach the home screen.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> toSignup(WidgetTester tester) async {
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personal'));
    await tester.pumpAndSettle();
  }

  testWidgets('Google button signs in and lands on home', (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final google = FakeGoogleAuth(const GoogleSignInResult.token('fake-id-token'));
    final backend = FakeBackend();
    final app = await _pump(tester, google: google, backend: backend);

    await toSignup(tester);
    await tester.tap(find.text('Sign up with Google'));
    await _pumpAnimated(tester);

    // The service was invoked, and the token went to the backend with the mode.
    expect(google.signInCalls, 1);
    expect(backend.googleRequests, hasLength(1));
    expect(backend.googleRequests.first['id_token'], 'fake-id-token');
    expect(backend.googleRequests.first['mode'], 'personal');

    // Signed in: account applied and routed to the personal home.
    expect(app.authError, isNull);
    expect(app.screen, AppScreen.home);
    expect(app.displayName, 'Gmail User');
    expect(find.text('Gmail User'), findsOneWidget);
    expect(find.text('Split a bill'), findsOneWidget);
  });

  testWidgets('user cancelling shows no error', (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final google = FakeGoogleAuth(const GoogleSignInResult.userCancelled());
    final backend = FakeBackend();
    final app = await _pump(tester, google: google, backend: backend);

    await toSignup(tester);
    await tester.tap(find.text('Sign up with Google'));
    await tester.pumpAndSettle();

    expect(google.signInCalls, 1);
    expect(backend.googleRequests, isEmpty); // never hit the backend
    expect(app.authError, isNull); // cancelling is not an error
    expect(app.authLoading, isFalse); // spinner cleared
    expect(find.text('Create your personal account'), findsOneWidget);
  });

  testWidgets('Google SDK failure surfaces its message', (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final google =
        FakeGoogleAuth(const GoogleSignInResult.failed('Play Services missing.'));
    final backend = FakeBackend();
    final app = await _pump(tester, google: google, backend: backend);

    await toSignup(tester);
    await tester.tap(find.text('Sign up with Google'));
    await tester.pumpAndSettle();

    expect(backend.googleRequests, isEmpty);
    expect(app.authError, 'Play Services missing.');
    expect(find.text('Play Services missing.'), findsOneWidget);
  });

  testWidgets('unconfigured Google shows setup hint', (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final google = FakeGoogleAuth(
      const GoogleSignInResult.token('unused'),
      configured: false,
    );
    final backend = FakeBackend();
    final app = await _pump(tester, google: google, backend: backend);

    await toSignup(tester);
    await tester.tap(find.text('Sign up with Google'));
    await tester.pumpAndSettle();

    expect(google.signInCalls, 0); // guarded before calling the SDK
    expect(app.authError, contains('GOOGLE_SERVER_CLIENT_ID'));
  });

  testWidgets('business mode is sent for a business signup', (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final google = FakeGoogleAuth(const GoogleSignInResult.token('tok'));
    final backend = FakeBackend();
    await _pump(tester, google: google, backend: backend);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Business'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign up with Google'));
    await _pumpAnimated(tester);

    expect(backend.googleRequests.first['mode'], 'business');
  });

  testWidgets('logout also clears the Google account', (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final google = FakeGoogleAuth(const GoogleSignInResult.token('tok'));
    final backend = FakeBackend();
    final app = await _pump(tester, google: google, backend: backend);

    await toSignup(tester);
    await tester.tap(find.text('Sign up with Google'));
    await _pumpAnimated(tester);
    expect(app.screen, AppScreen.home);

    await app.logout();
    await _pumpAnimated(tester);

    expect(google.signOutCalls, 1);
    expect(app.account, isNull);
    expect(app.screen, AppScreen.onboard1);
  });
}
