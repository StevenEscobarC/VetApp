---
phase: 08-dashboard-y-dise-o-visual
plan: 06
subsystem: home
tags: [inicio, dashboard, metrics, pull-to-refresh, dark-mode]
requires:
  - 08-02 (theme tokens, dash04_gates.sh)
  - 08-03 (inicioResumenProvider, proximasCitasProvider, FakeInicioRepository, formatearCopCorto)
  - 08-15 (VacunasPendientesCard.mostrarSiVacia, avisoPlanVisibleProvider)
provides:
  - InicioColores (theme-aware text/number/skeleton colors, reused by 08-12)
  - BloqueError (per-block error card, reused by 08-12)
  - InicioEncabezado, MetricasMes, MetricaTarjeta
  - Rewritten InicioScreen (header, banner gap, metrics, Vacunar, alerts, RefreshIndicator, resume)
affects:
  - test/widget_test.dart (Inicio greeting expectations)
tech-stack:
  added: []
  patterns:
    - three-way value -> error -> skeleton state without .when, so a refresh keeps old numbers
    - screen decides gaps from the same providers the alert cards watch (no double/trailing gap)
key-files:
  created:
    - lib/features/home/presentation/widgets/inicio_colores.dart
    - lib/features/home/presentation/widgets/bloque_error.dart
    - lib/features/home/presentation/widgets/inicio_encabezado.dart
    - lib/features/home/presentation/widgets/metricas_mes.dart
    - test/metricas_mes_test.dart
  modified:
    - lib/features/home/presentation/screens/inicio_screen.dart
    - test/inicio_screen_test.dart
    - test/widget_test.dart
decisions:
  - "MetricaTarjeta exposes a Semantics node with button + onTap only when tappable (excludeSemantics would otherwise drop the InkWell tap action)"
  - "Unknown (non-InicioFailure) summary errors render kErrorResumenInicio, never raw exception text (T-08-21)"
  - "PlanBanner and StockBajoCard already own an md padding; Inicio adds sm next to them so every visible gap totals lg"
metrics:
  duration: ~35 min
  completed: 2026-11-17
---

# Phase 8 Plan 06: Inicio slice 1 (header, month metrics, pull-to-refresh) Summary

Inicio now opens with a greeting header (no AppTopBar) and three real month numbers from `inicioResumenProvider`: Consultas (`formatearMiles`), Ingresos (`formatearCopCorto`, opens `/cobros`) and Pacientes nuevos (opens `/pacientes`). Each block fails on its own with a neutral `BloqueError`, colors work in dark mode, and pull-to-refresh plus app resume reload the screen without a skeleton flash.

## Tasks

| # | Task | Result | Commits | Evidence |
|---|------|--------|---------|----------|
| 1 | InicioColores, BloqueError, InicioEncabezado and MetricasMes widgets | ✅ | e9f4036 (RED), 01ff772 (GREEN) | RED: compile failure (`MetricaTarjeta` undefined). GREEN: `flutter test test/metricas_mes_test.dart` → `+17: All tests passed!`; `flutter analyze lib/features/home` → No issues; `dash04_gates.sh lib/features/home/presentation/widgets` → `DASH04_GATES: PASS`; no light-only AppColors text constant in the 3 widgets; no "factur" in lib/features/home → printed **METRICAS_OK** |
| 2 | Rewrite InicioScreen | ✅ | e767c28 (RED), 269c9aa (GREEN) | RED: `flutter test test/inicio_screen_test.dart` → `+11 -12: Some tests failed.` GREEN: `flutter test test/inicio_screen_test.dart test/metricas_mes_test.dart test/widget_test.dart` → `+51: All tests passed!` (23 + 17 + 11); no AppTopBar; RefreshIndicator, `mostrarSiVacia: false` and AppLifecycleListener present; `dash04_gates.sh lib/features/home` → PASS; no "factur"; full `flutter analyze` → No issues found → printed **INICIO_SLICE1_OK** |

