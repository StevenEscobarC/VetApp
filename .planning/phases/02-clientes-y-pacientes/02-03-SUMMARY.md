---
phase: 02-clientes-y-pacientes
plan: 03
subsystem: clients

tags: [flutter, riverpod, supabase, postgrest, go_router, debounce, search]

# Dependency graph
requires:
  - phase: 01-fundacion
    provides: Supabase project + clientes/mascotas schema with vet-only RLS, Riverpod AsyncNotifier + go_router walking skeleton, auth_providers.dart pattern to replicate
provides:
  - Cliente entity reconciled to the live schema.sql (clinicaId, numeroMascotas, vinculación fields; veterinarioId/mascotaIds removed)
  - ClienteFailure domain exception mirroring AuthFailure
  - sanitizarBusqueda/filtroOrIlike shared search helpers (lib/core/data/busqueda.dart) for reuse by Pacientes search (Plan 06)
  - SupabaseClienteRepository.buscar with two-tier PostgrestException error handling
  - clienteRepositoryProvider + ClientesNotifier (350ms debounce, stale-response sequence guard)
  - ClientesListScreen wired at /clientes replacing ComingSoonScreen, with UI-SPEC empty/error states
  - test/helpers/router_harness.dart and test/helpers/fake_clientes.dart reused by Plans 04-09
affects: [clients, patients, agenda]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "AsyncNotifier depending on another AsyncNotifier must `await ref.watch(otherProvider.future)`, never read `.value` synchronously (races the dependency's own pending build)"
    - "ProviderContainer in tests must pass `retry: (retryCount, error) => null` to disable Riverpod 3's default exponential-backoff retry on failed providers, or intentional-error tests hang/timeout"
    - "Debounced search notifier avoids AsyncValue.copyWithPrevious (marked @internal in riverpod 3.3.2) by simply not touching `state` until the guarded fetch resolves — previous AsyncData renders unchanged in the meantime"

key-files:
  created:
    - lib/features/clients/domain/cliente_failure.dart
    - lib/core/data/busqueda.dart
    - lib/features/clients/data/repositories/supabase_cliente_repository.dart
    - lib/features/clients/presentation/providers/clientes_providers.dart
    - lib/features/clients/presentation/screens/clientes_list_screen.dart
    - lib/features/clients/presentation/clientes_routes.dart
    - test/helpers/router_harness.dart
    - test/helpers/fake_clientes.dart
  modified:
    - lib/features/clients/domain/entities/cliente.dart
    - lib/core/widgets/inputs/app_text_field.dart
    - lib/core/router/app_router.dart

key-decisions:
  - "Used the two-step-avoiding own-table .or() filter for Clientes search (no join needed) — filtroOrIlike shared with the joined Pacientes search that Plan 06 will add"
  - "Skipped AsyncValue.copyWithPrevious (internal API) in favor of leaving state untouched during debounced fetches — equivalent UX, no analyzer warning"

patterns-established:
  - "Pattern: always `await ref.watch(dep.future)` inside an AsyncNotifier.build() that depends on another AsyncNotifier's resolved value"
  - "Pattern: test ProviderContainers must disable default retry (`retry: (retryCount, error) => null`) exactly like ProviderScope already does in fake_auth.dart"

requirements-completed: [CLI-03]

# Metrics
duration: 35min
completed: 2026-09-24
---

# Phase 2 Plan 03: Clientes instant search Summary

**Real Supabase-backed Clientes list with 350ms-debounced instant search by nombre/teléfono, replacing the ComingSoonScreen stub at `/clientes`.**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-09-24T21:51:00-05:00 (approx.)
- **Completed:** 2026-09-24T22:19:45-05:00
- **Tasks:** 3
- **Files modified:** 13 (8 created, 5 modified/edited)

