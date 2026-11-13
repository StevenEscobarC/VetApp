# 06 QA Report (plan 06-09 Task 2, flujos F1..F9)

- Fase: 06 Inventario, plan 06-09 Task 2
- Fecha: 2026-11-13 (reloj del emulador 15:2x GMT = 10:2x Bogotá; los historiales muestran 3:2x p. m. en GMT)
- Dispositivo: AVD Pixel_9_API_35 (emulator-5554), Android 15
- Build: debug de master (`da2a64d`), `flutter run -d emulator-5554 --dart-define-from-file=dart_define.json`, contra el proyecto Supabase vivo
- Cuenta: admin QA existente de "QA Clinica 51" (plan Beta). La sesión ya estaba iniciada en el emulador; no hizo falta introducir contraseña (el archivo `qa-pass.txt` indicado no existía en el scratchpad).
- Capturas: `.planning/phases/06-inventario/qa/06-*.png`
- Datos de prueba creados: "Amoxicilina QA" (archivada al final) e "Ivermectina QA" (queda activa en la clínica QA, 20 frascos, vence 03/12/2026, $ 85.000).

## Resumen

| Flujo | Fuente | Resultado |
|-------|--------|-----------|
| F1 Alta de producto, estado vacío (INV-01) | 06-09-PLAN Task 2 | PASS |
| F2 Más detalles, precio, vencimiento, nombre duplicado (INV-01) | 06-09-PLAN Task 2 | PASS |
| F3 Ajustes −1 / + / Deshacer / confirmación grande (INV-03) | 06-09-PLAN Task 2 | PASS |
| F4 Stock bajo: badge, tarjeta Inicio, pastilla Más, borde (INV-02) | 06-09-PLAN Task 2 | PASS |
| F5 Pedir por WhatsApp, hoja de compartir (INV-02) | 06-09-PLAN Task 2 | PASS (sin enviar; envío real queda para teléfono físico) |
| F6 Historial, doble toque, −1 en 0, Uso bloqueado (INV-03) | 06-09-PLAN Task 2 | PASS |
| F7 Colega y solo lectura (D-13/D-14) | 06-09-PLAN Task 2 | BLOCKED (la app sigue con puede_escribir=true; sin candados ni LimitePlanSheet; ver sección F7) |
| F8 Modo avión (D-12) | 06-09-PLAN Task 2 | FAIL (copy distinto al esperado; la cantidad no cambió) |
| F9 Archivar "Amoxicilina QA" | 06-09-PLAN Task 2 | PASS (parte de archivar) |
| F9 restaurar planes y verificar clínica del usuario | 06-09-PLAN Task 2 | PENDIENTE (autorización del usuario para SQL de soporte) |

## F1 PASS

Pasos: Más > Inventario. Estado vacío: "Aún no tienes productos / Registra tus medicamentos e insumos para saber cuándo reabastecer. Toca «Nuevo producto» para empezar." Nuevo producto > nombre "Amoxicilina QA", Unidad preseleccionada (botón naranja), cantidad 10, mínimo 2 (valor por defecto) > Guardar producto.
- Observado: lista con árbol `Amoxicilina QA, 10 unidades, mínimo 2.` y snackbar `«Amoxicilina QA» agregado al inventario.`
- Evidencia: `qa/06-F1-vacio.png`, `qa/06-F1-form.png`, `qa/06-F1-form-abajo.png`, `qa/06-F1-guardado.png`.

## F2 PASS

