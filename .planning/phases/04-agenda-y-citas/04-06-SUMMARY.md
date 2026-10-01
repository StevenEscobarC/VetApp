---
phase: 04-agenda-y-citas
plan: 06
subsystem: appointments
tags: [flutter, riverpod, go_router, supabase, agenda, estados]
requires: [04-03, 04-05]
provides:
  - SupabaseCitaRepository.actualizar (rpc actualizar_cita), cambiarEstado, marcarRecordatorioEnviado
  - CitaActions.actualizar / cambiarEstado / marcarRecordatorioEnviado
  - cita_acciones.dart (cambiarEstadoConDeshacer, confirmarCancelacion, mostrarMasAcciones)
  - CitaDetailScreen and routes /agenda/:id and /agenda/:id/editar
  - CitaFormScreen edit mode (citaId)
affects: [04-07, 04-08, 04-09, 04-10, 04-11]
key-files:
  created:
    - lib/features/appointments/presentation/widgets/cita_acciones.dart
    - lib/features/appointments/presentation/screens/cita_detail_screen.dart
    - test/cita_actions_test.dart
    - test/cita_detail_screen_test.dart
  modified:
    - lib/features/appointments/data/repositories/supabase_cita_repository.dart
    - lib/features/appointments/presentation/providers/citas_providers.dart
    - lib/features/appointments/presentation/widgets/cita_card.dart
    - lib/features/appointments/presentation/screens/agenda_screen.dart
    - lib/features/appointments/presentation/screens/cita_form_screen.dart
    - lib/features/appointments/presentation/agenda_routes.dart
    - test/helpers/fake_citas.dart
    - test/cita_form_screen_test.dart
key-decisions:
  - "Estado/recordatorio updates use .select('id') so RLS-hidden rows surface as 'Esta cita ya no existe.' instead of a silent success"
  - "Deshacer closure captures CitaActions and ScaffoldMessenger before awaiting, so it never touches a disposed widget"
  - "Edit mode shows a spinner until a one-time post-frame prefill; terminal citas show a not-editable message instead of the form"
requirements-completed: [AGND-03]
completed: 2026-10-01
---

# Phase 4 Plan 06: Estados y detalle de cita Summary

The vet can now confirm, mark no-show, cancel, reopen and edit citas: card actions with a 6 s Deshacer snackbar, a cancel confirmation dialog, a full cita detail screen, and an edit mode in the cita form with the cliente fixed and a self-excluding overlap check. Citas are never deleted.

## Tasks

| Task | Commit |
|------|--------|
| 1. Write path (repo + CitaActions), cita_acciones helpers, card actions, banner tap | 9c9fbbe |
| 2. CitaDetailScreen and ':id' / 'editar' routes | 76e7c0e |
| 3. Edit mode in CitaFormScreen | e245736 |

## Verification

`flutter analyze` reports no issues and the full `flutter test` suite is green (270 tests), including the new cita_actions, cita_detail_screen and edit-mode form tests. No `Dismissible` and no `.delete(` in `lib/features/appointments`.

## Deviations from Plan

**1. [Process] Worktree base corrected** with `git reset --hard a1ffc5f` at startup per the branch-check step (merge-base differed).

**2. [Minor] Overlap dialog body unchanged in edit mode.** Only the primary button label changes to 'Guardar igual'; the body still ends with '¿Agendar igual?' as the plan only specified the button text.

**3. [Minor] Task 2 touched `cita_form_screen.dart`** to add the `citaId` constructor parameter so the ':id/editar' route compiles; the behavior landed in Task 3.

## Known Stubs

None. WhatsApp / Cómo llegar (04-08) and Completar (04-09) actions are intentionally absent, with room left in the card action Wrap.

## Notes

`actualizar_cita`, `cambiarEstado` and `marcarRecordatorioEnviado` are covered with fakes only in widget tests; the RPC/column names follow the contract validated by the 04-01 live smoke. STATE.md and ROADMAP.md untouched; regenerated platform plugin files not committed.

## Self-Check: PASSED