## Accomplishments
- Reconciled `Cliente` entity to the actual `clientes` table (`clinicaId`, `numeroMascotas` read-time aggregate, vinculación fields) and removed the two fields that never existed in the schema (`veterinarioId`, `mascotaIds`)
- Real `SupabaseClienteRepository.buscar()` against the live `clientes` table with an embedded `mascotas(count)` aggregate, sanitized `.or()` search filter, and two-tier `PostgrestException`/generic error handling
- `ClientesNotifier` debounces every keystroke 350ms before firing a real query, with a sequence guard that drops stale/out-of-order responses (CLI-03, D-06)
- `ClientesListScreen` now renders real clientes with phone + mascota-count badge, and the exact UI-SPEC empty/no-results/error copy — no mock data anywhere
- Shared `test/helpers/router_harness.dart` and `test/helpers/fake_clientes.dart` ready for Plans 04-09 to reuse without re-deriving the fake/router shape

## Task Commits

Each task was committed atomically:

1. **Task 1: Failing tests + Wave 0 fakes for instant client search (RED)** - `dc1b647` (test)
2. **Task 2: Cliente entity, failure, search helpers, repository and debounced notifier (GREEN for providers test)** - `458559d` (feat)
3. **Task 3: ClientesListScreen wired at /clientes (GREEN for screen test)** - `3e03cb3` (feat)

_TDD plan: RED → GREEN → GREEN (no separate refactor commit needed; no regressions to clean up)._

## Files Created/Modified
- `lib/features/clients/domain/entities/cliente.dart` - reconciled entity (clinicaId, numeroMascotas, vinculación fields)
- `lib/features/clients/domain/cliente_failure.dart` - ClienteFailure exception, mirrors AuthFailure
- `lib/core/data/busqueda.dart` - sanitizarBusqueda + filtroOrIlike, shared with future Pacientes search
- `lib/features/clients/data/repositories/supabase_cliente_repository.dart` - real Supabase repository
- `lib/features/clients/presentation/providers/clientes_providers.dart` - clienteRepositoryProvider + ClientesNotifier
- `lib/features/clients/presentation/screens/clientes_list_screen.dart` - real list + search screen
- `lib/features/clients/presentation/clientes_routes.dart` - clientesRoute, future child routes attach here
- `lib/core/router/app_router.dart` - `/clientes` branch now uses `clientesRoute` instead of `ComingSoonScreen`
- `lib/core/widgets/inputs/app_text_field.dart` - added `hideLabel` param for label-less search fields
- `test/helpers/router_harness.dart` - shared GoRouter+ProviderScope test harness
- `test/helpers/fake_clientes.dart` - FakeClienteRepository + FakeClientesNotifier + sample clientes
- `test/clientes_providers_test.dart` - provider/notifier unit tests
- `test/clientes_list_screen_test.dart` - screen widget tests

## Decisions Made
- Followed the plan's concrete-repository-no-interface convention exactly (matches `SupabaseAuthRepository`'s shape, no `domain/repositories/` file added)
- `numeroMascotas` kept strictly as a read-time aggregate (never denormalized/stored), per the plan's schema-gap analysis

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `ClientesNotifier.build()` raced `authProfileProvider`'s own pending async build**
- **Found during:** Task 2, first `flutter test` run of `clientes_providers_test.dart`
- **Issue:** `ref.watch(authProfileProvider).value?.clinicaId` reads the synchronous snapshot of another `AsyncNotifier` before its own `build()` future has resolved (still `AsyncLoading`, `.value == null`), which produced hangs/timeouts under real-time (`test()`, not `testWidgets`) execution once combined with Riverpod's default retry (see #2 below) rather than a clean, quick empty result.
- **Fix:** Changed to `(await ref.watch(authProfileProvider.future))?.clinicaId` — the documented Riverpod pattern for depending on another AsyncNotifier's resolved value.
- **Files modified:** `lib/features/clients/presentation/providers/clientes_providers.dart`
- **Verification:** `flutter test test/clientes_providers_test.dart` — all 10 tests pass
- **Committed in:** `458559d` (Task 2 commit)

