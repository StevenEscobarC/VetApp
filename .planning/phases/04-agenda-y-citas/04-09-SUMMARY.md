---
phase: 04-agenda-y-citas
plan: 09
subsystem: appointments, clinical_history
tags: [flutter, riverpod, go_router, supabase-rpc]
requires: [04-01, 04-05, 04-06, 04-08]
provides:
  - consultas linked to citas via p_cita_id
  - CompletarCitaScreen and /agenda/:id/completar routes
  - Completar entry points on card and detail
affects: [appointments, clinical_history]
key-files:
  created:
    - lib/features/appointments/presentation/screens/completar_cita_screen.dart
    - test/completar_cita_screen_test.dart
  modified:
    - lib/features/clinical_history/data/repositories/supabase_consulta_repository.dart
    - lib/features/clinical_history/presentation/providers/consultas_providers.dart
    - lib/features/clinical_history/presentation/screens/consulta_form_screen.dart
    - lib/features/appointments/presentation/agenda_routes.dart
    - lib/features/appointments/presentation/widgets/cita_acciones.dart
    - lib/features/appointments/presentation/widgets/cita_card.dart
    - lib/features/appointments/presentation/screens/cita_detail_screen.dart
    - test/helpers/fake_consultas.dart
    - test/consultas_providers_test.dart
    - test/consulta_form_screen_test.dart
    - test/cita_detail_screen_test.dart
    - test/cita_actions_test.dart
decisions:
  - Completion is not transactional with consultas; Finalizar only changes estado, Deshacer reverts only estado
  - Consulta repository stays append-only (no update/delete added)
requirements-completed: [AGND-06, AGND-03]
duration: ~35 min
completed: 2026-10-01
---

# Phase 4 Plan 09: Completar cita Summary

Completing a cita now flows into the clinical record: per-mascota consulta registration prefilled from the cita and linked via `p_cita_id`, optional skipping, "Completar sin consulta", and estado completada with Deshacer.

## Tasks

1. **Link consultas to citas** (a61e2c2): `registrarConsulta` sends `'p_cita_id'` (always present); `_messageFor` maps 23505 and 23503-"pertenece"; `RegistrarConsulta` forwards `citaId` and invalidates `citaProvider(citaId)` and `agendaSemanaProvider`; `ConsultaFormScreen(citaId)` shows the "Cita del mié 30/09 · 10:30 a. m." pill and prefills anamnesis (`{motivo}.` or `{motivo}. {notas}`), details expanded. Fake `registros` record gained `citaId`.
2. **CompletarCitaScreen + routes** (fa1334a): per-mascota Pendiente/Omitida/Consulta registrada cards, Registrar/Omitir, Finalizar cita, Completar sin consulta; `cambiarEstadoConDeshacer` now returns `Future<bool>` with `mensajeError`; routes `completar` and `completar/consulta/:mascotaId`.
3. **Entry points** (61dc2b3): outline "Completar" on card (non-terminal), primary "Completar cita" on pendiente/confirmada detail (sole primary button, asserted), completada detail shows "Consulta registrada"/"Sin consulta" and "Registrar consulta pendiente".

## Verification

`flutter analyze`: no issues. `flutter test`: 329 passed (GATE: GREEN). No `.update(`/`.delete(` in the consulta repository.

## Deviations from Plan

- [Rule 3 - Blocking] A card "Completar" test was added to `test/cita_actions_test.dart` (not in files_modified); the plan explicitly allowed card assertions in existing card tests, and a `completar` stub route was needed there.
- Accidental `dart format` over whole directories touched unrelated files; those were reverted before commit, so no unrelated changes landed.

## Known Stubs

None.

## Threat Flags

None. T-04-35..37 mitigations hold: RPC guards plus Spanish error mapping, append-only repository, Deshacer only reverts estado.

## Self-Check: PASSED

Commits a61e2c2, fa1334a, 61dc2b3 exist; created files present. Generated plugin registrant files were not committed. STATE.md and ROADMAP.md untouched.
