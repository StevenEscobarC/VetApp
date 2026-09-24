# Coding Conventions

**Analysis Date:** 2026-09-24

## Naming Patterns

**Files:**
- `snake_case.dart` throughout, matching the primary class name in singular/verb form. Examples: `sign_in_with_email.dart`, `supabase_auth_repository.dart`, `app_status_chip.dart`, `app_text_field.dart`.
- Domain entity files are named after the noun they model (`mascota.dart`, `cliente.dart`, `veterinario.dart`, `cita.dart`, `consulta.dart`, `factura.dart`, `vacuna.dart`, `producto.dart`).
- Usecase files are named as `verb_noun_with_noun.dart` mirroring the class name (`watch_current_veterinario.dart` → `WatchCurrentVeterinario`).

**Classes:**
- `PascalCase`. Domain terms are kept in **Spanish** even though the codebase (comments, identifiers, structure) mixes English and Spanish: `Veterinario`, `Mascota`, `Cliente`, `Cita`, `Consulta`, `Factura`, `Vacuna`, `Producto`, `AuthFailure`.
- Private widgets/helpers are prefixed with `_` and still `PascalCase`: `_AuthGateState`, `_AuthScaffold`, `_VeterinarianHome`, `_SummaryCard`, `_PatientRow` (`lib/features/home/home_screen.dart`).
- Repository implementations follow `<Provider><Domain>Repository`, e.g. `SupabaseAuthRepository` (`lib/features/auth/data/repositories/supabase_auth_repository.dart`) implementing the abstract `AuthRepository` (`lib/features/auth/domain/repositories/auth_repository.dart`).
- Usecase classes are single-purpose, named as an imperative verb phrase with **no `UseCase` suffix**: `SignInWithEmail`, `SignUpWithEmail`, `SignOut`, `SignInWithGoogle`, `WatchCurrentVeterinario` (all in `lib/features/auth/domain/usecases/`).

**Functions/Methods:**
- `camelCase`. Private helpers prefixed with `_`: `_messageFor`, `_profileFor`, `_loadSession`, `_submit` (`lib/features/auth/presentation/auth_screens.dart`, `lib/features/auth/data/repositories/supabase_auth_repository.dart`).
- Usecase classes expose a single `call(...)` method so instances are invoked like functions: `SignInWithEmail(repo).call(email: ..., password: ...)` (`lib/features/auth/domain/usecases/sign_in_with_email.dart`).
- Boolean getters read as predicates: `esVeterinario` (`lib/features/auth/data/repositories/supabase_auth_repository.dart:24`), computed getters like `edadEnAnios` (`lib/features/patients/domain/entities/mascota.dart:36`).

**Variables:**
- `camelCase`, in **Spanish for domain data** (`nombre`, `telefono`, `clienteId`, `veterinarioId`, `fechaNacimiento`) and **English for framework/UI plumbing** (`onPressed`, `isLoading`, `controller`, `errorText`).
- Private field state in `StatefulWidget`s uses a leading underscore and no `is`/`has` prefix convention beyond booleans: `_loading`, `_error`, `_profile` (`lib/features/auth/presentation/auth_screens.dart`).

**Types:**
- Enums are `PascalCase` names with lowercase `camelCase` values: `enum Especie { perro, gato, otro }`, `enum Sexo { macho, hembra }` (`lib/features/patients/domain/entities/mascota.dart`), `enum AppButtonVariant { primary, outline, text }` (`lib/core/widgets/buttons/app_button.dart`), `enum AppStatus { confirmed, pending, cancelled, completed }` (`lib/core/widgets/status/app_status_chip.dart`).
- Dart records (`({Color color, IconData icon, String label})`) are used for small internal lookup tables rather than defining a class, e.g. the private `_spec` getter in `lib/core/widgets/status/app_status_chip.dart:19`.

## Code Style

