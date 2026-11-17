---
phase: 07-facturaci-n
reviewed: 2026-11-16T00:00:00Z
depth: deep
files_reviewed: 46
files_reviewed_list:
  - supabase/schema.sql (Fase 7, líneas 4547-5631)
  - supabase/tests/verify_live_schema.sh
  - lib/core/router/app_router.dart
  - lib/core/utils/formato.dart
  - lib/features/billing/data/repositories/supabase_cobros_repository.dart
  - lib/features/billing/data/services/cobro_pdf_service.dart
  - lib/features/billing/domain/clave_idempotencia.dart
  - lib/features/billing/domain/cobro_failure.dart
  - lib/features/billing/domain/entities/cobro.dart
  - lib/features/billing/domain/entities/cobro_item.dart
  - lib/features/billing/domain/numeracion.dart
  - lib/features/billing/domain/pesos_en_letras.dart
  - lib/features/billing/domain/whatsapp_cobro.dart
  - lib/features/billing/presentation/cobros_routes.dart
  - lib/features/billing/presentation/cobros_rutas.dart
  - lib/features/billing/presentation/providers/borrador_cobro_provider.dart
  - lib/features/billing/presentation/providers/cobro_pdf_providers.dart
  - lib/features/billing/presentation/providers/cobros_providers.dart
  - lib/features/billing/presentation/screens/cobro_detail_screen.dart
  - lib/features/billing/presentation/screens/cobro_form_screen.dart
  - lib/features/billing/presentation/screens/cobros_screen.dart
  - lib/features/billing/presentation/widgets/anular_cobro_sheet.dart
  - lib/features/billing/presentation/widgets/cobrar_boton.dart
  - lib/features/billing/presentation/widgets/enviar_cobro_sheet.dart
  - lib/features/billing/presentation/widgets/linea_cobro_tile.dart
  - lib/features/billing/presentation/widgets/marcar_pagada_sheet.dart
  - lib/features/billing/presentation/widgets/producto_cobro_sheet.dart
  - lib/features/billing/presentation/widgets/servicio_sheet.dart
  - lib/features/clients/data/repositories/supabase_cliente_repository.dart
  - lib/features/clients/domain/entities/cliente.dart
  - lib/features/clients/presentation/screens/cliente_detail_screen.dart
  - lib/features/clinic/data/repositories/supabase_clinica_repository.dart
  - lib/features/clinic/domain/clinica.dart
  - lib/features/clinic/presentation/providers/datos_clinica_providers.dart
  - lib/features/clinic/presentation/screens/datos_clinica_screen.dart
  - lib/features/appointments/presentation/screens/cita_detail_screen.dart
  - lib/features/appointments/presentation/screens/completar_cita_screen.dart
  - lib/features/clinical_history/presentation/screens/consulta_form_screen.dart
  - lib/features/clinical_history/presentation/widgets/historia_clinica_timeline.dart
  - lib/features/home/presentation/screens/mas_screen.dart
  - lib/features/inventory/data/repositories/supabase_inventario_repository.dart
  - lib/features/inventory/domain/entities/movimiento_stock.dart
  - lib/features/inventory/presentation/widgets/movimiento_tile.dart
  - lib/features/inventory/presentation/providers/inventario_providers.dart
  - test/cobros_select_embed_test.dart
  - test/helpers/fake_cobros.dart
findings:
  critical: 1
  warning: 6
  info: 8
  total: 15
status: issues_found
---

# Fase 7: Informe de revisión de código

**Revisado:** 2026-11-16
**Profundidad:** deep
**Archivos revisados:** 46
**Estado:** issues_found

## Resumen

Revisé el rango `7cbaa03..7d85c01` (lib, supabase, test), con foco en las RPC `security definer` y en la integración del cliente.

**Lo que está bien en el servidor:**
- **Aislamiento por clínica:** toda lectura y escritura filtra por `mi_clinica_id()`. La FK compuesta `cobro_items(cobro_id, clinica_id)` impide líneas de otra clínica. Productos y servicios ajenos se rechazan sin revelar si existen.
- **Numeración sin huecos:** el contador vive en `cobro_contadores` y está en el mismo sub-bloque que el encabezado, las líneas y el stock. Si algo falla, el número se revierte.
- **Stock:** se descuenta en orden de `producto_id`, con `for update`, sin negativos (IN001) y sin tocar `mover_stock`.
- **Anulación:** la reversión acepta productos archivados. Los permisos son admin o emisor para anular, y solo admin para servicios.
- **`guard_solo_lectura`:** cubre las 4 tablas nuevas.
- **`es_autor_en_mi_clinica`:** conserva sus 4 brazos.
- **`cobro_para_pdf`:** no expone el teléfono del cliente ni la clave.

