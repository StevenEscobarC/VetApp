# 07 QA Report (plan 07-16 Task 2, flujos F1..F12)

- Fase: 07 Facturación (UI: Cobros), plan 07-16 Task 2
- Fecha: 2026-11-16 (reloj del emulador 21:2x-21:3x hora Bogotá = 02:2x-02:3x GMT del día 17; los historiales de inventario muestran 17/11 en GMT, los documentos 16/11)
- Dispositivo: AVD Pixel_9_API_35 (emulator-5554), Android 15
- Build: debug de master (`7d85c01`), `flutter run -d emulator-5554 --dart-define-from-file=dart_define.json`, contra el proyecto Supabase vivo. El emulador se cayó a mitad de la sesión ("Lost connection to device") y se relanzó el AVD y la app; la sesión siguió iniciada.
- Cuenta: admin QA existente de "QA Clinica 51" (plan Beta), sesión ya iniciada. Sin cierre de sesión, sin cuentas nuevas, sin SQL, sin Linear.
- Capturas: `.planning/phases/07-facturaci-n/qa/07-*.png`
- Datos de prueba (todos falsos): cliente "QA Dueno Lote 51" (teléfono 3001234567, cédula 1234567890), mascota "QA Lote 50", servicio "Consulta" $ 50.000, producto "Amoxicilina QA" (frasco, 3 unidades, $ 85.000; el producto de la Fase 6 estaba archivado, se creó uno nuevo), NIT de la clínica 900123456-7 (falso), cita de hoy 9:45 p. m.
- Números reales: CC-0001, CC-0002, CC-0003, CC-0004, CC-0005 y COT-0001 (la clínica no tenía documentos previos).

## Resumen

| Flujo | Fuente | Resultado |
|-------|--------|-----------|
| F1 Cobros en Más, vacío, toggle (D-17, D-20) | 07-16-PLAN Task 2 | PASS |
| F2 Servicios y precios, chips, duplicado (D-06) | 07-16-PLAN Task 2 | PASS |
| F3 CC-0001 con cantidad 2, Otro, precio cambiado (BILL-01, BILL-02) | 07-16-PLAN Task 2 | PASS |
| F4 Producto, tope de stock, descuento e historial (BILL-03, D-12) | 07-16-PLAN Task 2 | PASS |
| F5 Marcar como pagada, Nequi, resumen del mes (BILL-04, D-15) | 07-16-PLAN Task 2 | PASS |
| F6 Cédula/NIT, PDF, hoja de compartir, WhatsApp (D-16, D-22, D-24) | 07-16-PLAN Task 2 | FAIL (el aviso de WhatsApp no instalado queda oculto tras la hoja; el resto PASS) |
| F7 Cotización y conversión (D-09, D-23) | 07-16-PLAN Task 2 | FAIL (enlaces "COT-0000" / "CC-0000" en vez de los números reales; el resto PASS) |
| F8 Anular CC-0002 (D-10, D-13) | 07-16-PLAN Task 2 | PASS |
| F9 Cobrar desde cita, cliente y consulta (D-05) | 07-16-PLAN Task 2 | PASS |
| F10 Modo avión, reintento sin duplicado (D-21) | 07-16-PLAN Task 2 | PASS |
| F11 Colega y solo lectura (D-19) | 07-16-PLAN Task 2 | BLOCKED (parte admin PASS: "Anular" visible; colega y candados sin sesión) |
| F12 Sin la palabra "Factura" (D-01) | 07-16-PLAN Task 2 | PASS (restaurar planes de las clínicas QA: no aplica, ver sección de cambios) |

## F1 PASS

Más muestra `Inventario` y justo debajo `Cobros` (árbol: Inventario [1339..1570], Cobros [1591..1822]). Cobros: `Cobrado este mes, 0 pesos. Por cobrar, 0 pesos, Nada pendiente.`; el selector "Cuentas de cobro" viene activo (naranja) y "Todas" activo; estado vacío `Aún no tienes cuentas de cobro` / `Cobra una consulta, un servicio o un producto y compártelo por WhatsApp. Toca «Nueva cuenta de cobro» para empezar.` En Cotizaciones: `Aún no tienes cotizaciones` / `Envía el precio de una cirugía o tratamiento antes de hacerlo. Toca «Nueva cotización».`
Evidencia: `qa/07-F1-mas.png`, `qa/07-F1-cobros.png`, `qa/07-F7-cotizaciones-vacio.png`.

