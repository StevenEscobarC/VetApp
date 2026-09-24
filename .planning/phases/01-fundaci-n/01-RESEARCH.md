# Phase 1: Fundación - Research

**Researched:** 2026-09-24
**Domain:** Supabase (Postgres/RLS) schema hardening + Flutter Riverpod/go_router wiring (brownfield: mocked UI → real backend)
**Confidence:** HIGH

## Summary

Phase 1 has three independent-but-sequenced deliverables, all already scoped precisely by `01-CONTEXT.md` and the project-level research (`ARCHITECTURE.md`/`PITFALLS.md`/`STACK.md`, researched 2026-09-23, one day old, still valid — no new packages are needed this phase):

1. **Schema/RLS hardening** — apply `supabase/schema.sql` (currently unapplied) to the real, empty cloud project, fix the exact privilege-escalation bug in `perfiles_update` (a `CLIENTE` can today set their own `rol`/`clinica_id` to anything), add a new `clientes` table decoupled from `perfiles` (FOUND-04), and re-point `mascotas.dueno_id` at `clientes` instead of `perfiles` — which also requires **rewriting `mascotas`' RLS policies**, because their current `dueno_id = auth.uid()` clause silently becomes meaningless once `dueno_id` no longer points at an authenticated user.
2. **Riverpod/go_router wiring** — replace `AuthGate` + `Navigator.push(MaterialPageRoute(...))` with a `Provider<GoRouter>` built from a `StatefulShellRoute.indexedStack` (5 branches matching the bottom nav) and a `redirect:` callback driven by a new `authProfileProvider` (`AsyncNotifier<AuthProfile?>`). This is a full replacement of the existing session/routing logic, not an addition alongside it — `Navigator.push` and `AuthGate`'s widget-based branching must not survive this phase (Pitfall #4).
3. **Walking Skeleton** — a real `InicioScreen`, routed at `/inicio`, that reads the authenticated vet's name/clinic via `authProfileProvider` and renders it inside the terracota/crema design system. The current `app_colors.dart`/`app_typography.dart` tokens are **not** the approved palette (verified by direct read: today's `AppColors.primary` is a forest green `#2F6F4F`, not terracota `#C67139`, and `AppTypography` uses Figtree+Noto Sans, not Caprasimo+Figtree) — updating these tokens is in scope and is a prerequisite for the Walking Skeleton to look like the approved mockup, not a cosmetic afterthought.

Firebase-era dead code removal (FOUND-06) is a bounded, enumerable file list (below) — no ambiguity there.

