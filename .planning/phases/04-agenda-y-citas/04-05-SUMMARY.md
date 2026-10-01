---
phase: 04-agenda-y-citas
plan: 05
subsystem: appointments
tags: [flutter, riverpod, go_router, supabase, agenda, forms]
requires: [04-02, 04-03, 04-04]
provides:
  - cita_solapes (solapa, ocupaHorario, solapesCon, primerHuecoLibre)
  - motivos_cita table with default durations
  - SupabaseCitaRepository.crear (rpc crear_cita), CitaActions, citasRevisionProvider
  - CitaFormScreen (nueva) with ClienteSearchField, MascotaMultiSelect, TimeStepper
  - Agenda "Nueva cita" button, diaInicial, "Se cruza con" card label
affects: [04-06, 04-07, 04-08, 04-09, 04-10, 04-11]
key-files:
  created:
    - lib/features/appointments/domain/cita_solapes.dart
    - lib/features/appointments/domain/motivos_cita.dart
    - lib/features/appointments/presentation/screens/cita_form_screen.dart
    - lib/features/appointments/presentation/widgets/time_stepper.dart
    - lib/features/appointments/presentation/widgets/cliente_search_field.dart
    - lib/features/appointments/presentation/widgets/mascota_multi_select.dart
    - test/cita_solapes_test.dart
    - test/cita_form_screen_test.dart
  modified:
    - lib/features/appointments/data/repositories/supabase_cita_repository.dart
    - lib/features/appointments/presentation/providers/citas_providers.dart
    - lib/features/appointments/presentation/agenda_routes.dart
    - lib/features/appointments/presentation/screens/agenda_screen.dart
    - lib/features/appointments/presentation/widgets/cita_card.dart
    - test/helpers/fake_citas.dart
    - test/agenda_screen_test.dart
key-decisions:
  - "Form state derives the suggested time and default mascota selection in build (no side effects): manual step / manual checkbox toggle override it"
  - "Overlap warns via dialog and never blocks (D-09); cancelada/noAsistio free the slot (D-21)"
  - "Form-local busquedaClientesCitaProvider so the Clientes tab query is not mutated"
requirements-completed: [AGND-02]
completed: 2026-09-30
---

# Phase 4 Plan 05: Crear cita Summary

A vet can book a cita from the Agenda: search a cliente, pick one or several mascotas, choose motivo/duration, get the first free 15-minute slot suggested, set domicilio, and save through `crear_cita`; overlaps warn but never block, and agenda cards flag "Se cruza con".

## Tasks

| Task | Commit |
|------|--------|
| 1. Overlap + first-free-slot utilities and motivo table (TDD) | 996c60b |
| 2. Repository crear, CitaActions, CitaFormScreen, widgets, routes, Nueva cita button | 4f7efea |
| 3. Agenda/form coverage tests (Nueva cita, dia query, Se cruza con) | see git log (test(04-05)) |

## Verification

`flutter analyze` clean; full `flutter test` suite green (all tests pass, including 15 solapes, 14 form, 11 agenda tests). No `showTimePicker` in `lib/features/appointments`.

## Deviations from Plan

**1. [Process] Tasks 2 and 3 implementation landed in one commit.** The form is a single file and the routes/Agenda need `diaInicial` and `cruceCon` to compile, so all Task 3 production code (motivo/duration chips, domicilio, notas, overlap dialog, combined-alta returns, Agenda button, CitaCard label) was committed with Task 2; Task 3's commit holds the agenda tests.

**2. [Rule 3 - Blocking] FakeCitaRepository gained `errorCrear`** so a `crear` failure can be tested while reads still succeed (plan only specified `error`).

**3. Minor UI simplifications.** The search field has no leading search icon (AppTextField has no icon slot, shared widget left untouched); domicilio with empty dirección shows the error text but does not auto-focus the field (AppTextField exposes no FocusNode). Overlap "Cambiar hora" just closes the dialog.

**4. Route guard.** `mascota` child route passes `clienteId ?? ''` to `MascotaFormScreen` because that screen asserts exactly one of clienteId/mascotaId.

## Known Stubs

None. Reminder resync listening to `citasRevisionProvider` is intentionally left to 04-07.

## Notes

Live DB schema (04-01) not applied: `crear_cita` RPC param names follow the plan contract and are untested against a real database; all tests use fakes. No supabase/ files edited. STATE.md and ROADMAP.md untouched.

## Self-Check: PASSED
