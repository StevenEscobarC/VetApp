---
phase: 06-inventario
reviewed: 2026-11-13T00:00:00Z
depth: deep
files_reviewed: 27
files_reviewed_list:
  - supabase/schema.sql
  - supabase/tests/rls_smoke_test.sql
  - supabase/tests/verify_live_schema.sh
  - lib/core/router/app_router.dart
  - lib/core/utils/formato.dart
  - lib/core/widgets/inputs/app_text_field.dart
  - lib/features/home/presentation/screens/inicio_screen.dart
  - lib/features/home/presentation/screens/mas_screen.dart
  - lib/features/inventory/data/repositories/supabase_inventario_repository.dart
  - lib/features/inventory/domain/entities/movimiento_stock.dart
  - lib/features/inventory/domain/entities/producto.dart
  - lib/features/inventory/domain/inventario_failure.dart
  - lib/features/inventory/domain/pedido_whatsapp.dart
  - lib/features/inventory/domain/stock.dart
  - lib/features/inventory/presentation/inventario_routes.dart
  - lib/features/inventory/presentation/providers/inventario_providers.dart
  - lib/features/inventory/presentation/screens/inventario_screen.dart
  - lib/features/inventory/presentation/screens/producto_detail_screen.dart
  - lib/features/inventory/presentation/screens/producto_form_screen.dart
  - lib/features/inventory/presentation/widgets/ajuste_rapido_botones.dart
  - lib/features/inventory/presentation/widgets/ajuste_sheet.dart
  - lib/features/inventory/presentation/widgets/ajuste_stock.dart
  - lib/features/inventory/presentation/widgets/insignia_stock.dart
  - lib/features/inventory/presentation/widgets/movimiento_tile.dart
  - lib/features/inventory/presentation/widgets/producto_fila.dart
  - lib/features/inventory/presentation/widgets/resumen_bajos_strip.dart
  - lib/features/inventory/presentation/widgets/stock_bajo_card.dart
findings:
  critical: 1
  warning: 6
  info: 8
  total: 15
status: issues_found
---

# Fase 06: Informe de revisión de código

**Revisado:** 2026-11-13
**Profundidad:** deep (cadena entre capas: SQL, repositorio, providers y UI)
**Archivos revisados:** 27 de `lib` y `supabase`. Los tests solo se revisaron para ver si dan una falsa confianza.
**Estado:** issues_found

## Resumen

El bloque SQL de la fase 6 es sólido en los puntos que se pidió mirar con lupa:

- **Aislamiento por clínica:** cada RPC `security definer` filtra por `mi_clinica_id()` dentro de la función. Los selects `for update` y los `update` se limitan a `clinica_id = v_clinica`. La FK compuesta `(producto_id, clinica_id)` impide que un movimiento apunte a otra clínica.
- **Sin escrituras directas:** `revoke insert/update/delete/truncate` sobre `authenticated` y ninguna policy de escritura. En Dart no hay ningún `.insert/.update/.delete/.upsert` (comprobado con grep). Las únicas llamadas `.from()` son lecturas en el repositorio.
- **Capas:** ningún archivo de `presentation/` importa `supabase_flutter`.
- **Reloj:** el código de inventario no usa `DateTime.now()`. Todo pasa por `clockProvider` y `diaBogota`.
- **Deshacer en concurrencia:** es correcto en el servidor. El `for update` del producto serializa los dos deshacer, así que el segundo ve el primero ya confirmado y recibe IN003. Además lo respalda el índice único `movimientos_deshace_uq`.

El defecto grave está en el cliente. La hoja de **conteo** convierte la cantidad contada en un `delta` usando una cantidad que puede estar desactualizada. Como el servidor aplica ese delta al valor real, el stock final no coincide con lo que el veterinario contó. Esto contradice la garantía de D-02 de que "dos veterinarios no se pisan".

Además hay estos problemas:

