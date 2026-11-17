---
phase: 08-dashboard-y-dise-o-visual
plan: 02
subsystem: core-theme
tags: [theme, design-system, dash-04, gates, tdd]
requires: []
provides:
  - "AppTheme light/dark: switch, checkbox, FAB, dialog, snackbar, datePicker, bottomSheet themes"
  - "textButtonTheme AA foreground (primaryText light / primaryHover dark)"
  - "AppButton square icon mode (cuadrado, lado, contenido, botonKey)"
  - "tool/dash04_gates.sh (SW-01..SW-09 + SW-04, exemptions, --selftest)"
affects: [08-07, 08-08, 08-09, 08-10, 08-11, 08-16]
tech-stack:
  added: []
  patterns: ["component themes from colorScheme/textTheme", "grep gate script with exemption table"]
key-files:
  created:
    - test/core_tokens_test.dart
    - test/app_button_test.dart
    - tool/dash04_gates.sh
  modified:
    - lib/core/theme/app_theme.dart
    - test/app_theme_test.dart
    - lib/core/widgets/buttons/app_button.dart
    - lib/core/widgets/status/app_status_chip.dart
    - lib/core/widgets/inputs/app_text_field.dart
    - lib/features/clients/presentation/screens/clientes_list_screen.dart (comment only)
    - lib/features/patients/presentation/screens/pacientes_list_screen.dart (comment only)
  deleted:
    - lib/features/home/presentation/screens/coming_soon_screen.dart
decisions:
  - "textButtonTheme reads AppColors by brightness (primaryText light, primaryHover dark); the only brightness branch in the theme besides snackbar action color"
  - "Square icon mode lives in AppButton (no new core widget); square child wrapped in Semantics(label, excludeSemantics), no Tooltip so steppers keep long-press"
  - "Outlined disabled colors moved to outlinedButtonTheme (surfaceContainerHighest / onSurfaceVariant)"
  - "Snackbar behavior intentionally left unset (D-19)"
  - "Status chip 6px padding/gap mapped to AppSpacing.xs (4)"
metrics:
  duration: "~35 min"
  completed: 2026-11-17
---

# Phase 8 Plan 02: Core theme, core tokens, ComingSoon removal and DASH-04 gate script Summary

`AppTheme` now themes Switch, Checkbox, FAB, dialog, snackbar, date picker and bottom sheet in terracota/crema for both modes. Text buttons meet AA. `AppButton` gained a square icon mode for the steppers. Core widgets use only `AppSpacing`. The dead `ComingSoonScreen` is deleted. `tool/dash04_gates.sh` runs the self-tested DASH-04 grep gates.

## Per-task evidence

Note: every verify command was run from the worktree root instead of the plan's `cd /c/Trabajo/VetApp`, so the worktree's own code was tested.

| Task | Result | Evidence |
|------|--------|----------|
| 1. Component themes + AA text buttons | ✅ | RED: `flutter test test/app_theme_test.dart` -> `+12 -9: Some tests failed` (cfd9024). GREEN: `+21: All tests passed!`; all 7 `xxxTheme:` keys present; `AppColors.primaryText` present; no `Colors.*` / `circular(<n>)`; `flutter analyze lib/core test/app_theme_test.dart` -> `No issues found!` -> **THEME_OK** (074625d) |
| 2. Core spacing tokens + ComingSoon removal | ✅ | RED: core_tokens_test listed the 4 literals (app_button:52, app_text_field:70, app_status_chip:51/61) + ComingSoon; app_button_test failed to compile (no `cuadrado`) -> `+0 -5` (4285ec9). GREEN: `flutter test test/core_tokens_test.dart test/app_button_test.dart test/app_text_field_test.dart test/clientes_list_screen_test.dart test/pacientes_list_screen_test.dart` -> `+30: All tests passed!`; coming_soon_screen.dart absent; 0 ComingSoon/Próximamente hits in lib+test; spacing grep over lib/core/widgets empty; `flutter analyze` (whole project) -> `No issues found!` -> **CORE_TOKENS_OK** (7bb61e4). The clientes/pacientes diffs touch only doc-comment lines |
| 3. DASH-04 gate script | ✅ | RED: `--selftest` -> 7x `SELFTEST FALLA`, `DASH04_SELFTEST_FAIL (7)`, rc=1 (cbc5fb3). GREEN: `bash -n` ok; `--selftest` -> `DASH04_SELFTEST_OK`; `bash tool/dash04_gates.sh lib/core` -> `EXENTOS: 1` (recorte_cuadrado), `DASH04_GATES: PASS` -> **GATES_SCRIPT_OK** (aabbddc) |

