# Phase 6: Inventario - Research

**Researched:** 2026-10-31
**Domain:** Inventario multi-tenant en Supabase (Postgres/RLS/RPC) + Flutter/Riverpod a mano
**Confidence:** HIGH (todo el stack y los patrones salen del repo; la semantica de concurrencia esta verificada contra la documentacion de PostgreSQL)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

Todas las areas quedaron a criterio de Claude: el usuario no eligio ninguna para discutir (2026-10-31) y se tomaron las recomendaciones de la investigacion previa con `vetapp-opportunity-research`. El usuario puede revisar y cambiar cualquier decision antes de `/gsd-plan-phase 6`.

**Modelo de stock**
- **D-01:** El stock es de la **clinica** (`clinica_id`, RLS multi-tenant como el resto del esquema), no del veterinario. Cada producto y cada movimiento guardan quien los creo. El stub `lib/features/inventory/domain/entities/producto.dart` (cuelga de `veterinarioId`, usa `double`, `stockBajo` con `<=`) se reescribe; no es contrato.
- **D-02:** El stock se mueve solo por **movimientos que solo se agregan** (tabla de movimientos, como la historia clinica) aplicados por una **RPC atomica** del estilo `mover_stock(producto, delta, motivo, origen, ref_id)` que actualiza la cantidad en la misma transaccion. Asi dos veterinarios no se pisan y la Fase 7 reutiliza la RPC con `origen = 'factura'`. Origenes previstos: `ajuste` (esta fase), `alta` (cantidad inicial), y reservados `dosis` y `factura` (fases siguientes).
- **D-03:** **Una sola unidad de conteo por producto**, elegida con chips (unidad, tableta, frasco, ml, dosis, caja, kg). **Cantidades enteras.** Sin conversion de presentaciones (caja -> tabletas) ni fracciones.
- **D-04:** **Sin stock negativo:** el ajuste manual no puede dejar la cantidad por debajo de 0 (validado en el servidor). La Fase 7 decide si permite vender en negativo.

**Vacunas y vencimientos**
- **D-05:** Registrar una dosis **no descuenta inventario en esta fase**. El origen `dosis` queda reservado en los movimientos; el selector opcional "Producto de inventario" en Registrar dosis se planea como fase 6.x o junto a la 7 (toca `registrar_dosis`).
- **D-06:** **Vencimiento opcional y unico por producto** (sin lotes multiples) y chip "Vence pronto" a 30 dias o menos. El lote sigue viviendo en la dosis aplicada (Fase 5), que es donde el certificado lo necesita.

**Avisos y ajuste rapido**
- **D-07:** "Stock bajo" es **cantidad estrictamente menor que el minimo** (`<`), literal a INV-02 ("cae por debajo del umbral"). Un producto con minimo 0 nunca esta bajo.
- **D-08:** El aviso vive **dentro de la app**, sin push (igual que Fase 5 D-10): tarjeta en Inicio ("N productos con stock bajo", como en `.planning/design/DESIGN-REFERENCE.md`), insignia "Bajo" en la lista y filtro "Bajos". La tarjeta solo aparece si hay al menos uno.
- **D-09:** **Ajuste rapido desde la fila** de la lista: botones -1 y +N de 48 dp y chips de motivo (Compra, Uso, Vencido o danado, Conteo). Confirmacion solo para ajustes grandes (mas de 10 unidades); para el resto, snackbar con "Deshacer" (que aplica el movimiento inverso, no borra).
- **D-10:** **Alta en un solo paso:** nombre + cantidad + minimo (prellenado, p. ej. 2) y unidad; categoria, vencimiento y precios en "Mas detalles". El nombre puede autocompletarse con el catalogo de biologicos de la Fase 5 si sale barato; si no, queda para despues.
- **D-11:** **"Pedir por WhatsApp"** desde el filtro de bajos: arma un texto con los productos en bajo y una cantidad sugerida (minimo x 2 - stock) y abre la hoja de compartir del sistema (sin destinatario fijo). Reutiliza los helpers de compartir y WhatsApp existentes. Si complica el plan, es lo primero que se corta.
- **D-12:** Sin conexion el ajuste falla con un mensaje claro (no hay cola offline en esta fase).

**Permisos, plan y precio**
- **D-13:** **Cualquier veterinario activo** de la clinica crea productos y mueve stock, siempre con motivo y autoria. **Solo el admin** archiva productos (borrado logico, nunca fisico) y cambia minimo y precios. Igual que Fase 5 D-24 con protocolos.
- **D-14:** Los colegas en **solo lectura** (Fase 5.1, tras la gracia) **no** pueden crear ni mover stock: el guard de solo lectura se extiende a las tablas nuevas y la UI usa el mismo tratamiento de candado (`ControlEscritura`, `limite_plan_gate`).
- **D-15:** El inventario entra en **todos los planes sin limite nuevo**: se mantiene la regla de solo 4 limites por plan (Fase 5.1 D-01). Si negocio quiere un tope en Gratis, se decide aparte.
- **D-16:** **Precio de venta opcional en COP entero** (lo necesita la Fase 7) y **costo opcional** escondido en "Mas detalles". Sin IVA hasta la Fase 7. Formato COP sin decimales de `lib/core/utils/formato.dart`.

### Claude's Discretion
- Todas las decisiones D-01..D-16 (el usuario delego todas las areas).
- Nombres exactos de tablas, RPC y pantallas; ubicacion del inventario en la navegacion (probablemente desde Mas o una entrada en Inicio, sin cambiar las 5 ramas del shell).

### Deferred Ideas (OUT OF SCOPE)
- Descontar stock al registrar una dosis (selector "Producto de inventario" en Registrar dosis) - fase 6.x o junto a la Fase 7.
- Maletin de domicilio / varias bodegas, lotes multiples, proveedores y ordenes de compra, codigo de barras, conversion de presentaciones, notificaciones push, IVA y facturacion DIAN - v2 o Fase 7.
- Limite de productos por plan (p. ej. en Gratis) - solo si negocio lo decide.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| INV-01 | Registrar producto/insumo con nombre, cantidad y umbral de stock minimo | Tablas `productos` + `movimientos_inventario`; RPC `crear_producto` (inserta producto y movimiento `alta` en una transaccion); alta de un paso con minimo prellenado 2; entidad `Producto` reescrita |
| INV-02 | Alerta cuando un producto cae por debajo del umbral | Regla unica `cantidad < minimo` (D-07); RPC `inventario_resumen()` para la tarjeta de Inicio (patron `vacunas_resumen`); insignia "Bajo" + filtro "Bajos" en la lista |
| INV-03 | Ajuste manual de la cantidad | RPC atomica `mover_stock` (bloqueo de fila, sin negativos, movimiento con autoria y motivo); ajuste rapido -1/+N, deshacer por movimiento inverso |
</phase_requirements>

## Summary

La Fase 6 es una fase de **datos + una lista movil rapida**. Todo lo que necesita ya existe en el repo: el patron de RLS por `clinica_id` con `es_veterinario()`/`mi_clinica_id()`, el patron "solo-append + RPC" de `dosis_aplicadas`/`registrar_dosis` (Fase 5), el guard de solo lectura `guard_solo_lectura` (Fase 5.1), el patron de resumen para Inicio (`vacunas_resumen` -> `VacunasPendientesCard`), `Compartidor` para WhatsApp/compartir, `ControlEscritura`/`asegurarEscritura` para candados y `AppFilterChip` (cuyo doc ya anticipa "Inventario"). **No hace falta ninguna dependencia nueva.**

Cuatro hallazgos cambian lo que el planner debe asumir. (1) **Las RPC de stock deben ser `security definer`, no `invoker`** como pide el brief: si `mover_stock` fuera `invoker`, la politica UPDATE que necesitaria sobre `productos` permitiria a cualquier veterinario cambiar `cantidad` por PostgREST sin dejar movimiento, rompiendo D-02. Se sigue el patron de Fase 5 (`registrar_dosis` es `security definer`, tablas con solo SELECT y escrituras revocadas, chequeos explicitos `es_veterinario()` + `mi_clinica_id()` dentro). (2) **No existe helper de COP** en `lib/core/utils/formato.dart` (CONTEXT D-16 asume que si; `colombia.md` lo confirma): hay que crear `formatearCop`/`parsearCop` + prueba. (3) **R44 hay que editarlo**: hoy exige `guard_solo_lectura` en exactamente 7 tablas; pasa a 9 (`productos`, `movimientos_inventario`). (4) **`es_autor_en_mi_clinica` debe redefinirse** (ultima vez en Fase 5 para dosis) para incluir `movimientos_inventario`, o el nombre de un veterinario retirado desaparece del historial de movimientos.

