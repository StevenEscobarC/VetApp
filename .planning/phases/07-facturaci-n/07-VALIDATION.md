---
phase: 7
slug: facturaci-n
status: planned
nyquist_compliant: true
wave_0_complete: false
created: 2026-11-13
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (SDK) + fakes a mano en `test/helpers/` + `supabase/tests/rls_smoke_test.sql` (bloque `do $$` que termina siempre en `RAISE EXCEPTION`) + `supabase/tests/verify_live_schema.sh` (sondas anon) |
| **Config file** | `analysis_options.yaml` (flutter_lints); el smoke test se pega en el SQL Editor |
| **Quick run command** | `flutter analyze && flutter test test/<archivos del plan>` |
| **Full suite command** | `flutter analyze && flutter test`, más pegar `rls_smoke_test.sql` completo (esperado `RLS SMOKE: PASS (291 checks)`: 261 + bloque T de 30) y `bash supabase/tests/verify_live_schema.sh` (`LIVE_SCHEMA_OK`) |
| **Estimated runtime** | ~40 segundos (`flutter test`) |

---

## Sampling Rate

- **After every task commit:**
  - `flutter analyze` más los `flutter test` de los archivos de la tarea;
  - en tareas SQL, las compuertas grep del bloque Fase 7.
- **After every plan wave:**
  - `flutter test` completo;
  - compuerta de vocabulario: `grep -rni "factur" lib --include=*.dart | grep -v "const String kOrigenCobro = 'factura';"` debe salir vacío.
- **Before `/gsd:verify-work`:**
  - suite verde y `flutter analyze` limpio;
  - smoke `PASS (291 checks)` pegado por el usuario (07-08);
  - `LIVE_SCHEMA_OK`;
  - QA en emulador (`vetapp-qa`, 07-16).
