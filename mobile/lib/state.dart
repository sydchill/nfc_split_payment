import 'dart:async';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'google_signin_service.dart';
import 'models.dart';
import 'payments.dart';
import 'repo.dart';

export 'models.dart';

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

class AppState extends ChangeNotifier {
  /// Pass [api] to talk to the Flask backend. Omit it (tests, offline demos) and
  /// the app runs on an in-memory repo with auth disabled.
  AppState({
    ApiClient? api,
    Repo? repo,
    PaymentTerminal? terminal,
    GoogleAuthService? google,
  })  : api = api,
        google = google ?? (api != null ? GoogleSignInService() : null),
        repo = repo ?? (api != null ? ApiRepo(api) : InMemoryRepo()),
        terminal = terminal ?? MockTerminal();

  final ApiClient? api;
  final GoogleAuthService? google;
  final Repo repo;
  final PaymentTerminal terminal;

  /// The signed-in account, as returned by the API (null when signed out).
  Map<String, dynamic>? account;

  AppScreen screen = AppScreen.onboard1;
  Mode mode = Mode.personal;
  Mode signinMode = Mode.personal;
  bool linkedApple = false;
  bool linkedGoogle = false;

  // Auth UI state.
  bool authLoading = false;
  String? authError;

  // Loaded domain data.
  bool dataLoading = false;
  List<Friend> savedFriends = [];
  List<Txn> transactions = [];
  SalesSummary todaySales = const SalesSummary.empty();

  // Split draft (setup screen) + the persisted bill being collected.
  String splitMerchant = '';
  double splitTotal = 0;
  List<Participant> draft = [];
  Bill? bill;

  // Split tap-to-pay overlay.
  int tapIdx = -1;
  TapStage? tapStage;

  // Business charge.
  int chargeCents = 0;
  BizStage? bizStage;
  PayMethod? bizMethod;
  Txn? lastSale;
  ChargeResult? lastCharge;

  Txn? receipt;
  AppScreen prevScreen = AppScreen.home;

  final List<Timer> _timers = [];
  int _draftSeq = 0;

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

  // ---------------------------------------------------------------------------
  // Derived
  // ---------------------------------------------------------------------------
  AppScreen get homeScreen => mode == Mode.business ? AppScreen.homeBiz : AppScreen.home;
  bool get showNav =>
      screen == AppScreen.home || screen == AppScreen.homeBiz || screen == AppScreen.activity;
  bool get tapActive => tapIdx >= 0;

  List<Txn> get recentActivity => transactions.take(3).toList();
  List<Txn> get recentSales => transactions.where((t) => t.isSale).take(3).toList();

  // Split draft math.
  double get draftOwed => draft.fold(0.0, (a, p) => a + p.amount);
  double get draftYourShare {
    final v = ((splitTotal - draftOwed) * 100).round() / 100;
    return v < 0 ? 0 : v;
  }

  bool get canStartCollecting =>
      splitMerchant.trim().isNotEmpty && splitTotal > 0 && draft.isNotEmpty;

  Participant? get tapParticipant {
    final ps = bill?.participants ?? const <Participant>[];
    return tapIdx >= 0 && tapIdx < ps.length ? ps[tapIdx] : null;
  }

  String _walletDbMethod() => (linkedApple && !linkedGoogle) ? 'apple_pay' : 'google_pay';

  /// Wallet label for the mock tap sheet.
  String get payMethodLabel => _walletDbMethod() == 'apple_pay' ? 'Apple Pay' : 'Google Pay';

  // ---------------------------------------------------------------------------
  // Account display
  // ---------------------------------------------------------------------------
  String get accountEmail => (account?['email'] as String?) ?? '';

  /// The backend computes the display name; fall back locally when signed out.
  String get displayName {
    final fromApi = (account?['display_name'] as String?)?.trim();
    if (fromApi != null && fromApi.isNotEmpty) return fromApi;
    if (mode == Mode.business) return 'Your business';
    final email = accountEmail;
    return email.isNotEmpty ? email.split('@').first : 'You';
  }

  String get initials => initialsOf(displayName);

  // ---------------------------------------------------------------------------
  // Auth (Flask API)
  // ---------------------------------------------------------------------------
  bool get _configured => api != null;

  void _setLoading(bool v) {
    authLoading = v;
    if (v) authError = null;
    notifyListeners();
  }

  bool _guardConfigured() {
    if (_configured) return true;
    authError = 'No backend configured — start the Flask API and set '
        'API_BASE_URL (see backend/README.md).';
    notifyListeners();
    return false;
  }

