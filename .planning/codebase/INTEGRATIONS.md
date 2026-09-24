# External Integrations

**Analysis Date:** 2026-09-24

## APIs & External Services

**Backend-as-a-Service:**
- Supabase - the only active external integration. Provides Postgres database, Auth, and (via config) Storage/Realtime.
  - SDK/Client: `supabase_flutter` (locked `2.17.2`)
  - Auth: credentials supplied via `--dart-define=SUPABASE_URL=...` and `--dart-define=SUPABASE_ANON_KEY=...`, read with `String.fromEnvironment` in `lib/main.dart` and `lib/features/auth/presentation/auth_screens.dart`
  - Client initialized once in `lib/main.dart` (`Supabase.initialize(url:, publishableKey:)`), then accessed globally via `Supabase.instance.client` (see `lib/features/auth/presentation/auth_screens.dart:31`)

**Declared but not integrated:**
- Firebase - `firebase.json` exists at repo root (project id `vetapp-colombia`, app ids for Android/iOS/Web, expects `lib/firebase_options.dart` and `android/app/google-services.json`), but there are **no Firebase packages** in `pubspec.yaml`/`pubspec.lock` and `lib/firebase_options.dart` is absent. Treat this as inactive/vestigial scaffolding, not a live integration.
- Google Sign-In - `AuthRepository.signInWithGoogle()` is declared in `lib/features/auth/domain/repositories/auth_repository.dart` and has a use case wrapper `lib/features/auth/domain/usecases/sign_in_with_google.dart`, but there is no `google_sign_in` package dependency, no implementation of `AuthRepository` in the codebase, and Supabase's local config (`supabase/config.toml`) does not enable any external OAuth provider. This is an aspirational/unimplemented interface only.

## Data Storage

**Databases:**
- Supabase Postgres (cloud-hosted, or local via Supabase CLI/Docker)
  - Connection: implicit through the Supabase client (`SUPABASE_URL` + `SUPABASE_ANON_KEY` dart-defines); no direct Postgres connection string is used by the Flutter app
  - Client: `supabase_flutter`'s `SupabaseClient.from('table').select()/.eq()/.single()` query builder, e.g. `lib/features/auth/data/repositories/supabase_auth_repository.dart:112` querying the `perfiles` table joined to `clinicas`
  - Schema/migrations: maintained by hand in `supabase/schema.sql` (not run through a formal migrations pipeline) - defines tables `clinicas`, `perfiles`, `mascotas`, a `rol_perfil` enum, a `crear_perfil_nuevo_usuario` trigger on `auth.users` insert, and helper SQL functions `mi_perfil()`, `es_veterinario()`, `mi_clinica_id()`
  - Row Level Security (RLS) is enabled on all three tables with explicit `select`/`insert`/`update`/`delete` policies enforcing per-clinic and per-owner isolation (`supabase/schema.sql:99-143`)

**File Storage:**
- Local filesystem only for app assets. Supabase Storage is enabled in the local dev config (`supabase/config.toml` `[storage]` section) but no Storage client calls exist anywhere in `lib/`.

**Caching:**
- None detected. No local cache/DB package (e.g. `shared_preferences`, `hive`, `sqflite`) is a direct dependency; session persistence is handled entirely by `supabase_flutter`'s built-in session storage/restoration (per `README.md`: "La sesión la persiste `supabase_flutter` y se restaura al abrir la app").

## Authentication & Identity

**Auth Provider:**
- Supabase Auth (email/password only, active integration)
  - Sign in: `lib/features/auth/data/repositories/supabase_auth_repository.dart` `signIn()` → `_client.auth.signInWithPassword(...)`
  - Sign up: `signUp()` → `_client.auth.signUp(email:, password:, data: {...})`, passing profile metadata (`nombre`, `telefono`, `rol`, and optional clinic fields) that the Postgres trigger `crear_perfil_nuevo_usuario` consumes server-side to create a `perfiles` row (and a `clinicas` row when `rol = 'VETERINARIO'`)
  - Password reset: `resetPassword()` → `_client.auth.resetPasswordForEmail(...)`; redirect URL must be manually allow-listed in the Supabase dashboard (README: "Authentication > URL Configuration")
  - Email confirmation is required before profile access is granted (README, `supabase/config.toml` `[auth.email] enable_signup = true`)
  - Session state: `_client.auth.onAuthStateChange` stream and `_client.auth.currentSession` (`supabase_auth_repository.dart:32-34`), consumed in `lib/features/auth/presentation/auth_screens.dart` (`AuthGate`)
  - Error translation: Supabase `AuthException` messages are pattern-matched and translated into Spanish user-facing strings in `_messageFor()` (`supabase_auth_repository.dart:134-151`)
  - Authorization model: role-based (`VETERINARIO` vs `CLIENTE`) enforced both client-side (`AuthProfile.esVeterinario` in `supabase_auth_repository.dart:24`) and server-side via Postgres RLS policies keyed off `public.es_veterinario()`/`public.mi_clinica_id()` (`supabase/schema.sql`)
  - Google OAuth: not implemented (see "Declared but not integrated" above)

## Monitoring & Observability

**Error Tracking:**
- None. No Sentry/Crashlytics/Firebase Crashlytics or similar package present.

**Logs:**
- None beyond default Flutter/Dart console output; no logging package (e.g. `logger`) is a direct dependency.

## CI/CD & Deployment

**Hosting:**
- Not defined in-repo. No web hosting config, no store deployment scripts, no Dockerfile for the app itself.

**CI Pipeline:**
- None detected. No `.github/workflows/`, no `bitbucket-pipelines.yml`, no other CI config files found in the repository.

## Environment Configuration

**Required env vars (passed as `--dart-define`, not `.env`):**
- `SUPABASE_URL` - Supabase project REST/Auth endpoint
- `SUPABASE_ANON_KEY` - Supabase public/anon API key (never the `service_role` key, per `README.md`)

**Secrets location:**
- No secrets are committed to the repository. No `.env` files exist. Supabase credentials must be supplied at build/run time on the command line (`flutter run --dart-define=...`) or via CI secret injection (no CI currently configured).
- Local Supabase CLI config `supabase/config.toml` contains only local development defaults (ports, feature toggles) - no real credentials.

## Webhooks & Callbacks

**Incoming:**
- None. No Supabase Edge Functions (`supabase/functions/` does not exist) and no server code in this repository to receive webhooks.

**Outgoing:**
- None detected beyond standard Supabase Auth email delivery (password reset / confirmation emails), which Supabase manages internally - not a webhook initiated by app code.

---

*Integration audit: 2026-09-24*