**Primary recommendation:** Un solo bloque idempotente "Fase 6" al final de `supabase/schema.sql` (antes de `notify pgrst`) con `productos`, `movimientos_inventario`, RPC `crear_producto`/`actualizar_producto`/`archivar_producto`/`mover_stock`/`inventario_resumen` (todas `security definer`, `search_path = public`), guard en las 2 tablas, redefinicion de `es_autor_en_mi_clinica`; en Flutter, feature `inventory` completa (repositorio `SupabaseInventarioRepository` + `InventarioFailure`, providers a mano, rutas de primer nivel `/inventario...` empujadas desde Mas y desde la tarjeta de Inicio) y un bloque S nuevo en el smoke test.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Aislamiento por clinica (quien ve que producto) | Database (RLS) | — | Multi-tenencia vive en RLS (`clinica_id = mi_clinica_id()`); el cliente no filtra |
| Invariante "cantidad solo cambia por movimientos" + sin negativos | Database (RPC `mover_stock` + CHECK) | — | Atomicidad y concurrencia solo se garantizan en el servidor (D-02, D-04) |
| Regla de stock bajo (`cantidad < minimo`) | Database (RPC `inventario_resumen`) | Flutter (getter `Producto.bajo`) | Una definicion en SQL para la tarjeta; el getter Dart para insignia/filtro sobre la lista ya cargada; ambas con la misma prueba de borde |
| Permisos admin-only (archivar, minimo, precios) | Database (chequeo en RPC) | Flutter (ocultar/bloquear controles) | La UI es cortesia; el servidor es la autoridad |
| Solo lectura por plan (D-14) | Database (trigger `guard_solo_lectura`) | Flutter (`ControlEscritura`, `asegurarEscritura`) | Mismo modelo que Fase 5.1: el servidor decide, la UI explica |
| Busqueda/filtro instantaneo de la lista | Flutter (sobre lista cargada) | — | Una clinica pequena tiene decenas/cientos de productos; una consulta + filtro local da busqueda instantanea y sin red |
| Formato COP / fechas dd/mm/aaaa / vence pronto | Flutter (`core/utils`) | Database (`_hoy_bogota()` para el conteo) | Presentacion en cliente; el conteo de "por vencer" usa fecha Bogota en SQL |
| "Pedir por WhatsApp" | Flutter (`Compartidor`) | — | Texto armado en dominio puro; hoja nativa de compartir, sin destinatario |
| Navegacion al inventario | Flutter (`go_router`, rutas de primer nivel) | — | Sin tocar las 5 ramas del shell (ver patron G5) |

## Standard Stack

No hay paquetes nuevos. Todo se resuelve con lo ya instalado (`pubspec.yaml`, verificado en el repo).

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_riverpod | ^3.3.2 | Providers a mano (`FutureProvider.autoDispose`, clase de acciones) | Convencion del repo; sin generador [VERIFIED: pubspec.yaml + arquitecto-vetapp SKILL] |
| go_router | ^17.3.0 | Rutas `/inventario...` de primer nivel | Unico router (`app_router.dart`) [VERIFIED: codebase] |
| supabase_flutter | ^2.9.1 (lock 2.17.2) | `.from('productos')`, `.rpc('mover_stock')` | Unica integracion backend [VERIFIED: pubspec.lock via CLAUDE.md] |
| share_plus | ^13.3.1 | "Pedir por WhatsApp" via `Compartidor` | Ya envuelto en `lib/core/utils/compartir.dart` [VERIFIED: codebase] |
| intl | ^0.20.3 | Solo fechas numericas (`formatearFecha`) | COP se agrupa a mano (ver Don't Hand-Roll) |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_test | SDK | Todas las pruebas (fakes a mano) | Unico framework de pruebas del repo |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `security definer` + escrituras revocadas | `security invoker` + politica UPDATE + trigger que bloquee cambios directos de `cantidad` | Cumple la letra del brief pero agrega un trigger fragil; Fase 5 ya fijo el patron definer para tablas "solo-append" |
| Lista completa + filtro local | Query con `ilike` por tecla | Mas viajes de red; la meta es "busqueda instantanea" con una mano |
| Columna generada `bajo` | Getter Dart + expresion SQL en el RPC | La columna evita duplicar la regla pero agrega superficie de schema; se prefiere 1 expresion SQL (en `inventario_resumen`) + 1 getter, ambas con prueba de borde |

**Installation:** ninguna (`flutter pub get` sin cambios).

## Package Legitimacy Audit

Esta fase **no instala paquetes externos nuevos**, por lo que no aplica la verificacion slopcheck. Los paquetes que se usan ya estan en `pubspec.yaml`/`pubspec.lock` desde fases anteriores.

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
                        ENTRADAS (UI)
  Inicio: StockBajoCard ──push('/inventario?filtro=bajos')──┐
  Mas:    fila "Inventario" ──push('/inventario')───────────┤
                                                            v
   /inventario (lista)  ──tap fila──>  /inventario/:id (detalle + historial)
     |  busqueda local / chips Todos|Bajos|Vence pronto         |
     |  fila: [-1] [+N] + chips de motivo                       | editar (admin: minimo/precios; archivar)
     |  "Pedir por WhatsApp" (solo filtro Bajos)                |
     v                                                          v
   /inventario/nuevo (alta de un paso + "Mas detalles")
     |
     |   asegurarEscritura()  (cortesia UX; LP004 = respaldo del servidor)
     v
  InventarioActions (Ref)  ──invalida──> productosProvider, resumenInventarioProvider, movimientosProvider(id)
     |
     v
  SupabaseInventarioRepository  ──PostgrestException──> InventarioFailure (mensajeErrorInventario)
     |  .rpc('crear_producto' | 'mover_stock' | 'actualizar_producto' | 'archivar_producto')
     |  .from('productos') / .from('movimientos_inventario')  (solo SELECT)
     |  .rpc('inventario_resumen')
     v
  ───────────────────────── Supabase (Postgres) ─────────────────────────
  RPC (security definer, search_path=public, chequea es_veterinario()+mi_clinica_id())
     |-- trigger guard_solo_lectura (before ins/upd/del) --> LP004 si el colega esta en solo lectura
     |-- SELECT ... FOR UPDATE productos -> validar (>=0, no archivado) -> UPDATE cantidad
     |-- INSERT movimientos_inventario (append-only, cantidad_resultante, autoria)
     v
  productos (RLS select por clinica)   movimientos_inventario (RLS select; sin update/delete)
```

### Recommended Project Structure
```
lib/features/inventory/
├── domain/
│   ├── entities/producto.dart            # REESCRIBIR (int, clinicaId, bajo con <, venceEn)
│   ├── entities/movimiento_stock.dart    # delta, motivo, origen, cantidadResultante, autor, fecha
│   ├── inventario_failure.dart           # implements Exception, ConLimitePlan
│   ├── pedido_whatsapp.dart              # texto puro: minimo*2 - stock
│   └── stock.dart                        # constantes: umbral vence pronto (30), ajuste grande (10), minimo por defecto (2)
├── data/repositories/supabase_inventario_repository.dart   # _fromRow, mensajeErrorInventario
└── presentation/
    ├── inventario_routes.dart            # List<GoRoute> inventarioRoutes + rutaInventario(...)
    ├── providers/inventario_providers.dart   # repo, productosProvider, resumenInventarioProvider, movimientosProvider.family, InventarioActions
    ├── screens/{inventario_screen,producto_form_screen,producto_detail_screen}.dart
    └── widgets/{producto_fila,ajuste_rapido,stock_bajo_card,chip_stock}.dart
lib/core/utils/formato.dart               # AGREGAR formatearCop / parsearCop
test/helpers/fake_inventario.dart
```

### Pattern 1: Esquema (idempotente, un solo bloque al final de `schema.sql`)
**What:** tablas + RPC + RLS + guard, re-ejecutable. Va **despues** del bloque 5.1 y **antes** de `notify pgrst, 'reload schema';` (las funciones `language sql` validan sus referencias al crearse, asi que las tablas van primero; `es_autor_en_mi_clinica` se redefine al final del bloque).
**Example (esqueleto prescriptivo; nombres sugeridos, ajustables):**
```sql
-- Fase 6 · Inventario
create table if not exists public.productos (
  id uuid primary key default gen_random_uuid(),
  clinica_id uuid not null references public.clinicas(id) on delete cascade,
  nombre text not null check (char_length(btrim(nombre)) between 1 and 80),
  categoria text not null default 'medicamento'
    check (categoria in ('medicamento','insumo','alimento','otro')),
  unidad text not null
    check (unidad in ('unidad','tableta','frasco','ml','dosis','caja','kg')),
  cantidad int not null default 0
    constraint productos_cantidad_no_negativa check (cantidad >= 0 and cantidad <= 1000000),
  minimo int not null default 2 check (minimo between 0 and 1000000),
  vencimiento date null,
  precio_venta_cop int null check (precio_venta_cop is null or precio_venta_cop between 0 and 100000000),
  costo_cop int null check (costo_cop is null or costo_cop between 0 and 100000000),
  creado_por uuid not null references public.perfiles(id) on delete restrict,
  archivado_at timestamptz null,
  archivado_por uuid null references public.perfiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, clinica_id)
);
-- Sin duplicados activos por clinica (insensible a mayusculas); archivar libera el nombre.
create unique index if not exists productos_clinica_nombre_activo_uq
  on public.productos (clinica_id, lower(btrim(nombre))) where archivado_at is null;