Verifies were run from the worktree root (the plan's `cd /c/Trabajo/VetApp` replaced by the worktree path). The full suite is run by the orchestrator after the wave merge.

## What was built

- `inicio_colores.dart`: `numero` (primaryText / primaryHover), `secundario`, `tenue` (`onSurfaceVariant`), `principal` (`onSurface`), `esqueleto` (surfaceMuted / mutedDark). It is the only Inicio file that names light/dark constants.
- `bloque_error.dart`: AppCard with a decorative icon (wifi_off when `sinConexion`, otherwise error_outline), a liveRegion message, and a text "Reintentar" that shows a spinner while the retry runs.
- `inicio_encabezado.dart`: "Hola," / name (Display 28, 2 lines) / storefront icon + clinic or "Sin clínica asignada". It is one header semantics node, "Hola, {nombre}. {clínica}". While loading it shows 160x28 and 120x16 skeleton bars.
- `metricas_mes.dart`: three cards in a row (IntrinsicHeight, min 96). They stack when the width is under 320 or the text scale is above 1.3 (min 64, number on the right). Loading shows the real kickers plus 56x28 skeletons, and taps are off. On error the whole row becomes one BloqueError, and Reintentar invalidates only `inicioResumenProvider`.
- `inicio_screen.dart`: a `ConsumerStatefulWidget` with `SafeArea > RefreshIndicator > ListView(AlwaysScrollable)`. Order: header, then the banner (only when `avisoPlanVisibleProvider` is non-null), metrics, the unchanged Vacunar block, `VacunasPendientesCard(mostrarSiVacia: false)`, and `StockBajoCard`.
  - `_refrescar` increments `inicioRevisionProvider`, invalidates profile, plan, both vacunas providers and inventario, then awaits the resumen and citas futures with errors swallowed.
  - On resume, the same 5 providers are invalidated.
  - Profile error shows "No pudimos cargar tu perfil." (or the offline text) with Reintentar.

## Deviations from Plan

**1. [Rule 1 - Bug] Gap arithmetic next to cards that own padding.** `PlanBanner` has a built-in bottom `md` and `StockBajoCard` a built-in top `md`, and neither file belongs to this plan. Adding a full `lg` next to them would leave 40px double gaps. Inicio adds `sm` there instead, so each gap totals `lg`; code comments explain why. If 08-12 removes PlanBanner's padding, change that `sm` to `lg`. Commit 269c9aa.

**2. [Rule 1 - Test fix] Read-only lock assertion.** The new D-06 test first expected exactly one `lock_outline` on screen, but the read-only PlanBanner shows one too. It now asserts there is no lock inside `MetricasMes`. Commit 269c9aa.

**3. [Rule 3 - Lint] `containsSemantics` is deprecated in this Flutter version.** Switched to `isSemantics` so `flutter analyze` is clean. Commit 269c9aa.

**4. [Rule 2 - Security] Unknown summary errors.** Non-`InicioFailure` errors render the fixed `kErrorResumenInicio` copy, never exception text (T-08-21). A test covers this.

## Threat mitigations

- T-08-21: BloqueError only renders `InicioFailure.message`. Unknown errors are mapped to the fixed copy (test "un error desconocido muestra el mensaje genérico").
- T-08-22: metrics are never wrapped in ControlEscritura. Test "las cifras navegan igual en solo lectura (D-06)" shows no lock and that `/cobros` opens with `planSoloLectura`.
- T-08-23: one AppLifecycleListener, disposed in `dispose`. `onRefresh` awaits once and swallows errors.

## Known Stubs

None. The standalone Vacunar button stays on purpose; 08-12 folds it into the quick actions (D-10).

## Self-Check: PASSED

- FOUND: lib/features/home/presentation/widgets/{inicio_colores,bloque_error,inicio_encabezado,metricas_mes}.dart, test/metricas_mes_test.dart
- FOUND commits: e9f4036, 01ff772, e767c28, 269c9aa