- **Max feedback latency:** ~40 segundos

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 07-01-T1 | 07-01 | 1 | BILL-01..04 | T-07-01..10 | El bloque T1..T23 codifica: numeración sin huecos, idempotencia, descuento y devolución de stock atómicos, anular solo admin o autor, pago, conversión, visita ya cobrada, solo lectura, autoría. R44 queda en 13 tablas | SQL smoke (estático) | grep gates -> `SMOKE_T_A_OK` (284 checks) | ❌ W0 | ✅ green |
| 07-01-T2 | 07-01 | 1 | BILL-02, BILL-03 | T-07-01, T-07-04, T-07-05, T-07-08 | Tablas con RLS solo select; sin privilegios de escritura; helpers privados revocados; sin SEQUENCE; mover_stock intacto | grep (SQL) | awk bloque Fase 7 -> `SCHEMA_F7A_TABLAS_OK` | ✅ schema.sql | ✅ green |
| 07-01-T3 | 07-01 | 1 | BILL-02..04 | T-07-02, T-07-03, T-07-06, T-07-07, T-07-09, T-07-10 | 4 RPC definer con search_path; orden de bloqueo; manejador unique_violation; guarda en 4 tablas; es_autor con 6 brazos | grep (SQL) | -> `SCHEMA_F7A_OK` | ✅ schema.sql | ✅ green |
| 07-02-T1 | 07-02 | 1 | BILL-01, BILL-02 | — | Dominio entero en COP; número CC-0012 igual al del servidor; stub factura.dart eliminado | unit | `flutter test test/cobro_test.dart` -> `DOMINIO_COBRO_OK` | ❌ W0 | ✅ green |
| 07-02-T2 | 07-02 | 1 | BILL-01..04 | T-07-11, T-07-12, T-07-13 | Errores -> CobroFailure tipado en español (IN001 con plural, BC001..003, LP004); red por tipo; params sin total ni número | unit | `flutter test test/supabase_cobros_repository_test.dart` -> `REPO_COBROS_OK` | ❌ W0 | ✅ green |
| 07-02-T3 | 07-02 | 1 | BILL-03, BILL-04 | T-07-13, T-07-14 | Las acciones invalidan cobros e inventario en `finally`, también ante fallos (WR-03); rutas solo como texto | unit + suite | `flutter test test/cobros_invalidacion_test.dart` + `flutter test` -> `CONTRATO_COBROS_OK` | ❌ W0 | ✅ green |
| 07-03-T1 | 07-03 | 1 | BILL-01 | T-07-16 | Clave UUID v4 con Random.secure() y sin paquete nuevo; valor en letras ('ciento veinte mil pesos') | unit | `flutter test test/clave_idempotencia_test.dart test/pesos_en_letras_test.dart` -> `HELPERS_CLAVE_LETRAS_OK` | ❌ W0 | ✅ green |
| 07-03-T2 | 07-03 | 1 | BILL-01 | T-07-17, T-07-18 | Mensaje formal de WhatsApp sin cédula, teléfono ni la palabra prohibida; cédula y NIT normalizados con puntos | unit | `flutter test test/whatsapp_cobro_test.dart test/formato_test.dart` -> `HELPERS_WA_DOC_OK` | ❌ W0 / ✅ formato_test | ✅ green |
| 07-04-T1 | 07-04 | 2 | BILL-01, BILL-02, BILL-04 | T-07-19..24 | T24..T30: editar cotización, resumen por mes Bogotá, payload del PDF (logo según plan, sin teléfono), servicios solo admin, p_nit, snapshot de cédula, privilegios | SQL smoke (estático) | -> `SMOKE_T_B_OK` (291 checks) | ✅ (07-01) | ✅ green |
| 07-04-T2 | 07-04 | 2 | BILL-01, BILL-02, BILL-04 | T-07-19..23 | RPC parte B; actualizar_clinica de 6 argumentos (la de 5 eliminada); gating de logo | grep (SQL) | -> `SCHEMA_F7B_OK` | ✅ schema.sql | ✅ green |
| 07-04-T3 | 07-04 | 2 | BILL-01..04 | T-07-24 | anon sin acceso a 4 tablas, 9 RPC y 4 helpers (404); 3 hints de embed | script sintaxis | `bash -n` + grep -> `PROBE_F7_OK` | ✅ | ✅ green |
| 07-05-T1 | 07-05 | 2 | BILL-04 | T-07-25, T-07-26 | Resumen y conteo de pendientes vienen del servidor; chips con ícono y texto; candado en el FAB | widget | `flutter test test/cobros_screen_test.dart` -> `LISTA_COBROS_OK` | ❌ W0 | ✅ green |
| 07-05-T2 | 07-05 | 2 | BILL-01 | T-07-25, T-07-27 | Detalle en solo lectura sin "Editar" en una CC; CobrarBoton con candado; fila de visita ya cobrada | widget | `flutter test test/cobro_detail_screen_test.dart test/cobrar_boton_test.dart` -> `DETALLE_LECTURA_OK` | ❌ W0 | ✅ green |
| 07-05-T3 | 07-05 | 2 | BILL-01 | T-07-28 | Más -> /cobros -> detalle sin duplicar el shell (G5); fila estática | widget/router + suite | `flutter test test/router_cobros_cross_shell_test.dart` + `flutter test` -> `SLICE_LISTA_OK` | ❌ W0 | ✅ green |
| 07-06-T1 | 07-06 | 2 | BILL-01 | T-07-29, T-07-31 | Cédula opcional: se guarda en dígitos y se valida; el formulario rápido no cambia | widget | `flutter test test/cliente_detail_screen_test.dart ...` -> `CEDULA_CLIENTE_OK` | ✅ | ✅ green |
| 07-06-T2 | 07-06 | 2 | BILL-01 | T-07-29, T-07-30 | NIT o cédula de la clínica vía p_nit; el conjunto de claves del contrato incluye p_nit | unit + widget + suite | `flutter test test/clinica_contrato_test.dart ...` + `flutter test` -> `NIT_CLINICA_OK` | ✅ | ✅ green |
| 07-07-T1 | 07-07 | 3 | BILL-02 | T-07-32 | Una clave por borrador, nunca se regenera; el precio por línea no toca el precio base | unit | `flutter test test/borrador_cobro_test.dart` -> `BORRADOR_OK` | ❌ W0 | ⬜ pending |
| 07-07-T2 | 07-07 | 3 | BILL-01, BILL-02 | T-07-33 | Formulario con servicios, "Otro", líneas editables y total en vivo; sin descuento global | widget | `flutter test test/cobro_form_screen_test.dart` -> `FORM_LAYOUT_OK` | ❌ W0 | ⬜ pending |
| 07-07-T3 | 07-07 | 3 | BILL-01, BILL-02 | T-07-32, T-07-34, T-07-35 | Confirmar y emitir; sin conexión conserva el borrador y reenvía el mismo p_clave; doble toque = una llamada; LP004 abre la hoja | widget/router + suite | `flutter test test/cobro_form_screen_test.dart test/router_cobros_cross_shell_test.dart` + `flutter test` -> `SLICE_EMITIR_OK` | ❌ W0 | ⬜ pending |
| 07-08-T1 | 07-08 | 3 | BILL-01..04 | T-07-36 | Revisión estática antes de aplicar | grep (SQL) | -> `PREAPPLY_F7_OK` | ✅ | ✅ green |
| 07-08-T2 | 07-08 | 3 | BILL-01..04 | T-07-36, T-07-37, T-07-39 | Delta en vivo; smoke completo en la nube | manual (usuario) | conteo -> `SMOKE_291_READY`; línea literal `RLS SMOKE: PASS (291 checks)` pegada por el usuario | ✅ | ✅ green |
| 07-08-T3 | 07-08 | 3 | BILL-01..04 | T-07-24, T-07-38 | Superficie anon denegada en vivo; los embeds resuelven | script (nube) | `verify_live_schema.sh` -> `LIVE_F7_OK` | ✅ | ✅ green |
| 07-09-T1 | 07-09 | 3 | BILL-01 | T-07-41, T-07-44 | PDF de la familia del carné: encabezado con NIT, C.C., "La suma de", estado; sin Factura/IVA/DIAN ni teléfono; logo opcional | unit | `flutter test test/cobro_pdf_service_test.dart` -> `PDF_COBRO_OK` | ❌ W0 | ⬜ pending |
| 07-09-T2 | 07-09 | 3 | BILL-01 | T-07-40, T-07-42 | PDF + texto formal por la hoja de compartir; wa.me solo en la app; sin enlace público | widget | `flutter test test/compartir_cobro_test.dart` -> `ENVIAR_COBRO_OK` | ❌ W0 | ⬜ pending |
| 07-09-T3 | 07-09 | 3 | BILL-04 | T-07-43 | Marcar pagada con método y fecha; un solo acento por estado; candado en solo lectura y compartir siempre disponible | widget + suite | `flutter test test/marcar_pagada_sheet_test.dart test/cobro_detail_screen_test.dart ...` + `flutter test` -> `SLICE_PAGO_PDF_OK` | ❌ W0 | ⬜ pending |
| 07-10-T1 | 07-10 | 3 | BILL-02 | T-07-45, T-07-46, T-07-47 | Servicios: solo el admin edita; sin semilla de precios; archivar nunca borra | widget | `flutter test test/servicios_screen_test.dart` -> `SERVICIOS_OK` | ❌ W0 | ⬜ pending |
| 07-10-T2 | 07-10 | 3 | BILL-02 | — | /servicios de primer nivel sin duplicar el shell | widget/router + suite | `flutter test test/servicios_screen_test.dart` + `flutter test` -> `SLICE_SERVICIOS_OK` | ❌ W0 | ⬜ pending |
| 07-11-T1 | 07-11 | 4 | BILL-02, BILL-03 | T-07-49 | El selector muestra solo productos activos; "Agotado" no se puede elegir en una CC | widget + unit | `flutter test test/producto_cobro_sheet_test.dart test/borrador_cobro_test.dart` -> `PICKER_PRODUCTOS_OK` | ❌ W0 | ⬜ pending |
| 07-11-T2 | 07-11 | 4 | BILL-03 | T-07-48 | Tope de stock en la línea; IN001/IN002 del servidor marcan la línea exacta; se conserva la clave | widget | `flutter test test/cobro_form_screen_test.dart` -> `STOCK_FORM_OK` | ✅ (07-07) | ⬜ pending |
| 07-11-T3 | 07-11 | 4 | BILL-03 | T-07-50, T-07-51 | Historial "−2 frascos · Cuenta de cobro CC-0002" / "+2 · Anulada CC-0002"; única constante permitida | widget + unit + suite | `flutter test test/movimiento_tile_test.dart ...` + `flutter test` -> `SLICE_STOCK_OK` | ❌ W0 | ⬜ pending |
| 07-12-T1 | 07-12 | 4 | BILL-03, BILL-04 | T-07-53, T-07-54 | Anular con motivo, consecuencias, fallos en español; doble toque = una llamada | widget | `flutter test test/anular_cobro_sheet_test.dart` -> `ANULAR_SHEET_OK` | ❌ W0 | ⬜ pending |
| 07-12-T2 | 07-12 | 4 | BILL-03, BILL-04 | T-07-52 | Anular visible solo para el admin o el autor; candado en solo lectura | widget + suite | `flutter test test/cobro_detail_screen_test.dart ...` + `flutter test` -> `SLICE_ANULAR_OK` | ✅ (07-05) | ⬜ pending |
| 07-13-T1 | 07-13 | 4 | BILL-01, BILL-02 | T-07-55, T-07-56 | "Finalizar y cobrar" usa el mismo camino de completar y lleva la cita vinculada; candado solo en el cobro | widget | `flutter test test/completar_cita_screen_test.dart` -> `FINALIZAR_COBRAR_OK` | ✅ | ⬜ pending |
| 07-13-T2 | 07-13 | 4 | BILL-01 | T-07-55 | "Cobrar" / "Cobrada: CC-…" en la cita completada; un error de cobros nunca bloquea | widget + suite | `flutter test test/cita_detail_screen_test.dart ...` + `flutter test` -> `SLICE_CITA_COBRAR_OK` | ✅ | ⬜ pending |
| 07-14-T1 | 07-14 | 4 | BILL-01 | T-07-57, T-07-58, T-07-59 | "Cobrar" en el snackbar de la consulta y en el timeline; historia clínica solo-append | widget | `flutter test test/consulta_form_screen_test.dart test/historia_clinica_timeline_test.dart test/mascota_detail_screen_test.dart` -> `CONSULTA_COBRAR_OK` | ✅ | ⬜ pending |
| 07-14-T2 | 07-14 | 4 | BILL-01 | T-07-59 | "Nueva cuenta de cobro" desde el cliente (push, G5) | widget + suite | `flutter test test/cliente_detail_screen_test.dart` + `flutter test` -> `SLICE_ENTRADAS_OK` | ✅ | ⬜ pending |
| 07-15-T1 | 07-15 | 5 | BILL-01..03 | T-07-60, T-07-61 | Editar, convertir y copiar; BC002 deshabilita el envío; reemitir genera una clave nueva | unit + widget | `flutter test test/borrador_cobro_test.dart test/cobro_form_screen_test.dart` -> `MODOS_FORM_OK` | ✅ (07-07) | ⬜ pending |
| 07-15-T2 | 07-15 | 5 | BILL-01, BILL-03 | T-07-62 | Tabla de acciones completa (un acento por estado); rutas editar/convertir antes de :id | widget/router + suite | `flutter test test/cobro_detail_screen_test.dart test/router_cobros_cross_shell_test.dart ...` + `flutter test` -> `SLICE_COTIZACIONES_OK` | ✅ | ⬜ pending |
| 07-16-T1 | 07-16 | 6 | BILL-01..04 | T-07-64, T-07-67 | Gate integrado, sonda en vivo, compuertas grep (vocabulario, capas, escrituras), auditoría de marca, revisión de código, documentación | suite + script | -> `PHASE7_GATE_OK` | ✅ | ⬜ pending |
| 07-16-T2 | 07-16 | 6 | BILL-01..04 | T-07-63, T-07-65 | UAT en emulador contra el proyecto vivo (F1..F12) | manual (vetapp-qa) | -> `QA_REPORT_OK` + `QA: PASS` | ✅ | ⬜ pending |
| 07-16-T3 | 07-16 | 6 | BILL-01..04 | T-07-66 | Visto bueno del usuario | manual (usuario) | -> `SIGNOFF_RECORDED` + respuesta literal | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

