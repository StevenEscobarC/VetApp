# Architecture Research

**Domain:** Flutter mobile app + Supabase (Postgres/RLS) backend — multi-feature CRUD practice-management app (clean-architecture rebuild of a brownfield app where only `auth` is real)
**Researched:** 2026-09-23
**Confidence:** HIGH (Riverpod 3 / go_router patterns verified against official docs via Context7; Supabase-specific layering verified via multiple community sources; VetApp-specific findings verified by direct codebase reading)

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                          Presentation Layer                          │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐         │
│  │  Screens   │  │ Consumer  │  │  Riverpod │  │ go_router │         │
│  │ (Widgets)  │──│ Widgets   │──│ Providers │  │ routes    │         │
│  └───────────┘  └───────────┘  └─────┬─────┘  └─────┬─────┘         │
│         ref.watch/ref.read ──────────┘  redirect ────┘               │
├────────────────────────────────────┴──────────────────────────────────┤
│                            Domain Layer (thin)                        │
│  ┌────────────────────┐   ┌────────────────────────────────────┐     │
│  │  Entities (pure)    │   │ Repository interfaces (abstract)   │     │
│  │  Failure types      │   │ Usecases — ONLY for cross-feature   │     │
│  │                      │   │ orchestration (multi-repo writes)  │     │
│  └────────────────────┘   └────────────────┬───────────────────┘     │
├─────────────────────────────────────────────┴──────────────────────────┤
│                              Data Layer                                │
│  ┌───────────────┐   ┌────────────────────┐   ┌────────────────────┐  │
│  │  Datasource    │──▶│ Repository impl    │──▶│ Models (fromJson/  │  │
│  │ (raw Supabase  │   │ (Supabase<Feature> │   │  toJson, table map)│  │
│  │  query/mutate) │   │  Repository)        │   │                    │  │
│  └───────────────┘   └────────────────────┘   └────────────────────┘  │
├─────────────────────────────────────────────────────────────────────────┤
│              Supabase (supabase_flutter client — single instance)      │
│         Postgres tables + RLS policies + Auth + Realtime (optional)    │
└─────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| Screen (Widget) | Layout, local form/UI state (text controllers, selected tab), delegates all data reads/writes to providers | `ConsumerWidget`/`ConsumerStatefulWidget`, no direct `Supabase.instance.client` calls |
| Riverpod Notifier/AsyncNotifier | Owns feature's server-backed state; calls repository, exposes `AsyncValue<T>`; contains business logic that only touches one repository | `class PatientsNotifier extends AsyncNotifier<List<Mascota>>` |
| Repository (interface + Supabase impl) | Abstracts persistence; maps Supabase rows ↔ domain entities; translates `PostgrestException`/`AuthException` into typed `Failure` | `abstract class PatientsRepository`, `class SupabasePatientsRepository implements PatientsRepository` |
| Datasource | Raw Supabase calls only (`.from(table).select()/.insert()/.update()`), no domain mapping | Optional — can be folded into the repository for CRUD-simple features; keep separate only when a feature has multiple sources (e.g. Storage + Postgres) |
| Domain entity | Immutable data shape, no Flutter/Supabase import, `copyWith` | Already the existing convention (`Mascota`, `Cita`, etc.) — keep, but reconcile fields with `schema.sql` |
| Usecase | Orchestrates **multiple repositories** for one business operation | Only needed for: registrar vacuna → agenda próxima dosis; facturar → descontar inventario; completar cita → crear entrada de historia clínica |
| go_router `GoRoute`/`StatefulShellRoute` | Declarative route table, auth-gated redirects, bottom-nav shell with 5 persistent branches | `GoRouter(routes: [...], redirect: (context, state) { ... })` |
| Riverpod `Provider` for router | Exposes the single `GoRouter` instance, watched once in `main.dart` | `final routerProvider = Provider<GoRouter>((ref) => GoRouter(...))` |
| Auth state provider | Single source of truth for "who is logged in / what role" — everything else (router redirect, RLS-scoped queries) reads from here | `AsyncNotifier<AuthProfile?>` wrapping `supabase.auth.onAuthStateChange` |

## Recommended Project Structure

