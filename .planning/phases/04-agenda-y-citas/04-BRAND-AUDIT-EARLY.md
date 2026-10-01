# Phase 4 — Early brand-ui audit (vetapp-brand-ui, 2026-10-01)

Scope: screens built in 04-03..04-06 (+ 04-04 client/patient changes), audited mid-phase while 04-08 was running.
Verdict: **PASS CON OBSERVACIONES** — 0 Alta, 7 Media, 8 Baja. Input for plan 04-11 Task (brand-ui audit + fixes): re-check these after 04-08/09/10 land; line numbers may have shifted.

## Media
1. `cita_form_screen.dart` overlap dialog uses raw `TextButton`/`ElevatedButton` → "Agendar igual" stretches full width. Use `AppButton(variant: text, expand: false)` / `AppButton(expand: false)`.
2. Raw `TextButton`/`TextButton.icon` ("Volver", destructive "Cancelar cita", "Cambiar", "Hoy") in `cita_acciones.dart`, `cita_detail_screen.dart`, `cita_form_screen.dart`, `agenda_screen.dart` → 44dp vs 48dp spec. Use `AppButton(variant: text)`; consider `AppButtonVariant.destructive` (styleFrom repeated in 3 places).
3. Phone warning text in `cliente_detail_screen.dart` / `nuevo_cliente_mascota_screen.dart` is `warning` (#D97706) on cream without icon (~2.7:1). Add `Icons.warning_amber_outlined` in warning; text in primaryText/textSecondary.
4. "Se cruza con X" in `cita_card.dart`: keep icon warning, text primaryText.
5. Day number (`day_strip.dart`) and week range (`agenda_screen.dart`) use `titleMedium` (Figtree); spec = Heading Caprasimo 20 → `headlineSmall`/`titleLarge`.
6. `day_strip.dart` `FontWeight.w700` breaks 400/600 rule.
7. `labelMedium` renders 12px; spec Label = 14/600 (agenda hour marker, count, cruce, "Recordatorio enviado", time_stepper). Use `labelLarge` or set fontSize 14 in `app_typography.dart`; verify 64px gutter at 360dp.

## Baja
8. `day_strip.dart` `labelSmall` 11px for LUN + count pill; literal `BorderRadius.circular(8)` → `AppSpacing.radiusSm`.
9. `time_stepper.dart` redundant `copyWith(fontSize: 28)`.
10. `time_stepper.dart` raw `OutlinedButton` 64x64 — acceptable.
11. `cita_form_screen.dart` date row plain `InkWell` → `AppCard(onTap:)` h48.
12. "Marcar como pendiente" in Más acciones not in UI-SPEC — intentional (plan-checker fix for AGND-03); keep, update UI-SPEC note.
13. No `snackBarTheme`/`dialogTheme`/`bottomSheetTheme` in `app_theme.dart` — cross-cutting, defer to Phase 8 unless trivial.
14. `cita_detail_screen.dart` mascota rows lack `Semantics(button: true, label: 'Ver a …')`.
15. `_yyyyMmDd` duplicated in `agenda_screen.dart` and `cita_form_screen.dart` → move to `formato_hora.dart`/`zona_bogota.dart`.
