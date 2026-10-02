---
phase: 05-vacunaci-n-y-desparasitaci-n
plan: 07
subsystem: vaccination
tags: [flutter, riverpod, go_router, vaccination, carne]
requires:
  - phase: 05-02
    provides: carneProvider, DosisEstadoChip, FakeVacunaRepository
  - phase: 05-05
    provides: rutaRegistrarDosis, DosisRegistrada, mostrarDosisRegistrada
  - phase: 05-06
    provides: showCompartirCarneSheet
provides:
  - "CarneScreen at /pacientes/:id/carne (and /clientes/:id/mascotas/:mascotaId/carne)"
  - DosisCard, BiologicoGroupHeader, showAnularDosisSheet, AnularDosis action
  - CarneResumenSection and CarneBadge in the ficha
affects: [05-16]
key-files:
  created:
    - lib/features/vaccination/presentation/screens/carne_screen.dart
    - lib/features/vaccination/presentation/widgets/dosis_card.dart
    - lib/features/vaccination/presentation/widgets/biologico_group_header.dart
    - lib/features/vaccination/presentation/widgets/anular_dosis_sheet.dart
    - lib/features/vaccination/presentation/widgets/carne_resumen_section.dart
    - lib/features/vaccination/presentation/providers/anular_dosis_providers.dart
    - test/carne_screen_test.dart
  modified:
    - lib/features/patients/presentation/pacientes_routes.dart
    - lib/features/clients/presentation/clientes_routes.dart
    - lib/features/patients/presentation/screens/mascota_detail_screen.dart
    - test/mascota_detail_screen_test.dart
decisions:
  - "Carné lives on its own screen; ficha keeps 'Nueva consulta' as its only accent CTA"
  - "CarneScreen list body starts with a marked extension point where 05-16 can prepend the clinic header"
requirements-completed: [VAC-01, VAC-02, VAC-03, VAC-04]
completed: 2026-10-02
---

# Phase 5 Plan 07: Carné en la ficha + anular Summary

Carné screen grouping doses by biológico (Vencida > Próxima > Al día, then alphabetical) with the server-derived current dose card, collapsed Historial, append-only "Anular dosis" with motivo, pinned "Registrar dosis" / "Compartir carné" actions, and a ficha section plus header badge that open it.

## Tasks

| Task | Commit | Notes |
|------|--------|-------|
| 1 RED tests | 66b5bb3 | carne_screen_test (11) + 4 new ficha tests; failed only because UI was missing (compile errors on the missing CarneScreen / no section) |
| 2 CarneScreen, DosisCard, anular | f83fccc | carne_screen_test green (11/11) |
| 3 Ficha integration + routes | a865d95 | full suite green |

## Verification

`flutter analyze` clean; full `flutter test` passes (566). Verified with fakes only; the live Phase 5 schema is not applied yet.

## Deviations from Plan

**1. [Rule 2 - Missing critical] Route also added under /clientes/:id/mascotas/:mascotaId/carne**
- The ficha is reachable from the Clientes tab with a different `rutaBase`; without the child route the section would navigate to a non-existent location.
- Files: lib/features/clients/presentation/clientes_routes.dart

**2. Signature additions:** `showAnularDosisSheet(context, dosis, {required mascotaId})` (the dose has no mascotaId, needed to invalidate the carné), and `CarneResumenSection` / `CarneBadge` take `rutaBase` (as the ficha does) so navigation works from both entry points.

**3. Button label** is "Registrar dosis" with `Icons.add` (not a literal "+" in text), matching the existing "Nueva consulta" idiom.

## Known Stubs

None. Header area of CarneScreen is a marked extension point for the clinic logo (05-16); not implemented here by design.

## Notes

`flutter pub get` regenerated linux/macos/windows plugin registrants; left uncommitted. Orphan doses whose biológico no longer appears in `biologicos` (e.g. all doses anulled) are not listed; the server decides which biológicos exist.

## Self-Check: PASSED
