---
phase: 02-clientes-y-pacientes
plan: 06
subsystem: patients
tags: [flutter, riverpod, supabase, postgrest, go_router, debounce, search, two-step-search]

# Dependency graph
requires:
  - phase: 02-clientes-y-pacientes
    plan: 03
    provides: sanitizarBusqueda/filtroOrIlike shared search helpers (lib/core/data/busqueda.dart), ClientesNotifier debounce/sequence-guard pattern to mirror, routerHarness, fake_auth.dart
  - phase: 02-clientes-y-pacientes
    plan: 04
    provides: Mascota entity reconciled to schema, MascotaFailure, SupabaseMascotaRepository (registrarClienteConMascota/porCliente/actualizarFotoPath), AppFilterChip, formatearEdad, fake_mascotas.dart base shape
provides:
  - "buscarMascotasEnDosPasos: top-level, SupabaseClient-free orchestration function for the two-step owner-name search (resolve dueño ids -> fold into mascotas' own .or() via .in.())"
  - "SupabaseMascotaRepository.buscar(query, clinicaId) — real two-step Postgres search by nombre/especie/dueño"
  - "MascotasNotifier + mascotasProvider (350ms debounce, stale-response sequence guard) mirroring ClientesNotifier exactly"
  - "PacientesListScreen wired at /pacientes replacing ComingSoonScreen — instant search + client-side species chip filter, no FAB"
  - "pacientesRoute (lib/features/patients/presentation/pacientes_routes.dart) — child routes for ficha/edit attach here in later plans"
  - "fake_mascotas.dart: FakeMascotaRepository.buscar + busquedas log, FakeMascotasNotifier"
affects: [02-08, 02-09]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Two-step search extracted as a top-level function (buscarMascotasEnDosPasos) taking resolverDuenos/consultar callbacks, so the resolve-then-fold orchestration logic is unit-testable without a real SupabaseClient — the repository method itself supplies the two real Postgres-calling closures"
    - "Species chip filtering is purely client-side (filters the already-fetched/searched mascotasProvider value in memory) — never triggers a new debounced query, distinct from the text-search path which does debounce+query"

key-files:
  created:
    - lib/features/patients/presentation/screens/pacientes_list_screen.dart
    - lib/features/patients/presentation/pacientes_routes.dart
    - test/mascotas_providers_test.dart
    - test/pacientes_list_screen_test.dart
  modified:
    - lib/features/patients/data/repositories/supabase_mascota_repository.dart
    - lib/features/patients/presentation/providers/mascotas_providers.dart
    - lib/core/router/app_router.dart
    - test/helpers/fake_mascotas.dart
    - test/widget_test.dart

key-decisions:
  - "Reused the existing sanitizarBusqueda/filtroOrIlike helpers as-is (Plan 03) rather than writing mascota-specific sanitization — buscarMascotasEnDosPasos sanitizes once up front and passes the sanitized query to both resolverDuenos and filtroOrIlike (idempotent double-sanitize on the filtro side, harmless)"
  - "Chose 'Rocky()...,' (punctuation only at the string's edges) for the sanitization test input instead of the plan's illustrative 'Ro(cky),' — sanitizarBusqueda replaces delimiters with a space rather than deleting them outright, so punctuation embedded mid-word (as in 'Ro(cky)') would split it into two words ('Ro cky'); an edge-only example is the one sanitizarBusqueda's real, already-shared implementation actually collapses back to a single clean word, and changing the shared helper's behavior was out of scope for this plan (it's used by Clientes search too)"
  - "PacientesListScreen rows render duenoNombre/raza/edad but have no onTap and no photo thumbnail yet — intentionally deferred to Plan 08 per this plan's own scope note ('List thumbnails and row navigation to the ficha arrive with the ficha itself in Plan 08')"

requirements-completed: [PAT-04]

# Metrics
duration: ~45min
completed: 2026-09-25
---

# Phase 2 Plan 06: Pacientes Instant Search (PAT-04) Summary

**Real two-step Postgres search for pacientes (nombre, dueño or especie) with a 350ms-debounced notifier and client-side species chips, replacing the ComingSoonScreen stub at `/pacientes`.**

## Performance

- **Duration:** ~45 min
- **Tasks:** 3 of 3 completed
- **Files modified:** 9 (4 created, 5 modified)

## Accomplishments

