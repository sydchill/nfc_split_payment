# Patela — How Transactions Are Handled

This document describes how money-movement flows are modelled, processed, and
stored in Patela — for both **business sales** (a merchant charging a customer)
and **split collections** (a personal user collecting a friend's share).

> **Honesty note up front.** Today the tap/card-read is **simulated**
> (`MockTerminal`) — no real money moves and no real NFC card is read. What *is*
> real is everything around it: authentication, the saved bills/friends, and the
> **transaction ledger** written by the Flask API to PostgreSQL. The design isolates the payment
> step so a **certified SoftPOS SDK** (Halo Dot / Lipa Payments) can replace the
> simulator without changing anything else. See `SOFTPOS_PROVIDERS.md`.

---

## 1. Architecture at a glance

```
UI (screens)
   │  user taps a button
   ▼
AppState  (lib/state.dart)        ← orchestrates the flow, holds state
   │                 │
   │                 └────────────► PaymentTerminal (lib/payments.dart)
   │                                   • MockTerminal   (simulated, active)
   │                                   • HaloDot/Lipa   (real SoftPOS SDK, later)
   │  returns a ChargeResult ◄────────┘
   ▼
Repo  (lib/repo.dart)             ← persists the outcome
   • ApiRepo       → HTTP/JSON → Flask API → SQLAlchemy → PostgreSQL
   • InMemoryRepo  → tests / offline demo
```

The Flask backend (`backend/`) owns the rules: it validates input, scopes every
query to the authenticated user, computes split totals, marks shares paid, writes
the ledger, and rolls up sales. The app never holds database credentials.

Two independent abstractions do the work:

- **`PaymentTerminal`** — *accepts* the payment (the tap). Swappable: mock now,
  certified SDK later.
- **`Repo`** — *records* the payment and reads history. Swappable: the Flask API
  in production, in-memory for tests.

`AppState` coordinates them; the UI never talks to the API or a terminal
directly.

---

## 2. The transaction ledger

Every completed payment — from either flow — becomes one row in a single
**`transactions`** table. That table is the source of truth for the Activity
feed, receipts, and the business "today's sales" figures.

| Column | Meaning |
|--------|---------|
| `id` | Primary key |
| `owner_id` | The user who owns the row (FK to `users`) |
| `kind` | `sale` (business took a payment) or `split_incoming` (a friend paid you back) |
| `title` | Display title — "Card sale" or the friend's name |
| `subtitle` | Context — e.g. "Fig & Vine · phone tap" or "Bill split · The Fig Tree" |
| `amount` | Amount in ZAR (positive = money in) |
| `method` | `card` \| `apple_pay` \| `google_pay` |
| `reference` | Receipt/acquirer reference, e.g. `TXN-7750` |
| `bill_id` | Links a `split_incoming` row back to its bill (nullable) |
| `created_at` | Timestamp |

Supporting tables: **`friends`** (a personal user's saved contacts),
**`bills`** (a split: merchant + total + settled flag), and
**`bill_participants`** (each friend's share + paid state). Full definitions live
in `backend/app/models.py`.

**Schema separation.** Identity and domain data live in separate PostgreSQL
schemas: credentials in **`auth`** (`auth.users`) and everything else in
**`app`** (`app.friends`, `app.bills`, `app.bill_participants`,
`app.transactions`). Each `app` row is owned by an `auth.users.id`.

---

## 3. Flow A — Business sale (merchant charges a customer)

**Screens:** keypad → tap-to-pay → approved receipt.

```
Merchant enters amount ──► Charge ──► terminal.charge(ChargeRequest)
                                          │  (MockTerminal: ~1.5s, returns approved
                                          │   with method, masked PAN, auth code;
                                          │   real SDK: reads the EMV card over NFC)
                                          ▼
                                     ChargeResult
                                          │  approved?
                                          ▼
                              Repo.recordSale(...)  ──► INSERT transactions (kind='sale')
                                          │
                                          ▼
                              today's sales total/count updated ──► Approved receipt
```

**Step by step (`AppState.sim` in `mobile/lib/state.dart`):**
1. The keypad builds an amount in cents (`chargeCents`).
2. *Charge* moves to the tap screen; the merchant chooses "Tap a card" or
   "Tap a phone" (the mock's way of picking the instrument — a real terminal
   detects it automatically).
3. `terminal.charge(ChargeRequest(amountCents, reference: 'TXN-…', currency: 'ZAR'))`
   runs. The mock waits ~1.5s and returns an **approved** `ChargeResult`; a real
   SDK performs the actual contactless read + acquirer authorization.
4. On approval, `Repo.recordSale(...)` inserts a `transactions` row
   (`kind = 'sale'`).
5. The in-memory "today's sales" summary is bumped and the **Approved** receipt
   shows `method`, masked card (`chargeMaskedPan`), and `reference` — all read
   from the `ChargeResult`.
6. A decline/error returns the merchant to the tap screen to retry.

---

## 4. Flow B — Split collection (friend pays back their share)

**Screens:** split setup → collecting → done.

```
Setup: merchant + total + friends/shares ──► Start collecting
        └► Repo.createBill()  ──► INSERT bills + bill_participants

Per friend on the Collecting screen:
   Tap to pay ──► (pay sheet: confirm) ──► Repo.payParticipant()
                                              ├─ UPDATE bill_participant → paid
                                              └─ INSERT transactions (kind='split_incoming')
   when every participant.paid ──► Repo.settleBill() ──► bills.settled_at set ──► Done
```

**Step by step:**
1. **Setup** — the user enters the merchant and total and adds friends. Adding a
   new friend also **saves them** (`Repo.addFriend` → `friends` table) for reuse.
   Shares are set manually or via **Split evenly**; the user's own share is the
   remainder of the total.
2. **Start collecting** — `Repo.createBill(merchant, total, participants)` inserts
   the `bills` row and one `bill_participants` row per friend.
3. **Collect** — for each friend, *Tap to pay* runs the tap animation and pay
   sheet, then `Repo.payParticipant(...)`:
   - marks that participant **paid** (with method + timestamp), and
   - inserts a `transactions` row (`kind = 'split_incoming'`, linked via
     `bill_id`).
4. **Settle** — once all participants are paid, `Repo.settleBill(billId)` stamps
   `bills.settled_at`, and the **Done** summary is shown.
5. Progress (ring, "X of N paid", collected-of-total) is derived live from the
   participants' paid state.

---

## 5. The payment abstraction (`PaymentTerminal`)

Defined in `mobile/lib/payments.dart`. This is the single seam between the app and the
outside payment world.

**Request in:**

```
ChargeRequest { amountCents, reference, currency = 'ZAR' }
```

**Result out:**

```
ChargeResult {
  status,        // approved | declined | cancelled | error
  methodDb,      // 'card' | 'apple_pay' | 'google_pay'  (how it's stored)
  scheme,        // 'Visa' | 'Mastercard' | …
  maskedPan,     // '•••• 4291'  (for the receipt)
  reference,     // acquirer/receipt reference
  authCode,      // authorization code
  declineReason, // set when not approved
}
```

**Implementations:**

| Implementation | Purpose | Behaviour |
|----------------|---------|-----------|
| `MockTerminal` | Active today; demos & tests | Waits ~1.5s, returns an approved result with a fake masked card. **No money, no NFC.** |
| `HaloDotTerminal` (stub) | Real SoftPOS via a certified SDK | Currently throws "not integrated"; the documented place the SDK is wired. Would perform a real NFC EMV read, talk to the acquirer, and map the SDK's result to `ChargeResult`. |

Switching to real payments is a **one-line change** in `AppState` (inject the
real terminal instead of `MockTerminal`) plus filling in that terminal's
`init()`/`charge()` against the provider SDK. Nothing in the UI, `Repo`, or the
ledger changes.

---

## 6. Persistence & security

- **Backend:** a Flask API (`backend/`) with SQLAlchemy models on **PostgreSQL**.
  All business logic lives in `backend/app/services.py`.
- **Auth:** email + password with PBKDF2 hashing, JWT access tokens (60 min) and
  refresh tokens (30 days). Logout revokes the presented token. The Flutter app
  stores tokens with `shared_preferences` so sessions survive restarts.
- **Ownership:** enforced server-side — every query filters by the authenticated
  user, and cross-user access returns 404.
- **Idempotency:** recording a sale is idempotent on `reference`, so a retry
  can't double-charge.
- **Testability:** `InMemoryRepo` mirrors `ApiRepo` so the app's flows run in
  widget tests with no backend; the API itself has its own pytest suite
  (`backend/tests/test_api.py`).


---

## 7. What "real" will and won't mean

- **Business card acceptance is the realistic real-money path.** With a certified
  SoftPOS SDK, the merchant's phone becomes the terminal and the customer's
  card/phone is the instrument; funds settle to the merchant's bank via the
  provider's acquiring. It is **not** a phone-to-phone transfer.
- **Friend repayment (P2P) staying real is much harder** — moving money between
  individuals typically needs licensing or a dedicated payout provider, so that
  flow remains a UX demo for now.
- **Certification is mandatory** for real card reading (PCI MPoC / Visa & Mastercard
  Tap-to-Phone). The app cannot read cards directly by design; the provider's
  certified SDK does, and it owns compliance and settlement.

---

## 8. Quick reference — what gets written when

| Action | Table(s) written | `kind` |
|--------|------------------|--------|
| Business charge approved | `transactions` | `sale` |
| Start a split | `bills`, `bill_participants` | — |
| Add a friend | `friends` | — |
| Friend pays their share | `bill_participants` (update), `transactions` | `split_incoming` |
| All shares paid | `bills` (`settled_at`) | — |
| Sign up | `profiles` (via DB trigger) | — |
