# Phase 6: Inventario - Context

**Gathered:** 2026-10-31
**Status:** Ready for planning

<domain>
## Phase Boundary

El veterinario controla el stock de medicamentos e insumos de su clínica desde el celular y sabe cuándo reabastecer (INV-01 registrar producto con nombre, cantidad y umbral mínimo; INV-02 aviso cuando el stock cae por debajo del mínimo; INV-03 ajuste manual de cantidad). Modo mvp.

Fuera de esta fase: descontar stock al facturar (Fase 7), facturación/IVA, proveedores y órdenes de compra. El modelo deja listo el camino para que la Fase 7 descuente stock sin rediseño.

</domain>

<decisions>
## Implementation Decisions

Todas las áreas quedaron a criterio de Claude: el usuario no eligió ninguna para discutir (2026-10-31) y se tomaron las recomendaciones de la investigación previa con `vetapp-opportunity-research`. El usuario puede revisar y cambiar cualquier decisión antes de `/gsd-plan-phase 6`.

### Modelo de stock
- **D-01:** El stock es de la **clínica** (`clinica_id`, RLS multi-tenant como el resto del esquema), no del veterinario. Cada producto y cada movimiento guardan quién los creó. El stub `lib/features/inventory/domain/entities/producto.dart` (cuelga de `veterinarioId`, usa `double`, `stockBajo` con `<=`) se reescribe; no es contrato.
- **D-02:** El stock se mueve solo por **movimientos que solo se agregan** (tabla de movimientos, como la historia clínica) aplicados por una **RPC atómica** del estilo `mover_stock(producto, delta, motivo, origen, ref_id)` que actualiza la cantidad en la misma transacción. Así dos veterinarios no se pisan y la Fase 7 reutiliza la RPC con `origen = 'factura'`. Orígenes previstos: `ajuste` (esta fase), `alta` (cantidad inicial), y reservados `dosis` y `factura` (fases siguientes).
- **D-03:** **Una sola unidad de conteo por producto**, elegida con chips (unidad, tableta, frasco, ml, dosis, caja, kg). **Cantidades enteras.** Sin conversión de presentaciones (caja → tabletas) ni fracciones.
- **D-04:** **Sin stock negativo:** el ajuste manual no puede dejar la cantidad por debajo de 0 (validado en el servidor). La Fase 7 decide si permite vender en negativo.

### Vacunas y vencimientos
- **D-05:** Registrar una dosis **no descuenta inventario en esta fase**. El origen `dosis` queda reservado en los movimientos; el selector opcional "Producto de inventario" en Registrar dosis se planea como fase 6.x o junto a la 7 (toca `registrar_dosis`).
- **D-06:** **Vencimiento opcional y único por producto** (sin lotes múltiples) y chip "Vence pronto" a 30 días o menos. El lote sigue viviendo en la dosis aplicada (Fase 5), que es donde el certificado lo necesita.

### Avisos y ajuste rápido
- **D-07:** "Stock bajo" es **cantidad estrictamente menor que el mínimo** (`<`), literal a INV-02 ("cae por debajo del umbral"). Un producto con mínimo 0 nunca está bajo.
- **D-08:** El aviso vive **dentro de la app**, sin push (igual que Fase 5 D-10): tarjeta en Inicio ("N productos con stock bajo", como en `.planning/design/DESIGN-REFERENCE.md`), insignia "Bajo" en la lista y filtro "Bajos". La tarjeta solo aparece si hay al menos uno.
- **D-09:** **Ajuste rápido desde la fila** de la lista: botones −1 y +N de 48 dp y chips de motivo (Compra, Uso, Vencido o dañado, Conteo). Confirmación solo para ajustes grandes (más de 10 unidades); para el resto, snackbar con "Deshacer" (que aplica el movimiento inverso, no borra).
- **D-10:** **Alta en un solo paso:** nombre + cantidad + mínimo (prellenado, p. ej. 2) y unidad; categoría, vencimiento y precios en "Más detalles". El nombre puede autocompletarse con el catálogo de biológicos de la Fase 5 si sale barato; si no, queda para después.
- **D-11:** **"Pedir por WhatsApp"** desde el filtro de bajos: arma un texto con los productos en bajo y una cantidad sugerida (mínimo × 2 − stock) y abre la hoja de compartir del sistema (sin destinatario fijo). Reutiliza los helpers de compartir y WhatsApp existentes. Si complica el plan, es lo primero que se corta.
- **D-12:** Sin conexión el ajuste falla con un mensaje claro (no hay cola offline en esta fase).

### Permisos, plan y precio
- **D-13:** **Cualquier veterinario activo** de la clínica crea productos y mueve stock, siempre con motivo y autoría. **Solo el admin** archiva productos (borrado lógico, nunca físico) y cambia mínimo y precios. Igual que Fase 5 D-24 con protocolos.
- **D-14:** Los colegas en **solo lectura** (Fase 5.1, tras la gracia) **no** pueden crear ni mover stock: el guard de solo lectura se extiende a las tablas nuevas y la UI usa el mismo tratamiento de candado (`ControlEscritura`, `limite_plan_gate`).
- **D-15:** El inventario entra en **todos los planes sin límite nuevo**: se mantiene la regla de solo 4 límites por plan (Fase 5.1 D-01). Si negocio quiere un tope en Gratis, se decide aparte.
- **D-16:** **Precio de venta opcional en COP entero** (lo necesita la Fase 7) y **costo opcional** escondido en "Más detalles". Sin IVA hasta la Fase 7. Formato COP sin decimales de `lib/core/utils/formato.dart`.

