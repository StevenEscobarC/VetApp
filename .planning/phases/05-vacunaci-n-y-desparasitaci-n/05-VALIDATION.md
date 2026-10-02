---
phase: 5
slug: vacunacion-y-desparasitacion
status: draft
nyquist_compliant: false
wave_0_complete: false
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
| VAC-01 | Registrar dosis (biológico+fecha; externa; anular con motivo) | widget + repo fake | `flutter test test/registrar_dosis_screen_test.dart` | ❌ Wave 0 |
| VAC-01 | RLS/RPC de dosis (aislamiento, append-only, anulación) | SQL smoke | pegar `rls_smoke_test.sql` (bloque Q) | ✅ extender |
| VAC-02 | Serie 1/3→refuerzo, duración elegida, ventanas, `es_refuerzo`, reinicio | SQL smoke (`p_hoy` fijo) | `rls_smoke_test.sql` Q | ✅ extender |
| VAC-02 | Mapeo Dart de filas calculadas, `fechaDeBd`, etiquetas | unit | `flutter test test/vacuna_mapeo_test.dart` | ❌ Wave 0 |
| VAC-03 | Tarjeta Inicio, lista Vencidas/Próximas, badges, D-13, descartar/posponer | widget + provider fake | `flutter test test/vacunas_pendientes_screen_test.dart` | ❌ Wave 0 |
| VAC-03 | WhatsApp recordatorio (marca solo si `abrirEnApp` true) | widget (`FakeLanzadorExterno`) | `flutter test test/whatsapp_vacunas_test.dart` | ❌ Wave 0 |
| VAC-04 | Enlace: crear/regenerar/desactivar, compartir texto/WhatsApp/PDF | widget + fakes (`fake_compartir`, `fake_pdf`) | `flutter test test/enlace_carne_sheet_test.dart`, `test/carne_pdf_service_test.dart` | ❌ Wave 0 |
| VAC-04/05 | `carne_publico` solo claves D-15; token viejo inválido; anon/authenticated sin acceso | SQL smoke + sonda | `rls_smoke_test.sql` Q + `bash supabase/tests/verify_live_schema.sh` | ✅ extender |
| VAC-05 | Edge Function: token mal formado → 404; válido → JSON mínimo; página renderiza sin cuenta | manual + curl | `curl` documentado en plan; verificación visual en celular | manual-only (justificación: host externo) |
| VAC-04 (D-26/D-27) | Logo de la clínica: bucket privado `clinica-logos` (solo admin escribe, otra clínica no lee), `actualizar_clinica` solo admin, `carne_publico` solo devuelve la ruta | SQL smoke | `rls_smoke_test.sql` Q41..Q48 | ✅ extender |
| VAC-04 (D-26/D-27) | Pantalla Datos de la clínica, recorte cuadrado, logo en carné app/PDF/página | widget + unit + node | `flutter test test/datos_clinica_screen_test.dart test/carne_pdf_service_test.dart` + `node --test test/web/carne_logica.test.mjs` | ❌ Wave 0 |


### Per-task map (planner, 2026-10-02)