### Cobertura de requisitos

| Req | Planes |
|-----|--------|
| BILL-01 (cotización o cuenta de cobro en PDF) | 01, 02, 03, 04, 05, 06, 07, 08, 09, 13, 14, 15, 16 |
| BILL-02 (uno o más ítems con precio) | 01, 02, 04, 07, 10, 11, 13, 14, 15, 16 |
| BILL-03 (descuento automático de stock) | 01, 02, 08, 11, 12, 15, 16 |
| BILL-04 (pagada / pendiente) | 01, 02, 04, 05, 08, 09, 12, 16 |

---

## Wave 0 Requirements

- [ ] `test/helpers/fake_cobros.dart`: `FakeCobrosRepository` con estado, numeración por tipo, repetición por clave, errores por método, `llamadas` y `bloqueoCrear`; también `cobroDePrueba`, `servicioDePrueba` y `clinicaPdfDePrueba` (07-02).
- [ ] `test/helpers/fake_compartir_cobro.dart`: `CompartirCobroFalso` (07-09).
- [ ] Pruebas nuevas:
  - `cobro_test`, `supabase_cobros_repository_test`, `cobros_invalidacion_test`;
  - `clave_idempotencia_test`, `pesos_en_letras_test`, `whatsapp_cobro_test`;
  - `cobros_screen_test`, `cobro_detail_screen_test`, `cobrar_boton_test`, `router_cobros_cross_shell_test`;
  - `borrador_cobro_test`, `cobro_form_screen_test`;
  - `cobro_pdf_service_test`, `compartir_cobro_test`, `marcar_pagada_sheet_test`;
  - `servicios_screen_test`, `producto_cobro_sheet_test`, `movimiento_tile_test`, `anular_cobro_sheet_test`.
