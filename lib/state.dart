import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

enum AppScreen {
  onboard1,
  chooseType,
  signup,
  signin,
  home,
  homeBiz,
  splitAmount,
  splitCollect,
  splitDone,
  bizAmount,
  bizTap,
  bizApproved,
  activity,
  receipt,
}

enum Mode { personal, business }

enum TapStage { searching, sheet, processing }

enum BizStage { waiting, processing }

enum PayMethod { card, phone }

String fmt(num n) => '\$${n.toStringAsFixed(2)}';

class Friend {
  Friend({
    required this.name,
    required this.initials,
    required this.color,
    required this.amount,
    this.paid = false,
  });

  final String name;
  final String initials;
  final Color color;
  double amount;
  bool paid;

  String get firstName => name.split(' ').first;
}

class ActivityItem {
  const ActivityItem({
    required this.initials,
    required this.color,
    required this.title,
    required this.sub,
    required this.amount,
    required this.date,
    required this.method,
    required this.ref,
  });

  final String initials;
  final Color color;
  final String title;
  final String sub;
  final double amount;
  final String date;
  final String method;
  final String ref;

  bool get positive => amount >= 0;
  String get amountStr => (positive ? '+' : '−') + fmt(amount.abs());
}

class SaleItem {
  const SaleItem({required this.title, required this.sub, required this.amountStr});

  final String title;
  final String sub;
  final String amountStr;
}

class AppState extends ChangeNotifier {
  AppScreen screen = AppScreen.onboard1;
  Mode mode = Mode.personal;
  Mode signinMode = Mode.personal;
  bool linkedApple = false;
  bool linkedGoogle = false;

  final double total = 128.40;
  final List<Friend> friends = [
    Friend(name: 'Maya Chen', initials: 'MC', color: const Color(0xFFE08579), amount: 32.10),
    Friend(name: 'Leo Park', initials: 'LP', color: const Color(0xFF6E78CE), amount: 32.10),
    Friend(name: 'Priya Rao', initials: 'PR', color: const Color(0xFFA67BD4), amount: 32.10),
  ];

  int tapIdx = -1;
  TapStage? tapStage;
  int chargeCents = 0;
  BizStage? bizStage;
  PayMethod? bizMethod;
  ActivityItem? receipt;
  AppScreen prevScreen = AppScreen.home;

  final List<Timer> _timers = [];

  void _after(int ms, VoidCallback fn) => _timers.add(Timer(Duration(milliseconds: ms), fn));

  void _clearTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  @override
  void dispose() {
    _clearTimers();
    super.dispose();
  }

  void go(AppScreen s) {
    _clearTimers();
    screen = s;
    notifyListeners();
  }

  // ---- derived ----
  double get owedTotal => friends.fold(0.0, (a, f) => a + f.amount);
  double get yourShare => math.max(0, ((total - owedTotal) * 100).round() / 100);
  double get collected => friends.where((f) => f.paid).fold(0.0, (a, f) => a + f.amount);
  bool get allPaid => friends.isNotEmpty && friends.every((f) => f.paid);
  int get paidCount => friends.where((f) => f.paid).length;
  AppScreen get homeScreen => mode == Mode.business ? AppScreen.homeBiz : AppScreen.home;
  bool get showNav =>
      screen == AppScreen.home || screen == AppScreen.homeBiz || screen == AppScreen.activity;
  bool get tapActive => tapIdx >= 0;
  Friend? get tapFriend => tapIdx >= 0 ? friends[tapIdx] : null;

  /// Wallet the user linked during auth; Google sign-in links Google Pay.
  String get payMethodLabel {
    if (linkedApple && !linkedGoogle) return 'Apple Pay';
    if (linkedGoogle && !linkedApple) return 'Google Pay';
    return linkedApple ? 'Apple Pay' : 'Google Pay';
  }

  // ---- auth ----
  void getStarted() => go(AppScreen.chooseType);

  void logout() {
    linkedApple = false;
    linkedGoogle = false;
    signinMode = Mode.personal;
    go(AppScreen.onboard1);
  }

  void pickType(Mode m) {
    mode = m;
    go(AppScreen.signup);
  }

  void submitSignup() => go(homeScreen);

  void setSigninMode(Mode m) {
    signinMode = m;
    notifyListeners();
  }

  void submitSignin() {
    mode = signinMode;
    go(homeScreen);
  }

  void googleAuthSignup() {
    linkedGoogle = true;
    go(homeScreen);
  }

  void googleAuthSignin() {
    mode = signinMode;
    linkedGoogle = true;
    go(homeScreen);
  }

  // ---- split ----
  void adj(int i, double d) {
    friends[i].amount = math.max(0, ((friends[i].amount + d) * 100).round() / 100);
    notifyListeners();
  }

