# Technology Stack

**Analysis Date:** 2026-09-24

## Languages

**Primary:**
- Dart `^3.11.1` (SDK constraint in `pubspec.yaml`) - entire application (`lib/`)
- SQL (PostgreSQL/PL-pgSQL) - Supabase schema, triggers, RLS policies in `supabase/schema.sql`

**Secondary:**
- Kotlin/Gradle (Android platform shell) - `android/app/build.gradle.kts`, `android/`
- Swift/Objective-C (iOS/macOS platform shell) - `ios/Runner/`, `macos/Runner/`
- C++/CMake (Windows/Linux desktop shells) - `windows/`, `linux/`
- YAML - `pubspec.yaml`, `supabase/config.toml`, `analysis_options.yaml`

## Runtime

**Environment:**
- Flutter SDK, channel `stable`, revision `ff37bef603469fb030f2b72995ab929ccfc227f0` (`.metadata`)
- Multi-platform Flutter app: Android, iOS, Web, Windows, macOS, Linux all scaffolded (`android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`)
- Android: `applicationId = "com.vetapp.vetapp"` (`android/app/build.gradle.kts`), compileSdk/minSdk/targetSdk driven by Flutter tooling defaults
- iOS/macOS bundle id: `com.vetapp.vetapp` (`ios/Runner.xcodeproj/project.pbxproj`)

**Package Manager:**
- `pub` (Dart/Flutter's native package manager)
- Manifest: `pubspec.yaml`
- Lockfile: present - `pubspec.lock` (committed, pins exact resolved versions)

## Frameworks

**Core:**
- Flutter (Material) - UI toolkit, `sdk: flutter` in `pubspec.yaml`
- `flutter_riverpod` `^3.3.2` (locked `3.3.2`, transitively pulls `riverpod` core `3.3.2`) - state management. `ProviderScope` wraps the app root in `lib/main.dart`; no feature-level providers are defined yet elsewhere in `lib/`
- `go_router` `^17.3.0` (locked `17.3.0`) - declarative routing package is a direct dependency, but `lib/core/router/` is currently an empty directory - routing is not yet wired up; `lib/main.dart` uses a plain `MaterialApp` with a static `home:` widget (`AuthGate`)
- `supabase_flutter` `^2.9.1` (locked `2.17.2`) - backend client (auth, Postgres, realtime, storage)

**Testing:**
- `flutter_test` (SDK dev dependency) - only scaffold test present: `test/widget_test.dart` (default counter-app template, not adapted to this app)

**Build/Dev:**
- `flutter_lints` `^6.0.0` (locked `6.0.0`) - lint rule set, configured via `analysis_options.yaml` (`include: package:flutter_lints/flutter.yaml`, no custom rule overrides)

## Key Dependencies

**Critical:**
- `supabase_flutter` `2.17.2` - sole backend integration: authentication, Postgres data access (`SupabaseClient.from(...)`), session persistence/restoration. Used directly in `lib/main.dart` and `lib/features/auth/data/repositories/supabase_auth_repository.dart`
- `flutter_riverpod` `3.3.2` - DI/state container, currently only bootstrapped (`ProviderScope`) with no providers defined in feature code
- `go_router` `17.3.0` - declared but unused; no `GoRouter` instance exists in the codebase yet (`lib/core/router/` is empty)

**Infrastructure:**
- `google_fonts` `^8.2.0` (locked `8.2.0`) - typography, referenced from `lib/core/theme/app_typography.dart`
- `intl` `^0.20.3` (locked `0.20.3`) - date/number formatting/localization primitives (Spanish-language app)
- `cupertino_icons` `^1.0.8` - iOS-style icon set

## Configuration

**Environment:**
- No `.env` file present in the repository. Supabase credentials are injected at build/run time via Dart compile-time environment variables:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - Read via `String.fromEnvironment(...)` in `lib/main.dart` and `lib/features/auth/presentation/auth_screens.dart`
  - Passed with `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` (documented in `README.md`)
  - App explicitly guards against missing config: if either var is empty, `Supabase.initialize` is skipped and the UI falls back to an unconfigured state (`supabaseConfigured` flag in `auth_screens.dart`)
  - README explicitly warns to use only the `anon`/`publishable` key, never `service_role`, in the mobile app
- `firebase.json` exists at repo root (project `vetapp-colombia`, referencing `lib/firebase_options.dart` and `android/app/google-services.json`) but **no Firebase Dart packages are declared** in `pubspec.yaml`/`pubspec.lock` (no `firebase_core`, `firebase_auth`, etc.) and `lib/firebase_options.dart` does not exist. This appears to be leftover FlutterFire scaffolding from an earlier setup step and is not part of the active stack - see `CONCERNS.md` if generated.

**Build:**
- `pubspec.yaml` - single source of truth for dependencies, Dart SDK constraint, and Flutter asset/font config (no custom fonts or assets currently declared)
- `analysis_options.yaml` - static analysis config, extends `flutter_lints/flutter.yaml` with no local overrides
- `supabase/config.toml` - local Supabase CLI stack configuration (API port `54321`, DB, Auth, Storage, Realtime, Edge Runtime all enabled for local dev via `supabase start`); no custom Edge Functions present (no `supabase/functions/` directory)
- `supabase/schema.sql` - hand-maintained SQL migration (tables, enum, trigger, RLS policies) intended to be pasted into the Supabase SQL Editor per `README.md` (no formal `supabase/migrations/` folder is used)

## Platform Requirements

**Development:**
- Flutter SDK (stable channel) matching Dart constraint `^3.11.1`
- Platform toolchains as needed per target: Android SDK/Gradle, Xcode (iOS/macOS), Visual Studio (Windows), standard Linux build toolchain
- Supabase account/project (cloud) or Supabase CLI + Docker for local stack (`supabase/config.toml`)

**Production:**
- Deployment target(s): not yet defined in-repo (no CI/CD config, no store listing files, no environment-specific build scripts beyond the standard Flutter platform folders)
- Backend: Supabase-hosted Postgres + Auth (cloud project, URL/key supplied at build time - no project ref committed)

---

*Stack analysis: 2026-09-24*
