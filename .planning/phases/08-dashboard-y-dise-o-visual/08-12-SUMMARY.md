---
phase: 08-dashboard-y-dise-o-visual
plan: 12
subsystem: home (Inicio UI slice 2)
tags: [inicio, dashboard, quick-actions, proximas-citas, read-only, router]
requires: ["08-03", "08-06", "08-09", "08-14", "08-15"]
provides:
  - AccesosRapidos + AccesoRapido (lib/features/home/presentation/widgets/accesos_rapidos.dart)
  - ProximasCitas + ProximaCitaFila (lib/features/home/presentation/widgets/proximas_citas.dart)
  - PlanBanner driven by avisoPlanVisibleProvider
  - Real-router proof for Inicio navigation (test/router_inicio_cross_shell_test.dart)
affects: [InicioScreen, PlanBanner]
tech-stack:
  added: []
  patterns:
    - "ControlEscritura outside, Semantics(button, excludeSemantics, onTap) inside only when writing is allowed"
    - "Row of 4 Expanded -> Wrap 2x2 when textScaler.scale(16) > 20.8"
    - "Cross-branch row tap with context.go; root routes pushed through route helpers"
key-files:
  created:
    - lib/features/home/presentation/widgets/accesos_rapidos.dart
    - lib/features/home/presentation/widgets/proximas_citas.dart
    - test/accesos_rapidos_test.dart
    - test/proximas_citas_test.dart
    - test/router_inicio_cross_shell_test.dart
  modified:
    - lib/features/home/presentation/screens/inicio_screen.dart
    - lib/features/plan/presentation/widgets/plan_banner.dart
    - test/inicio_screen_test.dart
    - test/plan_banner_test.dart
decisions:
  - "Paciente keeps context.push('/clientes/nuevo'): the real-router test shows no keyReservation assert and Atrás returns to /inicio, so no go fallback was needed"
  - "PlanBanner keeps its bottom md padding, so Inicio keeps the sm gap after it (08-06 note does not apply)"
  - "Row semantics state text comes from a local EstadoCita -> label switch with the same copy as AppStatusChip (its labels are private)"
requirements: [DASH-02, DASH-03]
metrics:
  completed: 2026-11-17
  tasks: 3
  commits: 6
---

# Phase 8 Plan 12: Inicio slice 2 (quick actions and próximas citas) Summary

Inicio now has the full D-12 order. "Accesos rápidos" offers Paciente, Cita, Cobro and Vacunar in one tap, and each one shows a padlock in read-only mode. "Próximas citas" lists up to 5 live citas grouped by Bogotá day. A row opens the cita detail in the Agenda tab, and the block fails on its own. PlanBanner and Inicio now share one visibility rule.

## Per-task evidence

Every verify ran from the worktree root, with the plan's `cd /c/Trabajo/VetApp` replaced by the worktree path. As instructed, I ran only this plan's tests plus `flutter analyze`; the orchestrator runs the full suite after the wave merge.

| Task | Result | Marker | Tests | Commits (RED / GREEN) |
|------|--------|--------|-------|-----------------------|
| 1 AccesosRapidos + PlanBanner on avisoPlanVisibleProvider | ✅ | `ACCESOS_OK` | RED: accesos_rapidos_test did not compile (no widget), and the 2 new plan_banner tests failed (`+20 -3`). GREEN: `flutter test test/accesos_rapidos_test.dart test/plan_banner_test.dart` gave `+36: All tests passed!` (14 + 22). `flutter analyze lib/features/plan lib/features/home`: No issues found | e8cdc68 / 7f1effc |
| 2 ProximasCitas | ✅ | `PROXIMAS_OK` | RED: compile failure (no `ProximasCitas`). GREEN: `flutter test test/proximas_citas_test.dart` gave `+14: All tests passed!`. `dash04_gates.sh lib/features/home` ended with `DASH04_GATES: PASS` (EXENTOS: 0) | aa87445 / 51e6afd |
| 3 Inicio assembly + cross-shell | ✅ | `INICIO_COMPLETO_OK` | RED: `+19 -16`. All new Inicio tests and all 6 cross-shell tests failed because Inicio had no quick actions or rows yet. GREEN: inicio_screen 29, router_inicio_cross_shell 6, accesos_rapidos 14, proximas_citas 14, plan_banner 22, total `+85: All tests passed!`. `! grep _vacunar`, AccesosRapidos and ProximasCitas present, `dash04_gates.sh lib/features/home .../plan_banner.dart` gave PASS, no "factur" in lib/features/home, and full `flutter analyze` gave No issues found | 316b4bc / c5a52bf |

## What the tests cover

