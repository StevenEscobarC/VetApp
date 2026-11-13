---
phase: 06-inventario
plan: 10
type: gap-closure
subsystem: inventario
tags: [inventario, mover_stock, concurrencia-optimista, rls-smoke, gap-closure]
requires:
  - "06-01 bloque Fase 6 de schema.sql + bloque S del smoke"
  - "06-06 hoja de ajuste y ajuste rápido"
provides:
  - "mover_stock con p_cantidad_esperada (IN004) y deshacer solo de ajustes"
  - "ErrorInventario.stockCambio + copy"
  - "esErrorDeRed por tipo (http.ClientException)"
  - "topes del servidor validados en la hoja"
  - "smoke S21..S23 (total 261)"
affects:
  - supabase/schema.sql
  - supabase/tests/rls_smoke_test.sql
  - lib/features/inventory
tech-stack:
  added:
    - "http ^1.6.0 como dependencia directa (ya estaba fijada 1.6.0 como transitiva; el lock no cambia de versión)"
  patterns:
    - "Concurrencia optimista en la RPC: el cliente envía la cantidad sobre la que calculó el delta y el servidor la compara con la fila bloqueada for update"
key-files:
  created:
    - .planning/phases/06-inventario/06-10-SUMMARY.md
  modified:
    - supabase/schema.sql
    - supabase/tests/rls_smoke_test.sql
    - lib/features/inventory/data/repositories/supabase_inventario_repository.dart
    - lib/features/inventory/domain/inventario_failure.dart
    - lib/features/inventory/domain/stock.dart
    - lib/features/inventory/presentation/providers/inventario_providers.dart
    - lib/features/inventory/presentation/widgets/ajuste_sheet.dart
    - lib/features/inventory/presentation/widgets/ajuste_stock.dart
    - pubspec.yaml
    - pubspec.lock
    - test/ajuste_sheet_test.dart
    - test/supabase_inventario_repository_test.dart
    - test/inventario_invalidacion_test.dart
    - test/ajuste_rapido_test.dart
    - test/helpers/fake_inventario.dart
    - .planning/phases/06-inventario/06-VALIDATION.md
    - .planning/phases/06-inventario/06-09-PLAN.md
decisions:
  - "CR-01 se resuelve con concurrencia optimista (p_cantidad_esperada), no con delta calculado en el servidor: la RPC sigue recibiendo solo deltas y el libro no cambia"
  - "p_cantidad_esperada solo viaja cuando tiene valor (conteo): los demás ajustes siguen funcionando aunque el esquema vivo aún tenga la firma de 7 argumentos"
  - "WR-04 usa el check_violation existente ('Solo se puede deshacer el inverso exacto de un ajuste del mismo producto.') añadiendo origen <> 'ajuste' a la condición"
  - "Tras IN004 la hoja conserva lo contado y relee el producto: la cabecera muestra la cantidad fresca y reaplicar envía el delta correcto"
metrics:
  completed: 2026-11-13
  tasks: 4
---

# Phase 6 Plan 10: gap closure de la revisión de código (CR-01, WR-01, WR-02, WR-04)

El conteo físico ya no puede fijar una cifra distinta a la contada: `mover_stock` recibe la cantidad esperada y rechaza con IN004 si el stock cambió. Además, deshacer queda limitado a ajustes manuales, la detección de "sin conexión" reconoce la excepción real de `package:http` y la hoja de ajuste valida los mismos topes que el servidor.

## Qué cambió

### CR-01 (crítico): conteo sobre una cantidad desactualizada
- `supabase/schema.sql`: `mover_stock` tiene un nuevo parámetro final `p_cantidad_esperada int default null`. Si no es null y difiere de `v_p.cantidad`, que se lee de la fila bloqueada `for update`, lanza `IN004` con el mensaje "El stock cambió mientras contabas. Revisa la cantidad actual e intenta de nuevo." En ese caso no se escribe nada.
- El bloque sigue siendo idempotente:
  - `drop function if exists` de la firma vieja `(uuid, int, text, text, uuid, text, uuid)` y de la nueva `(…, int)`;
  - `revoke`/`grant` con la firma nueva exacta de 8 argumentos.
- Repositorio:
  - `moverStock(..., cantidadEsperada)` envía `p_cantidad_esperada` solo cuando hay valor;
  - `IN004` se mapea a `ErrorInventario.stockCambio`, que usa el copy anterior (`kMensajeStockCambio`).
- `InventarioActions.ajustar(..., cantidadEsperada)`: con `stockCambio`, igual que con `stockInsuficiente` y `noDisponible`, invalida la lista, el producto, el historial y el resumen.
- `AjusteSheet`:
  - con el motivo Conteo envía `cantidadEsperada = _p.cantidad`;
  - tras IN004 muestra el copy y relee `productoProvider(id)`. La cabecera pasa a decir "hay N" con la cantidad fresca;
  - lo contado se conserva, así que reaplicar envía el delta correcto sobre la cantidad nueva;
  - `textoErrorAjuste` y `textoErrorEnHoja` muestran el copy de IN004.

### WR-04: deshacer solo ajustes
- En `mover_stock`, la validación de deshacer exige ahora `v_o.origen = 'ajuste'`, además de `motivo <> 'deshacer'` y del inverso exacto. Si no se cumple, lanza `check_violation` con el mensaje existente "Solo se puede deshacer el inverso exacto de un ajuste del mismo producto."
- Esto impide revertir un `alta` hoy, y una salida de `factura` o `dosis` cuando llegue la Fase 7.

