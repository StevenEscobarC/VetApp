---
phase: 8
slug: dashboard-y-dise-o-visual
status: automated-complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-11-17
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (SDK) + fakes a mano en `test/helpers/` + `MockClient` de `package:http/testing.dart` (patrón de `supabase_cobros_repository_test.dart`) + `supabase/tests/rls_smoke_test.sql` (bloque `do $$` que termina en `RAISE EXCEPTION`) + `supabase/tests/verify_live_schema.sh` + `tool/dash04_gates.sh` |
| **Config file** | `analysis_options.yaml` (flutter_lints); el smoke se pega en el SQL Editor |
| **Quick run command** | `flutter analyze && flutter test test/<archivos del plan>` |
| **Full suite command** | `flutter analyze && flutter test`, más el smoke completo pegado por el usuario (**301 checks**: 293 + T33..T40) y `bash supabase/tests/verify_live_schema.sh` (`LIVE_SCHEMA_OK`), y `bash tool/dash04_gates.sh lib` (`DASH04_GATES: PASS`) |
| **Estimated runtime** | ~45 segundos (`flutter test`) |

---

## Sampling Rate

- **After every task commit:** `flutter analyze` + los `flutter test` de los archivos de la tarea; en tareas SQL, las compuertas grep del bloque Fase 8; en tareas de barrido, `bash tool/dash04_gates.sh <archivos del plan>`.
- **After every plan wave:** `flutter test` completo + compuertas DASH-04:
  - `grep -rn "ComingSoon\|Próximamente" lib test --include=*.dart | grep -v test/core_tokens_test.dart` vacío (desde la ola 1);
  - `grep -rni "factur" lib --include=*.dart | grep -v "const String kOrigenCobro = 'factura';"` vacío;
  - `bash tool/dash04_gates.sh` sobre los archivos de cada plan de la ola (sobre `lib` completo solo en 08-13).
- **Before `/gsd:verify-work`:** suite verde, analyze limpio, smoke `PASS (301 checks)` pegado por el usuario, `LIVE_SCHEMA_OK`, `DASH04_GATES: PASS` sobre `lib`, QA en emulador (`vetapp-qa`) en modo claro y oscuro.
- **Max feedback latency:** 60 segundos.

---

## Wave Structure

| Wave | Plans | Notes |
|------|-------|-------|
| 1 | 08-01 (backend SQL), 08-02 (core: temas, AppButton, ComingSoon, gate script), 08-03 (datos de Inicio), 08-15 (`mostrarSiVacia` + `avisoPlanVisibleProvider`) | sin archivos en común |
| 2 | 08-04 (aplicar en vivo, checkpoint), 08-05 (invalidación), 08-06 (Inicio: encabezado + métricas), 08-07 (barrido agenda), 08-08 (barrido cobros), 08-09 (barrido inventario + plan), 08-10 (barrido equipo + vacunación), 08-11 (barrido auth + main), 08-14 (override de Inicio en los harness del router real) | sin archivos en común; los barridos dependen de 08-02 |
| 3 | 08-12 (Inicio: accesos rápidos + próximas citas) | después de 08-06, 08-09 (plan_banner.dart), 08-14 y 08-15 |
| 4 | 08-13 (cierre automático: gate, compuertas, re-auditoría, Linear, revisión, docs) | autónomo |
| 5 | 08-16 (QA en emulador, estado de solo lectura en producción, aprobación) | checkpoints |

Each executor runs its plan in its own git worktree and its task verifies only run the plan's own test files plus `flutter analyze`; the orchestrator runs the full suite after each wave merge.

