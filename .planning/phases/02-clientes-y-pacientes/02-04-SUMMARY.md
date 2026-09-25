---
phase: 02-clientes-y-pacientes
plan: 04
subsystem: clients+patients
tags: [flutter, riverpod, supabase, postgrest-rpc, go_router, forms, intl]

# Dependency graph
requires:
  - phase: 02-clientes-y-pacientes
    plan: 01
    provides: registrar_cliente_con_mascota RPC, mascotas.foto_path, mascota_pesos table (all LIVE)
  - phase: 02-clientes-y-pacientes
    plan: 03
    provides: Cliente entity, clienteRepositoryProvider, clientesProvider, ClientesListScreen, clientesRoute, routerHarness, fake_clientes.dart
provides:
  - "Mascota reconciled to schema (duenoId, clinicaId, fotoPath, duenoNombre) + Especie extension (etiqueta/etiquetaPlural) + especieDesdeTexto parser"
  - "MascotaFailure domain exception mirroring ClienteFailure"
  - "SupabaseMascotaRepository: registrarClienteConMascota (RPC), porCliente, actualizarFotoPath — two-tier PostgrestException handling"
  - "mascotaRepositoryProvider + mascotasDeClienteProvider (autoDispose.family) for Plan 07"
  - "AppFilterChip — reusable pill selector (core/widgets), reused by Pacientes species filter (Plan 06)"
  - "MascotaCamposSection — shared pet-fields section (nombre/especie/raza/fecha/peso + disclosure), reused standalone by MascotaFormScreen (Plan 09)"
  - "lib/core/utils/formato.dart — formatearFecha/parsearFecha/parsearPeso/formatearPeso/formatearEdad (dd/mm/aaaa + comma-decimal kg)"
  - "NuevoClienteMascotaScreen at /clientes/nuevo — combined create flow (D-02), CLI-01 + PAT-01 create half"
  - "test/helpers/fake_mascotas.dart — FakeMascotaRepository + sample mascotas (mascotaRocky/Luna/Michi)"
affects: [02-05, 02-06, 02-07, 02-08, 02-09]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Calendar-validated date parsing without a calendar library: parseStrict then reformat-and-compare against the original trimmed input — Dart's DateTime constructor silently rolls over invalid days (31/02 -> 02/03) instead of throwing, so parseStrict alone is not enough"
    - "MascotaCamposSection's pesoController is nullable by contract — passing null hides the peso field entirely (edit mode in Plan 09), avoiding a second near-duplicate widget"
    - "Screen-level manual field-listener validation (no Form/validator widgets) mirrors register_screen.dart exactly: TextEditingController.addListener(setState) gates AppButton.onPressed"

key-files:
  created:
    - lib/features/patients/domain/mascota_failure.dart
    - lib/core/utils/formato.dart
    - lib/features/patients/data/repositories/supabase_mascota_repository.dart
    - lib/features/patients/presentation/providers/mascotas_providers.dart
    - lib/core/widgets/chips/app_filter_chip.dart
    - lib/features/patients/presentation/widgets/mascota_campos_section.dart
    - lib/features/clients/presentation/screens/nuevo_cliente_mascota_screen.dart
    - test/helpers/fake_mascotas.dart
    - test/formato_test.dart
    - test/nuevo_cliente_mascota_screen_test.dart
  modified:
    - lib/features/patients/domain/entities/mascota.dart
    - lib/features/clients/presentation/screens/clientes_list_screen.dart
    - lib/features/clients/presentation/clientes_routes.dart

key-decisions:
  - "Screen trims cliente/mascota nombre and teléfono before calling the repository (not the repository) — the RPC call-site itself always trims too, but the fake used in tests doesn't, so the screen owns the trim to keep the plan's exactly-once-with-trimmed-values test contract honest"
  - "MascotaCamposSection collapsed-by-default disclosure (raza/fecha/peso) implemented with a plain InkWell+Icon toggle, no AnimatedSize/ExpansionTile — matches the codebase's existing 'no unnecessary animation dependency' convention"