- `buscarMascotasEnDosPasos`: a top-level, dependency-injected function that orchestrates the two-step search (sanitize query → resolve matching dueño ids → fold them into the mascotas query's own `.or()` via `.in.()`) — fully unit-tested without touching a real `SupabaseClient`, confirming call order, the exact `.in.()` filtro string, the no-match no-in-clause case, and pre-sanitization.
- `SupabaseMascotaRepository.buscar(query, clinicaId)`: the real Postgres-backed implementation — `resolverDuenos` queries `clientes.id` scoped to the clinic with a `.limit(50)` cap (T-02-28 mitigation), `consultar` queries `mascotas` with the `mascotas_dueno_misma_clinica_fkey`-hinted `clientes(nombre)` embed for `duenoNombre`, two-tier `PostgrestException`/generic error handling throughout.
- `MascotasNotifier` + `mascotasProvider`: 350ms debounce, stale-response sequence guard, `ref.mounted` checks — an exact mirror of `ClientesNotifier` (Plan 03), including the `await ref.watch(authProfileProvider.future)` pattern that avoids racing that provider's own pending build.
- `PacientesListScreen`: real list + instant search (hint "Buscar por nombre, dueño o especie") + Todos/Perros/Gatos/Otros `AppFilterChip` row that filters the already-fetched result set in memory (zero extra network round-trips per chip tap) + exact UI-SPEC empty/no-results/error copy. No `FloatingActionButton` — per D-02/D-03, every mascota is created through an owner, never standalone.
- `pacientesRoute` mirrors `clientesRoute`'s convention so later ficha/edit plans (08/09) never need to touch `app_router.dart` again.

## Task Commits

Each task was committed atomically:

1. **Task 1: Failing tests for two-step pet search, debounce and species chips (RED)** - `006a308` (test)
2. **Task 2: Two-step mascota search in the repository + MascotasNotifier (GREEN for providers test)** - `f410b80` (feat)
3. **Task 3: PacientesListScreen wired at /pacientes (GREEN for screen + widget tests)** - `acb30d5` (feat)

_TDD plan: RED → GREEN → GREEN. `flutter analyze` clean and full `flutter test` (76/76) green after Task 3._

## Files Created/Modified

- `lib/features/patients/data/repositories/supabase_mascota_repository.dart` - added top-level `buscarMascotasEnDosPasos` + `SupabaseMascotaRepository.buscar`
- `lib/features/patients/presentation/providers/mascotas_providers.dart` - added `MascotasNotifier` + `mascotasProvider`
- `lib/features/patients/presentation/screens/pacientes_list_screen.dart` - real list/search/chips screen (new)
- `lib/features/patients/presentation/pacientes_routes.dart` - `pacientesRoute` (new)
- `lib/core/router/app_router.dart` - `/pacientes` branch now uses `pacientesRoute` instead of `ComingSoonScreen`
- `test/helpers/fake_mascotas.dart` - added `FakeMascotaRepository.buscar`/`busquedas`, `FakeMascotasNotifier`
- `test/mascotas_providers_test.dart` - unit tests for `buscarMascotasEnDosPasos` + `mascotasProvider` (new)
- `test/pacientes_list_screen_test.dart` - widget tests for `PacientesListScreen` (new)
- `test/widget_test.dart` - `'cambiar de pestaña'` now taps Agenda instead of the now-real Pacientes tab

## Decisions Made

- Followed the plan's concrete-repository-no-interface convention exactly (matches `SupabaseClienteRepository`/`SupabaseMascotaRepository`'s existing shape).
- Kept `sanitizarBusqueda`/`filtroOrIlike` (Plan 03) as the single shared sanitization/filter-building implementation rather than duplicating mascota-specific logic — see the sanitization test-input decision above.
- Used the explicit FK-hinted embed `clientes!mascotas_dueno_misma_clinica_fkey(nombre)` per the plan's CONTRACTS and the FK name confirmed in the plan's interfaces section. **This could not be verified against the live Supabase project in this execution environment** (unit/widget tests only, no live network access) — if the live PostgREST instance rejects the explicit FK hint, the fallback per the plan's own contingency is to drop it to the unqualified `clientes(nombre)` embed in `SupabaseMascotaRepository.buscar`'s `consultar` closure. Flagging this for verification the next time the app runs against the real backend (e.g. during Plan 08/09's manual verification or a future `checkpoint:human-verify`).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Plan's illustrative sanitization test input would not clean up the way the plan describes**
- **Found during:** Task 1, writing `mascotas_providers_test.dart`'s sanitization test
- **Issue:** The plan's interfaces section states `query 'Ro(cky),' is sanitized to 'Rocky' before both steps`. The actual (already shared, Plan-03-established) `sanitizarBusqueda` replaces `,()` with a space and then collapses repeated whitespace — for `'Ro(cky),'` the `(` sits directly between `o` and `c` with no pre-existing space, so replacing it with a space produces `'Ro cky'` (two words), not `'Rocky'`. This is a real, verified behavior of the existing shared helper (confirmed against Plan 03's own `clientes_providers_test.dart` assertion, where the punctuation is always adjacent to an existing space and so the split is invisible).
- **Fix:** Used `'Rocky(),'` (punctuation only at the trailing edge, no space-adjacency ambiguity) as the test input instead — this sanitizes cleanly to `'Rocky'` under the real, unmodified `sanitizarBusqueda`, preserving the same "sanitize before both steps" behavior the plan intends without changing the shared helper's contract (which Clientes search also depends on).
- **Files modified:** `test/mascotas_providers_test.dart`
- **Verification:** `flutter test test/mascotas_providers_test.dart` — sanitization test passes; `flutter test` (full suite) still 76/76 green, confirming Clientes search behavior was untouched
- **Committed in:** `006a308` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1, test-input correction — no production code behavior changed)
**Impact on plan:** No scope creep, no architectural changes. The shared `sanitizarBusqueda` helper (Plan 03) was deliberately left unmodified since changing its space-insertion behavior would also affect the already-shipped Clientes search.