**Lo que está bien en el cliente:**
- `esErrorDeRed` ya usa `is ClientException` (WR-01 de la 06 resuelto).
- `CobrosActions` invalida en `finally` (WR-03 resuelto).
- La clave se crea una sola vez por borrador.
- La palabra "factura" solo aparece en `kOrigenCobro`.
- Facturación usa `clockProvider` y no `DateTime.now()`.
- La presentación no importa `supabase_flutter`: solo el provider del repositorio, igual que las demás features.

**Hallazgos principales:**
- **CR-01:** la clave es estable, pero el contenido del borrador no. Tras una respuesta perdida, el usuario puede editar y reintentar, y el servidor devuelve en silencio el documento viejo.
- **Carreras de reintento:** un reintento concurrente de una conversión cae en BC002 en vez de devolver el documento ya creado.
- **Lista de pendientes:** el filtro trabaja sobre las últimas 50 y oculta cuentas pendientes antiguas.
- **Stock desactualizado:** el tope local con stock viejo bloquea emisiones válidas (la misma clase de problema que CR-01 de la 06).
- **NIT:** se borra si alguien guarda los datos de la clínica desde un build anterior.

## Problemas críticos

### CR-01: Un reintento con la misma clave tras editar el borrador "emite" en silencio el documento viejo

**Archivo:** `lib/features/billing/presentation/screens/cobro_form_screen.dart:386-422` (además `:801-827`). Relacionado: `lib/features/billing/presentation/providers/borrador_cobro_provider.dart:176`, `supabase/schema.sql:4976-4983` y `:5123-5130`.

**Problema:** la clave de idempotencia se fija al abrir el borrador. Tras un `sinConexion`, el formulario vuelve a ser editable: `AbsorbPointer` solo se activa con `_loading`, y el toggle de tipo sigue habilitado. Ese es justo el caso D-21: el servidor confirmó pero la respuesta se perdió.

**Escenario A: cambia el contenido.** El veterinario baja una cantidad, quita una línea o cambia un precio, y reintenta.
- El servidor encuentra la clave y devuelve la CC original con `ya_existia = true`, sin comparar el payload.
- El cliente ignora `yaExistia` y muestra "Cuenta de cobro CC-0012 emitida."
- El veterinario cree que emitió su versión corregida. El documento guardado, el total que se comparte y el stock descontado son los de la primera versión.

**Escenario B: cambia el tipo.** El veterinario pasa de CC a Cotización y reintenta.
- El servidor responde `check_violation` ("Esa clave ya se usó en otro documento").
- El cliente lo muestra como "No pudimos guardar la cotización". El borrador nunca se podrá guardar, porque la clave no cambia.
- Mientras tanto, la CC existe sin que el usuario lo sepa.

**Arreglo:**
1. Tras un fallo `sinConexion`, bloquea la edición del borrador (líneas, cliente, mascota y tipo) hasta que un reintento resuelva. La única acción posible es "Reintentar"; para cambiar algo, primero se descarta.
2. Además, usa `yaExistia`. Si vuelve `true`, no digas "emitida": navega al detalle con "Este cobro ya se había emitido. Revisa su contenido."

```dart
// _emitir, rama sinConexion
setState(() { _pendienteReintento = true; _banner = _bannerPara(e, b.tipo); });
// build: AbsorbPointer(absorbing: _loading || _pendienteReintento, ...) y toggle deshabilitado
// éxito:
final texto = r.yaExistia
    ? '$numero ya estaba emitida. Revisa su contenido.'
    : (esCc ? 'Cuenta de cobro $numero emitida.' : 'Cotización $numero guardada.');
```

Opcional en el servidor: guarda un hash del payload junto a la clave y responde con un error propio (BC004, "la clave ya se usó con otro contenido") si no coincide.

## Advertencias

### WR-01: Un reintento concurrente de una conversión, o de un cobro de visita, devuelve BC002/BC003 en vez del documento ya creado

**Archivo:** `supabase/schema.sql:4976-4983`, `:5021-5031` y `:5033-5043`

**Problema:** la búsqueda por clave se hace una sola vez, al inicio y sin bloqueo.

**Caso conversión:** la petición A (convertir COT-0004, clave K) supera su timeout en el cliente pero sigue corriendo. El reintento B, con la misma K, no ve todavía la CC de A. B espera en `select ... for update` sobre la cotización. Cuando A confirma, B vuelve a leer la fila, ve `estado = 'convertida'` y lanza BC002.

