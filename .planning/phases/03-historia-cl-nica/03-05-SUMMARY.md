---
phase: 03-historia-cl-nica
plan: 05
subsystem: clinical-history
tags: [riverpod, flutter, pdf, printing, share-sheet]

# Dependency graph
requires:
  - phase: 03-historia-cl-nica
    plan: "03-02"
    provides: "pdf 3.12.0 / printing 5.14.3 pinned without caret (SDK-constrained)"
  - phase: 03-historia-cl-nica
    plan: "03-03"
    provides: consultasProvider, Consulta/ExamenFisico entity, ConsultaFailure, fake_consultas.dart fixtures
  - phase: 03-historia-cl-nica
    plan: "03-04"
    provides: "formato_consulta.dart (formatearTemperatura, lineasExamenFisico), reused verbatim so the PDF and the on-screen timeline render identical vital-sign lines"
provides:
  - "HistoriaClinicaPdfService: entradasDe (whole-history, chronological document model, D-04) + generar (pw.MultiPage -> Uint8List, every error -> ConsultaFailure) + nombreArchivo"
  - "historia_clinica_pdf_providers.dart: historiaClinicaPdfServiceProvider + injectable compartirPdfProvider (CompartirPdf typedef) wrapping Printing.sharePdf"
  - "MascotaDetailScreen top-bar 'Exportar PDF' action: one tap -> native OS share sheet, spinner while exporting, never disabled"
  - "test/helpers/fake_pdf.dart: fuentesDePrueba/fuentesQueFallan (offline font-loader seam) + CompartirPdfFalso (call-logging share fake), reusable by any later plan that touches PDF export"