```
lib/
├── main.dart                          # Supabase.initialize, ProviderScope, MaterialApp.router(routerConfig: ...)
├── core/
│   ├── router/
│   │   └── app_router.dart            # GoRouter provider, route table, StatefulShellRoute (5 tabs), redirect logic
│   ├── data/
│   │   └── supabase_client_provider.dart   # Provider<SupabaseClient> — THE single injection point, nothing else touches Supabase.instance directly
│   ├── errors/
│   │   └── failure.dart               # Shared `Failure`/`AppException` base type + Supabase error → Failure mapper (generalize existing AuthFailure pattern)
│   ├── theme/                         # (existing, unchanged)
│   ├── widgets/                       # (existing, unchanged)
│   └── utils/                         # date/currency formatting (COP, dd/mm/aaaa) shared across features
├── features/
│   └── <feature>/                     # patients, clients, appointments, clinical_history, vaccination, inventory, billing, dashboard, auth
│       ├── data/
│       │   ├── models/                # <Entity>Model with fromJson/toJson mapping exact schema.sql columns
│       │   └── repositories/          # Supabase<Feature>Repository implements <Feature>Repository
│       ├── domain/
│       │   ├── entities/              # existing entity files — trim/extend fields to match schema.sql
│       │   ├── repositories/          # abstract interface (thin: 4-6 CRUD methods)
│       │   └── usecases/              # ONLY where cross-feature orchestration is real (see table above); do not create one per CRUD op
│       └── presentation/
│           ├── providers/             # <Feature>Notifier (AsyncNotifier), list/detail/form providers
│           ├── screens/                # one file per screen, replacing home_screen.dart content
│           └── widgets/                # feature-local widgets (cards, list tiles)
└── ...
```

### Structure Rationale

- **`core/data/supabase_client_provider.dart`:** Today every screen that needs Supabase constructs `SupabaseAuthRepository(Supabase.instance.client)` inline. Centralizing the client behind one `Provider` is the single highest-leverage change: it's what makes every repository injectable/overridable in tests and is a prerequisite for Riverpod adoption everywhere else.
- **`core/router/app_router.dart`:** One file, one `GoRouter`. Avoid letting each feature register its own router config ad hoc — go_router route tables should be centrally declared even though route *builders* reference per-feature screens.
- **`domain/repositories/` kept, `domain/usecases/` mostly dropped:** The existing scaffold has a `usecases/` folder in every feature. For this app's actual features, plain CRUD (create/read/update/delete a paciente, a cliente, a cita) does not need a usecase — the Notifier calling the repository directly is standard and avoids ceremony. Usecases earn their keep only for the ~4 real cross-feature workflows identified in Data Flow below. This deliberately diverges from the current empty scaffold (which implies 1 usecase file per CRUD verb, following the `auth` feature's dead pattern) — mirroring `auth`'s unused usecases would repeat the exact anti-pattern already flagged in `.planning/codebase/ARCHITECTURE.md`.
- **`data/models/` reintroduced (currently empty in every feature):** Entities today have no `fromJson`/`toJson` and don't match `schema.sql` column names/types. A dedicated `Model` class (or extension methods on the entity) keeps Supabase's snake_case JSON mapping out of the pure `domain/entities/` files.

## Architectural Patterns

### Pattern 1: Repository interface + single Supabase implementation

**What:** `abstract class PatientsRepository { Future<List<Mascota>> getForClinic(String clinicaId); Future<Mascota> create(Mascota m); ... }`, with exactly one concrete class `SupabasePatientsRepository implements PatientsRepository`.
**When to use:** Every feature that reads/writes a Supabase table (all 7 stub features).
**Trade-offs:** Costs one extra interface file per feature; buys unit-testable Notifiers (fake repository) without needing a real Supabase connection in tests, and gives a single seam if a table is ever restructured. Given the app has exactly one backend (Supabase, permanent decision per `PROJECT.md` constraints), this is about testability, not backend-swappability.