## F2 PASS

Servicios y precios vacío: `Aún no tienes servicios` y los 4 chips `Consulta`, `Vacunación`, `Desparasitación`, `Cirugía`. Nuevo servicio "Consulta" con precio 50000: lista `Consulta / $ 50.000` y snackbar `«Consulta» guardado.` Duplicado ` consulta ` (con espacios y minúsculas): `Ya tienes un servicio con ese nombre.`
Evidencia: `qa/07-F2-servicios-chips.png`, `qa/07-F2-snack.png`, `qa/07-F2-duplicado.png`.

## F3 PASS

Nueva cuenta de cobro > cliente "QA Dueno Lote 51" > mascota "QA Lote 50" > Consulta dos veces (cantidad 2) > Otro "Bano medicado" (sin tilde por el tecleo) 30.000 > precio de Consulta a 45000: árbol `Precio base $ 50.000`, total `120.000 pesos`. Diálogo `¿Emitir la cuenta de cobro?` / `Total $ 120.000 para QA Dueno Lote 51. Después no se puede editar: si hay un error, la anulas y emites otra.` > Emitir: snackbar `Cuenta de cobro CC-0001 emitida.`; detalle `CC-0001 / Pendiente / Total 120.000 pesos / Emitida el 16/11/2026 por Dr(a). QA Admin Cincuentayuno`; tarjeta de lista `Cuenta de cobro CC-0001, QA Dueno Lote 51, QA Lote 50, 120.000 pesos, Pendiente, 16/11/2026`; resumen `Por cobrar, 120.000 pesos, 1 cuenta pendiente`.
Observación (no es fallo): en el campo de precio, el teclado no cierra al tocar fuera; con el teclado cerrado, Atrás abre el diálogo "¿Descartar este cobro?".
Evidencia: `qa/07-F3-form.png`, `qa/07-F3-form-lineas.png`, `qa/07-F3-precio-base.png`, `qa/07-F3-dialogo.png`, `qa/07-F3-snack.png`, `qa/07-F3-detalle.png`, `qa/07-F3-lista.png`.

## F4 PASS

Agregar producto: `Amoxicilina QA / Quedan 3 frascos · $ 85.000`. Cantidad 4: `Solo quedan 3 frascos de Amoxicilina QA.`; al tocar Emitir no abre el diálogo y la pantalla se desplaza a la línea (Detalle y la línea quedan a la vista). Cantidad 2 > emitir: CC-0002 por 170.000. Inventario `Amoxicilina QA, 1 frasco, mínimo 2, Bajo.`; historial `−2 frascos · Cuenta de cobro CC-0002. Quedaron 1 · ... · QA Admin Cincuentayuno.`
Evidencia: `qa/07-F4-selector.png`, `qa/07-F4-solo-quedan.png`, `qa/07-F4-emitir-bloqueado.png`, `qa/07-F4-cc0002.png`, `qa/07-F4-historial.png`.

## F5 PASS

En CC-0001, `Marcar como pagada`: hoja con los 6 métodos (Efectivo, Nequi, Daviplata, Transferencia, Tarjeta, Otro), ninguno preseleccionado, aviso `Elige cómo pagó.`, `Hoy, 16/11/2026`. Nequi > Confirmar pago: snackbar `CC-0001 marcada como pagada.`; detalle `Pagada el 16/11/2026 · Nequi`; Cobros `Cobrado este mes, 120.000 pesos. Por cobrar, 170.000 pesos, 1 cuenta pendiente.`
Evidencia: `qa/07-F5-hoja.png`, `qa/07-F5-snack.png`, `qa/07-F5-detalle.png`.

## F6 FAIL