En el cliente, BC002 activa `_marcarNoUsable`: "Esta cotización ya no se puede usar". El usuario no se entera de que su CC sí se creó. Lo mismo pasa con la pre-validación BC003 (`:5021`) si A confirma entre `:4976` y `:5021`.

El fallback `unique_violation` solo cubre la carrera que llega hasta el `insert`.

**Arreglo:** antes de lanzar BC002 o BC003, repite la búsqueda por clave.

```sql
if v_cot.estado <> 'abierta' then
  select * into v_prev from public.cobros c where c.clinica_id = v_clinica and c.clave_idempotencia = p_clave;
  if found and v_prev.tipo = 'cuenta_cobro' then
    return query select v_prev.id, v_prev.numero, true; return;
  end if;
  raise exception 'La cotización ya no está abierta.' using errcode = 'BC002';
end if;
```

Haz lo mismo antes del `raise` BC003 de `:5028`. Agrega un smoke test de dos llamadas con la misma clave.

### WR-02: Los filtros "Pendientes"/"Pagadas" trabajan sobre las 50 más recientes y ocultan cuentas pendientes antiguas

**Archivo:** `lib/features/billing/presentation/screens/cobros_screen.dart:241-249`. Relacionado: `lib/features/billing/data/repositories/supabase_cobros_repository.dart:87-96`.

**Problema:** `cobros(tipo)` trae las últimas `kCobrosLista` (50), sin filtrar por estado, y el filtro se aplica en Dart.

Una clínica con más de 50 CC verá en el encabezado "Por cobrar: $ X (n pendientes)", porque `cobros_resumen` cuenta todas. Pero el filtro "Pendientes" no muestra las que quedaron fuera de las 50. No hay paginación ni búsqueda, así que esa CC no se puede abrir desde Cobros para marcarla pagada. Solo queda llegar por la cita o la consulta, si tiene.

**Arreglo:** pasa el estado al repositorio y filtra en el servidor.

```dart
Future<List<Cobro>> cobros(TipoCobro tipo, {EstadoCobro? estado}) => _run(() async {
  var q = _client.from('cobros').select(kSelectCobro).eq('tipo', tipo.bd);
  if (estado != null) q = q.eq('estado', estado.bd);
  ...
```

Haz que la familia del provider tenga como clave `(tipo, estado)`.

### WR-03: El tope local de stock, con existencias desactualizadas, bloquea emisiones que el servidor aceptaría (misma clase que CR-01 de la 06)

**Archivo:** `lib/features/billing/presentation/screens/cobro_form_screen.dart:192-206` (usado en `_validarLocal`, `:272`). Relacionado: `lib/features/billing/presentation/widgets/producto_cobro_sheet.dart:125,133` y `borrador_cobro_provider.dart:244,308`.

**Problema:** el stock de cada línea es una copia de `productosProvider` al agregarla o al cargar el origen.

Si Inventario está montado en otra rama, el provider puede llevar horas en caché. Si un colega repuso stock, aparecen dos bloqueos:
- `_errorStockLocal` marca la línea inválida y `_validarLocal` no deja enviar.
- El selector bloquea el producto "agotado".

Como el envío nunca llega al servidor, la nota de existencias nunca se corrige. IN001 sí la corregiría con `quedan`. El comentario dice "cortesía: el servidor es la autoridad", pero en la práctica es un bloqueo duro con datos viejos. Al convertir una cotización vieja también se usan las existencias en caché.

**Arreglo:**
- Refresca el inventario al abrir el formulario de CC y el selector: `ref.invalidate(productosProvider)` en `initState` o al abrir la hoja.
- Convierte el tope local en aviso, no en bloqueo: deja enviar y que IN001 decida. Otra opción es refrescar las existencias de esas líneas justo antes de bloquear.

### WR-04: `p_nit default null` borra el NIT cuando guarda un cliente sin el campo (builds anteriores)

**Archivo:** `supabase/schema.sql:5497-5498, 5511, 5546`. Relacionado: `lib/features/clinic/data/repositories/supabase_clinica_repository.dart:47`.

**Problema:** la decisión registrada ("null lo borra") es correcta para el cliente actual, que siempre envía el valor. Pero la firma de 5 argumentos se eliminó y la nueva tiene `p_nit default null`.

Una app instalada con la versión anterior a la Fase 7 sigue llamando `actualizar_clinica` con 5 parámetros nombrados. PostgREST la resuelve a la función de 6 con el default, y el NIT queda en `null` en silencio. Esto pasa cada vez que un admin con la app vieja cambia el teléfono o el logo. El NIT desaparece de los PDF sin aviso.

