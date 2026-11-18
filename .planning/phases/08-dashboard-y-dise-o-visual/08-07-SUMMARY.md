---
phase: 08-dashboard-y-dise-o-visual
plan: 07
subsystem: appointments-ui
tags: [dash-04, appointments, design-system, accessibility, tdd]
requires: ["08-02 (AppButton destructive + square mode, themes, tool/dash04_gates.sh)"]
provides:
  - "Appointments presentation files with no raw TextButton/OutlinedButton"
  - "DayStrip with 48 dp cells and token spacing"
  - "test/barrido_agenda_test.dart source + widget guards"
affects: [agenda, cita form, cita detail, recordatorios, notificaciones banner]
tech-stack:
  added: []
  patterns: ["AppButton(expand: false) for dialog/inline actions", "AppButton square mode inside long-press GestureDetector"]
key-files:
  created:
    - test/barrido_agenda_test.dart
  modified:
    - lib/features/appointments/presentation/screens/agenda_screen.dart
    - lib/features/appointments/presentation/screens/cita_form_screen.dart
    - lib/features/appointments/presentation/screens/recordatorios_screen.dart
    - lib/features/appointments/presentation/widgets/cita_acciones.dart
    - lib/features/appointments/presentation/widgets/notificaciones_banner.dart
    - lib/features/appointments/presentation/widgets/permiso_notificaciones.dart
    - lib/features/appointments/presentation/widgets/time_stepper.dart
    - lib/features/appointments/presentation/widgets/day_strip.dart
decisions:
  - "DayStrip: horizontal padding md -> sm and the per-cell 2 px padding removed so 7 x 48 dp fits at 360 dp (344/7 = 49.1 dp). The strip is 8 dp wider on each side (accepted visual change)."
  - "TimeStepper keeps its outer Semantics + Tooltip + GestureDetector; only the inner SizedBox+OutlinedButton became AppButton(outline, cuadrado, lado 64). The icon is now 20 dp (AppButton square mode) instead of the default 24 dp."
metrics:
  completed: 2026-11-17
  tasks: 2
  files: 9
---

# Phase 8 Plan 07: Appointments DASH-04 sweep Summary

The appointments module no longer uses raw Material buttons. Hoy, Cambiar, Abrir ajustes, Activar, Ahora no and Volver are `AppButton` text buttons (`expand: false`). Cancelar cita, in both the dialog and the "Más acciones" sheet, is `AppButton` destructive, and the sheet keeps its `ControlEscritura` wrapper. TimeStepper uses the 64 dp outline square `AppButton`. Every DayStrip cell is now 48 dp or wider at 360 dp, and the strip uses only `AppSpacing` tokens. No flow, rule or copy changed (D-19).

## Task evidence

| Task | Result | Evidence |
|------|--------|----------|
| 1. RED guard + 8 buttons -> AppButton | ✅ | RED (86948b2): 7 source guards failed (`TextButton(`, `TextButton.styleFrom(`, `OutlinedButton(` found), plus the dialog and TimeStepper widget tests (0 AppButton found). GREEN (672221c): `flutter test barrido_agenda + agenda_screen + cita_detail_screen + cita_form_screen + recordatorios_screen` -> `+105: All tests passed!`; the grep printed **AGENDA_BOTONES_OK**. cita_solo_lectura_test was also run with them: `+117` / `+120` all passed (T-08-25). |
| 2. DayStrip 48 dp + tokens | ✅ | RED (73698b0): cell width `42.857` < 48, and the source test was missing `AppSpacing.touchTarget`. GREEN (04ccced): `flutter test barrido_agenda + agenda_screen` -> `+36: All tests passed!`; `dash04_gates.sh` over the 8 files -> `EXENTOS: 1 (SW-01 tematizado en app_theme.dart, the cita_form Switch)`, `DASH04_GATES: PASS`; `flutter analyze` -> `No issues found!`; printed **AGENDA_BARRIDO_OK**. |

WARN closed: W-06, W-07, W-08, W-09, W-10, W-11, W-12, W-13. I-08 (agenda_screen skeleton `height: 14`) is an allowed literal and was recorded with no change. W-14 is covered by the 08-02 themes, so nothing was edited for it.

Threats: T-08-25 (ControlEscritura wrappers kept verbatim; cita_solo_lectura and cita_detail tests pass). T-08-26 (destructive variant asserted, and both dialog outcomes return false/true in tests). T-08-27 (the 360 dp test asserts `takeException()` is null, so there is no overflow).

## Deviations from Plan

**1. [Rule 1 - Test harness] Dialog trigger in the new test needed `HitTestBehavior.opaque`.** This affects only the new test file. The RED run failed with a harness error at first, so I fixed it before the RED commit.

**2. Formatter scope.** `dart format` on the presentation folder also reformatted 3 files outside this plan (`estado_cita_ui.dart`, `cliente_search_field.dart`, `proxima_banner.dart`). I reverted them, and they are not in any commit. `flutter pub get` also regenerated the plugin registrant files. I reverted those too.

No existing test files were edited.

## Known Stubs

None.

## Commits

- 86948b2 test(08-07): add failing appointments sweep guards
- 672221c refactor(08-07): appointments buttons to AppButton
- 73698b0 test(08-07): add failing DayStrip 48dp test
- 04ccced fix(08-07): DayStrip 48dp touch targets and spacing tokens

## TDD Gate Compliance

There is a RED `test(...)` commit before each GREEN commit (86948b2 -> 672221c and 73698b0 -> 04ccced).

## Self-Check: PASSED

The test file and all 8 lib files exist, and all 4 commits are present in `git log`.
