# Patela

*Tap. Split. Settle.* — a bill-splitter and phone-as-card-machine (SoftPOS) app
for South Africa, by Patela Inc. Amounts are in South African Rand (ZAR).

Two things in one product:

- **Personal** — pay a bill, then collect each friend's share by tap.
- **Business** — accept a customer's tapped card or phone wallet, no terminal
  hardware.

## Repository layout

This is a single git repo with the client and server in separate folders:

```
patela/
├── mobile/     Flutter app (Android-first) — UI + local state, thin client
├── backend/    Flask API — all business logic, SQLAlchemy models, PostgreSQL
├── docs/       Product documentation (use cases, transaction flows)
└── SOFTPOS_PROVIDERS.md   Real-payment provider research (Halo Dot / Lipa)
```

| Folder | Stack | Read next |
|--------|-------|-----------|
| [`mobile/`](mobile) | Flutter, Dart | `mobile/lib/` — `state.dart`, `repo.dart`, `payments.dart` |
| [`backend/`](backend) | Flask, SQLAlchemy, PostgreSQL | [`backend/README.md`](backend/README.md) |

## Architecture

```
mobile (Flutter)  ──HTTP/JSON + JWT──►  backend (Flask)  ──SQLAlchemy──►  PostgreSQL
     UI + state                      all business rules        auth. + app. schemas
```

The app holds no database credentials and enforces no rules: the API validates
input, scopes every query to the signed-in user, does the split maths, writes the
ledger, and rolls up sales. Two seams keep it swappable:

- **`Repo`** (`mobile/lib/repo.dart`) — `ApiRepo` in production, `InMemoryRepo`
  for tests/offline.
- **`PaymentTerminal`** (`mobile/lib/payments.dart`) — `MockTerminal` today; a
  certified SoftPOS SDK drops in here to make taps real.

## Quick start

**1. Backend** (needs PostgreSQL running):

```bash
cd backend
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
copy .env.example .env          # then set DATABASE_URL + secrets
.venv\Scripts\python.exe -m flask --app run init-db
.venv\Scripts\python.exe run.py
```

**2. Mobile** (in another terminal):

```bash
cd mobile
flutter pub get
flutter run --dart-define-from-file=env/dev.json
```

`env/dev.json` points the app at the API — `http://10.0.2.2:5000` reaches your
machine from an Android emulator; use your LAN IP for a physical phone.

## Tests

```bash
cd backend && .venv\Scripts\python.exe -m pytest tests -q    # 20 API tests
cd mobile  && flutter test                                    # 8 widget/golden tests
```

## Status

| Area | State |
|------|-------|
| UI, both account modes | Working |
| Auth (email/password, JWT, sessions persist) | Working |
| Data persistence (friends, splits, ledger, sales) | Working |
| The card tap itself | **Simulated** — needs a certified SoftPOS SDK; see [`SOFTPOS_PROVIDERS.md`](SOFTPOS_PROVIDERS.md) |
| Google sign-in | Not implemented on the Flask backend yet |
| iOS | Code is portable; only run on Android so far |

See [`docs/USE_CASES.md`](docs/USE_CASES.md) for what the app does,
[`docs/TRANSACTIONS.md`](docs/TRANSACTIONS.md) for how a payment flows through
the stack today, and [`docs/TRANSACTIONS_WITH_SDK.md`](docs/TRANSACTIONS_WITH_SDK.md)
for how it will work with real card acceptance.
