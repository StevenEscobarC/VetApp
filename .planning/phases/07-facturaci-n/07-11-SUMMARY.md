---
phase: 07-facturaci-n
plan: 11
subsystem: billing + inventory (UI)
tags: [billing, inventory, stock, tdd]
requires: ["07-07", "07-02", "07-01"]
provides:
  - showProductoCobroSheet(context, {required bool esCuentaCobro}) -> Producto?
  - BorradorCobroNotifier.agregarProducto / marcarErrorStock / limpiarErroresStock
  - LineaCobroTile limiteStock / pasosBloqueados / ayudaPrecio / autofocusPrecio
  - MovimientoStock.nota + const String kOrigenCobro = 'factura'
affects: [cobro_form_screen, linea_cobro_tile, movimiento_tile, producto detail history]
tech-stack:
  added: []
  patterns: [local stock courtesy cap with server as authority, GlobalKey per line + Scrollable.ensureVisible]
key-files:
  created:
    - lib/features/billing/presentation/widgets/producto_cobro_sheet.dart
    - test/producto_cobro_sheet_test.dart
    - test/movimiento_tile_test.dart
  modified:
    - lib/features/billing/presentation/providers/borrador_cobro_provider.dart
    - lib/features/billing/presentation/widgets/linea_cobro_tile.dart
    - lib/features/billing/presentation/screens/cobro_form_screen.dart
    - lib/features/inventory/domain/entities/movimiento_stock.dart
    - lib/features/inventory/data/repositories/supabase_inventario_repository.dart
    - lib/features/inventory/presentation/widgets/movimiento_tile.dart
    - test/borrador_cobro_test.dart
    - test/cobro_form_screen_test.dart
    - test/supabase_inventario_repository_test.dart
decisions:
  - "Stock line messages are composed in the UI from the line (descripcion, unidad, quedan), matching the repo wording ('Solo queda 1 …' singular); IN002 text is '{Producto} ya no está disponible. Quítalo del cobro.'"
  - "Typing a quantity above stock is allowed (shows the D-12 inline error); only '+' is capped on a CC. The tile's 999 max is unchanged"
  - "IN002 with a matched line shows no banner (inline only, stepper disabled); IN001 always shows 'Revisa las cantidades marcadas.'"
  - "Pre-emit validation now scrolls to the first invalid line of any kind (description, price or stock)"
requirements: [BILL-02, BILL-03]
metrics:
  completed: 2026-11-14
  tasks: 3
---

# Phase 7 Plan 11: Products in billing with stock-aware lines Summary

The vet can add active inventory products to a cotización or cuenta de cobro from a searchable picker. On a CC, lines are capped at the current stock and show the D-12 messages. Server IN001/IN002 rejections land on the exact line and keep the draft and its idempotency key. The product history shows "Cuenta de cobro CC-000N" / "Anulada CC-000N" instead of "Venta".

## Tasks

| # | Task | RED commit | GREEN commit | Gate | Result |
|---|------|------------|--------------|------|--------|
| 1 | ProductoCobroSheet + agregarProducto/marcarErrorStock/limpiarErroresStock | 20a0bbe | 011fbed | PICKER_PRODUCTOS_OK | ✅ |
| 2 | Stock-aware lines in the form + server stock errors on the line | 3826e15 | 8249d40 | STOCK_FORM_OK | ✅ |
| 3 | Inventory history labels (nota, kOrigenCobro) | 151e53f | 49d9375 | SLICE_STOCK_OK | ✅ |

## Per-task evidence

These gates ran from the worktree root, not from `/c/Trabajo/VetApp`.

**Task 1** (`flutter analyze lib/features/billing test/producto_cobro_sheet_test.dart test/borrador_cobro_test.dart && flutter test … && grep -q productosProvider …`)
- RED: the borrador tests failed to compile because `agregarProducto`, `marcarErrorStock` and `limpiarErroresStock` were not defined, and the sheet file was missing (`00:00 +0 -2: Some tests failed.`).
- GREEN:
```
No issues found! (ran in 7.0s)
00:02 +30: All tests passed!
PICKER_PRODUCTOS_OK
```

**Task 2** (`flutter analyze lib/features/billing test/cobro_form_screen_test.dart && flutter test test/cobro_form_screen_test.dart && grep -q "Al emitirla …" … && echo STOCK_FORM_OK`)
- RED: `00:07 +35 -9: Some tests failed.` All 9 new cases failed.
- GREEN:
```
No issues found! (ran in 10.1s)
00:07 +44: All tests passed!
STOCK_FORM_OK
```
- `git diff --numstat 6cd8b47 -- test/cobro_form_screen_test.dart` returns `357	0`, so the change is additions only.

**Task 3** (`flutter analyze && flutter test test/movimiento_tile_test.dart test/supabase_inventario_repository_test.dart test/producto_detail_screen_test.dart && <factur grep gate> && flutter test && echo SLICE_STOCK_OK`)
- RED: compile errors for the missing `nota` parameter and the undefined `kOrigenCobro`.
- GREEN:
```
No issues found! (ran in 10.3s)
00:04 +57: All tests passed!
00:41 +1359: All tests passed!
SLICE_STOCK_OK
```
- The 'factur' ban gate passes: the only match in `lib/` is `const String kOrigenCobro = 'factura';`. Its doc comment does not contain the substring.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The tile's typed-quantity clamp would have hidden the stock error**
- **Found during:** Task 2
- **Issue:** `LineaCobroTile._cantidadEscrita` clamps typed input to `cantidadMaxima`. Passing the stock as `cantidadMaxima` would turn "5" into "3", so the required "Solo quedan 3 frascos…" error could never appear.
- **Fix:** I added a separate `limiteStock` that only disables "+". Typed quantities above stock are kept and flagged inline. The emit is blocked locally and scrolls to the line.
- **Commit:** 8249d40

**2. [Rule 1 - Bug] Duplicate keys in the skeleton rows**
- **Found during:** Task 1
- **Fix:** I gave each skeleton row a unique key (`esqueleto-producto-$i`). The test counts rows by key prefix.
- **Commit:** 011fbed

### Notes
- The existing test "stock insuficiente: Revisa las cantidades marcadas." has no `productoId`. It still gets the banner, because IN001 always shows it.
- `flutter pub get` rewrote the generated plugin registrants (linux/macos/windows) on each run. I restored those files one by one with `git checkout -- <path>`; they were never committed.
- I did not update STATE.md, ROADMAP.md or 07-VALIDATION.md. 07-12, 07-13 and 07-14 run in parallel, and the orchestrator copies this evidence once per wave.

## Known Stubs
None.

## Threat Flags
None. There is no new network or trust surface. T-07-48..51 are mitigated as planned: the UI cap is a courtesy and the server's IN001/IN002 errors are mapped to the line, the picker lists active products only, the ledger nota is shown with no undo, and the 'factur' substring appears once in `lib/`.

## Self-Check: PASSED
- All files listed in key-files exist.
- Commits 20a0bbe, 011fbed, 3826e15, 8249d40, 151e53f and 49d9375 are present on branch `worktree-agent-afca85518c3e0481b`.