### Claude's Discretion
- Todas las decisiones D-01..D-16 (el usuario delegó todas las áreas).
- Nombres exactos de tablas, RPC y pantallas; ubicación del inventario en la navegación (probablemente desde Más o una entrada en Inicio, sin cambiar las 5 ramas del shell).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requisitos y alcance
- `.planning/ROADMAP.md` §Phase 6 — objetivo, INV-01..03, criterios de éxito
- `.planning/REQUIREMENTS.md` — INV-01..03 y la exclusión de multi-bodega / por lote (~línea 146)
- `.planning/research/FEATURES.md` — vencimiento opcional (~línea 53), riesgo de conflictos de stock (~línea 109), IVA en mascotas para la Fase 7 (~línea 38)

### Decisiones previas que aplican
- `.planning/phases/05-vacunaci-n-y-desparasitaci-n/05-CONTEXT.md` — D-06 (lote en la dosis), D-10 (alertas sin push), D-24 (solo admin edita catálogo), descuento de stock al vacunar diferido (~línea 139)
- `.planning/phases/05.1-planes-y-l-mites/05.1-CONTEXT.md` — D-01 (solo 4 límites por plan), D-12 (solo lectura tras la gracia), guard de solo lectura por tabla
- `.planning/design/DESIGN-REFERENCE.md` — tarjeta de stock bajo en Inicio (~línea 17)

### Convenciones del proyecto
- `.claude/skills/arquitecto-vetapp/SKILL.md` — Riverpod a mano, repositorios Supabase, `*Failure`, fakes en `test/helpers`, schema.sql idempotente + smoke test, flujo GSD
- `supabase/schema.sql` y `supabase/tests/rls_smoke_test.sql` — patrón de RLS por `clinica_id`, RPC `security invoker`, guard de solo lectura

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/core/widgets/` — `AppCard`, `AppButton`, `AppTextField`, `AppFilterChip`, `AppStatusChip`, `AppTopBar` para lista, alta, filtros e insignias.
- `lib/core/utils/formato.dart` — formato COP y fechas dd/mm/aaaa; `lib/core/utils/compartir.dart` y `lanzador_externo.dart` para "Pedir por WhatsApp".
- `lib/features/plan/presentation/limite_plan_gate.dart` y `ControlEscritura` — candados de solo lectura (D-14).
- Tarjetas de Inicio de vacunas pendientes (Fase 5) — patrón de tarjeta de aviso que solo aparece si hay algo.

### Established Patterns
- Multi-tenencia por `clinica_id` con `es_veterinario()` / `mi_clinica_id()` y RPC `security invoker`; cada cambio de schema lleva checks en el smoke test (agente `vetapp-supabase`).
- Escrituras por clase de acciones que invalida providers; lecturas con `FutureProvider.autoDispose`.
- Guard de solo lectura (Fase 5.1) aplicado por trigger en las tablas de escritura de la clínica.

### Integration Points
- `supabase/schema.sql` (tablas nuevas, RPC, RLS, guard) y `rls_smoke_test.sql` (bloque nuevo).
- Inicio (tarjeta de stock bajo) y Más o la ruta que se decida para entrar al inventario; `app_router.dart`.
- Fase 7: la RPC de movimientos (`origen = 'factura'`) y el precio de venta.

</code_context>

<specifics>
## Specific Ideas

- Meta de usabilidad: registrar o ajustar en unos 10 segundos con una mano (teclado numérico, botones +/−, búsqueda instantánea, estados vacío y error).
- La diferencia frente a la competencia (VetPraxis, Vetmanager y Okvet ofrecen lotes y vencimientos) es la rapidez para un veterinario solo, no la granularidad.
- Medicamentos de control especial (ketamina, tramadol…): la app no se presenta como libro oficial (Res. 1478/2006 modificada por Res. 315/2020). Basta con no prometerlo; un aviso al crear productos de esa categoría queda a criterio del planner.

</specifics>

<deferred>
## Deferred Ideas

- Descontar stock al registrar una dosis (selector "Producto de inventario" en Registrar dosis) — fase 6.x o junto a la Fase 7.
- Maletín de domicilio / varias bodegas, lotes múltiples, proveedores y órdenes de compra, código de barras, conversión de presentaciones, notificaciones push, IVA y facturación DIAN — v2 o Fase 7.
- Límite de productos por plan (p. ej. en Gratis) — solo si negocio lo decide.

### Reviewed Todos (not folded)
- "Decidir marca antes del lanzamiento público", "Carné público con aviso de privacidad y minimización", "Landing con precios y cookies sin trackers previos" — coincidieron por palabras sueltas, no por alcance; siguen pendientes por su cuenta.

</deferred>

---

*Phase: 06-inventario*
*Context gathered: 2026-10-31*
