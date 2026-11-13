---
phase: 06-inventario
plan: 06
subsystem: inventory-ui
tags: [flutter, riverpod, inventario, ajuste, undo]
requires: [06-02, 06-03, 06-05]
provides:
  - "ajuste_stock.dart helpers (textoAjusteAplicado, textoErrorAjuste, mostrarResultadoAjuste, aplicarAjusteConFeedback, descontarUno, confirmarAjusteGrande) reusable by 06-08"
  - "AjusteRapidoBotones (-1 / +) inside ProductoFila"
  - "mostrarAjusteSheet / AjusteSheet"
affects: [06-07, 06-08]
key-files:
  created:
    - lib/features/inventory/presentation/widgets/ajuste_stock.dart
    - lib/features/inventory/presentation/widgets/ajuste_rapido_botones.dart
    - lib/features/inventory/presentation/widgets/ajuste_sheet.dart
    - test/ajuste_rapido_test.dart
    - test/ajuste_sheet_test.dart
  modified:
    - lib/features/inventory/presentation/widgets/producto_fila.dart
    - test/inventario_screen_test.dart
requirements: [INV-03]
completed: 2026-11-12
---

# Phase 6 Plan 06: Ajuste de stock (INV-03) Summary

Quick -1 with Deshacer by inverse movement, per-row in-flight lock, read-only lock icons, and the AjusteSheet (4 motivos, stepper, "Quedarán N" preview, validation, big-adjust confirm, inline errors), all on `FakeInventarioRepository`.

## Commits

- 90f798e test(06-06): ajuste rapido -1 ... (RED)
- 7707c07 feat(06-06): ajuste rapido -1 con Deshacer, bloqueo en vuelo y candados
- 42b6366 test(06-06): AjusteSheet ... (RED)
- 3dfa234 feat(06-06): AjusteSheet con motivos, vista previa, validacion y confirmacion de ajuste grande

## Evidence (2026-11-12)

- AJUSTE_RAPIDO_OK printed (analyze clean, 11 tests, no `Opacity(`, row uses AjusteRapidoBotones)
- AJUSTE_SHEET_OK printed (`flutter analyze` clean, ajuste_sheet_test 15 tests, ajuste_rapido_test 11 tests = 26, full suite 964 passed, 0 failed)
- Sheet has exactly one primary AppButton; "Aplicar ajuste" appears once in ajuste_sheet.dart.
- `grep "cantidad + "` in presentation matches only the sheet preview (`_quedarian`, labelled courtesy). Displayed quantities always come from the server's `cantidadNueva`.

## Deviations from Plan

1. **[Rule 3 - Blocking] Worktree base reset.** HEAD merge-base was eea3a10, not the required c742170; `git reset --hard c742170` run as the startup check directs.
2. **[Rule 1 - Test impact] `test/inventario_screen_test.dart` adapted.** Two FAB tests used `find.byIcon(Icons.add)` / `Icons.lock_outline` over the whole screen; rows now also contain `+` and lock icons. Assertions were scoped to the `FloatingActionButton` (same intent, not weakened). 06-07 may touch the same file: trivial merge.
3. **ProductoFila semantics restructured.** The old `excludeSemantics` wrapped the whole card, which would have hidden the two buttons. The label now wraps Row A only; badges row is `ExcludeSemantics` (already in the label); buttons are separate semantic actions.
4. **Empty-field message.** "Escribe una cantidad mayor que 0." is shown once the user has interacted (typed/cleared/stepped) or typed 0, not on a fresh open, to avoid an error on an untouched field; the button is disabled either way. In Conteo an empty field shows no message (0 is a valid count).
5. **In-flight lock covers the write-permission pre-check** (`asegurarEscritura`) as well, so a fast second tap cannot slip in before the request starts. For "+" the lock covers only that pre-check; the sheet owns its own `isLoading`.

## Known Stubs

None (the temporary `mostrarAjusteSheet` stub of Task 1 was replaced in Task 2).

## Pending / for orchestrator

- 06-VALIDATION.md rows 06-06-T1..T2 + evidence row (orchestrator-owned); emulator QA in 06-09 (F3, F8).
- `flutter pub get` modified generated plugin registrants (linux/macos/windows); intentionally not committed.
- Deshacer from the snackbar cannot open LimitePlanSheet (no BuildContext after the row/sheet may be gone); a limit failure on undo shows the generic error snackbar.

## Self-Check: PASSED
