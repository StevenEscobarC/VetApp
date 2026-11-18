---
phase: 08-dashboard-y-dise-o-visual
plan: 05
subsystem: home / cross-feature invalidation
tags: [riverpod, invalidation, inicio, D-13]
requires: [08-03 inicioRevisionProvider in lib/core/data/inicio_revision.dart]
provides: [Inicio refresh after cita/consulta/cobro/mascota writes and on Inicio tab focus]
affects: [inicioResumenProvider, proximasCitasProvider (both watch inicioRevisionProvider)]
tech-stack:
  added: []
  patterns: ["try { unchanged body } finally { counter++ } for non-atomic writes", "success-path bump for atomic RPCs in widgets"]
key-files:
  created:
    - test/inicio_invalidacion_test.dart
  modified:
    - lib/features/appointments/presentation/providers/citas_providers.dart
    - lib/features/clinical_history/presentation/providers/consultas_providers.dart
    - lib/features/billing/presentation/providers/cobros_providers.dart
    - lib/features/patients/presentation/screens/mascota_form_screen.dart
    - lib/features/clients/presentation/screens/nuevo_cliente_mascota_screen.dart
    - lib/features/home/presentation/app_shell.dart
    - test/mascota_form_screen_test.dart
    - test/nuevo_cliente_mascota_screen_test.dart
    - test/plan_refresco_test.dart
decisions:
  - "CitaActions (4 writes) and RegistrarConsulta bump inicioRevisionProvider in finally; existing invalidations keep success-only semantics"
  - "invalidarCobros bumps the counter once per call; its callers already run it in finally"
  - "Mascota screens bump on the success path next to miPlanProvider (atomic RPC, widget may be unmounted in finally)"
  - "AppShell bumps only when the new index is 0, inside the existing post-frame callback"
metrics:
  completed: 2026-11-17
  tasks: 2
  commits: 4
---

# Phase 8 Plan 05: Inicio invalidation wiring Summary

Every write that changes an Inicio number (citas, consultas, cobros, new mascotas), plus returning to the Inicio tab, now bumps the core `inicioRevisionProvider`. Inicio's providers already watch that counter. No feature imports `home/`.

## Tasks

| # | Task | RED commit | GREEN commit | Result |
|---|------|------------|--------------|--------|
| 1 | Counter in CitaActions, RegistrarConsulta, invalidarCobros (finally) | ee77700 | 1bc62ac | ✅ `INVALIDACION_PROVIDERS_OK` |
| 2 | Mascota sign-up sites + Inicio tab focus hook | f580981 | 3d8f066 | ✅ `INVALIDACION_PANTALLAS_OK` |

### Evidence

- **Task 1 RED:** `flutter test test/inicio_invalidacion_test.dart` gave `+1 -13: Some tests failed.` Each failure was `Expected: <1> Actual: <0>`. The only passing case was the negative one, `marcarRecordatorioEnviado no suma`.
- **Task 1 GREEN:** I ran `flutter test test/inicio_invalidacion_test.dart test/cita_actions_test.dart test/consultas_providers_test.dart test/cobros_invalidacion_test.dart` and got `+56: All tests passed!`, with the new file alone at `+14`. After that, every grep gate passed and the run printed `INVALIDACION_PROVIDERS_OK`. The gates were: exactly 4 `incrementar()` in citas_providers, the counter in consultas and cobros, `finally` appearing at least 4 times, and no `home/` import from features.
- **Task 2 RED:** 4 of the new cases failed with `Expected: <1> Actual: <0>`: create mascota, nuevo cliente + mascota, back to Inicio by tap, and back to Inicio with context.go. The negative cases (edit mascota, going to Más, no navigation) passed.
- **Task 2 GREEN:** I ran `flutter test test/mascota_form_screen_test.dart test/nuevo_cliente_mascota_screen_test.dart test/plan_refresco_test.dart` and got `+36: All tests passed!`. `flutter analyze` reported `No issues found!`, and the run printed `INVALIDACION_PANTALLAS_OK`.
- I ran the verify commands from the worktree root, not `/c/Trabajo/VetApp` as the plan text says, so they checked this worktree's code.

## Deviations from Plan

None in behaviour. Small notes:
- In `AppShell` the callback is now `if (!mounted) return; ref.invalidate(miPlanProvider); if (indice == 0) { ... }`. This has the same meaning as before, and the braces are there to satisfy `curly_braces_in_flow_control_structures`.
- `dart format` reformatted one unrelated line in `nuevo_cliente_mascota_screen.dart`. I put it back to keep the diff small.
- The tests read the counter through `ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))`, or through `NavigationBar` in the shell tests. This keeps the container reachable after the form pops.

## Out of scope

Running `flutter` changed the generated plugin registrant files under `linux/`, `macos/` and `windows/` in the working tree. I did not commit or revert them.

## Known Stubs

None.

## Self-Check: PASSED

- test/inicio_invalidacion_test.dart: FOUND
- Commits ee77700, 1bc62ac, f580981, 3d8f066: FOUND in `git log`