- **Quick actions:** the header has header semantics. The 4 labels appear left to right, with no "Factur" anywhere. Each circle is 56x56 with the fill primary, success, textSecondary or primaryStrong. Icons are onPrimary, each target is at least 48x48, and only Paciente uses the accent. Writing semantics are "Nuevo paciente", "Nueva cita", "Nueva cuenta de cobro" and "Vacunar".
- **Quick action routes:** Paciente goes to `/clientes/nuevo`, Cita to `/citas/nueva`, Cobro to `/cobros/nuevo?tipo=cc`, and Vacunar opens "¿A quién vacuna?". With `planGratisAlTope`, Paciente opens the patient-cap sheet instead.
- **Quick actions in read-only:** there are 4 `lock_outline` icons, the fills don't change, and the semantics read "{semantica}, bloqueado, solo lectura". All 4 taps open the read-only sheet and nothing navigates.
- **Text scale:** at 1.5 the actions wrap into 2x2 with no ellipsis.
- **PlanBanner:** it follows an overridden `avisoPlanVisibleProvider` both ways: it shows a notice the plan alone would not, and hides one the plan would show. The 20 existing tests are unchanged and pass.
- **Próximas citas, grouping:** with the fixed clock, the separators read "Hoy, lun 16/11", "Mañana, mar 17/11" and "jue 19/11" in that order. Each is a header and sits before its rows.
- **Próximas citas, rows:** each row shows its title, meta and chip, and is at least 72 tall. An empty motivo leaves just "Luna". The semantics start with the hour and end with "Abre el detalle de la cita".
- **Próximas citas, navigation:** a row and "Ver agenda" both use `go`, which the tests confirm with `canPop() == false`.
- **Vet mark:** multi-vet rows show a 40 px VetAvatar, and a retired vet's is outlined (index 2). Single-vet rows show the paw in primaryStrong, and dark mode uses the theme tone instead.
- **Próximas citas, states:**
  - Empty shows the copy and an outline "Agendar cita" with `Icons.add` that goes to `/citas/nueva`. In read-only it shows the padlock and the read-only sheet, and rows still open.
  - Loading shows 3 skeleton rows.
  - An error shows BloqueError with the fixed text, and Reintentar refetches. Offline shows its own text.
  - "Ver agenda" is visible in every state.
- **Inicio:**
  - Order is header, banner, metrics, AccesosRapidos, ProximasCitas, a row, Vacunas pendientes, stock.
  - The gap before AccesosRapidos and before ProximasCitas is exactly lg.
  - There is no standalone `AppButton` 'Vacunar'.
  - Blocks are isolated both ways: a metrics error leaves the rows, and a próximas error leaves the metrics.
  - Pull-to-refresh refetches próximas.
  - In dark mode there is no exception and the metric number uses primaryHover.
  - The two former Vacunar tests now target the quick action.
- **Real router:** this uses `routerProvider` + `AppShell`. Paciente, Cita and Cobro reach `/clientes/nuevo`, `/citas/nueva` and `/cobros/nuevo` with a single AppShell and no exception, and `pop()` returns to `/inicio` each time. Vacunar opens the sheet over `/inicio`. A row lands on `/agenda/cita-prox`, and "Ver agenda" on `/agenda`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Inicio tests needed a taller test view**
- **Found during:** Task 3 GREEN.
- **Issue:** with the 2 new blocks, the alert cards fall outside the 800x600 test view plus the ListView cache. `ListView(children:)` does not build them there, so 5 existing tests found 0 "Vacunas pendientes" or stock widgets.
- **Fix:** a `_alto(tester)` helper sets a 400x2400 view. I added it to those tests and to the 0/0 and "sin bajos" tests, which would otherwise pass for the wrong reason. No assertion changed.
- **Files:** test/inicio_screen_test.dart. **Commit:** c5a52bf.

**2. [Rule 3 - Blocking] Cross-shell overrides**
- The plan said to copy the cobros `_app()` overrides (`inicioShellOverrides()` and `citaRepositoryProvider`) and also add `inicioOverrides(citas:)`.
- `inicioOverrides` overrides both providers itself, and Riverpod rejects a provider overridden twice. So the test uses `inicioOverrides(citas: FakeCitaRepository(citas: [one próxima]))` in place of those two lines.
- **Commit:** 316b4bc.

**3. Harness for dark mode**
- `routerHarness` only takes `AppTheme.light`.
- The dark-mode tests (inicio_screen_test, proximas_citas_test) build their own `ProviderScope` + `MaterialApp.router(theme: AppTheme.dark)` with the same `retry: null`. The shared helper is untouched.

**4. Format-only**
- `dart format` reflowed the new test files and proximas_citas.dart. That change is folded into c5a52bf.
- Flutter tooling regenerated the desktop plugin registrants (linux/macos/windows). I did not commit them.

### Not changed (recorded)
- I did not remove PlanBanner's bottom padding, so Inicio's `sm` gap after the banner stays as 08-06 left it.
- The UI-SPEC accessibility note asks for text buttons on Inicio ("Ver agenda", "Reintentar") to render in `primaryText` for contrast. This plan does not cover it, and the app-wide fix belongs to the core-theme plan. I left the theme color unchanged.

## Threat mitigations

- **T-08-39:** every quick action and "Agendar cita" is gated (`asegurarNuevoPaciente` for Paciente, `asegurarEscritura` for the rest) and wrapped in `ControlEscritura`. The planSoloLectura tests assert there is no navigation.
- **T-08-40:** the `planGratisAlTope` test shows Paciente opens the patient-cap sheet.
- **T-08-41:** rows come only from `proximasCitasProvider`. There is no client-side merging.
- **T-08-42:** routes under `/agenda` use `go`, and root routes are pushed through `rutaNuevaCita()` / `rutaNuevoCobro()`. The real-router test passes with no exception.
- **T-08-43:** the label is "Cobro". The tests check that no "Factur" text appears, and SW-09 passes.

## Known Stubs
None.

## Threat Flags
None. There are no new endpoints or trust boundaries; the widgets only read existing providers.

## Notes for the orchestrator
- Inicio now also renders ProximasCitas, which reads the citas repository and the team providers. Any other suite that pumps the real app at /inicio needs those overrides. widget_test and the cobros, vacunas and inventario cross-shell tests already override `citaRepositoryProvider` and the team providers, but I did not run them, as instructed. Please check them in the full-suite run.

## Self-Check: PASSED
- FOUND: lib/features/home/presentation/widgets/accesos_rapidos.dart, lib/features/home/presentation/widgets/proximas_citas.dart, test/accesos_rapidos_test.dart, test/proximas_citas_test.dart, test/router_inicio_cross_shell_test.dart
- FOUND commits: e8cdc68, 7f1effc, aa87445, 51e6afd, 316b4bc, c5a52bf
