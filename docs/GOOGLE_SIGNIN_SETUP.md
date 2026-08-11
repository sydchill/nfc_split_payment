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

> To check what a built APK is actually signed with (the value that must be
> registered), run:
> `apksigner verify --print-certs build/app/outputs/flutter-apk/app-debug.apk`
>
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

## Browser fallback (devices with no Google account)

The native picker can only offer accounts already added to the phone. When there
are none, the app falls back to signing in through the system browser, where any
Google account works without adding it to the device.

```
system browser → accounts.google.com   (user signs in)
               ← com.example.split_nfc_payment:/oauth2redirect?code=...
app            → oauth2.googleapis.com/token  { code, code_verifier }
               ← { id_token }  → same POST /api/auth/google as the native flow
```

It's the OAuth authorization-code flow with **PKCE**, so no client secret is
needed or stored. The app never sees a Google password — the sign-in happens on
Google's own page.

No plugin is involved: `MainActivity.kt` opens the browser and receives the
redirect (`launchMode="singleTop"` → `onNewIntent`), and `lib/oauth_browser.dart`
bridges that over a method channel. The `flutter_web_auth_2` plugin did this
originally but applies the Kotlin Gradle Plugin, which future Flutter versions
refuse to build, and no fixed release exists as of 5.0.3.

> **Underscores.** `com.example.split_nfc_payment` is not a legal URI *scheme* —
> RFC 3986 allows only letters, digits, `+`, `-` and `.`. Android accepts it and
> routes the redirect correctly, but `Uri.parse` throws on it, so the redirect's
> query is read without full URI parsing. Keep that in mind if you touch
> `GoogleWebSignInService.queryOf`.
>
> The package also still carries the default `com.example.` prefix, which the
> Play Store rejects. Renaming it before release means updating the Android
> OAuth client, this redirect scheme, and the manifest intent-filter together.

To enable it, paste your **Android** OAuth client id (the one created in step 3b)
into `mobile/env/dev.json`:

```json
"GOOGLE_ANDROID_CLIENT_ID": "1234567890-android.apps.googleusercontent.com"
```

and **append it** to the backend's client id list, comma-separated — tokens from
this flow carry the Android client as their audience, not the web one:

```
GOOGLE_CLIENT_ID=<web-client-id>,<android-client-id>
```

Leave `GOOGLE_ANDROID_CLIENT_ID` empty and the fallback is simply off: the app
tells the user to add a Google account instead, exactly as before.

> The redirect scheme is the package name (`com.example.split_nfc_payment`) —
> Google requires that of an Android client, and it's declared as an
> intent-filter in `AndroidManifest.xml`. If you ever rename the package, change
> both.

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
| Picker opens, spins, closes — app shows **nothing** | The Android OAuth client is missing from the project that owns the Web client id. Play Services reports this as a *cancel*, so the app stays silent. Confirm with `adb logcat -s Auth.Api.Credentials`: look for `status=UNREGISTERED_ON_API_CONSOLE` followed by `Account reauth failed` |
| Works in debug, fails after release build | Release keystore SHA-1 not registered as a second Android client |

## Emulator note

Google Sign-In needs **Google Play Services** on the device. Use an emulator
image with the Play Store (the current `sdk gphone` image qualifies) and make sure
a Google account is added under Android Settings, or the picker will be empty.
