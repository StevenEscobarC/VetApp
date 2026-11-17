---
phase: 8
slug: dashboard-y-dise-o-visual
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-11-17
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (SDK) + fakes a mano en `test/helpers/` + `supabase/tests/rls_smoke_test.sql` (bloque `do $$` que termina en `RAISE EXCEPTION`) + `supabase/tests/verify_live_schema.sh` |
| **Config file** | `analysis_options.yaml` (flutter_lints); el smoke se pega en el SQL Editor |
| **Quick run command** | `flutter analyze && flutter test test/<archivos del plan>` |
| **Full suite command** | `flutter analyze && flutter test`, más el smoke completo pegado por el usuario (293 + checks del bloque `inicio_resumen`; el planner fija el total exacto) y `bash supabase/tests/verify_live_schema.sh` (`LIVE_SCHEMA_OK`) |
| **Estimated runtime** | ~45 segundos (`flutter test`) |

---

## Sampling Rate

- **After every task commit:** `flutter analyze` + los `flutter test` de los archivos de la tarea; en tareas SQL, las compuertas grep del bloque Fase 8.
- **After every plan wave:** `flutter test` completo + compuertas DASH-04:
  - `grep -rn "ComingSoonScreen\|Próximamente" lib test` vacío;
  - `grep -rni "factur" lib --include=*.dart | grep -v "const String kOrigenCobro = 'factura';"` vacío;
  - compuertas de widgets crudos del UI-SPEC (SW-01..SW-10) fuera de `lib/core/`.
- **Before `/gsd:verify-work`:** suite verde, analyze limpio, smoke `PASS` pegado por el usuario, `LIVE_SCHEMA_OK`, QA en emulador (`vetapp-qa`) en modo claro y oscuro.
- **Max feedback latency:** 60 segundos.

---

## Per-Task Verification Map

El planner completa una fila por tarea (`08-NN-MM`). Mapa requisito → prueba (de 08-RESEARCH §Validation Architecture):

| Req | Behavior | Test Type | Automated Command | File Exists |
|-----|----------|-----------|-------------------|-------------|
| DASH-01 | RPC: consultas del mes Bogotá con borde 00:00; aislamiento entre clínicas; ingresos = `cobros_resumen().cobrado_mes` (excluye anulada, cotización, pendiente, mes anterior); pacientes nuevos; ceros en clínica vacía; privilegios (no vet, anon, colega solo lectura sí) | SQL smoke | bloque nuevo en `rls_smoke_test.sql` | ❌ W0 |
| DASH-01 | `formatearCopCorto` (950.000 · 1.000.000 · 3.800.000 · 3.000.000 · 12.340.000 · 3.960.000) | unit | `flutter test test/formato_test.dart` | ✅ ampliar |
| DASH-01 | repositorio Inicio: mapeo y errores (sin conexión) | unit | `flutter test test/supabase_inicio_repository_test.dart` | ❌ W0 |
| DASH-01 | tarjetas: cifras, abreviado, tap Ingresos → Cobros, Nuevos → Pacientes, Consultas no navega | widget | `flutter test test/inicio_screen_test.dart` | ✅ ampliar |
| DASH-02 | `proximas()`: `estado in (pendiente,confirmada)`, `gte` ahora, límite 5 | unit | `flutter test test/supabase_cita_repository_test.dart` | ✅ ampliar |
| DASH-02 | separadores Hoy/Mañana/día; vacío + "Agendar cita"; color vet solo multi-vet; tap → `/agenda/:id` | widget | `flutter test test/inicio_screen_test.dart` | ✅ ampliar |
| DASH-03 | 4 accesos ≥ 48 dp, rutas, "Cobro" (nunca "Factura"), candado + hoja del plan en solo lectura | widget | `flutter test test/inicio_screen_test.dart` | ✅ ampliar |
| D-13 | contador `inicioRevision` sube tras citas, consultas, cobros y alta de mascota | unit | `flutter test test/inicio_invalidacion_test.dart` | ❌ W0 |
| D-14 | esqueleto, error por bloque con "Reintentar" sin tumbar los demás, texto sin conexión | widget | `flutter test test/inicio_screen_test.dart` | ✅ ampliar |
| DASH-04 | temas de componente (switch, checkbox, FAB, diálogo, snackbar, date picker, bottom sheet) | unit | `flutter test test/app_theme_test.dart` | ✅ ampliar |
| DASH-04 | sin ComingSoon/"Próximamente"/widgets crudos fuera de core | grep gate | ver Sampling Rate | ❌ W0 (script) |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/supabase_inicio_repository_test.dart`
- [ ] `test/inicio_invalidacion_test.dart` (modelo `cobros_invalidacion_test.dart`)
- [ ] `test/helpers/fake_inicio.dart`
- [ ] Ampliar `test/formato_test.dart`, `test/inicio_screen_test.dart`, `test/supabase_cita_repository_test.dart`, `test/app_theme_test.dart`
- [ ] Bloque `inicio_resumen` en `supabase/tests/rls_smoke_test.sql` + `verify_live_schema.sh`
- [ ] Script de compuertas grep DASH-04

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Smoke SQL en vivo | DASH-01 | El SQL Editor lo pega el usuario | Pegar `rls_smoke_test.sql`; esperar `RLS SMOKE: PASS (N checks) - cambios revertidos` |
| Inicio real con datos de clínica de prueba | DASH-01..03 | Datos y navegación reales | `vetapp-qa` en emulador: métricas, próximas citas, accesos, pull-to-refresh, solo lectura |
| Apariencia en modo claro y oscuro de todas las pantallas | DASH-04 | Apariencia/contraste | `vetapp-qa` capturas en `qa/` por feature, ambos modos |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
