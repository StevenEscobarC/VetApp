# Phase 1: Fundación - Pattern Map

**Mapped:** 2026-09-24
**Files analyzed:** 22 (new/modified/deleted, excluding pure entity-domain no-ops)
**Analogs found:** 14 exact/role-match / 22 total (8 are genuinely new patterns for this codebase — first-ever Riverpod/go_router usage — analog is RESEARCH.md's fully-specified Code Examples, not an existing file)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `supabase/schema.sql` (EDIT: `clientes` table, `perfiles_update` fix, `mascotas` FK+RLS rewrite) | migration | CRUD | `supabase/schema.sql` (itself — existing `clinicas`/`perfiles`/`mascotas` tables+RLS) | exact |
| `lib/core/data/supabase_client_provider.dart` (NEW) | provider | request-response | none in codebase (first Riverpod provider) — RESEARCH.md Pattern 1 | new-pattern |
| `lib/features/auth/presentation/providers/auth_providers.dart` (NEW) | provider/service | event-driven (auth-state stream) | `lib/features/auth/data/repositories/supabase_auth_repository.dart` (error-handling/session pattern to wrap) + RESEARCH.md Pattern 2 | role-match (error handling) / new-pattern (AsyncNotifier shape) |
| `lib/core/router/app_router.dart` (NEW) | route/config | request-response | none in codebase (first go_router usage) — RESEARCH.md Pattern 3 | new-pattern |
| `lib/features/home/presentation/app_shell.dart` (NEW) | component (shell) | request-response | `lib/features/home/home_screen.dart` — `_HomeScreenState.build()` (`NavigationRail`/`NavigationBar` + `IndexedStack`, lines 122-201) | role-match (nav-destination list shape reusable; index mechanism replaced by `StatefulNavigationShell`) |
| `lib/main.dart` (EDIT: `MaterialApp` → `MaterialApp.router`, `StatefulWidget` → `ConsumerWidget`) | config/entry-point | request-response | `lib/main.dart` (itself) | exact |
| `lib/features/auth/presentation/screens/login_screen.dart` (NEW, extracted) | component (screen) | request-response | `lib/features/auth/presentation/auth_screens.dart` — `LoginScreen`/`_LoginScreenState` (lines 67-153) | exact |
| `lib/features/auth/presentation/screens/register_screen.dart` (NEW, extracted) | component (screen) | request-response | `lib/features/auth/presentation/auth_screens.dart` — `RegisterScreen`/`_RegisterScreenState` (lines 155-282) | exact |
| `lib/features/auth/presentation/screens/reset_password_screen.dart` (NEW, extracted) | component (screen) | request-response | `lib/features/auth/presentation/auth_screens.dart` — `ResetPasswordScreen`/`_ResetPasswordScreenState` (lines 284-335) | exact |
| `lib/features/auth/presentation/screens/client_home_screen.dart` (NEW, relocated) | component (screen) | request-response | `lib/features/auth/presentation/auth_screens.dart` — `ClientHomeScreen` (lines 398-425) | exact (verbatim move) |
| `lib/features/home/presentation/screens/inicio_screen.dart` (NEW) | component (screen) | request-response (reads `AsyncNotifier`) | `lib/features/home/home_screen.dart` — `DashboardScreen` (greeting portion only, lines 203+) for visual shape; RESEARCH.md Pattern 4 for the Riverpod wiring | role-match (layout) / new-pattern (data source) |
| `lib/core/theme/app_colors.dart` (EDIT: green→terracota/crema palette) | config | transform | `lib/core/theme/app_colors.dart` (itself) | exact |
| `lib/core/theme/app_typography.dart` (EDIT: Figtree/NotoSans→Caprasimo/Figtree) | config | transform | `lib/core/theme/app_typography.dart` (itself) | exact |
| `test/widget_test.dart` (EDIT: pump `ProviderScope(child: VetApp())`, assert router boot) | test | request-response | `test/widget_test.dart` (itself) | exact |
| `test/inicio_screen_test.dart` (NEW) | test | request-response | `test/widget_test.dart` (only test file in repo — structure to imitate: `testWidgets` + `pumpWidget` + `find.text`) | role-match |
| `lib/features/auth/domain/auth_failure.dart` (EDIT: strip Firestore doc comment, keep class) | model (exception) | — | `lib/features/auth/domain/auth_failure.dart` (itself) | exact |

### Deletions (no analog needed — dead-code removal per FOUND-06 / Pitfall 4)
`firebase.json`, `android/app/google-services.json`, `lib/features/auth/domain/repositories/auth_repository.dart`, `lib/features/auth/domain/entities/veterinario.dart`, `lib/features/auth/domain/usecases/{sign_in_with_email,sign_in_with_google,sign_up_with_email,sign_out,watch_current_veterinario}.dart`, `lib/features/auth/presentation/auth_screens.dart` → `AuthGate` + `_VeterinarianHome` classes, `lib/features/home/home_screen.dart` → `LoginScreen` (duplicate) + `HomeScreen`/`_HomeScreenState`/`DashboardScreen`/`PatientsScreen`/`AgendaScreen`/`HistoryScreen`/`VaccinationScreen`/`InventoryScreen`/`BillingScreen` (replaced by `_ComingSoonScreen` placeholder inline in `app_router.dart`, per Pitfall 4 recommendation).

## Pattern Assignments

### `supabase/schema.sql` (migration, CRUD)

**Analog:** the file itself — follow its own established conventions exactly (Spanish `snake_case` names, `drop policy if exists` + `create policy` pairing, `security definer` helper functions).

**Table + RLS pattern to copy for the new `clientes` table** (model on `public.clinicas`, lines 11-18 + `clinicas_select`, lines 105-108):
```sql
create table if not exists public.clinicas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null check (length(trim(nombre)) > 0),
  ...
  created_at timestamptz not null default now()
);
...
drop policy if exists clinicas_select on public.clinicas;
create policy clinicas_select on public.clinicas for select to authenticated
using (public.es_veterinario() and id = public.mi_clinica_id());
```
Apply the same `check (length(trim(nombre)) > 0)` constraint style and the same `es_veterinario() and clinica_id = mi_clinica_id()` RLS clause shape to every new `clientes` policy (exact SQL already drafted in RESEARCH.md "Exact `clientes` table + RLS").

**Bug being fixed — exact current broken policy** (lines 115-117):
```sql
drop policy if exists perfiles_update on public.perfiles;
create policy perfiles_update on public.perfiles for update to authenticated
using (id = auth.uid()) with check (id = auth.uid());
```
Replace with the `WITH CHECK` column-comparison fix in RESEARCH.md Pitfall 1 (subquery against pre-update `perfiles` snapshot to pin `rol`/`clinica_id`).

**`mascotas` RLS to rewrite — current dueño-scoped clauses** (lines 125-143), all four policies (`select`/`insert`/`update`/`delete`) currently key off `dueno_id = auth.uid()`. Per Pitfall 2, every occurrence of `dueno_id = auth.uid()` must be dropped (not just left alongside a vet clause) once `dueno_id` points at `clientes` — copy the exact replacement SQL in RESEARCH.md "Exact `mascotas` FK repoint + RLS rewrite".

**Helper functions already available, reuse as-is** (lines 87-93):
```sql
create or replace function public.es_veterinario() ...
create or replace function public.mi_clinica_id() ...
```
Every new `clientes`/`mascotas` policy should call these two functions — do not re-derive tenant scoping inline.

---

### `lib/core/data/supabase_client_provider.dart` (provider, request-response) — NEW PATTERN

**Analog:** none in codebase — this is the first `Provider` ever defined outside `main.dart`'s bare `ProviderScope`. Use RESEARCH.md Pattern 1 verbatim (it is already final, reviewed code, not a draft):
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
```
Every later repository provider (this phase and future ones) must derive from `supabaseClientProvider` rather than calling `Supabase.instance.client` inline — this directly fixes the anti-pattern already present 3× in `auth_screens.dart` (`SupabaseAuthRepository(Supabase.instance.client)` at lines 31, 96-97, 194, 299-300 — see excerpts below).

---

### `lib/features/auth/presentation/providers/auth_providers.dart` (provider, event-driven) — new shape, reused error handling

**Analog for error handling / session semantics:** `lib/features/auth/data/repositories/supabase_auth_repository.dart` (do not modify this file — wrap it, don't replicate its logic).

**Two-tier error handling to preserve when calling the repository from the notifier** (lines 40-53):
```dart
try {
  final response = await _client.auth.signInWithPassword(
    email: email.trim(),
    password: password,
  );
  return _profileFor(response.user!.id);
} on AuthException catch (error) {
  throw AuthFailure(_messageFor(error));
} catch (_) {
  throw const AuthFailure('No fue posible iniciar sesión. Intenta de nuevo.');
}
```
The notifier's `build()` must catch `AuthFailure` specifically (not generic `Exception`), matching the existing convention that only `AuthFailure` ever crosses into presentation:
```dart
// current AuthGate._loadSession, lines 38-48 — the exact logic to migrate
Future<void> _loadSession() async {
  final session = _repository.currentSession;
  if (session != null) {
    try {
      _profile = await _repository.profileForCurrentUser();
    } on AuthFailure {
      await _repository.signOut();
    }
  }
  if (mounted) setState(() => _loading = false);
}
```
**New shape (AsyncNotifier) — no existing analog, use RESEARCH.md Pattern 2 verbatim** (already reviewed against Riverpod 3 docs):
```dart
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
}
```
Per Pitfall 3, never cache `ref.read(authProfileProvider.notifier)` in a local variable across an `await` — read it inline at each call site.

---

### `lib/core/router/app_router.dart` (route/config, request-response) — NEW PATTERN

**Analog:** none — first `go_router` usage. Use RESEARCH.md Pattern 3 verbatim.

**What it replaces (exact call sites to delete):**
```dart
// auth_screens.dart:129-131 — Navigator.push to ResetPasswordScreen
onPressed: () => Navigator.push<void>(
  context,
  MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
),
// auth_screens.dart:144-146 — Navigator.push to RegisterScreen
onPressed: () => Navigator.push<void>(
  context,
  MaterialPageRoute(builder: (_) => const RegisterScreen()),
),
```
Replace both with `context.push('/reset-password')` / `context.push('/register')` inside the extracted `login_screen.dart`. `RegisterScreen`'s own `Navigator.pop(context)` (line 211, after successful sign-up) becomes `context.pop()`.

**Redirect/shell skeleton to implement** — copy RESEARCH.md's `routerProvider` + `_AuthRefreshNotifier` + `StatefulShellRoute.indexedStack` block exactly (already includes the 5 branches matching `AppShell`'s nav destinations and a `_ComingSoonScreen` placeholder for the four not-yet-built feature screens).

---

### `lib/features/home/presentation/app_shell.dart` (component/shell, request-response)

**Analog:** `lib/features/home/home_screen.dart` — `_HomeScreenState.build()` (lines 122-201) for the **destination list shape only** (icons + Spanish labels), not for the `IndexedStack`/`setState` mechanism (that part is superseded by `StatefulNavigationShell`).

**Destination labels/icons to carry over exactly** (lines 176-197):
```dart
NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Inicio'),
NavigationDestination(icon: Icon(Icons.pets_rounded), label: 'Pacientes'),
NavigationDestination(icon: Icon(Icons.calendar_month_rounded), label: 'Agenda'),
// Historial/Cobros in the old shell → Clientes/Más in the new 5-branch router table
// per RESEARCH.md's route table (FOUND-02); confirm final label set against app_router.dart before implementing
```
**New mechanism (StatefulNavigationShell) — use RESEARCH.md Pattern 3's `AppShell` verbatim**:
```dart
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
      destinations: const [ /* ... */ ],
    ),
  );
}
```
Note: the desktop `NavigationRail` branch (`isDesktop` check, lines 135-158 of `home_screen.dart`) is explicitly **not** required by FOUND-02/CONTEXT.md (mobile-first walking skeleton) — flag as optional follow-up, do not silently drop functionality without noting it in the plan.

---

### `lib/main.dart` (config/entry-point, request-response)

**Analog:** the file itself (42 lines total, read in full).

**Current state to replace entirely:**
```dart
class VetApp extends StatefulWidget {
  const VetApp({super.key});
  @override
  State<VetApp> createState() => _VetAppState();
}