| Plan-Task | Wave | Requirement | Automated Command | File Exists? | Status |
|-----------|------|-------------|-------------------|--------------|--------|
| 05-01-T1 | 1 | VAC-01/02/03 | grep gates (4 tables after Fase 5 header, no proxima column, es_autor OR dosis) | ✅ schema.sql | ⬜ |
| 05-01-T2 | 1 | VAC-01..05 | grep loop over 15 RPCs + carne_publico service_role-only (CONTRATO_OK) | ✅ schema.sql | ⬜ |
| 05-02-T1 | 1 | VAC-02/03 | `flutter test test/vacuna_mapeo_test.dart test/whatsapp_vacunas_test.dart test/dosis_estado_chip_test.dart` | ❌ W0 (this task) | ⬜ |
| 05-02-T2 | 1 | VAC-01..04 | `flutter test test/supabase_vacuna_repository_test.dart` | ❌ W0 (this task) | ⬜ |
| 05-03-T1 | 1 | VAC-04/05 | grep gates EDGE_OK | ❌ (this task) | ⬜ |
| 05-03-T2 | 1 | VAC-05 | `node --test test/web/carne_logica.test.mjs` + no-innerHTML gate (PAGE_OK) | ❌ W0 (this task) | ⬜ |
| 05-03-T3 | 1 | VAC-05 | WORKFLOW_OK grep gates | ❌ (this task) | ⬜ |
| 05-14-T1 | 2 | VAC-04 | grep gates LOGO_SQL_OK (logo_path in both carné functions, 4 clinica_logos policies, actualizar_clinica admin-only, no clinicas update policy) | ✅ schema.sql | ⬜ |
| 05-14-T2 | 2 | VAC-04 | `flutter test test/clinica_contrato_test.dart` | ❌ W0 (this task) | ⬜ |
| 05-14-T3 | 2 | VAC-04 | `flutter test test/clinica_logo_test.dart` | ❌ W0 (this task) | ⬜ |
| 05-04-T1 | 3 | VAC-01..05 | 193 `checks := checks + 1` + Q1..Q48 labels (Q41..Q48 logo) | ✅ extend | ⬜ |
| 05-04-T2 | 3 | VAC-04 | `bash -n verify_live_schema.sh` (PROBE_SYNTAX_OK, incl. actualizar_clinica + clinica-logos) | ✅ extend | ⬜ |
| 05-04-T3 | 3 | VAC-01..05 | manual: `RLS SMOKE: PASS (193 checks)` + `LIVE_SCHEMA_OK` | — | ⬜ |
| 05-05-T1/T2 | 2 | VAC-01/02 | `flutter test test/registrar_dosis_screen_test.dart` | ❌ W0 (T1) | ⬜ |
| 05-06-T1 | 2 | VAC-04 | `flutter test test/carne_pdf_service_test.dart` | ❌ W0 (this task) | ⬜ |
| 05-06-T2 | 2 | VAC-04 | `flutter test test/compartir_carne_sheet_test.dart` | ❌ W0 (this task) | ⬜ |
| 05-07-T1..T3 | 3 | VAC-01..04 | `flutter test test/carne_screen_test.dart test/mascota_detail_screen_test.dart` | ❌ W0 (T1) | ⬜ |
| 05-08-T1/T2 | 3 | VAC-02 | `flutter test test/protocolos_screen_test.dart` | ❌ W0 (T1) | ⬜ |
| 05-09-T1/T2 | 3 | VAC-03 | `flutter test test/vacunas_pendientes_screen_test.dart test/cita_form_screen_test.dart` | ❌ W0 (T1) | ⬜ |
| 05-10-T1/T2 | 3 | VAC-01 | `flutter test test/completar_cita_screen_test.dart` | ✅ extend | ⬜ |
| 05-11-T1 | 5 | VAC-04/05 | manual authorization | — | ⬜ |
| 05-11-T2 | 5 | VAC-04/05 | `REQUIRE_CARNE_FN=1 bash supabase/tests/verify_live_schema.sh` + curl Pages 200 (CARNE_LIVE_OK) | ✅ | ⬜ |
| 05-12-T1..T3 | 4 | VAC-01/03 | `flutter test test/inicio_screen_test.dart test/mascota_search_sheet_test.dart test/pacientes_list_screen_test.dart test/agenda_screen_test.dart` | ❌ W0 (T1) | ⬜ |
| 05-15-T1 | 4 | VAC-04 | `flutter test test/recorte_cuadrado_test.dart test/guardar_datos_clinica_test.dart` | ❌ W0 (this task) | ⬜ |
| 05-15-T2 | 4 | VAC-04 | `flutter test test/datos_clinica_screen_test.dart test/equipo_screen_test.dart test/router_equipo_test.dart` | ❌ W0 (this task) | ⬜ |
| 05-16-T1 | 4 | VAC-04 | `flutter test test/vacuna_mapeo_test.dart test/carne_screen_test.dart` | ✅ extend | ⬜ |
| 05-16-T2 | 4 | VAC-04 | `flutter test test/carne_pdf_service_test.dart test/compartir_carne_sheet_test.dart` | ✅ extend | ⬜ |
| 05-16-T3 | 4 | VAC-04/05 | `node --test test/web/carne_logica.test.mjs` + LOGO_WEB_OK grep gates | ✅ extend | ⬜ |
| 05-13-T1 | 6 | all | PHASE5_GATE_OK (`flutter analyze && flutter test` + node test + live probe) | ✅ | ⬜ |
| 05-13-T2 | 6 | all | 05-QA-REPORT.md F1..F13 (F13 = logo de la clínica) | — | ⬜ |
| 05-13-T3 | 6 | VAC-04/05 | manual real phone | — | ⬜ |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/helpers/fake_vacunas.dart` — `FakeVacunaRepository` (patrón `FakeCitaRepository`: logs de llamadas, `error`/`errorX` inyectables)
- [ ] Tests listados arriba (registro, mapeo, pendientes, WhatsApp, enlace, PDF)
- [ ] Bloque Q en `rls_smoke_test.sql` (+ nuevo total: 193, Q41..Q48 logo)
- [ ] `test/helpers/fake_clinica.dart` — `FakeClinicaRepository`, `FakeClinicaLogoDatasource` (05-14)
- [ ] Sondas en `verify_live_schema.sh`
- Framework: ya instalado; ninguna instalación nueva


---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Aplicar delta de schema + smoke test en proyecto vivo | VAC-01..05 | Sin CLI/psql; MCP `apply_migration` con autorización + pegado del smoke en SQL Editor | `RLS SMOKE: PASS ({N} checks)` |
| Activar GitHub Pages y desplegar Edge Function `carne` | VAC-04/05 | Configuración en GitHub/Supabase | Página pública carga un carné de prueba sin cuenta; token inválido muestra estado genérico |
| Carné público en celular real (sin app ni cuenta) + compartir por WhatsApp + PDF | VAC-04/05 | Navegador/WhatsApp reales | Abrir link desde WhatsApp; ver datos D-15/D-20, sin anuladas (D-23), pie "Hecho con VetApp" (D-19), logo de la clínica en el encabezado (D-26) |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
