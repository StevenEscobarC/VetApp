---
phase: 08-dashboard-y-dise-o-visual
plan: 11
subsystem: auth (presentation) + app bootstrap
tags: [DASH-04, sweep, auth, spacing, dead-cta]
requires: ["08-02"]
provides: ["auth screens token-clean", "ClientHomeScreen without dead CTAs"]
affects: [login, reset password, auth_scaffold, client home, missing-config screen]
tech-stack:
  added: []
  patterns: ["AppButton text variant for inline links", "textTheme.bodyLarge.copyWith for status lines"]
key-files:
  created:
    - test/barrido_auth_test.dart
  modified:
    - lib/features/auth/presentation/screens/login_screen.dart
    - lib/features/auth/presentation/screens/reset_password_screen.dart
    - lib/features/auth/presentation/screens/auth_scaffold.dart
    - lib/features/auth/presentation/screens/client_home_screen.dart
    - lib/main.dart
decisions:
  - "Dead client CTAs removed (not disabled); secondary copy now 'Tu veterinario registra tus mascotas; aquí podrás consultar su historial.'"
  - "Spacing mapping: 24->lg, 16->md, 20->md, 12->sm, 8->sm"
  - "auth_scaffold success color: AppColors.successBg in dark, AppColors.success in light (SW-07)"
requirements: [DASH-04]
metrics:
  completed: 2026-11-17
  tasks: 2
  files: 6
---

# Phase 8 Plan 11: Auth and bootstrap DASH-04 sweep Summary

Login links are now `AppButton` text buttons (same routes), auth/reset/client/bootstrap spacing uses `AppSpacing`, auth_scaffold status lines use `bodyLarge` with theme colors (success readable in dark), and the client landing no longer shows the two CTAs that did nothing.

BRAND-BASELINE items closed: W-01, W-02, W-03, W-04, I-01, plus the `lib/main.dart` literals.

## Task evidence

| Task | Result | Evidence |
|------|--------|----------|
| 1 RED | ✅ | `flutter test test/barrido_auth_test.dart` -> `+1 -10: Some tests failed.` (commit 36a69e3) |
| 1 GREEN | ✅ | `--plain-name "login"` -> `+7: All tests passed!`; `widget_test.dart` + `register_screen_test.dart` -> `+18: All tests passed!`; no `TextButton(` in login_screen; printed **AUTH_LOGIN_OK** (commit d082b97) |
| 2 RED | ✅ | `--plain-name "cliente"` -> `+0 -1` (new copy not found) (commit 5c7fbcd) |
| 2 GREEN | ✅ | `flutter test test/barrido_auth_test.dart` -> `+12: All tests passed!`; no `onPressed: () {}` in client_home_screen; `bash tool/dash04_gates.sh lib/features/auth lib/main.dart` -> `DASH04_GATES: PASS`; `flutter analyze` -> `No issues found!`; printed **AUTH_BARRIDO_OK** (commit 567aa3f) |

Re-run after Task 2: `widget_test.dart` + `register_screen_test.dart` -> `+18: All tests passed!` (login copy unchanged).

## Commits

- 36a69e3 test(08-11): add failing auth sweep guards
- d082b97 refactor(08-11): login buttons, auth spacing and theme text styles
- 5c7fbcd test(08-11): add failing client home test
- 567aa3f fix(08-11): remove dead client CTAs and token spacing

## Deviations from Plan

None - plan executed exactly as written. No existing test file was edited. The test for sign-out uses a local `_SignOutSpy` subclass of `FakeAuthProfileNotifier` (inside the new test file) to count calls.

## TDD Gate Compliance

RED (`test(...)`) commits precede both GREEN commits (`refactor(...)`, `fix(...)`).

## Known Stubs

None. The client experience itself remains minimal by design until SCALE-01 / Phase 9.

## Self-Check: PASSED

- All 6 files exist; commits 36a69e3, d082b97, 5c7fbcd, 567aa3f present in `git log`.
- No secrets, Supabase URLs or phone numbers written. STATE.md / ROADMAP.md untouched.