**Formatting:**
- Standard `dart format` output (trailing commas on multi-line constructors, no semicolon omission). No custom `.prettierrc`-equivalent; formatting is whatever `flutter_lints` + `dart format` enforce.
- Widget `build()` methods are frequently written as expression-bodied arrow functions when the whole widget is a single return, e.g. `Widget build(BuildContext context) => Scaffold(...)` (`lib/features/auth/presentation/auth_screens.dart:108`, `:221`, `:317`, `:351`, `:402`).
- `const` is used aggressively wherever the constructor allows it (`const SizedBox(...)`, `const Icon(...)`, `const AuthGate()`).

**Linting:**
- `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml` with no rule overrides (`analysis_options.yaml`). Treat the default Flutter lint set as authoritative; do not disable rules without discussion.
- `pubspec.yaml` pins `flutter_lints: ^6.0.0` as the only dev-tooling dependency besides `flutter_test`.

## Import Organization

**Order observed in every file:**
1. `package:flutter/...` and other `package:` imports (e.g. `package:supabase_flutter/supabase_flutter.dart`) first.
2. Relative imports second, using **relative paths, not `package:vetapp/...`** — e.g. `import '../../../core/widgets/buttons/app_button.dart';` (`lib/features/auth/presentation/auth_screens.dart:4`), `import '../entities/veterinario.dart';` (`lib/features/auth/domain/usecases/sign_in_with_email.dart:1`).
- No blank-line grouping convention beyond package-imports-before-relative-imports; there are no barrel files (`index.dart`-equivalents) anywhere in `lib/`.
- No path aliases configured in `pubspec.yaml`; imports always use relative paths within `lib/`, and only the test target imports via `package:vetapp/...` (`test/widget_test.dart:3`).

## Error Handling

**Patterns:**
- Domain-facing errors are a single custom `Exception` type per feature: `AuthFailure implements Exception` with just a `message` field (`lib/features/auth/domain/auth_failure.dart`). The doc comment explicitly states the intent: the data layer translates provider-specific errors (Supabase `AuthException`) into this type so **domain/presentation code never depends on the data provider's SDK directly**.
- Data-layer repository methods (`lib/features/auth/data/repositories/supabase_auth_repository.dart`) wrap every external SDK call in `try { ... } on AuthException catch (error) { throw AuthFailure(_messageFor(error)); } catch (_) { throw const AuthFailure('<generic Spanish message>'); }`. Always provide **both** a specific `on <SdkException>` branch and a generic catch-all fallback with a user-facing Spanish message.
- `_messageFor(AuthException error)` (`lib/features/auth/data/repositories/supabase_auth_repository.dart:134`) centralizes translation of raw provider error strings (lowercased substring checks) into Spanish, user-safe messages. Add new provider error mappings here rather than inline at call sites.
- Presentation widgets catch the domain failure type only (`on AuthFailure catch (error)`) and surface `error.message` directly in `setState` (`lib/features/auth/presentation/auth_screens.dart:100`, `:213`, `:307`). They do not catch generic `Exception`/`Object` — any unmapped error is expected to already have been normalized to `AuthFailure` by the data layer.
- No app-wide error boundary, logger, or crash-reporting integration exists yet — errors that aren't `AuthFailure` will propagate as unhandled Flutter framework errors.

## Comments

**When to Comment:**
- File/class-level doc comments (`///`) explain **why**, not what — architectural intent, cross-feature relationships, or a non-obvious workaround. Examples:
  - `lib/features/auth/domain/auth_failure.dart:1` — explains the translation boundary.
  - `lib/features/patients/domain/entities/mascota.dart:5` — explains the entity's relationship to `Cliente`, `Consulta`, `Vacuna` via Dart doc `[Cliente]` cross-references.
  - `lib/core/widgets/status/app_status_chip.dart:8` — documents an accessibility rule (`color-not-only`) and a concrete Flutter `Chip` layout bug being worked around.
  - `lib/core/theme/app_theme.dart:7` — states the single-source-of-truth rule ("main.dart only ever references `AppTheme.light`/`AppTheme.dark` — never raw colors").
