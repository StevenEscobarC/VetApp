---
phase: 07-facturaci-n
plan: 15
subsystem: billing
tags: [cobros, cotizaciones, convertir, editar, reemitir, tdd]
requires: ["07-11", "07-12"]
provides:
  - "BorradorCobroNotifier.cargarDesde(Cobro, {required List<Producto> productos, bool marcarArchivados = true})"
  - "CobroFormScreen modes editarCotizacion / convertir / copiar"
  - "Routes /cobros/:id/editar and /cobros/:id/convertir (before /cobros/:id)"
  - "Complete CobroDetailScreen action table for all 6 (tipo, estado) states"
affects: [cobro_form_screen, cobro_detail_screen, cobros_routes, borrador_cobro_provider]
tech-stack:
  added: []
  patterns:
    - "Origin copied into the draft once, after the frame (post-frame flag); the draft key is never regenerated"
    - "_BotonEscritura: a shared write action (ControlEscritura + asegurarEscritura + padlock)"
key-files:
  created: []
  modified:
    - lib/features/billing/presentation/providers/borrador_cobro_provider.dart
    - lib/features/billing/presentation/screens/cobro_form_screen.dart
    - lib/features/billing/presentation/cobros_routes.dart
    - lib/features/billing/presentation/screens/cobro_detail_screen.dart
    - test/borrador_cobro_test.dart
    - test/cobro_form_screen_test.dart
    - test/cobro_detail_screen_test.dart
    - test/router_cobros_cross_shell_test.dart
decisions:
  - "Copiar mode copies the visit link (citaId/consultaId); convertir sets cotizacionId = origen.id and copies no visit link"
  - "Edit and convert accept only an open quote; any other origin (or BC002 from the server) shows 'Esta cotización ya no se puede usar. Actualiza la lista.' with the CTA disabled and 'Volver'"
  - "Products are requested only when the origin has product lines; if the inventory fails to load, archived lines are not marked and the server decides"
  - "'Anular cotización' reuses the 07-12 _AccionAnular/showAnularCobroSheet, with the label chosen by tipo; nothing is duplicated"
metrics:
  duration: "~45 min"
  completed: 2026-11-14
  tasks: 2
  files: 8
---

# Phase 7 Plan 15: Quotes edit/convert and voided-CC reissue Summary

This plan closes the quote loop. One form now covers four flows:
- **Edit a quote:** `editarCotizacion`, then the form pops and shows "Cambios guardados.".
- **Convert a quote:** `emitirCuentaCobro(cotizacionId:)`. The emit confirmation runs first, stock is checked at that moment, and the route is replaced by the new CC.
- **Reissue a voided CC:** "Emitir una nueva" opens a fresh draft with a new key. It carries the same client, pet, visit link and lines.
- **Detail actions:** every state now has its full action table, and write actions show a padlock in read-only.

## Tasks

| # | Task | RED commit | GREEN commit | Result |
|---|------|-----------|--------------|--------|
| 1 | Form modes editar / convertir / copiar and cargarDesde | 4432110 | 8a79fe1 | ✅ MODOS_FORM_OK |
| 2 | Routes editar/convertir and the complete detail action table | e9945af | 0e77c48 | ✅ SLICE_COTIZACIONES_OK |

## Per-task evidence

### Task 1: ✅
- **RED** (4432110): new tests in `test/borrador_cobro_test.dart` (group `cargarDesde (07-15)`, 4 tests) and `test/cobro_form_screen_test.dart` (group `modos editar / convertir / copiar (07-15)`, 10 tests). They failed as expected: the run ended with `00:07 +44 -11: Some tests failed.`, and the borrador file did not compile because `cargarDesde` was missing.
- **GREEN** (8a79fe1): `<automated>`, run from the worktree root:
  - `flutter analyze lib/features/billing test/borrador_cobro_test.dart test/cobro_form_screen_test.dart` returned `No issues found! (ran in 6.8s)`
  - `flutter test test/borrador_cobro_test.dart test/cobro_form_screen_test.dart` returned `00:08 +79: All tests passed!`
  - both grep checks passed, and the command printed `MODOS_FORM_OK`
- Acceptance: compared with base `efb9217`, `git diff` of `test/borrador_cobro_test.dart` and `test/cobro_form_screen_test.dart` has 0 removed lines (additions only).

### Task 2: ✅
- **RED** (e9945af): 13 failing tests.
  - 12 are new: group `acciones completas (07-15)` in the detail test, and group `editar y convertir (07-15)` in the router test.
  - 1 is an existing assertion I changed on purpose (see Deviations).
  - The run ended with `00:04 +30 -13: Some tests failed.`
- **GREEN** (0e77c48): `<automated>`, run from the worktree root:
  - `flutter analyze` returned `No issues found! (ran in 9.6s)`
  - `flutter test test/cobro_detail_screen_test.dart test/router_cobros_cross_shell_test.dart test/cobro_form_screen_test.dart` returned `00:08 +97: All tests passed!`
  - The route-order checks passed: `/cobros/:id/editar` and `/cobros/:id/convertir` come before `'/cobros/:id'`.
  - The "factur" grep returned 0.
  - full `flutter test` returned `00:41 +1441: All tests passed!`
  - the command printed `SLICE_COTIZACIONES_OK`
