---
phase: 6
slug: inventario
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-10-31
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (SDK) + fakes a mano en `test/helpers/` + `supabase/tests/rls_smoke_test.sql` (bloque `do $$` que termina siempre en `RAISE EXCEPTION`) + `supabase/tests/verify_live_schema.sh` (sondas anon) |
| **Config file** | `analysis_options.yaml` (flutter_lints); el smoke test se pega en el SQL Editor |
| **Quick run command** | `flutter analyze && flutter test test/<archivo>_test.dart` |
| **Full suite command** | `flutter test` + pegar `rls_smoke_test.sql` completo (esperado `RLS SMOKE: PASS (238+N checks)`, N fijado por el plan del bloque S) + `bash supabase/tests/verify_live_schema.sh` |
| **Estimated runtime** | ~35 segundos (`flutter test`, línea base 856) |

---

## Sampling Rate

- **After every task commit:** `flutter analyze` + `flutter test` de los archivos del plan (tareas SQL: compuertas grep del bloque Fase 6)
- **After every plan wave:** `flutter test` completo + compuertas grep de SQL
- **Before `/gsd:verify-work`:** suite verde, `flutter analyze` limpio, smoke `PASS (238+N checks)` pegado por el usuario, `LIVE_SCHEMA_OK`, QA en emulador (`vetapp-qa`)
- **Max feedback latency:** ~40 segundos

---

## Per-Task Verification Map

*El planner completa esta tabla con una fila por tarea (Task ID, plan, ola, requisito INV-0x, amenaza, comportamiento seguro, tipo de prueba, comando `<automated>`, si el archivo existe, estado). Mapa por requisito de partida: `06-RESEARCH.md` §Validation Architecture.*

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/helpers/fake_inventario.dart` — `FakeInventarioRepository` (datos fijos, errores por método, `llamadas`)
- [ ] Overrides de `inventarioRepositoryProvider` en los tests que montan Inicio, Más o el router (RESEARCH Pitfall 6)
- [ ] Pruebas nuevas: `producto_test`, `supabase_inventario_repository_test`, `producto_form_screen_test`, `inventario_screen_test`, `ajuste_rapido_test`, `stock_bajo_card_test`, `pedido_stock_test`, `inventario_invalidacion_test`, `router_inventario_cross_shell_test`
- [ ] Extender `test/formato_test.dart` (COP) e `test/inicio_screen_test.dart`
- [ ] Bloque S en `supabase/tests/rls_smoke_test.sql`, edición de R44 (guard en 9 tablas) y cabecera con el total nuevo
- [ ] Framework: nada que instalar

---

## Evidencia de ejecución por plan

*Cada plan, al cerrarse, registra aquí sus comandos `<automated>`, resultado (marcadores), pruebas por archivo y la suite completa con fecha y commit (memoria del proyecto `vetapp-verify-each-plan`). Los pasos manuales quedan como pendientes del usuario, nunca en verde.*

| Plan | Compuertas / comando | Resultado | Pruebas por archivo (pasan) |
|------|----------------------|-----------|-----------------------------|

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Delta de esquema aplicado y smoke test en la nube | INV-01..03 | El usuario autoriza el apply y pega el smoke test (convención D-03 de Fase 1) | Aplicar el bloque Fase 6 con OK explícito; pegar `rls_smoke_test.sql` y registrar la línea literal `RLS SMOKE: PASS (238+N checks)` |
| Alta, ajuste rápido, tarjeta de Inicio y filtro de bajos en emulador | INV-01..03 | Verificación visual/interactiva en dispositivo | `vetapp-qa` en el emulador Android (el usuario solo tiene iPhone) |
| "Pedir por WhatsApp" con la hoja de compartir real | INV-02 | Integración externa | Abrir la hoja en el emulador; el envío real queda para un teléfono físico |
| Concurrencia real de `mover_stock` (dos sesiones) | INV-03 | No se puede probar dentro de un único `do $$` | Opcional: dos pestañas del SQL Editor; cubierto por construcción (`FOR UPDATE`, verificado por grep) |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 40s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