affects: [03-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Injectable-function seam for a platform capability (CargarFuentesPdf, CompartirPdf) - same shape as capturadorFotoProvider/capturadorFalso: tests never touch PdfGoogleFonts' network fetch or Printing's platform channel"
    - "Whole-document assembly with pw.MultiPage so pagination is automatic; the vet-facing PDF and the on-screen timeline share formato_consulta.dart's formatting helpers so both read identically"
    - "AppBar action swaps between an IconButton and a fixed-size spinner based on a single bool flag - no disabled state, no dialog, matches D-05's 'no extra ceremony' requirement"

key-files:
  created:
    - lib/features/clinical_history/data/services/historia_clinica_pdf_service.dart
    - lib/features/clinical_history/presentation/providers/historia_clinica_pdf_providers.dart
    - test/helpers/fake_pdf.dart
    - test/historia_clinica_pdf_service_test.dart
  modified:
    - lib/features/patients/presentation/screens/mascota_detail_screen.dart
    - test/mascota_detail_screen_test.dart

key-decisions:
  - "Dropped the plan's defensive 'wrap the tap-and-wait in tester.runAsync' suggestion for the three tests that exercise the real (fake-font) generar() + share flow - runAsync caused pumpAndSettle to time out; since fuentesDePrueba/the fakes involved use plain Futures with no real Timers, a plain await tester.tap(...) + await tester.pumpAndSettle() resolves correctly inside the standard fake-async test zone. Only the Completer-backed loading test keeps its manual pump()/completer.complete() sequence, which needed no runAsync either."
  - "CompartirPdf typedef (and compartirPdfProvider) live in historia_clinica_pdf_providers.dart, not the service file - the service only knows how to generate bytes; the providers file owns the injectable platform-facing seam, matching where capturadorFotoProvider lives relative to captura_foto.dart"
  - "entradasDe returns a defensive copy sorted fecha ASCENDING (oldest first) - deliberately the opposite order from HistoriaClinicaTimeline's newest-first screen sort, because a printed clinical document is read chronologically (D-04) while a screen shows the most recent event first"

requirements-completed: [HIST-03]

# Metrics
duration: ~40min
completed: 2026-09-28
---

# Phase 3 Plan 05: Export whole clinical history to PDF Summary

**Third vertical slice of Phase 3: one tap on the ficha's top-bar icon generates a PDF of the patient's WHOLE clinical history (chronological, D-04) and hands it straight to the phone's native share sheet (D-05, no preview, no dialog). `flutter analyze` clean, `flutter test` 154/154 passing.**

## Performance

- **Duration:** ~40 min, single session
- **Tasks:** 3 of 3 completed

## Accomplishments

- `HistoriaClinicaPdfService` (`lib/features/clinical_history/data/services/historia_clinica_pdf_service.dart`): `entradasDe(List<Consulta>)` builds a defensive, chronologically-sorted (oldest first, D-04) document model with the 5 fixed sections (Anamnesis, Examen físico, Diagnóstico, Tratamiento, Evolución), reusing `lineasExamenFisico` from Plan 03-04's `formato_consulta.dart` so the PDF's vital-sign lines read identically to the on-screen timeline. Every optional field renders `'Sin registrar'` instead of an empty line — verified by asserting `.trim().isNotEmpty` on every rendered value.
- `generar({mascota, consultas, generadoEn})` wraps the whole body (font loading + `pw.MultiPage` assembly + `doc.save()`) in a single `try/catch`, always throwing the same `ConsultaFailure('No pudimos generar el PDF. Intenta de nuevo.')` on any failure — a font-download error and a layout error look identical to the caller. An empty `consultas` list still produces a valid PDF (header + `'Aún no hay consultas registradas'`), never throws.
- `HistoriaClinicaPdfService.nombreArchivo` produces a filesystem-safe name (`'historia_clinica_Rocky.pdf'`, `'historia_clinica_Don_Gato.pdf'`, falling back to `'historia_clinica_paciente.pdf'` for an empty/only-punctuation name).
- `historia_clinica_pdf_providers.dart`: `historiaClinicaPdfServiceProvider` (plain `Provider`, no `autoDispose` needed — the service is stateless) and `compartirPdfProvider` (`Provider<CompartirPdf>`) whose default implementation calls `Printing.sharePdf(bytes:, filename:)` inside its own try/catch, rethrowing as the same `ConsultaFailure` message. `share_plus` was never added — `Printing.sharePdf` already invokes the platform's native share intent directly (confirmed by grep gate in the plan's verification).
- `MascotaDetailScreen`: new `bool _exportando` + `_exportarPdf()` fetches the mascota and its consultas, generates the PDF, and shares it via the injected `compartirPdfProvider`; both `ConsultaFailure` and `MascotaFailure` surface the identical Spanish SnackBar. The `AppTopBar`'s single action swaps between `IconButton(Icons.picture_as_pdf_outlined, tooltip: 'Exportar historia clínica a PDF')` and a fixed 24×24 `CircularProgressIndicator` based on `_exportando` — no disabled state (works for a zero-consulta patient too, per D-04), no preview screen, no confirmation dialog (D-05).
- `test/helpers/fake_pdf.dart`: `fuentesDePrueba` (offline base14 Helvetica, no network), `fuentesQueFallan` (simulates a font-download failure), and `CompartirPdfFalso` (call-logging `CompartirPdf` fake, invocable directly wherever the typedef is expected via Dart's callable-class feature) — no test in the suite touches `PdfGoogleFonts` or `Printing` directly.
- Unit tests (`historia_clinica_pdf_service_test.dart`, 7 cases) pin: whole-history chronological order and content, the fixed 5-section shape with `'Sin registrar'`, Otitis's formatted vitals matching the timeline's copy, valid-PDF-bytes generation (both with and without consultas), and font-failure → `ConsultaFailure` translation.
- Widget tests (`mascota_detail_screen_test.dart`, +6 cases) pin: the tooltip/icon existing, a real tap producing exactly one share call with the correct filename and PDF-starting bytes, the zero-consultas patient still sharing once, the loading spinner replacing the icon mid-export (and the tooltip disappearing, making a second tap impossible) via a `Completer`-backed font loader, and the fixed error SnackBar with zero share calls when the font loader fails.

## Task Commits

1. **Task 1: Failing tests for the PDF service and the ficha export action (RED)** - `50db8b6` (test)
2. **Task 2: HistoriaClinicaPdfService and its providers (GREEN for the service test)** - `fda0bae` (feat)
3. **Task 3: 'Exportar PDF' top-bar action on the ficha (GREEN)** - `e228510` (feat)

## Files Created/Modified

- Created: `lib/features/clinical_history/data/services/historia_clinica_pdf_service.dart`, `lib/features/clinical_history/presentation/providers/historia_clinica_pdf_providers.dart`, `test/helpers/fake_pdf.dart`, `test/historia_clinica_pdf_service_test.dart`
- Modified: `lib/features/patients/presentation/screens/mascota_detail_screen.dart`, `test/mascota_detail_screen_test.dart`

## Decisions Made

- `entradasDe` sorts ascending (oldest first) — the opposite direction from `HistoriaClinicaTimeline`'s newest-first screen sort — because D-04 explicitly frames the export as "the whole history in chronological order," matching how a printed clinical record is conventionally read.
- Runtime PDF strings keep their Spanish accents (á, é, í, ó, ú, ñ — all valid Latin-1 code points) since `PdfGoogleFonts.notoSansRegular()`/`.notoSansBold()` render them correctly in production; only characters genuinely outside Latin-1 (em dash, curly quotes) were avoided, per the plan's literal instruction.
- No veterinarian identity and no owner-facing wording anywhere in the generated document (RESEARCH Open Question 2 / D-05) — the PDF's patient block only shows Especie, Raza, Fecha de nacimiento, Dueño, and a "Generado el" timestamp.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `implicit_call_tearoffs` lint on the `CompartirPdfFalso` override**
- **Found during:** Task 2, confirming `flutter analyze` was clean per that task's verify gate
- **Issue:** `compartirPdfProvider.overrideWithValue(compartir ?? CompartirPdfFalso())` passed a callable-class instance directly where the `CompartirPdf` function type is expected, triggering an implicit tear-off info-lint under `flutter_lints`' default rule set.
- **Fix:** Made the tear-off explicit — `(compartir ?? CompartirPdfFalso()).call`.
- **Files modified:** `test/mascota_detail_screen_test.dart`
- **Commit:** `fda0bae`

**2. [Rule 1 - Bug] `tester.runAsync` wrapper caused `pumpAndSettle` to time out**
- **Found during:** Task 3, `flutter test` after wiring the ficha action
- **Issue:** The plan's RED-authored tests wrapped each tap-and-wait in `tester.runAsync(() async { await tester.tap(...); })` per the plan's defensive guidance ("if PDF generation does not complete under testWidgets' fake async..."). Calling `tester.tap()` (a widget-binding API) inside `runAsync`'s real-async-zone callback desynchronized the test from the normal fake-clock test zone, and the subsequent `await tester.pumpAndSettle()` never observed the state change — timing out after 10s in three separate tests.
- **Fix:** Removed the `runAsync` wrapper for the three affected tests (plain export, zero-consultas export, font-failure). `fuentesDePrueba`/`fuentesQueFallan` and every fake involved are plain `Future`-returning functions with no real `Timer`, so a normal `await tester.tap(...); await tester.pumpAndSettle();` resolves correctly inside the standard test zone — matching how every other async flow in this codebase's widget tests (e.g. `_cambiarFoto`, `RegistrarConsulta`) is already tested without `runAsync`.
- **Files modified:** `test/mascota_detail_screen_test.dart`
- **Commit:** `e228510`

None else. All three tasks otherwise executed exactly as written.

## Issues Encountered

None beyond the two fixes documented above.

## User Setup Required

None. `pdf 3.12.0` / `printing 5.14.3` were already pinned in `pubspec.yaml` by Plan 03-02; no new dependency was added (`share_plus` explicitly not needed — confirmed by the plan's own grep gate).

## Next Phase Readiness

- Plan 03-06 can build on this plan's `HistoriaClinicaPdfService`/`compartirPdfProvider` pair without further changes to `MascotaDetailScreen`'s body — the export action lives entirely in the `AppTopBar`'s `actions` list.
- This plan ran entirely against `FakeMascotaRepository`/`FakeConsultaRepository` and the offline `fuentesDePrueba` font loader; it does not depend on live Supabase data or a real network fetch of `PdfGoogleFonts`. Production behavior (real Google Fonts download, real native share sheet) has not been manually verified on-device — flagged for manual QA before shipping, since `[CITED: RESEARCH Assumptions Log A3]` notes exact Android/iOS share-sheet permission requirements were not explicitly confirmed by the fetched `printing` docs.
- No blockers.

## Self-Check

- `HistoriaClinicaPdfService.entradasDe` sorts ascending (chronological, D-04): CONFIRMED via `flutter test test/historia_clinica_pdf_service_test.dart` (7/7 passing)
- `pw.MultiPage`, `PdfGoogleFonts.notoSansRegular`, and `lineasExamenFisico` all present in the service file: CONFIRMED via grep (`PDF_SERVICE_OK`)
- `Printing.sharePdf` used in the providers file, no `share_plus` in `pubspec.yaml`: CONFIRMED via grep (`PDF_SERVICE_OK`)
- `Icons.picture_as_pdf_outlined`, `compartirPdfProvider`, and the exact tooltip string wired into `mascota_detail_screen.dart`, with no `showDialog` anywhere in the file: CONFIRMED via grep (`SLICE_PDF_OK`)
- Commit `50db8b6` (Task 1, test): FOUND in `git log --oneline`
- Commit `fda0bae` (Task 2, feat): FOUND in `git log --oneline`
- Commit `e228510` (Task 3, feat): FOUND in `git log --oneline`
- `flutter analyze`: No issues found
- `flutter test`: 154/154 passing
- Working tree clean for all plan files after these commits: CONFIRMED via `git status --short` (only unrelated pre-existing local/generated-file diffs remain untouched)

## Self-Check: PASSED

---
*Phase: 03-historia-cl-nica*
*Completed: 2026-09-28*
