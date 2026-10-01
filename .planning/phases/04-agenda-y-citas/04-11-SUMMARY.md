---
phase: 04-agenda-y-citas
plan: 11
status: partial-awaiting-checkpoint
requirements: [AGND-01, AGND-02, AGND-03, AGND-04, AGND-05, AGND-06]
key-files:
  modified:
    - .planning/phases/04-agenda-y-citas/04-VALIDATION.md
    - lib/features/appointments/presentation/screens/agenda_screen.dart
    - lib/features/appointments/presentation/screens/cita_detail_screen.dart
    - lib/features/appointments/presentation/screens/cita_form_screen.dart
    - lib/features/appointments/presentation/widgets/cita_acciones.dart
    - lib/features/appointments/presentation/widgets/cita_card.dart
    - lib/features/appointments/presentation/widgets/day_strip.dart
    - lib/features/appointments/presentation/widgets/recordar_manana_sheet.dart
    - lib/features/appointments/presentation/widgets/time_stepper.dart
---

# Phase 4 Plan 11: Integrated gate, live probe, brand audit - Summary (PARTIAL)

Task 1 complete (commit a36f1ed). Task 2 (device UAT) is a blocking human checkpoint, pending.

## Task 1 results

- `flutter analyze`: no issues. `flutter test`: 344 passed.
- `verify_live_schema.sh`: `OK citas embed`, ends `LIVE_SCHEMA_OK` (repository `_select` unchanged, no relationship fix needed; Assumption A1 confirmed).
- `flutter build apk --debug --dart-define-from-file=dart_define.json`: built OK (build/app/outputs/flutter-apk/app-debug.apk).
- 04-VALIDATION.md: all automated rows green, `nyquist_compliant: true`, `wave_0_complete: true`, sign-off checklist ticked; Manual-Only rows left pending.

## Brand-ui audit re-verification (04-BRAND-AUDIT-EARLY.md)

| # | Sev | Disposition |
|---|-----|-------------|
| 1 | Media | Fixed: overlap dialog uses `AppButton(expand: false)` |
| 2 | Media | Resolved by theme: `textButtonTheme` already enforces 48x48 min size (the 44dp finding no longer applies). Destructive "Cancelar cita" stays a raw TextButton with destructive color (no destructive AppButton variant; `app_button.dart` outside plan files) - note |
| 3 | Media | Deferred: files (`cliente_detail_screen.dart`, `nuevo_cliente_mascota_screen.dart`) are outside this plan's files_modified (Phase 3 screens); add warning icon + primaryText there |
| 4 | Media | Fixed: cruce text in primaryText (icon stays warning) |
| 5 | Media | Fixed: day number and week range use `headlineSmall` (Caprasimo 20) |
| 6 | Media | Fixed: removed `FontWeight.w700` in day_strip |
| 7 | Media | Fixed: `labelMedium` (12px) replaced by `labelLarge` (14/600) in agenda, card, sheet, stepper, detail, acciones; suite still green |
| 8 | Baja | Fixed: day_strip LUN/count use `labelMedium`; radius uses `AppSpacing.radiusSm` |
| 9 | Baja | Fixed: redundant `copyWith(fontSize: 28)` removed |
| 10 | Baja | Accepted (64x64 stepper OutlinedButton) |
| 11 | Baja | Not done: date row InkWell (non-blocking) |
| 12 | Baja | Intentional, kept ("Marcar como pendiente") |
| 13 | Baja | Deferred (snackBar/dialog/bottomSheet theming, Phase 8) |
| 14 | Baja | Fixed: `Semantics(button, 'Ver a <nombre>')` on detail mascota rows |
| 15 | Baja | Deferred: `_yyyyMmDd` duplication; `formato_hora.dart` outside plan files |

Zero blocking findings remain. `dart format` was applied to the touched files (some incidental reformatting).

## Deviations

None from the plan beyond the scoped deferrals above. Regenerated linux/macos/windows plugin files were not committed. `dart_define.json` was copied locally (gitignored), not committed.

## Task 2: Device UAT checklist (pending)

Run: `flutter run -d <dispositivo Android 13+> --dart-define-from-file=dart_define.json`, logueado como veterinario con al menos dos clientes (uno con celular, uno con telefono fijo).

1. Instalacion limpia: crear la primera cita, debe salir '¿Te avisamos antes de tus citas?', 'Activar recordatorios', aviso del SO. Negar dos veces: banner 'Recordatorios desactivados', 'Activar' abre ajustes; permitir, volver, el banner desaparece.
2. Mas > Recordatorios > '15 minutos antes'. Cita en 17 min: llega 'Cita en 15 min'; tocar abre el detalle. Repetir con la app cerrada del todo.
3. Cita en ~20 min, reiniciar el telefono: el recordatorio igual suena; abrir la app, sin duplicados.
4. Cita en ~20 min, cerrar sesion desde Mas: no debe llegar el recordatorio.
5. WhatsApp en cliente con celular: abre el chat con el texto formal (tildes, '—', 'SÍ'); al volver, 'Recordatorio enviado'. Cliente con fijo: boton deshabilitado con explicacion. Sin WhatsApp: 'No pudimos abrir WhatsApp. ¿Está instalado?'.
6. Con 3 citas manana: 'Recordar a todos los de mañana (3)', enviar cada una (al volver marca y avanza); probar 'Marcar como enviado'.
7. Cita a domicilio: 'Cómo llegar' abre Google Maps con la direccion, sin pedir permiso de ubicacion.
8. Zona horaria del telefono en UTC: 'Hoy' y el dia de una cita 11:30 p. m. siguen correctos (Bogota); horas de recordatorio sin cambio. Restaurar zona.
9. Completar cita de 2 mascotas: consulta para una (anamnesis precargada, pastilla 'Cita del …'), omitir la otra, 'Finalizar cita' -> 'Cita completada' + Deshacer; la consulta aparece en la historia clinica.

Resume signal: "approved" o numeros de pasos fallidos con notas.
