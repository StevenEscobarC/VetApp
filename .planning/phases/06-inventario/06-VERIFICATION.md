---
phase: 06-inventario
verified: 2026-11-13T00:00:00Z
status: passed
score: 3/3 must-haves verified
overrides_applied: 0
re_verification: false
accepted_deviations:
  - item: "F7 (solo lectura) no corrido en vivo en el emulador"
    reason: "No había sesión del colega (solo lectura aplica al miembro que excede cupos). Cubierto por el smoke R44 (guard_solo_lectura en 9 tablas, incluidas productos y movimientos_inventario) y por tests de widget."
    accepted_by: "usuario (visto bueno 'Aprobado', 06-09)"
    accepted_at: "2026-11-13"
  - item: "Deuda WR-03, WR-05, WR-06 (06-REVIEW.md) queda abierta"
    reason: "Aceptada por el usuario; no impide ningún criterio de éxito."
    accepted_by: "usuario"
    accepted_at: "2026-11-13"
---

# Phase 6: Inventario — Verification Report

**Phase Goal:** El veterinario puede controlar el stock de medicamentos/insumos y anticipar cuándo reabastecer.
**Mode:** mvp
**Verified:** 2026-11-13
**Status:** passed
**Re-verification:** No (verificación inicial)

## User Flow Coverage (MVP)

| Paso | Esperado | Evidencia en el código | Estado |
|------|----------|------------------------|--------|
| Entrar a Inventario | Más > Inventario abre la lista | `lib/features/home/presentation/screens/mas_screen.dart:207` (`context.push(rutaInventario())`), rutas registradas en `lib/core/router/app_router.dart:94` (`...inventarioRoutes`) | ✓ |
| Registrar producto | Nombre, cantidad inicial y stock mínimo → RPC real | Form `producto_form_screen.dart:641,663,680` → `inventarioActionsProvider.crear` `:168-177` → repo `supabase_inventario_repository.dart:76-99` (`rpc('crear_producto')`) → `schema.sql:4269-4310` | ✓ |
| Ver aviso de stock bajo | Tarjeta en Inicio, pastilla en Más, insignia y filtro "Bajos" | `inicio_screen.dart:91` (`StockBajoCard`), `stock_bajo_card.dart:20-21` lee `resumenInventarioProvider` → `rpc('inventario_resumen')` repo `:171-172` → `schema.sql:4479-4502` (`cantidad < minimo`) | ✓ |
| Ajustar cantidad | −1/+ rápido, hoja Ajustar (Compra/Uso/Vencido/Conteo), Deshacer | `ajuste_stock.dart:141-143`, `ajuste_sheet.dart:191-199`, `ajuste_stock.dart:114` (deshacer) → repo `:131-155` (`rpc('mover_stock')`) → `schema.sql:4399-4475` | ✓ |
| Anticipar reabastecimiento (outcome) | Filtro Bajos/Vence pronto + "Pedir por WhatsApp" | `inventario_screen.dart:270-272` (filtros), `:227` (Pedir por WhatsApp), `domain/pedido_whatsapp.dart` | ✓ |

## Goal Achievement

### Observable Truths

