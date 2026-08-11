/// Payment acceptance abstraction.
///
/// The "take a payment" step is intentionally provider-agnostic so a real
/// SoftPOS / Tap-to-Pay SDK (e.g. Halo Dot) can be dropped in behind
/// [PaymentTerminal] without touching the UI or the rest of the app — the same
/// pattern used for data with `Repo`. Today the app runs on [MockTerminal];
/// [HaloDotTerminal] is the wiring point for the certified SDK.
library;

enum TapKind { card, phone }

enum ChargeStatus { approved, declined, cancelled, error }

class ChargeRequest {
  const ChargeRequest({
    required this.amountCents,
    required this.reference,
    this.currency = 'ZAR',
  });

  final int amountCents;
  final String reference;
  final String currency;

  double get amount => amountCents / 100;
}

class ChargeResult {
  const ChargeResult({
    required this.status,
    required this.methodDb,
    this.scheme,
    this.maskedPan,
    this.reference,
    this.authCode,
    this.declineReason,
  });

  /// Outcome of the tap.
  final ChargeStatus status;

  /// How the DB records the method: 'card' | 'apple_pay' | 'google_pay'.
  final String methodDb;

  /// Card network, e.g. 'Visa' / 'Mastercard' (null for wallet-only).
  final String? scheme;

  /// Masked card number for the receipt, e.g. '•••• 4291'.
  final String? maskedPan;

  /// Acquirer/reference id echoed back onto the receipt.
  final String? reference;

  /// Authorization code from the acquirer.
  final String? authCode;

  /// Human-readable reason when [status] is declined/error.
  final String? declineReason;

  bool get approved => status == ChargeStatus.approved;
}

/// A card-acceptance terminal. A real SoftPOS SDK drives the NFC tap itself and
/// ignores [simulateAs]; the mock uses it to fake which instrument was tapped.
abstract class PaymentTerminal {
  String get name;

  /// True for a certified real terminal, false for the simulator.
  bool get isReal;

  /// One-time setup (SDK init, credential/session bootstrap). No-op for mock.
  Future<void> init() async {}

  Future<ChargeResult> charge(ChargeRequest req, {TapKind simulateAs = TapKind.card});
}

/// Simulated terminal used for demos and tests — no money moves, no real NFC.
class MockTerminal implements PaymentTerminal {
  MockTerminal({this.walletMethodDb = 'google_pay', this.delay = const Duration(milliseconds: 1500)});

  /// Which wallet a "phone" tap simulates ('google_pay' | 'apple_pay').
  final String walletMethodDb;
  final Duration delay;

  @override
  String get name => 'Simulated terminal';

  @override
  bool get isReal => false;

  @override
  Future<void> init() async {}

  @override
  Future<ChargeResult> charge(ChargeRequest req, {TapKind simulateAs = TapKind.card}) async {
    await Future<void>.delayed(delay);
    return ChargeResult(
      status: ChargeStatus.approved,
      methodDb: simulateAs == TapKind.phone ? walletMethodDb : 'card',
      scheme: 'Visa',
      maskedPan: '•••• 4291',
      reference: req.reference,
      authCode: '${100000 + (req.amountCents % 900000)}',
    );
  }
}

/// Real SoftPOS terminal via the Halo Dot Tap-to-Pay (SoftPOS) SDK.
///
/// Not functional yet — it is the single, contained place the certified SDK
/// gets wired in. Onboarding gates this (see SOFTPOS_PROVIDERS.md). Steps once
/// you have Halo Dot merchant access + their Android SDK:
///
///  1. Add the Halo Dot Android SDK (their AAR / Maven artifact) under
///     `android/`, exposed to Flutter via a platform channel or their Flutter
///     package if provided.
///  2. In [init], initialize the SDK with your Halo Dot merchant credentials,
///     supplied at build time (`--dart-define` / secure storage) — never
///     hard-coded in source.
///  3. In [charge], call the SDK's start-transaction with amount / currency /
///     reference. The SDK presents the NFC tap prompt, reads the EMV card or
///     wallet, talks to the acquirer, and returns a result. Map that result to
///     [ChargeResult] (status, scheme, masked PAN, auth code, decline reason).
class HaloDotTerminal implements PaymentTerminal {
  @override
  String get name => 'Halo Dot';

  @override
  bool get isReal => true;

  @override
  Future<void> init() async {
    // TODO(payments): HaloSdk.initialize(merchantId: ..., apiKey: ...);
  }

  @override
  Future<ChargeResult> charge(ChargeRequest req, {TapKind simulateAs = TapKind.card}) async {
    throw UnimplementedError(
      'Halo Dot SDK not integrated yet. Onboard at halodot.io, add their '
      'Android Tap-to-Pay SDK, then map startTransaction() -> ChargeResult here.',
    );
  }
}
