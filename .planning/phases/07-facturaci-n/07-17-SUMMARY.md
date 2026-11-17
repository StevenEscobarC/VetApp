---
phase: 07-facturaci-n
plan: 17
type: gap-closure
subsystem: facturacion
tags: [cobros, idempotencia, crear_cuenta_cobro, actualizar_clinica, rls-smoke, gap-closure]
requires:
  - "07-01/07-04 bloque Fase 7 de schema.sql + bloque T del smoke"
  - "07-07/07-11/07-15 formulario de cobro, stock y modos"
  - "07-09 hoja Enviar (PDF y chat)"
  - "07-REVIEW.md (CR-01, WR-01..WR-06, IN-05)"
provides:
  - "Borrador bloqueado tras sin conexión: solo Reintentar o Descartar (CR-01)"
  - "Mensaje 'Ya estaba emitida: CC-NNNN.' / 'Ya estaba guardada: COT-NNNN.' con yaExistia"
  - "crear_cuenta_cobro repite la búsqueda por clave antes de BC002 y BC003 (WR-01)"
  - "Filtro Pendientes/Pagadas en el servidor (WR-02)"
  - "Inventario refrescado al abrir el formulario y el selector; tope local convertido en aviso (WR-03)"
  - "actualizar_clinica con p_nit default '__sin_cambio__' (WR-04)"
  - "PDF y chat se recuperan tras un fallo de red; texto de lectura sin conexión (WR-05)"
  - "23505 es 'nombre repetido' solo para clinica_servicios_nombre_activo_uq (WR-06)"
  - "Mensaje BC002 en la hoja de anular (IN-05)"
  - "Smoke T31..T32 (total 293)"
affects:
  - supabase/schema.sql
  - supabase/tests/rls_smoke_test.sql
  - lib/features/billing
tech-stack:
  added: []
  patterns:
    - "Bloqueo del borrador tras un fallo de red: la misma clave de idempotencia nunca viaja con otro contenido"
    - "Centinela como default de un parámetro opcional para distinguir 'no enviado' de 'null explícito' con una sola firma (sin ambigüedad en PostgREST)"
key-files:
  created:
    - .planning/phases/07-facturaci-n/07-17-SUMMARY.md
  modified:
    - supabase/schema.sql
    - supabase/tests/rls_smoke_test.sql
    - lib/features/billing/data/repositories/supabase_cobros_repository.dart
    - lib/features/billing/presentation/providers/cobros_providers.dart
    - lib/features/billing/presentation/screens/cobro_form_screen.dart
    - lib/features/billing/presentation/screens/cobros_screen.dart
    - lib/features/billing/presentation/widgets/anular_cobro_sheet.dart
    - lib/features/billing/presentation/widgets/enviar_cobro_sheet.dart
    - lib/features/billing/presentation/widgets/linea_cobro_tile.dart
    - lib/features/billing/presentation/widgets/producto_cobro_sheet.dart
    - test/helpers/fake_cobros.dart
    - test/cobro_form_screen_test.dart
    - test/cobros_screen_test.dart
    - test/cobros_invalidacion_test.dart
    - test/compartir_cobro_test.dart
    - test/anular_cobro_sheet_test.dart
    - test/supabase_cobros_repository_test.dart
    - .planning/phases/07-facturaci-n/07-VALIDATION.md
decisions:
  - "CR-01 usa la opción (a): tras sinConexion se bloquean líneas, cliente, mascota, servicios y tipo; el CTA pasa a 'Reintentar' y el banner ofrece 'Descartar'. No se genera una clave nueva (opción b), porque exigiría preguntar al servidor si la primera existe"
  - "El reintento no repite la validación local ni el diálogo de emisión: el contenido es el mismo que ya se confirmó"
  - "Cualquier respuesta del servidor (éxito, rechazo, LP004, BC002) resuelve el reintento y desbloquea; solo un nuevo sinConexion lo mantiene"
  - "Descartar con un reintento pendiente avisa: 'Si alcanzó a crearse, lo verás en Cobros.'"
  - "WR-04 usa el centinela, no una envoltura de 5 argumentos: con dos firmas, una llamada de 5 argumentos nombrados casaría con ambas (p_nit tiene default) y PostgREST respondería PGRST203"
  - "WR-03: el aviso local usa info_outline + textSecondary (no destructive); el error del servidor (IN001) sigue siendo destructive y, si existe, oculta el aviso. '+' ya no se detiene en el stock local"
  - "WR-03: el selector conserva el bloqueo de 'agotado' en una CC, pero relee el inventario al abrirse"
  - "WR-06 identifica la constraint por message o details de la PostgrestException"