create index if not exists productos_clinica_activos_idx
  on public.productos (clinica_id) where archivado_at is null;

create table if not exists public.movimientos_inventario (
  id uuid primary key default gen_random_uuid(),
  clinica_id uuid not null,
  producto_id uuid not null,
  delta int not null check (delta <> 0),
  cantidad_resultante int not null check (cantidad_resultante >= 0),
  motivo text not null check (motivo in
    ('compra','uso','vencido_danado','conteo','alta','venta','dosis','deshacer')),
  origen text not null default 'ajuste'
    check (origen in ('alta','ajuste','dosis','factura')),       -- 'dosis'/'factura' reservados (D-02)
  ref_id uuid null,                    -- polimorfico (dosis/factura): SIN FK, esas tablas no existen aun
  nota text null check (nota is null or char_length(nota) <= 120),
  deshace_id uuid null references public.movimientos_inventario(id),
  veterinario_id uuid not null references public.perfiles(id) on delete restrict,
  created_at timestamptz not null default now()
);
-- FK compuesta anti cruce de clinicas (+ do $$ ... exception when duplicate_object, como dosis_aplicadas)
--   (producto_id, clinica_id) -> productos(id, clinica_id)
create unique index if not exists movimientos_deshace_uq
  on public.movimientos_inventario (deshace_id) where deshace_id is not null;  -- un movimiento se deshace una vez
create index if not exists movimientos_producto_fecha_idx
  on public.movimientos_inventario (producto_id, created_at desc);
```
Notas de diseno:
- **Constraints con nombre** (`productos_cantidad_no_negativa`): si la Fase 7 decide permitir negativo, basta `drop constraint` (no hay que adivinar el nombre autogenerado). Con `create table if not exists`, cambiar un CHECK despues exige `drop constraint` + `add constraint`; por eso los valores reservados (`dosis`, `factura`, `venta`) se incluyen **ya** en los CHECK de `origen`/`motivo`.
- `veterinario_id`/`creado_por` apuntan a `perfiles(id)` (no a `auth.users`): un solo FK evita la ambiguedad de embeds en PostgREST que `dosis_aplicadas` ya sufrio (ver sonda en `verify_live_schema.sh` linea ~276; "400 = hint equivocado").
- `kg` con cantidades enteras (D-03) significa "bultos de 1 kg"; es aceptado por la decision, no se corrige aqui.

### Pattern 2: `mover_stock` atomica y segura ante concurrencia
**What:** `SELECT ... FOR UPDATE` de la fila del producto, validacion con mensajes claros, `UPDATE`, `INSERT` del movimiento; todo en la transaccion de la funcion.
**Why safe:** en READ COMMITTED, `UPDATE`/`SELECT FOR UPDATE` esperan a la transaccion concurrente, y al liberarse re-evaluan sobre la version actualizada de la fila [CITED: postgresql.org/docs/current/transaction-iso.html, seccion Read Committed]. Dos veterinarios que restan a la vez se serializan; el segundo ve la cantidad ya actualizada y puede fallar con `IN001`. El CHECK `cantidad >= 0` queda como red de seguridad.
```sql
create or replace function public.mover_stock(
  p_producto_id uuid, p_delta int, p_motivo text,
  p_origen text default 'ajuste', p_ref_id uuid default null,
  p_nota text default null, p_deshace_id uuid default null
) returns table (movimiento_id uuid, cantidad_nueva int)
language plpgsql security definer set search_path = public
as $$
#variable_conflict use_column
declare
  v_clinica uuid := public.mi_clinica_id();
  v_p public.productos;
  v_nueva int;
  v_mov uuid;
begin
  if not public.es_veterinario() or v_clinica is null then
    raise exception 'Solo un veterinario puede mover el inventario.' using errcode = '42501';
  end if;
  if p_delta is null or p_delta = 0 or abs(p_delta) > 100000 then
    raise exception 'La cantidad del ajuste no es valida.' using errcode = 'check_violation';
  end if;
  -- (validar p_motivo contra la lista; en Fase 6 aceptar p_origen = 'ajuste' unicamente; Fase 7 lo amplia)
  select * into v_p from public.productos
   where id = p_producto_id and clinica_id = v_clinica for update;
  if not found or v_p.archivado_at is not null then
    raise exception 'El producto ya no esta disponible.' using errcode = 'IN002';
  end if;
  v_nueva := v_p.cantidad + p_delta;
  if v_nueva < 0 then
    raise exception 'No hay suficiente stock (quedan %).', v_p.cantidad using errcode = 'IN001';
  end if;
  update public.productos set cantidad = v_nueva where id = v_p.id;
  insert into public.movimientos_inventario
    (clinica_id, producto_id, delta, cantidad_resultante, motivo, origen, ref_id, nota, deshace_id, veterinario_id)
  values (v_clinica, v_p.id, p_delta, v_nueva, p_motivo, p_origen, p_ref_id, nullif(btrim(p_nota), ''), p_deshace_id, auth.uid())
  returning id into v_mov;
  return query select v_mov, v_nueva;
end;
$$;
```
- **Deshacer (D-09):** el cliente llama `mover_stock(id, -delta, 'deshacer', p_deshace_id => movimiento_id)`. El servidor valida que el original sea de la clinica y del mismo producto, que `p_delta = -original.delta`, y el indice unico `movimientos_deshace_uq` impide deshacer dos veces. Si entre medias el stock cambio y el inverso dejaria negativo, falla con `IN001` y la UI lo explica ("El stock cambio; ajusta manualmente"). Es el unico punto no trivial del deshacer; si se corta, sigue valido como un ajuste normal con motivo opuesto.
- `#variable_conflict use_column` y OUT `cantidad_nueva` (no `cantidad`): evitan el choque entre la columna `cantidad` y los parametros OUT (mismo recurso que usan `vacunas_resumen*`).
- **Codigos propios `IN001` (stock insuficiente) / `IN002` (producto no disponible):** mismo estilo que `LP00x`; `42501` para permisos. Mapear en `mensajeErrorInventario`, nunca mostrar texto crudo del servidor.