- La detección de "sin conexión" no reconoce la excepción real de `package:http`.
- El cliente acepta ajustes que el servidor rechaza.
- Un ajuste que el servidor sí guardó puede reportarse como no guardado.
- La RPC deshacer acepta movimientos de cualquier origen.
- Hay huecos de permisos en precios y mínimo.

## Critical Issues

### CR-01: El conteo envía un delta calculado sobre una cantidad desactualizada, así que el stock final no es lo contado

**Archivo:** `lib/features/inventory/presentation/widgets/ajuste_sheet.dart:138-145` (además `:126`, `:148`). Relacionado: `supabase/schema.sql:4451-4456` y `lib/features/inventory/data/repositories/supabase_inventario_repository.dart:215-228`.

**Problema:** con el motivo `conteo`, el veterinario escribe la cantidad **absoluta** que contó. La hoja envía `delta = n - _p.cantidad`. Ese `_p` es la copia de `Producto` que tenía la fila de la lista o el detalle **al abrir la hoja**.

Los providers no son realtime. La lista de Inventario, o el detalle, puede llevar minutos u horas montada sin recargarse. Mientras tanto, otro veterinario puede haber descontado stock. El servidor hace `v_nueva := v_p.cantidad + p_delta` sobre el valor real.

Ejemplo:
- La lista se cargó con 13 unidades.
- Un colega descontó 3, así que en la base quedan 10.
- El veterinario cuenta 10 en el estante y aplica el conteo.
- Se envía `delta = 10 - 13 = -3` y el stock queda en **7**, no en 10.

El snackbar dice "Stock de X corregido a 7", que no es lo que se contó. Un conteo físico es justamente la operación que debe fijar la verdad, y aquí la corrompe.

El mismo dato desactualizado también:
- bloquea un conteo legítimo con "Es la misma cantidad que hay ahora" (`:126`);
- hace que la vista previa "Quedarán m" mienta.

Ni el `for update` ni el libro append-only lo evitan, porque el error está en la intención que se envía y no en la atomicidad.

**Corrección:** que el servidor reciba la cantidad esperada y rechace si cambió (concurrencia optimista). Otra opción es que reciba la cantidad absoluta del conteo y calcule él el delta:

```sql
-- mover_stock: nuevo parámetro opcional (drop + recreate + re-grant con la nueva firma)
p_cantidad_esperada int default null
...
if p_cantidad_esperada is not null and v_p.cantidad <> p_cantidad_esperada then
  raise exception 'El stock cambió (hay %).', v_p.cantidad using errcode = 'IN004';
end if;
```

```dart
// ajuste_sheet.dart -> actions.ajustar(..., cantidadEsperada: _esConteo ? _p.cantidad : null)
// IN004 -> ErrorInventario.stockCambio: invalidar productoProvider/productosProvider y mostrar
// "El stock cambió a N mientras contabas. Revisa y vuelve a aplicar."
```

Hay que añadir un caso en `rls_smoke_test.sql` (bloque S) donde un conteo con una cantidad esperada desactualizada falle sin cambiar nada.

## Warnings

### WR-01: `esErrorDeRed` no reconoce la excepción real de socket de `package:http`, así que D-12 ("Sin conexión…") no se cumple

**Archivo:** `lib/features/inventory/data/repositories/supabase_inventario_repository.dart:312-316`

**Problema:** la detección compara `e.runtimeType.toString()` con `'SocketException'` o `'ClientException'`. `http 1.6.0` (fijado en `pubspec.lock`) envuelve los errores de socket de `IOClient` en `_ClientSocketException extends ClientException implements SocketException` (`io_client.dart:27`, se lanza en `:227`). Su `runtimeType` es `"_ClientSocketException"`, que no coincide con ninguno de los dos nombres. Ese es precisamente el caso típico de "sin señal".

Además, con `--obfuscate` en release, `runtimeType.toString()` devuelve nombres ofuscados y la detección falla siempre.