metrics:
  completed: 2026-11-16
  tasks: 2
---

# Phase 7 Plan 17: gap closure de la revisión de código (CR-01, WR-01..WR-06, IN-05)

Tras un fallo sin conexión el borrador ya no se puede editar: solo se reintenta con el mismo contenido y la misma clave, o se descarta. Si el servidor ya lo había creado, el aviso dice "Ya estaba emitida: CC-NNNN.". Además, el servidor devuelve el documento existente en las carreras de reintento, Pendientes y Pagadas se filtran en el servidor, el stock local es solo un aviso, el NIT sobrevive a los builds viejos y el PDF se recupera tras perder la señal.

## Qué cambió

### CR-01 (crítico): editar tras una respuesta perdida
- `cobro_form_screen.dart`:
  - nuevo estado `_pendienteReintento`, que se activa solo con `ErrorCobro.sinConexion` al crear una CC o una cotización;
  - mientras está activo, `AbsorbPointer` bloquea el cuerpo, `LineaCobroTile.habilitado = false` y `TipoCobroToggle.habilitado = false`;
  - el CTA dice **"Reintentar"** y el banner sin conexión agrega un `TextButton` **"Descartar"**;
  - el reintento reenvía el mismo borrador y la misma clave, sin validar de nuevo ni volver a abrir el diálogo "¿Emitir la cuenta de cobro?";
  - cualquier respuesta del servidor desbloquea; un nuevo sin conexión mantiene el bloqueo;
  - "Descartar" (y el gesto atrás) preguntan "¿Descartar este cobro?". Con el reintento pendiente agregan "Si alcanzó a crearse, lo verás en Cobros.".
- `yaExistia` en el aviso de éxito:
  - CC: "Ya estaba emitida: CC-0001.";
  - cotización: "Ya estaba guardada: COT-0001.";
  - si es nuevo, sigue "Cuenta de cobro CC-0001 emitida." / "Cotización COT-0001 guardada.".
- Editar una cotización (`_guardarCambios`) no usa clave, así que no se bloquea.

### WR-01 (schema): carreras de reintento en `crear_cuenta_cobro`
- Antes del `raise` **BC003** de la pre-validación de visita y del `raise` **BC002** ("La cotización ya no está abierta."), la función vuelve a buscar la clave. Si existe una CC con esa clave, la devuelve con `ya_existia = true`.
- En READ COMMITTED, la nueva consulta ve lo que confirmó la petición concurrente, también después de esperar el `for update` de la cotización.

### WR-02: filtros en el servidor
- `SupabaseCobrosRepository.cobros(tipo, {EstadoCobro? estado})` agrega `.eq('estado', …)` antes de `order`/`limit(50)`.
- `cobrosProvider` es una familia por `FiltroCobros = ({TipoCobro tipo, EstadoCobro? estado})`.
- `CobrosScreen` pide `pendiente` o `pagada` según el chip. Ya no filtra en Dart.
- Los vacíos de Pendientes ("Nada por cobrar") y Pagadas no cambian.

### WR-03: stock desactualizado
- El formulario relee `productosProvider` al abrir (en `initState`, por microtarea fuera del build).
- `_observarOrigen` espera esa relectura (`isLoading`) antes de copiar una cotización.
- `ProductoCobroSheet` relee el inventario al abrirse.
- El tope local ya no bloquea:
  - `_lineaInvalida` solo mira la descripción y el precio;
  - "+" no se detiene en el stock;
  - el texto "Solo quedan N … de X." / "X está agotado." se muestra como aviso (`avisoStock`: `info_outline` + `textSecondary`);
  - IN001 del servidor sigue marcando la línea como error (`errorStock`, destructive) y oculta el aviso.