### Pattern 3: Escrituras solo por RPC, lecturas por SELECT con RLS
```sql
alter table public.productos enable row level security;
alter table public.movimientos_inventario enable row level security;
-- Solo SELECT (mismo shape que dosis_aplicadas_select)
create policy productos_select on public.productos for select to authenticated
  using (public.es_veterinario() and clinica_id = public.mi_clinica_id());
create policy movimientos_inventario_select on public.movimientos_inventario for select to authenticated
  using (public.es_veterinario() and clinica_id = public.mi_clinica_id());
revoke all on table public.productos from anon;
revoke all on table public.movimientos_inventario from anon;
revoke insert, update, delete, truncate on table public.productos from authenticated;
revoke insert, update, delete, truncate on table public.movimientos_inventario from authenticated;
-- (usar drop policy if exists antes de cada create policy: idempotencia)
```
Supabase concede privilegios por defecto a `anon`/`authenticated` en tablas nuevas de `public`: **los `revoke` explicitos son obligatorios** (patron lineas 2017-2024 de `schema.sql`) [VERIFIED: codebase].

RPC restantes (todas `security definer set search_path = public`, `es_veterinario()` + `mi_clinica_id()` adentro; `revoke all ... from public, anon; grant execute ... to authenticated`):
- `crear_producto(p_nombre, p_unidad, p_cantidad, p_minimo default 2, p_categoria default 'medicamento', p_vencimiento default null, p_precio_venta_cop default null, p_costo_cop default null) returns uuid`: inserta producto con `cantidad = p_cantidad` y, si `p_cantidad > 0`, un movimiento `alta/alta` con `cantidad_resultante = p_cantidad`. `23505` (indice de nombre) -> "Ya tienes un producto con ese nombre".
- `actualizar_producto(p_id, p_nombre, p_categoria, p_vencimiento, p_minimo, p_precio_venta_cop, p_costo_cop) returns void`: el formulario envia el registro completo; el servidor compara y, **si `minimo` o precios cambian y el llamador no es `es_admin_clinica()`, `42501`**. Enviar el registro completo (no "null = sin cambio") permite borrar un precio. **`unidad` no se edita** (cambiarla con historial invalidaria los movimientos). [ASSUMED: edicion libre de nombre/categoria/vencimiento por cualquier veterinario; D-13 solo reserva minimo/precios/archivar al admin]
- `archivar_producto(p_id) returns void`: solo `es_admin_clinica()`; `archivado_at = now()`, `archivado_por = auth.uid()`. Nunca DELETE (D-13). Sin "restaurar" en la fase (ver Open Questions).
- `inventario_resumen() returns table (bajos int, por_vencer int, vencidos int)`: `stable`, mismo shape de guardia que `vacunas_resumen` (`insufficient_privilege` si no es veterinario). Cuenta solo productos no archivados: `bajos = count(*) filter (where cantidad < minimo)`, `por_vencer = count(*) filter (where vencimiento between hoy and hoy + 30)`, `vencidos = count(*) filter (where vencimiento < hoy)` con `hoy = public._hoy_bogota()`. Un minimo 0 nunca cuenta porque `cantidad >= 0` (D-07).

### Pattern 4: Guard de solo lectura (D-14) y R44
Agregar al final del bloque de guard (mismo texto de las lineas 3780-3799):
```sql
drop trigger if exists guard_solo_lectura on public.productos;
create trigger guard_solo_lectura before insert or update or delete on public.productos
  for each row execute function public.guard_solo_lectura();
drop trigger if exists guard_solo_lectura on public.movimientos_inventario;
create trigger guard_solo_lectura before insert or update or delete on public.movimientos_inventario
  for each row execute function public.guard_solo_lectura();
```
- El trigger corre igual bajo RPC `security definer` (auth.uid() sale del JWT), exactamente como se documenta en el comentario de la linea 3742. El primer write de `mover_stock` (el UPDATE) dispara `LP004`.
- **R44 (linea ~4270 de `rls_smoke_test.sql`) hay que editarlo:** `cardinality(r_arr) <> 7` -> `<> 9` y agregar `'movimientos_inventario','productos'` a ambos arrays literales; actualizar el texto "(guarda en exactamente 7 tablas)" y el comentario en `schema.sql` linea ~3739 ("Guarda en las 7 tablas"). **Esto no cambia el total de checks** (es una modificacion, no un check nuevo). Tambien R30/R31 siguen valiendo (no tocan inventario). [VERIFIED: codebase]
- **No** agregar claves a `mi_plan()` (R2 exige exactamente las 21 claves) ni limites nuevos (D-15).

### Pattern 5: `es_autor_en_mi_clinica` (autoria visible tras retirar al veterinario)
`perfiles_select` deja leer el perfil de quien aparezca como autor en la clinica. `retirar_miembro` solo pone `activo = false` (no borra), asi que el historial seguiria mostrando el nombre **solo si** `es_autor_en_mi_clinica` conoce las tablas nuevas. Redefinir (al final del bloque Fase 6) agregando:
```sql
or exists (select 1 from public.movimientos_inventario m
           where m.clinica_id = public.mi_clinica_id() and m.veterinario_id = p_id)
```
y re-afirmar `revoke all ... from public, anon; grant execute ... to authenticated;`. Actualizar los comentarios "ver redefinicion al final del archivo" (lineas ~1117 y ~2060). Debe ir despues de crear la tabla (las funciones `language sql` validan referencias al crearse).

### Pattern 6: Navegacion sin tocar las 5 ramas
- **Rutas de primer nivel** (fuera del shell), igual que `vacunacionRoutes`: `lib/features/inventory/presentation/inventario_routes.dart` exporta `inventarioRoutes` (`/inventario`, `/inventario/nuevo`, `/inventario/:id`; **`nuevo` antes de `:id`**) y se esparce en `app_router.dart` junto a `...vacunacionRoutes` (linea ~92). Motivo: dos puntos de entrada en ramas distintas (Inicio y Mas); empujar una ruta *dentro* de una rama del shell duplica la pagina en el Navigator raiz (patron G5, documentado en `vacunacion_routes.dart`). Desde estas pantallas solo se empujan rutas de primer nivel.
- **Mas:** nueva fila `AppCard` "Inventario" (`Icons.inventory_2_outlined`, `minHeight: 56`, chevron) en `mas_screen.dart`, con texto auxiliar "N bajos" si `resumenInventarioProvider` los trae (mismo estilo que "N miembros" de Equipo). Ubicarla antes de "Recordatorios" (operativo antes que ajustes). [ASSUMED: posicion exacta; no afecta el contrato]
- **Inicio:** `StockBajoCard` debajo de `VacunasPendientesCard` en `inicio_screen.dart`; `context.push('/inventario?filtro=bajos')`.
- **Diferencia con `VacunasPendientesCard`:** esa tarjeta esta siempre visible con estado "Todo al dia"; D-08 pide que la de stock **solo aparezca si hay al menos un bajo**. Recomendado: `SizedBox.shrink()` en carga, en error y con `bajos == 0` (un aviso opcional no debe ensuciar Inicio con errores; el reintento vive en la lista). [ASSUMED: ocultar tambien en error]

### Pattern 7: Providers y acciones (a mano)
```dart
final inventarioRepositoryProvider = Provider<SupabaseInventarioRepository>(
  (ref) => SupabaseInventarioRepository(ref.watch(supabaseClientProvider)));
final productosProvider = FutureProvider.autoDispose<List<Producto>>(
  (ref) => ref.watch(inventarioRepositoryProvider).listar());      // activos, orden por nombre
final resumenInventarioProvider = FutureProvider.autoDispose<ResumenInventario>(...);
final movimientosProvider = FutureProvider.autoDispose.family<List<MovimientoStock>, String>(...);
// Acciones: NO autoDispose; guardan Ref; invalidan lista + resumen (+ historial del producto).
final inventarioActionsProvider = Provider<InventarioActions>((ref) => InventarioActions(ref));
void invalidarInventario(Ref ref, {String? productoId}) { ... }   // como invalidarVacunas
```
- **Invalidar siempre** `productosProvider` y `resumenInventarioProvider` tras cualquier mutacion: la rama Inicio del shell sigue montada, asi que un provider `autoDispose` con listener vivo **no** se refresca solo (lecccion G4 de Fase 5, `invalidar_vacunas.dart`).
- `AsyncValue.when` tiene `skipLoadingOnRefresh = true` por defecto: tras invalidar, la lista conserva los datos viejos mientras recarga (sin parpadeo de spinner por cada -1).
- Candado por fila: mientras una fila tiene un RPC en vuelo, deshabilitar sus botones (evita rafagas de -1 duplicadas por doble toque).