requirements-completed: [CLI-01, PAT-01]

# Metrics
duration: ~40min
completed: 2026-09-25
---

# Phase 2 Plan 04: Combined Cliente+Mascota Create Flow Summary

**Single-scroll `NuevoClienteMascotaScreen` at `/clientes/nuevo` that registers a new dueño and their first mascota in one atomic `registrar_cliente_con_mascota` RPC call, wired to a new "Nuevo cliente" FAB on the Clientes list — the phase's primary zero-friction path (D-01/D-02/D-04).**

## Performance

- **Duration:** ~40 min
- **Tasks:** 3 of 3 completed
- **Files modified:** 13 (10 created, 3 modified)

## Accomplishments

- Reconciled `Mascota` to the live schema (`duenoId`, `clinicaId`, `fotoPath`, `duenoNombre`) — removed `veterinarioId`/`Sexo`/`color`/`esterilizado`/`pesoKg`/`fotoUrl`, none of which exist in `mascotas` or any PAT-01..05 requirement — and added the `Especie` extension (`etiqueta`/`etiquetaPlural`) plus `especieDesdeTexto` parser used by the chip selector.
- Real `SupabaseMascotaRepository` with `registrarClienteConMascota` (the atomic RPC, called exactly once per submit — never two sequential inserts), `porCliente` (for Plan 07's mascotas-of-cliente list), and `actualizarFotoPath` (for Plan 05's photo upload) — two-tier `PostgrestException`/generic-catch error handling throughout, mirroring `SupabaseClienteRepository`.
- `lib/core/utils/formato.dart`: Colombian `dd/mm/aaaa` date parsing/formatting (with a reformat-and-compare round-trip to reject calendar-invalid dates like `31/02/2020`, since `DateFormat.parseStrict` alone silently rolls those over) and comma-or-dot decimal weight parsing/formatting.
- `AppFilterChip` (new shared widget, `core/widgets/chips/`) and `MascotaCamposSection` (shared pet-fields section with the D-04 collapsed "Agregar más detalles" disclosure) — both built to be reused as-is by later plans (species filter in Plan 06, standalone form in Plan 09).
- `NuevoClienteMascotaScreen`: one continuous `SingleChildScrollView` (no stepper, no `PageView`, no intermediate navigation step), the "Guardar cliente y mascota" button disabled until all four required fields are filled, inline dd/mm/aaaa + peso validation before submit, and a Spanish error message on `MascotaFailure` that keeps the vet on the form.
- Clientes list now has a "Nuevo cliente" FAB navigating to `/clientes/nuevo`; the route sits as the first child of `clientesRoute` so it can never be shadowed by a future `:id` child route.

## Task Commits

1. **Task 1: Failing tests for the combined alta + formato helpers (RED)** - `2f4ff22` (test)
2. **Task 2: Mascota entity, MascotaFailure, formato helpers, repository and providers (GREEN for formato test)** - `14f6a5e` (feat)
3. **Task 3: AppFilterChip, MascotaCamposSection, NuevoClienteMascotaScreen, 'Nuevo cliente' entry point (GREEN)** - `4ea02b9` (feat)

_TDD plan: RED → GREEN → GREEN. `flutter analyze` was clean on the production files touched in Task 2 (verified with a scoped `dart analyze` on just those 5 files) but not project-wide until Task 3 landed — see Deviations._

## Files Created/Modified

