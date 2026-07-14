import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:split_nfc_payment/main.dart';

Future<void> _loadFonts() async {
  final loader = FontLoader('Poppins');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final bytes = File('assets/fonts/Poppins-$w.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

Future<void> _golden(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('full walkthrough of every screen', (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TandemApp());
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));

    // ---- welcome ----
    expect(find.text('Tandem'), findsOneWidget);
    expect(find.text('Tap. Split. Settle.'), findsOneWidget);
    await _golden(tester, '01-welcome');

    // ---- choose account type ----
    await tester.tap(find.text('Get started'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('How will you use Tandem?'), findsOneWidget);
    await _golden(tester, '02-choose-type');

    // ---- personal signup ----
    await tester.tap(find.text('Personal'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Create your personal account'), findsOneWidget);
    expect(find.text('Business name'), findsNothing);
    await _golden(tester, '03-signup-personal');

    // ---- personal home ----
    await tester.tap(find.text('Create account'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Alex Rivera'), findsOneWidget);
    expect(find.text('Split a bill'), findsOneWidget);
    expect(find.text('Maya Chen'), findsOneWidget);
    await _golden(tester, '04-home-personal');

    // ---- split: amounts ----
    await tester.tap(find.text('Split a bill'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('\$128.40'), findsOneWidget);
    // stepper: +$1 on Maya, your share shrinks
    await tester.tap(find.text('+').first);
    await tester.pump();
    expect(find.text('\$33.10'), findsOneWidget);
    expect(find.text('\$31.10'), findsOneWidget); // your share
    await tester.tap(find.text('Split evenly'));
    await tester.pump();
    expect(find.text('\$32.10'), findsNWidgets(4)); // you + 3 friends
    await _golden(tester, '05-split-amounts');

    // ---- split: collect ----
    await tester.tap(find.text('Start collecting'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('0 of 3 paid'), findsOneWidget);
    expect(find.text('of \$96.30'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    await _golden(tester, '06-split-collect');

    // ---- friend 1 taps: searching -> sheet -> processing -> paid ----
    await tester.tap(find.text('Tap to pay').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Hold phones together'), findsOneWidget);
    await _golden(tester, '07-tap-searching');

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 400)); // sheet slide-in
    expect(find.text('Google Pay'), findsOneWidget);
    expect(find.text('Confirm with Face ID'), findsOneWidget);
    await _golden(tester, '08-wallet-sheet');

    await tester.tap(find.text('Confirm with Face ID'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Sending \$32.10…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('1 of 3 paid'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    await _golden(tester, '09-collect-one-paid');

    // ---- friends 2 and 3 pay; auto-advance to settled ----
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Tap to pay').first);
      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pump(const Duration(milliseconds: 400)); // sheet slide-in
      await tester.tap(find.text('Confirm with Face ID'));
      await tester.pump(const Duration(milliseconds: 1300));
    }
    expect(find.text("You're all settled"), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    await _golden(tester, '10-split-done');

    await tester.tap(find.text('Done'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Split a bill'), findsOneWidget);

    // ---- activity + receipt ----
    await tester.tap(find.text('Activity'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Dana Reyes'), findsOneWidget);
    await _golden(tester, '11-activity');

    await tester.tap(find.text('Maya Chen'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Receipt'), findsOneWidget);
    expect(find.text('+\$32.10'), findsOneWidget);
    expect(find.text('Apple Pay'), findsOneWidget);
    await _golden(tester, '12-receipt');
    await tester.tap(find.text('Close'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));

    // ---- logout, sign in as business ----
    await tester.tap(find.text('Home'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    // logout via the round header button (only CircleBorder InkWell on home)
    final logoutBtn = find.byWidgetPredicate(
        (w) => w is InkWell && w.customBorder is CircleBorder && w.onTap != null);
    await tester.tap(logoutBtn.first);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Get started'), findsOneWidget);

    await tester.tap(find.text('Sign in').last);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Welcome back'), findsOneWidget);
    await _golden(tester, '13-signin');

    await tester.tap(find.text('Business'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Sign in'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Fig & Vine Café'), findsOneWidget);
    expect(find.text('\$482.50'), findsOneWidget);
    await _golden(tester, '14-home-business');

    // ---- charge keypad ----
    await tester.tap(find.text('Take a payment'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Charge \$0.00'), findsOneWidget);
    for (final k in ['1', '2', '5', '0']) {
      await tester.tap(find.text(k));
      await tester.pump();
    }
    expect(find.text('Charge \$12.50'), findsOneWidget);
    await _golden(tester, '15-biz-keypad');

    // ---- tap to pay ----
    await tester.tap(find.text('Charge \$12.50'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Ready — tap a card or phone'), findsOneWidget);
    await _golden(tester, '16-biz-tap');

    await tester.tap(find.text('Tap a phone'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Reading phone…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('Approved'), findsOneWidget);
    expect(find.text('Google Pay'), findsOneWidget);
    expect(find.text('TXN-7750'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    await _golden(tester, '17-biz-approved');

    await tester.tap(find.text('Done'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text("Today's sales"), findsOneWidget);
  });

  testWidgets('business signup shows extra fields', (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TandemApp());
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Get started'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Business'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Create your business account'), findsOneWidget);
    expect(find.text('Business name'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Owner name'), findsOneWidget);
    await _golden(tester, '18-signup-business');
  });
}
