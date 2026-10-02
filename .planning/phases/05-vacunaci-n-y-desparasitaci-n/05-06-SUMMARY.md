---
phase: 05-vacunaci-n-y-desparasitaci-n
plan: 06
subsystem: vaccination
tags: [flutter, pdf, share, whatsapp, riverpod]
requires:
  - phase: 05-02
    provides: SupabaseVacunaRepository.enlaceCarne/regenerarEnlace, Carne entities, FakeVacunaRepository
provides:
  - showCompartirCarneSheet(context, mascotaId)
  - CarnePdfService (A4 certificate) and carnePdfServiceProvider
  - kCarneBaseUrl / urlCarne, enlaceCarneProvider, regenerarEnlaceCarneProvider
affects: [05-07]
tech-stack:
  added: []
  patterns: [injectable font loader seam reused, bearer link in URL fragment]
key-files:
  created:
    - lib/core/config/carne_config.dart
    - lib/features/vaccination/presentation/providers/enlace_carne_providers.dart
    - lib/features/vaccination/presentation/providers/carne_pdf_providers.dart
    - lib/features/vaccination/data/services/carne_pdf_service.dart
    - lib/features/vaccination/presentation/widgets/compartir_carne_sheet.dart
    - test/carne_pdf_service_test.dart
    - test/compartir_carne_sheet_test.dart
  modified: []
key-decisions:
  - "Reuse CargarFuentesPdf (two fonts); Figtree regular/semibold for the PDF, titles in semibold (Caprasimo not loaded)"
  - "PDF header leaves a marked slot next to the clinic name for the D-26 logo (plan 05-16)"
requirements-completed: [VAC-04]
duration: ~40min
completed: 2026-10-02
---

# Phase 5 Plan 06: Compartir el carné Summary

Share sheet for the permanent revocable carné link (WhatsApp app-only, native share, copy, PDF, regenerate with confirmation) plus the A4 certificate PDF service with "Hecho con VetApp" footer and no QR.

## Tasks

| Task | Commit | Notes |
|------|--------|-------|
| 1 RED | 25ca0c9 | PDF/config tests |
| 1 GREEN | 8c2c419 | config, link providers, PDF service |
| 2 RED | 4649dc7 | sheet tests |
| 2 GREEN | b797855 | CompartirCarneSheet |

## Verification

`flutter analyze` clean; full `flutter test` passes (541 tests). Fakes only; live schema is applied in 05-04.

## Deviations from Plan

**1. Caprasimo not used in the PDF** - the shared `CargarFuentesPdf` typedef carries two fonts; the pet name and titles use Figtree semibold. A display font can be added later with the logo work (05-16) without changing the contract.

**2. `dart format` side effects** - formatting touched three unrelated 05-02 files; they were reverted and not committed.

## Known Stubs

None. The logo slot in the PDF header is an intentional comment placeholder for 05-16 (D-26).

## Notes

`flutter pub get` regenerated linux/macos/windows plugin registrants; left uncommitted.

## Self-Check: PASSED