  /// Applies a signed-in account: stores it, routes to the right home, loads data.
  Future<void> _onSignedIn(Map<String, dynamic> user) async {
    account = user;
    mode = (user['mode'] as String?) == 'business' ? Mode.business : Mode.personal;
    authError = null;
    authLoading = false;
    screen = homeScreen;
    notifyListeners();
    await loadData();
  }

  /// Restores a persisted session at startup. Returns true if still signed in.
  Future<bool> restoreSession() async {
    final client = api;
    if (client == null) return false;
    await client.loadSession();
    if (!client.hasSession) return false;
    try {
      await _onSignedIn(await client.me());
      return true;
    } on ApiException {
      await client.clearSession();
      return false;
    }
  }

  void getStarted() => go(AppScreen.chooseType);

  void pickType(Mode m) {
    mode = m;
    authError = null;
    go(AppScreen.signup);
  }

  void setSigninMode(Mode m) {
    signinMode = m;
    notifyListeners();
  }

  Future<void> submitSignup({
    required String email,
    required String password,
    required String fullName,
    String? businessName,
    String? category,
  }) async {
    if (!_guardConfigured()) return;
    if (email.trim().isEmpty || password.isEmpty) {
      authError = 'Enter your email and a password.';
      notifyListeners();
      return;
    }
    _setLoading(true);
    try {
      final user = await api!.register(
        email: email.trim(),
        password: password,
        mode: mode.name,
        fullName: fullName.trim(),
        businessName: mode == Mode.business ? businessName?.trim() : null,
        category: mode == Mode.business ? category?.trim() : null,
      );
      await _onSignedIn(user);
    } on ApiException catch (e) {
      authError = e.message;
      _setLoading(false);
    } catch (_) {
      authError = 'Could not create your account. Please try again.';
      _setLoading(false);
    }
  }

  Future<void> submitSignin({required String email, required String password}) async {
    if (!_guardConfigured()) return;
    if (email.trim().isEmpty || password.isEmpty) {
      authError = 'Enter your email and password.';
      notifyListeners();
      return;
    }
    _setLoading(true);
    try {
      await _onSignedIn(await api!.login(email.trim(), password));
    } on ApiException catch (e) {
      authError = e.message;
      _setLoading(false);
    } catch (_) {
      authError = 'Could not sign you in. Please try again.';
      _setLoading(false);
    }
  }