**Example:**
```dart
// domain/repositories/patients_repository.dart
abstract class PatientsRepository {
  Future<List<Mascota>> watchForOwner(String duenoId);
  Future<Mascota> create(Mascota mascota);
  Future<Mascota> update(Mascota mascota);
  Future<void> delete(String id);
}

// data/repositories/supabase_patients_repository.dart
class SupabasePatientsRepository implements PatientsRepository {
  SupabasePatientsRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<Mascota>> watchForOwner(String duenoId) async {
    try {
      final rows = await _client.from('mascotas').select().eq('dueno_id', duenoId);
      return rows.map(MascotaModel.fromJson).map((m) => m.toEntity()).toList();
    } on PostgrestException catch (e) {
      throw Failure.fromPostgrest(e);
    }
  }
  // ...
}
```

### Pattern 2: AsyncNotifier as the sole state container per feature (Riverpod 3, no code generation)

**What:** One `AsyncNotifier<T>` (or `AsyncNotifier<List<T>>`) per meaningful piece of server-backed state; screens are `ConsumerWidget`s that `ref.watch` it and render `AsyncValue.when(data:, error:, loading:)`.
**When to use:** Every list/detail/form screen backed by Supabase data — patients list, client detail, appointment calendar, invoice, inventory stock.
**Trade-offs:** Riverpod 3 (`^3.3.2`, already in `pubspec.yaml`) supports both hand-written `Notifier`/`AsyncNotifier` classes and `@riverpod`-annotated code generation (`riverpod_generator` + `build_runner`). **The project has neither `riverpod_generator` nor `build_runner`/`freezed` declared today.** Recommendation: use hand-written `Notifier`/`AsyncNotifier` (no codegen) to avoid adding a build step and generated-file churn across 7 new feature modules being built in sequence by an AI executor — codegen is a valid later optimization, not a prerequisite. `StateNotifier` is deprecated/legacy in Riverpod 3; do not introduce it even though older tutorials still show it.

**Example:**
```dart
final patientsRepositoryProvider = Provider<PatientsRepository>((ref) {
  return SupabasePatientsRepository(ref.watch(supabaseClientProvider));
});

class PatientsNotifier extends AsyncNotifier<List<Mascota>> {
  @override
  Future<List<Mascota>> build() async {
    final duenoId = ref.watch(authProfileProvider).value?.id;
    if (duenoId == null) return [];
    return ref.watch(patientsRepositoryProvider).watchForOwner(duenoId);
  }

  Future<void> addPatient(Mascota mascota) async {
    await ref.read(patientsRepositoryProvider).create(mascota);
    ref.invalidateSelf(); // or optimistic update
  }
}

final patientsProvider = AsyncNotifierProvider<PatientsNotifier, List<Mascota>>(
  PatientsNotifier.new,
);
```

### Pattern 3: go_router `StatefulShellRoute.indexedStack` for the 5-tab bottom nav + Riverpod-driven redirect

