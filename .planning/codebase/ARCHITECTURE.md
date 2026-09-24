<!-- refreshed: 2026-09-24 -->
# Architecture

**Analysis Date:** 2026-09-24

## System Overview

```text
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Client App                       │
├──────────────────┬──────────────────┬───────────────────────┤
│  core/theme       │  core/widgets    │  features/*           │
│ `lib/core/theme`  │ `lib/core/widgets`│ `lib/features/*`     │
│  design tokens     │  shared UI atoms │  screens + (partial)  │
│                    │                  │  data/domain layers   │
└────────┬───────────┴────────┬─────────┴──────────┬────────────┘
         │                    │                     │
         ▼                    ▼                     ▼
┌─────────────────────────────────────────────────────────────┐
│         supabase_flutter client (Supabase.instance.client)   │
│         instantiated ad hoc inside presentation widgets      │
└────────┬──────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│              Supabase (Postgres + Auth + RLS)                │
│  `supabase/schema.sql`: clinicas / perfiles / mascotas       │
└─────────────────────────────────────────────────────────────┘
```

Only the `auth` feature is wired end-to-end (UI → Supabase → Postgres). Every
other feature directory (`appointments`, `billing`, `clients`,
`clinical_history`, `inventory`, `patients`, `vaccination`) contains only a
domain entity file and is otherwise unimplemented scaffolding. `dashboard` is
an empty shell with zero files. The authenticated home experience
(`lib/features/home/home_screen.dart`) is a single static UI mockup with
hardcoded values and no data wiring at all.

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| App bootstrap | Initializes Supabase (if env vars present), wraps app in `ProviderScope`, sets theme, renders `AuthGate` | `lib/main.dart` |
| AuthGate | De-facto root router: checks Supabase config, restores session, loads profile, decides Login vs role-based home | `lib/features/auth/presentation/auth_screens.dart` |
| SupabaseAuthRepository | Concrete auth/profile data access: sign in/up/out, password reset, profile fetch, Supabase error → Spanish message translation | `lib/features/auth/data/repositories/supabase_auth_repository.dart` |
| AuthProfile | Data-layer view model actually consumed by the UI (id, nombre, email, rol, telefono, clinicaId, clinicaNombre) | `lib/features/auth/data/repositories/supabase_auth_repository.dart` |
| AuthRepository (interface) / Veterinario / usecases | Domain-layer abstraction for auth — **defined but never referenced by any other file** | `lib/features/auth/domain/repositories/auth_repository.dart`, `lib/features/auth/domain/entities/veterinario.dart`, `lib/features/auth/domain/usecases/*.dart` |
| HomeScreen shell | Post-login veterinarian UI: `NavigationRail`/`NavigationBar` switching between 5 static sub-screens via `IndexedStack` | `lib/features/home/home_screen.dart` |
| Design tokens | Central color/spacing/typography/theme definitions consumed via `AppTheme.light` / `AppTheme.dark` | `lib/core/theme/app_theme.dart`, `app_colors.dart`, `app_spacing.dart`, `app_typography.dart` |
| Shared widgets | Reusable UI atoms (button, card, text field, status chip, top bar) used across features | `lib/core/widgets/**` |
| Domain entities (stub features) | Data shape for future features; no repository/usecase/datasource/screen exists yet | `lib/features/{appointments,billing,clients,clinical_history,inventory,patients,vaccination}/domain/entities/*.dart` |
| DB schema + RLS | Multi-tenant schema (clinicas → perfiles → mascotas), signup trigger, row-level security policies | `supabase/schema.sql` |

## Pattern Overview

**Overall:** Feature-first "Clean Architecture" scaffold (`data/domain/presentation` per feature under `lib/features/<feature>/`), but the pattern is **only fully realized in name for `auth`**, and even there the presentation layer bypasses the domain layer entirely. All other features are scaffolding-only (a single `domain/entities/*.dart` file, nothing else). There is no dependency-injection container, no Riverpod providers, and no router — despite `flutter_riverpod` and `go_router` both being declared dependencies in `pubspec.yaml`.

**Key Characteristics:**
- Directory layout signals intended Clean Architecture (`data/datasources`, `data/models`, `data/repositories`, `domain/entities`, `domain/repositories`, `domain/usecases`, `presentation/providers`, `presentation/screens`, `presentation/widgets`) per feature.
- In practice, the `auth` feature's presentation code (`auth_screens.dart`) instantiates the concrete `SupabaseAuthRepository` class directly (`SupabaseAuthRepository(Supabase.instance.client)`) inline inside widget callbacks — it never depends on the `AuthRepository` interface, never uses the `Veterinario` entity, and never calls any of the `domain/usecases/*.dart` classes. Those domain files are unused dead code.
- State management is plain `StatefulWidget` + `setState()` everywhere. `flutter_riverpod`'s `ProviderScope` wraps the app in `lib/main.dart` but no `Provider`, `StateNotifier`, `ConsumerWidget`, or `ref.watch` exists anywhere in `lib/`.
- Routing is manual `Navigator.push(MaterialPageRoute(...))` plus in-widget `IndexedStack`/`NavigationRail` index state. `go_router` is declared in `pubspec.yaml` but never imported anywhere in `lib/`.
- Multi-tenancy is enforced at the database layer via Postgres RLS (`supabase/schema.sql`), not in the Flutter client.
- Domain-layer comments reference **Firestore/Firebase** ("cuelgan de `veterinarios/{id}` en Firestore", "la capa de datos traduce los códigos de Firebase a este tipo") — e.g. `lib/features/auth/domain/entities/veterinario.dart:1-3` and `lib/features/auth/domain/auth_failure.dart:2-3` — even though the actual, wired implementation uses **Supabase** exclusively. This indicates the domain scaffolding predates (or was copy-pasted from) an earlier Firebase-based design and was never updated to match the Supabase implementation.

## Layers

**Presentation (`presentation/`):**
- Purpose: Screens and widgets; owns all business logic for the one implemented feature (auth) inline in widget State classes.
- Location: `lib/features/auth/presentation/auth_screens.dart`, `lib/features/home/home_screen.dart`
- Contains: `StatefulWidget`/`StatelessWidget` classes, form controllers, direct Supabase client calls, hardcoded UI copy in Spanish.
- Depends on: `lib/features/auth/data/repositories/supabase_auth_repository.dart` directly (not through an interface); `lib/core/widgets/**`; `lib/core/theme/**`.
- Used by: `lib/main.dart` (renders `AuthGate`).

**Data (`data/`):**
- Purpose: Concrete Supabase access + error translation.
- Location: `lib/features/auth/data/repositories/supabase_auth_repository.dart` (only implemented instance; `data/datasources`, `data/models` folders exist under other features but are empty).
- Contains: `SupabaseAuthRepository` (raw Supabase calls), `AuthProfile` (plain data class returned to the UI).
- Depends on: `package:supabase_flutter`, `lib/features/auth/domain/auth_failure.dart` (only domain file actually used, purely as an exception type).
- Used by: `presentation/auth_screens.dart`.

**Domain (`domain/`):**
- Purpose: Intended business-rule layer (entities, repository interfaces, usecases).
- Location: `lib/features/*/domain/**`
- Contains: Entities (`Veterinario`, `Mascota`, `Cita`, `Factura`, `Cliente`, `Consulta`, `Producto`, `Vacuna`), one repository interface (`AuthRepository`), five auth usecases, `AuthFailure` exception.
- Depends on: Nothing (pure Dart, no Flutter/Supabase imports) — correctly isolated in principle.
- Used by: **Nothing**, except `AuthFailure`, which is used purely as an exception type by the data layer. All entities and the `AuthRepository` interface/usecases are unreferenced dead code as of this analysis.

**Core (`lib/core/`):**
- Purpose: Cross-feature design system and shared UI primitives.
- Location: `lib/core/theme/**` (tokens + `AppTheme`), `lib/core/widgets/**` (`AppButton`, `AppCard`, `AppTextField`, `AppStatusChip`, `AppTopBar`).
- Contains: Stateless style/config classes and small reusable widgets.
- Depends on: Flutter SDK only.
- Used by: `lib/main.dart`, `lib/features/auth/presentation/auth_screens.dart`, `lib/features/home/home_screen.dart`.
- Empty (scaffold-only, zero files): `lib/core/router/`, `lib/core/data/`, `lib/core/errors/`, `lib/core/utils/`, `lib/core/constants/`.

## Data Flow

### App Boot / Session Restore

1. `main()` reads `SUPABASE_URL` / `SUPABASE_ANON_KEY` from `--dart-define` and conditionally calls `Supabase.initialize(...)` (`lib/main.dart:8-18`).
2. `ProviderScope` wraps `VetApp`, but no provider is ever read — this is inert scaffolding for future Riverpod adoption (`lib/main.dart:20`).
3. `MaterialApp.home` renders `AuthGate` (`lib/main.dart:39`).
4. `AuthGate.initState` creates `SupabaseAuthRepository(Supabase.instance.client)` and calls `_loadSession()` (`lib/features/auth/presentation/auth_screens.dart:22-36`).
5. If a Supabase session exists, `profileForCurrentUser()` queries `perfiles` joined with `clinicas` by user id (`lib/features/auth/data/repositories/supabase_auth_repository.dart:102-130`); a failed lookup forces `signOut()`.
6. `AuthGate.build` renders `LoginScreen` (no profile), `_VeterinarianHome` → `HomeScreen` (`rol == 'VETERINARIO'`), or `ClientHomeScreen` (`rol == 'CLIENTE'`) (`lib/features/auth/presentation/auth_screens.dart:56-64`).

### Sign-In

1. `LoginScreen._submit` validates non-empty fields locally, then calls `SupabaseAuthRepository(...).signIn(email, password)` (`lib/features/auth/presentation/auth_screens.dart:82-105`).
2. `signIn` calls `_client.auth.signInWithPassword(...)`, then `_profileFor(user.id)` to fetch the joined `perfiles`/`clinicas` row (`lib/features/auth/data/repositories/supabase_auth_repository.dart:36-53`).
3. Supabase `AuthException`s are translated to Spanish via `_messageFor()`; unknown errors fall back to a generic `AuthFailure` message (`lib/features/auth/data/repositories/supabase_auth_repository.dart:134-151`).
4. On success, `onAuthenticated(profile)` callback bubbles the `AuthProfile` back up to `AuthGate`'s `setState` (`lib/features/auth/presentation/auth_screens.dart:57-59, 99`).

### Sign-Up

1. `RegisterScreen._submit` performs client-side field validation (name/email/password length, clinic name required for `VETERINARIO` role) (`lib/features/auth/presentation/auth_screens.dart:175-192`).
2. Calls `SupabaseAuthRepository.signUp(...)`, passing role and (for vets) clinic fields as Supabase Auth user metadata (`lib/features/auth/data/repositories/supabase_auth_repository.dart:55-88`).
3. A Postgres trigger (`crear_perfil_nuevo_usuario`, `supabase/schema.sql:46-80`) fires on `auth.users` insert: creates a `clinicas` row when `rol = 'VETERINARIO'`, then always inserts the matching `perfiles` row — profile creation is entirely server-side, not client-side.
4. Email confirmation is required before the user can sign in (enforced by Supabase Auth config per `README.md`, not by app code).

**State Management:**
- Purely local widget state (`setState`) per screen; no shared/global app state container is actually wired despite `flutter_riverpod` being present.
- Session/profile state lives only in `_AuthGateState` (`_profile`, `_loading`) and is lost/rebuilt on full widget tree rebuild; no persistence layer beyond what `supabase_flutter` itself persists (its own session token storage).

## Key Abstractions

**Repository pattern (auth only, partially applied):**
- Purpose: intended to abstract the auth backend behind an interface.
- Examples: `lib/features/auth/domain/repositories/auth_repository.dart` (interface, unused), `lib/features/auth/data/repositories/supabase_auth_repository.dart` (concrete class, used directly — does not `implements AuthRepository`).
- Pattern: broken — the concrete class is used as its own type everywhere; the abstraction it was meant to sit behind is never referenced.

**Design tokens:**
- Purpose: single source of truth for color/spacing/typography so theming changes propagate app-wide.
- Examples: `lib/core/theme/app_colors.dart`, `app_spacing.dart`, `app_typography.dart`, composed by `app_theme.dart`.
- Pattern: static classes with private constructors (`AppSpacing._()`) exposing only `static const` fields — never instantiated.

**Entities as plain immutable classes:**
- Purpose: domain data shapes with `copyWith`, used (in principle) independently of any persistence framework.
- Examples: `lib/features/patients/domain/entities/mascota.dart`, `lib/features/appointments/domain/entities/cita.dart`, `lib/features/billing/domain/entities/factura.dart`, etc.
- Pattern: `const` constructor + `copyWith()` method; no JSON (de)serialization, no Supabase mapping — these exist purely as future domain shapes, not yet connected to any `data/models` or Supabase table mapping code.

## Entry Points

**App boot:**
- Location: `lib/main.dart`
- Triggers: Flutter engine on process start (mobile/desktop/web target set under `android/`, `ios/`, `web/`, `windows/`, `linux/`, `macos/`).
- Responsibilities: Supabase init (conditional), theme setup, render `AuthGate`.

**AuthGate (effective root router):**
- Location: `lib/features/auth/presentation/auth_screens.dart`
- Triggers: rendered unconditionally by `main.dart`; re-renders on internal `setState` after login/logout.
- Responsibilities: session bootstrap, role-based screen selection (veterinarian vs client), Supabase-not-configured fallback.

**Test entry point:**
- Location: `test/widget_test.dart`
- Triggers: `flutter test`
- Responsibilities: single smoke test pumping `VetApp` and asserting login-screen copy is present (see also TESTING.md-equivalent coverage note below — no other tests exist in the repo).

## Architectural Constraints

- **Threading:** Standard single-threaded Flutter UI/event-loop model; no isolates, workers, or background tasks used anywhere.
- **Global state:** `supabaseConfigured` is a module-level `final` computed from `String.fromEnvironment` in `lib/features/auth/presentation/auth_screens.dart:10-13` — the only global/module-level state in the app. No singletons elsewhere.
- **Circular imports:** None detected — the feature/core layering is acyclic; the main issue is unused domain code, not circular coupling.
- **Environment configuration:** Supabase URL/anon key must be passed via `--dart-define` at build/run time (`lib/main.dart:10-11`); there is no `.env` file loading and no fallback config file. If unset, the app runs in a "not configured" degraded mode (`supabaseConfigured == false`) that still renders `LoginScreen` but blocks all auth actions.
- **Multi-tenancy enforcement:** Tenant isolation (`clinica_id`) is enforced exclusively via Postgres RLS policies in `supabase/schema.sql` — the Flutter client performs no additional tenant-scoping logic itself; any future feature querying `mascotas` or other tenant-scoped tables relies entirely on RLS being correct.

## Anti-Patterns

### Domain layer defined but bypassed

**What happens:** `AuthRepository` (interface), `Veterinario` (entity), and all five `domain/usecases/*.dart` classes for auth are fully written but never imported or called by any presentation or data code. The presentation layer talks directly to the concrete `SupabaseAuthRepository`/`AuthProfile` types instead.
**Why it's wrong:** The abstraction provides no actual decoupling benefit while adding files to maintain; any future refactor extending this pattern (e.g., adding usecases for other features) has no working example to follow inside this codebase — `auth`'s own domain layer is not the truth of how auth actually works.
**Do this instead:** Either delete the unused `domain/` files for `auth` or (preferably, if adopting Clean Architecture forward) make `auth_screens.dart` depend on `AuthRepository`/usecases and have `SupabaseAuthRepository implements AuthRepository`, returning `Veterinario` instead of the ad hoc `AuthProfile`.

### Declared-but-unused core dependencies (Riverpod, go_router)

**What happens:** `pubspec.yaml` declares `flutter_riverpod` and `go_router`; `main.dart` wraps the app in `ProviderScope`, but no `Provider`/`ConsumerWidget`/`ref.watch` and no `GoRouter`/`go_router` import exists anywhere in `lib/`. All navigation is manual `Navigator.push(MaterialPageRoute(...))` and all state is `setState`.
**Why it's wrong:** Two state/navigation strategies are implied by the dependency graph but only one (imperative Navigator + setState) is actually used, which will confuse anyone extending a stub feature folder that already has a `presentation/providers/` directory waiting to be filled.
**Do this instead:** Pick one strategy going forward and apply it consistently: either commit to Riverpod providers + `go_router` route table (matching the scaffolded `presentation/providers/` folders in every feature), or remove the unused dependencies/folders to reflect the imperative approach actually in use.

### Feature-directory scaffolding without implementation

**What happens:** `appointments`, `billing`, `clients`, `clinical_history`, `inventory`, `patients`, `vaccination` each have a full `data/{datasources,models,repositories}`, `domain/{entities,repositories,usecases}`, `presentation/{providers,screens,widgets}` directory tree, but only `domain/entities/<name>.dart` contains a file — everything else is an empty directory. `dashboard` has no files at all.
**Why it's wrong:** Empty directories signal "implemented structure" to anyone browsing the tree, but there is zero behavior behind them; a planner/executor navigating by directory listing alone will overestimate how much of the app is built.
**Do this instead:** Treat every non-`auth` feature as **not started** for planning purposes; use `auth`'s directory shape only as the intended target structure, not as evidence of existing behavior.

### Hardcoded/mock UI presented as the main app screen

**What happens:** `lib/features/home/home_screen.dart` (1400 lines) renders `DashboardScreen`, `PatientsScreen`, `AgendaScreen`, `HistoryScreen`, `BillingScreen` entirely from hardcoded literals (e.g. `_SummaryCard(title: 'Citas hoy', value: '08', ...)`), with no Supabase query, no provider, no `FutureBuilder`/`StreamBuilder` anywhere in the file.
**Why it's wrong:** This is the screen every authenticated veterinarian actually sees (`_VeterinarianHome` → `HomeScreen`), so it is easy to mistake static mock data for a working dashboard feature.
**Do this instead:** When implementing real data for any of these five sections, replace the static widgets feature-by-feature and move each into its own `features/<name>/presentation/screens/` file rather than growing this single monolithic file further.

## Error Handling

**Strategy:** Centralized translation of Supabase `AuthException` into a single Spanish-language `AuthFailure` exception, applied only within `SupabaseAuthRepository`.

**Patterns:**
- `AuthFailure implements Exception` carries a pre-translated, user-facing message (`lib/features/auth/domain/auth_failure.dart`).
- `SupabaseAuthRepository._messageFor(AuthException)` pattern-matches on lowercased substrings of the raw Supabase error message (`invalid login credentials`, `already registered`, `email not confirmed`, `password`, `email`) and returns a fixed Spanish string, with a generic catch-all otherwise (`lib/features/auth/data/repositories/supabase_auth_repository.dart:134-151`).
- Every repository method wraps its Supabase call in `try { ... } on AuthException catch (error) { throw AuthFailure(_messageFor(error)); } catch (_) { throw const AuthFailure('...'); }` — a consistent two-tier catch (`lib/features/auth/data/repositories/supabase_auth_repository.dart:40-53, 66-88, 91-100, 111-129`).
- Presentation widgets catch `AuthFailure` specifically and set it into `_error`/`_message` state for display (`lib/features/auth/presentation/auth_screens.dart:100-104, 213-216, 307-313`).
- No error handling exists outside the auth feature (no other feature has any backend calls yet).

## Cross-Cutting Concerns

**Logging:** Not detected — no logging framework or `print`/`debugPrint` calls found in the reviewed feature code.
**Validation:** Client-side, ad hoc, inline in each `_submit()` method (non-empty checks, password length ≥ 8, conditional clinic-field requirement for `VETERINARIO` role) — no shared validator utility exists (`lib/core/utils/` is empty).
**Authentication:** Fully delegated to `supabase_flutter`'s `SupabaseClient.auth` (email/password sign in, sign up, sign out, password reset); session persistence/restore is handled by the `supabase_flutter` package itself, not custom code. `signInWithGoogle` is defined as a domain usecase (`lib/features/auth/domain/usecases/sign_in_with_google.dart`) but has no corresponding implementation in `SupabaseAuthRepository` or any UI entry point — it is unimplemented/dead.

---

*Architecture analysis: 2026-09-24*
