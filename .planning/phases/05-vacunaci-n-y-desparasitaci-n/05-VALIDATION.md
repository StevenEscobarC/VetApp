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


*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/helpers/fake_vacunas.dart` — `FakeVacunaRepository` (patrón `FakeCitaRepository`: logs de llamadas, `error`/`errorX` inyectables)
- [ ] Tests listados arriba (registro, mapeo, pendientes, WhatsApp, enlace, PDF)
- [ ] Bloque Q en `rls_smoke_test.sql` (+ nuevo total)
- [ ] Sondas en `verify_live_schema.sh`
- Framework: ya instalado; ninguna instalación nueva


---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Aplicar delta de schema + smoke test en proyecto vivo | VAC-01..05 | Sin CLI/psql; MCP `apply_migration` con autorización + pegado del smoke en SQL Editor | `RLS SMOKE: PASS ({N} checks)` |
| Activar GitHub Pages y desplegar Edge Function `carne` | VAC-04/05 | Configuración en GitHub/Supabase | Página pública carga un carné de prueba sin cuenta; token inválido muestra estado genérico |
| Carné público en celular real (sin app ni cuenta) + compartir por WhatsApp + PDF | VAC-04/05 | Navegador/WhatsApp reales | Abrir link desde WhatsApp; ver datos D-15/D-20, sin anuladas (D-23), pie "Hecho con VetApp" (D-19) |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