El resultado es que el usuario sin conexión ve "No pudimos guardar el ajuste. Intenta de nuevo." en lugar del mensaje de D-12.

Los tests (`test/supabase_inventario_repository_test.dart:12-14, 76-84`) definen clases falsas que se llaman `SocketException` y `ClientException`, así que pasan aunque el código falle con la excepción real.

**Corrección:** comprobar el tipo, no el nombre. `package:http` se puede importar en web, así que se mantiene la restricción de no usar `dart:io`:

```dart
import 'package:http/http.dart' as http; // declararlo como dependencia directa
bool esErrorDeRed(Object e) =>
    e is TimeoutException || e is http.ClientException; // _ClientSocketException es ClientException
```

En el test, usar `http.ClientException('x')` real.

### WR-02: el cliente acepta ajustes que el servidor siempre rechaza (tope del delta y tope del resultado)

**Archivo:** `lib/features/inventory/presentation/widgets/ajuste_sheet.dart:124-132`. Relacionado: `supabase/schema.sql:4420`.

**Problema:**
- La hoja valida `n <= kCantidadMaxima` (1.000.000), pero `mover_stock` rechaza `abs(p_delta) > 100000`. Una compra de 150.000 ml, o un conteo de 0 a 200.000, pasa la validación local y luego falla.
- Tampoco se valida que `cantidad + delta <= 1.000.000`. Si se supera, salta el CHECK `productos_cantidad_no_negativa`, que también tiene el tope superior.

Ambos casos llegan como `23514`, se mapean a `datosInvalidos`, y `textoErrorEnHoja` muestra el genérico "No pudimos completar la operación". El usuario no tiene forma de saber qué pasó. `crear_producto` sí admite hasta 1.000.000 de entrada, lo que hace la regla aún más inconsistente.

**Corrección:**
- Definir `kAjusteMaximo = 100000` en `stock.dart`.
- En `_errorValidacion`, rechazar `_delta.abs() > kAjusteMaximo` ("El ajuste máximo es 100.000.") y `_quedarian > kCantidadMaxima`.
- Hacer que `textoErrorEnHoja` muestre un texto útil para `datosInvalidos`.

### WR-03: un ajuste que el servidor sí guardó se reporta como "no se guardó"; reintentarlo lo duplica

**Archivo:** `lib/features/inventory/data/repositories/supabase_inventario_repository.dart:16-17, 39-43`, `lib/features/inventory/presentation/widgets/ajuste_stock.dart:18-20` y `lib/features/inventory/presentation/providers/inventario_providers.dart:378-385`.

**Problema:** un `TimeoutException` o un corte de red **después** de que Postgres confirmó `mover_stock` se convierte en "Sin conexión. El ajuste no se guardó." Esa afirmación no se puede saber desde el cliente. Con señal intermitente, que es el escenario objetivo (consulta a domicilio), el usuario reintenta y el movimiento queda **doble** (por ejemplo, −2 en lugar de −1). La RPC no es idempotente.

Además, `_mover` solo invalida con `stockInsuficiente` o `noDisponible`. Con `sinConexion`, `yaDeshecho` u `otro`, la lista y el detalle siguen mostrando una cantidad que puede estar mal.

**Corrección:**
- Generar en el cliente una clave de idempotencia por intento (UUID). Enviarla en `p_ref_id`, o en un parámetro nuevo con índice único parcial `(clinica_id, ref_id) where origen = 'ajuste'`. Si la clave ya existe, el servidor devuelve el movimiento existente.
- Cambiar el texto a "No pudimos confirmar el ajuste. Revisa el historial antes de reintentar."
- Llamar a `invalidarInventario` en **cualquier** `InventarioFailure` dentro de `_mover`.

### WR-04: `mover_stock` deshace movimientos de cualquier origen y en cualquier momento; con la Fase 7 permitirá revertir salidas de factura

**Archivo:** `supabase/schema.sql:4441-4449`

