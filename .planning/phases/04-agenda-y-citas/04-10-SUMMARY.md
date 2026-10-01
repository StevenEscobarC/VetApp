---
phase: 04-agenda-y-citas
plan: 10
subsystem: appointments
tags: [notifications, permissions, shared_preferences, riverpod, go_router]
requires: [04-06, 04-07, 04-08]
provides:
  - RecordatoriosScreen (Mas > Recordatorios lead-time setting) and etiquetaAnticipacion
  - pedirPermisoEnContexto / activarNotificaciones permission flow
  - NotificacionesBanner on the Agenda
  - permisoExplicadoProvider, marcarPermisoExplicado, mostrarBannerNotificacionesProvider
affects: [04-11]
tech-stack:
  added: []
  patterns: [in-context permission rationale once, never-throwing permission flow]
key-files:
  created:
    - lib/features/appointments/presentation/screens/recordatorios_screen.dart
    - lib/features/appointments/presentation/widgets/permiso_notificaciones.dart
    - lib/features/appointments/presentation/widgets/notificaciones_banner.dart
    - test/recordatorios_screen_test.dart
  modified:
    - lib/features/appointments/presentation/providers/recordatorios_providers.dart
    - lib/features/appointments/presentation/screens/agenda_screen.dart
    - lib/features/appointments/presentation/screens/cita_form_screen.dart
    - lib/features/home/presentation/screens/mas_screen.dart
    - lib/core/router/app_router.dart
    - test/agenda_screen_test.dart
    - test/cita_form_screen_test.dart
    - test/widget_test.dart
key-decisions:
  - "Rationale dialog shown only on create (not edit), once, and only if permission not already granted"
  - "Permission flow wrapped in try/catch so it can never block saving or navigation"
  - "Settings opened only when the OS request returns false"
requirements-completed: [AGND-04]
duration: ~40min
completed: 2026-10-01
---

# Phase 4 Plan 10: Reminder UX Summary

In-context notification permission after the first cita, a persistent non-error "Recordatorios desactivados" banner on the Agenda, and the global lead-time setting under Mas > Recordatorios (D-12, D-13).

## Tasks

| Task | Commit | Result |
|------|--------|--------|
| 1. Mas > Recordatorios screen, Mas entry, route | bfbbd1f | 4 single-select rows, immediate save with snackbar, denied warning with "Abrir ajustes" |
| 2. Permission rationale after first cita | 42c3f9a | Dialog once, "Activar recordatorios" requests, "Ahora no" skips |
| 3. Agenda banner | (task 3 commit) | Warning-tinted, persistent, "Activar", hidden when granted |

## Deviations from Plan

- Removed a planned "changing lead time reprograms" widget test from recordatorios_screen_test: that behavior is already covered by 04-07's recordatorios_providers_test, and reproducing it required the full auth and cita harness.
- `AnticipacionRecordatorio.build` already fell back to 60 for invalid stored values (04-07), so no change was needed for T-04-39.
- Test note: while the rationale dialog is open the form's saving spinner keeps animating, so the new tests use `pump(Duration)` instead of `pumpAndSettle` at that step. Existing create tests now default the fake service to permission granted.

## Verification

`flutter analyze`: no issues. `flutter test`: 329 passed. Real OS prompt and settings behavior remains a manual device check in 04-11.

## Known Stubs

None.

## Self-Check: PASSED
