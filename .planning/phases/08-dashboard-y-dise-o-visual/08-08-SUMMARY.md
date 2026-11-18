---
phase: 08-dashboard-y-dise-o-visual
plan: 08
subsystem: billing (presentation)
tags: [DASH-04, sweep, AppButton, brand-warn]
requires: [08-02]
provides: [billing DASH-04 sweep, W-24, W-25, W-30 (VET-78) closed]
affects: [cobro_form_screen, anular_cobro_sheet, marcar_pagada_sheet, producto_cobro_sheet, servicio_sheet, linea_cobro_tile]
tech-stack:
  added: []
  patterns: [AppButton text/destructive in place of raw TextButton; dialog actions with expand false]
key-files:
  created:
    - test/barrido_cobros_test.dart
  modified:
    - lib/features/billing/presentation/screens/cobro_form_screen.dart
    - lib/features/billing/presentation/widgets/linea_cobro_tile.dart
    - lib/features/billing/presentation/widgets/anular_cobro_sheet.dart
    - lib/features/billing/presentation/widgets/marcar_pagada_sheet.dart
    - lib/features/billing/presentation/widgets/producto_cobro_sheet.dart
    - lib/features/billing/presentation/widgets/servicio_sheet.dart
    - test/cobro_form_screen_test.dart
decisions:
  - "Inline buttons (Cambiar, Agregar servicios, Volver, banner Descartar, dialog actions, anular Cancelar) use expand false to keep the previous intrinsic width; marcar-pagada Cancelar, producto Reintentar and Quitar servicio use the default expand true"
metrics:
  completed: 2026-11-17
  tasks: 2
  files: 8
---

# Phase 8 Plan 08: Billing DASH-04 Sweep Summary

I replaced all 12 raw `TextButton` / `TextButton.styleFrom` uses in the billing form and sheets with `AppButton`, using the text or destructive variant. Labels, callbacks and `_guardando` disable conditions are unchanged. `linea_cobro_tile` now uses `AppSpacing.xs` instead of `SizedBox(height: 6)`. This closes brand WARNs W-24, W-25 and W-30 (VET-78). The changes are visual only (D-19).

## Tasks

| Task | Result | Evidence | Commits |
|------|--------|----------|---------|
| 1: RED guard, then cobro_form_screen buttons and linea_cobro_tile spacing | ✅ | `COBRO_FORM_BARRIDO_OK` printed; cobro_form_screen_test `+62: All tests passed!`; barrido `formulario` group `+4: All tests passed!`; dash04_gates `DASH04_GATES: PASS` (EXENTOS: 0) | d1e9c49 (RED, 11 failing as expected), 5f58059 (GREEN) |
| 2: Billing sheets to AppButton | ✅ | `COBROS_BARRIDO_OK` printed; barrido + anular + marcar_pagada + producto + servicios_screen `+65: All tests passed!`; dash04_gates over 6 files PASS; "factur" grep in lib = 0 besides `kOrigenCobro`; `flutter analyze` "No issues found!" | 9e69496 (RED, 8 failing as expected), 489f1a6 (GREEN) |

After Task 2 I ran cobro_form_screen_test again and it is still green (`+62`).

## Deviations from Plan

**1. [Rule 3 - Blocking] I changed one finder in an existing test file**
- **Found during:** Task 1 GREEN
- **Issue:** In `test/cobro_form_screen_test.dart` ("CR-01: Descartar pregunta, avisa que puede existir y sale", around line 780), the test taps `find.widgetWithText(AppButton, 'Descartar')` to confirm the dialog. The banner's 'Descartar' is now also an AppButton and stays in the tree under the dialog, so the finder matched 2 widgets.
- **Fix:** I limited that one finder to `find.descendant(of: find.byType(AlertDialog), ...)`. The assertions and the behaviour under test did not change.
- **Files modified:** test/cobro_form_screen_test.dart (please check it against the other wave-2 plans before merging)
- **Commit:** 5f58059

**2. [Rule 1] Removed an unused import:** `app_colors.dart` in servicio_sheet.dart was only used by the removed `styleFrom`. Commit 489f1a6.

The comment that said "Agrega el `TextButton` Volver" now says "Agrega el botón Volver".

## Known Stubs

None.

## Threat mitigations

- T-08-28: I moved the callbacks and the `_guardando` conditions over unchanged. The new test checks that 'Quitar servicio' is disabled while a save is in flight. Every existing billing test is green.
- T-08-29: The source guard checks each file for "Factura"/"factura", and the lib-wide grep in the verify also passes.
- T-08-30: I did not touch any ControlEscritura or LimitePlan wrappers.

Untracked or unstaged files I left alone: `.claude/settings.local.json` (already modified before I started) and the desktop plugin registrants that the flutter tool regenerated. I did not commit them.

## Self-Check: PASSED

- test/barrido_cobros_test.dart exists
- commits d1e9c49, 5f58059, 9e69496 and 489f1a6 are present in git log
