---
phase: 08-dashboard-y-dise-o-visual
plan: 10
subsystem: ui
tags: [flutter, dash-04, team, vaccination, design-system]
requires:
  - phase: 08-02
    provides: AppButton text/destructive variants, AppTheme dark colorScheme, tool/dash04_gates.sh
provides:
  - Team dialog actions on AppButton (W-17 fixed)
  - Vaccination spacing tokens and dark-safe '(retirado)' label (W-16, I-10 fixed)
  - test/barrido_equipo_vacunas_test.dart sweep guard
affects: [08-VALIDATION]
tech-stack:
  added: []
  patterns: ["Dialog actions as AppButton(variant: text, expand: false)"]
key-files:
  created:
    - test/barrido_equipo_vacunas_test.dart
  modified:
    - lib/features/team/presentation/screens/equipo_screen.dart
    - lib/features/team/presentation/widgets/invitacion_card.dart
    - lib/features/team/presentation/widgets/miembro_acciones_sheet.dart
    - lib/features/vaccination/presentation/widgets/dosis_card.dart
    - lib/features/vaccination/presentation/widgets/carne_resumen_section.dart
key-decisions:
  - "dosis_card PopupMenuButton padding AppSpacing.sm keeps a 48x48 tap target (measured), so AppSpacing.md was not needed"
requirements-completed: [DASH-04]
duration: ~25min
completed: 2026-11-17
---

# Phase 8 Plan 10: Team and vaccination DASH-04 sweep Summary

The team dialogs now use AppButton text actions with the same pop(true/false) outcomes. In vaccination, spacing uses AppSpacing tokens and the '(retirado)' label takes its color from the theme, so it stays legible in dark mode. Only visual changes were made (D-19).

## Evidence per task

| Task | Result | Evidence |
|------|--------|----------|
| 1 RED | ✅ | `7232ef8`: 7 of 7 new guard and equipo tests failed for the right reason (TextButton found; 0 `AppButton` ancestors for 'Volver'/'Generar nuevo'/'Hacer administrador') |
| 1 GREEN | ✅ | `341de09`: `--plain-name "equipo"` gave `+4: All tests passed!`. `equipo_screen_test.dart` + `team_actions_test.dart` gave `+47: All tests passed!`. The grep found no raw `TextButton(` and the command printed **EQUIPO_BARRIDO_OK** |
| 2 RED | ✅ | `e2fb6d8`: 3 tests failed (dosis_card literal, carne_resumen literal, dark '(retirado)' was #645C50 instead of #9C8F7B). The 48 dp, light-color and xl-height tests passed on purpose because they guard behaviour that already worked |
| 2 GREEN | ✅ | `ff280d3`: the new test file + `mascota_detail_screen_test.dart` gave `+58: All tests passed!`. `dash04_gates.sh` over the 5 files gave `DASH04_GATES: PASS`. The `const TextStyle(color: AppColors.textMuted)` grep was empty. `flutter analyze` reported `No issues found!` and the command printed **VACUNAS_BARRIDO_OK** |

The full suite was not run here; per the plan, the orchestrator runs it per wave.

## Commits

- `7232ef8` test(08-10): add failing team and vaccination sweep guards
- `341de09` refactor(08-10): team dialog buttons to AppButton
- `e2fb6d8` test(08-10): add failing vaccination sweep tests
- `ff280d3` refactor(08-10): vaccination spacing tokens and theme-aware retired label

## Deviations from Plan

1. **[Rule 1 - Bug in own test] Spacing-literal regex.** The first version of the guard regex did not match `EdgeInsets.all(12)` because the digit follows `(` directly. Fixed before the RED commit with `\((?:[^)]*[^a-zA-Z_.0-9])?\d+`.
2. **dart format** reflowed two unrelated lines (the `CarneBadge` constructor and a list literal in `dosis_card._lote`). This is formatting only, with no logic change.

No existing test files were edited.

## Deferred Issues

- `tool/dash04_gates.sh` SW-04 uses the same regex shape (`\([^)]*[^a-zA-Z_.0-9][0-9]+\b`), so it misses a literal that sits right after the parenthesis, such as `EdgeInsets.all(12)`. It is owned by 08-02 and was not changed here. The orchestrator should consider `\(([^)]*[^a-zA-Z_.0-9])?[0-9]+\b`, which can surface hits in other plans.

## Threat review

- T-08-34: only the dialog buttons changed. The admin checks and RPC guards are untouched, and `team_actions_test` is green.
- T-08-35: the pop(false)/pop(true) mapping was copied verbatim. The new widget tests tap both outcomes for regenerate and for member confirm, and the 'Volver' outcome for revoke.

## Known Stubs

None.

## Self-Check: PASSED

- The test file and the 5 lib files exist, and all 4 commits are present in `git log`.