**2. [Rule 1 - Bug] Test `ProviderContainer` didn't disable Riverpod 3's default retry-with-backoff**
- **Found during:** Task 2, same test run — the "repository throws `ClienteFailure`" test hung and eventually errored with "provider was disposed during loading state"
- **Issue:** `ProviderContainer` in `test/clientes_providers_test.dart`'s `_containerWith()` helper omitted `retry: (retryCount, error) => null`. Riverpod 3.3.2's `ProviderContainer` retries a failed provider build with exponential backoff by default; an intentionally-thrown `ClienteFailure` was silently retried in the background instead of settling into `AsyncError` immediately, and the container was disposed (by `addTearDown`) mid-retry once the test's own 30s timeout fired.
- **Fix:** Added `retry: (retryCount, error) => null` to the helper, matching the same convention already used by `test/helpers/fake_auth.dart`'s `appUnderTest()` and `test/helpers/router_harness.dart`'s `routerHarness()`.
- **Files modified:** `test/clientes_providers_test.dart`
- **Verification:** `flutter test test/clientes_providers_test.dart` — the ClienteFailure test now settles in ~0ms
- **Committed in:** `458559d` (Task 2 commit)

**3. [Rule 1 - Bug] `AsyncValue.copyWithPrevious` is `@internal` in the installed riverpod 3.3.2, not public**
- **Found during:** Task 2, `flutter analyze` after writing the notifier per the plan's suggested pattern
- **Issue:** The plan explicitly flagged this as a possibility ("use `copyWithPrevious` if public... otherwise plain `AsyncLoading`"). Grepping the pub-cache source confirmed every `copyWithPrevious` override/declaration in `riverpod-3.3.2/lib/src/core/async_value.dart` carries `@internal`, and using it triggered an `invalid_use_of_internal_member` analyzer warning.
- **Fix:** `ClientesNotifier.search()` no longer sets an intermediate `AsyncLoading` state at all — it leaves `state` untouched (still the previous `AsyncData`) until the guarded fetch resolves, then assigns the final result. This achieves the same "results re-render in place" UX the plan asked for without touching an internal API, at the cost of not showing a transient loading indicator during a debounced re-search (only the very first, unfiltered load shows the centered spinner, per `AsyncNotifier`'s normal initial-loading state).
- **Files modified:** `lib/features/clients/presentation/providers/clientes_providers.dart`, `lib/features/clients/presentation/screens/clientes_list_screen.dart`
- **Verification:** `flutter analyze` clean; screen test's debounced-search-then-pump assertions pass
- **Committed in:** `458559d` (providers), `3e03cb3` (screen)

---

**Total deviations:** 3 auto-fixed (all Rule 1 - bug fixes, all discovered via `flutter analyze`/`flutter test` during the plan's own TDD cycle)
**Impact on plan:** All three were correctness fixes required to make the plan's own acceptance tests pass reliably; no scope creep, no architectural changes.

## Issues Encountered
- First `flutter test` invocations took several minutes longer than expected due to CPU contention with sibling worktree agents (02-01, 02-02) running their own `flutter test`/`flutter analyze` concurrently on the same machine — not a code issue, just slower turnaround while iterating on the two bugs above.

## User Setup Required
None - no external service configuration required (uses the same Supabase project already configured in Phase 1).

## Next Phase Readiness
- CLI-03 done: clientes are searchable/filterable by nombre or teléfono, instantly, against the real backend.
- `Cliente`, `ClienteFailure`, `clienteRepositoryProvider`, `clientesRoute`, `routerHarness`, and the `fake_clientes.dart` fakes are now stable contracts — Plans 04 (alta combinada), 07 (ficha), 08 (vinculación) and 09 (edición) build directly on top of them without renaming anything.
- No blockers. `lib/core/router/app_router.dart` and `lib/core/widgets/inputs/app_text_field.dart` were touched (shared files noted in the wave's coordination note) — no conflicts expected since no sibling plan in this wave touches them.

---
*Phase: 02-clientes-y-pacientes*
*Completed: 2026-09-24*

## Self-Check: PASSED

All 9 created files verified present on disk; all 3 task commit hashes (`dc1b647`, `458559d`, `3e03cb3`) verified present in `git log --oneline --all`.
