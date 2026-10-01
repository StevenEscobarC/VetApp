---
phase: 04-agenda-y-citas
plan: 03
subsystem: appointments
tags: [flutter, riverpod, go_router, supabase, agenda, timezone]
requires: []
provides:
  - zona_bogota helpers (fixed UTC-5)
  - formato_hora Spanish formatters
  - Cita entity + SupabaseCitaRepository (read) + providers + clockProvider
  - AgendaScreen mounted at /agenda
affects: [04-05, 04-06, 04-07, 04-08, 04-09, 04-10]
tech-stack:
  added: []
  patterns: [injected clock provider, hand-written es formatters, fake repository with unsorted results]
key-files:
  created:
    - lib/core/utils/zona_bogota.dart
    - lib/core/utils/formato_hora.dart
    - lib/core/data/clock_provider.dart
    - lib/features/appointments/domain/cita_failure.dart
    - lib/features/appointments/data/repositories/supabase_cita_repository.dart
    - lib/features/appointments/presentation/providers/citas_providers.dart
    - lib/features/appointments/presentation/estado_cita_ui.dart
    - lib/features/appointments/presentation/agenda_routes.dart
    - lib/features/appointments/presentation/screens/agenda_screen.dart
    - lib/features/appointments/presentation/widgets/day_strip.dart
    - lib/features/appointments/presentation/widgets/cita_card.dart
    - lib/features/appointments/presentation/widgets/proxima_banner.dart
    - test/helpers/fake_citas.dart
    - test/cita_test.dart
    - test/zona_bogota_test.dart
    - test/formato_hora_test.dart
    - test/agenda_screen_test.dart
  modified:
    - lib/features/appointments/domain/entities/cita.dart
    - lib/core/widgets/status/app_status_chip.dart
    - lib/core/router/app_router.dart
    - test/helpers/fake_auth.dart
    - test/widget_test.dart
key-decisions:
  - "Day math always via fixed UTC-5 helpers; no toLocal()"
  - "DayStrip is hand-built, no calendar package (D-08)"
requirements-completed: [AGND-01]
duration: ~25min
completed: 2026-09-30
---

# Phase 4 Plan 03: Agenda semanal Summary

The Agenda tab now shows the real Bogota-time week (LUN-DOM strip with non-cancelled counts, hourly list, Proxima banner, week navigation, loading/empty/error states) backed by a reconciled `Cita` entity and the read side of `SupabaseCitaRepository`, tested against `FakeCitaRepository`.

## Tasks

| Task | Commits |
|------|---------|
| 1. Bogota helpers + Spanish formatters (TDD) | 27a9021 (RED), bbaa26b (GREEN) |
| 2. Cita entity, repository read, providers, clock, fake | ddae790 |
| 3. AgendaScreen, widgets, router, noShow | 44f88bd |

## Verification

`flutter analyze` clean; full `flutter test` suite green (190 tests). No `DateTime.now()` in `lib/features/appointments`; no calendar package in pubspec.

## Deviations from Plan

None - plan executed as written. Notes: the worktree base was corrected with `git reset --hard aff72c0` at startup per the branch-check step. The live DB schema (04-01) was not applied; the repository `_select` / column names follow the plan contract and are untested against a real database.

## Known Stubs

- `ProximaBanner.onTap` and `CitaCard.onTap` are intentionally null; 04-06 wires them to the detail screen.

## Self-Check: PASSED