- [ ] Extender las pruebas existentes (solo adiciones, salvo el conjunto de claves de `clinica_contrato_test`):
  - `formato_test`, `cliente_detail_screen_test`;
  - `clinica_contrato_test`, `guardar_datos_clinica_test`, `datos_clinica_screen_test`;
  - `supabase_inventario_repository_test`;
  - `completar_cita_screen_test`, `cita_detail_screen_test`, `cita_solo_lectura_test`, `whatsapp_acciones_test`;
  - `consulta_form_screen_test`, `historia_clinica_timeline_test`, `mascota_detail_screen_test`.
- [ ] Bloque T (T1..T30) en `supabase/tests/rls_smoke_test.sql`, R44 a 13 tablas y cabecera "Total esperado: 291."
- [ ] Sondas de facturación en `supabase/tests/verify_live_schema.sh`
- [ ] Framework: nada que instalar (sin paquetes nuevos; `uuid` sigue siendo solo transitivo)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Delta Fase 7 aplicado y smoke en vivo | BILL-01..04 | Solo el usuario corre el smoke en el SQL Editor; el clasificador de MCP lo bloquea | 07-08 T2: autorizar `apply_migration fase_07_facturacion`, pegar `rls_smoke_test.sql` completo y reportar la línea literal `RLS SMOKE: PASS (291 checks) - cambios revertidos` |
| Dos sesiones emitiendo a la vez obtienen números consecutivos | BILL-01 (D-02) | Un bloque `do $$` de una sola sesión no prueba concurrencia real | Opcional en 07-08: dos pestañas del SQL Editor emiten una CC en la misma clínica QA al mismo tiempo; anotar los números o "no ejecutado" |
| Flujos completos en el emulador contra el proyecto vivo | BILL-01..04 | Hoja de compartir del sistema, modo avión y solo lectura real del servidor | 07-16 T2: `vetapp-qa`, flujos F1..F12 |
| PDF adjunto a un chat real de WhatsApp | BILL-01 (D-16) | El emulador no tiene WhatsApp y el usuario solo tiene iPhone | Opcional, cuando exista build de iOS; registrar el resultado o "pendiente de dispositivo" |
| Revisión del formato de cuenta de cobro con un contador | BILL-01 (D-01, RESEARCH A1-A3) | Es una decisión legal, no de código | Pendiente del usuario antes de cobrar la facturación a clínicas; se registra como ítem abierto en 07-16 T3 |
| Visto bueno del usuario | BILL-01..04 | Aprobación humana | 07-16 T3: respuesta literal |

