---
phase: 06-inventario
plan: 03
subsystem: core-helpers
tags: [cop, formato, app-text-field, tdd]
requires: []
provides: [formatearMiles, formatearCop, parsearCop, parsearFecha-permitirFuturo, AppTextField-extended]
affects: [06-05, 06-06, 06-08]
key-files:
  modified:
    - lib/core/utils/formato.dart
    - test/formato_test.dart
    - lib/core/widgets/inputs/app_text_field.dart
  created:
    - test/app_text_field_test.dart
requirements: [INV-01, INV-03]
completed: 2026-11-12
---

# Phase 06 Plan 03: Core helpers Summary

Integer COP formatting/parsing (dot thousands, no decimal comma), `parsearFecha(permitirFuturo)` and a backward-compatible `AppTextField` extension, built test-first.

## Commits
- e56cbfc feat(06-03): formatearMiles/formatearCop/parsearCop y parsearFecha(permitirFuturo)
- 4575543 feat(06-03): AppTextField con textInputAction, focusNode, enabled, textAlign y prefixText

## Evidence
- FORMATO_COP_OK: test/formato_test.dart 35 tests pass (RED confirmed first: compile failure on new symbols); analyze clean.
- APP_TEXT_FIELD_OK: test/app_text_field_test.dart 3 tests pass (RED confirmed first); `flutter analyze` clean; full `flutter test`: 868 passed, 0 failed (2026-11-12).
- Existing formato tests untouched (only added lines); no parameter removed from AppTextField; no new dependencies.

## Deviations from Plan
- Doc comment wording avoids the literal "NumberFormat" so the plan's grep guard passes.
- Worktree base was reset to fd53b7f at startup per the branch check. Generated platform plugin files modified by `flutter pub get` were not committed.

## Self-Check: PASSED