**Arreglo:** distingue "no enviado" de "borrar".
- Opción 1: usa un centinela como default, por ejemplo `p_nit text default '__sin_cambio__'`, y `nit = case when p_nit = '__sin_cambio__' then nit else v_nit end`. El cliente nuevo sigue enviando `null` para borrar.
- Opción 2: conserva la firma de 5 argumentos como envoltura que llama a la de 6 con el NIT actual.

### WR-05: El PDF y el chat no se recuperan tras un fallo de red mientras la hoja sigue abierta, y el mensaje sin conexión de las lecturas es falso

**Archivo:** `lib/features/billing/presentation/widgets/enviar_cobro_sheet.dart:83-85, 98-100, 108-110, 131`. Relacionado: `lib/features/billing/data/repositories/supabase_cobros_repository.dart:59, 87-117, 252-259, 291-312`.

**Problema 1: el error queda en caché.** La hoja observa `datosPdfCobroProvider(id)` (`:131`). Si la primera carga falla por red, el provider guarda el error. Mientras la hoja esté abierta, nada lo invalida: cada toque en "Compartir PDF" o "Enviar PDF por WhatsApp" lee `.future` y recibe el mismo error al instante, aunque ya haya señal. El usuario tiene que cerrar y volver a abrir la hoja.

**Problema 2: el texto no corresponde.** `_run` usa por defecto `kMensajeSinConexionServicio` ("Sin conexión. No se guardaron los cambios…"). Eso afecta a `datosPdf`, `cobros`, `cobro`, `resumen`, `servicios` y `cobroVinculado`, que son lecturas. El snackbar del PDF dice "No se guardaron los cambios" cuando el usuario solo quería compartir.

**Arreglo:**
- En el `on CobroFailure` de `_compartirPdf` y `_chat`, llama a `ref.invalidate(datosPdfCobroProvider(widget.cobro.id))` antes de avisar.
- Agrega en el repositorio una constante para lecturas, por ejemplo `'Sin conexión. Inténtalo de nuevo cuando tengas señal.'`, y pásala como `sinConexion:` en todas las lecturas.

### WR-06: Una violación de unicidad inesperada en las RPC de cobro llega a la UI como "Ya tienes un servicio con ese nombre"

**Archivo:** `lib/features/billing/data/repositories/supabase_cobros_repository.dart:486`. Relacionado: `supabase/schema.sql:5085, 5169`.

**Problema:** `crear_cuenta_cobro` y `crear_cotizacion` relanzan con `raise;` cualquier `unique_violation` que no sea la clave ni la visita, por ejemplo `cobros_numero_uq` si el contador queda desfasado tras una restauración o una carga manual. `_tipoDe` mapea todo `23505` a `nombreDuplicado`. El banner del formulario cae en el genérico, pero `e.message` dice "Ya tienes un servicio con ese nombre".

Lo mismo pasa al reintentar `guardar_servicio` (crear) tras una respuesta perdida: el servicio ya existe y se informa como duplicado. Eso es engañoso aunque inocuo.

**Arreglo:** mapea `23505` a `nombreDuplicado` solo para las operaciones de servicio. Pasa un indicador a `cobroFailureDe`, o comprueba `e.message`/`constraint` contra `clinica_servicios_nombre_activo_uq`. En el servidor, convierte `cobros_numero_uq` en un error propio con un mensaje genérico.

## Info

### IN-01: Si el embed no resuelve, el detalle muestra "Ver CC-0000"; la sonda en vivo no valida la forma del embed autorreferente

**Archivo:** `lib/features/billing/presentation/screens/cobro_detail_screen.dart:194`. Relacionado: `supabase/tests/verify_live_schema.sh` (sonda `cobros conversion embed`) y `supabase_cobros_repository.dart:53-54, 398-399`.

**Problema:** `probe_embed ... allow_denied` acepta 401 con `anon`. Eso prueba que el hint no da 400/300, pero no que `cobros!convertida_en_id` llegue como objeto (M2O) y no como arreglo. Si llega como arreglo, `_numeroEmbed` devuelve `null` en silencio y el botón dice "Ver CC-0000".

Además, el 400 inicial por nombre de constraint, con la FK presente, sugiere que el nombre en vivo no es `cobros_convertida_en_fkey`. Habría que revisar si `create table if not exists` dejó nombres automáticos en vivo.

