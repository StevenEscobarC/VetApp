---
phase: 04-agenda-y-citas
plan: 07
subsystem: appointments
tags: [flutter, riverpod, local-notifications, timezone, reminders]
requires: [04-02, 04-05]
provides:
  - recordatorios_plan (NotificacionPlan, idNotificacion FNV-1a, planificar, tituloRecordatorio, cuerpoRecordatorio)
  - RecordatoriosService (interface), LocalNotificationsRecordatorios, RecordatoriosNoop
  - recordatoriosServiceProvider, sharedPreferencesProvider, anticipacionRecordatorioProvider, permisoNotificacionesProvider, abrirCitaDesdeNotificacionProvider, recordatoriosSyncProvider
  - FakeRecordatoriosService test helper
affects: [04-10, 04-11]
key-files:
  created:
    - lib/features/appointments/domain/recordatorios_plan.dart
    - lib/features/appointments/data/services/recordatorios_service.dart
    - lib/features/appointments/presentation/providers/recordatorios_providers.dart
    - test/helpers/fake_recordatorios.dart
    - test/recordatorios_plan_test.dart
    - test/recordatorios_providers_test.dart
  modified:
    - lib/main.dart
    - test/helpers/fake_auth.dart
key-decisions:
  - "sincronizar() returns the in-flight future and re-runs once if requested mid-run, so awaiting callers see the final state"
  - "Constructor syncs only if a vet profile is already loaded; otherwise the authProfileProvider listener does it (avoids a duplicate reprogramar)"
  - "Inexact allow-while-idle alarms, private lock-screen visibility, payload = cita id only"
requirements-completed: [AGND-04]
completed: 2026-10-01
---

# Phase 4 Plan 07: Recordatorios locales Summary

Local reminders for upcoming pendiente/confirmada citas: a pure tested planner (FNV-1a ids, 30-day horizon, 60 max, Bogota times) feeds a plugin service behind an interface; `RecordatoriosSync` rebuilds the schedule on login, resume, cita changes and lead-time changes, cancels everything on sign-out and routes taps (including cold start) to `/agenda/{id}`.

## Tasks

| Task | Commit |
|------|--------|
| 1. Plan builder with deterministic ids (TDD) | 8ee8b0d |
| 2. RecordatoriosService, no-op and fake | 1cda1bb |
| 3. Providers, RecordatoriosSync, app-root wiring | fce02e4 |

## Verification

`flutter analyze` clean; full `flutter test` green (257 tests); `flutter build apk --debug` succeeds. Real delivery, reboot persistence and sign-out are manual device checks in 04-11.

## Deviations from Plan

**1. [Process] Task 1 test and implementation committed together** (no separate RED commit); tests were written first and then run green.

**2. Test expectation note.** With a 15-minute lead the 10:30 fixture cita becomes eligible at the 09:35 clock, so the lead-time test asserts that first plan (10:15 Bogota).

## Known Stubs

None. The permission request UI, denied banner and Mas > Recordatorios setting are 04-10 (providers exist here).

## Threat Surface

T-04-26..30 mitigations implemented: cancelarTodo on sign-out (tested), private visibility + id-only payload, horizon/cap + cancelAll-first, inexact alarms only.

## Self-Check: PASSED