- `lib/features/patients/domain/entities/mascota.dart` - reconciled entity (duenoId/clinicaId/fotoPath/duenoNombre), `Especie` extension + parser
- `lib/features/patients/domain/mascota_failure.dart` - `MascotaFailure` exception
- `lib/core/utils/formato.dart` - date/weight/edad formatting+parsing helpers
- `lib/features/patients/data/repositories/supabase_mascota_repository.dart` - real Supabase repository (RPC + 2 queries)
- `lib/features/patients/presentation/providers/mascotas_providers.dart` - `mascotaRepositoryProvider` + `mascotasDeClienteProvider`
- `lib/core/widgets/chips/app_filter_chip.dart` - reusable pill selector chip
- `lib/features/patients/presentation/widgets/mascota_campos_section.dart` - shared pet-fields section
- `lib/features/clients/presentation/screens/nuevo_cliente_mascota_screen.dart` - combined create screen
- `lib/features/clients/presentation/screens/clientes_list_screen.dart` - added "Nuevo cliente" FAB
- `lib/features/clients/presentation/clientes_routes.dart` - added `nuevo` child route (first child)
- `test/helpers/fake_mascotas.dart` - `FakeMascotaRepository` + sample mascotas
- `test/formato_test.dart` - unit tests for `formato.dart`
- `test/nuevo_cliente_mascota_screen_test.dart` - widget tests for the combined create flow

## Decisions Made

- Followed the plan's concrete-repository-no-interface convention exactly (matches `SupabaseClienteRepository`/`SupabaseAuthRepository`'s shape).
- The screen (not the repository) trims `clienteNombre`/`clienteTelefono`/`mascotaNombre` before calling `registrarClienteConMascota`, since the RPC call-site's own `.trim()` calls only take effect against a real Supabase client — the in-memory `FakeMascotaRepository` used in tests records values verbatim, so trimming had to happen before the call to satisfy the "trimmed values reach the repository" test contract.
- `parsearFecha` uses a reformat-and-compare round-trip after `DateFormat('dd/MM/yyyy').parseStrict(...)` to reject calendar-invalid dates (e.g. `31/02/2020`), because Dart's `DateTime` constructor normalizes out-of-range days/months instead of throwing, and `parseStrict` only checks pattern-matching strictness, not calendar validity.
- `mascota_pesos`/`registrar_mascota`/photo-upload wiring were intentionally left untouched — those are Plan 05 (photo)/06 (search)/07-09 (detail/edit) scope; this plan only needed `mascota_peso_kg` as an optional param passed straight through to the RPC when the vet fills the (optional) peso field during the initial create.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Doc comment on `NuevoClienteMascotaScreen` literally contained the plan's own forbidden-pattern grep terms**
- **Found during:** Task 3, running the `<verify><automated>` command (`! grep -qE "PageView|Stepper|Siguiente" ...`)
- **Issue:** The screen's class-level doc comment explained what the screen does *not* use ("no stepper, no `PageView`, no 'Siguiente' between sections"), which literally contains the three substrings the plan's own negative grep gate checks for — a false-positive failure caused by the comment's wording, not the implementation.
- **Fix:** Reworded the doc comment to describe the same guarantee ("both sections always visible with no intermediate navigation step between them") without using the literal words `PageView`/`Stepper`/`Siguiente`.
- **Files modified:** `lib/features/clients/presentation/screens/nuevo_cliente_mascota_screen.dart`
- **Verification:** `! grep -qE "PageView|Stepper|Siguiente" lib/features/clients/presentation/screens/nuevo_cliente_mascota_screen.dart && echo NO_STEPPER_OK` → prints `NO_STEPPER_OK`
- **Committed in:** `4ea02b9` (Task 3 commit)

### Noted, Not Fixed (verification-script limitation, not a code issue)

**2. The plan's `! grep -qE "FilterChip\(|ChoiceChip\(" lib/core/widgets/chips/app_filter_chip.dart` gate is a structural false positive for this file.** The CONTRACTS section mandates the class be named `AppFilterChip`, whose own constructor declaration (`const AppFilterChip({...`) contains the literal substring `FilterChip(` — the same substring the gate is trying to forbid (Material's `FilterChip(...)`/`ChoiceChip(...)` widget calls). Any class named `AppFilterChip` fails this exact grep by construction, independent of whether Material's `FilterChip`/`ChoiceChip` widgets are actually used. Direct code review of `app_filter_chip.dart` confirms the *only* match for that pattern is the class's own constructor line, and the widget is built entirely on `Container`+`InkWell` (no Material `Chip` subtype anywhere in the file or its imports) — the actual requirement ("no Material FilterChip/ChoiceChip") is satisfied; only the letter of the automated grep gate is not. Not fixed because the fix (renaming the class) would violate the plan's own CONTRACTS naming mandate that Plans 06/09 depend on.