### WR-04 (schema): NIT y builds anteriores
- `actualizar_clinica(..., p_nit text default '__sin_cambio__')`:
  - con el centinela (llamada de 5 argumentos, posicionales o nombrados), el `update` conserva `clinicas.nit` y se salta la validación del NIT;
  - un `null` explícito lo sigue borrando, y el cliente actual siempre envía `p_nit`.
- **Una sola firma**. Se descartó la envoltura de 5 argumentos: con dos firmas, una llamada de 5 argumentos nombrados casaría con ambas, porque `p_nit` tiene default, y PostgREST no podría elegir (PGRST203).
- `create or replace` cambia el default sin `drop` de la firma de 6 argumentos, así que los grants se conservan. Igual se re-aplican.

### WR-05: PDF y chat tras un fallo de red
- `EnviarCobroSheet`:
  - antes de leer los datos, si `datosPdfCobroProvider(id)` tiene un error en caché, lo invalida;
  - tras un `sinConexion`, también lo invalida;
  - el segundo toque con señal comparte o abre el chat sin cerrar la hoja;
  - en el chat, sin red se muestra el texto de lectura, no "No pudimos abrir WhatsApp".
- Repositorio:
  - nueva `kMensajeSinConexionLectura = 'Sin conexión. Inténtalo de nuevo cuando tengas señal.'`, que es el default de `_run`;
  - la usan `cobros`, `cobro`, `resumen`, `cobroVinculado`, `servicios` y `datosPdf`;
  - las escrituras siguen pasando su propio texto.

### WR-06: 23505
- `_tipoDe` mapea `23505` a `nombreDuplicado` solo si el `message` o el `details` contienen `clinica_servicios_nombre_activo_uq`. Cualquier otro 23505 (p. ej. `cobros_numero_uq`) es `otro`, con el mensaje genérico.

### IN-05
- `AnularCobroSheet`: `ErrorCobro.cotizacionNoDisponible` → "Esta cotización ya se convirtió. Actualiza para ver su estado.".

## Esquema a re-aplicar en vivo (no se aplicó nada)

`supabase/schema.sql` en el commit `68f4581`:
- **Mínimo**, en una sola ejecución:
  - líneas **4934–5102**: comentario, `drop function if exists public.crear_cuenta_cobro(...)` y `create or replace function public.crear_cuenta_cobro` completo;
  - líneas **5506–5578**: comentario WR-04, `drop` de la firma de 5 argumentos (no-op en vivo) y `create or replace function public.actualizar_clinica` con el centinela;
  - líneas **5626–5627**: `revoke`/`grant` de `crear_cuenta_cobro`;
  - líneas **5646–5647**: `revoke`/`grant` de `actualizar_clinica` (6 argumentos);
  - línea **5649**: `notify pgrst, 'reload schema';`.
- **Alternativa equivalente e idempotente**: el bloque Fase 7 completo, líneas **4547–5649**.

**Importante:** el `drop` de `crear_cuenta_cobro` elimina sus grants. Las líneas 5626–5627 tienen que ir en la misma ejecución.

Mientras no se re-aplique:
- la app nueva funciona igual contra el esquema vivo: no cambian firmas ni parámetros, y el filtro por estado es un `eq` de PostgREST sobre una columna existente;
- solo faltan las dos defensas del servidor (WR-01 y WR-04).

## Smoke

- Bloque T: T1..T32.
  - **T31** (WR-01):
    - un reintento con la clave de una CC de visita ya cobrada devuelve esa CC con `ya_existia`, no BC003;
    - el cuerpo de `crear_cuenta_cobro` repite la búsqueda por clave justo antes de los `raise` BC002 y BC003. La carrera concurrente no se puede reproducir en una sola sesión.
  - **T32** (WR-04):
    - una llamada con 5 argumentos nombrados y otra con 5 posicionales conservan el NIT;
    - hay una sola firma `actualizar_clinica` y su default es `'__sin_cambio__'`.
- **Nuevo total: 293** (291 + 2).
  - Hay 293 `checks := checks + 1` y una sola cabecera "Total esperado: 293.".
  - El comando de la suite completa en `07-VALIDATION.md` se actualizó a 293.
  - Los registros históricos (291 en 07-04/07-08) no se tocaron.
