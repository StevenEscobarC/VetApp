---
phase: 5
slug: vacunacion-y-desparasitacion
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-10-02
---

# Phase 5 — Validation Strategy

> Per-phase validation contract. Source: `05-RESEARCH.md` §Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (SDK) + fakes en `test/helpers/`; SQL: `supabase/tests/rls_smoke_test.sql` (manual, SQL Editor) |
| **Config file** | `analysis_options.yaml` |
| **Quick run command** | `flutter test <archivos tocados>` + `flutter analyze` |
| **Full suite command** | `flutter analyze && flutter test` (agente `vetapp-gate`) |
| **Estimated runtime** | ~120 seconds |

---

## Sampling Rate

- **After every task commit:** quick command on touched tests
- **After every plan wave:** `flutter analyze && flutter test`
- **Before `/gsd-verify-work`:** suite verde + `RLS SMOKE: PASS` en vivo + `verify_live_schema.sh` → `LIVE_SCHEMA_OK` + página pública verificada en celular
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

To be filled by planner/executor per task. Requirement → test map:

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| VAC-01 | Registrar dosis (biológico+fecha; externa; anular con motivo) | widget + repo fake | `flutter test test/registrar_dosis_screen_test.dart` | ✅ green |
| VAC-01 | RLS/RPC de dosis (aislamiento, append-only, anulación) | SQL smoke | pegar `rls_smoke_test.sql` (bloque Q) | ✅ green |
| VAC-02 | Serie 1/3→refuerzo, duración elegida, ventanas, `es_refuerzo`, reinicio | SQL smoke (`p_hoy` fijo) | `rls_smoke_test.sql` Q | ✅ green |
| VAC-02 | Mapeo Dart de filas calculadas, `fechaDeBd`, etiquetas | unit | `flutter test test/vacuna_mapeo_test.dart` | ✅ green |
| VAC-03 | Tarjeta Inicio, lista Vencidas/Próximas, badges, D-13, descartar/posponer | widget + provider fake | `flutter test test/vacunas_pendientes_screen_test.dart` | ✅ green |
| VAC-03 | WhatsApp recordatorio (marca solo si `abrirEnApp` true) | widget (`FakeLanzadorExterno`) | `flutter test test/whatsapp_vacunas_test.dart` | ✅ green |
| VAC-04 | Enlace: crear/regenerar/desactivar, compartir texto/WhatsApp/PDF | widget + fakes (`fake_compartir`, `fake_pdf`) | `flutter test test/compartir_carne_sheet_test.dart`, `test/carne_pdf_service_test.dart` | ✅ green |
| VAC-04/05 | `carne_publico` solo claves D-15; token viejo inválido; anon/authenticated sin acceso | SQL smoke + sonda | `rls_smoke_test.sql` Q + `bash supabase/tests/verify_live_schema.sh` | ✅ green |
| VAC-05 | Edge Function: token mal formado → 404; válido → JSON mínimo; página renderiza sin cuenta | manual + curl | `curl` documentado en plan; verificación visual en celular | manual-only (justificación: host externo) |
| VAC-04 (D-26/D-27) | Logo de la clínica: bucket privado `clinica-logos` (solo admin escribe, otra clínica no lee), `actualizar_clinica` solo admin, `carne_publico` solo devuelve la ruta | SQL smoke | `rls_smoke_test.sql` Q41..Q48 | ✅ green |
| VAC-04 (D-26/D-27) | Pantalla Datos de la clínica, recorte cuadrado, logo en carné app/PDF/página | widget + unit + node | `flutter test test/datos_clinica_screen_test.dart test/carne_pdf_service_test.dart` + `node --test test/web/carne_logica.test.mjs` | ✅ green |


### Per-task map (planner, 2026-10-02)