### Pattern 8: Reutilizacion de widgets/helpers
`AppCard`, `AppButton`, `AppTextField` (`keyboardType: TextInputType.number`, `inputFormatters: [FilteringTextInputFormatter.digitsOnly]`, `autofocus`), `AppFilterChip` (su doc ya lo reserva para Inventario; **no copiar**), `AppStatusChip` o chip local para "Bajo"/"Vence pronto"/"Vencido" (**icono + texto, nunca solo color**; colores `AppColors.warning`/`destructive`), `AppTopBar`, `AppSpacing.touchTarget = 48`, `ControlEscritura` + `iconoEscritura` + `asegurarEscritura` + `manejarLimitePlan` (`limite_plan_gate.dart`), `Compartidor`/`FakeCompartidor` para el pedido, `clockProvider` + `diaBogota` para "vence pronto" (no llamar `DateTime.now()` directo).

### Anti-Patterns to Avoid
- **`UPDATE productos SET cantidad` desde el cliente o una politica UPDATE:** rompe el log append-only. Escrituras solo por RPC; sin politicas ni grants de escritura.
- **Leer-modificar-escribir en Dart** (`cantidad + 1` calculado en el cliente): condicion de carrera entre veterinarios. Siempre `delta` al servidor.
- **Empujar `/inventario` como subruta de una rama del shell** (G5).
- **Duplicar la regla de stock bajo con `<=`** (el stub viejo la tenia): D-07 es `<` en SQL y en Dart.
- **Mostrar `PostgrestException.message`:** traducir en `mensajeErrorInventario`.
- **Nuevo `double`/`numeric` para cantidades o dinero:** enteros (D-03, D-16).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Concurrencia de stock | Reintentos/locks en Dart | `SELECT ... FOR UPDATE` + CHECK en `mover_stock` | La unica forma correcta es en el servidor; el row lock serializa |
| Aislamiento por clinica | Filtros `.eq('clinica_id')` en Dart | RLS `es_veterinario()` + `mi_clinica_id()` | Patron de todo el repo; el cliente nunca es la defensa |
| Solo lectura por plan | Chequeo propio de plan en Dart | `guard_solo_lectura` + `asegurarEscritura`/`manejarLimitePlan` | Ya cubre RPC definer y devuelve `LP004` traducible |
| Compartir / WhatsApp | `launchUrl('whatsapp://...')` a mano | `Compartidor.compartirTexto` (hoja del sistema, sin destinatario, D-11) | Ya abstraido y con fake |
| Chips de filtro | Nuevo `ChoiceChip` | `AppFilterChip` | Evita el bug de ancho de `Chip` con Google Fonts documentado en el widget |
| Dinero | `double` o `NumberFormat('es_CO')` | `int` de pesos + `formatearCop`/`parsearCop` (agrupacion manual con RegExp) | No hay helper hoy; evita depender de datos de locale (la app nunca llama `initializeDateFormatting`); la prueba fija `$ 85.000` |
| Fecha "hoy" | `DateTime.now()` | `clockProvider` + `diaBogota` / `_hoy_bogota()` | Zona fija America/Bogota (UTC-5); pruebas deterministas |

**Key insight:** el stock parece "un CRUD" pero es un libro mayor: lo unico que cambia es `cantidad` y solo por movimientos. Si se mantiene esa disciplina, deshacer, auditoria, Fase 7 (`origen = 'factura'`) y dosis (`origen = 'dosis'`) son extensiones sin rediseno.

## Runtime State Inventory

No aplica: es una fase de funcionalidad nueva (no rename/refactor/migracion). Unica nota de estado vivo: el schema debe aplicarse al proyecto Supabase real (ver Pitfall 1); `supabase_flutter` y la app no cachean nada del inventario.

## Common Pitfalls

### Pitfall 1: Aplicar el schema a la base viva
**What goes wrong:** Se edita `schema.sql` y se asume que la base real cambio; o un agente escribe en la base viva sin OK.
**Why:** No hay `supabase/migrations/`; `schema.sql` es la unica fuente y se aplica a mano.
**How to avoid:** El plan de SQL termina en un checkpoint humano: aplicar **solo el bloque Fase 6** (es idempotente y depende de objetos ya vivos: `tocar_updated_at`, `guard_solo_lectura`, `es_veterinario`, `mi_clinica_id`, `es_admin_clinica`, `_hoy_bogota`) por SQL Editor, o por Supabase MCP **solo con OK explicito del usuario**; luego pegar el smoke test completo. Las lecturas por MCP son libres; escrituras/DDL piden confirmacion. Nunca escribir refs de proyecto ni claves en docs/codigo.
**Warning signs:** la app en el emulador recibe `PGRST202`/`42P01` ("function/relation does not exist") -> falta aplicar o recargar cache (`notify pgrst, 'reload schema'` ya cierra el archivo).

### Pitfall 2: Total del smoke test y R44
**What goes wrong:** El bloque S suma checks pero el encabezado sigue diciendo "Total esperado: 238", o R44 sigue exigiendo 7 guards y falla en cuanto se agregan los triggers.
**How to avoid:** En el mismo plan que agrega el SQL: (a) editar R44 (7 -> 9 y los dos arrays); (b) actualizar el comentario de cabecera ("Fase 6 (bloque S, N checks) ... Total esperado: 238+N"); (c) verificar con `grep -c "checks := checks + 1" supabase/tests/rls_smoke_test.sql` (hoy 238) que el conteo coincide con el esperado. El smoke solo se ejecuta pegandolo en el SQL Editor (siempre termina en excepcion `RLS SMOKE: PASS|FAIL (n checks)`); marcarlo como **pendiente del usuario**, no verde.

### Pitfall 3: Estado de plan heredado por el bloque S
**What goes wrong:** El bloque S corre despues de R45 y reutiliza clinicas (`r_c_s`, `r_vet_s2`) cuyo plan lo van mutando los checks R*; el colega "en solo lectura" deja de estarlo.
**How to avoid:** Al inicio del check de solo lectura de S, fijar el estado como lo hace R30 (`update public.clinica_planes set plan='gratis', miembros_max=1, ... prueba_clinica_hasta = r_hoy - 16 where clinica_id = r_c_s`) o crear una fixture propia. Declarar variables `s_*` en el `declare` global (el script es un unico `do $$`).

### Pitfall 4: `security invoker` por inercia
**What goes wrong:** Copiar `crear_cita` (invoker) para `mover_stock` obliga a otorgar UPDATE sobre `productos` -> un veterinario cambia `cantidad` por PostgREST sin movimiento.
**How to avoid:** Seguir `registrar_dosis` (definer + tabla solo-lectura + chequeos internos). Registrar la divergencia respecto al brief como decision explicita del plan. Verificar con un check: `update public.productos set cantidad = 99` como `authenticated` debe fallar (`42501`).

### Pitfall 5: Conflicto de nombres OUT / columnas en plpgsql
**What goes wrong:** `returns table (cantidad int)` choca con la columna `cantidad` y la funcion falla con "column reference is ambiguous".
**How to avoid:** `#variable_conflict use_column` (precedente en `vacunas_*`) y nombres OUT distintos (`cantidad_nueva`).

### Pitfall 6: Tests que montan Inicio/Mas sin override del inventario
**What goes wrong:** Los tests que montan `InicioScreen`/`MasScreen`/`routerProvider` (`inicio_screen_test`, `router_equipo_test`, `router_vacunas_cross_shell_test`, `plan_refresco_test`, `mi_plan_screen_test`, `datos_clinica_screen_test`, `equipo_screen_test`, `mi_perfil_screen_test`, `protocolos_screen_test`) empiezan a leer `supabaseClientProvider` -> `Supabase.instance.client` (no inicializado en pruebas).
**How to avoid:** Wave 0: crear `FakeInventarioRepository` y agregar `inventarioRepositoryProvider.overrideWithValue(...)` a los helpers/`_appUnderTest` de esos archivos (mismo trato que `vacunaRepositoryProvider`). Correr la **suite completa** (`flutter test`) al cerrar cada plan, no solo los archivos nuevos.

