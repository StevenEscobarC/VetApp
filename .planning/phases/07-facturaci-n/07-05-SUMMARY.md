---
phase: 07-facturaci-n
plan: 05
subsystem: billing-ui
tags: [billing, cobros, flutter, riverpod, go_router, tdd]
requires: ["07-02", "07-03"]
provides:
  - "cobrosRoutes (/cobros, /cobros/:id) registered after inventarioRoutes"
  - "CobrosScreen (summary, toggle, filters, list, FAB)"
  - "CobroDetailScreen (read view; _acciones(Cobro) placeholder for 07-09/07-12/07-15)"
  - "EstadoCobroChip, TipoCobroToggle, CobroFila, ResumenCobrosCard"
  - "CobrarBoton and CobroVinculadoFila for the entry-point plans"
  - "Más row 'Cobros'"
affects: [lib/core/router/app_router.dart, lib/features/home/presentation/screens/mas_screen.dart]
tech-stack:
  added: []
  patterns:
    - "Top-level routes outside the shell (G5), same as inventario"
    - "Padlock via ControlEscritura/iconoEscritura/semanticaEscritura + asegurarEscritura"
    - "Today from clockProvider + diaBogota"
key-files:
  created:
    - lib/features/billing/presentation/cobros_routes.dart
    - lib/features/billing/presentation/screens/cobros_screen.dart
    - lib/features/billing/presentation/screens/cobro_detail_screen.dart
    - lib/features/billing/presentation/widgets/resumen_cobros_card.dart
    - lib/features/billing/presentation/widgets/tipo_cobro_toggle.dart
    - lib/features/billing/presentation/widgets/cobro_fila.dart
    - lib/features/billing/presentation/widgets/estado_cobro_chip.dart
    - lib/features/billing/presentation/widgets/cobrar_boton.dart
    - test/cobros_screen_test.dart
    - test/cobro_detail_screen_test.dart
    - test/cobrar_boton_test.dart
    - test/router_cobros_cross_shell_test.dart
  modified:
    - lib/core/router/app_router.dart
    - lib/features/home/presentation/screens/mas_screen.dart
decisions:
  - "The detail's client row uses context.go('/clientes/:id'), not push: the client detail lives in a shell branch and pushing it from a top-level route would duplicate the shell page (G5); same as cita_acciones.dart"
  - "'De la cita del …' / 'De la consulta del …' show the document date: Cobro carries only citaId/consultaId, not the visit date"
  - "EstadoCobroChip.para(estado) returns null for an open quote so callers render no chip"
  - "TipoCobroToggle gets an extra 'habilitado' flag so the list can render it disabled while loading (UI-SPEC Screen States)"
  - "Helpers pesosSemantica() and validezCotizacion() live in cobro_fila.dart and are reused by the detail"
metrics:
  duration: "~70 min (split across a usage-limit pause)"
  completed: 2026-11-13
  tasks: 3
  files: 14
requirements: [BILL-01, BILL-04]
---

# Phase 7 Plan 05: Cobros list, read detail and entry widgets Summary

A vet can open Más > Cobros and see the server summary ("Cobrado este mes" / "Por cobrar"). They can switch between Cotizaciones and Cuentas de cobro (with Todas/Pendientes (N)/Pagadas filters on CCs) and read any document in full. The shared billing widgets (state chip, toggle, Cobrar button, Cobrada row) are ready for the entry-point plans. Everything runs on FakeCobrosRepository; live data arrives with 07-08.

## Branch and commits

Branch: `worktree-agent-a73c40b3df586cd46` (base `8b17acc`)

| # | Commit | Gate | Message |
|---|--------|------|---------|
| 1 | e7e68e4 | RED | test(07-05): add failing test for Cobros list screen |
| 2 | 532116c | GREEN | feat(07-05): Cobros list with server summary, toggle, filters and state chips |
| 3 | c91ec94 | RED | test(07-05): add failing tests for cobro detail and Cobrar entry widgets |
| 4 | b169be5 | GREEN | feat(07-05): cobro read detail, CobrarBoton and CobroVinculadoFila |
| 5 | 02f7b30 | RED | test(07-05): add failing cross-shell router test for Cobros |
| 6 | 7991ef1 | GREEN | feat(07-05): top-level Cobros routes, router registration and Más row |