- Nuevo producto "Ivermectina QA", Frasco, cantidad 20, Agregar más detalles: categoría Insumo, vencimiento `03/12/2026` (hoy + 20 días), precio 85000. El campo de precio muestra `$ 85.000` al perder foco.
- Lista: `Ivermectina QA, 20 frascos, mínimo 2, Vence pronto, vence 03/12/2026.`; filtro "Vence pronto (1)".
- Detalle: `Vence pronto`, `Vencimiento 03/12/2026 · en 20 días`, `Precio de venta $ 85.000`, historial `+20 frascos · Alta inicial. Quedaron 20 ... QA Admin Cincuentayuno`.
- Duplicado: segundo producto "amoxicilina qa" (minúsculas) bloquea el guardado con `Ya tienes un producto con ese nombre.` (también detecta sin distinguir mayúsculas).
- Observaciones sin fallo: dejar "Cantidad inicial" vacío da `Escribe la cantidad (puede ser 0).`; el campo de vencimiento no tiene máscara (hay que teclear las barras); al tener el teclado abierto el primer toque en "Guardar producto" solo lo cierra.
- Evidencia: `qa/06-F2-detalles.png`, `qa/06-F2-lleno-ok.png`, `qa/06-F2-lista.png`, `qa/06-F2-detalle.png`, `qa/06-F2-duplicado.png`.

## F3 PASS

- Fila −1: `Descontaste 1 unidad de Amoxicilina QA. Ahora hay 9.` con acción Deshacer. Deshacer: `Ajuste deshecho. Ahora hay 10.`
- "+" Compra 5: `Agregaste 5 unidades a Amoxicilina QA. Ahora hay 15.` con Deshacer.
- "+" Compra 15: diálogo `¿Confirmas este ajuste? / Vas a sumar 15 unidades a Amoxicilina QA. Quedarán 30.` (botones Revisar / Confirmar ajuste). Tras confirmar: `Ajuste aplicado a Amoxicilina QA. Ahora hay 30.` sin Deshacer.
- Detalle > Ajustar cantidad > Conteo 1: diálogo `Vas a restar 29 unidades de Amoxicilina QA. Quedarán 1.`; confirmado: `Ajuste aplicado a Amoxicilina QA. Ahora hay 1.`
- Evidencia: `qa/06-F3-menos1.png`, `qa/06-F3-hoja-mas.png`, `qa/06-F3-confirma.png`, `qa/06-F3-30.png`, `qa/06-F3-conteo-confirma.png`, `qa/06-F3-detalle-1.png`.

## F4 PASS

- Con cantidad 1 < mínimo 2: badge `Bajo` en el detalle y en la fila (`Amoxicilina QA, 1 unidad, mínimo 2, Bajo.`). Más: `Inventario, 1 bajo`. Inicio: tarjeta `1 producto con stock bajo. Ver inventario.`; al tocarla abre la lista en "Bajos (1)".
- Conteo a exactamente 2 (borde): sin badge, la lista Bajos muestra `Nada por reabastecer / Todos tus productos están en el mínimo o por encima.`, Inicio sin tarjeta, Más sin pastilla (`Inventario` a secas).
- Evidencia: `qa/06-F4-lista-bajo.png`, `qa/06-F4-mas-pill.png`, `qa/06-F4-inicio-card.png`, `qa/06-F4-bajos.png`, `qa/06-F4-conteo-2.png`, `qa/06-F4-detalle-2.png`, `qa/06-F4-lista-2.png`, `qa/06-F4-inicio-sin-card.png`, `qa/06-F4-mas-sin-pill.png`.

## F5 PASS

En Bajos (1): botón `Pedir por WhatsApp` y nota `Pedimos lo necesario para llegar al doble del mínimo.` Abre la hoja de compartir del sistema ("Sharing text") con el texto exacto, sin enviarlo a nadie (se cerró con Atrás):

```
Pedido de QA Clinica 51:
- Amoxicilina QA: pedir 3 unidades (quedan 1)
```

(3 = doble del mínimo 4 − 1 actual; coherente con la nota.) Envío por WhatsApp real queda para teléfono físico.
- Evidencia: `qa/06-F5-compartir.png`.

## F6 PASS

