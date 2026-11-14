---
phase: 07-facturaci-n
plan: 12
subsystem: billing
tags: [flutter, riverpod, billing, anular, tdd]
requires: ["07-02 cobrosActionsProvider.anular + puedeAnularCobroProvider", "07-09 CobroDetailScreen._acciones"]
provides: ["showAnularCobroSheet(context, cobro)", "void action in CC pendiente/pagada detail"]
affects: ["07-15 (wires 'Anular cotización' and 'Emitir una nueva')"]
tech-stack:
  added: []
  patterns: ["messenger captured before the modal sheet", "ControlEscritura + asegurarEscritura padlock", "role-limit hides action (no padlock)"]
key-files:
  created:
    - lib/features/billing/presentation/widgets/anular_cobro_sheet.dart
    - test/anular_cobro_sheet_test.dart
  modified:
    - lib/features/billing/presentation/screens/cobro_detail_screen.dart
    - test/cobro_detail_screen_test.dart
decisions:
  - "Void action is a destructive AppButton (TextButton style) with no icon; in read-only it gets Icons.lock_outline and keeps its place"
  - "Products sentence/snackbar only when cobro.esCuentaCobro && productoIds.isNotEmpty (quotes never move stock)"
  - "Voided CC explicitly maps to SizedBox.shrink() in the (tipo, estado) switch"
metrics:
  completed: 2026-11-14
  tasks: 2
  files: 4
---

# Phase 7 Plan 12: Anular cuenta de cobro Summary

Append-only correction: `showAnularCobroSheet` voids a CC or quote with a 3..200-char reason via `cobrosActionsProvider.anular` (which invalidates billing and the inventory of `cobro.productoIds`), and the CC detail shows a destructive "Anular cuenta de cobro" only to the admin or the issuer, with the plan padlock in read-only.

## Branch and commits

Branch: `worktree-agent-a65aa082bf60947ae` (base `6cd8b47`)

| Commit | Message |
|--------|---------|
| d61ba65 | test(07-12): add failing test for AnularCobroSheet |
| 94282fa | feat(07-12): implement AnularCobroSheet |
| 70305a9 | test(07-12): add failing tests for void action in cobro detail |
| 777ffcf | feat(07-12): void action in cobro detail with role limit and padlock |

## Per-task evidence

### Task 1: AnularCobroSheet ✅

- RED (d61ba65): `flutter test test/anular_cobro_sheet_test.dart` failed to compile: `Error: Method not found: 'showAnularCobroSheet'.` / `00:00 +0 -1: Some tests failed.`
- GREEN (94282fa), `<automated>` run from the worktree root:
  - `No issues found! (ran in 10.6s)` (flutter analyze lib/features/billing test/anular_cobro_sheet_test.dart)
  - `00:02 +15: All tests passed!`
  - grep for `eliminar|borrar|factur` in the sheet: no matches
  - Marker: `ANULAR_SHEET_OK`
- The 15 tests cover each behavior bullet: CC with products, CC without products, paid CC, quote title plus first sentence only, field hint/maxLength 200/autofocus, ' ab ' gives 'Escribe el motivo.' with no call, success with products and one call on a double tap with the reason trimmed, success without products, quote success, sinConexion, sinPermiso, estadoInvalido, other, LP004 → LimitePlanSheet, and Cancelar. A forbidden-words check runs in several tests.

### Task 2: Void action in the detail ✅

- RED (70305a9): `00:02 +19 -4: Some tests failed.` (admin last action, author paid, read-only padlock and after-voiding failed. The non-author case passed already, as expected, because the action did not exist yet.)
- GREEN (777ffcf), `<automated>` run from the worktree root:
  - `No issues found! (ran in 12.2s)` (full `flutter analyze`)
  - `00:03 +38: All tests passed!` (cobro_detail_screen_test + anular_cobro_sheet_test)
  - `puedeAnularCobroProvider` present in cobro_detail_screen.dart; `grep -rni factur lib/features/billing`: no matches
  - `00:50 +1350: All tests passed!` (full `flutter test`)
  - Marker: `SLICE_ANULAR_OK`
- New test cases:
  - admin pending: destructive last action, no icon, one primary, opens the sheet;
  - non-admin author on a paid CC: sees the action, one primary 'Enviar al cliente';
  - non-admin non-author on pending and paid: no 'Anular' text, no padlock;
  - read-only author: `lock_outline`, semantics 'Anular cuenta de cobro, bloqueado, solo lectura', opens LimitePlanSheet and not the sheet;
  - full void flow: snackbar, 'Anulada' chip, 'Motivo: Error en el precio', struck-through total, and no AppButton left.

## Deviations from Plan

- The `<automated>` commands say `cd /c/Trabajo/VetApp`. As the coordinator instructed, they were run from the worktree root instead.
- `cobro_detail_screen.dart`: only the 07-09 action block changed. That is the `_acciones` switch (an explicit anulada → `SizedBox.shrink()` case), `_AccionesCcPendiente`/`_AccionesCcPagada` (now each appends `_AccionAnular`), the new `_AccionAnular` widget and one import. In the test file, `_cc` gained a `creadoPor` param and `_abrir` a `profile` param (default `vetProfile`, so the existing tests are unchanged).
- I did not update STATE.md, ROADMAP.md, REQUIREMENTS.md or 07-VALIDATION.md. Plans 07-11, 07-13 and 07-14 run in parallel, so the orchestrator consolidates those per wave.
- Flutter tooling rewrote the generated plugin registrants (linux/macos/windows) in the working tree. They are not staged or committed because they are outside this plan.

## Threat model

- T-07-52: the UI hides the action for a non-author non-admin; the server's 42501 maps to 'Solo el administrador o quien la emitió puede anularla.'
- T-07-53: the reason is mandatory (≥3 chars trimmed, max 200) and the detail shows the 'Anulada el … por Dr(a). …' and 'Motivo: …' block.
- T-07-54: an in-flight lock (`_guardando` guard plus `isLoading`), with BC001 mapped to 'Ya estaba anulada. Actualiza para ver su estado.' The `finally` block in 07-02 handles invalidation.

## Known Stubs

None. The quote void path is in the sheet (it is tested), but 07-15 wires its entry point, as the plan says.

## Self-Check: PASSED

- All 4 files exist; commits d61ba65, 94282fa, 70305a9 and 777ffcf are on the branch.
