# Patela API (Flask + PostgreSQL + SQLAlchemy)

The backend owns **all business logic**: accounts, split maths, marking shares
paid, the transaction ledger, and sales rollups. The Flutter app is a thin client
that calls this API — it holds no database credentials and enforces no rules.

```
Flutter app ──HTTP/JSON──►  Flask  ──SQLAlchemy──►  PostgreSQL
              (JWT auth)    services.py = rules      models.py = tables
```

## Schema separation

Identity is isolated from domain data in two PostgreSQL schemas:

| Schema | Tables | Contains |
|--------|--------|----------|
| **`auth`** | `users` | Credentials (password hashes), email, account mode. Nothing else. |
| **`app`** | `friends`, `bills`, `bill_participants`, `transactions` | Business-logic data; every row is owned by an `auth.users.id`. |

Why: password hashes stay in one place, domain migrations can never touch the
credentials table, and you can later grant an analytics/reporting role access to
`app` only. Schema names are constants in `app/models.py` (`AUTH_SCHEMA`,
`APP_SCHEMA`).

`flask --app run init-db` creates both schemas before the tables. Tests run on
SQLite too — `attach_sqlite_schemas()` emulates the schemas with `ATTACH
DATABASE`, so the same models work either way.

## Layout

| Path | Purpose |
|------|---------|
| `app/__init__.py` | App factory, error handlers, JWT hooks, `init-db` CLI |
| `app/config.py` | Env-driven config (`Config`, `TestConfig`) |
| `app/models.py` | SQLAlchemy models: `User`, `Friend`, `Bill`, `BillParticipant`, `Transaction` |
| `app/services.py` | **All business logic** — validation, ownership, split maths, ledger |
| `app/routes/auth.py` | `/api/auth/*` — register, login, refresh, me, logout |
| `app/routes/api.py` | `/api/*` — friends, bills, transactions, sales |
| `tests/test_api.py` | 20 end-to-end tests (auth, isolation, splits, sales) |

## Setup

### 1. PostgreSQL

Install Postgres (or run it in Docker), then create the database and role:

```bash
docker run --name patela-db -e POSTGRES_PASSWORD=patela -e POSTGRES_USER=patela -e POSTGRES_DB=patela -p 5432:5432 -d postgres:16
```

Or with a local install:

```sql
CREATE USER patela WITH PASSWORD 'patela';
CREATE DATABASE patela OWNER patela;
```

### 2. Python environment

```bash
cd backend
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
```

### 3. Configure

```bash
copy .env.example .env
```

Then edit `.env`: set `DATABASE_URL` and generate real secrets with
`python -c "import secrets; print(secrets.token_urlsafe(48))"`.

### 4. Create tables

```bash
.venv\Scripts\python.exe -m flask --app run init-db
```

For versioned schema changes use migrations instead:

```bash
.venv\Scripts\python.exe -m flask --app run db init      # once
.venv\Scripts\python.exe -m flask --app run db migrate -m "message"
.venv\Scripts\python.exe -m flask --app run db upgrade
```

### 5. Run

```bash
.venv\Scripts\python.exe run.py
```

Listens on `0.0.0.0:5000` so an emulator or phone on your LAN can reach it.

> `run.py` uses Flask's built-in dev server — fine for development, never for
> production (single-threaded, no hardening).

### 6. Run in production mode

`requirements.txt` installs the right WSGI server per platform, because
**gunicorn does not support Windows** (it needs POSIX `fcntl`):

| Platform | Server | Command |
|----------|--------|---------|
| Linux / macOS (deployment) | gunicorn | `gunicorn --bind 0.0.0.0:5000 --workers 4 "run:app"` |
| Windows (local prod-mode testing) | waitress | `.venv\Scripts\python.exe -m waitress --listen=0.0.0.0:5000 run:app` |

Worker count rule of thumb: `(2 × CPU cores) + 1`. Put it behind nginx/Caddy for
TLS, and remember the in-process token blocklist needs replacing with Redis once
you run more than one worker (see *Before production*).

## Tests

```bash
.venv\Scripts\python.exe -m pytest tests -q
```

Tests default to in-memory SQLite for speed; set `TEST_DATABASE_URL` to a
throwaway Postgres database to test against the real engine.

## Endpoints

All domain routes require `Authorization: Bearer <access_token>`.

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/health` | Liveness check (no auth) |
| POST | `/api/auth/register` | Create account -> tokens + user |
| POST | `/api/auth/login` | Sign in -> tokens + user |
| POST | `/api/auth/refresh` | New access token (send the refresh token) |
| GET | `/api/auth/me` | Current account |
| PATCH | `/api/auth/me` | Update name / business details / mode |
| POST | `/api/auth/logout` | Revoke the current access token |
| GET | `/api/friends` | List saved friends |
| POST | `/api/friends` | Add a friend |
| DELETE | `/api/friends/<id>` | Remove a friend |
| GET | `/api/bills` | Recent splits |
| POST | `/api/bills` | Create a split (validates shares <= total) |
| GET | `/api/bills/<id>` | One split with participants + derived totals |
| POST | `/api/bills/<id>/participants/<pid>/pay` | Mark a share paid, write ledger entry, auto-settle |
| POST | `/api/bills/<id>/settle` | Force-settle a split |
| GET | `/api/transactions` | Activity ledger (newest first) |
| POST | `/api/transactions/sale` | Record a business sale (idempotent on `reference`) |
| GET | `/api/sales/today` | Today's total / count / average |

## Security model

- **Passwords** hashed with PBKDF2 (Werkzeug); never stored or returned in clear.
- **JWT** access tokens (default 60 min) + refresh tokens (30 days). Logout adds
  the token's `jti` to a revocation set.
- **Ownership** is enforced in `services.py`: every query is filtered by the
  authenticated user, and cross-user access returns 404. This replaces the
  database-level row policies used by the previous backend.
- **Idempotency** on `POST /api/transactions/sale` via `reference`, so a retried
  charge can't double-record.
- **Secrets** come from the environment only; `.env` must never be committed.

### Before production

- Swap the in-process token blocklist (`app/routes/blocklist.py`) for Redis or a
  `revoked_tokens` table so revocation works across workers.
- Run behind gunicorn/uWSGI + TLS; restrict `CORS_ORIGINS`.
- Add rate limiting on the auth routes.

## Connecting the app

Point the Flutter client at this API with `mobile/env/dev.json`:

```json
{ "APP_ENV": "dev", "API_BASE_URL": "http://10.0.2.2:5000" }
```

`10.0.2.2` is how an Android emulator reaches your development machine; use your
LAN IP for a physical phone. Then, from the `mobile/` folder:

```bash
flutter run --dart-define-from-file=env/dev.json
```