- Inline `//` comments are rare and only used for non-obvious constants, e.g. `// Dark mode (full support, per style spec).` (`lib/core/theme/app_colors.dart:29`).

**JSDoc/TSDoc equivalent (DartDoc):**
- Public classes that are part of the domain layer or shared widget library get a `///` doc comment; private/internal state classes and screen-glue widgets do not. Follow this asymmetry: document domain entities, repositories interfaces, and reusable `core/widgets/*` components; skip docs on private `_FooState` and one-off screen sections.
- Cross-references use Dart's `[Identifier]` doc-link syntax (`mascota.dart:5`) — use this when referencing other entities/classes in comments.

## Function Design

**Size:** Small and single-purpose in the domain layer (usecases are ~5-10 lines, one `call()` method). UI `build()` methods can be large (up to ~100 lines) since Flutter widget trees are inherently nested; no extraction-to-sub-widget requirement is enforced except for clearly reusable pieces (`AppButton`, `AppTextField`, `AppCard`, `AppStatusChip`).

**Parameters:** Widgets and usecases favor **named, required parameters** over positional ones. Optional fields default via `this.field = <default>` in the constructor initializer list, not via null-checks in the body (see `AppButton`, `AppTextField`, `Mascota`).

**Return Values:** Repository/usecase methods return `Future<T>` or `Stream<T>` directly (no `Result`/`Either` wrapper type) and communicate failure via **thrown exceptions**, not sentinel values or nullable-error tuples.

## Module Design

**Exports:** No `export` statements or barrel files anywhere in `lib/`. Every consumer imports the exact file it needs via a relative path.

**Feature-first structure:** Each feature under `lib/features/<name>/` is expected to have `domain/entities`, `domain/repositories`, `domain/usecases`, `data/repositories`, and `presentation/` subfolders (clean-architecture style), but **only the `auth` feature currently has all layers implemented**. Other features (`appointments`, `billing`, `clients`, `clinical_history`, `inventory`, `patients`, `vaccination`) currently have **only `domain/entities/`** — no repositories, usecases, or data layer yet. When adding functionality to these features, follow the `auth` feature's layering as the template:
  1. `domain/entities/<name>.dart` — plain immutable class with `copyWith`.
  2. `domain/repositories/<name>_repository.dart` — abstract interface.
  3. `domain/usecases/<verb>_<noun>.dart` — one class per operation, `call()` method.
  4. `data/repositories/supabase_<name>_repository.dart` — concrete implementation wrapping the Supabase client, translating SDK exceptions to a domain failure type.
  5. `presentation/<name>_screens.dart` — `StatefulWidget`s owning their own async/loading/error state via `setState` (no state-management library is wired up yet, see note below).

**State management note:** `flutter_riverpod` and `go_router` are declared in `pubspec.yaml` and `ProviderScope` wraps the app root (`lib/main.dart:20`), but **no feature uses Riverpod providers or `Notifier`/`Consumer` classes, and `go_router` has zero usages** — navigation is done with `Navigator.push(MaterialPageRoute(...))` (`lib/features/auth/presentation/auth_screens.dart:129`) and all async UI state is local `StatefulWidget` + `setState`. Do not assume Riverpod providers exist elsewhere in the codebase; if introducing them, this will be the first usage.

**Demo vs. wired screens:** `lib/features/home/home_screen.dart` (1400 lines) contains `DashboardScreen`, `PatientsScreen`, `AgendaScreen`, `HistoryScreen`, `VaccinationScreen`, `InventoryScreen`, `BillingScreen` — these are **static UI mockups with hardcoded private data classes** (`_AppointmentCard`, `_PatientRow`, `_InventoryItem`, `_InvoiceItem`, etc. defined at the bottom of the same file) and are not connected to any repository or entity. Only `lib/features/auth/` is wired to real Supabase data end-to-end. Do not treat `home_screen.dart`'s data classes as the real domain model — the real entities live in each feature's `domain/entities/`.

---

*Convention analysis: 2026-09-24*