## Per-task evidence (for 07-VALIDATION.md; copied by the orchestrator)

Every command below was run from the worktree root (`C:\Trabajo\VetApp\.claude\worktrees\agent-a73c40b3df586cd46`), not from `/c/Trabajo/VetApp`.

| Task | RED | GREEN | Automated marker | Tests |
|------|-----|-------|------------------|-------|
| 1 CobrosScreen | ✅ e7e68e4 (compile failure: `EstadoCobroChip` not found) | ✅ 532116c | ✅ `LISTA_COBROS_OK` | `00:06 +23: All tests passed!` (test/cobros_screen_test.dart) |
| 2 Detail + CobrarBoton | ✅ c91ec94 (compile failure, missing screen/widgets) | ✅ b169be5 | ✅ `DETALLE_LECTURA_OK` | `00:04 +19: All tests passed!` (detail 12 + cobrar_boton 7) |
| 3 Routes + Más row | ✅ 02f7b30 (5/5 failing) | ✅ 7991ef1 | ✅ `SLICE_LISTA_OK` | `00:02 +5: All tests passed!` (router test) + full suite `01:01 +1201: All tests passed!` |

Literal gate lines:
- Task 1: `flutter analyze lib/features/billing test/cobros_screen_test.dart` → `No issues found! (ran in 11.5s)`; then `00:06 +23: All tests passed!`; then `LISTA_COBROS_OK`.
- Task 2: `No issues found! (ran in 17.8s)`; then `00:04 +19: All tests passed!`; then `DETALLE_LECTURA_OK`.
- Task 3: `flutter analyze` → `No issues found! (ran in 19.7s)`; then `00:02 +5: All tests passed!`; then `flutter test` → `01:01 +1201: All tests passed!`; then `SLICE_LISTA_OK`.

Extra checks:
- `grep -rn "Colors\.\(red\|green\|blue\|grey\)" lib/features/billing` returns nothing (exit 1).
- `grep -rni "factur" lib` returns nothing (exit 1).
- `git diff --stat 8b17acc -- test/` lists only the 4 new test files; no existing test file changed.

## Behavior coverage

- **Summary:** shows $ 3.850.000 / "Noviembre 2026" and $ 450.000 / "1 cuenta pendiente". Also covered: the plural form, "Nada pendiente", and the error state ("—" ×2 plus the message while the list still renders). Columns stack at text scale 1.3. The filter count comes from `ResumenCobros.pendientes`: the test shows "Pendientes (1)" even though 2 pending CCs are visible.
- **Toggle:** defaults to Cuentas de cobro. Switching to Cotizaciones loads `cobrosProvider(cotizacion)`, hides the filters and changes the FAB label. `tipoInicial` preselects the tab. Semantics are a radio group "Tipo de documento" with a checked option.
- **Filters:** Pendientes and Pagadas work; a voided CC appears only in Todas.
- **CobroFila:** shows the name · pet, "CC-0012 · 18/08/2026 · Consulta +2", "$ 120.000" and the chip. A voided card is struck through. An open quote has no chip and shows "Válida hasta" or "Venció el". The card is one semantics node and a tap pushes `rutaCobro`.
- **Chips:** all four show icon and text.
- **Empty states:** CC, quote, read-only ("Aún no hay cobros") and "Nada por cobrar".
- **List error and size:** the error shows "Reintentar", which re-reads. The footer appears at exactly 50 and not below. The list keeps 88px bottom padding. Refresh invalidates both the list and the summary.
- **FAB:** pushes `/cobros/nuevo?tipo=cc|cot`. The "Servicios y precios" action works. In read-only the FAB shows the padlock with semantics "Nueva cuenta de cobro, bloqueado, solo lectura", and a tap opens the sheet without navigating; list, toggle and filters stay usable.
- **Detail:**
  - A pending CC shows the full header, the client with "C.C. 1.020.304.050" and "Mascota: Rocky", and the lines ("2 × $ 25.000", subtotals, Total).
  - A product line keeps its saved description and price (D-14).
  - No "Editar" and no edit icon appear (D-10).
  - Also covered: paid ("Pagada el 20/08/2026 · Nequi"), open, expired and converted quotes. The converted row is ≥48dp and opens CC-0013; "Viene de la cotización COT-0004" opens the quote.
  - A voided CC shows the strikethrough plus "Anulada el 13/11/2026 por Dr(a). Luis Gómez." and "Motivo: …".
  - Also covered: the cita/consulta links, the client row (≥48dp, opens the client), not-found with "Volver a Cobros", and the error with "Reintentar".