**What:** A single `StatefulShellRoute.indexedStack` with 5 branches (Dashboard, Patients/Clients, Agenda, Clinical History or Inventory, Billing — matching the mockup's 5-section bottom nav), each branch preserving its own navigation stack. A top-level `redirect` callback reads the auth-state provider (via a `Provider<GoRouter>` built once, watching a `ChangeNotifier` bridge) to send unauthenticated users to `/login` and role-mismatched users to the right home.
**When to use:** Replaces the current `AuthGate` + manual `Navigator.push`/`IndexedStack` entirely.
**Trade-offs:** Requires one small bridge class (`GoRouterRefreshStream` or a `ChangeNotifier` fed by `ref.listen`) because `GoRouter`'s `refreshListenable` expects a `Listenable`, not a Riverpod provider directly — this is a well-established, documented pattern, not a workaround.

**Example:**
```dart
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authProfileProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshNotifier(ref);
  return GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      final profile = ref.read(authProfileProvider).value;
      final loggingIn = state.matchedLocation == '/login';
      if (profile == null) return loggingIn ? null : '/login';
      if (loggingIn) return profile.rol == 'VETERINARIO' ? '/dashboard' : '/client';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/patients', builder: (_, __) => const PatientsScreen())]),
          // agenda, historia/inventario, facturación branches...
        ],
      ),
    ],
  );
});
```

## Data Flow

### Request Flow (typical feature CRUD)

```
[Screen: ConsumerWidget]
    ↓ ref.watch(featureProvider)
[AsyncNotifier<T>] → [Repository interface] → [SupabaseXRepository] → [SupabaseClient]
    ↓ AsyncValue.when(loading/data/error)              ↓ .from(table).select/insert/update/delete
[Screen re-renders]  ←──────────────────────── [Postgres row(s), scoped by RLS on auth.uid()]
```

### State Management

```
[SupabaseClient.auth.onAuthStateChange stream]
    ↓
[authProfileProvider: AsyncNotifier<AuthProfile?>]   (replaces AuthGate's local setState)
    ↓ ref.watch                              ↓ ref.listen → notifyListeners()
[Feature Notifiers scope queries by profile.id/clinicaId]   [routerProvider redirect logic]
```

### Key Data Flows (cross-feature — where `usecases/` earn their keep)

1. **Vaccination → next-dose reminder:** Registering a `vacuna` (vaccination feature) must also compute/schedule the next-dose alert (per `PROJECT.md`'s "alertas automáticas de próxima dosis"). This is a `RegisterVaccinationUseCase` in `vaccination/domain/usecases/` that calls `VaccinationRepository.create()` then either writes a `next_due_date` column on the same row or inserts a follow-up reminder record — decide the schema shape before building this feature.
2. **Billing → inventory decrement:** Creating a `factura` line item for a medicamento/insumo should decrement `inventario` stock and can trigger a low-stock alert. This spans `billing` and `inventory` repositories — a usecase in `billing/domain/usecases/` (or a Postgres function/trigger, see Anti-Patterns) is the right seam.
3. **Appointment completion → clinical history entry:** Marking a `cita` as completed plausibly creates/links a `consulta` (clinical history entry). Spans `appointments` and `clinical_history`.
4. **Sign-up → profile/clinic creation:** Already implemented server-side via the `crear_perfil_nuevo_usuario` Postgres trigger (no client usecase needed) — keep this precedent: prefer a Postgres trigger/function over a client-side usecase when the operation is a rigid, security-relevant invariant (as flagged in `.planning/codebase/CONCERNS.md`, this trigger currently has no tests — add coverage before extending the schema for the flows above).

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| Solo vet / single clinic (current target) | Single Supabase project, RLS-scoped by `clinica_id`; plain `AsyncNotifier` + `.select()` per screen is entirely sufficient — no caching/pagination layer needed yet |
| Small clinic, few hundred patients/citas | Add `.range()` pagination to list queries (patients, historia clínica timeline) and `.order()`; still no separate caching layer — Riverpod's provider retains data during navigation, which is enough |
| Multi-clinic SaaS (out of scope per `PROJECT.md`, but worth architecting for) | RLS already isolates by `clinica_id`, so this mostly needs UI/plan-tier work, not a data-layer rewrite — the repository-behind-interface pattern is what makes this cheap later |

### Scaling Priorities

1. **First bottleneck:** Historia clínica timeline and patients list growing unbounded per clinic — add pagination (`range()`) and an index-backed `order_by fecha` once real data volume exists; not a v1 concern.
2. **Second bottleneck:** `_profileFor`-style embedded joins (`perfiles` + `clinicas`) repeated per screen — if every feature independently re-fetches the profile/clinic, centralize it in the single `authProfileProvider` (already recommended above) so it's fetched once per session, not per feature.

## Anti-Patterns

### Anti-Pattern 1: Building the screen before the repository exists (the app's current failure mode)

**What people do:** Write the full UI with hardcoded literals first (`lib/features/home/home_screen.dart`, 1400 lines, exactly this), planning to "wire it up later."
**Why it's wrong:** "Later" never arrives cleanly — the UI's data shape, loading/error states, and empty states are all guessed rather than derived from the actual repository return type, so the eventual wiring pass becomes a rewrite, not a connection. This is the single most consequential existing problem per `.planning/codebase/CONCERNS.md`.
**Do this instead:** Per feature, build bottom-up: schema/RLS → entity/model → repository (interface + Supabase impl) → provider (`AsyncNotifier`) → screen consuming `AsyncValue`. Do not write a feature's `presentation/screens/*.dart` until its `presentation/providers/*.dart` compiles and returns real (even if empty/seed) data.

### Anti-Pattern 2: Domain layer defined but bypassed (already present in `auth`)

**What people do:** Write `domain/repositories/`, `domain/usecases/` for a feature, then have the presentation layer call the concrete data-layer class directly, skipping the abstraction entirely — exactly what `auth_screens.dart` does today with `SupabaseAuthRepository`.
**Why it's wrong:** The abstraction provides zero benefit if nothing depends on it, and it actively misleads whoever reads the folder structure into believing the pattern is enforced.
**Do this instead:** If a `domain/repositories/<X>Repository` interface exists for a feature, the corresponding Riverpod provider must return the interface type (`Provider<PatientsRepository>`, not `Provider<SupabasePatientsRepository>`) and notifiers must depend on that interface type, never the concrete class. Retrofit `auth` to this same pattern in the same milestone that establishes it for other features, or delete auth's dead domain files — don't leave the inconsistency as precedent.

### Anti-Pattern 3: One usecase class per CRUD verb

**What people do:** Scaffold `create_patient.dart`, `get_patient.dart`, `update_patient.dart`, `delete_patient.dart` usecases that each do nothing but call one repository method.
**Why it's wrong:** Pure ceremony for this app's scale — 7 features × 4-5 CRUD verbs would produce ~30 single-method wrapper classes with no orchestration logic, adding files without adding safety or clarity.
**Do this instead:** Notifiers call the repository interface directly for CRUD. Reserve `domain/usecases/` for the ~4 real cross-repository workflows identified in Data Flow above.

### Anti-Pattern 4: Instantiating `Supabase.instance.client` (or any repository) inline in widget code

**What people do:** `SupabaseAuthRepository(Supabase.instance.client)` constructed fresh inside a `_submit()` method — the exact pattern already present three times in `auth_screens.dart` per `CONCERNS.md`.
**Why it's wrong:** No single injection point means no way to override with a fake in tests, and it multiplies boilerplate as more repositories are added across 7 new features.
**Do this instead:** One `Provider<SupabaseClient>` in `core/data/supabase_client_provider.dart`; every repository provider derives from it. Retrofit `auth` when introducing this for the new features, so the pattern is consistent app-wide, not auth-vs-everything-else.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Supabase Postgres (CRUD) | `SupabaseClient.from(table).select()/insert()/update()/delete()` inside repository implementations only | Never call from presentation code directly; RLS is the security boundary, not client-side filtering — every query still relies on RLS being correct (already true for `mascotas`, must be extended per new table) |
| Supabase Auth | `SupabaseClient.auth` — session stream feeds `authProfileProvider`; already implemented in `SupabaseAuthRepository`, needs to move behind the `AuthRepository` interface and be watched via `onAuthStateChange` rather than one-shot `_loadSession()` | `signInWithGoogle` usecase exists but is unimplemented/dead — either implement or delete before this milestone ships |
| Supabase Storage (mascota photos, if pursued) | Separate `datasource` per feature for file upload, distinct from the Postgres datasource | `Mascota.fotoUrl` field already exists in the entity but has no matching schema column or upload path yet — decide schema before building patients feature UI for photos |
| PDF export (historia clínica, facturación) | Client-side PDF generation library (e.g. `pdf`/`printing` packages, not yet in `pubspec.yaml`) consuming already-fetched domain entities — keep as a `presentation`-adjacent concern (e.g. `<feature>/presentation/pdf/`), not a repository method | Out of this research's direct scope; flag as needing its own focused research before the billing/clinical_history phases |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `patients` ↔ `clients` | `mascotas.dueno_id` foreign key; patients repository queries need the owning client's id, clients repository/entity is the source of truth for contact info | **Schema decision needed before either feature is built** — see Anti-Pattern/Gap below: current schema ties every "cliente" to a Supabase Auth user via `perfiles`, which conflicts with the product's own "vet manages clients directly, no receptionist, clients may never create an account" premise. |
| `appointments` ↔ `clinical_history` | Completing a `cita` may create/link a `consulta` | Cross-feature usecase (see Data Flow #3); appointments repository should not directly write to the clinical_history table — go through a usecase or a single Postgres function, not ad hoc cross-repository calls buried in a Notifier |
| `billing` ↔ `inventory` | Invoice line items reference inventory products; creating an invoice may decrement stock | Cross-feature usecase or Postgres function (Data Flow #2) |
| `vaccination` ↔ (dashboard alerts) | Dashboard's "próxima dosis" alerts read vaccination due-dates | Read-only cross-feature dependency — dashboard should have its own lightweight aggregate query/provider, not reach into `vaccination`'s internal repository types |
| Every feature ↔ `auth` | Every RLS-scoped query needs `clinica_id`/`dueno_id`/`rol` from the current session | All features should depend on the single `authProfileProvider`, never re-fetch the profile themselves |

### Open Architectural Gap Surfaced by This Research

**Clients as authenticated users vs. clients as vet-managed contacts.** `supabase/schema.sql` models `perfiles` (which is what the current `Cliente`-shaped data must live in, per the FK on `mascotas.dueno_id`) as a table that **requires** a corresponding `auth.users` row — every client must have signed up with email/password. But `PROJECT.md`'s core value ("veterinario atiende solo... sin depender de... recepcionista") and the vaccination/billing features imply the vet frequently creates a client + pet record on the spot, during a walk-in or home visit, without the client ever creating an account. This is a genuine, unresolved schema/architecture decision, not yet made anywhere in the codebase or planning docs reviewed:
- **Option A:** Add a `clientes` table owned by `clinica_id` (no FK to `auth.users`), decoupled from `perfiles`; `mascotas.dueno_id` points here instead of (or in addition to) `perfiles`. A client *may later* be invited to create a real account (`perfiles` row) that links back to their `clientes` record — this matches the "app complementaria para el dueño" fase-3 item in `PROJECT.md`.
- **Option B:** Keep `perfiles` as-is and have the vet's signup flow silently create a `perfiles` row (with a role like `CLIENTE`, no real auth credential, or a service-role-created shadow user) for every walk-in client — more schema reuse, but conflates "authenticated user" with "contact record" and complicates RLS.
- **Recommendation:** Option A. It matches the existing multi-tenant RLS pattern (scope by `clinica_id`), avoids inventing shadow auth users, and is a materially smaller schema change than it looks (one new table + one FK swap) — but it must be decided and the schema patched **before** the `clients`/`patients` feature phases start, or those two features will be built against the wrong data model twice.

## Sources

- Riverpod 3 official docs (`AsyncNotifier`/`Notifier`, migration from `StateNotifier`/`FutureProvider`) — Context7 `/rrousselgit/riverpod`, HIGH confidence
- [Flutter + Riverpod + GoRouter redirect — ApparenceKit](https://apparencekit.dev/blog/flutter-riverpod-gorouter-redirect/) — MEDIUM confidence, cross-checked against Riverpod's own `ref.listen`/`ChangeNotifier` bridging docs
- [Guarding routes in Flutter with GoRouter and Riverpod — Dinko Marinac](https://dinkomarinac.dev/blog/guarding-routes-in-flutter-with-gorouter-and-riverpod/) — MEDIUM confidence
- [GoRouter Advanced Tutorial: Bottom Nav, Nested Routes, Auth Redirects & Typed Navigation — dev.to](https://dev.to/techwithsam/gorouter-advanced-tutorial-2026-bottom-nav-nested-routes-auth-redirects-typed-navigation-31d) — MEDIUM confidence
- [Flutter Clean Architecture with Riverpod and Supabase — Otakoyi](https://otakoyi.software/blog/flutter-clean-architecture-with-riverpod-and-supabase) and its companion repo [otakoyi/flutter_ddd_riverpod_example](https://github.com/otakoyi/flutter_ddd_riverpod_example) — MEDIUM confidence, corroborates data/domain/presentation layering with Supabase
- Direct codebase reads: `.planning/codebase/ARCHITECTURE.md`, `.planning/codebase/STRUCTURE.md`, `.planning/codebase/CONCERNS.md`, `supabase/schema.sql`, `pubspec.yaml` — HIGH confidence (primary source)

---
*Architecture research for: Flutter + Supabase clean-architecture veterinary practice-management app*
*Researched: 2026-09-23*
