---
phase: 03-historia-cl-nica
plan: 03
subsystem: clinical-history
tags: [riverpod, supabase, rpc, forms, go_router]

# Dependency graph
requires:
  - phase: 02-clientes-y-pacientes
    provides: mascotaRepositoryProvider, pesosProvider, MascotaDetailScreen insertion point, parsearPeso, AppButton/AppTextField/AppTopBar/AppCard, routerHarness test helper
provides:
  - "Reconciled Consulta/ExamenFisico entity (anamnesis nullable, no proximaCita/adjuntoUrls, no copyWith - append-only per HIST-04)"
  - "SupabaseConsultaRepository: porMascota + registrarConsulta (single RPC), no update/delete/insert path"
  - "consultaRepositoryProvider, consultasProvider, registrarConsultaProvider (dual invalidation: consultasProvider always, pesosProvider only when pesoKg != null - D-02)"
  - "ConsultaFormScreen at /pacientes/:id/consultas/nueva and /clientes/:id/mascotas/:mascotaId/consultas/nueva"
  - "MascotaDetailScreen: Historia clinica heading + primary 'Nueva consulta' CTA; Editar demoted to outline"
  - "test/helpers/fake_consultas.dart (FakeConsultaRepository + consultasRocky fixtures) reused by Plans 03-04/03-05"
  - "formato.dart: parsearNumeroPositivo (temperatura/frecuencias)"
