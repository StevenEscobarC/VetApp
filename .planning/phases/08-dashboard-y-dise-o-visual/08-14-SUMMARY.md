---
phase: 08-dashboard-y-dise-o-visual
plan: 14
subsystem: test-harness
tags: [tests, riverpod, inicio, harness]
requires: ["08-03"]
provides: ["inicioShellOverrides()"]
affects: [test/helpers/fake_auth.dart, real-router tests]
tech-stack:
  added: []
  patterns: ["shared override helper spread into every real-router ProviderScope"]
key-files:
  created: [test/harness_inicio_test.dart]
  modified:
    - test/helpers/fake_inicio.dart
    - test/helpers/fake_auth.dart
    - test/router_cobros_cross_shell_test.dart
    - test/router_vacunas_cross_shell_test.dart
    - test/router_inventario_cross_shell_test.dart
    - test/servicios_screen_test.dart
decisions:
  - "inicioShellOverrides() goes before ...overrides in appUnderTest, so a test can still pass its own inicioRepositoryProvider override"
requirements: [DASH-01]
metrics:
  completed: 2026-11-17
  tasks: 2
  files: 7
---

# Phase 8 Plan 14: Shared Inicio override for real-router tests Summary

One shared helper, `inicioShellOverrides()`, swaps `inicioRepositoryProvider` for a `FakeInicioRepository`. `appUnderTest` and every real-router ProviderScope (cobros/vacunas/inventario cross-shell, and both scopes in servicios_screen) now use it, so the rewritten Inicio can never reach `Supabase.instance` in tests.

## Tasks

| # | Task | Result | Commits |
|---|------|--------|---------|
| 1 | inicioShellOverrides() helper + appUnderTest | ✅ `HARNESS_HELPER_OK`. RED: 5/5 failing (`-5`). GREEN: `appUnderTest` group passes 1/1 | fbdfbdc (RED), 7cfe1e3 (GREEN) |
| 2 | Real-router test files use the helper | ✅ `HARNESS_ROUTER_OK`. harness_inicio + 4 router/servicios files + router_equipo + widget_test: `+59: All tests passed!`. servicios_screen has 2 `inicioShellOverrides()` calls. `flutter analyze`: No issues found | 263a473 |

## TDD Gate Compliance

RED `test(08-14)` fbdfbdc came before GREEN 7cfe1e3 and 263a473. This plan only touches tests, so all commits use the `test` type, as the plan says.

## Deviations from Plan

None. The plan was executed exactly as written. I also ran test/widget_test.dart in Task 2, which the plan's action list includes.

## Threat Mitigations

- T-08-51: every real-router harness overrides the Inicio repository. The `fuente` guard in test/harness_inicio_test.dart checks the 4 files.
- T-08-52: only the overrides lists and imports changed (9 lines added across the 4 files). No assertions were touched.

## Self-Check: PASSED

- test/harness_inicio_test.dart and test/helpers/fake_inicio.dart exist, and fake_inicio.dart contains `inicioShellOverrides`.
- Commits fbdfbdc, 7cfe1e3 and 263a473 are on branch worktree-agent-aba43dd0415ad0827.