| Plan-Task | Wave | Requirement | Automated Command | File Exists? | Status |
|-----------|------|-------------|-------------------|--------------|--------|
| 05-01-T1 | 1 | VAC-01/02/03 | grep gates (4 tables after Fase 5 header, no proxima column, es_autor OR dosis) | ✅ schema.sql | ✅ green |
| 05-01-T2 | 1 | VAC-01..05 | grep loop over 15 RPCs + carne_publico service_role-only (CONTRATO_OK) | ✅ schema.sql | ✅ green |
| 05-02-T1 | 1 | VAC-02/03 | `flutter test test/vacuna_mapeo_test.dart test/whatsapp_vacunas_test.dart test/dosis_estado_chip_test.dart` | ✅ | ✅ green |
| 05-02-T2 | 1 | VAC-01..04 | `flutter test test/supabase_vacuna_repository_test.dart` | ✅ | ✅ green |
| 05-03-T1 | 1 | VAC-04/05 | grep gates EDGE_OK | ✅ | ✅ green |
| 05-03-T2 | 1 | VAC-05 | `node --test test/web/carne_logica.test.mjs` + no-innerHTML gate (PAGE_OK) | ✅ | ✅ green |
| 05-03-T3 | 1 | VAC-05 | WORKFLOW_OK grep gates | ✅ | ✅ green |
| 05-14-T1 | 2 | VAC-04 | grep gates LOGO_SQL_OK (logo_path in both carné functions, 4 clinica_logos policies, actualizar_clinica admin-only, no clinicas update policy) | ✅ schema.sql | ✅ green |
| 05-14-T2 | 2 | VAC-04 | `flutter test test/clinica_contrato_test.dart` | ✅ | ✅ green |
| 05-14-T3 | 2 | VAC-04 | `flutter test test/clinica_logo_test.dart` | ✅ | ✅ green |
| 05-04-T1 | 3 | VAC-01..05 | 193 `checks := checks + 1` + Q1..Q48 labels (Q41..Q48 logo) | ✅ | ✅ green |
| 05-04-T2 | 3 | VAC-04 | `bash -n verify_live_schema.sh` (PROBE_SYNTAX_OK, incl. actualizar_clinica + clinica-logos) | ✅ | ✅ green |
| 05-04-T3 | 3 | VAC-01..05 | manual: `RLS SMOKE: PASS (193 checks)` (en vivo, pegado por el usuario) + `LIVE_SCHEMA_OK` | — | ✅ green (manual) |
| 05-05-T1/T2 | 2 | VAC-01/02 | `flutter test test/registrar_dosis_screen_test.dart` | ✅ | ✅ green |
| 05-06-T1 | 2 | VAC-04 | `flutter test test/carne_pdf_service_test.dart` | ✅ | ✅ green |
| 05-06-T2 | 2 | VAC-04 | `flutter test test/compartir_carne_sheet_test.dart` | ✅ | ✅ green |
| 05-07-T1..T3 | 3 | VAC-01..04 | `flutter test test/carne_screen_test.dart test/mascota_detail_screen_test.dart` | ✅ | ✅ green |
| 05-08-T1/T2 | 3 | VAC-02 | `flutter test test/protocolos_screen_test.dart` | ✅ | ✅ green |
| 05-09-T1/T2 | 3 | VAC-03 | `flutter test test/vacunas_pendientes_screen_test.dart test/cita_form_screen_test.dart` | ✅ | ✅ green |
| 05-10-T1/T2 | 3 | VAC-01 | `flutter test test/completar_cita_screen_test.dart` | ✅ | ✅ green |
| 05-11-T1 | 5 | VAC-04/05 | manual authorization (concedida) | — | ✅ green (manual) |
| 05-11-T2 | 5 | VAC-04/05 | `REQUIRE_CARNE_FN=1 bash supabase/tests/verify_live_schema.sh` + curl Pages 200 (CARNE_LIVE_OK) + token real: `clinica.logo_url` firmado, sin `logo_path`/`foto_path` (REAL_TOKEN_OK) | ✅ | ✅ green |
| 05-12-T1..T3 | 4 | VAC-01/03 | `flutter test test/inicio_screen_test.dart test/mascota_search_sheet_test.dart test/pacientes_list_screen_test.dart test/agenda_screen_test.dart` | ✅ | ✅ green |
| 05-15-T1 | 4 | VAC-04 | `flutter test test/recorte_cuadrado_test.dart test/guardar_datos_clinica_test.dart` | ✅ | ✅ green |
| 05-15-T2 | 4 | VAC-04 | `flutter test test/datos_clinica_screen_test.dart test/equipo_screen_test.dart test/router_equipo_test.dart` | ✅ | ✅ green |
| 05-16-T1 | 4 | VAC-04 | `flutter test test/vacuna_mapeo_test.dart test/carne_screen_test.dart` | ✅ | ✅ green |
| 05-16-T2 | 4 | VAC-04 | `flutter test test/carne_pdf_service_test.dart test/compartir_carne_sheet_test.dart test/historia_clinica_pdf_service_test.dart` + PDF_LOGO_FONT_OK (logo decodificado, Caprasimo con respaldo Figtree) | ✅ | ✅ green |
| 05-17-T1 | 4 | VAC-04/05 | `node --test test/web/carne_logica.test.mjs` + LOGO_PAGE_OK | ✅ | ✅ green |
| 05-17-T2 | 4 | VAC-04/05 | LOGO_EDGE_OK grep gates (firmar(), LOGO_RE, sin logo_path/foto_path) | ✅ | ✅ green |
| 05-13-T1 | 6 | all | PHASE5_GATE_OK: `flutter analyze` limpio; `flutter test` 654 OK; `node --test test/web/carne_logica.test.mjs` 9/9; `REQUIRE_CARNE_FN=1 verify_live_schema.sh` LIVE_SCHEMA_OK; REAL_TOKEN_OK con/sin logo; auditoría brand-ui (315dc84, b2b5a74, 5b6fbc8, 99384b0, 947b262) | ✅ | ✅ green |
| 05-13-T2 | 6 | all | 05-QA-REPORT.md F1..F13 + G1..G8: r1 10/13, r2 G4/G5/G6 PASS, r3 G7/G8/Agendar→guardar PASS. BLOCKED (no bloqueante): lectura de no-admin (sin vet no-admin activo en la clínica QA), toque de notificación (reloj del emulador) | — | ✅ green (UAT en emulador) |
| 05-13-T3 | 6 | VAC-04/05 | adaptado: el usuario solo tiene iPhone; carné público verificado en Safari/iPhone ("se ve bien", 2026-10-03); chequeos Android reemplazados por evidencia de emulador; WhatsApp/notificación reales diferidos al build iOS/TestFlight | — | ✅ green (adaptado) |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/helpers/fake_vacunas.dart` — `FakeVacunaRepository` (patrón `FakeCitaRepository`: logs de llamadas, `error`/`errorX` inyectables)
- [x] Tests listados arriba (registro, mapeo, pendientes, WhatsApp, enlace, PDF)
- [x] Bloque Q en `rls_smoke_test.sql` (+ nuevo total: 193, Q41..Q48 logo)
- [x] `test/helpers/fake_clinica.dart` — `FakeClinicaRepository`, `FakeClinicaLogoDatasource` (05-14)
- [x] Sondas en `verify_live_schema.sh`
- Framework: ya instalado; ninguna instalación nueva


---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Aplicar delta de schema + smoke test en proyecto vivo | VAC-01..05 | Sin CLI/psql; MCP `apply_migration` con autorización + pegado del smoke en SQL Editor | `RLS SMOKE: PASS ({N} checks)` |
| Activar GitHub Pages y desplegar Edge Function `carne` | VAC-04/05 | Configuración en GitHub/Supabase | Página pública carga un carné de prueba sin cuenta; token inválido muestra estado genérico |
| Carné público en celular real (sin app ni cuenta) | VAC-04/05 | Navegador real | ✅ Verificado por el usuario en Safari/iPhone (2026-10-03, "se ve bien"). Abrir link; ver datos D-15/D-20, sin anuladas (D-23), pie "Hecho con VetApp" (D-19), logo de la clínica en el encabezado (D-26) |
| WhatsApp real, compartir PDF y toque de notificación en dispositivo | VAC-03/04 | Hardware/apps reales; el usuario solo tiene iPhone | ⏳ Diferido al build iOS/TestFlight (fase final); emulador cubrió el flujo, salvo toque de notificación (reloj del emulador) |
| Vista de solo lectura para veterinario no-admin | VAC-01 | Sin vet no-admin activo en la clínica QA | ⏳ Pendiente de cuenta adicional |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 120s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-10-03