- Historial del detalle (árbol, de más reciente a más antiguo), todos con autor `QA Admin Cincuentayuno`: `Alta inicial`, `Uso`, `Ajuste deshecho`, `Compra`, `Compra`, `Conteo`, `Conteo`, `Uso`, `Uso`.
- Doble toque rápido en −1 con cantidad 1 (dos `input tap` seguidos en una sola llamada adb): el stock pasa a 0 y el historial añade exactamente un movimiento (`−1 unidad · Uso. Quedaron 0 · 3:28 p. m.`), no dos. Snackbar `Descontaste 1 unidad de Amoxicilina QA. Ahora hay 0.`
- Con stock 0: el −1 queda deshabilitado (`content-desc="Descontar 1, no hay stock"`, `enabled="false"`), badge `Agotado`.
- Con stock 0, "+" > Uso > 1: aparece `No puedes dejar el stock por debajo de 0.` y `Aplicar ajuste` queda deshabilitado.
- Evidencia: `qa/06-F6-doble-tap.png`, `qa/06-F6-historial.png`, `qa/06-F6-uso-bloqueado.png`.

## F7 BLOCKED (precondicion de solo lectura no efectiva en la app)

Pasos: app a segundo plano y de vuelta (monkey LAUNCHER), pestañas Inicio y Más, Más > Mi plan (que relee el plan), Más > Inventario.
- Esperado: candados en FAB "Nuevo producto", −1 y +, y "Editar producto"; LimitePlanSheet al tocar.
- Observado: Mi plan muestra `Plan Gratis`, `Activo`, "Tu prueba terminó el 28/10/2026", `50 de 50 pacientes`, `2 de 1 veterinarios`; NO muestra estado de solo lectura. En Inventario el FAB muestra el icono "+" y −1/+ sin candado. Al tocar −1 la escritura SE EJECUTO (20 -> 19, snackbar `Descontaste 1 frasco de Ivermectina QA. Ahora hay 19.`), es decir el servidor devolvio puede_escribir=true y no rechazo con LP004. Se pulso `Deshacer`: stock de vuelta a 20 (queda un movimiento extra de ajuste en el historial de Ivermectina QA).
- Conclusion: no se pudo probar candados, LimitePlanSheet (cliente ni LP004), ni lista/detalle/WhatsApp bajo solo lectura. Hipotesis: el SQL de soporte no dejo la clinica en solo lectura (o el plan vencido degrada a Gratis con puede_escribir=true; `plan_providers.dart:46-47` depende de `puede_escribir` del RPC `miPlan`, `mi_plan.dart:85`). El orquestador debe verificar con SELECT la fila de plan/RPC mi_plan de "QA Clinica 51" y reintentar F7. No se pudo comprobar por SQL (prohibido para QA).
- Desviacion: las comprobaciones propias del colega (minimo y precios de solo lectura con el helper de admin, sin "Archivar producto") no se corrieron en el emulador porque no hay contrasena de la cuenta colega. Las cubren los tests de widget de `producto_form_screen`.
- Evidencia: `qa/06-F7-mas-plan.png`, `qa/06-F7-mi-plan.png`, `qa/06-F7-inventario.png`, `qa/06-F7-tap-menos1.png`, `qa/06-F7-deshecho-20.png`.

## F8 FAIL

Pasos: lista Todos, modo avión activado (`cmd connectivity airplane-mode enable`, `airplane_mode_on=1`, icono de avión en la barra de estado), −1 sobre "Ivermectina QA" (20).

- Esperado: `Sin conexión. El ajuste no se guardó. Inténtalo de nuevo cuando tengas señal.`
- Observado: snackbar `No pudimos completar la operación. Intenta de nuevo.` (mensaje genérico). La cantidad permaneció en 20 y, tras desactivar el modo avión, refrescar y reabrir la lista, sigue en 20 (sin movimiento registrado).
- Evidencia: `qa/06-F8-sin-conexion.png`, `qa/06-F8-tras-reconectar.png`.
- Causa probable: `lib/features/inventory/data/repositories/supabase_inventario_repository.dart:312-316` (`esErrorDeRed`) compara `runtimeType.toString()` con `'SocketException'` o `'ClientException'`. Con `package:http` (1.2.2 en caché; `io_client.dart:30`) el error de red llega como `_ClientSocketException` (clase privada que extiende `ClientException`), cuyo nombre no coincide, así que `_run` (línea 40-45) cae al mensaje genérico. Los tests unitarios (`test/supabase_inventario_repository_test.dart:76-80`) usan `ClientException()` público y por eso no lo detectan. No verificado con un log del tipo real de excepción (la app no lo imprime). Corrección sugerida: usar `e is ClientException` / `e is SocketException` (con import condicional) o comparar con `contains('SocketException')`.
- Siguiente paso: `/gsd-debug` (bug puntual) o `/gsd-plan-phase 6 --gaps`.

