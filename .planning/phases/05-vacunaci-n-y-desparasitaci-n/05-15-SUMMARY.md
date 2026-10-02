---
phase: 05-vacunaci-n-y-desparasitaci-n
plan: 15
subsystem: clinic-logo
tags: [flutter, riverpod, storage, image-crop]
requires: [05-14, 05-04, 05-08]
provides:
  - "Mas > Datos de la clinica screen (/mas/clinica): admin edit with logo, non-admin read-only"
  - "recortarCuadradoPng/Jpeg center square crop (512 px, white background)"
  - "GuardarDatosClinica action (upload, actualizar_clinica, orphan cleanup, profile refresh)"
key-files:
  created:
    - lib/core/utils/recorte_cuadrado.dart
    - lib/features/clinic/presentation/providers/datos_clinica_providers.dart
    - lib/features/clinic/presentation/screens/datos_clinica_screen.dart
    - test/recorte_cuadrado_test.dart
    - test/guardar_datos_clinica_test.dart
    - test/datos_clinica_screen_test.dart
  modified:
    - lib/features/team/presentation/equipo_routes.dart
    - lib/features/home/presentation/screens/mas_screen.dart
requirements: [VAC-04]
decisions:
  - "Center crop with dart:ui only; no image_cropper dependency"
  - "Form keeps the Clinica returned by the save as its base so a second save never uses a stale logoPath"
metrics:
  tasks: 2
  completed: 2026-10-02
---

# Phase 5 Plan 15: Datos de la clinica with logo upload Summary

The admin can edit clinic name, city, address, phone and logo from Mas; the logo is cropped to a centered 512 px square on white, compressed to JPEG, uploaded to `clinica-logos` and saved through `actualizar_clinica`. Non-admins see the data read-only.

## Commits
- b417fd4: crop util + GuardarDatosClinica (tests first-class: 2 crop tests, 6 action tests)
- 0e96460: DatosClinicaScreen, `path: 'clinica'` in masTeamRoutes, Mas entry, 7 widget tests

## Verification
- `flutter analyze`: no issues. Full `flutter test`: 629 passing.
- `app_router.dart` untouched; no new dependency (`image_cropper` absent).
- Not verified live: upload against the real bucket and the RLS smoke result (pending from the user; covered by QA flow F13 in 05-13).

## Deviations from Plan
None of substance. One layout fix during GREEN: the 96 dp "Agregar logo" card overflowed with default card padding, so it uses `AppSpacing.sm` padding. Tests were written alongside the implementation rather than as separate RED commits.

## Known Stubs
None.

## Threat Flags
None beyond the plan's threat model (T-05-46..50 mitigated: size guard, UI gating, datasource-built path, re-encode drops EXIF, orphan cleanup).

## Self-Check: PASSED
