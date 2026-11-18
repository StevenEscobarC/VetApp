---
phase: 08-dashboard-y-dise-o-visual
plan: 09
subsystem: inventory, plan (presentation)
tags: [DASH-04, VET-57, sweep, AppButton, brand]
requires: ["08-02"]
provides:
  - "Inventory and plan widgets free of raw TextButton/OutlinedButton and literal radius 4"
  - "Inventory header visible and inert while products load"
affects: [inventory, plan]
tech-stack:
  added: []
  patterns:
    - "AppButton(cuadrado: true, botonKey:) for 48x48 steppers, inner OutlinedButton keeps the key"
    - "IgnorePointer(ignoring: !habilitado) for a disabled-without-opacity header"
key-files:
  created:
    - test/barrido_inventario_plan_test.dart
  modified:
    - lib/features/inventory/presentation/screens/producto_detail_screen.dart
    - lib/features/inventory/presentation/widgets/ajuste_stock.dart
    - lib/features/inventory/presentation/widgets/resumen_bajos_strip.dart
    - lib/features/inventory/presentation/widgets/ajuste_rapido_botones.dart
    - lib/features/inventory/presentation/widgets/insignia_stock.dart
    - lib/features/inventory/presentation/screens/inventario_screen.dart
    - lib/features/plan/presentation/widgets/plan_banner.dart
    - lib/features/plan/presentation/widgets/uso_contador_tile.dart
decisions:
  - "Inventory header while loading: shown when hasValue OR (isLoading && !hasError), with productos const [] and habilitado false; chip taps blocked by IgnorePointer, no opacity change; filtering logic untouched"
  - "Quick-adjust disabled colors now come from the 08-02 outlined theme (local surfaceMuted/placeholder overrides removed, as recorded in the plan)"
metrics:
  completed: 2026-11-17
  tasks: 2
  files: 9
---

# Phase 8 Plan 09: Inventory and plan DASH-04 sweep Summary

I swept the inventory and plan widgets onto AppButton. The quick-adjust steppers are now square outline AppButtons that keep `botonKey`, so the existing `OutlinedButton` finders still match. The stock badge uses labelLarge (14/600) with no FontWeight literal, the inventory header stays visible but inert while products load, and the usage bar uses `AppSpacing.radiusSm`. Behaviour did not change (D-19).

## Tasks

| Task | Name | Commits | Result |
|------|------|---------|--------|
| 1 | RED guard, then inventory buttons, badge role and header-while-loading (VET-57) | 43495f0 (test), 283d572 (refactor) | ✅ `INVENTARIO_BARRIDO_OK` |
| 2 | Plan banner button and usage bar radius | e22641f (test), 15914f0 (refactor) | ✅ `PLAN_BARRIDO_OK` |

## Evidence

**Task 1 ✅**
- RED (43495f0): the source guard failed for 4 inventory files plus plan_banner and uso_contador_tile, and so did the `FontWeight.` guard. The quick-adjust test failed with "0 AppButton ancestors". The badge test got fontSize 12 where 14 was expected. The header-while-loading test found no "Todos" chip while loading.
- GREEN verify (from the worktree root):
  - `flutter test test/barrido_inventario_plan_test.dart --plain-name "inventario"`: `+4: All tests passed!`
  - `flutter test test/producto_detail_screen_test.dart test/ajuste_rapido_test.dart test/ajuste_sheet_test.dart test/inventario_screen_test.dart`: `+86: All tests passed!`
  - There is no `FontWeight.` in insignia_stock.dart, `botonKey: botonKey` is present, and the run printed `INVENTARIO_BARRIDO_OK`.
- I-11: the doc comment above `_AbsorbeToqueSiInactivo` already explains why it swallows the tap (a disabled button would let the tap reach the row and open the detail). Recorded as "ya documentado"; no change.

**Task 2 ✅**
- RED (e22641f): the source guard failed for plan_banner and uso_contador_tile. `find.widgetWithText(AppButton, 'Ver mi plan')` found 0 widgets, and the radius came out as `circular(4.0)` where `circular(8.0)` was expected.
- GREEN verify (from the worktree root):
  - `flutter test test/barrido_inventario_plan_test.dart test/plan_banner_test.dart test/mi_plan_screen_test.dart`: `+58: All tests passed!` (the new file passes 12 of 12)
  - `bash tool/dash04_gates.sh <8 files>` printed `EXENTOS: 1` (SW-01 "tematizado en app_theme.dart (08-02)"). That one hit is the inventario `FloatingActionButton.extended` at l.133, i.e. W-20 fixed by the theme. The script ended with `DASH04_GATES: PASS`.
  - `flutter analyze`: `No issues found!`, and the run printed `PLAN_BARRIDO_OK`.

## WARNs closed

W-18 (plan_banner), W-19 (uso_contador_tile), W-21 (producto_detail_screen x2, ajuste_stock, resumen_bajos_strip), W-22 (ajuste_rapido_botones), W-28 (insignia_stock now uses labelLarge), W-29 (inventario header while loading). W-20 was already fixed by the 08-02 theme.

## Deviations from Plan

- None in code. I did not edit any existing test file.
- Process note: the plan's guard list covers TextButton/OutlinedButton/styleFrom. I also added `BorderRadius.circular(4)` to the source guard so W-19 has a source-level check too.
- Environment note: `flutter test` regenerated the desktop plugin registrants (`linux/`, `macos/`, `windows/` generated files). These are tool-generated and outside this plan, so I left them uncommitted.

## Known Stubs

None.

## Self-Check: PASSED

- test/barrido_inventario_plan_test.dart exists.
- Commits 43495f0, 283d572, e22641f and 15914f0 are present in `git log`.