**Primary recommendation:** Sequence the phase as schema/RLS → core wiring (client provider, auth provider, router) → design tokens → walking skeleton screen → dead-code deletion, in that order, because each later step assumes the previous one is real (an `AsyncNotifier` can't be built against a repository whose backing table doesn't exist yet; the walking skeleton can't render the approved palette until the tokens are updated).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Multi-tenant data isolation (`clinica_id` scoping) | Database / Storage (Postgres RLS) | — | Already the established pattern (`supabase/schema.sql`); the Flutter client performs zero additional tenant-scoping per `codebase/ARCHITECTURE.md` — RLS is the sole security boundary |
| Privilege escalation prevention (`perfiles.rol`/`clinica_id`) | Database / Storage (RLS `WITH CHECK`) | — | Must be enforced at the row level; a client-side check is trivially bypassable since the anon/authenticated key is the only credential the app ever holds |
| Client (dueño) record creation without auth | Database / Storage (new `clientes` table + RLS) | API/Backend (repository) | `clientes` rows are written by the vet's authenticated session but represent a non-authenticated third party — ownership/access control lives entirely in Postgres RLS keyed on `clinica_id`, never on the client's own credentials (they have none) |
| Session state / "who is logged in" | Frontend Server tier N/A (mobile-only app) → App/Client (Riverpod) | — | `authProfileProvider` (`AsyncNotifier`) is the single source of truth, replacing `AuthGate`'s local `setState`; watched by both the router and (later) every feature's RLS-scoped queries |
| Navigation / route guarding | Browser/Client (go_router `redirect:`) | App/Client (Riverpod via `ref.listen` bridge) | `go_router`'s `redirect:` callback is the enforcement point for auth-gating; it reads `authProfileProvider` through a `ChangeNotifier` bridge since `GoRouter.refreshListenable` requires a `Listenable`, not a raw provider |
| Design tokens / visual theme | App/Client (Flutter `ThemeData`) | — | No server involvement; `AppColors`/`AppTypography` are pure Dart constants consumed by `AppTheme` |
| Walking Skeleton data fetch (vet name/clinic) | API/Backend (Postgres query via repository) | App/Client (`AsyncNotifier` exposing `AsyncValue`) | Same `_profileFor`-style joined query the app already runs today (`perfiles` ⋈ `clinicas`), just moved behind a provider instead of inline `initState` |

## Project Constraints (from CLAUDE.md)

- **Tech stack is locked**: Flutter + Supabase — do not evaluate alternative backends or state-management libraries.
- **Backend real, no mocks**: every module must connect to the real cloud Supabase project; this phase's entire purpose is retiring the "not configured" degraded mode and the static `home_screen.dart` mock.
- **Diseño**: must match the approved mockup (terracota/crema, Caprasimo + Figtree) — **not** Material 3 defaults, and **not** the current green/Figtree+Noto-Sans tokens already in the repo (verified mismatch, see Summary).
- **Mercado objetivo**: Colombia — COP currency, `dd/mm/aaaa` dates. Not directly exercised by Phase 1 (no money/date-heavy UI yet), but any placeholder copy written this phase should stay in Spanish, matching existing convention.
- **GSD workflow enforcement**: file changes must happen through a GSD command (`/gsd-execute-phase` etc.) — informational for the planner, not an implementation detail.
- **Naming/style conventions** (from the generated stack profile, treated as binding): `snake_case.dart` file names, Spanish domain nouns for entities/fields, English plumbing (`onPressed`, `isLoading`), two-tier error handling (`AuthFailure`-style domain exception + `_messageFor`-style SDK-error translation with a generic catch-all), `PascalCase` classes with `_`-prefixed private widgets, doc comments (`///`) only on public domain/shared-widget classes.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FOUND-01 | Real cloud Supabase project, `schema.sql` applied | Project already exists (`https://apjonrmhkpyzbofupokb.supabase.co`, verified reachable) but empty — apply the revised `schema.sql` (below) via SQL Editor in one pass since no data exists yet; no migration/backfill needed |
| FOUND-02 | `go_router` navigation, 5 bottom-nav sections | `StatefulShellRoute.indexedStack` pattern, exact route table and `AppShell` widget specified below |
| FOUND-03 | Riverpod (`Notifier`/`AsyncNotifier`) state, no direct `setState` on data screens | `authProfileProvider` (`AsyncNotifier<AuthProfile?>`) + `supabaseClientProvider`/`authRepositoryProvider` specified below; `VetApp` becomes a `ConsumerWidget` |
| FOUND-04 | `clientes` table independent of `perfiles`, no auth required for the client | Exact SQL below: new `clientes` table owned by `clinica_id`, `mascotas.dueno_id` FK repointed, `mascotas` RLS rewritten (client-auth clause removed) |
| FOUND-05 | RLS on `clinicas`/`perfiles`/`mascotas` tested against `authenticated` role, `perfiles` self-escalation fixed | Exact bug identified in current `perfiles_update` policy; exact fix SQL + manual smoke-test script below |
| FOUND-06 | Firebase→Supabase dead code removed | Exact file list below (auth domain layer, `firebase.json`, `google-services.json`, duplicate `LoginScreen`) |

</phase_requirements>

## Standard Stack

### Core (already installed — no new packages this phase)

| Library | Version (pinned) | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter_riverpod` | `^3.3.2` (resolves `3.3.2`–`3.4.3`) | State/DI | Already a direct dependency, currently unused beyond `ProviderScope`; hand-written `Notifier`/`AsyncNotifier` (no codegen) per `.planning/research/STACK.md` |
| `go_router` | `^17.3.0` — **do not bump to 18.x** | Declarative navigation | Already declared, unused; `18.x` requires Flutter 3.44/Dart 3.12, incompatible with this project's `sdk: ^3.11.1` constraint (verified in STACK.md via changelog) |
| `supabase_flutter` | `^2.9.1` (locked `2.17.2`) | Backend client | Already the sole backend integration |
| `google_fonts` | `^8.2.0` | Typography (Caprasimo + Figtree) | Already installed; only the font family references in `app_typography.dart` need to change, not the package |

No `pubspec.yaml` changes are required for this phase. `flutter --version` confirms the installed toolchain (`Flutter 3.41.4`, `Dart 3.11.1`) matches the `^3.11.1` SDK constraint already in `pubspec.yaml` — `go_router ^17.3.0` and `flutter_riverpod ^3.3.2` are both compatible as-is `[VERIFIED: local flutter --version + pubspec.yaml]`.

### Supporting

None needed this phase — PDF/photo/notification libraries (STACK.md) belong to later feature phases (2–8).

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Hand-written `AsyncNotifier` | `riverpod_generator` + `build_runner` codegen | Rejected for this phase per STACK.md: adds a watch-mode build step and `.g.dart` churn while the whole app is being wired simultaneously; revisit once provider count is large (Phase 3+) |
| `WITH CHECK` column-comparison fix for `perfiles_update` | `BEFORE UPDATE` trigger rejecting `rol`/`clinica_id` changes | CONTEXT.md D-03 explicitly asks for the `WITH CHECK`-restriction approach; a trigger is a valid, slightly more defensive alternative (belt-and-suspenders) but is not what was decided — document as an optional hardening, not the primary fix |
| Deleting `home_screen.dart`'s non-login mock screens now | Leaving them in place as design reference until their real feature phase | CONTEXT.md only locks the *dashboard greeting* piece (D-01/D-02) and FOUND-06 only names `LoginScreen`/auth-domain dead code explicitly — treat the other four mock screens (`PatientsScreen`, `AgendaScreen`, `HistoryScreen`, `BillingScreen`) as **out of this phase's mandatory deletion list**; see Common Pitfalls for the recommended minimal placeholder approach instead |

**Installation:** none — no `flutter pub add` needed this phase.

## Package Legitimacy Audit

**Not applicable this phase.** No new external packages are installed — Phase 1 only wires already-declared, already-audited dependencies (`flutter_riverpod`, `go_router`, `supabase_flutter`, `google_fonts`) that are already present in `pubspec.lock` and already running in production code (auth flow). `slopcheck`/registry verification was not run because there is nothing new to verify.

## Architecture Patterns

### System Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│  App boot (main.dart)                                                     │
│  Supabase.initialize()  →  ProviderScope  →  ConsumerWidget VetApp        │
└───────────────────────────────┬───────────────────────────────────────────┘
                                 │ ref.watch(routerProvider)
                                 ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  routerProvider (Provider<GoRouter>)                                      │
│  redirect: reads authProfileProvider ── refreshListenable: _AuthRefresh   │
└───────┬───────────────────────────────────────────────────┬──────────────┘
        │ profile == null                                    │ profile != null
        ▼                                                     ▼
┌───────────────────┐                          ┌─────────────────────────────────┐
│ /login /register   │                          │ StatefulShellRoute.indexedStack │
│ /reset-password     │                          │  branches: /inicio /pacientes   │
│ (LoginScreen etc.)  │                          │  /agenda /clientes /mas          │
└─────────┬───────────┘                          └───────────────┬─────────────────┘
          │ signIn()                                              │
          ▼                                                       ▼
┌───────────────────────────────┐                    ┌─────────────────────────────┐
│ authRepositoryProvider          │◀──── ref.watch ───│ InicioScreen (ConsumerWidget)│
│ (SupabaseAuthRepository)        │                    │ ref.watch(authProfileProvider)│
└─────────────┬───────────────────┘                    └───────────────┬─────────────┘
              │ .signIn()/.profileForCurrentUser()                     │ AsyncValue.when
              ▼                                                        ▼
┌───────────────────────────────────────────────────────────────────────────┐
│ authProfileProvider (AsyncNotifier<AuthProfile?>)                          │
│ build(): reads currentSession, listens to onAuthStateChange, invalidates   │
└───────────────────────────────┬────────────────────────────────────────────┘
                                 │ .from('perfiles').select('...clinicas(nombre)')
                                 ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ Supabase Postgres — RLS enforced as `authenticated` role                  │
│ clinicas / perfiles / clientes (new) / mascotas                          │
└──────────────────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure (Phase 1 deltas only)

```
lib/
├── main.dart                                  # → MaterialApp.router, VetApp becomes ConsumerWidget
├── core/
│   ├── data/
│   │   └── supabase_client_provider.dart       # NEW — Provider<SupabaseClient>
│   ├── router/
│   │   └── app_router.dart                     # NEW — routerProvider, StatefulShellRoute, redirect
│   └── theme/
│       ├── app_colors.dart                     # EDIT — terracota/crema palette
│       └── app_typography.dart                 # EDIT — Caprasimo (display) + Figtree (body)
└── features/
    ├── auth/
    │   ├── domain/
    │   │   ├── auth_failure.dart               # EDIT — strip Firestore doc comments, keep type
    │   │   ├── repositories/auth_repository.dart   # DELETE (dead, Firebase-era)
    │   │   ├── entities/veterinario.dart            # DELETE (dead, Firebase-era)
    │   │   └── usecases/*.dart                      # DELETE (5 files, dead, Firebase-era)
    │   ├── data/repositories/supabase_auth_repository.dart   # unchanged (already the working pattern)
    │   └── presentation/
    │       ├── providers/auth_providers.dart    # NEW — authRepositoryProvider, authProfileProvider
    │       └── screens/                          # NEW — split LoginScreen/RegisterScreen/ResetPasswordScreen
    │           ├── login_screen.dart              #        out of auth_screens.dart (go_router-based nav)
    │           ├── register_screen.dart
    │           └── reset_password_screen.dart
    └── home/
        ├── presentation/
        │   ├── app_shell.dart                   # NEW — bottom nav shell (StatefulNavigationShell)
        │   └── screens/
        │       └── inicio_screen.dart            # NEW — Walking Skeleton dashboard
        └── home_screen.dart                      # EDIT/reduce — see Common Pitfalls
```

### Pattern 1: `Provider<SupabaseClient>` as the single injection point

**What:** One `Provider` wrapping `Supabase.instance.client`; every repository provider derives from it instead of constructing `SupabaseAuthRepository(Supabase.instance.client)` inline.
**When to use:** Immediately, before writing `authProfileProvider` — this is the foundation every later repository provider (clients, patients, ...) will copy.
**Example:**
```dart
// lib/core/data/supabase_client_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
```
Source: pattern confirmed in `.planning/research/ARCHITECTURE.md` Pattern 1 / Anti-Pattern 4, cross-checked against Riverpod 3 official docs (Context7 `/rrousselgit/riverpod`) for `Provider` semantics.

### Pattern 2: `authProfileProvider` — `AsyncNotifier<AuthProfile?>` replacing `AuthGate`

**What:** A single `AsyncNotifier` that (a) resolves the current session/profile on `build()`, and (b) re-runs itself whenever `onAuthStateChange` fires, so sign-in/sign-out/token-refresh propagate automatically to both the router and every screen watching it.
**When to use:** This is the phase's central provider — build it before the router, since the router's `redirect:` depends on it.
**Example:**
```dart
// lib/features/auth/presentation/providers/auth_providers.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/supabase_client_provider.dart';
import '../../data/repositories/supabase_auth_repository.dart';
import '../../domain/auth_failure.dart';

final authRepositoryProvider = Provider<SupabaseAuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

class AuthProfileNotifier extends AsyncNotifier<AuthProfile?> {
  StreamSubscription<dynamic>? _sub;

  @override
  Future<AuthProfile?> build() async {
    final repo = ref.watch(authRepositoryProvider);
    ref.onDispose(() => _sub?.cancel());
    _sub ??= repo.authStateChanges.listen((_) => ref.invalidateSelf());

    if (repo.currentSession == null) return null;
    try {
      return await repo.profileForCurrentUser();
    } on AuthFailure {
      await repo.signOut();
      return null;
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading<AuthProfile?>().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signIn(email: email, password: password),
    );
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(null);
  }
}

final authProfileProvider =
    AsyncNotifierProvider<AuthProfileNotifier, AuthProfile?>(AuthProfileNotifier.new);
```
`signIn`/`signUp` failures (`AuthFailure`) should still be caught in the *screen* for form-level error display (matching the existing `on AuthFailure catch (error) { setState(() => _error = error.message) }` pattern) rather than only surfaced via `AsyncValue.error` — call `ref.read(authRepositoryProvider).signIn(...)` directly from the login form's submit handler (not through the notifier's `signIn`) if you need the try/catch-per-field-error UX the current `LoginScreen` already has; use the notifier's own `signIn`/`signOut` only when the caller just needs the session to update and doesn't need a specific inline error string. Either approach is acceptable — pick one and keep it consistent between `LoginScreen`/`RegisterScreen`/`ResetPasswordScreen`.
Source: `AsyncNotifier`/`ref.onDispose`/`AsyncValue.guard` API confirmed against Riverpod 3 official docs (Context7 `/rrousselgit/riverpod`), HIGH confidence. `[CITED: riverpod.dev via Context7]`

### Pattern 3: `go_router` `StatefulShellRoute.indexedStack` + Riverpod `redirect:`

**What:** One `GoRouter` built inside a `Provider`, gated by a `redirect:` callback that reads `authProfileProvider`, with a `ChangeNotifier` bridge (`refreshListenable`) so route re-evaluation happens the instant the session changes, not just on next navigation.
**When to use:** Replaces `AuthGate` and every `Navigator.push(MaterialPageRoute(...))` call site (`auth_screens.dart:129-131`, `:144-146`; `home_screen.dart:502-504`, `:1243-1245`).
**Example:**
```dart
// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/home/presentation/app_shell.dart';
import '../../features/home/presentation/screens/inicio_screen.dart';

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authProfileProvider, (_, __) => notifyListeners());
  }
}

const _publicPaths = {'/login', '/register', '/reset-password'};

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshNotifier(ref);
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authProfileProvider);
      if (authState.isLoading) return null; // wait, don't bounce mid-load
      final profile = authState.valueOrNull;
      final onPublicPath = _publicPaths.contains(state.matchedLocation);
      if (profile == null) return onPublicPath ? null : '/login';
      if (onPublicPath) return '/inicio';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/reset-password', builder: (_, __) => const ResetPasswordScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/inicio', builder: (_, __) => const InicioScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/pacientes', builder: (_, __) => const _ComingSoonScreen(title: 'Pacientes')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/agenda', builder: (_, __) => const _ComingSoonScreen(title: 'Agenda')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/clientes', builder: (_, __) => const _ComingSoonScreen(title: 'Clientes')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/mas', builder: (_, __) => const _ComingSoonScreen(title: 'Más')),
          ]),
        ],
      ),
    ],
  );
});
```
```dart
// lib/features/home/presentation/app_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: navigationShell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      ),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
        NavigationDestination(icon: Icon(Icons.pets_outlined), selectedIcon: Icon(Icons.pets), label: 'Pacientes'),
        NavigationDestination(icon: Icon(Icons.calendar_today_outlined), selectedIcon: Icon(Icons.calendar_today), label: 'Agenda'),
        NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Clientes'),
        NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Más'),
      ],
    ),
  );
}
```
```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
  }
  runApp(const ProviderScope(child: VetApp()));
}

class VetApp extends ConsumerWidget {
  const VetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'VetApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
```
Note: the `supabaseConfigured`-false "degraded mode" branch that `AuthGate` currently handles (rendering `LoginScreen` with a config-missing message) has no direct `redirect:` equivalent — since FOUND-01 makes a real cloud project mandatory for this phase, it's acceptable to drop that branch entirely rather than port it; if kept, gate it in `main()` before `runApp` (show a plain `MaterialApp` error screen), not inside the router.
Source: `StatefulShellRoute.indexedStack` + `ChangeNotifier` `refreshListenable` bridge pattern cross-verified across `.planning/research/ARCHITECTURE.md` Pattern 3, STACK.md, and the official `go_router` topic docs referenced there (`go_router` package README/`StatefulShellRoute` API — Context7-equivalent, MEDIUM-HIGH confidence per multiple independent community sources agreeing on the same bridge shape). `[CITED: pub.dev/packages/go_router + community sources per STACK.md]`

### Pattern 4: Walking Skeleton `InicioScreen`

**What:** A real `ConsumerWidget` reading `authProfileProvider`, rendering `AsyncValue.when(loading/error/data)`, using `AppCard`/`AppTopBar`/design tokens.
**When to use:** Last step before dead-code removal — depends on Patterns 1-3 and the updated theme tokens.
**Example:**
```dart
// lib/features/home/presentation/screens/inicio_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bar/app_top_bar.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(authProfileProvider);
    return Scaffold(
      appBar: const AppTopBar(title: 'Inicio'),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('No hay una sesión activa.'));
          }
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hola, ${profile.nombre}',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(profile.clinicaNombre ?? 'Sin clínica asignada',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const Center(
          child: Text('No pudimos cargar tu perfil. Intenta de nuevo.'),
        ),
      ),
    );
  }
}
```
Per CONTEXT.md D-02: do not add metric cards (consultas/ingresos/próximas citas) here — that is explicitly Phase 8. This screen's only job is proving the real-data pipe works end to end.

### Anti-Patterns to Avoid

- **Mixing `Navigator.push` with `go_router` after this phase lands:** produces inconsistent back-stack behavior (STACK.md "What NOT to Use"); every screen-to-screen transition must use `context.go()`/`context.push()` once the router is wired.
- **Constructing `SupabaseAuthRepository(Supabase.instance.client)` inline in any new widget:** the exact anti-pattern already present 3× in the current `auth_screens.dart` (`CONCERNS.md`) — every new call site must go through `authRepositoryProvider`.
- **Leaving `mascotas`' RLS policies half-migrated:** if `dueno_id` is repointed to `clientes` but the `dueno_id = auth.uid()` policy clauses aren't removed, the policies still *parse* and *apply* (both are `uuid` columns) but become permanently false/dead conditions that silently make `mascotas` inaccessible to anyone except vets — an easy-to-miss bug because it fails closed (looks like "no data" rather than an error).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|--------------|-----|
| Auth-gated routing | A custom widget re-implementing `AuthGate`'s role branching | `go_router`'s `redirect:` + `StatefulShellRoute.indexedStack` | Already the Flutter-team-maintained standard; hand-rolling it means re-solving back-stack/deep-link edge cases `go_router` already handles |
| Cross-provider auth-state → router refresh | Polling or manual `setState` calls to force router re-evaluation | `ChangeNotifier` bridge + `GoRouter.refreshListenable` | This is the documented, only-supported way to make `redirect:` re-run outside of a navigation event (Pattern 3 above) |
| RLS role-impersonation for testing | A custom Dart test harness hitting the anon key with fake JWTs | Supabase SQL Editor `set local role authenticated; set local "request.jwt.claims" = '...'` inside a `begin; ... rollback;` block | Standard, documented Postgres/Supabase technique — zero code, runs directly against the real policies, no test framework needed for this phase per D-03 |

**Key insight:** every capability this phase needs (route guarding, state-driven refresh, RLS impersonation) already has a standard, narrow tool — the risk is *not adopting* them (Pitfall #4), not needing to build something custom.

## Common Pitfalls

### Pitfall 1: `perfiles_update` privilege escalation (the exact bug, verified by direct schema read)

**What goes wrong:** The current policy is:
```sql
create policy perfiles_update on public.perfiles for update to authenticated
using (id = auth.uid()) with check (id = auth.uid());
```
This lets *any* authenticated user — including a `CLIENTE` — run `update perfiles set rol = 'VETERINARIO', clinica_id = '<any-clinic-uuid>' where id = auth.uid()`. Because `es_veterinario()` and `mi_clinica_id()` (used by every other table's RLS) read straight from this same row, that single `UPDATE` grants the attacker full read access to an arbitrary clinic's `clinicas`/`mascotas` data.
**Why it happens:** The `WITH CHECK` only re-asserts `id = auth.uid()` (ownership), never restricts *which columns* can change.
**How to avoid — the fix (matches CONTEXT.md D-03: restrict via `WITH CHECK`):**
```sql
drop policy if exists perfiles_update on public.perfiles;
create policy perfiles_update on public.perfiles for update to authenticated
using (id = auth.uid())
with check (
  id = auth.uid()
  and rol = (select p.rol from public.perfiles p where p.id = auth.uid())
  and clinica_id is not distinct from
    (select p.clinica_id from public.perfiles p where p.id = auth.uid())
);
```
This works because, within a single `UPDATE` statement, the subquery against `perfiles` sees the pre-update snapshot (Postgres command-ID visibility rules), so `rol`/`clinica_id` in the *new* row are forced to equal what they already were — any attempt to change either value fails the check. `[CITED: PITFALLS.md Pitfall 2, cross-referencing makerkit.dev RLS best practices — MEDIUM confidence pattern, verify by running the negative smoke test below before relying on it]`
**Optional stronger alternative (not required by D-03, note for planner):** a `BEFORE UPDATE` trigger that explicitly `RAISE EXCEPTION` if `OLD.rol IS DISTINCT FROM NEW.rol OR OLD.clinica_id IS DISTINCT FROM NEW.clinica_id` is more explicit/auditable than the subquery trick and doesn't rely on snapshot-visibility semantics — mention as a hardening option, but the `WITH CHECK` fix above satisfies D-03/FOUND-05 as decided.
**Warning signs:** Any future `perfiles_update`-style policy that only checks `id = auth.uid()` with no column restriction.
**Phase to address:** This phase, before any other table trusts `es_veterinario()`/`mi_clinica_id()`.

### Pitfall 2: `mascotas` RLS silently breaks once `dueno_id` no longer points at an authenticated user

**What goes wrong:** Today's `mascotas_select`/`insert`/`update`/`delete` policies all include a `dueno_id = auth.uid()` clause (the "client sees their own pet" case). Once `dueno_id` is repointed at the new `clientes` table (FOUND-04), `auth.uid()` will *never* equal a `clientes.id` (clients have no `auth.users` row) — the clause becomes permanently `false`, not an error. If the vet-scoped `OR` clause (`es_veterinario() and clinica_id = mi_clinica_id()`) is dropped or mis-written during this edit, `mascotas` becomes silently inaccessible to everyone.
**How to avoid:** Rewrite all four `mascotas` policies to drop the `dueno_id = auth.uid()` branch entirely, keeping only the vet/clinic-scoped clause (exact SQL below). Verify with the positive smoke test (vet can read their clinic's `mascotas`) immediately after applying.
**Phase to address:** This phase, as part of the `clientes` migration.

### Pitfall 3: Reusing the same `AsyncNotifier` instance across an async gap

**What goes wrong:** Per PITFALLS.md #5, the most-cited Riverpod bug is caching `ref.read(provider.notifier)` in a local variable before an `await`, then calling a method on it after the provider was disposed/rebuilt.
**How to avoid:** Always `ref.read(authProfileProvider.notifier).signOut()` inline at the call site, never store the notifier reference across an `await`.
**Phase to address:** This phase's reference implementation (`auth_providers.dart`) sets the pattern every later feature copies — get it right once.

### Pitfall 4: `home_screen.dart` monolith — do not silently keep it wired

**What goes wrong:** `_VeterinarianHome` currently returns `const HomeScreen()` (the 1400-line mock). Once `AuthGate` is deleted and replaced by the router, `HomeScreen`/`_HomeScreenState` (the old `IndexedStack`/`NavigationRail` shell) becomes **unreachable dead code** — but only if every reference to it is actually removed. If `_VeterinarianHome` or `AuthGate` survive as a fallback "just in case," the mock silently keeps working alongside the real router and confuses QA (exactly the risk flagged in Pitfall #4 of PITFALLS.md and CONCERNS.md's fragile-file writeup).
**How to avoid:**
- Delete `AuthGate`, `_VeterinarianHome`, `ClientHomeScreen`'s current inline definition (move `ClientHomeScreen`'s content to its own file if kept as a future stub, or delete if a placeholder route is preferred), and the `HomeScreen`/`_HomeScreenState` nav-shell class — all superseded by `AppShell` + `StatefulShellRoute`.
- Delete the duplicate mock `LoginScreen` inside `home_screen.dart` (explicit FOUND-06 item).
- For the four remaining static mock screens (`PatientsScreen`, `AgendaScreen`, `HistoryScreen`, `BillingScreen`) — **not** explicitly named in FOUND-06 — the minimal, in-scope move is to replace their route destinations with the tiny `_ComingSoonScreen` placeholder shown in Pattern 3 above (a one-line "Próximamente" `Scaffold`) and delete the old mock classes, rather than porting 1000+ lines of hardcoded-data mock UI into "real" feature folders that don't have backing data yet. This keeps the phase's own "no dead code" bar (FOUND-06's spirit) without scope-creeping into Phase 2-8 work. Flag this choice for the planner — it is Claude's Discretion per CONTEXT.md, not a locked decision, so a plan-checker/human may prefer to relocate the mocks instead of deleting them.
**Phase to address:** This phase, as the final step (after the real `InicioScreen` exists and is reachable).

### Pitfall 5: Signup trigger untouched but must still work after schema changes

**What goes wrong:** `crear_perfil_nuevo_usuario` (the `on_auth_user_created` trigger) is not being changed this phase, but any schema edit to `perfiles`/`clinicas` risks silently breaking it (PITFALLS.md #3) if columns it references are renamed. This phase's edits (`clientes` table, `mascotas.dueno_id` FK swap) do **not** touch `perfiles`/`clinicas` columns, so the trigger is not at direct risk — but **must be re-verified with a live signup** after applying the schema, since this is the first time `schema.sql` runs against a real project at all.
**How to avoid:** After applying `schema.sql`, immediately run one real signup for each role (`VETERINARIO`, `CLIENTE`) through the app or via `supabase.auth.signUp` in a throwaway script, and confirm the correct `perfiles`/`clinicas` rows appear. Do this before writing any Riverpod/go_router code, since the walking skeleton depends on being able to log in.
**Phase to address:** This phase, immediately after schema apply, before wiring code.

## Code Examples

### Exact `clientes` table + RLS (FOUND-04)

```sql
-- Clientes: dueños de mascotas gestionados por el veterinario, sin cuenta propia.
create table if not exists public.clientes (
  id uuid primary key default gen_random_uuid(),
  clinica_id uuid not null references public.clinicas(id) on delete cascade,
  nombre text not null check (length(trim(nombre)) > 0),
  telefono text not null default '',
  email text,
  direccion text not null default '',
  notas text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists clientes_clinica_id_idx on public.clientes(clinica_id);

alter table public.clientes enable row level security;

drop policy if exists clientes_select on public.clientes;
create policy clientes_select on public.clientes for select to authenticated
using (public.es_veterinario() and clinica_id = public.mi_clinica_id());

drop policy if exists clientes_insert on public.clientes;
create policy clientes_insert on public.clientes for insert to authenticated
with check (public.es_veterinario() and clinica_id = public.mi_clinica_id());

drop policy if exists clientes_update on public.clientes;
create policy clientes_update on public.clientes for update to authenticated
using (public.es_veterinario() and clinica_id = public.mi_clinica_id())
with check (public.es_veterinario() and clinica_id = public.mi_clinica_id());

drop policy if exists clientes_delete on public.clientes;
create policy clientes_delete on public.clientes for delete to authenticated
using (public.es_veterinario() and clinica_id = public.mi_clinica_id());
```

### Exact `mascotas` FK repoint + RLS rewrite

Since the target Supabase project is confirmed empty (schema not yet applied), the simplest path is editing `schema.sql`'s `mascotas` table definition directly (no `ALTER TABLE` migration needed) before the one-time apply:

```sql
-- BEFORE (current schema.sql):
--   dueno_id uuid not null references public.perfiles(id) on delete cascade,
--   clinica_id uuid references public.clinicas(id) on delete cascade,

-- AFTER:
create table if not exists public.mascotas (
  id uuid primary key default gen_random_uuid(),
  dueno_id uuid not null references public.clientes(id) on delete cascade,
  clinica_id uuid not null references public.clinicas(id) on delete cascade,
  nombre text not null check (length(trim(nombre)) > 0),
  especie text not null,
  raza text not null default '',
  fecha_nacimiento date,
  created_at timestamptz not null default now()
);
```
(`clinica_id` is tightened to `not null` — every `mascota` now always belongs to the creating vet's clinic; there is no more "client-owned, unassigned clinic" case since clients don't authenticate.)

```sql
-- Mascotas: solo el veterinario de la clínica puede leer/escribir (no hay dueño autenticado).
drop policy if exists mascotas_select on public.mascotas;
create policy mascotas_select on public.mascotas for select to authenticated
using (public.es_veterinario() and clinica_id = public.mi_clinica_id());

drop policy if exists mascotas_insert on public.mascotas;
create policy mascotas_insert on public.mascotas for insert to authenticated
with check (public.es_veterinario() and clinica_id = public.mi_clinica_id());

drop policy if exists mascotas_update on public.mascotas;
create policy mascotas_update on public.mascotas for update to authenticated
using (public.es_veterinario() and clinica_id = public.mi_clinica_id())
with check (public.es_veterinario() and clinica_id = public.mi_clinica_id());

drop policy if exists mascotas_delete on public.mascotas;
create policy mascotas_delete on public.mascotas for delete to authenticated
using (public.es_veterinario() and clinica_id = public.mi_clinica_id());
```

**If Supabase CLI / migrations are adopted later** (PITFALLS.md recommends this, not required this phase per CONTEXT.md discretion on task ordering): the equivalent `ALTER TABLE` for a non-empty table would be `alter table public.mascotas drop constraint mascotas_dueno_id_fkey; alter table public.mascotas add constraint mascotas_dueno_id_fkey foreign key (dueno_id) references public.clientes(id) on delete cascade;` — not needed now since the project has zero rows.

### RLS manual smoke test (FOUND-05, D-03/D-04) — run in Supabase SQL Editor

Setup: create two throwaway `VETERINARIO` accounts (Clínica A, Clínica B) and one `CLIENTE` account via the app's real sign-up flow first (this also exercises Pitfall 5's signup-trigger check). Note their `auth.users.id` values, then run:

```sql
-- === Impersonate Vet A (positive tests: sees own clinic's data) ===
begin;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub": "<VET_A_UUID>", "role": "authenticated"}';

  select * from public.clinicas;              -- expect: 1 row (Vet A's clinic)
  select * from public.perfiles;               -- expect: rows scoped to Vet A's clinic + own row
  select * from public.clientes;                -- expect: only Clínica A's clientes (0 initially)
  select * from public.mascotas;                -- expect: only Clínica A's mascotas (0 initially)

  insert into public.clientes (clinica_id, nombre, telefono)
    values ('<CLINICA_A_ID>', 'Cliente de prueba A', '3001234567'); -- expect: succeeds
rollback;

-- === Impersonate Vet A again: negative test against Clinic B's data ===
begin;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub": "<VET_A_UUID>", "role": "authenticated"}';

  select * from public.clinicas where id = '<CLINICA_B_ID>';   -- expect: 0 rows
  select * from public.clientes where clinica_id = '<CLINICA_B_ID>'; -- expect: 0 rows (RLS-filtered, not an error)

  insert into public.clientes (clinica_id, nombre, telefono)
    values ('<CLINICA_B_ID>', 'Intento cruzado', '3000000000'); -- expect: ERROR — new row violates RLS policy
rollback;

-- === Impersonate the CLIENTE account: negative privilege-escalation test (Pitfall 1 fix) ===
begin;
  set local role authenticated;
  set local "request.jwt.claims" = '{"sub": "<CLIENTE_UUID>", "role": "authenticated"}';

  update public.perfiles set rol = 'VETERINARIO' where id = '<CLIENTE_UUID>'; -- expect: 0 rows updated (WITH CHECK blocks it) or ERROR
  update public.perfiles set clinica_id = '<CLINICA_A_ID>' where id = '<CLIENTE_UUID>'; -- expect: same, blocked

  select * from public.clinicas;    -- expect: 0 rows (CLIENTE has no es_veterinario())
  select * from public.clientes;     -- expect: 0 rows
rollback;
```

Every `begin; ... rollback;` block leaves no residue — safe to run repeatedly against the real project. Record pass/fail for each of the 4 tables (`clinicas`, `perfiles`, `clientes`, `mascotas`) × {positive, negative} before considering FOUND-05/D-04 satisfied.
`[CITED: Supabase RLS testing technique — role/JWT-claim impersonation via SET LOCAL, consistent with makerkit.dev and Supabase community guidance referenced in PITFALLS.md; MEDIUM confidence — this is the standard manual technique, not pgTAP, matching D-03's explicit "manual, not automated suite" decision]`

## Design Tokens Update (Walking Skeleton prerequisite)

Current `app_colors.dart` (green palette) does **not** match the approved mockup. Exact replacement values from `.planning/design/DESIGN-REFERENCE.md` (already extracted from the approved HTML mockup, `[CITED: .planning/design/DESIGN-REFERENCE.md]`):

```dart
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFFC67139);        // terracota
  static const Color primaryHover = Color(0xFFD67F48);
  static const Color primaryStrong = Color(0xFF8C491A);
  static const Color onPrimary = Color(0xFFFFFFFF);

  static const Color background = Color(0xFFF5EAD8);      // crema
  static const Color backgroundAlt = Color(0xFFF0EEE6);
  static const Color surface = Color(0xFFEEE7DB);
  static const Color surfaceMuted = Color(0xFFEBDDC5);
  static const Color border = Color(0xFFDCD3C4);

  static const Color foreground = Color(0xFF201E1D);       // text-primary
  static const Color textSecondary = Color(0xFF474238);
  static const Color textMuted = Color(0xFF645C50);
  static const Color placeholder = Color(0xFF82796A);

  static const Color success = Color(0xFF56633F);
  static const Color successBg = Color(0xFFF0FAE1);
  static const Color warningBg = Color(0xFFFFF2EB);
  static const Color destructive = Color(0xFFDC2626); // not in mockup extract — keep existing Material-safe red
  static const Color onDestructive = Color(0xFFFFFFFF);
}
```
Note: DESIGN-REFERENCE.md only documents light-mode values (it was extracted from a static mockup render) — dark-mode terracota tokens are not sourced from the approved design and must either be derived (darken the same hues) or flagged for the UI phase (`/gsd:ui-phase`) to confirm with the user; do not invent dark-mode values here. `[ASSUMED: no dark-mode terracota palette exists yet — flag for confirmation]`

`app_typography.dart` must switch the display/heading font family from `GoogleFonts.figtreeTextTheme()` to `GoogleFonts.caprasimoTextTheme()` for `displayLarge`/`displayMedium`/`displaySmall`/`headlineLarge`/`headlineMedium`/`headlineSmall`/`titleLarge` (per DESIGN-REFERENCE.md: "Display/headings: Caprasimo... usado en título de marca y nombres de pacientes/encabezados de pantalla"), keeping Figtree (not Noto Sans) for body text: `GoogleFonts.figtreeTextTheme()` as the `bodyBase`. Verify `google_fonts ^8.2.0` ships a `caprasimoTextTheme()` helper before relying on it — Caprasimo is a single-weight display font on Google Fonts, so `GoogleFonts.caprasimo()` (single `TextStyle` getter) may be the only available API rather than a full `TextTheme` helper; if so, apply it manually per text style (`displayLarge: GoogleFonts.caprasimo(textStyle: ...)`) rather than via a `*TextTheme()` bulk helper. `[ASSUMED: google_fonts package API for Caprasimo — verify exact helper name against the installed package before writing the final implementation]`

## Dead Code Removal (FOUND-06) — Exact File List

| File | Action | Reason |
|------|--------|--------|
| `firebase.json` (repo root) | Delete | Orphaned Firebase project config (`vetapp-colombia`), no `firebase_core`/`firebase_auth` in `pubspec.yaml` |
| `android/app/google-services.json` | Delete | Same — orphaned Firebase Android config |
| `lib/features/auth/domain/repositories/auth_repository.dart` | Delete | Unused interface, never implemented by `SupabaseAuthRepository`, Firestore-era doc comments |
| `lib/features/auth/domain/entities/veterinario.dart` | Delete | Unused entity, Firestore-era doc comments ("cuelgan de `veterinarios/{id}` en Firestore") |
| `lib/features/auth/domain/usecases/sign_in_with_email.dart` | Delete | Unused, never called (presentation calls `SupabaseAuthRepository` directly) |
| `lib/features/auth/domain/usecases/sign_in_with_google.dart` | Delete | Unused AND unimplemented — no `signInWithGoogle` method exists anywhere in the data layer either (`CONCERNS.md`) |
| `lib/features/auth/domain/usecases/sign_up_with_email.dart` | Delete | Unused, never called |
| `lib/features/auth/domain/usecases/sign_out.dart` | Delete | Unused, never called |
| `lib/features/auth/domain/usecases/watch_current_veterinario.dart` | Delete | Unused, never called |
| `lib/features/auth/domain/auth_failure.dart` | **Keep, edit** | Still the real exception type used by `SupabaseAuthRepository` and (per this research) `authProfileProvider` — only remove its Firestore-flavored doc-comment header |
| `lib/features/home/home_screen.dart` — `LoginScreen` class | Delete | Explicit FOUND-06 item: "LoginScreen duplicado" |
| `lib/features/home/home_screen.dart` — `HomeScreen`/`_HomeScreenState` | Delete | Superseded by `AppShell` + `StatefulShellRoute` (Pitfall 4) |
| `lib/features/auth/presentation/auth_screens.dart` — `AuthGate` | Delete | Superseded by `routerProvider`'s `redirect:` |
| `lib/features/auth/presentation/auth_screens.dart` — `_VeterinarianHome` | Delete | No longer needed — router routes `/inicio` directly |
| `lib/features/home/home_screen.dart` — remaining mock screens (`DashboardScreen`, `PatientsScreen`, `AgendaScreen`, `HistoryScreen`, `VaccinationScreen`, `InventoryScreen`, `BillingScreen`) | Delete (recommended) or relocate — see Pitfall 4 | Not explicitly named by FOUND-06; flagged as discretion, recommend deleting in favor of the `_ComingSoonScreen` placeholder to fully satisfy "no dead code" |

`ClientHomeScreen` (currently inline in `auth_screens.dart`): keep as a real class but move to its own file (e.g. `lib/features/auth/presentation/screens/client_home_screen.dart`) and wire it as a route target for a future client-facing entry point — it is not dead code (SCALE-01 will build on it later), just currently mis-located.

## Runtime State Inventory

This phase is not a rename/refactor/migration of existing production data — the target Supabase project is confirmed empty (`schema.sql` never applied). The Runtime State Inventory is included for completeness since the phase does perform a schema redesign (`clientes` table, `mascotas.dueno_id` FK swap):

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — target Supabase project is verified empty (no `clientes`/`mascotas` rows exist anywhere to migrate) | None |
| Live service config | None — no n8n/Datadog/Tailscale/Cloudflare Tunnel or other externally-configured services reference this schema | None |
| OS-registered state | None — no scheduled tasks, pm2 processes, or systemd units reference `dueno_id`/`perfiles` | None |
| Secrets/env vars | `SUPABASE_URL`/`SUPABASE_ANON_KEY` (via `--dart-define`) are unaffected — schema changes don't change project URL/keys | None |
| Build artifacts | None — no compiled server-side artifacts reference the old `mascotas.dueno_id → perfiles` FK | None |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `google_fonts ^8.2.0` exposes `GoogleFonts.caprasimo()`/`caprasimoTextTheme()` with this exact API shape | Design Tokens Update | Low — if the helper name differs, it's a compile error caught immediately, not a silent runtime issue; planner should verify against the installed package's generated font list before writing the final `app_typography.dart` edit |
| A2 | The `WITH CHECK` subquery-comparison pattern for `perfiles_update` reliably blocks `rol`/`clinica_id` changes under Postgres's command-visibility snapshot rules | Common Pitfalls / Pitfall 1 | Medium — if snapshot semantics behave unexpectedly (e.g., under a specific Postgres/Supabase version), the fix could be a no-op; **this is exactly why the manual smoke test's negative case for `perfiles` is mandatory before considering FOUND-05 done**, not optional |
| A3 | No dark-mode terracota palette values exist beyond the light-mode extraction in DESIGN-REFERENCE.md | Design Tokens Update | Low — worst case, dark mode looks inconsistent until a UI phase confirms values; does not block FOUND criteria (none require dark mode) |

## Open Questions

1. **Should `ClientHomeScreen` get a real route in this phase's router, or stay unrouted until a later phase?**
   - What we know: It exists today, is reachable via `AuthGate` for `rol == 'CLIENTE'` accounts, and self-registration for `CLIENTE` role remains open (D-05 only addresses `VETERINARIO`).
   - What's unclear: CONTEXT.md's walking skeleton scope (D-01/D-02) only discusses the vet-facing `Inicio` screen; it's silent on whether a `CLIENTE` who logs in during this phase should see anything at all.
   - Recommendation: Add a minimal `/cliente` route (reusing the existing `ClientHomeScreen` content, relocated per the Dead Code table) gated by the same `redirect:`, so a `CLIENTE` login doesn't dead-end or crash — this is a small addition, not new feature scope, and keeps the existing self-registration path functional per D-05.

2. **Does `perfiles_insert`'s existing `rol = 'CLIENTE' and clinica_id is null` restriction need any change given the new `clientes` table?**
   - What we know: `perfiles_insert` already prevents a self-registering user from setting `rol = 'VETERINARIO'` or a non-null `clinica_id` directly (only the trigger, running as `security definer`, can do that).
   - What's unclear: Nothing found requiring a change — the new `clientes` table is a parallel, vet-managed structure and doesn't interact with `perfiles_insert` at all.
   - Recommendation: No change needed; confirmed via schema read, not a gap.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (bundled with Flutter SDK, already a dev dependency) |
| Config file | none — no dedicated test config exists; `test/widget_test.dart` uses the default `flutter_test` + `pumpWidget` style |
| Quick run command | `flutter test test/widget_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FOUND-01 | Schema applies cleanly, signup trigger still works | manual-only (SQL Editor + real signup) | n/a — see Pitfall 5 smoke check | n/a |
| FOUND-02 | App boots to `/login` when unauthenticated, routes to `/inicio` after sign-in | widget | `flutter test test/widget_test.dart` (update existing test to pump `ProviderScope(child: VetApp())` and assert on the router's initial route content) | ✅ Wave 0 (update existing file) |
| FOUND-03 | No `setState` on data screens; `authProfileProvider` drives `InicioScreen` | widget (indirect — assert `InicioScreen` renders the profile's `nombre`) | `flutter test` | ❌ Wave 0 — add `test/inicio_screen_test.dart` with a fake `SupabaseAuthRepository`-shaped override via `ProviderScope(overrides: [...])` |
| FOUND-04 | `clientes` table exists, decoupled from `perfiles` | manual-only (SQL Editor: `insert into clientes` as vet, confirm no `auth.users` FK requirement) | n/a | n/a |
| FOUND-05 | RLS blocks cross-tenant + self-escalation, tested as `authenticated` | manual-only (locked by D-03 — no automated suite this phase) | n/a — see RLS smoke test script above | n/a |
| FOUND-06 | No Firebase dead code remains | static check | `grep -ril "firebase\|Firestore" lib/ --include=*.dart` (should return zero matches after cleanup) plus `flutter analyze` (unused-import/dead-code lints) | n/a (verification command, not a test file) |

### Sampling Rate
- **Per task commit:** `flutter analyze && flutter test test/widget_test.dart`
- **Per wave merge:** `flutter test` (full suite, currently 1-2 files)
- **Phase gate:** Full suite green + RLS manual smoke test script fully run and recorded (pass/fail per table×direction) before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/widget_test.dart` — currently asserts on `AuthGate`/`LoginScreen` copy directly; must be rewritten for `MaterialApp.router` + `ProviderScope` boot path (covers FOUND-02's "app boots correctly" behavior)
- [ ] `test/inicio_screen_test.dart` — new, needed to cover FOUND-03's "no direct setState" requirement with an actual assertion (override `authRepositoryProvider`/`authProfileProvider` with a fake so the test doesn't require live Supabase)
- [ ] No framework install needed — `flutter_test` is already present

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | Yes | Delegated entirely to `supabase_flutter`'s `SupabaseClient.auth` (email/password) — unchanged this phase, do not hand-roll |
| V3 Session Management | Yes | `supabase_flutter` handles token storage/refresh; `authProfileProvider` only *reads* `onAuthStateChange`, never manages tokens directly |
| V4 Access Control | Yes — **primary focus of this phase** | Postgres RLS exclusively (`clinicas`/`perfiles`/`clientes`/`mascotas` policies) — this phase's core deliverable is hardening this category |
| V5 Input Validation | Partial | Postgres `check` constraints (e.g. `length(trim(nombre)) > 0`) are the server-side backstop; client-side form validation (existing `_submit()` pattern) remains the first line, unchanged this phase |
| V6 Cryptography | No | Supabase manages encryption at rest/in transit by default; nothing hand-rolled this phase |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|----------------------|
| Vertical privilege escalation via mutable role column (`perfiles.rol`) | Elevation of Privilege | `WITH CHECK` column-comparison restriction (Pitfall 1 fix, this phase) |
| Horizontal/cross-tenant data leakage (`clinica_id` boundary) | Information Disclosure | RLS `USING`/`WITH CHECK` scoped to `mi_clinica_id()` on every table, verified via the manual smoke test (RLS section above) |
| RLS policy silently becomes a dead/false condition after a schema change (Pitfall 2, `mascotas.dueno_id` FK repoint) | Information Disclosure (fails closed, but masks the real bug — data becomes invisible to legitimate users, not exposed to illegitimate ones) | Explicit rewrite of all four `mascotas` policies (SQL above), verified with the positive smoke test immediately after |
| Self-service `VETERINARIO` signup with no verification (pre-existing, explicitly NOT fixed this phase per D-05) | Spoofing (of clinic-admin identity) | Out of scope this phase by explicit user decision (D-05) — documented here only so it isn't mistaken for an oversight |

## Sources

### Primary (HIGH confidence)
- Direct reads: `supabase/schema.sql`, `lib/main.dart`, `lib/features/auth/presentation/auth_screens.dart`, `lib/features/auth/data/repositories/supabase_auth_repository.dart`, `lib/core/theme/app_colors.dart`, `lib/core/theme/app_typography.dart`, `lib/core/theme/app_theme.dart`, `lib/core/widgets/cards/app_card.dart`, `lib/core/widgets/app_bar/app_top_bar.dart`, `pubspec.yaml` — this session, 2026-09-24
- `flutter --version` / `dart --version` (local environment probe) — confirms `Flutter 3.41.4` / `Dart 3.11.1`, matches `pubspec.yaml`'s `sdk: ^3.11.1` constraint
- `.planning/research/ARCHITECTURE.md`, `.planning/research/PITFALLS.md`, `.planning/research/STACK.md`, `.planning/research/SUMMARY.md` — project-level research, 2026-09-23, verified against Riverpod 3 official docs via Context7 and pub.dev API/changelogs
- `.planning/codebase/ARCHITECTURE.md`, `.planning/codebase/STRUCTURE.md`, `.planning/codebase/CONCERNS.md` — first-party codebase audit, 2026-09-24
- `.planning/design/DESIGN-REFERENCE.md` — palette/typography extracted from the user-approved mockup HTML, 2026-09-24

### Secondary (MEDIUM confidence)
- `WITH CHECK` old-vs-new column comparison pattern for privilege-escalation prevention — cited in `.planning/research/PITFALLS.md` Pitfall 2, sourced from [Supabase RLS Best Practices — Makerkit](https://makerkit.dev/blog/tutorials/supabase-rls-best-practices)
- `StatefulShellRoute.indexedStack` + `ChangeNotifier` refresh-bridge pattern — cross-corroborated across `.planning/research/ARCHITECTURE.md`/`STACK.md` citing [ApparenceKit](https://apparencekit.dev/blog/flutter-riverpod-gorouter-redirect/), [Dinko Marinac](https://dinkomarinac.dev/blog/guarding-routes-in-flutter-with-gorouter-and-riverpod/), [Q Agency](https://q.agency/blog/handling-authentication-state-with-go_router-and-riverpod/)
- Supabase SQL Editor role/JWT-claim impersonation technique for manual RLS testing — standard documented Postgres/Supabase community technique, referenced via `.planning/research/PITFALLS.md` Pitfall 1

### Tertiary (LOW confidence)
- `google_fonts` package's exact Caprasimo API surface (`caprasimo()` vs. `caprasimoTextTheme()`) — not independently verified against the live package source this session; flagged in Assumptions Log (A1)

## Metadata

**Confidence breakdown:**
- Standard stack (Riverpod/go_router wiring): HIGH — no new packages, patterns already verified against official docs in prior-day project research and cross-checked against this codebase's actual files this session
- RLS fix / `clientes` schema: HIGH for the bug identification (verified by direct schema read) and RLS testing methodology; MEDIUM for the exact `WITH CHECK` subquery-comparison mechanism (Postgres snapshot-visibility behavior — mandate the negative smoke test to confirm, not just trust the pattern)
- Design tokens: HIGH for palette values (sourced directly from the approved mockup's extracted DESIGN-REFERENCE.md); LOW for the exact `google_fonts` Caprasimo API shape (flagged, verify before implementing)
- Dead code removal: HIGH — every file in the list was directly confirmed unused/orphaned via codebase reads this session and prior CONCERNS.md audit

**Research date:** 2026-09-24
**Valid until:** 7 days (fast-moving phase — schema/RLS decisions here are foundational for every later phase; re-verify if the phase isn't started within a week, especially the `google_fonts` API assumption and package versions)

---
*Research for: Phase 1 — Fundación (VetApp)*
*Researched: 2026-09-24*