- **CobrarBoton:** outline button with the receipt icon that pushes the route. In read-only it shows `lock_outline`, its semantics contain "bloqueado, solo lectura", and a tap opens LimitePlanSheet without navigating.
- **CobroVinculadoFila:** all four states. Linked shows "Cobrada: CC-0012" plus the chip, and a tap opens the detail. Null, loading and error all render the given button.
- **Router (real `routerProvider`):** Más > Cobros leaves exactly one AppShell and Back returns to Más. `?tipo=cot` opens Cotizaciones. `/cobros/c1` opens the detail and Back returns to the list. The Más row has the icon, chevron, height ≥56 and no pill, and sits between Inventario and Recordatorios.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Client row navigates with `go` instead of `push`**
- **Found during:** Task 2
- **Issue:** The plan said `context.push('/clientes/${c.clienteId}')`. `/clientes/:id` lives in a shell branch; pushing it from the top-level `/cobros/:id` duplicates the shell page in the root Navigator (G5, the inventory/vaccination precedent).
- **Fix:** Used `context.go('/clientes/$clienteId')`, the same as `cita_acciones.dart`. No route helper exists in `clientes_routes.dart`.
- **Files modified:** lib/features/billing/presentation/screens/cobro_detail_screen.dart
- **Commit:** b169be5

**2. [Rule 3 - Blocking] Test tooling adjustments**
- `containsSemantics` is deprecated in this Flutter version (analyzer info), so the test uses `isSemantics`.
- The pull-to-refresh fling did not trigger `RefreshIndicator` reliably in the test, so the test calls `RefreshIndicator.onRefresh` directly. It still asserts that both the list and the summary re-read.
- Commit: 532116c

### Notes

- The cita/consulta link line uses the document date, because `Cobro` has no visit date. Showing the real visit date needs a join in a later plan (07-08 or the entry-point plans).
- `flutter pub get` rewrote the generated plugin registrants (linux/macos/windows) during the test runs. They were restored with a per-file `git checkout --` and are not part of any commit.
- STATE.md, ROADMAP.md and REQUIREMENTS.md were not updated, because this plan runs in parallel with 07-04 and 07-06. The orchestrator consolidates per wave, as with VALIDATION.

## Known Stubs

- `CobroDetailScreen._acciones(Cobro c)` returns `SizedBox.shrink()` on purpose. 07-09, 07-12 and 07-15 replace this single method with the action block.
- `/cobros/nuevo` and `/servicios` are only pushed. Their routes are registered by 07-07 and the servicios plan. In the real router today `/cobros/nuevo` would match `/cobros/:id` and show "Este cobro ya no está disponible." until 07-07 declares `nuevo` before `:id`, as documented in `cobros_routes.dart`.

## Threat Flags

None. No new network surface; reads go through the existing 07-02 providers. T-07-25 (padlock plus asegurarEscritura on the FAB and CobrarBoton), T-07-26 (summary and pending count only from the server) and T-07-28 (top-level routes, cross-shell test) are mitigated and tested.

## TDD Gate Compliance

Each task has a `test(07-05)` RED commit followed by a `feat(07-05)` GREEN commit: e7e68e4→532116c, c91ec94→b169be5, 02f7b30→7991ef1. No refactor commits were needed.

## Self-Check: PASSED
