# Patela — Use Cases

*"Tap. Split. Settle."* — a bill-splitter and phone-based card reader (SoftPOS)
for South Africa, by Patela Inc. Built with Flutter (Android-first) against its
own **Flask** API (`backend/`) — email/password auth with JWT, business logic in
Python, data in **PostgreSQL** via SQLAlchemy. All amounts are in South African
Rand (ZAR).

Patela has **two account modes**, chosen at sign-up and stored on the account:

- **Personal** — split a bill with friends and collect what they owe by having
  them tap their phone or card.
- **Business** — accept payments from customers by having them tap a card or
  phone on *your* device (the phone acts as the card machine).

> **Status legend used below**
> ✅ *Live* — works end-to-end today · 🟡 *Simulated* — the flow runs and records
> data, but the tap/payment is a demo (no real money, no real NFC) · ⏳ *Planned* —
> designed for but not built yet.

---

## Personas

| Persona | Who | Primary goal |
|---------|-----|--------------|
| **Alex (Personal)** | An individual out with friends | Pay a bill up front, then collect each friend's share |
| **Fig & Vine (Business)** | A café / small merchant | Accept card & phone-wallet payments without buying a Yoco-style terminal |

---

## A. Onboarding & account

### A1. Create a personal account ✅
- **Actor:** new personal user
- **Steps:** Welcome → *Get started* → choose **Personal** → enter name, email,
  password → *Create account*.
- **Result:** account created via `POST /api/auth/register`; the account's `mode`
  and name are stored; the user lands on the personal home screen.

### A2. Create a business account ✅
- **Actor:** new merchant
- **Steps:** Welcome → *Get started* → choose **Business** → enter business name,
  category, owner name, email, password → *Create account*.
- **Result:** business account created; lands on the business home screen.

### A3. Sign in / sign out ✅
- Returning users sign in with email + password. Sessions **persist across app
  restarts** (relaunching returns you to your home screen, not onboarding).
- The logout button (top-right of either home) ends the session and returns to
  onboarding.

### A4. Continue with Google ⏳
- The "Continue with Google" button exists in the UI but is not wired to the
  Flask backend yet (it shows a "coming soon" message), so email/password is the
  live path. Adding it means an OAuth flow plus a `/api/auth/google` endpoint.

---

## B. Personal — splitting & collecting

### B1. Split a bill ✅ (collection tap is 🟡)
- **Actor:** personal user who paid a shared bill
- **Goal:** recover each friend's share
- **Steps:**
  1. Home → *Split a bill*.
  2. Enter **where you paid** (merchant) and the **total**.
  3. **Add the friends** splitting it (pick a saved friend or add a new one).
  4. Set each person's share manually, or tap **Split evenly**. Your own share is
     whatever's left after the friends' shares.
  5. *Start collecting* — the bill and each friend's share are saved.
- **Then collect (per friend):** on the Collecting screen, tap **Tap to pay** for
  a friend → the pay sheet appears → confirm → that share is marked paid and a
  transaction is recorded. A progress ring and "X of N paid" track it.
  When everyone has paid, the bill is **settled** and a summary is shown.
- **Real vs demo:** the split math, the saved bill, and the recorded payments are
  real data; the **tap itself is simulated** (no real money moves yet).

### B2. Manage friends ✅
- Friends are **saved to your account** the first time you add them and can be
  **reused** in future splits (pick from your friends list instead of retyping).
- Each friend gets a consistent avatar colour.

### B3. Review activity & receipts ✅
- The **Activity** tab lists everything you've collected, newest first.
- Tapping an item opens a **receipt** (amount, date/time, method, reference).
- The personal home shows a **Recent activity** preview; a brand-new account
  shows a friendly empty state.

---

## C. Business — accepting payments

### C1. Take a payment ✅ (the tap is 🟡)
- **Actor:** merchant
- **Goal:** charge a customer
- **Steps:**
  1. Home → *Take a payment*.
  2. Enter the amount on the keypad.
  3. *Charge* → the tap screen appears ("Ready — tap a card or phone").
  4. The customer taps a **card** or **phone wallet** → the charge is processed →
     an **Approved** receipt shows the method, masked card, and reference.
- **Result:** an approved sale is recorded and today's totals update.
- **Real vs demo:** the sale is really recorded; the **card read is simulated**
  today (a certified SoftPOS SDK replaces this — see `SOFTPOS_PROVIDERS.md`).

### C2. See the day's takings ✅
- The business home shows **Today's sales**: total, number of sales, and average
  ticket — all computed from recorded sales.

### C3. Review sales & receipts ✅
- **Recent sales** on the home and the full **Activity** tab list recorded sales;
  tapping one opens its receipt.

---

## D. Explicitly out of scope / deferred

| Item | Why |
|------|-----|
| **Real card acceptance (live money)** ⏳ | Requires embedding a certified SoftPOS SDK (Halo Dot / Lipa Payments) + merchant onboarding. The app is architected for it (`PaymentTerminal`), but the tap is simulated until then. |
| **Real friend-to-you repayment (P2P)** ⏳ | Moving money between individuals generally needs money-transmitter licensing or a specialised provider; the split "tap to pay" is a demo of the UX. |
| **Google sign-in** ⏳ | Provider not enabled on the backend yet. |
| **iOS build** ⏳ | Code is portable; only tested/run on Android so far. NFC card acceptance on iOS ("Tap to Pay on iPhone") has its own separate requirements. |

---

## E. How the pieces map to the codebase

| Use case area | Where it lives |
|---------------|----------------|
| Screens / flows | `mobile/lib/screens/` (auth, home, split, business, activity) |
| App state & flow logic | `mobile/lib/state.dart` (`AppState`) |
| Data read/write | `mobile/lib/repo.dart` (`Repo` → `ApiRepo` / `InMemoryRepo`), `mobile/lib/api_client.dart` |
| Payment/tap handling | `mobile/lib/payments.dart` (`PaymentTerminal` → `MockTerminal` / real SDK) |
| Domain types | `mobile/lib/models.dart` |
| Backend (all business logic) | `backend/app/services.py` |
| Database models | `backend/app/models.py` |
| API routes | `backend/app/routes/` |

See **`docs/TRANSACTIONS.md`** for exactly how a payment moves through these
layers and what gets stored.
