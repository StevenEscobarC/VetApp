---
phase: quick-261001-lg6
plan: 01
subsystem: appointments
tags: [whatsapp, url_launcher, VET-25]
requirements: [VET-25]
key-files:
  modified:
    - lib/core/utils/lanzador_externo.dart
    - lib/features/appointments/presentation/widgets/cita_acciones.dart
    - lib/features/appointments/presentation/widgets/recordar_manana_sheet.dart
    - test/helpers/fake_url_launcher.dart
    - test/whatsapp_acciones_test.dart
    - test/recordar_manana_sheet_test.dart
metrics:
  completed: 2026-10-01
---

# Quick 261001-lg6: WhatsApp sin app instalada ya no marca el recordatorio (VET-25)

`LanzadorExterno.abrirEnApp` (LaunchMode.externalNonBrowserApplication) now backs both WhatsApp entry points, so a wa.me link that would only open in Chrome returns false, shows "No pudimos abrir WhatsApp. ¿Está instalado?" and does not mark the cita as "Recordatorio enviado".

## Commits
- RED: test(quick-261001-lg6) - abrirEnApp added, fake extended (`resultadoApp`, `metodos`), new tests failing for the right reason
- GREEN: fix(quick-261001-lg6) - cita_acciones.dart and recordar_manana_sheet.dart call `abrirEnApp(whatsappUri...)`; Maps still uses `abrir`
(hashes: see `git log`, last two commits)

## Plugin source finding / manifest decision
url_launcher_android 6.3.30 `UrlLauncher.launchUrl` adds `FLAG_ACTIVITY_REQUIRE_NON_BROWSER` when requested and SDK >= R (30), then calls `activity.startActivity` directly, returning false on `ActivityNotFoundException`. The `resolveActivity` pre-check exists only in `canLaunchUrl`, which we do not use. startActivity is not filtered by package visibility, so AndroidManifest.xml was NOT modified.

## Caveat
On Android < 11 the flag is ignored, so the browser may still open and the reminder may still be marked. Manual emulator re-test of QA C5/C6 (Android 11+, no WhatsApp) is still pending.

## Deviations
None. `flutter analyze`: no issues; full `flutter test`: 366 passed.
