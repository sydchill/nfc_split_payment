# Google Sign-In — setup

The code is done on both sides. What remains is creating **OAuth credentials in
your own Google Cloud project** and pasting two values into config. Until you do,
the Google buttons show a clear "not configured" message and email/password
keeps working.

## How it works

```
Flutter (google_sign_in v7)
  native account picker → Google ID token (a JWT signed by Google)
        │  POST /api/auth/google  { id_token, mode }
        ▼
Flask  verifies signature + audience + expiry against Google's public keys
       → find-or-create the account → returns Patela's own JWT tokens
```

The backend **never trusts the token's contents until verification passes** —
that's what proves the client really signed in with Google instead of inventing a
payload. The app never sees a Google password.

## Values you'll need from this project

| Thing | Value |
|-------|-------|
| Android package name | `com.example.split_nfc_payment` |
| Debug signing SHA-1 | `C6:EA:DB:66:1A:0E:3A:3A:48:3F:CA:2E:04:32:E7:0A:73:D4:A2:2B` |

> That SHA-1 is the **debug** keystore on this machine — fine for development.
> A release build is signed with a different key, so you must add its SHA-1 as a
> second Android OAuth client before shipping. Get it with:
> `keytool -list -v -keystore <your-release.jks> -alias <alias>`

## Steps

### 1. Create a Google Cloud project

<https://console.cloud.google.com> → **New Project** (e.g. "Patela").

### 2. Configure the OAuth consent screen

**APIs & Services → OAuth consent screen**

- User type: **External**
- App name: `Patela`, plus your support email
- Scopes: the defaults (`email`, `profile`, `openid`) are all this needs
- While in **Testing** mode, add your own Google account under **Test users** —
  otherwise sign-in is blocked for everyone else.

### 3. Create TWO OAuth client IDs

**APIs & Services → Credentials → Create credentials → OAuth client ID.**
Both are required — this trips people up:

**a) Web application** — this is the *audience* of the ID token.

- Name: `Patela backend`
- No redirect URIs needed for native sign-in
- **Copy the Client ID** → this is the value both sides use

**b) Android**

- Name: `Patela Android (debug)`
- Package name: `com.example.split_nfc_payment`
- SHA-1: `C6:EA:DB:66:1A:0E:3A:3A:48:3F:CA:2E:04:32:E7:0A:73:D4:A2:2B`
- You don't paste this one anywhere — it authorises the app to request tokens.

### 4. Paste the Web client id in both places

**Backend** — `backend/.env`:

```
GOOGLE_CLIENT_ID=1234567890-abcdef.apps.googleusercontent.com
```

**Mobile** — `mobile/env/dev.json`:

```json
{
  "APP_ENV": "dev",
  "API_BASE_URL": "http://10.0.2.2:5000",
  "GOOGLE_SERVER_CLIENT_ID": "1234567890-abcdef.apps.googleusercontent.com"
}
```

They must be the **same** value: the app requests a token for that audience and
the backend only accepts tokens for it.

### 5. Restart both

```bash
cd backend && .venv\Scripts\python.exe run.py
cd mobile  && flutter run --dart-define-from-file=env/dev.json
```

## Account behaviour

| Situation | Result |
|-----------|--------|
| New Google account | Account created with the mode picked on the choose-type screen; no password is set |
| Signing in again with Google | Same account reused (no duplicate) |
| Google email matches an existing email/password account | The accounts are **linked** — you can then use either method |
| Google-only account tries password login | Rejected (there is no password) |
| Google email not verified | Rejected |

## Troubleshooting

| Symptom | Cause |
|---------|-------|
| "Google sign-in is not configured on the server" (503) | `GOOGLE_CLIENT_ID` missing from `backend/.env` |
| "Google sign-in is not configured yet" in the app | `GOOGLE_SERVER_CLIENT_ID` missing from `mobile/env/dev.json` |
| "Google did not return an ID token" | You used the **Android** client id instead of the **Web** one |
| `ApiException 401: invalid token` | The two client ids don't match, or the token expired |
| Sign-in dialog closes instantly, error 10 | The Android OAuth client's package name / SHA-1 doesn't match the build |
| Works in debug, fails after release build | Release keystore SHA-1 not registered as a second Android client |

## Emulator note

Google Sign-In needs **Google Play Services** on the device. Use an emulator
image with the Play Store (the current `sdk gphone` image qualifies) and make sure
a Google account is added under Android Settings, or the picker will be empty.
