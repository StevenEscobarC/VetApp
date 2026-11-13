---
phase: 06-inventario
plan: 08
subsystem: inventory
tags: [flutter, riverpod, go_router, inventory, detail, history, archive]
requires: [06-02, 06-03, 06-05, 06-06, 06-07]
provides:
  - ProductoDetailScreen (/inventario/:id) with adjustments and last-50 history
  - MovimientoTile
  - Edit mode of ProductoFormScreen (/inventario/:id/editar), admin-only minimo/prices
  - Admin-only "Archivar producto" with confirmation dialog
  - rutaProducto / rutaEditarProducto, row tap to detail
affects: [06-09]
key-files:
  created:
    - lib/features/inventory/presentation/screens/producto_detail_screen.dart
    - lib/features/inventory/presentation/widgets/movimiento_tile.dart
    - test/producto_detail_screen_test.dart
  modified:
    - lib/features/inventory/presentation/inventario_routes.dart
    - lib/features/inventory/presentation/widgets/producto_fila.dart
    - lib/features/inventory/presentation/widgets/ajuste_rapido_botones.dart
    - lib/features/inventory/presentation/screens/producto_form_screen.dart
    - test/producto_form_screen_test.dart
    - test/router_inventario_cross_shell_test.dart
requirements-completed: [INV-01, INV-03]
completed: 2026-11-12
---

# Phase 6 Plan 08: Product detail, history, edit and archive Summary

Detail screen with adjustments (Descontar 1 / Agregar stock / Ajustar cantidad), last-50 movement history with author, edit mode with admin-only minimum and prices, and admin-only archive that keeps the history; all built on `FakeInventarioRepository`.

## Commits (TDD order)

| Hash | Subject |
|------|---------|
| 57683a5 | test(06-08): add failing tests for product detail, history and routes (RED) |
| 0c70d59 | feat(06-08): product detail with adjustments, movement history and routes |
| fd158ba | test(06-08): add failing tests for edit mode and admin-only archive (RED) |
| 59c3297 | feat(06-08): edit mode with admin-only fields and admin-only archive |
| 990d0b0 | fix(06-08): taps on a disabled row adjust button no longer open the detail |

## Evidence

- Markers: DETALLE_INV_OK (analyze lib/features/inventory + detail test clean; detail + router tests green; `rutaProducto` in producto_fila.dart; `'/inventario/:id'` declared after `kRutaNuevoProducto`; `destructive` count in movimiento_tile.dart = 0). EDITAR_ARCHIVAR_OK (analyze clean; form + detail tests green; literal "Solo el administrador puede cambiar el mínimo y los precios." present in producto_form_screen.dart; full suite green; `grep -rn "eliminar\|Eliminar" lib/features/inventory` returns nothing).
- Test counts per file (after last code commit 990d0b0): test/producto_detail_screen_test.dart +28, test/producto_form_screen_test.dart +20, test/router_inventario_cross_shell_test.dart +11, test/ajuste_rapido_test.dart +11.
- Date: 2026-11-12. Last code commit: 990d0b0.

Literal last lines of the gates (run in this worktree after the last code commit):

```
flutter analyze  -> No issues found! (ran in 17.2s)
flutter test     -> 00:57 +1034: All tests passed!
```

## Deviations from Plan

**1. [Rule 1 - Bug] Disabled row buttons let the tap open the detail**
- Found during: full-suite run after Task 2 (test/ajuste_rapido_test.dart "en vuelo ..." failed).
- Issue: making the whole `ProductoFila` card tappable meant a tap on a disabled -1/+ (in flight or no stock) bubbled to the card and navigated to the detail.
- Fix: `_AbsorbeToqueSiInactivo` in `ajuste_rapido_botones.dart` swallows taps while the button is inactive. The existing test was not changed.
- Commit: 990d0b0

**2. [Plan wording] Detail read-only test uses the non-admin profile**
- The lock-count assertion (4 locks) uses `vetColegaProfile` so the admin-only archive button does not change the count; archive read-only behavior has its own test with the admin profile.

## Notes

- Archive/`noDisponible` navigation uses a `GoRouter` captured before the await (the detail rebuilds to "no disponible" once the provider is invalidated, so relying on `mounted` could skip the pop).
- Movement date/time uses the device-local fields of `creadoEn` (the repository already applies `toLocal()`), same as the rest of the app's `hora12` usage.
- `flutter pub get` modified generated platform registrant files (linux/macos/windows); they were not committed.
- Emulator QA (F6, F7) is left to 06-09. STATE.md, ROADMAP.md and 06-VALIDATION.md were not touched (orchestrator-owned).

## Self-Check: PASSED

Files exist: producto_detail_screen.dart, movimiento_tile.dart, producto_detail_screen_test.dart. Commits 57683a5, 0c70d59, fd158ba, 59c3297, 990d0b0 present in git log.