- Acceptance: the test `un solo primario en CC pendiente, CC pagada y cotización abierta; ninguno en convertida, CC anulada y cotización anulada` covers all 6 states with expected primary counts 1/1/1/0/0/0.

## What was built

- **`cargarDesde`** (`borrador_cobro_provider.dart`):
  - copies `clienteId`, `mascotaId` and every line (tipo, descripcion, cantidad, precioUnitarioCop, servicioId, productoId);
  - copies `citaId`/`consultaId` only in copiar mode, and sets `cotizacionId = origen.id` only in convertir mode;
  - takes stock, unidad and precioBaseCop from the active products; a missing product line gets "{descripcion} ya no está disponible. Quítalo del cobro.";
  - is idempotent through a `_cargado` flag and never changes `clave`.
- **CobroFormScreen:**
  - Outside nuevo mode, the form watches `cobroProvider(origenId)`. It watches `productosProvider` only if the origin has product lines.
  - It calls `cargarDesde` once, after the frame.
  - Skeleton client/pet rows (`ValueKey('esqueleto-origen')`) show while the origin loads.
  - Titles are "Editar cotización", "Convertir COT-0004" and "Nueva …". The convert mode adds the note "Desde la cotización COT-0004. Revisa los precios y cantidades antes de emitir.".
  - Edit and convert have no Tipo toggle. The edit CTA reads "Guardar cambios".
  - The BC002 / wrong-origin banner has a `TextButton` "Volver", and the CTA is disabled.
- **Routes:** `/cobros/:id/editar` opens editarCotizacion (tipo cotizacion) and `/cobros/:id/convertir` opens convertir (tipo cuentaCobro). Both are declared before `/cobros/:id`.
- **Detail `_acciones`:**

  | State | Actions |
  |-------|---------|
  | Open quote | Convertir (primary, `swap_horiz`) · Enviar (outline) · Editar cotización (outline, `edit_outlined`) · Anular cotización (destructive, admin/author only) |
  | Converted quote | Ver CC-0013 (outline) · Enviar (outline) |
  | Voided CC | Emitir una nueva (outline) → `rutaNuevoCobro(desdeCobroId, clienteId, mascotaId, citaId, consultaId)` |
  | Voided quote | none |

  - Write actions go through `_BotonEscritura`: padlock plus `LimitePlanSheet`.
  - Enviar and Ver CC are never locked.
  - `_AccionAnular` (07-12) is reused with its label chosen by tipo and still calls `showAnularCobroSheet`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] An existing 07-12 assertion conflicted with D-10 "Emitir una nueva"**
- **Found during:** Task 2
- **Issue:** `test/cobro_detail_screen_test.dart` › `tras anular: … sin acciones` asserted `find.byType(AppButton), findsNothing`. The spec now requires the outline "Emitir una nueva" on a voided CC.
- **Fix:** I replaced that one line. The test now expects the only AppButton labels to be `['Emitir una nueva']`, and every other assertion is unchanged. This is the single removed line in the test diffs. Task 2's "append only" rule could not hold for it.
- **Commit:** e9945af

**2. [Rule 2 - Robustness] `cargarDesde` got an optional `marcarArchivados` flag (default `true`)**
- **Issue:** if `productosProvider` fails, passing an empty list would wrongly mark every product line as archived.
- **Fix:** I added an optional named parameter. With the default, the interface behaves exactly as specified.
- **Commit:** 8a79fe1

**3. [Test fix] My own RED test used `tester.pageBack()`**
- **Issue:** the marker destination scaffold has no back button, so `pageBack()` cannot work there.
- **Fix:** I switched it to `GoRouter.of(...).pop()` in GREEN.
- **Commit:** 0e77c48

### Notes
- `.planning/phases/07-facturaci-n/07-VALIDATION.md` was not edited. The evidence is in this SUMMARY.
- No Supabase MCP and no Linear were used. The `kSelectCobro` embeds were not touched.
- `flutter pub get` touched the generated plugin registrants (linux/macos/windows). I restored them with a per-file checkout; they are not part of any commit.
- STATE.md and ROADMAP.md were not updated from this worktree. The orchestrator merges the wave.

## Known Stubs
None.

## Threat Flags
None. The plan's threat register covers all of this:
- **T-07-60:** BC002 shows the banner and disables the CTA.
- **T-07-61:** a reissue always gets a new draft key (tested: `clave` differs from the earlier draft, and `generadas == 2`).
- **T-07-62:** read-only shows padlocks plus `asegurarEscritura` on Convertir, Editar, Emitir una nueva and Anular.

## Self-Check: PASSED
- Files exist: all 8 modified files are present.
- Commits exist: 4432110, 8a79fe1, e9945af, 0e77c48 (`git log --oneline` on worktree-agent-ad67e3e0e8079688c).
