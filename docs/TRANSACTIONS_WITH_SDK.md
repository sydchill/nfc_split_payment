# Patela — Transactions With a Real SoftPOS SDK

This document describes how transactions will work **once a certified SoftPOS
SDK (Halo Dot or Lipa Payments) is integrated** — replacing today's simulator.
It is the forward-looking companion to `docs/TRANSACTIONS.md` (which covers the
current, simulated behaviour) and `SOFTPOS_PROVIDERS.md` (provider choice).

> **Nothing here changes the app's architecture.** The provider SDK plugs into
> the existing `PaymentTerminal` seam (`mobile/lib/payments.dart`). The UI, the `Repo`
> persistence, and the `transactions` ledger stay exactly as they are — the tap
> just becomes real.

---

## 1. What actually changes

| Aspect | Today (`MockTerminal`) | With the SDK (`HaloDotTerminal` / `LipaTerminal`) |
|--------|------------------------|---------------------------------------------------|
| The tap | A button that waits ~1.5s | A **real NFC EMV read** of the customer's card / phone wallet |
| Money | None moves | **Real authorization + capture**, funds settle to the merchant's bank |
| Verification | None | **PIN on device (CVM)** for amounts over the contactless limit |
| Result data | Fake masked card | Real scheme, masked PAN, auth code, acquirer reference |
| Connectivity | Not needed | **Online authorization** required (issuer must approve) |
| Compliance | N/A | Handled by the **provider's certified SDK** (PCI MPoC / Visa & Mastercard Tap-to-Phone) |

Everything downstream of the tap is unchanged: an approved charge still becomes a
`transactions` row via `Repo.recordSale(...)`, still updates today's totals, and
still renders the same receipt.

---

## 2. Prerequisites (one-time, before any real transaction)

1. **Merchant onboarding** with the provider (business registration, KYC,
   acquiring/settlement account) — see `SOFTPOS_PROVIDERS.md`.
2. **SDK added** to the project — either the provider's Flutter package, or their
   Android SDK (AAR) wrapped behind a Flutter platform channel.
3. **Credentials** (merchant id / API key) supplied at build time via
   `--dart-define` or secure storage — **never hard-coded**, and different per
   environment (sandbox vs production).
4. **Android requirements** the SDK will specify: NFC permission + feature, a
   minimum Android version, hardware-backed keystore, and device integrity /
   attestation checks the SDK performs at init.

In code, all of this lands in **`PaymentTerminal.init()`** and the terminal's
`charge()` — no other file needs to change.

---

## 3. Real business-sale sequence

```
Merchant                 Patela app            SoftPOS SDK              Provider / Acquirer / Issuer
   │  enter amount           │                     │                              │
   │  ── Charge ──►          │                     │                              │
   │                terminal.charge(req) ──►        │                              │
   │                         │      SDK enables NFC reader mode                    │
   │  customer taps card/phone ─────────────────►   │                              │
   │                         │      reads EMV data (encrypted, in secure comp.)    │
   │                         │      amount > CVM limit? ──► prompt PIN on device    │
   │                         │                     │  ── encrypted txn ──►          │
   │                         │                     │            authorize online ──►│
   │                         │                     │  ◄── approved / declined ──    │
   │                         │  ◄── SDK result ──  │                              │
   │             map → ChargeResult                │                              │
   │             approved? Repo.recordSale() ──► INSERT transactions (kind='sale') │
   │  ◄── Approved receipt ──│                     │                              │
```

**Step by step (what fills into `HaloDotTerminal.charge()`):**

1. `terminal.charge(ChargeRequest{ amountCents, reference, currency:'ZAR' })` is
   called by `AppState.sim(...)` — unchanged from today.
2. The SDK puts the phone into **NFC reader mode** and shows its tap prompt.
3. The customer taps a **contactless card** or **phone wallet** (Google Pay /
   Apple Pay / Samsung Pay). The SDK reads the EMV data inside its certified
   secure component — the app never sees raw card data (keeps PCI scope with the
   provider).
4. **Cardholder verification (CVM):** if the amount is **above South Africa's
   contactless limit** (around **R500** — confirm the current value with your
   provider), the SDK collects a **PIN on the device screen** (protected by the
   PIN-on-COTS / MPoC certification). Below the limit, no PIN.
5. The SDK sends the encrypted transaction to the provider, which routes it to
   the **acquirer → card scheme → issuing bank** for **online authorization**.
6. The SDK returns the outcome. The terminal maps it to **`ChargeResult`**
   (`status`, `scheme`, `maskedPan`, `authCode`, `reference`, `declineReason`).
7. On **approved**, `Repo.recordSale(...)` writes the `transactions` row and the
   **Approved** receipt shows the real method, masked card, and reference — same
   code path as today.
8. On **declined/error**, the app surfaces the reason and lets the merchant retry
   (same handling the simulator already has).