### WR-01: `esErrorDeRed`
- Ahora es `e is TimeoutException || e is http.ClientException || runtimeType contiene 'SocketException'`.
- El chequeo por tipo cubre `_ClientSocketException` (una subclase privada de `ClientException`) y sobrevive a `--obfuscate`.
- No importa `dart:io`, así que el target web sigue compilando.
- `http: ^1.6.0` pasa a ser una dependencia directa en `pubspec.yaml`. Es la misma versión 1.6.0 que ya estaba en `pubspec.lock`; en el lock solo cambia `transitive` → `direct main`.
- Los tests usan `http.ClientException` real (con y sin `uri`), una subclase con otro nombre de tipo, `dart:io` `SocketException` real y un tipo cuyo nombre contiene `SocketException`. Se eliminaron las clases falsas que se llamaban igual.

### WR-02: topes del servidor en la hoja
- Se añade `kAjusteMaximo = 100000` en `stock.dart`.
- `_errorValidacion` rechaza:
  - `|delta| > 100.000` con "El ajuste máximo es 100.000.", también en un conteo que mueve más de eso;
  - un resultado mayor que 1.000.000 con "El stock no puede superar 1.000.000.".
- La regla anterior "La cantidad máxima es 1.000.000." para lo que se escribe sigue igual y tiene prioridad, así que el test existente no cambia.

## Esquema a re-aplicar en vivo (no se aplicó nada)

`supabase/schema.sql` en este commit (`9f06800`):
- Mínimo:
  - líneas **4393–4475** (comentario, los dos `drop function if exists` y el `create or replace function public.mover_stock` completo);
  - líneas **4542–4543** (`revoke`/`grant` con la firma de 8 argumentos);
  - línea **4547** (`notify pgrst, 'reload schema';`).
- Alternativa equivalente e idempotente: el bloque Fase 6 completo, líneas **4176–4547**.

Importante: el `drop` de la firma vieja elimina sus grants. Por eso las líneas 4542–4543 tienen que ir en la misma ejecución.

Mientras no se re-aplique:
- compra, uso, vencido y deshacer siguen funcionando, porque no envían `p_cantidad_esperada`;
- el **conteo** falla con un error genérico (PostgREST no encuentra la función con ese parámetro).

## Smoke

- Bloque S: S1..S23.
  - **S21**: conteo con la esperada correcta → 10.
  - **S22**: esperada vieja → `IN004`, sin cambios en la cantidad ni en los movimientos.
  - **S23**: deshacer el `alta` con el inverso exacto → `check_violation`, sin cambios.
- S2 usa la firma nueva `mover_stock(uuid,int,text,text,uuid,text,uuid,int)`.
- **Nuevo total: 261** (258 + 3).
  - 261 `checks := checks + 1`, y una sola cabecera "Total esperado: 261.".
  - El total esperado también se actualizó en `06-VALIDATION.md` (comando de la suite completa, compuerta previa a verify-work y verificación manual) y en `06-09-PLAN.md`.
  - Los registros históricos de 06-01/06-04 (258) no se tocaron, porque documentan lo que pasó.
- Resultado en vivo esperado tras re-aplicar: `RLS SMOKE: PASS (261 checks) - cambios revertidos`. Está pendiente: lo pega el usuario.

## Verificación (líneas literales)

```
flutter analyze -> No issues found! (ran in 9.5s)
flutter test    -> 00:38 +1045: All tests passed!
```

Por archivo: ajuste_sheet 20, supabase_inventario_repository 22, inventario_invalidacion 12, ajuste_rapido 11.

## Commits

- `fade4f1` test(06-10): pruebas en rojo. No compila: no existen `stockCambio` ni `cantidadEsperada`. Además, smoke S21..S23 con la firma nueva.
- `9f06800` fix(06-10): implementación (schema, repo, acciones, hoja).
- docs(06-10): este SUMMARY y VALIDATION.

## Deviations from Plan

1. **[Ajuste de un test del mismo plan] Reaplicar tras IN004** (`9f06800`).
   - El test rojo volvía a escribir "7" sobre un campo que ya decía "7", así que `onChanged` no se disparaba y el aviso seguía visible, lo que ocultaba la vista previa.
   - El test ahora comprueba que se conserva lo contado y que "Aplicar" sigue habilitado, y luego reaplica.
   - Las aserciones de fondo no cambiaron (delta −1, esperada 8, stock 7, snackbar).
2. **Sin tocar la base viva, el MCP de Supabase ni Linear**, como se pidió.
3. **Archivos generados de plugins**: `flutter pub get` reescribió el final de línea de `linux/`, `macos/` y `windows/`. Los restauré archivo por archivo; no forman parte de los commits.

## Known Stubs

Ninguno.

## Self-Check: PASSED

- `fade4f1` y `9f06800` existen en la rama `worktree-agent-a5819e74749386bdd`.
- `supabase/schema.sql` contiene `p_cantidad_esperada int default null`, `errcode = 'IN004'`, `v_o.origen <> 'ajuste'` y el grant de 8 argumentos.
- El smoke tiene 261 `checks := checks + 1`.

## Aplicación en vivo (2026-11-13)

- Autorización del usuario en el chat: "Autorizo".
- Supabase MCP `apply_migration fase_06_10_mover_stock_cantidad_esperada` → `{"success":true}`. Se aplicaron las líneas 4393-4475 (`mover_stock`, con ambos `drop`), 4542-4543 (`revoke` y `grant`) y 4547 (`notify`).
- Consulta de solo lectura: hay una sola firma, `mover_stock(uuid,integer,text,text,uuid,text,uuid,integer)`, con `prosecdef = true`; `anon` no puede ejecutarla y `authenticated` sí.
- `bash supabase/tests/verify_live_schema.sh`: `OK rpc mover_stock protegido 401`, `LIVE_SCHEMA_OK`.
- El usuario pegó el smoke completo en el SQL Editor. Línea literal:

```
RLS SMOKE: PASS (261 checks) - cambios revertidos
```