class _VetAppState extends State<VetApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VetApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}
```
**Target shape (RESEARCH.md, already final):**
```dart
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
Keep the existing `main()` Supabase-init guard (lines 8-20) unchanged — only `VetApp` changes. Per RESEARCH.md, the `supabaseConfigured == false` degraded-mode branch (currently handled inside `AuthGate`) has no direct `redirect:` equivalent and is acceptable to drop, since FOUND-01 makes a real cloud project mandatory this phase.

---

### `lib/features/auth/presentation/screens/{login,register,reset_password}_screen.dart` (component/screen, request-response)

**Analog:** `lib/features/auth/presentation/auth_screens.dart` — each screen class is extracted near-verbatim (see full excerpts read above, lines 67-335). Preserve:
- The `_AuthScaffold` shared wrapper (lines 337-389) — move it into a shared location (e.g. its own file or kept in one of the three screen files and imported) since all three screens depend on it.
- The exact validation-before-submit pattern (e.g. `login_screen.dart`, lines 82-90): manual empty-field checks via `setState`, not a `Form`/`validator` — matches the established codebase convention, do not introduce `Form` widgets unless explicitly asked.
- The `AuthFailure` catch pattern (lines 100-104, 213-216, 307-313) is the one place `AuthFailure` is still caught directly by presentation code, per project error-handling convention — do not change this to catch `Exception`.