| # | Truth (ROADMAP SC) | Status | Evidence |
|---|-------|--------|----------|
| 1 | El veterinario puede registrar un producto/insumo con nombre, cantidad y umbral de stock mínimo | ✓ VERIFIED | Tabla `productos` con `nombre`, `cantidad`, `minimo` (`supabase/schema.sql:4187-4204`); RPC `crear_producto` security definer con chequeo `es_veterinario()`+`mi_clinica_id()` y movimiento `alta` (`schema.sql:4269-4310`), grant a `authenticated` (`:4536-4537`). Cliente: campos en `producto_form_screen.dart:641` (Nombre), `:663` (Cantidad inicial), `:680` (Stock mínimo); llamada real `:168-177` → `inventario_providers.dart:75-97` → `supabase_inventario_repository.dart:86` `rpc('crear_producto')`. Nombre duplicado mapeado a error de campo (`producto_form_screen.dart:~198`). Lista lee `from('productos')` sin archivados (`repo:56-62`). |
| 2 | El veterinario recibe una alerta cuando un producto cae por debajo del umbral | ✓ VERIFIED | D-08 (06-CONTEXT.md:32) define la alerta como in-app sin push. Servidor: `inventario_resumen` cuenta `cantidad < minimo` de activos (`schema.sql:4496,4500`). Cliente: `StockBajoCard` en Inicio (`inicio_screen.dart:91`; `stock_bajo_card.dart:20-24`, navega a `rutaInventario(bajos: true)` `:42`); pastilla "N bajos" en Más (`mas_screen.dart:82-83,201-223`); insignia "Bajo" (`insignia_stock.dart:13`, `producto_fila.dart:34`) usando `Producto.bajo => cantidad < minimo` (`producto.dart:95`); filtro Bajos (`inventario_screen.dart:271`). Refresco tras cualquier mutación: `invalidarInventario` invalida `resumenInventarioProvider` (`inventario_providers.dart:52-57`), llamado en crear/actualizar/archivar/_mover (`:96,118,122,166`). Test `router_inventario_cross_shell_test.dart` "tras un ajuste el pill y la tarjeta se refrescan" pasa. |
| 3 | El veterinario puede ajustar manualmente la cantidad de un producto | ✓ VERIFIED | `mover_stock` es la única vía de cambio de `cantidad` (privilegios de escritura revocados `schema.sql:4264-4265`), bloquea la fila `for update` (`:4438-4440`), rechaza negativos IN001 (`:4460-4463`), concurrencia optimista del conteo IN004 (`:4445-4447`, CR-01), deshacer solo de ajustes (`:4449-4458`, WR-04), y escribe el movimiento append-only con autoría (`:4467-4471`). Cliente: botones rápidos (`ajuste_rapido_botones.dart`, montados en `producto_fila.dart:127`), hoja Ajustar (`ajuste_sheet.dart:191-199`, envía `cantidadEsperada` solo en conteo), deshacer (`ajuste_stock.dart:114`), detalle con historial (`producto_detail_screen.dart:223`; `repo:158-169` con autor). Errores tipados IN001..IN004 (`repo:~290-294`). |

**Score:** 3/3 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `supabase/schema.sql` (bloque Fase 6, 4176-4547) | Tablas, RLS solo-lectura, 5 RPC definer, guard, grants | ✓ VERIFIED | Sustantivo y aplicado en vivo (probe `LIVE_SCHEMA_OK`, las 5 RPC y ambas tablas responden 401 a anon) |
| `lib/features/inventory/data/repositories/supabase_inventario_repository.dart` (332 l.) | Acceso real a Supabase | ✓ VERIFIED | `from('productos')`, `from('movimientos_inventario')`, 5 `rpc(...)` con nombres/params que coinciden con el schema |
| `lib/features/inventory/presentation/providers/inventario_providers.dart` | Providers Riverpod + acciones con invalidación | ✓ VERIFIED | Wired desde form, hoja, ajuste rápido, detalle, Inicio y Más |
| `lib/features/inventory/presentation/screens/*` (lista, form, detalle) | UI completa | ✓ VERIFIED | Rutas de primer nivel en `inventario_routes.dart`, registradas en `app_router.dart:94` |
| `lib/features/inventory/presentation/widgets/stock_bajo_card.dart` | Alerta en Inicio | ✓ VERIFIED | Montada en `inicio_screen.dart:91` |
| `supabase/tests/rls_smoke_test.sql` (bloque S, 23 checks, total 261) | Pruebas RLS/RPC | ✓ VERIFIED (estático) | Cabecera "Total esperado: 261" (línea 37); PASS 261 en vivo registrado en `06-VALIDATION.md:138` (lo pega el usuario; no re-ejecutable por el verificador) |

### Key Link Verification

| From | To | Via | Status |
|------|----|-----|--------|
| `producto_form_screen.dart` | `crear_producto` | `inventarioActionsProvider.crear` → `repo.crearProducto` → `rpc` | ✓ WIRED |
| `ajuste_sheet.dart` / `ajuste_stock.dart` | `mover_stock` | `actions.ajustar/deshacer` → `repo.moverStock` → `rpc` | ✓ WIRED |
| `StockBajoCard` / `mas_screen.dart` | `inventario_resumen` | `resumenInventarioProvider` → `repo.resumen` → `rpc` | ✓ WIRED |
| Mutaciones | Alerta de Inicio/Más | `invalidarInventario` invalida `resumenInventarioProvider` | ✓ WIRED |
| `app_router.dart` | Pantallas de inventario | `...inventarioRoutes` (`app_router.dart:94`) | ✓ WIRED |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `InventarioScreen` | `productosProvider` | `from('productos').select().isFilter('archivado_at', null)` | Sí (RLS por clínica) | ✓ FLOWING |
| `StockBajoCard`, pill de Más | `resumenInventarioProvider.bajos` | RPC `inventario_resumen` (count filtrado) | Sí | ✓ FLOWING |
| `ProductoDetailScreen` historial | `movimientosProvider` | `from('movimientos_inventario')` con join al autor | Sí | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Análisis estático | `flutter analyze` | `No issues found!` | ✓ PASS |
| Suite de inventario (12 archivos: producto, form, detalle, lista, invalidación, ajuste rápido, hoja, tarjeta, pedido, repositorio, router cross-shell, inicio) | `flutter test <12 archivos>` | `+190: All tests passed!` | ✓ PASS |

