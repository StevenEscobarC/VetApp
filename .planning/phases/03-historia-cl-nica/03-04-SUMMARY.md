---
phase: 03-historia-cl-nica
plan: 04
subsystem: clinical-history
tags: [riverpod, flutter, go_router, timeline]

# Dependency graph
requires:
  - phase: 03-historia-cl-nica
    plan: "03-03"
    provides: consultasProvider, registrarConsultaProvider, Consulta/ExamenFisico entity, ConsultaFormScreen, MascotaDetailScreen entry point, test/helpers/fake_consultas.dart fixtures
provides:
  - "HistoriaClinicaTimeline (ConsumerWidget): newest-first defensive sort, expandable AppCard per consulta, empty/error/loading states"
  - "formato_consulta.dart: formatearTemperatura + lineasExamenFisico, shared formatting reused verbatim by the PDF export (Plan 03-05)"
  - "MascotaDetailScreen now renders the full clinical timeline between the Historia clinica heading and the Nueva consulta button"
  - "End-to-end register-then-see test pattern (formularioReal harness param) reused by later plans that touch this screen"
affects: [03-05, 03-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Timeline card is a StatefulWidget with a local bool _expandida - no navigation, no new screen, matches _HistorialPeso's in-place expansion precedent"
    - "Defensive client-side sort by fecha descending, never trusting source order - same pattern as _HistorialPeso (registradoEn) and now reused a third time"
    - "Shared formatting helpers (formato_consulta.dart) live in domain/, imported by both the presentation widget and the future PDF service, so timeline and document render identical strings"

key-files:
  created:
    - lib/features/clinical_history/domain/formato_consulta.dart
    - lib/features/clinical_history/presentation/widgets/historia_clinica_timeline.dart
  modified:
    - lib/features/patients/presentation/screens/mascota_detail_screen.dart
    - test/mascota_detail_screen_test.dart
    - test/mascota_form_screen_test.dart

key-decisions:
  - "Scoped the Control-general test's 'Sin registrar' count assertion to find.descendant(of: HistoriaClinicaTimeline) rather than the whole widget tree, after discovering the ficha's own blank fields (e.g. Fecha de nacimiento for mascotaRocky, who has none) also render that exact copy - Rule 1 bug fix in the RED-authored test, not a product bug"
  - "The collapsed diagnostico summary line stays rendered even when a card is expanded (per UI-SPEC, 'repeated here in full'), so diagnostico text can appear twice post-expansion - tests using find.text(...).first where needed"

requirements-completed: [HIST-02, HIST-04]

# Metrics
duration: ~35min
completed: 2026-09-28
---

# Phase 3 Plan 04: Clinical timeline widget Summary

**Second vertical slice of Phase 3: the pet ficha now shows the full clinical timeline inline, newest first, with in-place expand/collapse and zero edit/delete affordances (HIST-04). `flutter analyze` clean, `flutter test` 142/142 passing.**

## Performance

- **Duration:** ~35 min, single session
- **Tasks:** 2 of 2 completed
- **Files modified/created:** 5

## Accomplishments

- `formato_consulta.dart`: `formatearTemperatura` (one decimal, comma separator, ' °C') and `lineasExamenFisico` (fixed-order list of only the present vitals: Peso, Temperatura, Frecuencia cardiaca, Frecuencia respiratoria, Mucosas) — pure Dart, no Flutter import, reused verbatim by the PDF export in Plan 03-05 so the timeline and the exported document read identically.
- `HistoriaClinicaTimeline` (`ConsumerWidget`): watches `consultasProvider(mascotaId)`, mirrors `_HistorialPeso`'s `AsyncValue.when` shape (loading spinner, error copy, empty-state heading + body). Data path re-sorts defensively by `fecha` descending regardless of source order (test seeds `consultasRocky` unsorted and asserts both the visible dates and the vertical ordering via `getTopLeft().dy`).
- Private `_ConsultaCard` (`StatefulWidget`, local `bool _expandida`): collapsed shows date + diagnostico (ellipsized) + `keyboard_arrow_down`; tapping anywhere on the `AppCard` expands in place to `keyboard_arrow_up` and the fixed Anamnesis / Examen fisico / Diagnostico / Tratamiento / Evolucion block, with `Sin registrar` for any blank optional field and a single `Examen físico: Sin registrar` line (never five empty rows) when `examenFisico.estaVacio`.
- HIST-04 enforced both structurally (no `Icons.edit`/`Icons.delete`/`IconButton`/`onLongPress`/`Dismissible` anywhere in the file — static grep gate) and behaviorally (widget test scoped to `find.byType(HistoriaClinicaTimeline)` finds zero edit/delete icons).
- `MascotaDetailScreen`: `HistoriaClinicaTimeline(mascotaId: widget.mascotaId)` inserted between the "Historia clínica" heading and the "Nueva consulta" button — the exact gap Plan 03-03 left open. No other line in the file changed.
- End-to-end test: with the real `ConsultaFormScreen` mounted under `consultas/nueva` (`formularioReal: true` harness param) and a `FakeConsultaRepository(mascotas: repo)` wired to the same `FakeMascotaRepository`, filling Diagnóstico/Tratamiento, expanding details, entering a peso, and tapping "Guardar consulta" returns to the ficha with the new consulta on top of the timeline, the new weight on top of "Historial de peso", and the "Consulta guardada" snackbar visible — no manual refresh anywhere in the flow (both providers were already invalidated correctly by Plan 03-03's `RegistrarConsulta`).

## Task Commits

1. **Task 1: Failing widget tests for the clinical timeline and the register-then-see loop (RED)** - `374fdc9` (test)
2. **Task 2: Shared consulta formatting, HistoriaClinicaTimeline, and ficha wiring (GREEN)** - `6c93812` (feat)

## Files Created/Modified

- Created: `lib/features/clinical_history/domain/formato_consulta.dart`, `lib/features/clinical_history/presentation/widgets/historia_clinica_timeline.dart`
- Modified: `lib/features/patients/presentation/screens/mascota_detail_screen.dart`, `test/mascota_detail_screen_test.dart`, `test/mascota_form_screen_test.dart`

## Decisions Made

- Kept the timeline strictly feature-local under `lib/features/clinical_history/presentation/widgets/` — nothing new added to `lib/core/widgets/`, matching the plan's explicit boundary since no other feature needs a "consulta card."
- The collapsed diagnostico summary line is never hidden when a card expands (matches the UI-SPEC's "repeated here in full" wording for the Diagnóstico block), so tests that need a single match after expansion use `.first` rather than assuming the text is unique.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug in RED-authored test] Over-broad 'Sin registrar' count assertion**
- **Found during:** Task 2, first `flutter test` run after implementing the widget
- **Issue:** The Control-general expand test asserted exactly 2 unscoped `find.text('Sin registrar')` matches, but `mascotaRocky` (used by this test) has no `fechaNacimiento`, so the ficha's own "Fecha de nacimiento" row also renders "Sin registrar" — 3 matches total, not 2.
- **Fix:** Scoped both the `'Examen físico: Sin registrar'` and the `'Sin registrar'` count assertions to `find.descendant(of: find.byType(HistoriaClinicaTimeline), ...)`, isolating the check to the timeline the plan is actually verifying.
- **Files modified:** `test/mascota_detail_screen_test.dart`
- **Commit:** `6c93812`

None else. Both tasks otherwise executed exactly as written.

## Issues Encountered

None beyond the test-scoping fix documented above.

## User Setup Required

None.

## Next Phase Readiness

- Plan 03-05 (PDF export) can import `lineasExamenFisico`/`formatearTemperatura` directly from `lib/features/clinical_history/domain/formato_consulta.dart` so the exported PDF and the on-screen timeline render identical vital-sign lines and empty-value copy.
- Plan 03-05/03-06 can add the "Exportar PDF" `AppTopBar` action without touching `HistoriaClinicaTimeline` or `MascotaDetailScreen`'s body beyond the app bar's `actions` list.
- No blockers. This plan ran entirely against `FakeConsultaRepository`/`FakeMascotaRepository`; it does not depend on live Supabase data.

## Self-Check

- `HistoriaClinicaTimeline` sorts defensively by `fecha` descending: CONFIRMED via grep (`b.fecha.compareTo(a.fecha)`)
- No `Icons.edit`/`Icons.delete`/`IconButton`/`onLongPress`/`Dismissible` in the timeline file: CONFIRMED via grep (`NOEDIT_OK`)
- `HistoriaClinicaTimeline(` wired into `mascota_detail_screen.dart`: CONFIRMED via grep (`WIRED_OK`)
- `lib/features/clinical_history/domain/formato_consulta.dart` exists: CONFIRMED
- `lib/features/clinical_history/presentation/widgets/historia_clinica_timeline.dart` exists: CONFIRMED
- Commit `374fdc9` (Task 1): FOUND in `git log --oneline`
- Commit `6c93812` (Task 2): FOUND in `git log --oneline`
- `flutter analyze`: No issues found
- `flutter test`: 142/142 passing
- Working tree clean for all plan files after these commits: CONFIRMED via `git status --short` (only unrelated pre-existing local/generated-file diffs remain untouched)

## Self-Check: PASSED

---
*Phase: 03-historia-cl-nica*
*Completed: 2026-09-28*