**Arreglo:**
- Agrega una prueba autenticada (smoke T) que lea una cotización convertida por PostgREST y compruebe que `convertida.numero` viene informado.
- En la UI, si `convertidaEnNumero` es `null`, muestra "Ver cuenta de cobro".

### IN-02: El `select *` de `cobros` devuelve `clave_idempotencia` a los veterinarios de la clínica

**Archivo:** `supabase/schema.sql:4703-4705`. Relacionado: `supabase_cobros_repository.dart:49-50`.

**Problema:** `cobro_para_pdf` quita la clave, pero `kSelectCobro` usa `*` y la policy no restringe columnas. No veo un impacto real: la clave solo sirve dentro de la misma clínica y devuelve un documento que el colega ya puede leer. Aun así, contradice el comentario "la clave no sale del servidor".

**Arreglo:** `revoke select (clave_idempotencia) on public.cobros from authenticated` (con un grant por columnas) o lista explícita de columnas en `kSelectCobro`.

### IN-03: En una CC de cita sin consulta no se valida que la mascota pertenezca a la cita

**Archivo:** `supabase/schema.sql:5005-5019`

**Problema:** con `p_cita_id` y sin `p_consulta_id`, solo se exige que la mascota sea del cliente. Puede ser una mascota del mismo dueño que no estuvo en la cita, y el PDF diría "Mascota: X" por una visita de Y.

**Arreglo:** si `v_cita` no es null y `v_mascota` tampoco, exige `exists (select 1 from cita_mascotas where cita_id = v_cita and mascota_id = v_mascota)`.

### IN-04: La reversión al anular puede quedar bloqueada por el tope superior de stock

**Archivo:** `supabase/schema.sql:4769-4775` (con `:4193`)

**Problema:** `productos_cantidad_no_negativa` exige `cantidad <= 1000000`. Si después de la venta se registraron compras hasta cerca del tope, devolver el stock al anular viola el CHECK (23514). Esa CC no se puede anular nunca. Es un caso raro.

**Arreglo:** valida `v_nueva > 1000000` en `_aplicar_movimiento_stock` con un mensaje claro, o documenta el caso límite.

### IN-05: La hoja de anular no tiene mensaje para BC002 (cotización ya convertida)

**Archivo:** `lib/features/billing/presentation/widgets/anular_cobro_sheet.dart:100-109`

**Problema:** si un colega convirtió la cotización mientras la hoja estaba abierta, BC002 cae en el genérico "No pudimos anular. Intenta de nuevo." Reintentar nunca funcionará.

**Arreglo:** agrega `ErrorCobro.cotizacionNoDisponible => 'Esta cotización ya se convirtió. Actualiza para ver su estado.'`.

### IN-06: `cobroVinculado` interpola ids en el filtro `.or()` de PostgREST

**Archivo:** `lib/features/billing/data/repositories/supabase_cobros_repository.dart:135-145`

**Problema:** `'cita_id.eq.$cita'` concatena el texto tal cual. Hoy los ids vienen de entidades, no de la URL, y la RLS limita el alcance. Aun así, un id con `,` o `)` rompería la sintaxis del filtro.

**Arreglo:** valida que sean UUID antes de componer, o usa dos consultas con `.eq`.

### IN-07: Los precios de las líneas no avisan si la tarifa cambió con el borrador abierto

**Archivo:** `lib/features/billing/presentation/providers/borrador_cobro_provider.dart:277-311`

**Problema:** el precio del servicio o producto se copia al agregar la línea. Si el admin cambia la tarifa mientras el borrador está abierto, se emite el precio viejo sin aviso. D-07 permite precios por línea, así que no es inseguro, pero es un dato viejo silencioso. Al convertir, el precio de la cotización se respeta por diseño.

**Arreglo (opcional):** al emitir, compara `precioBaseCop` con el catálogo refrescado y muestra "La tarifa de X cambió a $ Y".

### IN-08: Una cotización convertida cuya CC se anuló no se puede reconvertir ni anular

**Archivo:** `supabase/schema.sql:5040-5042, 5246-5248`

**Problema:** al anular la CC, la cotización queda `convertida` y apunta a una CC anulada. El camino de reemisión es "Emitir una nueva" desde la CC anulada, lo cual es aceptable según D-10. Pero el detalle de la cotización sigue diciendo "Convertida en CC-00NN" sin indicar que esa CC está anulada.

**Arreglo:** en `_AccionesCotConvertida`, muestra el estado de la CC destino, o documenta el flujo.

---

_Revisado: 2026-11-16_
_Revisor: Claude (gsd-code-reviewer)_
_Profundidad: deep_

REVIEW: 1 critical, 6 warning
