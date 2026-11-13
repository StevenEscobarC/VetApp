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
| **Full suite command** | `flutter test` + pegar `rls_smoke_test.sql` completo (esperado `RLS SMOKE: PASS (258 checks)`: 238 + bloque S de 20) + `bash supabase/tests/verify_live_schema.sh` |
| **Estimated runtime** | ~35 segundos (`flutter test`, línea base 856) |

---

## Sampling Rate

- **After every task commit:** `flutter analyze` + `flutter test` de los archivos del plan (tareas SQL: compuertas grep del bloque Fase 6)
- **After every plan wave:** `flutter test` completo + compuertas grep de SQL
- **Before `/gsd:verify-work`:** suite verde, `flutter analyze` limpio, smoke `PASS (258 checks)` pegado por el usuario, `LIVE_SCHEMA_OK`, QA en emulador (`vetapp-qa`)
- **Max feedback latency:** ~40 segundos

---

## Per-Task Verification Map

*El planner completa esta tabla con una fila por tarea (Task ID, plan, ola, requisito INV-0x, amenaza, comportamiento seguro, tipo de prueba, comando `<automated>`, si el archivo existe, estado). Mapa por requisito de partida: `06-RESEARCH.md` §Validation Architecture.*

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 06-01-T1 | 06-01 | 1 | INV-01..03 | T-06-01..10 | Bloque S (S1..S20) codifica aislamiento, solo-append, sin negativos, solo admin, solo lectura; R44 a 9 tablas | SQL smoke (estático) | grep gates -> `SMOKE_S_OK` (258 checks, S1..S20) | ✅ | ✅ green (estático + en vivo: smoke PASS 258 en 06-04) |
| 06-01-T2 | 06-01 | 1 | INV-01..03 | T-06-02..09 | RPC security definer + search_path, `for update`, sin grants de escritura, guard en 2 tablas | grep (SQL) | awk bloque Fase 6 -> `SCHEMA_F6_OK` | ✅ (schema.sql) | ✅ green (estático + en vivo: smoke PASS 258 en 06-04) |
| 06-01-T3 | 06-01 | 1 | INV-01..03 | T-06-10 | anon sin acceso a tablas/RPC; hint de embed | script sintaxis | `bash -n` + grep -> `PROBE_F6_OK` | ✅ | ✅ green (sintaxis + `LIVE_F6_OK` en vivo, 06-04) |
| 06-02-T1 | 06-02 | 1 | INV-01, INV-02 | — | bajo = `<` (borde y mínimo 0), vence pronto/vencido con día Bogotá | unit | `flutter test test/producto_test.dart` -> `DOMINIO_INV_OK` | ✅ | ✅ green |
| 06-02-T2 | 06-02 | 1 | INV-01..03 | T-06-11, T-06-12, T-06-15 | Errores -> InventarioFailure tipado en español; sin conexión; solo delta al servidor | unit | `flutter test test/supabase_inventario_repository_test.dart` -> `REPO_INV_OK` | ✅ | ✅ green |
| 06-02-T3 | 06-02 | 1 | INV-01..03 | T-06-14 | Acciones invalidan lista + resumen + historial (G4); 9 overrides | unit + suite | `flutter test test/inventario_invalidacion_test.dart` + `flutter test` -> `CONTRATO_INV_OK` | ✅ | ✅ green |
| 06-03-T1 | 06-03 | 1 | INV-01 | T-06-16, T-06-17 | COP entero `$ 85.000`, rechazo de coma; fecha futura solo con `permitirFuturo` | unit | `flutter test test/formato_test.dart` -> `FORMATO_COP_OK` | ✅ | ✅ green |
| 06-03-T2 | 06-03 | 1 | INV-01, INV-03 | — | AppTextField extendido sin cambiar defaults | widget + suite | `flutter test test/app_text_field_test.dart` + `flutter test` -> `APP_TEXT_FIELD_OK` | ✅ | ✅ green |
| 06-04-T1 | 06-04 | 2 | INV-01..03 | T-06-18 | Revisión estática previa al apply | grep (SQL) | -> `PREAPPLY_F6_OK` | ✅ | ✅ green |
| 06-04-T2 | 06-04 | 2 | INV-01..03 | T-06-18, T-06-19, T-06-21 | Delta en vivo; smoke completo en la nube | manual (usuario) | conteo -> `SMOKE_258_READY`; literal `RLS SMOKE: PASS (258 checks)` pegado por el usuario | ✅ | ✅ green (delta aplicado 2026-11-12; smoke pegado por el usuario: `RLS SMOKE: PASS (258 checks) - cambios revertidos`) |
| 06-04-T3 | 06-04 | 2 | INV-01..03 | T-06-10, T-06-20 | Superficie anon denegada en vivo; embed resuelve | script (nube) | `verify_live_schema.sh` -> `LIVE_F6_OK` | ✅ | ✅ green |
| 06-05-T1 | 06-05 | 2 | INV-01, INV-02 | T-06-23 | Lista con insignias icono+texto, búsqueda, estados; FAB con candado en solo lectura | widget | `flutter test test/inventario_screen_test.dart` -> `LISTA_INV_OK` | ✅ | ✅ green |
| 06-05-T2 | 06-05 | 2 | INV-01 | T-06-22, T-06-24 | Alta de un paso, validaciones, 23505 inline, LP004 conserva datos | widget | `flutter test test/producto_form_screen_test.dart` -> `FORM_ALTA_OK` | ✅ | ✅ green |
| 06-05-T3 | 06-05 | 2 | INV-01 | T-06-25 | Más -> /inventario -> /nuevo sin duplicar el shell (G5) | widget/router + suite | `flutter test test/router_inventario_cross_shell_test.dart` + `flutter test` -> `SLICE_ALTA_OK` | ✅ | ✅ green |
| 06-06-T1 | 06-06 | 3 | INV-03 | T-06-26..29 | −1 inmediato, Deshacer = inverso, fila bloqueada en vuelo, candado, errores sin conexión/IN001/IN002 | widget | `flutter test test/ajuste_rapido_test.dart` -> `AJUSTE_RAPIDO_OK` | ✅ | ✅ green |
| 06-06-T2 | 06-06 | 3 | INV-03 | T-06-26, T-06-27 | Hoja de ajuste: motivos, vista previa, confirmación solo > 10, Deshacer solo <= 10, errores inline | widget + suite | `flutter test test/ajuste_sheet_test.dart` + `flutter test` -> `AJUSTE_SHEET_OK` | ✅ | ✅ green |
| 06-07-T1 | 06-07 | 3 | INV-02 | — | Filtros Todos/Bajos/Vence pronto, `?filtro=bajos`, franja | widget | `flutter test test/inventario_screen_test.dart` -> `FILTROS_INV_OK` | ✅ | ✅ green |
| 06-07-T2 | 06-07 | 3 | INV-02 | T-06-30 | Texto de pedido (mínimo×2−stock) y hoja de compartir sin destinatario | unit + widget | `flutter test test/pedido_stock_test.dart test/inventario_screen_test.dart` -> `PEDIDO_WA_OK` | ✅ | ✅ green |
| 06-07-T3 | 06-07 | 3 | INV-02 | T-06-31, T-06-32 | Tarjeta de Inicio solo con bajos > 0 (oculta en carga/error), pastilla en Más, Inicio -> Bajos sin duplicar shell | widget/router + suite | `flutter test test/stock_bajo_card_test.dart test/inicio_screen_test.dart test/router_inventario_cross_shell_test.dart` + `flutter test` -> `ALERTA_INV_OK` | ✅ | ✅ green |
| 06-08-T1 | 06-08 | 4 | INV-03 | T-06-34, T-06-36 | Detalle, ajustes, historial con autor (últimos 50), candados | widget/router | `flutter test test/producto_detail_screen_test.dart test/router_inventario_cross_shell_test.dart` -> `DETALLE_INV_OK` | ❌ W0 | ⬜ pending |
| 06-08-T2 | 06-08 | 4 | INV-01, INV-03 | T-06-33, T-06-35 | Editar: mínimo/precios solo admin; archivar solo admin, sin borrar | widget + suite | `flutter test test/producto_form_screen_test.dart test/producto_detail_screen_test.dart` + `flutter test` -> `EDITAR_ARCHIVAR_OK` | ✅ (extender) | ⬜ pending |
| 06-09-T1 | 06-09 | 5 | INV-01..03 | T-06-38 | Gate integrado, sonda en vivo, greps de capas/seguridad, auditoría de marca, docs | suite + script | -> `PHASE6_GATE_OK` | ✅ | ⬜ pending |
| 06-09-T2 | 06-09 | 5 | INV-01..03 | T-06-37, T-06-39 | UAT en emulador contra el proyecto vivo (F1..F9) | manual (vetapp-qa) | -> `QA_REPORT_OK` + `QA: PASS` | ❌ (se crea) | ⬜ pending |
| 06-09-T3 | 06-09 | 5 | INV-01..03 | T-06-40 | Visto bueno del usuario | manual (usuario) | -> `SIGNOFF_RECORDED` + respuesta literal | ✅ | ⬜ pendiente del usuario |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/helpers/fake_inventario.dart` — `FakeInventarioRepository` (datos fijos, errores por método, `llamadas`)
- [ ] Overrides de `inventarioRepositoryProvider` en los tests que montan Inicio, Más o el router (RESEARCH Pitfall 6)
- [ ] Pruebas nuevas: `producto_test`, `supabase_inventario_repository_test`, `producto_form_screen_test`, `inventario_screen_test`, `ajuste_rapido_test`, `ajuste_sheet_test`, `stock_bajo_card_test`, `pedido_stock_test`, `inventario_invalidacion_test`, `router_inventario_cross_shell_test`, `producto_detail_screen_test`, `app_text_field_test`
- [ ] Extender `test/formato_test.dart` (COP) e `test/inicio_screen_test.dart`
- [ ] Bloque S en `supabase/tests/rls_smoke_test.sql`, edición de R44 (guard en 9 tablas) y cabecera con el total nuevo
- [ ] Framework: nada que instalar

---

## Evidencia de ejecución por plan

*Cada plan, al cerrarse, registra aquí sus comandos `<automated>`, resultado (marcadores), pruebas por archivo y la suite completa con fecha y commit (memoria del proyecto `vetapp-verify-each-plan`). Los pasos manuales quedan como pendientes del usuario, nunca en verde.*

| Plan | Compuertas / comando | Resultado | Pruebas por archivo (pasan) |
|------|----------------------|-----------|-----------------------------|
| 06-01 | grep gates del bloque S y del bloque Fase 6, `bash -n` de la sonda (2026-11-12, fusionado en `f60f192`) | `SMOKE_S_OK` (258 `checks := checks + 1`, una cabecera "Total esperado: 258") · `SCHEMA_F6_OK` (5 RPC `security definer`, 0 `security invoker`, `for update` en `mover_stock`, guard en 2 tablas) · `PROBE_F6_OK` · en vivo (06-04): `RLS SMOKE: PASS (258 checks)` y `LIVE_F6_OK` | — (SQL estático; ningún cambio aplicado en vivo) |
| 06-02 | `flutter analyze` + 3 archivos nuevos + 9 pruebas existentes con override (2026-11-12) | `DOMINIO_INV_OK` · `REPO_INV_OK` · `CONTRATO_INV_OK` · desviación: código y pruebas de T1/T2 en un mismo commit (sin commit rojo previo) | producto 15, supabase_inventario_repository 18, inventario_invalidacion 10; 9 pruebas existentes verdes con `inventarioRepositoryProvider` (router_equipo vía `overrides` nuevo en `appUnderTest`) |
| 06-03 | `flutter analyze` + 2 archivos (2026-11-12) | `FORMATO_COP_OK` · `APP_TEXT_FIELD_OK` (rojo visto antes del verde) | formato 35 (casos existentes sin cambios), app_text_field 3 |
| Ola 1 (QA) | — | QA: no aplica — 06-01..03 no tienen pantallas (contrato SQL, contrato Dart y helpers); la UAT en emulador es de 06-09 | — |
| Ola 1 | Suite completa sobre `master` tras fusionar (`f60f192`, 2026-11-12) | `flutter analyze` → `No issues found!` · `flutter test` → `+911: All tests passed!` (856 base + 43 de 06-02 + 12 de 06-03) | — |
| 06-04 | Revisión previa + `apply_migration fase_06_inventario` (MCP, con OK del usuario) + 3 consultas de solo lectura + sonda anon (2026-11-12) | `PREAPPLY_F6_OK` (sin cambios) · primer intento con timeout de conexión, reintento `success` · productos 0, movimientos 0, guard en 9 tablas · `LIVE_F6_OK` / `LIVE_SCHEMA_OK` · smoke pegado por el usuario (primera corrida): `RLS SMOKE: PASS (258 checks) - cambios revertidos` | — (SQL en vivo; detalle en 06-04-SUMMARY) |
| 06-05 | `flutter analyze` + 3 archivos nuevos, commits en rojo antes de cada implementación (2026-11-12, fusionado en `703fe84`) | `LISTA_INV_OK` · `FORM_ALTA_OK` · `SLICE_ALTA_OK` · QA en emulador → 06-09 (F1, F2) | inventario_screen 12, producto_form_screen 12, router_inventario_cross_shell 3; `widget_test` ajustado con `ensureVisible` (sin debilitar) |
| Ola 2 | Suite completa sobre `master` tras fusionar 06-05 (`703fe84`, 2026-11-12) | `flutter analyze` → `No issues found!` · `flutter test` → `+938: All tests passed!` | — |
| 06-06 | `flutter analyze` + 2 archivos nuevos, commits en rojo antes de cada implementación (2026-11-12, fusionado en `85a5d76`) | `AJUSTE_RAPIDO_OK` · `AJUSTE_SHEET_OK` · QA en emulador → 06-09 (F3, F8) | ajuste_rapido 11, ajuste_sheet 15; en inventario_screen dos aserciones del FAB acotadas al `FloatingActionButton` (mismo chequeo; las filas ahora tienen sus propios íconos) |
| 06-07 | `flutter analyze` + archivos del plan, commits en rojo antes de cada implementación (2026-11-12, fusionado en `6819fa6`) | `FILTROS_INV_OK` · `PEDIDO_WA_OK` · `ALERTA_INV_OK` · "Pedir por WhatsApp" no se recortó · QA en emulador → 06-09 (F4, F5) · **discrepancia:** el ejecutor reportó la suite en verde, pero `router_inventario_cross_shell_test.dart` no compilaba (variable `producto` sin declarar); corregido por el orquestador en `1e16ee4` sin tocar aserciones | inventario_screen 27, pedido_stock 3, stock_bajo_card 6, inicio_screen 15, router_inventario_cross_shell 9; aserción del ícono `trending_down` acotada a `InsigniaStock` (mismo chequeo) |
| Ola 3 | Suite completa sobre `master` tras fusionar 06-06 y 06-07 y el arreglo (`1e16ee4`, 2026-11-12) | primera corrida tras la fusión: `1 issue` + `-1` (compilación); tras el arreglo: `flutter analyze` → `No issues found!` · `flutter test` → `+996: All tests passed!` | — |

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Delta de esquema aplicado y smoke test en la nube | INV-01..03 | El usuario autoriza el apply y pega el smoke test (convención D-03 de Fase 1) | Aplicar el bloque Fase 6 con OK explícito; pegar `rls_smoke_test.sql` y registrar la línea literal `RLS SMOKE: PASS (258 checks)` |
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