The orchestrator still has to run the full `flutter test` suite after merging the wave. This plan ran only its own verifies, as instructed.

## Sweep baseline: `bash tool/dash04_gates.sh lib` -> `DASH04_GATES: FAIL (47)`, `EXENTOS: 44`

Exemptions applied: 9 SW-01 (FAB/Switch/SwitchListTile/Checkbox, themed here), 1 SW-02 (recorte_cuadrado canvas fill), 33 SW-03 (pdf package styles), 1 SW-09 (`kOrigenCobro = 'factura'`).

**08-07 (appointments): 9 SW-01, 4 SW-04**
- SW-01 agenda_screen.dart:504; cita_form_screen.dart:833; recordatorios_screen.dart:75; cita_acciones.dart:95, 99, 178 (`TextButton.icon(`); notificaciones_banner.dart:49; permiso_notificaciones.dart:39; time_stepper.dart:140 (OutlinedButton -> AppButton `cuadrado`)
- SW-04 day_strip.dart:96 (h 2), 120 (SizedBox 2), 124 (h 6), 142 (SizedBox 16)

**08-08 (billing): 12 SW-01, 1 SW-04**
- SW-01 cobro_form_screen.dart:533, 652, 726, 999, 1004; anular_cobro_sheet.dart:167; marcar_pagada_sheet.dart:164, 189; producto_cobro_sheet.dart:108; servicio_sheet.dart:138, 142, 232
- SW-04 linea_cobro_tile.dart:242 (SizedBox 6)

**08-09 (inventory + plan): 6 SW-01, 1 SW-04**
- SW-01 producto_detail_screen.dart:436, 502; ajuste_rapido_botones.dart:145 (OutlinedButton -> AppButton `cuadrado` + `botonKey`); ajuste_stock.dart:195; resumen_bajos_strip.dart:50; plan_banner.dart:88
- SW-04 uso_contador_tile.dart:54 (`BorderRadius.circular(4)`)

**08-10 (team): 5 SW-01**
- SW-01 equipo_screen.dart:47, 51; invitacion_card.dart:65; miembro_acciones_sheet.dart:120, 132

**08-11 (auth + main): 2 SW-01, 7 SW-04**
- SW-01 login_screen.dart:71, 83
- SW-04 client_home_screen.dart:32, 34, 36; login_screen.dart:62, 81; reset_password_screen.dart:64; lib/main.dart:68

Totals: 34 SW-01 + 13 SW-04 = 47. There were no SW-02, SW-03, SW-05, SW-08 or SW-09 hits outside the exemptions.

## Deviations from Plan

**1. [Rule 3 - Blocking] Missing import in app_text_field.dart**
- **Found during:** Task 2
- **Issue:** `const SizedBox(height: AppSpacing.xs)` did not compile because the file did not import `app_spacing.dart`.
- **Fix:** I added `import '../../theme/app_spacing.dart';`.
- **Commit:** 7bb61e4

**2. [Process] Verify path adapted**
- The plan's verify blocks `cd /c/Trabajo/VetApp`, which is the main checkout. I ran the same commands from the worktree root instead.

Otherwise the plan was executed as written. `dart format` reformatted three unrelated core widget files; I reverted those so the diff stays in scope. app_status_chip.dart was already not dart-format clean before this plan, and only its two literal lines were changed.

## Known Stubs

None.

## Threat Flags

None. The script only greps `*.dart` under the given paths, so its output contains no secrets or URLs (T-08-09). Every exemption is printed on each run (T-08-08). Snackbar behavior is unchanged and FAB/Switch/Checkbox are themed, not replaced (T-08-07).

## Self-Check: PASSED

- FOUND: lib/core/theme/app_theme.dart, test/app_theme_test.dart, test/core_tokens_test.dart, test/app_button_test.dart, tool/dash04_gates.sh
- ABSENT (intended): lib/features/home/presentation/screens/coming_soon_screen.dart
- FOUND commits: cfd9024, 074625d, 4285ec9, 7bb61e4, cbc5fb3, aabbddc
