import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:split_nfc_payment/repo.dart';
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

/// Pumps the shell with a test-owned [AppState] over an in-memory repo, so the
/// real persistence logic runs without a backend. No [ApiClient] is passed, so
/// auth calls short-circuit with the "no backend" message and post-login screens
/// are reached by seeding [AppState].
Future<AppState> _pumpApp(WidgetTester tester, {Repo? repo}) async {
  final app = AppState(repo: repo ?? InMemoryRepo());
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

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle();

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

    expect(find.text('Patela'), findsOneWidget);
    expect(find.text('Tap. Split. Settle.'), findsOneWidget);
    await _golden(tester, '01-welcome');

    await tester.tap(find.text('Get started'));
    await _settle(tester);
    expect(find.text('How will you use Patela?'), findsOneWidget);
    await _golden(tester, '02-choose-type');

    await tester.tap(find.text('Personal'));
    await _settle(tester);
    expect(find.text('Create your personal account'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
    await _golden(tester, '03-signup-personal');
  });

  testWidgets('auth: no backend configured shows a helpful error', (tester) async {
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

    expect(app.authError, contains('No backend configured'));
    expect(find.textContaining('No backend configured'), findsOneWidget);
    expect(find.text('Create your personal account'), findsOneWidget);
  });

  testWidgets('google button reports when it is not configured', (tester) async {
    _sizePhone(tester);
    final app = await _pumpApp(tester);
    await tester.tap(find.text('Get started'));
    await _settle(tester);
    await tester.tap(find.text('Personal'));
    await _settle(tester);

    await tester.tap(find.text('Sign up with Google'));
    await _settle(tester);
    // No ApiClient in tests, so the backend guard fires first.
    expect(app.authError, isNotNull);
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

  testWidgets('empty personal home + empty activity', (tester) async {
    _sizePhone(tester);
    final app = await _pumpApp(tester);
    app.go(AppScreen.home);
    await _settle(tester);
    expect(find.text('Split a bill'), findsOneWidget);
    expect(find.textContaining('No activity yet'), findsOneWidget);
    await _golden(tester, '04-home-personal-empty');

    await tester.tap(find.text('Activity'));
    await _settle(tester);
    expect(find.text('No activity yet'), findsOneWidget);
    await _golden(tester, '19-activity-empty');
  });

  testWidgets('split flow: build a bill, collect, and persist transactions',
      (tester) async {
    _sizePhone(tester);
    final repo = InMemoryRepo();
    await repo.addFriend('Maya Chen');
    await repo.addFriend('Leo Park');
    await repo.addFriend('Priya Rao');
    final app = await _pumpApp(tester, repo: repo);
    await app.loadData();
    await tester.pump();

    app.go(AppScreen.home);
    await _settle(tester);
    await tester.tap(find.text('Split a bill'));
    await _settle(tester);

    // enter merchant + total
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'The Fig Tree');
    await tester.enterText(fields.at(1), '128.40');
    await tester.pump();
    // add the three saved friends to the split
    for (final f in app.savedFriends) {
      app.addFriendToDraft(f);
    }
    await tester.pump();
    await tester.tap(find.text('Split evenly'));
    await tester.pump();
    expect(find.text('R32.10'), findsNWidgets(4)); // you + 3 friends
    await _golden(tester, '05-split-setup');

    await tester.tap(find.text('Start collecting'));
    await _settle(tester);
    expect(find.text('0 of 3 paid'), findsOneWidget);
    expect(find.text('of R96.30'), findsOneWidget);
    await _golden(tester, '06-split-collect');

    // pay all three
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Tap to pay').first);
      await _navToAnimated(tester);
      if (i == 0) {
        expect(find.text('Hold phones together'), findsOneWidget);
        await _golden(tester, '07-tap-searching');
      }
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 400));
      if (i == 0) {
        expect(find.text('Confirm with Face ID'), findsOneWidget);
        await _golden(tester, '08-wallet-sheet');
      }
      await tester.tap(find.text('Confirm with Face ID'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 400));
      if (i == 0) {
        await tester.pumpAndSettle();
        expect(find.text('1 of 3 paid'), findsOneWidget);
        expect(find.textContaining('Paid ·'), findsOneWidget); // new paid-card style
        await _golden(tester, '09-collect-one-paid');
      }
    }

    expect(find.text("You're all settled"), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    await _golden(tester, '10-split-done');

    // data actually persisted
    final txns = await repo.listTransactions();
    expect(txns.length, 3);
    expect(txns.every((t) => t.kind == 'split_incoming'), isTrue);
    expect(txns.fold<double>(0, (a, t) => a + t.amount), closeTo(96.30, 0.001));
  });

  testWidgets('business charge records a sale and updates today\'s total',
      (tester) async {
    _sizePhone(tester);
    final repo = InMemoryRepo();
    final app = await _pumpApp(tester, repo: repo);
    app.mode = Mode.business;
    app.go(AppScreen.homeBiz);
    await _settle(tester);
    expect(find.text('R0.00'), findsNWidgets(2)); // today's total + avg ticket
    await _golden(tester, '14-home-business-empty');

    await tester.tap(find.text('Take a payment'));
    await _settle(tester);
    for (final k in ['1', '2', '5', '0']) {
      await tester.tap(find.text(k));
      await tester.pump();
    }
    expect(find.text('Charge R12.50'), findsOneWidget);
    await _golden(tester, '15-biz-keypad');

    await tester.tap(find.text('Charge R12.50'));
    await _navToAnimated(tester);
    expect(find.text('Ready — tap a card or phone'), findsOneWidget);
    await _golden(tester, '16-biz-tap');

    await tester.tap(find.text('Tap a phone'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 1500)); // processing timer
    await tester.pump(); // recordSale microtask
    await tester.pump(const Duration(milliseconds: 400)); // settle switch
    expect(find.text('Approved'), findsOneWidget);
    expect(find.text('TXN-7750'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    await _golden(tester, '17-biz-approved');

    // persisted
    final txns = await repo.listTransactions();
    expect(txns.length, 1);
    expect(txns.first.isSale, isTrue);
    expect(txns.first.amount, closeTo(12.50, 0.001));
    final sales = await repo.todaySales();
    expect(sales.count, 1);

    await tester.tap(find.text('Done'));
    await _settle(tester);
    expect(find.text("Today's sales"), findsOneWidget);
    expect(find.text('R12.50'), findsWidgets); // today's total now reflects the sale
  });

  testWidgets('activity feed + receipt read from stored transactions',
      (tester) async {
    _sizePhone(tester);
    final repo = InMemoryRepo();
    // Fixed dates so the receipt golden is deterministic.
    repo.seedTransactions([
      Txn(
          id: 't1',
          kind: 'sale',
          title: 'Card sale',
          subtitle: 'Card · phone tap',
          amount: 6.75,
          method: 'google_pay',
          reference: 'TXN-7702',
          createdAt: DateTime(2026, 7, 9, 15, 2)),
      Txn(
          id: 't2',
          kind: 'sale',
          title: 'Card sale',
          subtitle: 'Card · card tap',
          amount: 52.40,
          method: 'card',
          reference: 'TXN-7588',
          createdAt: DateTime(2026, 7, 6, 11, 20)),
    ]);
    final app = await _pumpApp(tester, repo: repo);
    app.mode = Mode.business;
    app.go(AppScreen.homeBiz);
    await app.loadData();
    await _settle(tester);

    await tester.tap(find.text('Activity'));
    await _settle(tester);
    expect(find.text('Card sale'), findsNWidgets(2));
    await _golden(tester, '11-activity');

    await tester.tap(find.text('Card sale').first);
    await _settle(tester);
    expect(find.text('Receipt'), findsOneWidget);
    expect(find.text('+R6.75'), findsOneWidget);
    expect(find.text('Google Pay'), findsOneWidget);
    expect(find.text('TXN-7702'), findsOneWidget);
    await _golden(tester, '12-receipt');
  });
}