La suite completa (+1045 según 06-09/06-10) no se re-corrió aquí; se corrieron todos los tests de la fase.

### Probe Execution

| Probe | Command | Result | Status |
|-------|---------|--------|--------|
| `supabase/tests/verify_live_schema.sh` | `bash supabase/tests/verify_live_schema.sh` | exit 0, 70 líneas `OK`, `LIVE_SCHEMA_OK`; incluye `productos`/`movimientos_inventario` protegidas 401 y las 5 RPC de inventario protegidas 401 | ✓ PASS |

Nota: con `timeout 30s` el probe se cortó (exit 124) por latencia de red; con 180 s terminó en 44 s con exit 0. No es un defecto de la fase. Convendría subir el timeout del probe o ejecutarlo en paralelo.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| INV-01 | 06-01, 02, 03, 05, 08, 09 | Registrar producto con nombre, cantidad y mínimo | ✓ SATISFIED | Truth 1 |
| INV-02 | 06-01, 02, 07, 09 | Alerta bajo el mínimo | ✓ SATISFIED | Truth 2 (in-app según D-08) |
| INV-03 | 06-01, 02, 06, 08, 09, 10 | Ajuste manual de cantidad | ✓ SATISFIED | Truth 3 |

No hay requisitos huérfanos: REQUIREMENTS.md asigna a la Fase 6 solo INV-01..03.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/features/inventory/**`, tests de inventario | — | TBD/FIXME/XXX/TODO/HACK | — | Ninguno encontrado |
| `supabase/schema.sql` `crear_producto` | 4269-4310 | Sin chequeo `es_admin_clinica()` para precios/mínimo (WR-06) | ℹ️ Info (deuda aceptada) | Un veterinario no admin puede fijar precios al crear |
| `actualizar_producto` / UI de edición | 4343-4348 | Falso "solo admin" con edición concurrente (WR-05) | ℹ️ Info (deuda aceptada) | UX |
| `mover_stock` | 4399 | No idempotente; un ajuste guardado justo antes de perder la red se reporta como no guardado (WR-03) | ℹ️ Info (deuda aceptada) | Posible duplicado al reintentar |

### Bookkeeping (Info, no bloquea)

- `.planning/ROADMAP.md:341,366`: muestra "8/9 plans executed" y 06-09 sin marcar, aunque `06-09-SUMMARY.md` registra el visto bueno ("Aprobado").
- `.planning/REQUIREMENTS.md:78-80,161`: INV-01..03 siguen como `[ ]` / Pending.
- `06-VALIDATION.md:102` aún dice "❌ pendiente del usuario: re-aplicar `mover_stock` en vivo", pero `:138` y el commit `9930428` registran el apply en vivo y `RLS SMOKE: PASS (261 checks)`. La fila 102 está desactualizada.

Lo normal es que el orquestador actualice estos tres puntos al cerrar la fase.

### Human Verification Required

Ninguna pendiente. Las dos verificaciones humanas posibles ya están cubiertas:
- F7 en vivo (solo lectura): desviación aceptada por el usuario (ver frontmatter).
- F5, el envío real por WhatsApp desde un teléfono físico: QA en emulador PASS hasta la hoja de compartir. El usuario dio el visto bueno sobre ese resultado.

### Gaps Summary

No hay gaps. Los tres criterios de éxito se cumplen con un camino completo y conectado de UI → Riverpod → repositorio → RPC/tabla de Supabase en vivo. El servidor asegura los invariantes: sin escritura directa, fila bloqueada, sin negativos, libro append-only con autoría, aislamiento por clínica y guard de solo lectura. La alerta de stock bajo se recalcula en el servidor y se refresca tras cada mutación. La deuda abierta (WR-03, WR-05, WR-06) está aceptada y no afecta al objetivo.

---

_Verified: 2026-11-13_
_Verifier: Claude (gsd-verifier)_

VERIFICATION: passed