### Pitfall 7: Doble toque / red inestable en el ajuste rapido
**What goes wrong:** Dos taps rapidos en -1 mandan dos RPC; un timeout reintentado por el usuario duplica el movimiento.
**How to avoid:** Bloqueo por fila mientras hay RPC en vuelo; mensaje claro sin conexion (D-12, sin cola offline). Idempotencia por `id` de movimiento generado en el cliente es una mejora opcional, no necesaria en el MVP. Para "Conteo": el delta se calcula contra la cantidad cargada; si la cantidad cambio, el movimiento resulta distinto del esperado (aceptado; la UI muestra la `cantidad_resultante` real devuelta por el RPC).

### Pitfall 8: COP sin helper
**What goes wrong:** Se asume `formato.dart` ya formatea COP (D-16) y se escribe `'\$${precio}'` o `NumberFormat`.
**How to avoid:** Tarea explicita: `formatearCop(int) -> '$ 85.000'` y `parsearCop(String) -> ({int? valor, String? error})` en `formato.dart` con `test/formato_test.dart` (ya existe, se extiende). `parsearCop`: acepta `85.000`, `85000`, `$ 85.000`; rechaza coma decimal ("Usa pesos enteros") y valores fuera de rango. Teclado numerico + `digitsOnly`.

### Pitfall 9: Filtros de PostgREST y nombres con comas
Si se busca en servidor con `.or()`, usar `filtroOrIlike`/`sanitizarBusqueda` (`core/data/busqueda.dart`). Con la recomendacion de filtrar localmente, comparar en minusculas y **sin tildes** (el repo no tiene helper de normalizacion de acentos; si se quiere "ibuprofeno" = "Ibuprofeno", basta `toLowerCase`; acentos son mejora opcional).

### Pitfall 10: Unicidad de nombre y archivado
El indice unico es parcial (`where archivado_at is null`): archivar libera el nombre. Si en el futuro se agrega "restaurar", puede chocar con un producto activo del mismo nombre (`23505`). Por eso no se incluye restaurar en la fase.

## Code Examples

### Regla de stock bajo en Dart (D-07) y vence pronto (D-06)
```dart
// Source: decision D-07/D-06; clockProvider + diaBogota del repo
bool get bajo => cantidad < minimo;                       // estrictamente menor
int? diasParaVencer(DateTime hoyBogota) =>
    vencimiento == null ? null : vencimiento!.difference(hoyBogota).inDays;
bool vencePronto(DateTime hoy) { final d = diasParaVencer(hoy); return d != null && d >= 0 && d <= 30; }
bool vencido(DateTime hoy) { final d = diasParaVencer(hoy); return d != null && d < 0; }
```

### Pedido por WhatsApp (D-11), dominio puro y testeable
```dart
// sugerida = minimo*2 - cantidad (siempre >= 1 porque cantidad < minimo)
String mensajePedidoStock({required List<Producto> bajos, String? clinica}) {
  final lineas = [for (final p in bajos)
    '- ${p.nombre}: pedir ${p.minimo * 2 - p.cantidad} ${p.unidad.etiqueta} (quedan ${p.cantidad})'];
  return 'Pedido${clinica == null ? '' : ' de $clinica'}:\n${lineas.join('\n')}';
}
// En la UI: await ref.read(compartidorProvider).compartirTexto(texto);  (capturar el error y mostrar snackbar)
```

### Mapeo de errores (un solo lugar, como `mensajeErrorVacuna`)
```dart
@visibleForTesting
String mensajeErrorInventario(PostgrestException e) {
  if (limitePlanDe(e) == LimitePlan.soloLectura) {
    return 'Tu cuenta esta en solo lectura. Pide al administrador que active el plan.';
  }
  switch (e.code) {
    case 'IN001': return 'No hay suficiente stock para ese ajuste.';
    case 'IN002': return 'Ese producto ya no esta disponible. Actualiza la lista.';
    case '23505': return 'Ya tienes un producto con ese nombre.';
    case '42501': return 'Solo el administrador de la clinica puede hacer esto.';
    case '23514': return 'Revisa los datos: las cantidades deben ser enteros validos.';
    default: return 'No pudimos completar la operacion. Intenta de nuevo.';
  }
}
// InventarioFailure(message, {limite}) implements Exception, ConLimitePlan -> la UI llama manejarLimitePlan antes de mostrar el mensaje.
```
(En el codigo real los mensajes llevan tildes, como el resto de la app.)

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Stub `Producto` (`double`, `veterinarioId`, `<=`) | Entidad entera con `clinicaId`, `<` y vencimiento | Fase 6 (D-01) | Reescribir el archivo; sin otros usuarios en `lib/`/`test/` (verificado con grep: solo se referencia a si mismo) |
| Stock editable directo | Libro de movimientos + RPC | D-02 | Auditoria, deshacer y Fase 7 gratis |

**Deprecated/outdated:** la seccion 8 "Planeado" de `references/modelo-dominio.md` y el item "billing/inventory/vaccination solo tienen entities" del skill `arquitecto-vetapp` quedaran desactualizados; incluir una tarea de documentacion (modelo de dominio de inventario + estructura) al cerrar la fase.

## Fase 7 forward-compatibility (resumen para el planner)
- `origen = 'factura'` y `motivo = 'venta'` ya estan permitidos en los CHECK; `ref_id` (uuid sin FK) llevara el id de factura/linea. La Fase 7 llamara `mover_stock(producto, -cantidad, 'venta', 'factura', factura_id)` dentro de su propia RPC (llamada anidada `security definer` en una sola transaccion = atomica para facturas con varios items); en esta fase el RPC publico solo acepta `origen = 'ajuste'` y se ampliara con `create or replace`.
- `precio_venta_cop` (int, COP) esta en `productos` para pre-llenar items de factura; la factura debe **copiar el precio** a su item (no referenciarlo) para que cambiar el precio no altere facturas pasadas (decision de Fase 7).
- Anular una factura = movimiento inverso (`delta` positivo, `deshace_id` o nuevo motivo), nunca borrar movimientos.
- Si la Fase 7 permite vender en negativo: `alter table public.productos drop constraint productos_cantidad_no_negativa` (por eso se nombra) y un parametro `p_permitir_negativo` en el RPC; fuera de alcance ahora (D-04). Considerar entonces un indice unico parcial `(ref_id, producto_id) where origen = 'factura'` para idempotencia.
- Descuento por dosis (D-05, diferido): `registrar_dosis` ganaria `p_producto_id` opcional y llamaria `mover_stock(..., 'dosis', 'dosis', dosis_id)`; el CHECK ya lo admite.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Cualquier veterinario puede editar nombre/categoria/vencimiento; solo admin cambia minimo/precios (D-13 solo lo dice para minimo/precios/archivar). Al **crear**, cualquier veterinario fija minimo y precios iniciales | Pattern 3 | Un veterinario no-admin podria esperar editar el minimo; o el negocio quiere precios solo-admin tambien al crear |
| A2 | `unidad` inmutable tras crear | Pattern 3 | Si el usuario espera corregir la unidad, necesitara archivar y recrear |
| A3 | Sin "restaurar" producto archivado en esta fase | Pitfall 10 | Archivado por error exige recrear (se pierde historial visible); riesgo de UX bajo (solo admin archiva) |
| A4 | La tarjeta de Inicio se oculta tambien en carga/error | Pattern 6 | Si se quiere un estado "Inventario al dia" siempre visible, cambiar el patron (D-08 dice que solo aparece si hay bajos) |
| A5 | Posicion de la fila "Inventario" en Mas (antes de Recordatorios) | Pattern 6 | Cosmetico |
| A6 | Autocompletar nombre con el catalogo de biologicos (D-10) **se recorta**: el catalogo trae nombres genericos ("Polivalente"), no marcas comerciales, y crea una dependencia vaccination->inventory sin valor claro | Standard Stack/UI | Si el usuario lo valora, se hace despues sin cambio de schema |
| A7 | Limites numericos (cantidad/minimo hasta 1.000.000; precios hasta 100.000.000 COP; delta por llamada hasta 100.000; nota 120 caracteres) | Pattern 1 | Valores arbitrarios de cordura; ajustables sin impacto de diseno |
| A8 | Un aviso/etiqueta para categorias de control especial (ketamina, tramadol) queda fuera de MVP; basta no prometer "libro oficial" (Res. 1478/2006, Res. 315/2020 segun CONTEXT) | Specifics | Si hay requisito regulatorio, validar con asesoria; no verificado en esta sesion |