**Problema:** la validación de deshacer solo excluye `v_o.motivo = 'deshacer'`. Hoy acepta revertir el movimiento `alta` (origen `alta`), y mañana aceptará los de `origen in ('dosis','factura')` que trae la Fase 7. El encabezado del bloque dice que la Fase 7 reutiliza esta RPC con `create or replace`.

Cualquier veterinario de la clínica podría llamar por PostgREST a `mover_stock(..., 'deshacer', p_deshace_id => <movimiento de una factura>)`. Eso devolvería el stock de una venta facturada sin tocar la factura y descuadraría el libro contra la facturación.

Tampoco hay ventana de tiempo ni comprobación de autor. La UI solo ofrece deshacer durante el snackbar de 6 s, pero el servidor lo permite sobre cualquier movimiento histórico.

**Corrección:**

```sql
if not found or v_o.origen <> 'ajuste' or v_o.motivo = 'deshacer' or p_delta <> -v_o.delta then
  raise exception 'Solo se puede deshacer el inverso exacto de un ajuste del mismo producto.' using errcode = 'check_violation';
end if;
-- opcional: and v_o.veterinario_id = auth.uid() and v_o.created_at > now() - interval '10 minutes'
```

Hay que añadir el caso "no se puede deshacer un alta" en S13.

### WR-05: la edición de un no-admin reenvía el mínimo y los precios de su copia local; un cambio concurrente del admin la convierte en un falso 42501

**Archivo:** `lib/features/inventory/presentation/screens/producto_form_screen.dart:237-245`. Relacionado: `supabase/schema.sql:4343-4348`.

**Problema:** el no-admin envía `original.minimo`, `original.precioVentaCop` y `original.costoCop` tal como estaban cuando cargó el formulario. Si el admin cambió alguno mientras tanto, `p_minimo is distinct from v_p.minimo` es verdadero. El colega recibe "Solo el administrador de la clínica puede hacer esto." aunque solo cambió el nombre, y no puede guardar hasta salir y volver a entrar.

Si quien guarda es el admin, la misma copia local sobrescribe en silencio los cambios del otro (gana el último que escribe) en campos que no tocó.

**Corrección:** que en `actualizar_producto` el `null` signifique "sin cambio" para mínimo y precios, y que el cliente no-admin los envíe en `null`:

```sql
v_minimo := coalesce(p_minimo, v_p.minimo); -- idem precio/costo, con un flag explícito para "borrar precio"
```

Otra opción es comparar con `updated_at` (concurrencia optimista) y mapear el conflicto a un mensaje propio.

### WR-06: `crear_producto` deja que cualquier veterinario fije los precios (y el mínimo), aunque D-13 los reserva al admin

**Archivo:** `supabase/schema.sql:4269-4310`, `lib/features/inventory/presentation/screens/producto_form_screen.dart` (sección "Más detalles" del alta, campos de precio y costo sin condición de admin)

**Problema:** D-13 dice "Solo el admin … cambia mínimo y precios", y `actualizar_producto` lo hace cumplir. `crear_producto`, en cambio, acepta `p_precio_venta_cop`, `p_costo_cop` y `p_minimo` de cualquier veterinario, y el formulario de alta los muestra a todos.

Un colega no-admin puede crear un producto con el precio de venta que quiera. La Fase 7 facturará con ese precio, y el colega no puede editarlo después, pero el admin tampoco se entera.

**Corrección:** decidirlo explícitamente.
- Si los precios son solo del admin, añadir a `crear_producto`: `if (p_precio_venta_cop is not null or p_costo_cop is not null) and not public.es_admin_clinica() then raise … insufficient_privilege` y ocultar esos campos en el alta para quien no es admin.
- Si no, documentar la excepción en D-13.

## Info

### IN-01: `productos()` no pagina y PostgREST corta en `max_rows` (1000 por defecto) sin avisar

