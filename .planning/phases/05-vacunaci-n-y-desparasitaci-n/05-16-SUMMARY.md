---
phase: 05-vacunaci-n-y-desparasitaci-n
plan: 16
subsystem: vaccination
tags: [carne, pdf, logo, caprasimo, flutter]
requires: [05-04, 05-06, 05-07, 05-14]
provides:
  - Carne.clinicaLogoPath (from clinica.logo_path)
  - CarneClinicaHeader widget on the in-app carné
  - CarnePdfService with CargarFuenteDisplayPdf / CargarLogoPdf / ValidarImagenPdf seams
affects: [05-17]
tech-stack:
  added: []
  patterns: [injected seams with silent fallback, dart:ui validation before pw.MemoryImage]
key-files:
  created:
    - lib/features/vaccination/presentation/widgets/carne_clinica_header.dart
  modified:
    - lib/features/vaccination/domain/entities/carne.dart
    - lib/features/vaccination/presentation/screens/carne_screen.dart
    - lib/features/vaccination/data/services/carne_pdf_service.dart
    - lib/features/vaccination/presentation/providers/carne_pdf_providers.dart
    - test/helpers/fake_pdf.dart
    - test/vacuna_mapeo_test.dart
    - test/carne_screen_test.dart
    - test/carne_pdf_service_test.dart
decisions:
  - Display font failure falls back to Figtree semibold; PDF never fails for it
  - Logo bytes validated with dart:ui before pw.MemoryImage, 5 s timeout, all in one try/catch
metrics:
  tasks: 2
  completed: 2026-10-02
---

# Phase 5 Plan 16: Clinic logo on carné and Caprasimo PDF display font Summary

The in-app carné and the PDF now show the clinic logo when set (name only otherwise), and the PDF uses Caprasimo for pet name (28) and title (20) with a Figtree semibold fallback.

## Commits
- b0b45f1 feat(05-16): clinic logo on in-app carne header
- second commit (see git log): feat(05-16): clinic logo and Caprasimo display font in carne PDF

## What was built
- `Carne.clinicaLogoPath` optional (empty string maps to null); `CarneClinicaHeader` is the first item of the carné body (data state), using `ClinicaLogo` from 05-14, which renders nothing on missing logo or error.
- `CarnePdfService`: new optional ctor params `cargarFuenteDisplay`, `cargarLogo`, `validarImagen`, `timeoutLogo`. `estilosTitulo` exposes the 28/20 styles. `imagenDecodificable` (dart:ui codec) rejects garbage bytes before they reach the document.
- `carnePdfServiceProvider` wires `PdfGoogleFonts.caprasimoRegular()` and `ClinicaLogoDatasource.descargar`.
- Tests: mapping, header (no logo / logo / failing logo), display font (once, styles, fallback), logo (valid, none, throws, timeout, garbage).

## Deviations from Plan
- [Rule 3] `timeoutLogo` is stored as a private field (`_timeoutLogo`) while the ctor param keeps the planned name; a public field broke the existing `_PdfFalso implements CarnePdfService` fake in compartir_carne_sheet_test.dart.
- `dart format` churn in unrelated vaccination files and regenerated linux/macos/windows plugin registrants were reverted, not committed.

## Verification
- `flutter analyze`: no issues. Tests pass: vacuna_mapeo, carne_screen, clinica_logo, carne_pdf_service, compartir_carne_sheet, historia_clinica_pdf_service.
- `git diff -- lib/features/clinical_history/` empty; compartir_carne_sheet.dart untouched.
- Live check of logo and Caprasimo in a real PDF is left to 05-13 F13 / real phone.

## Known Stubs
None.

## Self-Check: PASSED
