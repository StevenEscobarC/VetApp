# Testing Patterns

**Analysis Date:** 2026-09-24

## Test Framework

**Runner:**
- `flutter_test` (bundled with the Flutter SDK), declared as `dev_dependencies.flutter_test.sdk: flutter` in `pubspec.yaml`. No `test` package, no custom runner config.
- No `dart_test.yaml` or equivalent config file exists — defaults only.

**Assertion Library:**
- `flutter_test`'s built-in `expect(actual, matcher)` API (e.g. `findsOneWidget`). No third-party assertion library (no `matcher` extensions, no `checks` package).

**Mocking Library:**
- **None installed.** `pubspec.yaml` `dev_dependencies` contains only `flutter_test` and `flutter_lints` — no `mockito`, `mocktail`, or `fake_async`. There are currently no unit tests for repositories/usecases that would need mocks.

**Run Commands:**
```bash
flutter test                 # Run all tests (currently just test/widget_test.dart)
flutter test --coverage      # Generate lcov.info coverage report
flutter test test/widget_test.dart  # Run a single file
```
No `--watch` mode is configured; `flutter test` runs once and exits (standard Flutter behavior, no `--watch` flag support built in).

## Test File Organization

**Location:**
- Single top-level `test/` directory mirroring Flutter's default project template — not co-located with source files. Currently contains exactly one file: `test/widget_test.dart`.
- There is **no per-feature test structure yet** (e.g. no `test/features/auth/...`). If adding tests, mirror the `lib/features/<name>/...` path under `test/features/<name>/...` since that is the structural convention Flutter/Dart projects follow and matches this repo's feature-first `lib/` layout (see `ARCHITECTURE.md`/`STRUCTURE.md` if present).

**Naming:**
- `<subject>_test.dart` (only example: `widget_test.dart` testing the app root widget `VetApp`).

**Structure:**
```
test/
└── widget_test.dart   # Smoke test for VetApp root widget
```

## Test Structure

**Suite Organization:**
```dart
// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/main.dart';

void main() {
  testWidgets('VetApp boots to the login screen and exposes account creation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VetApp());

    expect(find.text('Bienvenido a VetApp'), findsOneWidget);
    expect(
      find.text('Gestiona tu clínica o cuida la salud de tus mascotas.'),
      findsOneWidget,
    );

    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('Olvidé mi contraseña'), findsOneWidget);
  });
}
```
- No `group()` blocks are used yet (only a single top-level `testWidgets` call).
- Test descriptions are written as full sentences describing observable behavior ("VetApp boots to the login screen and exposes account creation"), not `should X` phrasing.
- Assertions target **user-visible Spanish copy** via `find.text('...')` rather than `Key`s or `Finder` semantics — matches the app's Spanish-first UI convention. Note: this makes tests brittle to copy changes; there are no `Key(...)` widgets in the current UI to assert against instead.
- This is a real integration/smoke test against the entire app boot path (`pumpWidget(const VetApp())`), not an isolated unit test — because `AuthGate` short-circuits to `LoginScreen` when Supabase env vars are absent (`lib/features/auth/presentation/auth_screens.dart:30`, `supabaseConfigured` check), the test runs deterministically without a real Supabase backend or any mocking.

## Mocking

**Framework:** None configured (see above). No mocking library is available in `pubspec.yaml`.

**Patterns:**
- Not applicable yet — no unit tests exist for `SupabaseAuthRepository`, the usecases in `lib/features/auth/domain/usecases/`, or any other class that would need a mocked dependency.
- If adding tests that require mocking `SupabaseClient`/`AuthRepository`, note: `AuthRepository` is already an abstract interface (`lib/features/auth/domain/repositories/auth_repository.dart`) suitable for a hand-written fake or `mocktail` `Mock`. `SupabaseAuthRepository` itself is a concrete class (not behind an interface) that wraps `SupabaseClient` directly — testing it in isolation would require either `mocktail`'s `Mock` on `SupabaseClient` or a Supabase local/test instance, since there is no injectable abstraction over the Supabase SDK today.

**What to Mock (recommended for this codebase, not yet implemented):**
- The Supabase `SupabaseClient` / `GoTrueClient` when testing `SupabaseAuthRepository` in isolation.
- The `AuthRepository` abstract interface when testing usecases (`SignInWithEmail`, `SignUpWithEmail`, `SignOut`, `SignInWithGoogle`, `WatchCurrentVeterinario`) — each usecase takes the repository via constructor injection, which is designed for exactly this kind of substitution.

**What NOT to Mock:**
- Plain domain entities (`Veterinario`, `Mascota`, `Cliente`, etc.) — they are simple immutable data classes with `copyWith`, safe to construct directly in tests.
- `AppButton`, `AppTextField`, `AppCard`, `AppStatusChip` and other `core/widgets/` components — test these via `WidgetTester.pumpWidget` directly rather than mocking, since they have no external dependencies.

## Fixtures and Factories

**Test Data:**
- No fixtures or factory helpers exist yet. Any test data would currently need to be constructed inline using each entity's `const` constructor (e.g. `const Mascota(id: '1', clienteId: '1', veterinarioId: '1', nombre: 'Firulais', especie: Especie.perro, sexo: Sexo.macho)`).

**Location:**
- Not applicable — no `test/fixtures/` or `test/helpers/` directory exists.

## Coverage

**Requirements:** None enforced. No CI configuration, no coverage threshold, no badge.

**View Coverage:**
```bash
flutter test --coverage
# generates coverage/lcov.info
genhtml coverage/lcov.info -o coverage/html   # requires lcov tool separately installed
```

## Test Types

**Unit Tests:**
- **None exist.** No tests for domain entities, usecases, or the `SupabaseAuthRepository`/`AuthFailure` error-translation logic (`_messageFor` in `lib/features/auth/data/repositories/supabase_auth_repository.dart:134`) despite that logic having clear branch coverage worth testing (multiple `if (message.contains(...))` string-matching branches).

**Integration Tests:**
- `test/widget_test.dart` is effectively a shallow integration test (boots the real `VetApp` widget tree, real `MaterialApp`, real `AuthGate`), constrained to the "Supabase not configured" fallback path since no env vars are supplied during `flutter test`.
- No `integration_test/` directory (the Flutter package for full on-device integration tests) is set up.

**E2E Tests:**
- Not used. No `integration_test` package, no Patrol/Maestro/Appium configuration found anywhere in the repo.

## Common Patterns

**Async Testing:**
```dart
// Standard Flutter widget-test async pattern used in widget_test.dart:
await tester.pumpWidget(const VetApp());
// No explicit pump()/pumpAndSettle() calls yet since the smoke test only
// checks the synchronous initial frame after the "not configured" fast path.
```
There is no example yet of testing the `_loading` → `FutureBuilder`-style async flow in `AuthGate._loadSession()` (`lib/features/auth/presentation/auth_screens.dart:38`); a future test exercising the "Supabase configured" branch would need `tester.pump()`/`pumpAndSettle()` after mocking the repository's `Future`.

**Error Testing:**
- No examples exist. When adding coverage for `AuthFailure`-throwing code paths (`SupabaseAuthRepository.signIn/signUp/resetPassword/profileForCurrentUser`), use `expect(() => repository.signIn(...), throwsA(isA<AuthFailure>()))` as the idiomatic `flutter_test` pattern, and assert on `error.message` content for the Spanish user-facing text where relevant.

---

*Testing analysis: 2026-09-24*