## Issues Encountered

None beyond the sanitization-input correction documented above.

## User Setup Required

None - no external service configuration required (uses the same live Supabase project already configured in Phase 1). **Follow-up note:** the explicit FK-hinted embed (`clientes!mascotas_dueno_misma_clinica_fkey(nombre)`) in `SupabaseMascotaRepository.buscar` has not been exercised against the live PostgREST endpoint in this execution — verify on first real device/backend run per the "Decisions Made" note above.

## Next Phase Readiness

- PAT-04 done: pacientes are searchable/filterable by nombre, dueño or especie on the real backend, instantly (D-06), with client-side species chips.
- `buscarMascotasEnDosPasos`, `SupabaseMascotaRepository.buscar`, `mascotaRepositoryProvider`, `mascotasProvider`, `pacientesRoute`, and `fake_mascotas.dart`'s extended fakes are now stable contracts — Plans 08 (ficha) and 09 (edición) build directly on top of them without renaming anything.
- No blockers. `lib/core/router/app_router.dart` was touched (shared file) — this wave's sibling plans (02-05, 02-07) do not touch it per the orchestrator's disjoint-files coordination note, so no merge conflict expected.
- Deferred to Plan 08 (documented, not a defect): `PacientesListScreen` rows have no `onTap` and no photo thumbnail — the plan's own scope note assigns ficha navigation + photo thumbnails to Plan 08 alongside the ficha screen itself, to avoid a dead route this plan would otherwise introduce.

---
*Phase: 02-clientes-y-pacientes*
*Completed: 2026-09-25*

## Self-Check

- `lib/features/patients/data/repositories/supabase_mascota_repository.dart`: FOUND (contains `buscarMascotasEnDosPasos`)
- `lib/features/patients/presentation/providers/mascotas_providers.dart`: FOUND (contains `MascotasNotifier`)
- `lib/features/patients/presentation/screens/pacientes_list_screen.dart`: FOUND (contains `Buscar por nombre, dueño o especie`)
- `lib/features/patients/presentation/pacientes_routes.dart`: FOUND (contains `pacientesRoute`)
- `lib/core/router/app_router.dart`: FOUND (contains `pacientesRoute`, no longer contains `ComingSoonScreen(title: 'Pacientes')`)
- `test/helpers/fake_mascotas.dart`: FOUND (contains `buscar`, `FakeMascotasNotifier`)
- `test/mascotas_providers_test.dart`: FOUND
- `test/pacientes_list_screen_test.dart`: FOUND
- Commit `006a308` (Task 1): FOUND in `git log --oneline`
- Commit `f410b80` (Task 2): FOUND in `git log --oneline`
- Commit `acb30d5` (Task 3): FOUND in `git log --oneline`
- `flutter analyze`: clean (No issues found!)
- `flutter test` (full suite): 76/76 passed

## Self-Check: PASSED