------|-------|-------|
| 1 | 08-01 (backend SQL), 08-02 (core: temas, AppButton, ComingSoon, gate script), 08-03 (datos de Inicio) | sin archivos en común |
| 2 | 08-04 (aplicar en vivo, checkpoint), 08-05 (invalidación), 08-06 (Inicio: encabezado + métricas), 08-07 (barrido agenda), 08-08 (barrido cobros), 08-09 (barrido inventario + plan), 08-10 (barrido equipo + vacunación), 08-11 (barrido auth + main) | sin archivos en común; los barridos dependen de 08-02 |
| 3 | 08-12 (Inicio: accesos rápidos + próximas citas) | después de 08-06 y 08-09 (plan_banner.dart) |
| 4 | 08-13 (cierre: gates, re-auditoría, revisión, QA, sign-off) | checkpoint |

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Behavior | Test Type | Automated Command / Marker | File Exists | Status |
|---------|------|------|-------------|----------|-----------|----------------------------|-------------|--------|
| 08-01-01 | 01 | 1 | DASH-01 | Smoke T33..T40 (mes Bogotá con borde 00:00, aislamiento, paridad de ingresos con `cobros_resumen`, pacientes nuevos, ceros, privilegios, colega solo lectura), total 301 | SQL smoke (estático) | grep gate -> `SMOKE_F8_OK` | ❌ W0 (bloque nuevo) | ✅ `SMOKE_F8_OK` |
| 08-01-02 | 01 | 1 | DASH-01 | `inicio_resumen()` definer + guarda + join por mascotas + límites timestamptz + predicado de cobros | grep gate | `SCHEMA_F8_OK` | ✅ schema.sql | ✅ `SCHEMA_F8_OK` |
| 08-01-03 | 01 | 1 | DASH-01 | probe anon conoce `inicio_resumen` | grep + `bash -n` | `PROBE_F8_OK` | ✅ | ✅ `PROBE_F8_OK` |
| 08-02-01 | 02 | 1 | DASH-04 | 7 temas de componente + botón de texto AA + deshabilitado de outlined, claro y oscuro | unit | `flutter test test/app_theme_test.dart` -> `THEME_OK` | ✅ ampliar | ✅ `THEME_OK` |
| 08-02-02 | 02 | 1 | DASH-04 | sin literales de espaciado en core; AppButton modo cuadrado; sin ComingSoon/"Próximamente" | unit + widget | `flutter test test/core_tokens_test.dart test/app_button_test.dart ...` -> `CORE_TOKENS_OK` | ❌ W0 | ✅ `CORE_TOKENS_OK` |
| 08-02-03 | 02 | 1 | DASH-04 | script de compuertas DASH-04 con exenciones y autoprueba | script self-test | `bash tool/dash04_gates.sh --selftest` -> `GATES_SCRIPT_OK` | ❌ W0 (script) | ✅ `GATES_SCRIPT_OK`, `DASH04_SELFTEST_OK` |
| 08-03-01 | 03 | 1 | DASH-01 | `formatearCopCorto` (0 · 85.000 · 950.000 · 999.999 · 1 M · 3 M · 3,8 M · 3.849.999 · 3.960.000 · 12,3 M · 12,5 M · 999,9 M · 1.000 M · 1.250 M · negativo) | unit | `flutter test test/formato_test.dart` -> `COP_CORTO_OK` | ✅ ampliar | ✅ `COP_CORTO_OK` |
| 08-03-02 | 03 | 1 | DASH-01 | repositorio Inicio: ruta RPC, mapeo, sin conexión, genérico; contador | unit (MockClient) | `flutter test test/supabase_inicio_repository_test.dart` -> `INICIO_REPO_OK` | ❌ W0 | ✅ `INICIO_REPO_OK` |
| 08-03-03 | 03 | 1 | DASH-01, DASH-02 | `proximas()` forma de la petición (`estado=in.(pendiente,confirmada)`, `gte`, orden, `limit=5`); relanza errores de red (SocketException -> `InicioFailure(kMensajeSinConexionLectura, sinConexion: true)`); fake; providers recargan con contador, citas y reanudación | unit (MockClient) + provider | `flutter test test/supabase_cita_repository_test.dart test/inicio_providers_test.dart` -> `INICIO_DATA_OK` | ✅ ampliar / ❌ W0 | ✅ `INICIO_DATA_OK` |
| 08-04-01 | 04 | 2 | DASH-01 | revisión estática del delta | grep gate | `PREAPPLY_F8_OK` | ✅ | ✅ `PREAPPLY_F8_OK` |
| 08-04-02 | 04 | 2 | DASH-01 | delta aplicado (MCP o pegado) + smoke completo | manual (checkpoint) + static | `SMOKE_301_READY`; línea literal `RLS SMOKE: PASS (301 checks) - cambios revertidos` del usuario | ✅ | ✅ `RLS SMOKE: PASS (301 checks) - cambios revertidos` (pasted by the user, 08-04-SUMMARY) |
| 08-04-03 | 04 | 2 | DASH-01 | probe en vivo | live script | `bash supabase/tests/verify_live_schema.sh` -> `LIVE_F8_OK` | ✅ | ✅ `OK rpc inicio_resumen protegido 401`, `LIVE_SCHEMA_OK` (08-04; re-run in 08-13) |
| 08-05-01 | 05 | 2 | DASH-01, DASH-02 | contador sube tras citas (éxito y fallo), consulta y cobros; recordatorio no | unit | `flutter test test/inicio_invalidacion_test.dart ...` -> `INVALIDACION_PROVIDERS_OK` | ❌ W0 | ✅ `INVALIDACION_PROVIDERS_OK` |
| 08-05-02 | 05 | 2 | DASH-01 | contador sube tras alta de mascota y de cliente+mascota y al volver a la pestaña Inicio | widget | `flutter test test/mascota_form_screen_test.dart test/nuevo_cliente_mascota_screen_test.dart test/plan_refresco_test.dart` -> `INVALIDACION_PANTALLAS_OK` | ✅ ampliar | ✅ `INVALIDACION_PANTALLAS_OK` |
| 08-06-01 | 06 | 2 | DASH-01 | encabezado, 3 métricas (cifras, abreviado, semántica, taps, 48 dp, apilado, oscuro), esqueleto y BloqueError (sin conexión) | widget | `flutter test test/metricas_mes_test.dart` -> `METRICAS_OK` | ❌ W0 | ✅ `METRICAS_OK` |
| 08-06-02 | 06 | 2 | DASH-01 | Inicio reescrito: orden D-12, hueco del banner, alertas ocultas en 0, pull-to-refresh, reanudación, aislamiento por bloque, error de perfil | widget | `flutter test test/inicio_screen_test.dart test/metricas_mes_test.dart test/widget_test.dart` -> `INICIO_SLICE1_OK` | ✅ ampliar | ✅ `INICIO_SLICE1_OK` |
| 08-07-01 | 07 | 2 | DASH-04 | botones de agenda a AppButton (diálogos `expand: false`, destructivo) | source guard + widget | `flutter test test/barrido_agenda_test.dart ...` -> `AGENDA_BOTONES_OK` | ❌ W0 | ✅ `AGENDA_BOTONES_OK` |
| 08-07-02 | 07 | 2 | DASH-04 | DayStrip >= 48 dp a 360 dp; tokens | widget + gate | `flutter test test/barrido_agenda_test.dart` + gate -> `AGENDA_BARRIDO_OK` | ❌ W0 | ✅ `AGENDA_BARRIDO_OK` |
| 08-08-01 | 08 | 2 | DASH-04 | formulario de cobro a AppButton; espaciado de línea | source guard + widget | `flutter test test/cobro_form_screen_test.dart` + grupo `formulario` + gate -> `COBRO_FORM_BARRIDO_OK` | ❌ W0 | ✅ `COBRO_FORM_BARRIDO_OK` |
| 08-08-02 | 08 | 2 | DASH-04 | hojas de cobro a AppButton; sin "Factura" | source guard + widget | `flutter test test/barrido_cobros_test.dart ...` + gate -> `COBROS_BARRIDO_OK` | ❌ W0 | ✅ `COBROS_BARRIDO_OK` |
| 08-09-01 | 09 | 2 | DASH-04 | inventario: botones, ajuste rápido cuadrado con `botonKey`, insignia Label 14/600, cabecera visible al cargar (VET-57) | source guard + widget | `flutter test test/barrido_inventario_plan_test.dart --plain-name inventario ...` -> `INVENTARIO_BARRIDO_OK` | ❌ W0 | ✅ `INVENTARIO_BARRIDO_OK` |
| 08-09-02 | 09 | 2 | DASH-04 | plan: botón del banner, radio de la barra de uso | widget + gate | `flutter test test/barrido_inventario_plan_test.dart test/plan_banner_test.dart test/mi_plan_screen_test.dart` + gate -> `PLAN_BARRIDO_OK` | ❌ W0 | ✅ `PLAN_BARRIDO_OK` |
| 08-10-01 | 10 | 2 | DASH-04 | diálogos de equipo a AppButton | source guard + widget | `flutter test test/barrido_equipo_vacunas_test.dart --plain-name equipo ...` -> `EQUIPO_BARRIDO_OK` | ❌ W0 | ✅ `EQUIPO_BARRIDO_OK` |
| 08-10-02 | 10 | 2 | DASH-04 | vacunación: tokens, menú >= 48 dp, "(retirado)" legible en oscuro | widget + gate | `flutter test test/barrido_equipo_vacunas_test.dart test/mascota_detail_screen_test.dart` + gate -> `VACUNAS_BARRIDO_OK` | ❌ W0 | ✅ `VACUNAS_BARRIDO_OK` |
| 08-11-01 | 11 | 2 | DASH-04 | login/reset/auth_scaffold: AppButton, tokens, estilos del tema | source guard + widget | `flutter test test/barrido_auth_test.dart --plain-name login test/widget_test.dart test/register_screen_test.dart` -> `AUTH_LOGIN_OK` | ❌ W0 | ✅ `AUTH_LOGIN_OK` |
| 08-11-02 | 11 | 2 | DASH-04 | ClientHome sin CTAs muertos (D-19); main.dart con tokens | widget + gate | `flutter test test/barrido_auth_test.dart` + gate -> `AUTH_BARRIDO_OK` | ❌ W0 | ✅ `AUTH_BARRIDO_OK` |
| 08-12-01 | 12 | 3 | DASH-03 | 4 accesos (orden, nunca "Factura", 48 dp, rutas, tope de pacientes, candado + hoja del plan, 2x2 con texto grande); PlanBanner con el provider compartido | widget | `flutter test test/accesos_rapidos_test.dart test/plan_banner_test.dart` -> `ACCESOS_OK` | ❌ W0 | ✅ `ACCESOS_OK` |
| 08-12-02 | 12 | 3 | DASH-02 | separadores Hoy/Mañana/día con reloj fijo; fila, semántica, `go` al detalle; "Ver agenda"; VetAvatar solo multi-vet; vacío + "Agendar cita" (candado); esqueleto; error | widget | `flutter test test/proximas_citas_test.dart` -> `PROXIMAS_OK` | ❌ W0 | ✅ `PROXIMAS_OK` |
| 08-12-03 | 12 | 3 | DASH-01..03 | Inicio completo en orden D-12, sin Vacunar suelto, aislamiento en ambos sentidos, router real sin assert y "atrás" vuelve a Inicio | widget + router | `flutter test test/inicio_screen_test.dart test/router_inicio_cross_shell_test.dart ...` + gate -> `INICIO_COMPLETO_OK` | ✅ ampliar / ❌ W0 | ✅ `INICIO_COMPLETO_OK` |
| 08-13-01 | 13 | 4 | DASH-01..04 | suite completa, probe, APK, `DASH04_GATES: PASS` sobre lib, vocabulario, ciclo de imports | integrated | `PHASE8_GATE_OK` | ✅ | ✅ `PHASE8_GATE_OK` |
| 08-13-02 | 13 | 4 | DASH-04 | re-auditoría `vetapp-brand-ui`, cierre W-01..W-30, INFO en Linear | audit report check | `BRAND_AUDIT_OK` | ❌ (reporte) | ✅ `BRAND_AUDIT_OK` |
| 08-13-03 | 13 | 4 | DASH-01..04 | code review, docs de dominio, VALIDATION | report check | `REVIEW_DOCS_OK` | ❌ (reporte) | ✅ `REVIEW_DOCS_OK` (leak grep run with `--exclude=08-13-PLAN.md`: the plan's own threat row names the patterns) |
| 08-14-01 | 14 | 2 | DASH-01 | helper `inicioShellOverrides()` y `appUnderTest` | widget | `flutter test test/harness_inicio_test.dart --plain-name appUnderTest` -> `HARNESS_HELPER_OK` | ❌ W0 | ✅ `HARNESS_HELPER_OK` |
| 08-14-02 | 14 | 2 | DASH-01 | tests del router real (incluido `servicios_screen_test`) usan el helper | widget + source guard | `flutter test test/harness_inicio_test.dart test/router_*_cross_shell_test.dart test/servicios_screen_test.dart test/router_equipo_test.dart` -> `HARNESS_ROUTER_OK` | ✅ ampliar | ✅ `HARNESS_ROUTER_OK` |
| 08-15-01 | 15 | 1 | DASH-01 | `VacunasPendientesCard(mostrarSiVacia:)` ambos valores | widget | `flutter test test/vacunas_pendientes_card_test.dart test/vacunas_pendientes_screen_test.dart` -> `MOSTRAR_SI_VACIA_OK` | ❌ W0 | ✅ `MOSTRAR_SI_VACIA_OK` |
| 08-15-02 | 15 | 1 | DASH-01 | `avisoPlanVisibleProvider` = criterio de PlanBanner | provider | `flutter test test/aviso_plan_visible_provider_test.dart test/plan_banner_test.dart` -> `AVISO_VISIBLE_OK` | ❌ W0 | ✅ `AVISO_VISIBLE_OK` |
| 08-16-01 | 16 | 5 | DASH-01..04 | QA F1..F7, F9, F10 en claro y oscuro | manual (vetapp-qa) + report check | `QA_F1_F10_OK` | ❌ (reporte) | ⬜ |
| 08-16-02 | 16 | 5 | DASH-01, DASH-03 | estado de solo lectura en la clínica QA (escritura en producción, checkpoint), F8, restauración | checkpoint + report check | `QA_REPORT_OK` y `QA: PASS` | ✅ | ⬜ |
| 08-16-03 | 16 | 5 | DASH-01..04 | aprobación del usuario | checkpoint | `SIGNOFF_RECORDED` (grep `**Approval:** approved`) | ✅ | ⬜ |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

Every task has an automated verify (checkpoints included), and no three consecutive tasks lack one.

---

## BRAND-BASELINE WARN Ownership (D-16)

Every WARN of `08-BRAND-BASELINE.md` (24 counted by feature, 27 per row) plus the carried VET-57 / VET-78 WARNs has exactly one owner plan. 08-13 re-audits and fills the Status column.

| ID | Feature | Finding (BRAND-BASELINE) | Owner | Status |
|----|---------|--------------------------|-------|--------|
| W-01 | auth | `client_home_screen.dart:26,32,34,36` literal spacing | 08-11 | ✅ closed (08-BRAND-AUDIT.md) |
| W-02 | auth | `client_home_screen.dart` dead CTAs `onPressed: () {}` | 08-11 (removed, D-19) | ✅ closed (08-BRAND-AUDIT.md) |
| W-03 | auth | `login_screen.dart:62,81` SizedBox 16/12; TextButton 71,83 | 08-11 | ✅ closed (08-BRAND-AUDIT.md) |
| W-04 | auth | `reset_password_screen.dart:64` SizedBox(20) | 08-11 | ✅ closed (08-BRAND-AUDIT.md) |
| W-05 | clients | `clientes_list_screen.dart:87` raw FAB.extended | 08-02 (FAB theme) | ✅ closed (08-BRAND-AUDIT.md) |
| W-06 | appointments | `agenda_screen.dart:504` TextButton | 08-07 | ✅ closed (08-BRAND-AUDIT.md) |
| W-07 | appointments | `cita_form_screen.dart:833` TextButton | 08-07 | ✅ closed (08-BRAND-AUDIT.md) |
| W-08 | appointments | `recordatorios_screen.dart:75` TextButton | 08-07 | ✅ closed (08-BRAND-AUDIT.md) |
| W-09 | appointments | `cita_acciones.dart:95,99,100,178` TextButtons + destructive styleFrom | 08-07 | ✅ closed (08-BRAND-AUDIT.md) |
| W-10 | appointments | `notificaciones_banner.dart:49` (Size 48 literal), `permiso_notificaciones.dart:39` | 08-07 | ✅ closed (08-BRAND-AUDIT.md) |
| W-11 | appointments | `time_stepper.dart:140` OutlinedButton | 08-07 (AppButton square, 08-02) | ✅ closed (08-BRAND-AUDIT.md) |
| W-12 | appointments | `day_strip.dart:96,120,124,142` literal spacing | 08-07 | ✅ closed (08-BRAND-AUDIT.md) |
| W-13 | appointments | `day_strip.dart:102` minWidth 44 < 48 dp | 08-07 | ✅ closed (08-BRAND-AUDIT.md) |
| W-14 | appointments | `cita_form_screen.dart:647` Switch, `mascota_multi_select.dart:48` Checkbox | 08-02 (switch/checkbox themes; no file edit) | ✅ closed (08-BRAND-AUDIT.md) |
| W-15 | vaccination | `registrar_dosis_screen.dart:460,507,515` SwitchListTile | 08-02 (switch theme) | ✅ closed (08-BRAND-AUDIT.md) |
| W-16 | vaccination | `dosis_card.dart:122` EdgeInsets 12, `carne_resumen_section.dart:61` SizedBox 32 | 08-10 | ✅ closed (08-BRAND-AUDIT.md) |
| W-17 | team | TextButtons `equipo_screen.dart:47,51`, `invitacion_card.dart:65`, `miembro_acciones_sheet.dart:120,132` | 08-10 | ✅ closed (08-BRAND-AUDIT.md) |
| W-18 | plan | `plan_banner.dart:89` TextButton with Size(48) literal | 08-09 | ✅ closed (08-BRAND-AUDIT.md) |
| W-19 | plan | `uso_contador_tile.dart:54` BorderRadius 4 | 08-09 | ✅ closed (08-BRAND-AUDIT.md) |
| W-20 | inventory | `inventario_screen.dart:127` FAB | 08-02 (FAB theme) | ✅ closed (08-BRAND-AUDIT.md) |
| W-21 | inventory | TextButtons `producto_detail_screen.dart:436,502`, `ajuste_stock.dart:195`, `resumen_bajos_strip.dart:50` | 08-09 | ✅ closed (08-BRAND-AUDIT.md) |
| W-22 | inventory | `ajuste_rapido_botones.dart:145` OutlinedButton | 08-09 (AppButton square, 08-02) | ✅ closed (08-BRAND-AUDIT.md) |
| W-23 | billing | FABs `cobros_screen.dart:174`, `servicios_screen.dart:115` | 08-02 (FAB theme) | ✅ closed (08-BRAND-AUDIT.md) |
| W-24 | billing | ~12 TextButtons in `cobro_form_screen`, `anular_cobro_sheet`, `marcar_pagada_sheet`, `producto_cobro_sheet`, `servicio_sheet` | 08-08 | ✅ closed (08-BRAND-AUDIT.md) |
| W-25 | billing | `linea_cobro_tile.dart:242` SizedBox 6 | 08-08 | ✅ closed (08-BRAND-AUDIT.md) |
| W-26 | core | `app_status_chip.dart:51,61`, `app_text_field.dart:70`, `app_button.dart:52` literal 6/8 | 08-02 | ✅ closed (08-BRAND-AUDIT.md) |
| W-27 | core | `app_theme.dart` missing component themes | 08-02 | ✅ closed (08-BRAND-AUDIT.md) |
| W-28 | inventory (VET-57) | `insignia_stock.dart:87-90` labelMedium -> Label 14/600 | 08-09 | ✅ closed (08-BRAND-AUDIT.md) |
| W-29 | inventory (VET-57) | `inventario_screen.dart:85-92` header hidden while loading | 08-09 | ✅ closed (08-BRAND-AUDIT.md) |
| W-30 | billing (VET-78) | `cobro_form_screen` / `anular_cobro_sheet` raw TextButtons (Phase 7 audit) | 08-08 (same fix as W-24) | ✅ closed (08-BRAND-AUDIT.md) |
| W-31 | home | `mas_screen.dart:110,137,278` light-only `textSecondary` on the dark card (found by the 08-13 re-audit, SW-07) | 08-13 | ✅ fixed (`c3ca862`) |

INFO (D-16: Linear unless trivial):

| ID | Finding | Owner | Disposition |
|----|---------|-------|-------------|
| I-01 | `auth_scaffold.dart:57,61` loose TextStyle | 08-11 | fixed (trivial) |
| I-02 | `coming_soon_screen.dart` dead class | 08-02 | deleted (D-17) |
| I-03 | `pacientes_list_screen.dart:21` doc mentions ComingSoonScreen | 08-02 | comment fixed |
| I-04 | `mascota_detail_screen.dart:192` 24x24 spinner | 08-13 | allowed size (SW-04), recorded |
| I-05 | `clientes_list_screen.dart:16` comment | 08-02 | comment fixed |
| I-06 | `historia_clinica_timeline.dart:182` TextStyle in TextSpan | 08-13 | pendiente de Linear |
| I-07 | repeated `yyyy-MM-dd` route helper (agenda 392, cita_form 434, completar_cita 83) | 08-13 | pendiente de Linear |
| I-08 | `agenda_screen.dart:597` height 14 | 08-07 | skeleton bar, allowed literal, recorded |
| I-09 | `cita_form_screen.dart:267` showDatePicker | 08-02 | datePickerTheme |
| I-10 | `dosis_card.dart:306` TextStyle | 08-10 | fixed (trivial, dark-safe) |
| I-11 | `ajuste_rapido_botones.dart:206` swallowing GestureDetector | 08-09 | comment verified |
| I-xx | INFO not itemized in the baseline (billing x2, core x2, others) | 08-13 re-audit | I-12 (dark contrast, pre-existing screens), I-13 (`linea_cobro_tile` Quitar), I-14 (`esErrorDeRed` to core): pendiente de Linear |

---

## Wave 0 Requirements

- [x] `test/supabase_inicio_repository_test.dart` (08-03)
- [x] `test/inicio_providers_test.dart` (08-03)
- [x] `test/inicio_invalidacion_test.dart` (modelo `cobros_invalidacion_test.dart`, 08-05)
- [x] `test/helpers/fake_inicio.dart` (08-03)
- [x] `test/metricas_mes_test.dart` (08-06)
- [x] `test/vacunas_pendientes_card_test.dart`, `test/aviso_plan_visible_provider_test.dart` (08-15)
- [x] `test/harness_inicio_test.dart` (08-14)
- [x] `test/accesos_rapidos_test.dart`, `test/proximas_citas_test.dart`, `test/router_inicio_cross_shell_test.dart` (08-12)
- [x] `test/core_tokens_test.dart`, `test/app_button_test.dart` (08-02)
- [x] `test/barrido_agenda_test.dart`, `test/barrido_cobros_test.dart`, `test/barrido_inventario_plan_test.dart`, `test/barrido_equipo_vacunas_test.dart`, `test/barrido_auth_test.dart` (08-07..08-11)
- [x] Ampliar `test/formato_test.dart`, `test/inicio_screen_test.dart`, `test/supabase_cita_repository_test.dart`, `test/app_theme_test.dart`
- [x] Bloque T33..T40 en `supabase/tests/rls_smoke_test.sql` + `verify_live_schema.sh` (08-01)
- [x] Script de compuertas `tool/dash04_gates.sh` (08-02)

---

**RLS smoke (08-04, literal):** `RLS SMOKE: PASS (301 checks) - cambios revertidos`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Smoke SQL en vivo | DASH-01 | El SQL Editor lo pega el usuario | 08-04: pegar `rls_smoke_test.sql`; esperar `RLS SMOKE: PASS (301 checks) - cambios revertidos` |
| Aplicar el delta si el MCP se deniega | DASH-01 | Escritura en producción | 08-04: pegar el delta del portapapeles en el SQL Editor |
| Inicio real con datos de clínica de prueba | DASH-01..03 | Datos y navegación reales | 08-16 `vetapp-qa` F1..F8: métricas (ingresos = "Cobrado este mes"), próximas citas, accesos, refresco, sin conexión, solo lectura |
| Apariencia en modo claro y oscuro de todas las pantallas | DASH-04 | Apariencia/contraste | 08-16 `vetapp-qa` F7, F9: capturas en `qa/` por feature, ambos modos |
| Aprobación del usuario | DASH-01..04 | Sign-off | 08-16 Task 3 |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending (08-16)