---

## 4. Money flow & settlement

Authorization ≠ money in the bank. The real sequence:

1. **Authorize** — the issuer approves the amount at tap time (a hold).
2. **Capture** — the transaction is captured (immediately for a normal sale).
3. **Settle** — the provider batches captured transactions and **pays out to the
   merchant's bank account**, net of fees, on a schedule (typically next business
   day or T+2 — confirm with the provider).
4. **Fees** — a per-transaction merchant discount rate (MDR) is deducted by the
   provider.

So the app's `transactions` row is recorded at approval, but the corresponding
**funds arrive later** via settlement. The provider dashboard is the financial
source of truth; the app's ledger is for in-app UX.

---

## 5. Error, decline & edge handling

The real world adds outcomes the simulator never produces. Each maps to a
`ChargeResult` the UI already knows how to show:

| Situation | Result | UX |
|-----------|--------|----|
| Issuer declines (funds/limits/fraud) | `declined` + `declineReason` | Show reason, offer retry |
| Card removed too early / bad read | `error` | "Tap again" |
| Wrong PIN | `declined` (or SDK retry) | Per SDK's PIN retry policy |
| No connectivity | `error` (authorization needs online) | Prompt to reconnect and retry |
| Merchant cancels before tap | `cancelled` | Return to keypad |

Recommended additions when going live (small, contained):
- A visible **decline/error state** on the tap screen (today it silently returns
  to "waiting").
- **Idempotency**: pass a unique `reference` per attempt so a retry can't
  double-charge.

---

## 6. Refunds, voids & reversals (future capability)

Real payments imply the ability to give money back:

- **Void/reversal** — cancel an authorization before settlement.
- **Refund** — return funds after settlement (a separate SDK call).

These aren't built yet. When added:
- Expose them on `PaymentTerminal` (e.g. `refund(reference, amount)`).
- Record them in the ledger. **Schema note:** the `transactions.kind` check
  constraint already allows `refund` alongside `sale` and `split_incoming`, so a
  refund is a negative-amount row of that kind (`backend/app/models.py`).

---

## 7. Split collection with a real terminal

The personal "friend taps to pay their share" flow becomes real the same way — by
treating it as **card acceptance**, not a person-to-person transfer:

- The collecting user acts as the **acceptor** (their phone is the terminal); the
  friend's **card or phone wallet is the instrument** that gets charged.
- Each `Repo.payParticipant(...)` would run a real `terminal.charge()` for that
  friend's share, then record the `split_incoming` transaction exactly as now.
- This requires the **collecting user to be onboarded as a merchant** with the
  provider. A true consumer-to-consumer money transfer (no merchant) is a
  different, licence-heavy rail and is **not** what the SDK provides.

So: the split UX stays identical; under the hood each share is a small
card-present sale into the collector's account.

---

## 8. What stays the same (the payoff of the abstraction)

- **UI** — keypad, tap screen, collecting screen, receipts: unchanged.
- **`Repo` / ledger** — still one `transactions` row per payment (written by the
  Flask API to PostgreSQL); Activity,
  receipts, and "today's sales" all keep working.
- **`ChargeResult` contract** — the SDK result is mapped into it; everything that
  consumes a result (receipt fields, `recordSale`) is untouched.
- **Selecting the terminal** — one line in `AppState`:
  `MockTerminal()` → `HaloDotTerminal()` (behind config, so sandbox vs prod is a
  build flag).

---

## 9. Environments & security

- Keep **sandbox** and **production** provider credentials separate, selected the
  same way as the API base URL (`--dart-define-from-file=env/…`).
- Develop and test against the provider **sandbox** (test cards, no real money)
  before switching to production credentials.
- Credentials live in secure/build-time config, never in source control.
- The certified SDK keeps card data and PCI scope inside its secure component;
  the app only ever handles the **masked** result.

---

## 10. Integration checklist (maps to existing stubs)

- [ ] Onboard with provider; obtain SDK + sandbox credentials.
- [ ] Add SDK (Flutter package or Android AAR + platform channel).
- [ ] Implement `PaymentTerminal.init()` — SDK initialize + attestation.
- [ ] Implement `charge()` — start transaction, handle tap/PIN/processing
      callbacks, map to `ChargeResult`.
- [ ] Add NFC permission/feature + minSdk to `AndroidManifest.xml` per SDK docs.
- [ ] Wire credentials via `--dart-define` (sandbox/prod).
- [ ] Switch the default terminal in `AppState` from `MockTerminal` to the real
      one (config-gated).
- [ ] Test on a physical NFC phone against the sandbox (approve, decline, PIN,
      cancel, no-network).
- [ ] Add a visible decline/error state + idempotent `reference` per attempt.
- [ ] (Later) refunds/voids + `refund` transaction kind.