---

## Evidencia de ejecución por plan

*Se completa una fila por plan al ejecutarlo: comandos, resultado, pruebas por archivo, fecha y commit (pm-vetapp §6; memoria "verify + document each plan").*

| Plan | Comandos | Resultado | Pruebas | Fecha | Commit |
|------|----------|-----------|---------|-------|--------|
| 07-01 | smoke T1..T23 + SQL Fase 7A; gates del plan | `SMOKE_T_A_OK` · `SCHEMA_F7A_TABLAS_OK` · `SCHEMA_F7A_OK`; Postgres local desechable: `RLS SMOKE: FAIL (63 de 284 checks)` antes → `RLS SMOKE: PASS (284 checks) - cambios revertidos` después; `mover_stock` idéntico | smoke 284 (en vivo en 07-08) | 2026-11-13 | `eea80bb` |
| 07-02 | TDD por tarea; `flutter analyze` + `flutter test` | `DOMINIO_COBRO_OK` · `REPO_COBROS_OK` · `CONTRATO_COBROS_OK` | cobro 14, supabase_cobros_repository 29, cobros_invalidacion 19 | 2026-11-13 | `0e7ff17` |
| 07-03 | TDD por tarea; `flutter analyze` + `flutter test` | `HELPERS_CLAVE_LETRAS_OK` · `PUBSPEC_UNCHANGED` · `HELPERS_WA_DOC_OK` | helpers +47 (clave, letras, whatsapp, formato) | 2026-11-13 | `3225cb5` |
| Ola 1 (master) | gate integrado | `No issues found!` · `00:38 +1154: All tests passed!` | suite completa | 2026-11-13 | `eea80bb` |
| 07-04 | smoke T24..T30 + SQL Fase 7B + sondas anon | `SMOKE_T_B_OK` · `SCHEMA_F7B_OK` · `PROBE_F7_OK`; Postgres local desechable: `RLS SMOKE: FAIL (13 de 291 checks)` antes → `RLS SMOKE: PASS (291 checks) - cambios revertidos` después; mutaciones detectadas (T25, T27); `mover_stock` idéntico | smoke 291 (en vivo en 07-08) | 2026-11-13 | `728277a` |
| 07-05 | TDD por tarea; `flutter analyze` + `flutter test` | `LISTA_COBROS_OK` · `DETALLE_LECTURA_OK` · `SLICE_LISTA_OK`; `grep -rni factur lib` vacío | cobros_screen 23, detalle y entradas 19, router 5 | 2026-11-13 | `081e2c3` |
| 07-06 | TDD por tarea; `flutter analyze` + `flutter test` | `CEDULA_CLIENTE_OK` · `NIT_CLINICA_OK` | clientes 53, clínica 44 (solo adiciones a pruebas existentes) | 2026-11-13 | `82e6d64` |
| Ola 2 (master) | gate integrado | `No issues found!` · `01:05 +1217: All tests passed!` | suite completa | 2026-11-13 | `081e2c3` |
| 07-08 | `apply_migration` fase_07_facturacion_a + _b (MCP, con OK del usuario); consultas de solo lectura; smoke pegado por el usuario; `verify_live_schema.sh` | `PREAPPLY_F7_OK` · `{"success":true}` x2 · tablas 0/0/0/0 · guarda en 13 tablas · `actualizar_clinica` de 6 argumentos · `RLS SMOKE: PASS (291 checks) - cambios revertidos` · `LIVE_SCHEMA_OK` · `LIVE_F7_OK` (tras arreglar el embed autorreferente, PGRST200) | smoke 291 en vivo; regresión `cobros_select_embed_test` | 2026-11-13 | `d86965c` |

---


## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (se marca al ejecutar)
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending (07-16)
