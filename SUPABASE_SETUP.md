# Tandem — Supabase auth setup

The app is wired for real email/password **and** Google sign-in, with session
persistence and logout. To make it live you need to do four things once. Steps
1–2 are required for email/password; steps 3–4 add Google.

## 1. Create the project & get your keys

1. Go to <https://supabase.com> → sign in → **New project**. Pick a name
   (e.g. `tandem`), a strong database password, and a region near you. Free tier
   is fine. Wait ~2 minutes for it to provision.
2. In the dashboard: **Project Settings → API**. Copy:
   - **Project URL** (e.g. `https://abcd1234.supabase.co`)
   - the **anon / public** key (newer dashboards call it the *publishable* key;
     it may start with `sb_publishable_`). **Not** the `service_role` key.
3. Paste both into [`lib/supabase_config.dart`](lib/supabase_config.dart):
   ```dart
   static const String _urlLiteral = 'https://abcd1234.supabase.co';
   static const String _anonKeyLiteral = 'sb_publishable_xxx_or_the_anon_jwt';
   ```

## 2. Create the database tables

1. Dashboard → **SQL Editor → New query**.
2. Paste the entire contents of [`supabase/schema.sql`](supabase/schema.sql) and
   press **Run**. This creates the `profiles` table (one row per user, filled
   from sign-up details) with Row Level Security so each user only sees their own.
3. For easy testing, disable the confirmation email: **Authentication →
   Sign In / Providers → Email → turn OFF "Confirm email"**. (With it on, new
   users must click a link in their inbox before they can sign in — the app
   handles that case by telling them to check their email, but it slows testing.)

**At this point email/password sign-up, sign-in, and logout fully work.** Run:
```
D:\flutter\bin\flutter.bat run
```

## 3. Add Google sign-in (optional)

Google needs an OAuth client from Google Cloud, entered into Supabase:

1. **Google Cloud Console** (<https://console.cloud.google.com>) → create/select
   a project → **APIs & Services → Credentials → Create credentials → OAuth
   client ID → Web application**.
2. Under **Authorized redirect URIs** add your Supabase callback:
   `https://abcd1234.supabase.co/auth/v1/callback`
   (Project Settings → API shows your project ref for the subdomain.)
3. Copy the **Client ID** and **Client secret**.
4. Supabase dashboard → **Authentication → Sign In / Providers → Google** →
   enable it, paste the Client ID + secret, **Save**.

## 4. Register the app's redirect deep link

So the browser can hand control back to the app after Google login:

1. Supabase dashboard → **Authentication → URL Configuration → Redirect URLs**
   → **Add URL**: `io.supabase.tandem://login-callback`
2. This already matches `SupabaseConfig.oauthRedirect` in code and the
   `<intent-filter>` in
   [`android/app/src/main/AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml),
   so no code change is needed.

## Notes

- **Keys are safe in the client.** The anon/publishable key is designed to ship
  in apps; RLS is what protects data. Never put the `service_role` key here.
- **Account mode** (personal vs business) is chosen at sign-up and stored on the
  user. On login the app reads it back and routes to the right home — the
  Personal/Business toggle on the sign-in screen is a leftover from the design
  and no longer decides where you land.
- **iOS**: the same code works; you'd add a matching URL scheme in
  `ios/Runner/Info.plist` when you build on a Mac.