## F9 PASS (solo archivar)

Detalle de "Amoxicilina QA" (stock 0) > Archivar producto: diálogo `Archivar producto / «Amoxicilina QA» dejará de aparecer en tu inventario y no podrás ajustar su stock. El historial de movimientos se conserva. Esta acción no se puede deshacer desde la app.` (Cancelar / Archivar). Tras Archivar vuelve a la lista: ya no está "Amoxicilina QA", snackbar `«Amoxicilina QA» archivado.`
- Evidencia: `qa/06-F9-confirma.png`, `qa/06-F9-archivado.png`.
- PENDIENTE (autorización del usuario para SQL de soporte): restaurar planes de las clínicas QA a su fila registrada y verificar con consulta de solo lectura que la clínica del usuario no cambió. En esta ejecución no se tocó ningún plan, así que no hay filas antes/después que restaurar.

## Cambios al dispositivo

- Modo avión: activado en F8 y desactivado de inmediato (`airplane_mode_on=0` confirmado). Restaurado.
- Sin `pm clear`, sin cambios de zona horaria ni de permisos. La sesión QA existente se reutilizó.
- App instalada y ejecutada con `flutter run` (proceso en segundo plano, log en el scratchpad); sigue en ejecución en el emulador.
- F7: el −1 de prueba (20->19) se deshizo con Deshacer; stock final 20.
- Datos en el proyecto vivo: "Amoxicilina QA" archivada, "Ivermectina QA" activa en "QA Clinica 51".

## Nota del orquestador sobre F7 (2026-11-13)

- **Causa del BLOCKED:** `puede_escribir()` (`supabase/schema.sql:3464`) deja en solo lectura solo al miembro cuya posición supera los cupos. El orden es admin primero y luego antigüedad. Con plan vencido (`miembros_max = 1`), el admin conserva la escritura y el bloqueado es el colega. Esto es lo diseñado en D-02/D-12, no un bug. F7 debe correrse con la sesión del colega, y no hay contraseña disponible de la cuenta colega `qa.vet51.colega@example.com`. No se restablecieron credenciales.
- **Cobertura del servidor:** el bloque S del smoke (R44: `guard_solo_lectura` en 9 tablas, incluidas `productos` y `movimientos_inventario`) pasó en vivo (`RLS SMOKE: PASS (258 checks)`). Los candados y `LimitePlanSheet` del cliente los cubren los tests de widget de inventario.
- **SQL de soporte (autorizado por el usuario: "Autorizo")** sobre `clinica_planes` de QA Clinica 51:
  - **Fila antes:** `beta`, `miembros_max = 5`, `pagado_hasta = null`, `prueba_pro_hasta = 2026-10-29`, `prueba_clinica_hasta = 2026-10-14`, `prueba_clinica_usada = true`.
  - **Cambio a vencido:** `gratis`, `miembros_max = 1`.
  - **Restauración:** la fila volvió exactamente a la de antes, confirmado con `returning`.
  - Solo se tocó esa fila (`where clinica_id = <QA Clinica 51>`). La clínica del usuario no se tocó.
- **Datos:** el −1 y el Deshacer de esta prueba dejaron dos movimientos extra en el historial de "Ivermectina QA" (stock final 20).

QA: FAIL — F7 bloqueado (la clínica no quedó en solo lectura: −1 escribió sin candado ni LP004) y F8 pendiente del arreglo de WR-01