Pasos: cédula 1234567890 del cliente (guardada, se muestra `1.234.567.890`; el teléfono quedó normalizado a `573001234567`) y NIT de la clínica 900123456-7 (se muestra `900.123.456-7`, snackbar `Datos de la clínica guardados`). En CC-0001 > Enviar al cliente: hoja `Enviar CC-0001 / Para QA Dueno Lote 51` con `Enviar PDF por WhatsApp`, `Abrir chat de WhatsApp / +57 300 123 4567` y `Compartir PDF`.
- Compartir PDF: hoja del sistema con `Sharing 1 file` y `Cuenta_de_cobro_CC-0001.pdf` (no se envió nada; se cerró con Atrás). Evidencia: `qa/07-F6-share-sheet.png`.
- PDF (copiado del caché de la app con `run-as` y leído con PyMuPDF): encabezado `QA Clinica 51` / `NIT o cédula: 900.123.456-7`; `Cuenta de cobro`, `CC-0001`, `Fecha: 16/11/2026`; `Debe a: QA Clinica 51, NIT o cédula 900.123.456-7`; `La suma de: ciento veinte mil pesos ($ 120.000)`; tabla con Consulta 2 × $ 45.000 = $ 90.000, Bano medicado 1 × $ 30.000, Total $ 120.000; `Estado: Pagada el 16/11/2026 · Nequi`; `Emitida por Dr(a). QA Admin Cincuentayuno`; `Hecho con VetApp`; `Página 1 de 1`. Evidencia: `qa/07-F6-pdf-cc0001.png`.
- Línea "C.C." ausente en el PDF de CC-0001: esperado, porque la cédula se copia al documento al emitirlo (`supabase/schema.sql:5055`) y CC-0001 se emitió antes de registrarla. Los documentos posteriores sí la muestran en el detalle (`C.C. 1.234.567.890` en CC-0003, CC-0004, CC-0005; ver `qa/07-F7-cc0003-detalle.png`). No se regeneró el PDF de un documento posterior.
- Texto del mensaje (leído de `lib/features/billing/domain/whatsapp_cobro.dart:42-49`, usado como pie del PDF y mensaje del chat): para una CC pagada, `Hola, QA Dueno Lote 51. Le compartimos la cuenta de cobro CC-0001 de QA Clinica 51 por $ 120.000, ya pagada. Gracias por su confianza. — <firma>`.
- Abrir chat de WhatsApp: el emulador no tiene WhatsApp; logcat muestra `START u0 {act=android.intent.action.VIEW dat=https://wa.me/...} ... result code=-91` (sin actividad). La app llama al aviso, pero el snackbar `No pudimos abrir WhatsApp. Usa «Compartir PDF».` queda DETRÁS de la hoja modal, que sigue abierta: 3 capturas/dumps seguidos tras el toque no lo muestran (`qa/07-F6-whatsapp-fallback.png`, `...fallback2.png`, `...fallback3.png`); solo aparece al cerrar la hoja con Atrás en menos de 4 s (`qa/07-F6-fallback-tras-cerrar.png`, árbol `No pudimos abrir WhatsApp. Usa «Compartir PDF».`). Para el usuario el toque no produce ninguna respuesta visible.
- Causa probable: `lib/features/billing/presentation/widgets/enviar_cobro_sheet.dart:46-50` (`_aviso` usa el `ScaffoldMessenger` del Scaffold de debajo; el snackbar queda tapado por el `showModalBottomSheet` de `enviar_cobro_sheet.dart:24`), invocado desde `enviar_cobro_sheet.dart:116-120`. Opciones: cerrar la hoja antes de avisar, o mostrar el aviso dentro de la hoja.
- Parte de "enviar el PDF por WhatsApp" con la app real: REQUIERE-DISPOSITIVO (teléfono con WhatsApp); no probada.

## F7 FAIL

