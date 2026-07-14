import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:split_nfc_payment/shell.dart';
import 'package:split_nfc_payment/state.dart';

Future<void> _loadFonts() async {
  final loader = FontLoader('Poppins');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final bytes = File('assets/fonts/Poppins-$w.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

/// Pumps the shell with a test-owned [AppState] so screens can be driven
/// directly. Supabase is unconfigured in tests, so real auth calls short-circuit
/// with the "not configured" message; post-login flows are reached by seeding
/// [AppState] rather than round-tripping through a backend.
Future<AppState> _pumpApp(WidgetTester tester) async {
  final app = AppState();
  addTearDown(app.dispose);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'Poppins'),
      home: AppScope(notifier: app, child: const TandemShell()),
    ),
  );
  await tester.pump();
  return app;
}

/// Completes the shell's screen-switch transition. Safe only when the target
/// screen has no perpetual animation (spinner / ripple) — those would spin
/// forever and hang pumpAndSettle.
Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle();

/// Advances past a screen switch into a screen that DOES animate forever
/// (e.g. the tap-to-pay ripples): starts the transition, then finishes it.
Future<void> _navToAnimated(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _golden(WidgetTester tester, String name) async {
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
}

void _sizePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(780, 1688);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('onboarding + account-type + personal signup form', (tester) async {
    _sizePhone(tester);
    await _pumpApp(tester);

    expect(find.text('Tandem'), findsOneWidget);
    expect(find.text('Tap. Split. Settle.'), findsOneWidget);
    await _golden(tester, '01-welcome');

    await tester.tap(find.text('Get started'));
    await _settle(tester);
    expect(find.text('How will you use Tandem?'), findsOneWidget);
    await _golden(tester, '02-choose-type');

    await tester.tap(find.text('Personal'));
    await _settle(tester);
    expect(find.text('Create your personal account'), findsOneWidget);
    expect(find.text('Business name'), findsNothing);
    expect(find.byType(TextField), findsNWidgets(3)); // name, email, password
    await _golden(tester, '03-signup-personal');
  });

  testWidgets('auth: unconfigured backend shows a helpful error', (tester) async {
    _sizePhone(tester);
    final app = await _pumpApp(tester);

    await tester.tap(find.text('Get started'));
    await _settle(tester);
    await tester.tap(find.text('Personal'));
    await _settle(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Alex Rivera');
    await tester.enterText(fields.at(1), 'alex@example.com');
    await tester.enterText(fields.at(2), 'hunter2pass');
    await tester.tap(find.text('Create account'));
    await _settle(tester);

    expect(app.authError, contains('Supabase'));
    expect(find.textContaining('Supabase'), findsOneWidget);
    expect(find.text('Create your personal account'), findsOneWidget);
  });

  testWidgets('business signup shows extra fields', (tester) async {
    _sizePhone(tester);
    await _pumpApp(tester);

    await tester.tap(find.text('Get started'));
    await _settle(tester);
    await tester.tap(find.text('Business'));
    await _settle(tester);
    expect(find.text('Create your business account'), findsOneWidget);
    expect(find.text('Business name'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Owner name'), findsOneWidget);
    await _golden(tester, '18-signup-business');
  });

  testWidgets('sign-in screen renders with mode toggle', (tester) async {
    _sizePhone(tester);
    final app = await _pumpApp(tester);
    app.go(AppScreen.signin);
    await _settle(tester);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Business'), findsOneWidget);
    await _golden(tester, '13-signin');
  });

  testWidgets('personal split flow — collect from all friends', (tester) async {
    _sizePhone(tester);
    final app = await _pumpApp(tester);

    app.go(AppScreen.home);
    await _settle(tester);
    expect(find.text('Split a bill'), findsOneWidget);
    expect(find.text('Maya Chen'), findsOneWidget);
    await _golden(tester, '04-home-personal');

    // ---- split: amounts ----
    await tester.tap(find.text('Split a bill'));
    await _settle(tester);
    expect(find.text('\$128.40'), findsOneWidget);
    await tester.tap(find.text('+').first);
    await tester.pump();
    expect(find.text('\$33.10'), findsOneWidget);
    expect(find.text('\$31.10'), findsOneWidget); // your share shrinks
    await tester.tap(find.text('Split evenly'));
    await tester.pump();
    expect(find.text('\$32.10'), findsNWidgets(4));
    await _golden(tester, '05-split-amounts');

    // ---- collect ----
    await tester.tap(find.text('Start collecting'));
    await _settle(tester);
    expect(find.text('0 of 3 paid'), findsOneWidget);
    await _golden(tester, '06-split-collect');

    // friend 1: searching -> sheet -> processing -> paid
    await tester.tap(find.text('Tap to pay').first);
    await _navToAnimated(tester);
    expect(find.text('Hold phones together'), findsOneWidget);
    await _golden(tester, '07-tap-searching');
    await tester.pump(const Duration(milliseconds: 1600)); // searching -> sheet
    await tester.pump(const Duration(milliseconds: 400)); // sheet slide-in
    expect(find.text('Confirm with Face ID'), findsOneWidget);
    await _golden(tester, '08-wallet-sheet');
    await tester.tap(find.text('Confirm with Face ID'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Sending \$32.10…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200)); // processing -> paid
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('1 of 3 paid'), findsOneWidget);
    await _golden(tester, '09-collect-one-paid');

    // friends 2 and 3
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Tap to pay').first);
      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Confirm with Face ID'));
      await tester.pump(const Duration(milliseconds: 1300));
    }
    await tester.pump(const Duration(milliseconds: 400)); // settle into "done"
    expect(find.text("You're all settled"), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600)); // pop-in finishes
    await _golden(tester, '10-split-done');

    await tester.tap(find.text('Done'));
    await _settle(tester);
    expect(find.text('Split a bill'), findsOneWidget);
  });

  testWidgets('activity list + receipt', (tester) async {
    _sizePhone(tester);
    final app = await _pumpApp(tester);
    app.go(AppScreen.home);
    await _settle(tester);

    await tester.tap(find.text('Activity'));
    await _settle(tester);
    expect(find.text('Dana Reyes'), findsOneWidget);
    await _golden(tester, '11-activity');

    await tester.tap(find.text('Maya Chen'));
    await _settle(tester);
    expect(find.text('Receipt'), findsOneWidget);
    expect(find.text('+\$32.10'), findsOneWidget);
    await _golden(tester, '12-receipt');
  });

  testWidgets('business charge flow — keypad to approved', (tester) async {
    _sizePhone(tester);
    final app = await _pumpApp(tester);

    app.mode = Mode.business;
    app.go(AppScreen.homeBiz);
    await _settle(tester);
    expect(find.text('\$482.50'), findsOneWidget);
    await _golden(tester, '14-home-business');

    await tester.tap(find.text('Take a payment'));
    await _settle(tester);
    expect(find.text('Charge \$0.00'), findsOneWidget);
    for (final k in ['1', '2', '5', '0']) {
      await tester.tap(find.text(k));
      await tester.pump();
    }
    expect(find.text('Charge \$12.50'), findsOneWidget);
    await _golden(tester, '15-biz-keypad');

    // bizTap "waiting" ripples forever — advance the switch without settling.
    await tester.tap(find.text('Charge \$12.50'));
    await _navToAnimated(tester);
    expect(find.text('Ready — tap a card or phone'), findsOneWidget);
    await _golden(tester, '16-biz-tap');

    await tester.tap(find.text('Tap a phone'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Reading phone…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500)); // processing -> approved
    await tester.pump(const Duration(milliseconds: 400)); // settle the switch
    expect(find.text('Approved'), findsOneWidget);
    expect(find.text('TXN-7750'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600)); // pop-in finishes
    await _golden(tester, '17-biz-approved');

    await tester.tap(find.text('Done'));
    await _settle(tester);
    expect(find.text("Today's sales"), findsOneWidget);
  });
}
