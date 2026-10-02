---
phase: 05-vacunaci-n-y-desparasitaci-n
plan: 10
subsystem: appointments/vaccination
tags: [flutter, riverpod, go_router, completar-cita]
requires:
  - phase: 05-02
    provides: dosisDeCita repository method, FakeVacunaRepository
  - phase: 05-05
    provides: rutaRegistrarDosis, DosisRegistrada, mostrarDosisRegistrada
provides:
  - dosisDeCitaProvider(citaId)
  - "'Registrar dosis aplicada' offer in CompletarCitaScreen (D-05b, D-22)"
key-files:
  created:
    - lib/features/vaccination/presentation/providers/dosis_cita_providers.dart
  modified:
    - lib/features/appointments/presentation/screens/completar_cita_screen.dart
    - test/completar_cita_screen_test.dart
requirements-completed: [VAC-01]
completed: 2026-10-02
---

# Phase 5 Plan 10: Completar cita -> registrar dosis Summary

Per-mascota "Registrar dosis aplicada" row on the completar-cita screen for Vacunación/Desparasitación citas; it pushes `/dosis/nueva` with citaId and categoria, then invalidates `dosisDeCitaProvider` and shows 'Dosis registrada: {Biológico}'.

## Tasks

| Task | Commit |
|------|--------|
| 1 RED tests + provider | 954c022 |
| 2 Screen change (green) | 283b685 |

## Deviations from Plan

**1. [Minor] No visible "Luna" label under the offer.** The existing test expects `find.text('Luna')` to match once on the Vacunación fixture, so the pet name is exposed as a Semantics label ('Registrar dosis aplicada, Luna') rather than visible text; the name is already in the card header.

The harness now overrides `vacunaRepositoryProvider` with a fake and has a stub `/dosis/nueva` route.

## Verification

`flutter analyze` clean; full `flutter test` passes (555). `_omitidas`/`mascotasConConsulta` untouched (0 removed lines). Fakes only; no live schema used.

## Known Stubs

None.

## Self-Check: PASSED