- Nueva cotización con Amoxicilina QA × 5 (stock 1 en ese momento; aviso `Solo queda 1 frasco...` pero no bloquea): snackbar `Cotización COT-0001 guardada.`; detalle `COT-0001 / Total 425.000 pesos / Creada el 16/11/2026 por Dr(a). QA Admin Cincuentayuno / Válida por 15 días, hasta el 01/12/2026`; acciones Convertir en cuenta de cobro, Enviar al cliente, Editar cotización, Anular cotización.
- Convertir en cuenta de cobro: formulario `Convertir COT-0001` con aviso `Desde la cotización COT-0001. Revisa los precios y cantidades antes de emitir.`; cantidad bajada a 1 (con `Solo queda 1 frasco de Amoxicilina QA.` mientras estaba en 5) > Emitir: CC-0003 por 85.000. Stock 0 (`Amoxicilina QA, 0 frascos, mínimo 2, Agotado.`; historial `−1 frasco · Cuenta de cobro CC-0003. Quedaron 0`). La cotización queda `Convertida` en la lista.
- FALLO: el detalle de CC-0003 dice `Viene de la cotización COT-0000` y el de la cotización dice `Convertida en CC-0000`. Se esperaba `COT-0001` y `CC-0003`. El enlace sí navega al documento correcto, solo el número es 0.
- Causa probable: `lib/features/billing/presentation/screens/cobro_detail_screen.dart:418-419` y `:425-426` usan `cotizacionOrigenNumero ?? 0` / `convertidaEnNumero ?? 0`; el valor llega nulo desde `lib/features/billing/data/repositories/supabase_cobros_repository.dart:398-399` (`_numeroEmbed` solo acepta `Map`) y `:432-438`, alimentado por los embeds `convertida:cobros!convertida_en_id(numero)` / `origen:cobros!cotizacion_origen_id(numero)` de `:53-54`. Hipótesis: PostgREST devuelve esos embeds como lista (FK recíprocas), no como mapa; hay que confirmarlo con `/gsd-debug`.
- Evidencia: `qa/07-F7-form-cotizacion.png`, `qa/07-F7-guardada.png`, `qa/07-F7-convertir.png`, `qa/07-F7-cc0003.png`, `qa/07-F7-cc0003-detalle.png`, `qa/07-F7-cot-convertida-0000.png`, `qa/07-F7-stock-0.png`.

## F8 PASS

Anular CC-0002: hoja `Anular CC-0002` (`Queda anulada con su número y no se puede deshacer.` / `Los productos vuelven al inventario.` / `Si hace falta, emite una nueva.`), motivo `Error de prueba`; snackbar `CC-0002 anulada. Los productos volvieron al inventario.`; detalle `CC-0002 / Anulada ... Motivo: Error de prueba`. Inventario: `Amoxicilina QA, 2 frascos` e historial `+2 frascos · Anulada CC-0002. Quedaron 2`. Lista: `Cuenta de cobro CC-0002, ..., 170.000 pesos, Anulada`; "Por cobrar" excluye la anulada (85.000 con solo CC-0003 pendiente). `Emitir una nueva` abre el formulario `Nueva cuenta de cobro` con cliente y 170.000 precargados; se descartó con el diálogo (no se creó nada).
Evidencia: `qa/07-F8-snack.png`, `qa/07-F8-anulada.png`, `qa/07-F8-nueva-borrador.png`, `qa/07-F8-lista-anulada.png`.

## F9 PASS

- Cita de hoy 9:45 p. m. de "QA Lote 50" > Completar: hoja con `Finalizar cita` y `Finalizar y cobrar` (ambos deshabilitados hasta resolver la consulta; se pulsó "Omitir"). `Finalizar y cobrar` abrió el formulario con cliente y mascota precargados; se agregó Consulta y se emitió CC-0004 (`De la cita del 16/11/2026`). El detalle de la cita muestra el botón `Cobrada: CC-0004, Pendiente. Abrir detalle.`
- Detalle de cliente: `Nueva cuenta de cobro` abre el formulario con `QA Dueno Lote 51`.
- Guardar una consulta (cita completada > Registrar consulta pendiente): snackbar `Consulta guardada` con acción `Cobrar`.
- Observación: con uiautomator/accesibilidad activa los snackbars con acción (`Cita completada / Deshacer`, `Consulta guardada / Cobrar`) no se cierran solos y tapan el botón Emitir de la pantalla siguiente hasta que se deslizan. Es el comportamiento estándar de Flutter con accesibilidad activa, no se reporta como fallo.
- Evidencia: `qa/07-F9-completar.png`, `qa/07-F9-form-prellenado.png`, `qa/07-F9-cc-emitida.png`, `qa/07-F9-cita-cobrada2.png`, `qa/07-F9-cliente-nueva-cc.png`, `qa/07-F9-consulta-cobrar.png`.

## F10 PASS