  /// Native Google Sign-In, verified by the backend.
  ///
  /// The account type picked on the choose-type screen is only used if this is a
  /// brand-new account; returning users keep the mode stored on their account.
  Future<void> googleAuth() async {
    if (!_guardConfigured()) return;
    final svc = google;
    if (svc == null || !svc.isConfigured) {
      authError = 'Google sign-in is not configured yet — '
          'set GOOGLE_SERVER_CLIENT_ID in env/dev.json.';
      notifyListeners();
      return;
    }
    _setLoading(true);
    final res = await svc.signIn();
    if (res.cancelled) {
      _setLoading(false); // user backed out — no error message
      return;
    }
    if (!res.ok) {
      authError = res.error;
      _setLoading(false);
      return;
    }
    try {
      final user = await api!.googleSignIn(idToken: res.idToken!, mode: mode.name);
      await _onSignedIn(user);
    } on ApiException catch (e) {
      authError = e.message;
      _setLoading(false);
    } catch (_) {
      authError = 'Could not complete Google sign-in. Please try again.';
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    signinMode = Mode.personal;
    linkedApple = false;
    linkedGoogle = false;
    try {
      await api?.logout();
    } catch (_) {
      // Ignore; the local session is cleared regardless.
    }
    // Forget the Google account too, so the next sign-in shows the picker.
    await google?.signOut();
    account = null;
    authLoading = false;
    _resetData();
    go(AppScreen.onboard1);
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------
  void _resetData() {
    savedFriends = [];
    transactions = [];
    todaySales = const SalesSummary.empty();
    bill = null;
    draft = [];
  }

  Future<void> loadData() async {
    dataLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        repo.listFriends(),
        repo.listTransactions(),
        repo.todaySales(),
      ]);
      savedFriends = results[0] as List<Friend>;
      transactions = results[1] as List<Txn>;
      todaySales = results[2] as SalesSummary;
    } catch (_) {
      // Leave existing data; a transient load error shouldn't blank the UI.
    } finally {
      dataLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Split — setup
  // ---------------------------------------------------------------------------
  void startSplit() {
    splitMerchant = '';
    splitTotal = 0;
    draft = [];
    bill = null;
    go(AppScreen.splitAmount);
  }

  void setSplitMerchant(String v) {
    splitMerchant = v;
    notifyListeners();
  }

  void setSplitTotal(String v) {
    splitTotal = double.tryParse(v.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    notifyListeners();
  }

  bool _inDraft(String friendId) => draft.any((p) => p.friendId == friendId);

  void addFriendToDraft(Friend f) {
    if (_inDraft(f.id)) return;
    draft.add(Participant(
      id: 'draft-${_draftSeq++}',
      friendId: f.id,
      name: f.name,
      color: f.color,
      amount: 0,
    ));
    notifyListeners();
  }

  Future<void> createAndAddFriend(String name) async {
    final n = name.trim();
    if (n.isEmpty) return;
    final f = await repo.addFriend(n);
    savedFriends = [...savedFriends, f];
    addFriendToDraft(f);
  }

  void removeFromDraft(String participantId) {
    draft.removeWhere((p) => p.id == participantId);
    notifyListeners();
  }

  void adjustDraft(int i, double d) {
    final p = draft[i];
    p.amount = ((p.amount + d).clamp(0, double.infinity) * 100).round() / 100;
    notifyListeners();
  }

  void splitEven() {
    if (draft.isEmpty) return;
    final each = ((splitTotal / (draft.length + 1)) * 100).round() / 100;
    for (final p in draft) {
      p.amount = each;
    }
    notifyListeners();
  }

  Future<void> startCollecting() async {
    if (!canStartCollecting) return;
    dataLoading = true;
    notifyListeners();
    try {
      bill = await repo.createBill(
        merchant: splitMerchant.trim(),
        total: splitTotal,
        participants: draft,
      );
      dataLoading = false;
      go(AppScreen.splitCollect);
    } catch (_) {
      dataLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Split — collect / tap to pay
  // ---------------------------------------------------------------------------
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
    final b = bill;
    final p = tapParticipant;
    if (b == null || p == null) return;
    tapStage = TapStage.processing;
    notifyListeners();
    final method = _walletDbMethod();
    _after(1200, () async {
      try {
        final txn = await repo.payParticipant(bill: b, participant: p, method: method);
        transactions = [txn, ...transactions];
        if (b.allPaid) {
          await repo.settleBill(b.id);
        }
      } catch (_) {
        p.paid = true; // best-effort; still advance the UI
      }
      tapIdx = -1;
      tapStage = null;
      screen = b.allPaid ? AppScreen.splitDone : AppScreen.splitCollect;
      notifyListeners();
    });
  }

  // ---------------------------------------------------------------------------
  // Business
  // ---------------------------------------------------------------------------
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

  /// Runs the charge through [terminal] (mock today, a real SoftPOS SDK later),
  /// then records the sale. [m] tells the mock which instrument to simulate; a
  /// real terminal detects it from the tap.
  Future<void> sim(PayMethod m) async {
    bizStage = BizStage.processing;
    bizMethod = m;
    notifyListeners();
    final tap = m == PayMethod.card ? 'card tap' : 'phone tap';
    try {
      final res = await terminal.charge(
        ChargeRequest(amountCents: chargeCents, reference: 'TXN-$txnRef'),
        simulateAs: m == PayMethod.phone ? TapKind.phone : TapKind.card,
      );
      lastCharge = res;
      if (!res.approved) {
        bizStage = BizStage.waiting;
        notifyListeners();
        return;
      }
      try {
        final txn = await repo.recordSale(
          amount: chargeCents / 100,
          method: res.methodDb,
          reference: res.reference ?? 'TXN-$txnRef',
          subtitle: '$displayName · $tap',
        );
        lastSale = txn;
        transactions = [txn, ...transactions];
        todaySales = SalesSummary(
          count: todaySales.count + 1,
          total: todaySales.total + txn.amount,
        );
      } catch (_) {
        lastSale = null;
      }
      screen = AppScreen.bizApproved;
    } catch (_) {
      bizStage = BizStage.waiting; // terminal error — let them retry
    }
    notifyListeners();
  }

  String get chargeDisplay => fmt(chargeCents / 100);
  bool get canCharge => chargeCents > 0;
  String get txnRef => '${7700 + (chargeCents % 300)}';
  bool get bizWaiting => bizStage == BizStage.waiting;
  bool get bizProcessing => bizStage == BizStage.processing;
  // Receipt details come from the terminal's result once a charge completes.
  String get bizMethodLabel => methodLabelFor(lastCharge?.methodDb);
  String get chargeMaskedPan => lastCharge?.maskedPan ?? '•••• ----';
  String get chargeReference => lastCharge?.reference ?? 'TXN-$txnRef';
  String get bizTapMsg => bizProcessing
      ? (bizMethod == PayMethod.phone ? 'Reading phone…' : 'Reading card…')
      : 'Ready — tap a card or phone';

  // ---------------------------------------------------------------------------
  // Receipt
  // ---------------------------------------------------------------------------
  void openReceipt(Txn t) {
    prevScreen = screen;
    receipt = t;
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