**Archivo:** `lib/features/inventory/data/repositories/supabase_inventario_repository.dart:52-59`

Con más de 1000 productos activos, la lista, la búsqueda, el chip "Bajos (n)" y el pedido de WhatsApp trabajan sobre un subconjunto. La tarjeta de Inicio (`inventario_resumen`, que cuenta en el servidor) mostraría otro número. Conviene paginar, o al menos dejar documentado el límite.

### IN-02: el deshacer no pasa por `manejarLimitePlan`

**Archivo:** `lib/features/inventory/presentation/widgets/ajuste_stock.dart:120-122`

Si la cuenta pasa a solo lectura entre el ajuste y el toque en "Deshacer", el guard lanza LP004 y el usuario ve el texto genérico en lugar de la hoja de solo lectura que usa el resto de escrituras. Se puede reutilizar el mismo patrón de `aplicarAjusteConFeedback`, guardando el `BuildContext` o un callback.

### IN-03: archivar ignora `e.message` para `sinConexion`

**Archivo:** `lib/features/inventory/presentation/screens/producto_detail_screen.dart:536-537`

La rama `default` muestra el genérico y descarta el mensaje de "Sin conexión" que ya trae el `InventarioFailure`. Mejor usar `aviso(e.message)` en el `default`.

### IN-04: la hora del historial se muestra en la zona del dispositivo, no en la de Bogotá

**Archivo:** `lib/features/inventory/data/repositories/supabase_inventario_repository.dart:260` y `lib/features/inventory/presentation/widgets/movimiento_tile.dart:215`

`DateTime.parse(...).toLocal()` usa la zona horaria del teléfono, mientras que el resto de la fase razona en `diaBogota`. Si el teléfono tiene otra zona, fechas y horas del historial no coinciden con las del resto de la app. Conviene usar el helper de `core/utils/zona_bogota.dart`.

### IN-05: `desdeBd` corrige en silencio los valores desconocidos

**Archivo:** `lib/features/inventory/domain/entities/movimiento_stock.dart:173-174` y `lib/features/inventory/domain/entities/producto.dart:40-41, 59-60`

Un motivo nuevo del servidor (por ejemplo, de la Fase 7) se mostraría como "Conteo" y una unidad desconocida como "unidad", sin dejar rastro. Es mejor un valor explícito "desconocido" o un `assert` o log.

### IN-06: el mapeo de errores es demasiado general para 42501 y 23505

**Archivo:** `lib/features/inventory/data/repositories/supabase_inventario_repository.dart:276-307`

- `42501` siempre dice "Solo el administrador…". También lo reciben quienes no son veterinarios, los retirados y un `GRANT` faltante.
- `23505` siempre se traduce como "nombre duplicado", aunque podría venir de `movimientos_deshace_uq`.

Conviene distinguir el caso por `e.message` o `e.details`, o por códigos propios (IN00x) en las RPC.

### IN-07: el comentario del provider de permisos contradice D-13

**Archivo:** `lib/features/inventory/presentation/providers/inventario_providers.dart:263-264`

El comentario dice "Solo los administradores crean, editan y archivan". En realidad crea y edita cualquier veterinario y solo archivar, el mínimo y los precios son del admin. Hay que corregir el comentario para que nadie use este provider para bloquear el alta.

### IN-08: un id que no es UUID en `/inventario/:id` deja al usuario en un bucle de "Reintentar"

**Archivo:** `lib/features/inventory/presentation/screens/producto_detail_screen.dart:65-70`

`eq('id', 'abc')` produce `22P02`, que se mapea a `otro`, y la pantalla muestra "No pudimos cargar el producto" con un Reintentar que siempre falla. Lo correcto es tratar `22P02` como "no disponible", o validar el formato del id en la ruta.

---

_Revisado: 2026-11-13_
_Revisor: Claude (gsd-code-reviewer)_
_Profundidad: deep_

REVIEW: 1 critical, 6 warning