- Antes: último documento CC-0004. Modo avión activado con `cmd connectivity airplane-mode enable` (`airplane_mode_on=1`, icono de avión en la barra). Emitir: error `Sin conexión, el cobro no se creó. / Tus datos siguen aquí. Inténtalo de nuevo cuando tengas señal.`; el formulario conserva la línea Consulta, 50.000 pesos.
- Modo avión desactivado con `cmd connectivity airplane-mode disable`; `airplane_mode_on=0` confirmado. Emitir de nuevo: CC-0005. Lista: CC-0005, CC-0004, CC-0003, CC-0002 (anulada), CC-0001; "Por cobrar 185.000 pesos, 3 cuentas pendientes" (85.000 + 50.000 + 50.000). Un solo incremento (CC-0004 → CC-0005), sin duplicado ni CC-0006.
- Evidencia: `qa/07-F10-sin-conexion.png`, `qa/07-F10-reintento.png`, `qa/07-F10-lista.png`.

## F11 BLOCKED (parte admin PASS)

- Admin: `Anular cuenta de cobro` aparece en CC-0001..CC-0005 emitidas por el admin (árbol del detalle, p. ej. CC-0001 `Anular cuenta de cobro [42,2132][1038,2258]`, `qa/07-F3-detalle.png`). PASS.
- BLOCKED: una CC emitida por otra persona no muestra "Anular" (no hay sesión de colega ni contraseñas).
- BLOCKED: candados de solo lectura en FAB, Marcar como pagada y Cobrar, `LimitePlanSheet` por LP004 del servidor, y `Enviar al cliente` en solo lectura (requieren una clínica pasada de cuota por el orquestador; el solo lectura nunca afecta al admin).
- Pendiente para el humano / orquestador con sesión de colega y clínica en solo lectura.

## F12 PASS

Volcados de uiautomator (59 KB en total) de: lista de Cobros, detalle de CC, hoja Enviar, hoja Marcar como pagada, hoja Anular, Servicios, lista de Cotizaciones y formulario de nueva cotización, más todos los árboles de F1..F10: ninguna aparición de `Factura`/`factura`. El PDF tampoco la contiene (texto completo en F6). La comprobación de "plan de las clínicas QA restaurado y clínica del usuario sin cambios" no se ejecutó: no se cambió ningún plan ni se usó SQL en esta sesión (el plan de "QA Clinica 51" sigue en Beta, visible en Más > `Mi plan, Beta`).

## Fallos y causa probable

| Flujo | Fallo | Causa probable |
|-------|-------|----------------|
| F6 | Aviso "No pudimos abrir WhatsApp" oculto tras la hoja modal | `lib/features/billing/presentation/widgets/enviar_cobro_sheet.dart:46-50`, `:116-120` |
| F7 | "COT-0000" / "CC-0000" en los enlaces de conversión | `lib/features/billing/presentation/screens/cobro_detail_screen.dart:418-426`, `lib/features/billing/data/repositories/supabase_cobros_repository.dart:53-54`, `:398-399`, `:432-438` |

Recomendación: `/gsd-plan-phase 7 --gaps` con ambos fallos (o `/gsd-debug` para cada uno; ambos son puntuales).

## Cambios al dispositivo

- `pm clear`: no se hizo.
- Zona horaria: sin cambios.
- Permisos: sin cambios.
- Modo avión: activado y desactivado en F10; restaurado (`airplane_mode_on=0`).
- El emulador se reinició por caída y la app se reinstaló con `flutter run` (la sesión se conservó).
- Datos en la clínica QA (Supabase vivo, falsos, no se borra nada; los documentos son de solo agregar): servicio "Consulta", producto "Amoxicilina QA" (stock final 2 frascos, histórico en F4/F7/F8), cliente "QA Dueno Lote 51" con teléfono y cédula, NIT de la clínica, cita completada con consulta "Control QA", documentos COT-0001 (convertida), CC-0001 (pagada), CC-0002 (anulada), CC-0003, CC-0004, CC-0005 (pendientes).

QA: FAIL — F6 (aviso de WhatsApp oculto tras la hoja) y F7 (COT-0000/CC-0000 en enlaces de conversión); F11 (sesión del colega) pendiente