**Total deviations:** 1 auto-fixed (Rule 1, doc-comment wording), 1 noted verification-script limitation (no code change, confirmed by direct review).
**Impact on plan:** No scope creep, no architectural changes, no behavior changes — both items are wording/tooling-level, not functional.

## Issues Encountered

- **Expected TDD-sequencing gap in Task 2's own `<verify>` command:** Task 2's automated verify starts with a project-wide `flutter analyze`, but Task 1's RED test file (`test/nuevo_cliente_mascota_screen_test.dart`, committed in Task 1) already imports `NuevoClienteMascotaScreen` and `AppFilterChip`, which are only created in Task 3. A project-wide `flutter analyze` therefore cannot be clean until Task 3 lands, regardless of how correct Task 2's own files are. Verified Task 2's actual production files were analyzer-clean via a scoped `dart analyze` on just those 5 files (`No issues found!`), then confirmed the project-wide `flutter analyze` was clean immediately after Task 3 completed. This is inherent to the plan's own task/file split, not a defect introduced by this execution — documented here rather than silently reported as "DATA_OK" against a check that could not literally pass yet.

## User Setup Required

None - no external service configuration required (uses the same live Supabase project and RPC already applied/verified in Plan 01).

## Next Phase Readiness

- CLI-01 done: a new cliente is created with nombre + teléfono, no account, via the combined flow.
- PAT-01 create half done: a new mascota is created with especie (+ optional raza/fecha→edad/first peso) linked to its owner, atomically with the cliente.
- D-02/D-04 honoured: one continuous screen, four required fields, optional details collapsed by default.
- `Mascota`, `MascotaFailure`, `SupabaseMascotaRepository` (incl. `porCliente` and `actualizarFotoPath`), `mascotaRepositoryProvider`, `mascotasDeClienteProvider`, `AppFilterChip`, `MascotaCamposSection` (with its `foto` slot ready for Plan 05), `formato.dart`, and `fake_mascotas.dart` are now stable contracts — Plans 05-09 build directly on top of them without renaming anything.
- No blockers. `lib/features/clients/presentation/screens/clientes_list_screen.dart` and `clientes_routes.dart` were touched (both owned by Plan 03 in Wave 1, now extended here in Wave 2) — no conflicts expected since Wave 2 has only this one plan.

## Self-Check

- `lib/features/patients/domain/entities/mascota.dart`: FOUND, reconciled (no `veterinarioId`/`Sexo`/`esterilizado`/`pesoKg`/`fotoUrl`)
- `lib/features/patients/domain/mascota_failure.dart`: FOUND
- `lib/core/utils/formato.dart`: FOUND
- `lib/features/patients/data/repositories/supabase_mascota_repository.dart`: FOUND (contains `registrar_cliente_con_mascota`)
- `lib/features/patients/presentation/providers/mascotas_providers.dart`: FOUND
- `lib/core/widgets/chips/app_filter_chip.dart`: FOUND
- `lib/features/patients/presentation/widgets/mascota_campos_section.dart`: FOUND
- `lib/features/clients/presentation/screens/nuevo_cliente_mascota_screen.dart`: FOUND
- `test/helpers/fake_mascotas.dart`: FOUND
- `test/formato_test.dart`: FOUND
- `test/nuevo_cliente_mascota_screen_test.dart`: FOUND
- Commit `2f4ff22` (Task 1): FOUND in `git log --oneline`
- Commit `14f6a5e` (Task 2): FOUND in `git log --oneline`
- Commit `4ea02b9` (Task 3): FOUND in `git log --oneline`
- `flutter analyze`: clean (No issues found!)
- `flutter test` (full suite): 64/64 passed

## Self-Check: PASSED

---
*Phase: 02-clientes-y-pacientes*
*Completed: 2026-09-25*
