---
phase: 04-agenda-y-citas
plan: 08
subsystem: appointments
tags: [flutter, riverpod, whatsapp, url_launcher, agenda]
requires: [04-02, 04-04, 04-06]
provides:
  - whatsapp_recordatorio.dart (mensajeRecordatorio, whatsappUri, mapsUri, estadoWhatsApp)
  - LanzadorExterno / UrlLauncherLanzador / lanzadorExternoProvider
  - enviarRecordatorioWhatsApp, abrirComoLlegar and button helpers in cita_acciones.dart
  - RecordarMananaSheet and the tomorrow button on AgendaScreen
affects: [04-09, 04-11]
key-files:
  created:
    - lib/features/appointments/domain/whatsapp_recordatorio.dart
    - lib/core/utils/lanzador_externo.dart
    - lib/features/appointments/presentation/widgets/recordar_manana_sheet.dart
    - test/helpers/fake_url_launcher.dart
    - test/whatsapp_recordatorio_test.dart
    - test/whatsapp_acciones_test.dart
    - test/recordar_manana_sheet_test.dart
  modified:
    - lib/features/appointments/presentation/widgets/cita_acciones.dart
    - lib/features/appointments/presentation/widgets/cita_card.dart
    - lib/features/appointments/presentation/screens/cita_detail_screen.dart
    - lib/features/appointments/presentation/screens/agenda_screen.dart
key-decisions:
  - "URLs built with Uri.parse + Uri.encodeComponent (never queryParameters) so spaces are %20"
  - "launchUrl called directly (no canLaunchUrl): no Android <queries> needed"
  - "Disabled WhatsApp is Opacity(0.38) but still tappable to explain the reason"
requirements-completed: [AGND-05]
completed: 2026-10-01
---

# Phase 4 Plan 08: WhatsApp reminders and Como llegar Summary

One-tap formal WhatsApp reminders (card, detail and a serial "Recordar a todos los de manana" sheet) plus "Como llegar" to Google Maps, all through an injectable launcher so no test touches the platform.

## Tasks

| Task | Name | Commit |
|------|------|--------|
| 1 | Message, wa.me/Maps builders, phone gating, launcher abstraction | d30c33c |
| 2 | WhatsApp / Como llegar buttons on card and detail | 68bd3a2 |
| 3 | Batch sheet with return detection and agenda button | 80a7f0e |

## Verification

`flutter analyze`: no issues. Full `flutter test`: 314 passed (before the final two-line lint fix; affected suites re-run green).

## Deviations from Plan

**1. [Process] Worktree base corrected** with `git reset --hard 6d470e1` at startup (merge-base differed), after the HEAD assertion passed.

**2. [Rule 1 - Bug-avoidance] Tomorrow button counts only WhatsApp-capable pending citas.** The plan counts all unsent eligible citas; a fixed-line client can never be marked sent, which would leave the button stuck forever. The count and the "Todos los recordatorios enviados" label therefore ignore fixed-line/no-phone citas (the sheet still lists them as "Sin WhatsApp").

**3. [Minor] TDD** tests and implementation committed together per task (no separate RED commits).

**4. [Minor]** Added helper widgets `botonWhatsApp`, `botonComoLlegar`, `avisoWhatsApp`, `mostrarMotivoWhatsApp` to cita_acciones.dart to share the gating UI between card and detail.

## Known Stubs

None.

## Threat Flags

None. T-04-31 mitigated (encodeComponent on all dynamic parts, digits-only phone; tested with '#', '&', accents); T-04-34 mitigated (no location permission or import added).

## Notes

Real WhatsApp/Maps launches and lifecycle return detection on a device are manual checks for 04-11. STATE.md/ROADMAP.md untouched; regenerated platform plugin files not committed.

## Self-Check: PASSED
