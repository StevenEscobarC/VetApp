---
phase: 07-facturaci-n
plan: 14
subsystem: billing-entry-points
tags: [billing, clinical-history, clients, cobrar, D-05, D-20]
requires: ["07-02 rutaNuevoCobro + cobrosRepositoryProvider + FakeCobrosRepository", "07-05 CobrarBoton + CobroVinculadoFila"]
provides:
  - "SnackBarAction 'Cobrar' (6 s) after saving a consultation"
  - "CobroVinculadoFila / text CobrarBoton under 'Evolución' in the expanded timeline card"
  - "'Nueva cuenta de cobro' outline button on the client detail (walk-in sale)"
affects: [consulta_form_screen, historia_clinica_timeline, cliente_detail_screen]
tech-stack:
  added: []
  patterns: ["messenger + GoRouter captured before pop for a snackbar action (anular_dosis_sheet analog)"]
key-files:
  created: []
  modified:
    - lib/features/clinical_history/presentation/screens/consulta_form_screen.dart
    - lib/features/clinical_history/presentation/widgets/historia_clinica_timeline.dart
    - lib/features/clients/presentation/screens/cliente_detail_screen.dart
    - test/consulta_form_screen_test.dart
    - test/historia_clinica_timeline_test.dart
    - test/mascota_detail_screen_test.dart
    - test/cliente_detail_screen_test.dart
decisions:
  - "Consulta form watches mascotaProvider(mascotaId) and puedeEscribirProvider in build so the autoDispose values are live when the snackbar is built after the save"
  - "Snackbar 'Cobrar' only when puedeEscribir && duenoId != null; timeline 'Cobrar' only when the pet's dueño is known"
  - "Read-only form-snackbar case uses a separate harness (_appConPlan) so the existing harness diff stays additions-only"
metrics:
  duration: "~2 sessions (interrupted by usage limit)"
  completed: 2026-11-14
  tasks: 2
  files: 7
---

# Phase 7 Plan 14: Cobrar entry points from consultation, timeline and client profile Summary

You can now charge from the places where care ends or the vet sees the client. After saving a consultation, the 'Consulta guardada' snackbar shows 'Cobrar' for 6 s. An expanded card in the clinical timeline shows a text 'Cobrar' button under 'Evolución', or 'Cobrada: CC-0012' plus its chip if the visit is already charged. The client profile has a new 'Nueva cuenta de cobro' button for walk-in sales. Every entry opens the CC form with the client, pet and consultation already filled in.

## Tasks

| # | Task | RED commit | GREEN commit | Gate | Result |
|---|------|-----------|--------------|------|--------|
| 1 | 'Cobrar' after saving a consultation and in the clinical timeline | 47a6951 | 81642be | CONSULTA_COBRAR_OK | ✅ |
| 2 | 'Nueva cuenta de cobro' on the client detail | d821145 | 3a2b2c0 | SLICE_ENTRADAS_OK | ✅ |

## Evidence

### Task 1 (✅)
- RED: 8 new cases failed. The 59 existing cases in the 3 files still passed: `+59 -8: Some tests failed.`
- The `<automated>` command was run from the worktree root (not `cd /c/Trabajo/VetApp`):
  - `flutter analyze lib/features/clinical_history test/...` gave `No issues found! (ran in 13.2s)`.
  - `flutter test test/consulta_form_screen_test.dart test/historia_clinica_timeline_test.dart test/mascota_detail_screen_test.dart` gave `00:06 +67: All tests passed!`.
  - Both greps passed. The marker printed: `CONSULTA_COBRAR_OK`.
- `git diff 6cd8b47` of the 3 test files has 0 removed lines, so the diff is additions only.

### Task 2 (✅)
- RED: 2 new cases failed and 28 passed: `+28 -2: Some tests failed.`
- The `<automated>` command was run from the worktree root:
  - `flutter analyze` gave `No issues found! (ran in 10.8s)`.
  - `flutter test test/cliente_detail_screen_test.dart` gave `00:04 +30: All tests passed!`.
  - The grep for 'Nueva cuenta de cobro' passed, and the "factur" count was 0.
  - Full `flutter test` gave `01:00 +1345: All tests passed!`.
  - The marker printed: `SLICE_ENTRADAS_OK`.
- `git diff 6cd8b47 -- test/cliente_detail_screen_test.dart` has 0 removed lines.

### New cases
- **historia_clinica_timeline_test (7):**
  - A collapsed card shows neither 'Cobrar' nor 'Cobrada'.
  - An expanded card shows a 48dp TextButton under 'Evolución'. It opens the form with cc, c-1, m-1 and con-7.
  - A linked CC shows 'Cobrada: CC-0012' plus the chip. The repo is called with `{citaId: null, consultaId: con-7}`, and tapping the row opens the detail.
  - A billing error shows 'Cobrar' with no error text.
  - Read-only shows the padlock and the plan sheet, with no navigation.
  - An unknown dueño shows no 'Cobrar'.
  - Append-only: no Editar, Eliminar, edit icon or delete icon.
- **consulta_form_screen_test (3):**
  - The snackbar lasts 6 s and has the 'Cobrar' action. Its target carries c-1, m-1 and the returned id (con-77).
  - In read-only there is no action.
  - With an unknown dueño there is no action.
- **mascota_detail_screen_test (3):**
  - Timeline 'Cobrar' from the pet profile, with no Editar or Eliminar in the card.
  - Save a consultation, then 'Cobrar' in the snackbar, which opens the form with consultaId con-55.
  - Read-only padlock.
- **cliente_detail_screen_test (2):**
  - Outline button with the receipt icon, placed right after 'Agendar cita' (gap of 16 or less) and before 'Vincular cuenta'. Its query is exactly `{tipo: cc, clienteId: c-1}`.
  - Read-only shows the padlock and the sheet, with no navigation.

## Deviations from Plan

1. **[Rule 3, test harness] Firing the snackbar action in the consulta form test.** That harness's 'FICHA' route is a bare `Text` with no `Scaffold`, so the snackbar is not shown after the pop. The new test captures the `SnackBar` and calls `action.onPressed()` directly. The pet profile test, where the page has a real Scaffold, taps the on-screen action after `pumpAndSettle`. No production change was needed. This was fixed in 81642be.
2. **Additions-only harness changes.** The read-only form case uses a new `_appConPlan` harness. Adding a `plan` parameter to `_appUnderTest` would have changed an existing line. The timeline test file got a new `_appCobro` harness, and the existing `_app` got two added overrides (cobros and mascotas).
3. **Generated files restored.** Flutter tooling regenerated the linux, macos and windows plugin registrant files. They are out of scope, so I restored them file by file and did not commit them.
4. **Gate paths.** The `<automated>` commands start with `cd /c/Trabajo/VetApp`. As instructed, I ran them from the worktree root instead.

## Threat model
- **T-07-58 (append-only weakened):** the only new control is navigation. Tests assert no Editar or Eliminar on the cards, both in the timeline and in the pet profile.
- **T-07-59 (read-only charge):** `CobrarBoton` shows the padlock and the sheet. The snackbar has no action when `puedeEscribir` is false.
- **T-07-57 (consultation from another clinic or pet):** handled by the server (07-01). The client only sends ids it already has in context.

## Known Stubs
None.

## Self-Check: PASSED
- Commits 47a6951, 81642be, d821145 and 3a2b2c0 are present on branch worktree-agent-a292cbfabfb6a4c29.
- All 7 modified files exist.
