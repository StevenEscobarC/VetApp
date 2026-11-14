---
phase: 07-facturaci-n
plan: 10
subsystem: billing
tags: [flutter, riverpod, go_router, servicios, cobros, tdd]
requires:
  - 07-02 (serviciosProvider, puedeAdministrarServiciosProvider, cobrosActionsProvider.guardarServicio/archivarServicio, kRutaServicios, FakeCobrosRepository)
  - 07-05 (CobrosScreen top-bar action "Servicios y precios", cobrosRoutes in app_router)
provides:
  - ServiciosScreen (/servicios)
  - showServicioSheet(context, {servicio, nombreSugerido})
  - serviciosRoutes (GoRoute kRutaServicios, top-level)
affects:
  - lib/core/router/app_router.dart (...serviciosRoutes after ...cobrosRoutes)
tech-stack:
  added: []
  patterns: [admin-only courtesy gate + plan padlock (asegurarEscritura), CobroFailure -> manejarLimitePlan then inline]
key-files:
  created:
    - lib/features/billing/presentation/screens/servicios_screen.dart
    - lib/features/billing/presentation/widgets/servicio_sheet.dart
    - lib/features/billing/presentation/servicios_routes.dart
    - test/servicios_screen_test.dart
  modified:
    - lib/core/router/app_router.dart
decisions:
  - "Servicios: no seed; empty-state suggestion chips prefill the name only and focus the empty price field"
  - "Servicios: suggestion chips also pass through asegurarEscritura (they create), rows open the sheet and a server LP004 is handled by manejarLimitePlan"
  - "Servicios: price field is digitsOnly + maxLength 9; 'too high' is reachable with 9 digits (> 100.000.000)"
metrics:
  duration: ~25 min
  completed: 2026-11-13
  tasks: 2
  files: 5
---

# Phase 7 Plan 10: Servicios y precios Summary

Admin-maintained catalog of clinic services with a default COP price (create, edit, archive with confirmation), read-only for colleagues, with suggestion chips that prefill names only, served at a top-level `/servicios` route that keeps a single AppShell.

## Tasks

| # | Task | RED commit | GREEN commit | Result |
|---|------|------------|--------------|--------|
| 1 | ServiciosScreen + ServicioSheet | `ab8cfbf` | `c4e1957` | ✅ SERVICIOS_OK |
| 2 | /servicios route + router registration | `b6abc0c` | `42d902e` | ✅ SLICE_SERVICIOS_OK |

## Per-task evidence (for 07-VALIDATION.md)

All commands run from the worktree root (`C:\Trabajo\VetApp\.claude\worktrees\agent-af81f25ced07d7319`).

### Task 1 — ✅

RED: `flutter test test/servicios_screen_test.dart` → compile failure (`servicios_screen.dart` missing), `00:00 +0 -1: Some tests failed.`

GREEN, `<automated>`: `flutter analyze lib/features/billing test/servicios_screen_test.dart && flutter test test/servicios_screen_test.dart && ! grep -rni "factur" lib/features/billing && echo SERVICIOS_OK`

```
No issues found! (ran in 7.5s)
00:02 +14: All tests passed!
SERVICIOS_OK
```

Behavior bullets → tests (14):
- Admin list: intro, A–Z order, `$ 50.000`, 3 chevrons, tap → "Editar servicio" prefilled.
- FAB create: sheet copy and helper, name autofocus, `guardarServicio(id: null, nombre: 'Consulta', precioCop: 50000)` (trimmed), "«Consulta» guardado.", list refreshes.
- Price field: digits only, max 9, 0 is valid.
- Edit saves with the service id.
- Validation: empty name/price; too high; `nombreDuplicado` inline (sheet stays); `sinPermiso` → "Solo el administrador de la clínica puede hacer esto.".
- Archive: dialog copy, Cancelar does nothing, Quitar → `archivarServicio('s1')`, "«Consulta» quitado.", row gone.
- Non-admin: extra helper, no chevron, no FAB, rows do not open; non-admin empty state, no suggestions.
- Admin empty state: title, body and 4 chips; "Vacunación" → name prefilled, price empty and focused, save asks for the price.
- Read-only plan: FAB padlock, semantics "Nuevo servicio, bloqueado, solo lectura", opens LimitePlanSheet, list visible.
- Load error: "No pudimos cargar los servicios." + Reintentar re-requests.

### Task 2 — ✅

RED: router group → `00:03 +14 -2: Some tests failed.` (ServiciosScreen not found on `/servicios`).

GREEN, `<automated>`: `flutter analyze && flutter test test/servicios_screen_test.dart && grep -q "\.\.\.serviciosRoutes" lib/core/router/app_router.dart && flutter test && echo SLICE_SERVICIOS_OK`

```
No issues found! (ran in 12.3s)
00:03 +16: All tests passed!
00:53 +1233: All tests passed!
SLICE_SERVICIOS_OK
```

Router tests (real `routerProvider` + `VetApp`): `/cobros` → tooltip "Servicios y precios" → `/servicios`, one ServiciosScreen, exactly one AppShell, pop returns to `/cobros`; direct push of `/servicios` (the form's "Agregar servicios" path) is top-level with one AppShell.

## Deviations from Plan

1. **[Rule 1 - Test correctness] Too-high price input.** The plan's example `'1000000000'` cannot reach validation: the UI-SPEC field is `digitsOnly` + `maxLength: 9`, so it is truncated to `100000000` (= the server max, valid). The test enters `'1000000000'` and then `'999999999'`, the largest value that fits, which exceeds the 100.000.000 CHECK and shows "El valor es demasiado alto.". The behavior holds; only the literal input changed.
2. **[Rule 2] Suggestion chips go through `asegurarEscritura`** in read-only plans. They are create actions, like the FAB. The UI-SPEC only names the FAB, and the chips do not show a padlock icon.

## Threat model

- T-07-45: the UI hides edit and the FAB for non-admins. `sinPermiso` (42501) maps to the Spanish admin message (tested).
- T-07-46: there is no seed. Suggestions prefill the name only, and the price stays empty (tested).
- T-07-47: archiving goes through `archivarServicio`, and there is no delete path (tested: no `guardarServicio` call on archive).

## Known Stubs

None.

## Notes

- `cobros_routes.dart`, `router_cobros_cross_shell_test.dart` and `07-VALIDATION.md` were not touched.
- STATE.md and ROADMAP.md were not updated from this parallel worktree. The orchestrator consolidates them per wave.
- Running `flutter` regenerated the desktop plugin registrants (`linux/`, `macos/`, `windows/` generated files). They are left uncommitted, outside this plan's scope.

## Self-Check: PASSED

- FOUND: lib/features/billing/presentation/screens/servicios_screen.dart
- FOUND: lib/features/billing/presentation/widgets/servicio_sheet.dart
- FOUND: lib/features/billing/presentation/servicios_routes.dart
- FOUND: test/servicios_screen_test.dart
- FOUND commits: ab8cfbf, c4e1957, b6abc0c, 42d902e