  void splitEven() {
    final each = ((total / 4) * 100).round() / 100;
    for (final f in friends) {
      f.amount = each;
    }
    notifyListeners();
  }

  void startTap(int i) {
    _clearTimers();
    tapIdx = i;
    tapStage = TapStage.searching;
    notifyListeners();
    _after(1600, () {
      tapStage = TapStage.sheet;
      notifyListeners();
    });
  }

  void cancelTap() {
    _clearTimers();
    tapIdx = -1;
    tapStage = null;
    notifyListeners();
  }

  void confirmPay() {
    tapStage = TapStage.processing;
    notifyListeners();
    _after(1200, () {
      if (tapIdx < 0) return;
      friends[tapIdx].paid = true;
      tapIdx = -1;
      tapStage = null;
      screen = allPaid ? AppScreen.splitDone : AppScreen.splitCollect;
      notifyListeners();
    });
  }

  // ---- business keypad ----
  void press(String d) {
    var c = chargeCents;
    if (d == 'back') {
      c = c ~/ 10;
    } else if (d == '00') {
      c = c * 100;
    } else {
      c = c * 10 + int.parse(d);
    }
    if (c > 99999999) c = chargeCents;
    chargeCents = c;
    notifyListeners();
  }

  void startCharge() {
    chargeCents = 0;
    go(AppScreen.bizAmount);
  }

  void doCharge() {
    if (chargeCents <= 0) return;
    go(AppScreen.bizTap);
    bizStage = BizStage.waiting;
    bizMethod = null;
    notifyListeners();
  }

  void toBizAmount() {
    chargeCents = 0;
    go(AppScreen.bizAmount);
  }

  void sim(PayMethod m) {
    _clearTimers();
    bizStage = BizStage.processing;
    bizMethod = m;
    notifyListeners();
    _after(1500, () {
      screen = AppScreen.bizApproved;
      notifyListeners();
    });
  }

  String get chargeDisplay => fmt(chargeCents / 100);
  bool get canCharge => chargeCents > 0;
  String get txnRef => '${7700 + (chargeCents % 300)}';
  bool get bizWaiting => bizStage == BizStage.waiting;
  bool get bizProcessing => bizStage == BizStage.processing;
  String get bizMethodLabel =>
      bizMethod == PayMethod.phone ? payMethodLabel : 'Contactless card';
  String get bizTapMsg => bizProcessing
      ? (bizMethod == PayMethod.phone ? 'Reading phone…' : 'Reading card…')
      : 'Ready — tap a card or phone';

  // ---- activity ----
  static const List<ActivityItem> activityAll = [
    ActivityItem(
      initials: 'MC',
      color: Color(0xFFE08579),
      title: 'Maya Chen',
      sub: 'Bill split · The Fig Tree',
      amount: 32.10,
      date: 'Jul 9, 2026 · 8:14 PM',
      method: 'Apple Pay',
      ref: 'TXN-7741',
    ),
    ActivityItem(
      initials: 'FV',
      color: Color(0xFF2E3A87),
      title: 'Card sale',
      sub: 'Fig & Vine Café · phone tap',
      amount: 6.75,
      date: 'Jul 9, 2026 · 3:02 PM',
      method: 'Contactless card',
      ref: 'TXN-7702',
    ),
    ActivityItem(
      initials: 'DR',
      color: Color(0xFFA67BD4),
      title: 'Dana Reyes',
      sub: 'Bill split · Ramen Yokocho',
      amount: -18.40,
      date: 'Jul 6, 2026 · 9:41 PM',
      method: 'Google Pay',
      ref: 'TXN-7610',
    ),
    ActivityItem(
      initials: 'FV',
      color: Color(0xFF2E3A87),
      title: 'Card sale',
      sub: 'Fig & Vine Café · card tap',
      amount: 41.20,
      date: 'Jul 6, 2026 · 11:20 AM',
      method: 'Contactless card',
      ref: 'TXN-7588',
    ),
  ];

  List<ActivityItem> get activityHome => activityAll.take(3).toList();

  static const List<SaleItem> salesHome = [
    SaleItem(title: 'Card sale', sub: 'Just now · phone tap', amountStr: '+\$6.75'),
    SaleItem(title: 'Card sale', sub: '2:44 PM · card tap', amountStr: '+\$18.00'),
    SaleItem(title: 'Card sale', sub: '1:12 PM · card tap', amountStr: '+\$52.40'),
  ];

  void openReceipt(ActivityItem r) {
    prevScreen = screen;
    receipt = r;
    screen = AppScreen.receipt;
    notifyListeners();
  }

  void receiptBack() => go(prevScreen);
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState super.notifier, required super.child});

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