## Open Questions

1. **Restaurar productos archivados** — Sabemos que D-13 pide archivar sin borrar. No esta claro si el admin necesita deshacerlo. Recomendacion: no incluir; si se pide, agregar `restaurar_producto` que falle con `23505` si el nombre esta tomado.
2. **Orden y vista de lista por defecto** — Recomendacion: orden alfabetico, con los bajos primero solo cuando se llega desde la tarjeta (`?filtro=bajos`); chips `Todos | Bajos | Vence pronto`.
3. **Historial de movimientos en el detalle** — "siempre con motivo y autoria" (D-13) implica verlo en algun sitio. Recomendacion: ultimos 50 movimientos en `/inventario/:id` con embed `autor:perfiles!movimientos_inventario_veterinario_id_fkey(nombre)`; **agregar una sonda en `verify_live_schema.sh`** (patron `probe_embed ... allow_denied`) porque un hint de FK equivocado da 400.
4. **`deshace_id` en el MVP** — Si el planner quiere minimizar, puede omitir `p_deshace_id`/indice unico y modelar "Deshacer" como un ajuste normal inverso (motivo `deshacer`); se pierde la prevencion de doble-deshacer, que la UI ya cubre al cerrar el snackbar.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | todas las pruebas/analyze | si | 3.41.4 stable (Dart ^3.11.1) | — |
| Proyecto Supabase en la nube | aplicar schema + smoke | si (existente, Fases 1-5.1 vivas) | — | Aplicar a mano en SQL Editor (accion del usuario) |
| Supabase MCP | aplicar/verificar schema | si (con OK explicito del usuario para DDL) | — | SQL Editor manual |
| Emulador Android + agente `vetapp-qa` | UAT manual | segun memoria del proyecto (el usuario solo tiene iPhone; verificaciones reales -> emulador + Safari) | — | QA en emulador; "Pedir por WhatsApp" real queda como paso humano |
| `pip`/slopcheck | auditoria de paquetes | no necesario (sin paquetes nuevos) | — | — |

**Missing dependencies with no fallback:** ninguna.
**Missing dependencies with fallback:** envio real de la hoja de compartir/WhatsApp en dispositivo fisico (pendiente humano, igual que en 5.1).

## Validation Architecture

> `workflow.nyquist_validation` esta en `true` en `.planning/config.json`.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (SDK) + fakes a mano en `test/helpers/`; SQL smoke manual en `supabase/tests/rls_smoke_test.sql` |
| Config file | `analysis_options.yaml` (`flutter_lints`); sin config de test adicional |
| Quick run command | `flutter test test/<archivo>_test.dart` |
| Full suite command | `flutter analyze && flutter test` (agente `vetapp-gate`) |
| SQL smoke | pegar el archivo completo en el SQL Editor tras aplicar `schema.sql`; esperar `RLS SMOKE: PASS (N checks)` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INV-01 | `Producto` entero, mapeo fila->entidad, `copyWith` | unit | `flutter test test/producto_test.dart` | Wave 0 |
| INV-01 | Repositorio: `crear` envia parametros del RPC; errores -> `InventarioFailure` (23505, 42501, LP004) | unit | `flutter test test/supabase_inventario_repository_test.dart` | Wave 0 |
| INV-01 | Alta de un paso: minimo prellenado 2, chips de unidad, "Mas detalles" colapsado, validaciones, precios COP | widget | `flutter test test/producto_form_screen_test.dart` | Wave 0 |
| INV-01 | `formatearCop`/`parsearCop` (`$ 85.000`, rechazo de coma decimal) | unit | `flutter test test/formato_test.dart` | existe; extender |
| INV-01 | RPC `crear_producto` crea movimiento `alta`; duplicado 23505; aislamiento entre clinicas | SQL smoke | bloque S (S1..S5) | Wave 0 |
| INV-02 | `bajo` es `<` (borde igual a minimo = no bajo; minimo 0 nunca) ; vence pronto/vencido con fecha Bogota | unit | `flutter test test/producto_test.dart` | Wave 0 |
| INV-02 | Lista: insignia "Bajo" (icono+texto), filtro Bajos, busqueda, estados vacio/error/reintento | widget | `flutter test test/inventario_screen_test.dart` | Wave 0 |
| INV-02 | Tarjeta de Inicio: aparece solo con `bajos > 0`, texto "N productos con stock bajo", toca -> `/inventario?filtro=bajos`; oculta en 0/carga/error | widget | `flutter test test/inicio_screen_test.dart` (extender) y `test/stock_bajo_card_test.dart` | Wave 0 |
| INV-02 | Entrada desde Mas y desde Inicio abre una sola pagina (sin duplicar el shell, G5) | widget/router | `flutter test test/router_inventario_cross_shell_test.dart` | Wave 0 (modelo: `router_vacunas_cross_shell_test.dart`) |
| INV-02 | `inventario_resumen`: borde `cantidad = minimo` no cuenta; minimo 0 no cuenta; archivados no cuentan; aislado por clinica; CLIENTE rechazado | SQL smoke | bloque S | Wave 0 |
| INV-02 | Pedido por WhatsApp: texto (minimo*2 - stock), comparte via `FakeCompartidor`, error de compartir -> snackbar | unit + widget | `flutter test test/pedido_stock_test.dart` | Wave 0 |
| INV-03 | `mover_stock` atomico: cantidad nueva, movimiento con `cantidad_resultante`, autoria = `auth.uid()`; `IN001` sin cambios ni movimiento; `IN002` archivado/otra clinica | SQL smoke | bloque S | Wave 0 |
| INV-03 | Append-only: UPDATE/DELETE sobre movimientos y UPDATE directo de `cantidad` denegados | SQL smoke | bloque S | Wave 0 |
| INV-03 | Permisos: no-admin no cambia minimo/precios ni archiva (42501); admin si | SQL smoke | bloque S | Wave 0 |
| INV-03 | Solo lectura: `crear_producto`/`mover_stock`/`archivar` -> LP004; lectura sigue | SQL smoke | bloque S (preparar plan como R30) | Wave 0 |
| INV-03 | Ajuste rapido: -1/+N, chips de motivo, confirmacion solo > 10, snackbar "Deshacer" invoca inverso, fila bloqueada en vuelo, candado en solo lectura, error `IN001`/sin conexion | widget | `flutter test test/ajuste_rapido_test.dart` | Wave 0 |
| INV-03 | Acciones invalidan lista + resumen + historial (G4) | unit | `flutter test test/inventario_invalidacion_test.dart` | Wave 0 (modelo: `vacunas_invalidacion_test.dart`) |
| Transversal | Guard en 9 tablas (R44 editado); `es_autor_en_mi_clinica` incluye movimientos; anon sin acceso | SQL smoke | R44 + bloque S | R44 existe; editar |
| Transversal | Tablas/RPC expuestas y `anon` sin escritura en la nube | script | `bash supabase/tests/verify_live_schema.sh` (extender con `productos`, `movimientos_inventario`, sonda de embed) | existe; extender |
| Transversal | Gates de forma en SQL (sin ejecutar BD): `for update` en `mover_stock`; `security definer set search_path`; guard en `productos` y `movimientos_inventario`; sin `grant insert/update/delete` | grep | p. ej. `grep -c "guard_solo_lectura on public.productos" supabase/schema.sql` = 1 | Wave 0 |

