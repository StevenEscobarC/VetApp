# Phase 8 — Brand baseline (DASH-04)

**Auditor:** vetapp-brand-ui (read-only), 2026-11-16 · 145 files in `lib/features/*/presentation/**` + `lib/core/widgets/**`.
**Verdict:** PASS with observations — **0 BLOCKER, 24 WARN** (27 if counted per row).

## Clean (0 hits)
`Color(0x` outside theme · `Colors.*` (only transparent) · `fontSize`/`fontFamily`/`GoogleFonts` in UI (only PdfGoogleFonts in PDF providers) · `DateFormat`/ISO dates shown to the user · `toStringAsFixed`/USD/NumberFormat (money via `formatearCop`) · raw `TextField`/`Chip`/`AppBar` · English/"Próximamente" copy · all 12 `IconButton` have tooltip/Semantics.

## Cross-cutting
1. ~35 `TextButton`, 2 `OutlinedButton`, 3 `FloatingActionButton.extended` instead of `AppButton` (variant text exists).
2. `app_theme.dart` lacks `switchTheme`, `checkboxTheme`, `floatingActionButtonTheme`, `snackBarTheme`, `dialogTheme`, `datePickerTheme`, `bottomSheetTheme` → root cause of the Switch/Checkbox/FAB/date picker WARN (looks like generic M3).
3. Magic spacing 2/6/12/20/4 instead of `AppSpacing` (xs4 sm8 md16 lg24 xl32, radiusSm8 radiusMd12 radiusLg16, touchTarget48).

## Per feature (BLOCKER/WARN/INFO)
auth 0/4/1 · home 0/0/1 · patients 0/0/2 · clients 0/1/0 · clinical_history 0/0/1 · appointments 0/9/3 · vaccination 0/2/2 · team 0/1/0 · clinic 0/0/0 · plan 0/2/0 · inventory 0/3/2 · billing 0/3/2 · core 0/2/2

### auth
- WARN `auth/presentation/screens/client_home_screen.dart:26,32,34,36` literal EdgeInsets/SizedBox → AppSpacing.
- WARN `client_home_screen.dart:~31,~38` "Agregar mascota"/"Agendar cita" with `onPressed: () {}` (dead CTAs) → remove or disable until SCALE-01.
- WARN `login_screen.dart:62,81` SizedBox 16/12; `TextButton` 71,83 → AppSpacing; AppButton text.
- WARN `reset_password_screen.dart:64` SizedBox(20) → md/lg.
- INFO `auth_scaffold.dart:57,61` loose TextStyle → textTheme copyWith.
### home
- INFO `home/presentation/screens/coming_soon_screen.dart` dead class → delete (D-17).
### patients
- INFO `pacientes_list_screen.dart:21` doc mentions ComingSoonScreen; `mascota_detail_screen.dart:192` 24×24 spinner.
### clients
- WARN `clientes_list_screen.dart:87` raw FAB.extended → FAB theme. INFO comment line 16.
### clinical_history
- INFO `historia_clinica_timeline.dart:182` TextStyle in TextSpan.
### appointments
- WARN TextButton: `agenda_screen.dart:504`, `cita_form_screen.dart:833`, `recordatorios_screen.dart:75`, `cita_acciones.dart:95,99,100,178` (destructive styleFrom), `notificaciones_banner.dart:49` (minimumSize 48 literal), `permiso_notificaciones.dart:39`.
- WARN `time_stepper.dart:140` OutlinedButton → AppButton outline compact.
- WARN `day_strip.dart:96,120,124,142` literal spacing; `day_strip.dart:102` minWidth 44 < 48dp.
- WARN `cita_form_screen.dart:647` Switch, `mascota_multi_select.dart:48` Checkbox → theme.
- INFO repeated `yyyy-MM-dd` route helper (agenda_screen 392, cita_form 434, completar_cita 83); `agenda_screen.dart:597` height 14; `cita_form_screen.dart:267` showDatePicker → datePickerTheme.
### vaccination
- WARN `registrar_dosis_screen.dart:460,507,515` SwitchListTile → switchTheme.
- WARN `dosis_card.dart:122` EdgeInsets 12, `carne_resumen_section.dart:61` SizedBox 32 → tokens.
- INFO `dosis_card.dart:306` TextStyle.
### team
- WARN TextButton: `equipo_screen.dart:47,51`, `invitacion_card.dart:65`, `miembro_acciones_sheet.dart:120,132`.
### plan
- WARN `plan_banner.dart:89` TextButton with Size(48) literal; `uso_contador_tile.dart:54` BorderRadius 4.
### inventory
- WARN `inventario_screen.dart:127` FAB; TextButton `producto_detail_screen.dart:436,502`, `ajuste_stock.dart:195`, `resumen_bajos_strip.dart:50`; `ajuste_rapido_botones.dart:145` OutlinedButton.
- INFO `ajuste_rapido_botones.dart:206` swallowing GestureDetector (comment it).
### billing
- WARN FAB `cobros_screen.dart:174`, `servicios_screen.dart:115`; ~12 TextButton in `cobro_form_screen.dart:533,652,726,999,1004`, `anular_cobro_sheet.dart:167`, `marcar_pagada_sheet.dart:164,189`, `producto_cobro_sheet.dart:108`, `servicio_sheet.dart:138,142,232`; `linea_cobro_tile.dart:242` SizedBox 6.
### core
- WARN `app_status_chip.dart:51,61`, `app_text_field.dart:70`, `app_button.dart:52` literal 6/8.
- WARN `core/theme/app_theme.dart:53-150` missing component themes (see cross-cutting 2).

## Suggested fix order
1. Component themes in `app_theme.dart` (fixes Switch/Checkbox/FAB/dialog/date picker at once).
2. `TextButton`/`OutlinedButton` → `AppButton` (needs a destructive variant).
3. Spacing tokens.
4. Delete `coming_soon_screen.dart`.
5. `day_strip` minWidth 44; dead CTAs in `client_home_screen.dart`.

BRAND-BASELINE: 0 blockers, 24 warn