affects: [03-04, 03-05, 03-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Single RPC call carries both consulta fields and peso (D-02); repository never calls registrarPeso from this flow"
    - "Optional form fields collapsed behind an inline 'Agregar mas detalles' disclosure (copied inline from MascotaCamposSection, not extracted to a shared widget per plan)"
    - "Append-only entity: no copyWith on Consulta, no update/delete method on the repository (HIST-04 grep gate)"

key-files:
  created:
    - lib/features/clinical_history/domain/consulta_failure.dart
    - lib/features/clinical_history/data/repositories/supabase_consulta_repository.dart
    - lib/features/clinical_history/presentation/providers/consultas_providers.dart
    - lib/features/clinical_history/presentation/screens/consulta_form_screen.dart
    - test/helpers/fake_consultas.dart
    - test/consultas_providers_test.dart
    - test/consulta_form_screen_test.dart
  modified:
    - lib/features/clinical_history/domain/entities/consulta.dart
    - lib/core/utils/formato.dart
    - lib/features/patients/presentation/pacientes_routes.dart
    - lib/features/clients/presentation/clientes_routes.dart
    - lib/features/patients/presentation/screens/mascota_detail_screen.dart
    - test/formato_test.dart
    - test/mascota_detail_screen_test.dart

key-decisions:
  - "No shared widget extracted for the 'Agregar mas detalles' disclosure - copied inline into ConsultaFormScreen per the plan's explicit instruction, since MascotaCamposSection's version is coupled to its own field set"
  - "Numeric fields (temperatura, frecuencia cardiaca/respiratoria) validated client-side via parsearNumeroPositivo before any provider call; invalid input never reaches the RPC"

requirements-completed: [HIST-01, HIST-04]

# Metrics
duration: ~50min (interrupted once mid-task by a session rate limit between Task 2 and Task 3; resumed same worktree, verified state, completed Task 3)
completed: 2026-09-28
---

# Phase 3 Plan 03: Nueva consulta vertical slice Summary

**First vertical slice of Phase 3: reconciled Consulta entity, repository, providers, and ConsultaFormScreen wired into both route trees, with the pet ficha's "Nueva consulta" entry point. `flutter analyze` clean, `flutter test` 133/133 passing.**

## Performance

- **Duration:** ~50 min across two sessions (rate-limit interruption between Task 2 and Task 3)
- **Tasks:** 3 of 3 completed
- **Files modified/created:** 14

## Accomplishments

- Reconciled `Consulta`/`ExamenFisico` to the append-only shape: `anamnesis` nullable, `diagnostico`/`tratamiento` required, `examenFisico` defaults to `const ExamenFisico()`, `proximaCita`/`adjuntoUrls` removed entirely, no `copyWith` (HIST-04/D-01: a correction is always a new consulta, never an edit).
- `SupabaseConsultaRepository`: `porMascota` (ordered select, defensively re-sorted) + `registrarConsulta` (single RPC call carrying all ten `p_` params, optional blanks normalized to `null`), two-tier error handling (`PostgrestException` -> `_messageFor` -> `ConsultaFailure`, generic catch-all fallback). No update/delete/insert path exists anywhere — confirmed by the plan's static grep gate.
- `consultas_providers.dart`: `consultasProvider` (autoDispose family), `RegistrarConsulta` usecase + `registrarConsultaProvider` — exactly one repository call per save, with `pesosProvider(mascotaId)` invalidated only when `pesoKg != null` (D-02), so a weight typed in a consulta lands in the existing weight history without a second write.
- `ConsultaFormScreen`: Diagnóstico + Tratamiento always visible and required; Anamnesis, Examen físico (peso/temperatura/frecuencias/mucosas) and Evolución collapsed behind "Agregar más detalles"; `Guardar consulta` (primary, only accent on the screen) gated solely on the two required fields per D-03; numeric fields validated client-side (`parsearPeso`, new `parsearNumeroPositivo`) before any provider call.
- Wired `consultas/nueva` as a child route under both `/pacientes/:id` and `/clientes/:id/mascotas/:mascotaId`.
- `MascotaDetailScreen`: `Editar` demoted to `AppButtonVariant.outline`; new "Historia clínica" heading + primary "Nueva consulta" `AppButton` after the weight-history section (a gap intentionally left for Plan 03-04's timeline). No "Grabar nota de voz" button anywhere.
- `test/helpers/fake_consultas.dart`: `FakeConsultaRepository` + `consultasRocky` fixtures (deliberately unsorted, distinct dates) for reuse by Plans 03-04/03-05.

## Task Commits

1. **Task 1: Failing tests + Wave 0 fake for registering a consulta (RED)** - `e5ab14d` (test)
2. **Task 2: Reconcile Consulta, add ConsultaFailure/repository/providers/numeric parser (GREEN)** - `81b772b` (feat)
3. **Task 3: ConsultaFormScreen, routes, ficha entry point (GREEN)** - `26e1e83` (feat)

## Files Created/Modified

- Created: `lib/features/clinical_history/domain/consulta_failure.dart`, `.../data/repositories/supabase_consulta_repository.dart`, `.../presentation/providers/consultas_providers.dart`, `.../presentation/screens/consulta_form_screen.dart`, `test/helpers/fake_consultas.dart`, `test/consultas_providers_test.dart`, `test/consulta_form_screen_test.dart`
- Modified: `lib/features/clinical_history/domain/entities/consulta.dart`, `lib/core/utils/formato.dart`, `lib/features/patients/presentation/pacientes_routes.dart`, `lib/features/clients/presentation/clientes_routes.dart`, `lib/features/patients/presentation/screens/mascota_detail_screen.dart`, `test/formato_test.dart`, `test/mascota_detail_screen_test.dart`

## Decisions Made

- Copied the "Agregar más detalles" disclosure inline into `ConsultaFormScreen` rather than extracting a shared widget, per the plan's explicit instruction (`MascotaCamposSection`'s version is coupled to its own field set).
- Numeric vitals validated client-side before any call reaches the provider/RPC layer; the server's check constraints remain a backstop only (T-03-INPUT).

## Deviations from Plan

None. All three tasks executed exactly as written; no Rule 1-4 auto-fixes needed.

## Issues Encountered

**Session rate limit between Task 2 and Task 3.** The original executor agent was interrupted by a session-limit error right after `flutter analyze` passed for Task 3's work, before the full test suite could run. On resume, the worktree's uncommitted changes (Task 3's `ConsultaFormScreen`, route wiring, ficha entry point, and matching test updates) were verified intact: `flutter analyze` clean, `flutter test` 133/133 green, and the plan's `SLICE_REGISTRAR_OK` grep gate passed. The work was genuine and complete — only the commit and this summary were missing. Committed as `26e1e83` with no code changes beyond what the original run had already produced.

## User Setup Required

None.

## Next Phase Readiness

- Plans 03-04 (timeline) and 03-05 (PDF export) can now build directly against `consultasProvider`, `Consulta`/`ExamenFisico`, and `test/helpers/fake_consultas.dart`'s `consultasRocky` fixtures.
- The gap left in `MascotaDetailScreen` between the "Historia clínica" heading and the "Nueva consulta" button is exactly where Plan 03-04 inserts the timeline widget.
- No blockers. This plan ran entirely against fakes (`FakeConsultaRepository`/`FakeMascotaRepository`); it does not depend on Plan 03-01's live schema checkpoint to be considered complete, though the RPC contract it implements must match Plan 03-01's `registrar_consulta` signature verbatim (confirmed against `<interfaces>` in `03-03-PLAN.md`).

## Self-Check

- `Consulta` has no `copyWith`, no `proximaCita`, no `adjuntoUrls`: CONFIRMED via grep
- `SupabaseConsultaRepository` has no update/delete/insert path: CONFIRMED via grep (DATA3_OK gate)
- `consultas/nueva` wired in both route files: CONFIRMED via grep
- `AppButtonVariant.outline` on `Editar`: CONFIRMED via grep
- No "nota de voz" text anywhere in `lib/`: CONFIRMED via grep
- Commit `e5ab14d` (Task 1): FOUND in `git log --oneline`
- Commit `81b772b` (Task 2): FOUND in `git log --oneline`
- Commit `26e1e83` (Task 3): FOUND in `git log --oneline`
- `flutter analyze`: No issues found
- `flutter test`: 133/133 passing
- Working tree clean after this commit: CONFIRMED via `git status --short`

## Self-Check: PASSED

---
*Phase: 03-historia-cl-nica*
*Completed: 2026-09-28*