**Only mechanical change required:** replace direct `SupabaseAuthRepository(Supabase.instance.client)` construction (lines 96-98, 194, 299-300) with `ref.read(authRepositoryProvider)` (requires converting each `State<...>` to `ConsumerState<...>` and each `StatefulWidget` to `ConsumerStatefulWidget`), and replace the two `Navigator.push`/`Navigator.pop` call sites (lines 129-131, 144-146, 211) with `context.push(...)`/`context.pop()`.

---

### `lib/features/auth/presentation/screens/client_home_screen.dart` (component/screen, request-response)

**Analog:** `lib/features/auth/presentation/auth_screens.dart` — `ClientHomeScreen` (lines 398-425), moved verbatim into its own file (no logic change needed this phase — it's not dead code, just mis-located per RESEARCH.md Dead Code table):
```dart
class ClientHomeScreen extends StatelessWidget {
  const ClientHomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mis mascotas')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [ /* ... AppButton x2 ... */ ],
    ),
  );
}
```
Wire it as a `/cliente` route target in `app_router.dart` per RESEARCH.md Open Question 1 (recommended, not locked).

---

### `lib/features/home/presentation/screens/inicio_screen.dart` (component/screen, request-response)

**Analog (visual shape only):** `lib/features/home/home_screen.dart` — `DashboardScreen` (greeting/summary section, starts line 203) for card layout conventions; **do not** copy its hardcoded metric cards (out of scope, Phase 8 per D-02).

**Analog (data source — reusable widgets):** `lib/core/widgets/cards/app_card.dart` (full file, 34 lines) and `lib/core/widgets/app_bar/app_top_bar.dart` (full file, 18 lines):
```dart
// app_card.dart — every info panel wraps this instead of raw Card
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap,
      this.padding = const EdgeInsets.all(AppSpacing.md)});
  ...
}
// app_top_bar.dart
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({super.key, required this.title, this.actions});
  ...
}
```
**New pattern (AsyncValue.when + authProfileProvider) — use RESEARCH.md Pattern 4 verbatim**, which already composes `AppTopBar`/`AppCard`/`AppSpacing` correctly:
```dart
class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(authProfileProvider);
    return Scaffold(
      appBar: const AppTopBar(title: 'Inicio'),
      body: profileAsync.when(
        data: (profile) => profile == null
            ? const Center(child: Text('No hay una sesión activa.'))
            : Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hola, ${profile.nombre}', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: AppSpacing.sm),
                      Text(profile.clinicaNombre ?? 'Sin clínica asignada', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const Center(child: Text('No pudimos cargar tu perfil. Intenta de nuevo.')),
      ),
    );
  }
}
```

---

### `lib/core/theme/app_colors.dart` (config, transform)

**Analog:** the file itself (36 lines, current green/forest palette). Keep the exact static-class shape (`AppColors._()` private constructor, `static const Color` fields), only replace values:
```dart
// current (to replace)
static const Color primary = Color(0xFF2F6F4F);
static const Color background = Color(0xFFF4F1EC);
static const Color surface = Color(0xFFFFFCF8);
static const Color foreground = Color(0xFF1D2B24);
```
Target values are exact and already sourced from the approved mockup (RESEARCH.md "Design Tokens Update") — `primary = 0xFFC67139` (terracota), `background = 0xFFF5EAD8` (crema), etc. Keep the existing dark-mode field names (`backgroundDark`, `surfaceDark`, ...) but flag per RESEARCH.md A3 that dark-mode terracota values are not yet approved — derive conservatively or flag for `/gsd:ui-phase`, do not invent.

---

### `lib/core/theme/app_typography.dart` (config, transform)

**Analog:** the file itself (44 lines). Current pattern to preserve (only the two `GoogleFonts.*TextTheme()` calls change):
```dart
static TextTheme textTheme(Color foreground) {
  final headingBase = GoogleFonts.figtreeTextTheme();     // → GoogleFonts.caprasimoTextTheme() or manual per-style
  final bodyBase = GoogleFonts.notoSansTextTheme();         // → GoogleFonts.figtreeTextTheme()
  ...
}
```
Per RESEARCH.md Assumption A1: verify whether `google_fonts ^8.2.0` exposes `caprasimoTextTheme()` (bulk helper) before relying on it — Caprasimo is a single-weight display font, so the fallback is applying `GoogleFonts.caprasimo(textStyle: ...)` per individual `displayLarge`/`headlineSmall`/etc. field, mirroring the existing `.copyWith(displayLarge: headingBase.displayLarge, ...)` composition already in this file (lines 15-26) — same structure, just built manually if no bulk helper exists.

---

### `test/widget_test.dart` (test, request-response)

**Analog:** the file itself (20 lines, only test in repo).
```dart
await tester.pumpWidget(const VetApp());
expect(find.text('Bienvenido a VetApp'), findsOneWidget);
```
Target: wrap in `ProviderScope` (required once `VetApp` is a `ConsumerWidget` reading `routerProvider`) — `await tester.pumpWidget(const ProviderScope(child: VetApp()));` — and keep asserting on the same login-screen copy (`'Bienvenido a VetApp'`), since `/login` is still `initialLocation` for an unauthenticated boot.

### `test/inicio_screen_test.dart` (test, request-response) — NEW

**Analog:** `test/widget_test.dart`'s `testWidgets`/`pumpWidget`/`find.text` structure (only structural analog available; this is the first test needing provider overrides). Use `ProviderScope(overrides: [authProfileProvider.overrideWith(...)])` to inject a fake `AsyncNotifier` so the test never touches live Supabase, per RESEARCH.md Wave 0 Gaps.

## Shared Patterns

### Two-tier error handling (`AuthFailure` domain exception + SDK-error translation)
**Source:** `lib/features/auth/data/repositories/supabase_auth_repository.dart:40-53, 90-100, 134-151`
**Apply to:** `auth_providers.dart` (wraps repository calls), all three extracted screen files (catch `AuthFailure` specifically for inline form errors)
```dart
try {
  ...
} on AuthException catch (error) {
  throw AuthFailure(_messageFor(error));
} catch (_) {
  throw const AuthFailure('<mensaje genérico en español>');
}
```
`_messageFor(AuthException)` (lines 134-151) is the single place to add new provider-error → Spanish-message mappings; do not inline new translations at call sites.

### Single Supabase-client injection point
**Source:** RESEARCH.md Pattern 1 (`supabaseClientProvider`)
**Apply to:** `auth_providers.dart`'s `authRepositoryProvider` this phase; every future feature repository provider (Phase 2+) must also derive from `supabaseClientProvider`, never call `Supabase.instance.client` inline — this retires the exact anti-pattern at `auth_screens.dart:31, 96-98, 194, 299-300`.

### Static design-token classes (private constructor + `static const`)
**Source:** `lib/core/theme/app_colors.dart` (`AppColors._()`), `lib/core/theme/app_spacing.dart` (`AppSpacing._()`)
**Apply to:** No new token classes needed this phase — `app_colors.dart`/`app_typography.dart` are edited in place, keeping this exact shape.

### Reusable widget wrapping (never raw Material widgets for shared UI)
**Source:** `lib/core/widgets/cards/app_card.dart`, `app_bar/app_top_bar.dart`, `buttons/app_button.dart`, `inputs/app_text_field.dart`
**Apply to:** `inicio_screen.dart` (must use `AppCard`/`AppTopBar`, not raw `Card`/`AppBar`), all three auth screens (must keep using `AppButton`/`AppTextField`, already the case — do not regress to raw `TextFormField`/`ElevatedButton` during extraction).

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `lib/core/data/supabase_client_provider.dart` | provider | request-response | No Riverpod `Provider` exists anywhere outside `main.dart`'s bare `ProviderScope` — first of its kind. Use RESEARCH.md Pattern 1 (already final, reviewed code) as the source of truth instead of a codebase analog. |
| `lib/core/router/app_router.dart` | route/config | request-response | No `go_router` usage exists anywhere in `lib/` despite the package being declared since project scaffold — first of its kind. Use RESEARCH.md Pattern 3 verbatim. |
| `AuthProfileNotifier` shape inside `auth_providers.dart` | provider | event-driven | No `AsyncNotifier`/`Notifier` exists in the codebase (Riverpod is currently unused beyond `ProviderScope`). Error-handling body is a role-match copy from `supabase_auth_repository.dart`; the `AsyncNotifier` class shape itself is new — use RESEARCH.md Pattern 2. |

## Metadata

**Analog search scope:** `lib/` (all 27 existing `.dart` files), `test/` (1 file), `supabase/schema.sql`
**Files scanned:** 27 Dart files + 1 SQL file + 1 test file (full inventory via `Glob`/`Bash find`)
**Pattern extraction date:** 2026-09-24