Sugerencia de cantidad del bloque S: ~16-20 checks (S1..S18) -> total esperado **238 + N** (fijar N en el plan y verificar con el `grep -c` del Pitfall 2). La concurrencia real (dos sesiones) no se puede probar dentro de un unico `do $$`: se cubre por construccion (`FOR UPDATE` verificado por grep) y, opcionalmente, una prueba manual de dos sesiones en el SQL Editor.

### Sampling Rate
- **Per task commit:** `flutter analyze` + los `flutter test <archivos del plan>`.
- **Per wave merge:** `flutter test` (suite completa) + gates grep de SQL.
- **Phase gate:** suite completa verde + smoke SQL pegado por el usuario con `PASS (238+N checks)` + `verify_live_schema.sh` + QA en emulador (`vetapp-qa`), todo registrado por plan en `06-VALIDATION.md` (memoria `vetapp-verify-each-plan`: columna ✅/❌ y evidencia con conteos y fecha; pasos manuales = pendientes del usuario, no verdes).

### Wave 0 Gaps
- [ ] `test/helpers/fake_inventario.dart` — `FakeInventarioRepository` (datos fijos, errores por metodo, `llamadas` registradas)
- [ ] Overrides de `inventarioRepositoryProvider` en los tests que montan Inicio/Mas/router (Pitfall 6)
- [ ] Archivos de prueba nuevos listados arriba (`producto_test`, `supabase_inventario_repository_test`, `producto_form_screen_test`, `inventario_screen_test`, `ajuste_rapido_test`, `stock_bajo_card_test`, `pedido_stock_test`, `inventario_invalidacion_test`, `router_inventario_cross_shell_test`)
- [ ] Extender `test/formato_test.dart` (COP) e `inicio_screen_test.dart`
- [ ] Bloque S en `rls_smoke_test.sql`, edicion de R44, cabecera con el total nuevo
- [ ] Framework: ninguno que instalar

## Security Domain

`security_enforcement` no esta definido en `.planning/config.json` (ausente = habilitado).

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no (sin cambios) | Supabase Auth existente |
| V3 Session Management | no (sin cambios) | `supabase_flutter` |
| V4 Access Control | **si** | RLS por `clinica_id`; `es_veterinario()`; chequeo `es_admin_clinica()` en RPC admin-only; `revoke` de escrituras; guard LP004 |
| V5 Input Validation | **si** | CHECK constraints (longitudes, enums de unidad/categoria/motivo/origen, rangos enteros); validacion de `p_delta` y `p_motivo` en el RPC; `parsearCop`/`digitsOnly` en cliente |
| V6 Cryptography | no | — |

### Known Threat Patterns for Supabase RPC + RLS

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Acceso cruzado entre clinicas (IDOR por `producto_id`) | Information disclosure / Tampering | `mover_stock` filtra `where id = p and clinica_id = mi_clinica_id()` y responde `IN002` igual para "no existe" y "es de otra clinica" (no filtra existencia); FK compuesta `(producto_id, clinica_id)` |
| Escalada: veterinario no-admin cambia precio/minimo o archiva | Elevation of privilege | Chequeo `es_admin_clinica()` dentro de las RPC (la UI solo es cortesia) |
| Manipulacion directa de `cantidad` por PostgREST | Tampering | Sin politicas ni grants de escritura; `security definer` solo en RPC; check smoke de UPDATE directo denegado |
| Reescritura del historial | Repudiation | Movimientos sin update/delete; `veterinario_id` siempre `auth.uid()` (nunca parametro) |
| `anon` leyendo/escribiendo | Information disclosure | `revoke all ... from anon`; `revoke execute ... from public, anon`; check en smoke y `verify_live_schema.sh` |
| `security definer` sin `search_path` fijo | Elevation of privilege | `set search_path = public` en todas las RPC (convencion del repo) |
| Fabricar movimientos `origen='factura'` por un cliente malicioso | Tampering | En Fase 6 el RPC publico solo acepta `origen = 'ajuste'`; Fase 7 amplia con su propia RPC |
| Datos clinicos/PII en logs | Information disclosure | El inventario no guarda datos personales; no registrar contenido en logs |

## Project Constraints (from CLAUDE.md)

- Flutter + Supabase, sin reevaluar el stack; backend real, **sin mocks** en datos de produccion (los fakes son solo de prueba).
- Diseno: paleta terracota/crema, Caprasimo + Figtree, **sin Material 3 generico**; todo color/espaciado/tipografia de `AppColors`/`AppSpacing`/`AppTypography`/`AppTheme`; reutilizar widgets de `core/widgets`; revision visual delegada a `vetapp-brand-ui`.
- Colombia: COP sin decimales (enteros), fechas `dd/mm/aaaa`, zona `America/Bogota`.
- Convenciones: dominio en espanol, sufijos tecnicos en ingles, `snake_case.dart`, repositorios `Supabase<Dominio>Repository` sin interfaz, `*Failure` por feature, sin sufijo `UseCase`, sin freezed/json_serializable/mocktail/build_runner; no introducir dependencias sin justificar; no `flutter_lints` overrides.
- Errores: la capa de datos traduce `PostgrestException` a la `*Failure` (rama especifica + fallback generico en espanol); la presentacion captura solo la `*Failure` de su feature.
- Pruebas: solo `flutter_test`, fakes a mano en `test/helpers`, `routerHarness` para pantallas con navegacion; todo repositorio/provider/pantalla nuevo con su prueba; `flutter analyze` y `flutter test` en verde.
- Schema: `supabase/schema.sql` unica fuente idempotente; sin `supabase/migrations/`; cambios de schema/RLS acompanados de checks en el smoke test (agente `vetapp-supabase`); escritura en la base viva solo con OK explicito del usuario; nunca URLs/refs/claves en codigo ni docs.
- Flujo GSD: cambios al repo solo via `/gsd-*`; el brief tambien exige verificar y documentar cada plan en `VALIDATION.md`.
- Nota: la seccion "Architecture" de CLAUDE.md esta parcialmente obsoleta; manda el codigo y `arquitecto-vetapp`.

## Sources

### Primary (HIGH confidence)
- Repo: `supabase/schema.sql` (tablas/RPC de Fase 5 `dosis_aplicadas`/`registrar_dosis`, `vacunas_resumen`, `guard_solo_lectura` lineas ~3745-3799, helpers de rol lineas ~1085-1135, redefinicion `es_autor_en_mi_clinica` ~2062, cierre con `notify pgrst`), `supabase/tests/rls_smoke_test.sql` (238 checks, R44 ~4270, R30), `supabase/tests/verify_live_schema.sh`
- Repo: `lib/features/home/presentation/screens/{inicio,mas}_screen.dart`, `lib/core/router/app_router.dart`, `lib/features/vaccination/presentation/{vacunacion_routes.dart,widgets/vacunas_pendientes_card.dart,providers/*}`, `lib/features/vaccination/data/repositories/supabase_vacuna_repository.dart`, `lib/features/plan/presentation/limite_plan_gate.dart`, `lib/core/{data,utils,widgets,errors}/*`, `test/helpers/*`
- `.claude/skills/arquitecto-vetapp/SKILL.md` y `references/{modelo-dominio,colombia}.md`
- PostgreSQL docs, Transaction Isolation / Read Committed: https://www.postgresql.org/docs/current/transaction-iso.html (comportamiento de UPDATE/SELECT FOR UPDATE concurrente y re-evaluacion del WHERE)

### Secondary (MEDIUM confidence)
- `.planning/phases/06-inventario/06-CONTEXT.md`, `.planning/STATE.md`, memorias del proyecto (reglas de MCP/Supabase, verificacion por plan)

### Tertiary (LOW confidence)
- Ninguna; las afirmaciones no verificadas estan marcadas `[ASSUMED]` y listadas en el Assumptions Log.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — sin dependencias nuevas, todo verificado en el repo
- Architecture: HIGH — patrones copiados de Fase 5/5.1 ya en produccion; unica divergencia consciente (`security definer`) justificada
- Pitfalls: HIGH — los de repo (R44, total 238, overrides de tests, COP) verificados por lectura/grep; concurrencia verificada en la documentacion de PostgreSQL

**Research date:** 2026-10-31
**Valid until:** 2026-11-30 (stack estable; revisar si cambia `schema.sql` o el guard antes de planear)