- Postgres local desechable (`public.ecr.aws/supabase/postgres:17.11.0.011`, contenedor `vetapp-0717-scratch`, eliminado después), con los mismos shims locales de 07-01/07-04: `auth.uid()`/`auth.role()` desde `request.jwt.claims` y un `storage` mínimo.
  - schema de `6a561d0` + smoke nuevo: `RLS SMOKE: FAIL (4 de 293 checks) -> T31 … | T32 … | T32 … | T32 …` (los 4 mensajes son de T31 y T32; todo lo demás pasa);
  - schema nuevo aplicado encima (dos veces, sin errores): `RLS SMOKE: PASS (293 checks) - cambios revertidos`.
- Resultado esperado en vivo tras re-aplicar: `RLS SMOKE: PASS (293 checks) - cambios revertidos`. Está pendiente: lo pega el usuario.

## Verificación (líneas literales)

```
flutter analyze -> No issues found! (ran in 55.0s)
flutter test    -> 01:34 +1466: All tests passed!
grep -rn factur lib -> lib/features/inventory/domain/entities/movimiento_stock.dart:61:const String kOrigenCobro = 'factura';
```

Por archivo: cobro_form_screen 62, cobros_screen 25, compartir_cobro 15, anular_cobro_sheet 16, supabase_cobros_repository 41, cobros_invalidacion 19.

Rojo (`d4fdec8`):
- `flutter analyze` daba 6 errores de compilación: no existían `kMensajeSinConexionLectura`, `cobros(…, estado:)` ni la clave `(tipo, estado)`;
- `flutter test` de formulario, cobros, compartir y anular daba `+102 -16: Some tests failed.`.

## Commits

- `d4fdec8` test(07-17): pruebas en rojo (formulario, lista, hojas, repositorio) y smoke T31..T32 (total 293).
- `68f4581` fix(07-17): implementación (schema, repositorio, providers, formulario, hojas).
- docs(07-17): este SUMMARY y VALIDATION.

## Deviations from Plan

1. **[Rule 1 - prueba del mismo plan] `MockClient` sin `request`** (`68f4581`).
   - Las 3 pruebas nuevas de WR-02 respondían con `http.Response` sin `request:`, y postgrest falla al parsear (`Null check operator` en `_parseResponse`).
   - Se agregó `request: r` al doble. Las aserciones (tipo, estado y limit en la URL) no cambiaron.
2. **Pruebas existentes cuyo comportamiento cambió por la revisión** (rojo `d4fdec8`, no se debilitaron):
   - "CC repetida (yaExistia) también avisa emitida" ahora exige "Ya estaba emitida: CC-0001." y que NO aparezca "emitida";
   - "sin conexión … MISMA clave" ahora exige "Reintentar", "Descartar", ningún diálogo y las mismas líneas;
   - "'+' se detiene en el stock" pasó a "pasar el stock local es un aviso, no un tope";
   - "emitir con una línea inválida" usa una línea "Otro" vacía en vez del exceso de stock, que ya no es inválido;
   - el caso `23505` genérico del mapa de códigos ahora espera `otro`, y se agregó el caso con la constraint de servicios.
3. **Sin tocar la base viva, el MCP de Supabase ni Linear**, como se pidió. El smoke corrió solo en un contenedor local desechable.
4. **Archivos generados de plugins**: `flutter pub get` reescribió el final de línea en `linux/`, `macos/` y `windows/`. Los restauré archivo por archivo y no están en los commits.
5. **`07-REVIEW.md` no está en la base `6a561d0`**: está en master en `619fa3b`. Lo leí desde el checkout principal y no lo incluí en esta rama.

## Known Stubs

Ninguno.

## Threat Flags

Ninguno nuevo. Las dos funciones siguen siendo `security definer set search_path = public`, con las mismas validaciones de clínica y los mismos grants. La re-búsqueda por clave filtra por `clinica_id = mi_clinica_id()`.

## Self-Check: PASSED

- `d4fdec8` y `68f4581` existen en la rama `worktree-agent-add20910ae3944c28`.
- `supabase/schema.sql` contiene `p_nit text default '__sin_cambio__'` y dos nuevas re-búsquedas `WR-01 (07-17)`.
- El smoke tiene 293 `checks := checks + 1` y una sola cabecera "Total esperado: 293.".
