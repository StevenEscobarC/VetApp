# Fase 05 - Informe QA (Vacunacion y Desparasitacion + logo de clinica) - Plan 05-13 Task 2

- Fecha: 2026-10-02 (reloj del emulador GMT; la app muestra hora de Bogota)
- Dispositivo: AVD Pixel_9_API_35 (emulator-5554)
- Build: build/app/outputs/flutter-apk/app-debug.apk (`adb install -r`, sin `pm clear`; dart_define.json no se imprime)
- Proyecto: Supabase vivo
- Cuenta: `qa.vet41.admin@example.com` (QA Admin Cuarenta, clinica "QA Clinica 41"), sesion ya iniciada. Credenciales no copiadas aqui.
- Datos de prueba: mascota "QA Firulais" (renombrada desde "Firulais"), dueno "Cliente QA41" (telefono +57 300 987 6543, ficticio), clinica "QA Clinica 41". No se crearon cuentas.
- Capturas: `.planning/phases/05-vacunaci-n-y-desparasitaci-n/qa/` (prefijo `05-`)
- Pagina publica: es la version previa a los ultimos fixes de marca (sin push). Las diferencias visuales se anotan como "pendiente de push", no como FAIL.
- Tokens: no se registran tokens completos. Enlace vigente de la mascota termina en `...bb47`; el enlace reemplazado terminaba en `...098a`.

## Resumen

| Flujo | Fuente | Resultado |
|-------|--------|-----------|
| F1 Carne vacio > Registrar dosis > Polivalente hoy -> Proxima +21 -> snackbar (VAC-01/02) | 05-13 T2 | PASS (gap menor G1: texto de contexto) |
| F2 Antirrabica chip 3 anos -> proxima +3 anos | 05-13 T2 | PASS con observacion G2 (3 anos = 1095 dias, cae 1 dia antes) |
| F3 "Otro..." Giardia 6 meses + Guardar en mi catalogo -> Protocolos "Personalizado" (D-04) | 05-13 T2 | PASS (G2: 6 meses = 180 dias) |
| F4 Dosis historica externa -> etiqueta "Otra clinica" (D-07) | 05-13 T2 | PASS |
| F5 Anular dosis "Error de registro" -> tachada en Historial, carne recalculado (D-08) | 05-13 T2 | PASS (observacion G3) |
| F6 Dosis vencida -> Inicio, lista Pacientes "Vencida", Vacunas pendientes (D-10/D-11) | 05-13 T2 | FAIL parcial (G4: tarjeta de Inicio no se actualiza) |
| F7 Pendientes: Agendar / Descartar-Posponer-Deshacer / Recordar | 05-13 T2 | FAIL (G5: "Agendar" provoca pantalla roja). Posponer, Deshacer y Recordar PASS |
| F8 Cita Vacunacion -> Completar -> "Registrar dosis aplicada" -> "Dosis registrada: {Biologico}" (D-05b/D-22) | 05-13 T2 | PASS |
| F9 "Vacunar" en Inicio -> buscar -> registrar (D-05c) | 05-13 T2 | PASS |
| F10 Protocolos: Polivalente 28 dias -> preview +28; "Restablecer valores estandar" -> 21 | 05-13 T2 | PASS |
| F11 Compartir carne: enlace, Copiar, Descargar PDF, dialogo Regenerar | 05-13 T2 | PASS |
| F12 Enlace en Chrome sin login; tras regenerar el viejo es invalido | 05-13 T2 | PASS (estilo visual: pendiente de push) |
| F13 Logo de clinica (D-26/D-27) | 05-13 T2 | FAIL (G6: el logo no se puede establecer) + subpasos BLOCKED |

## Detalle por flujo

### F1 - PASS
- Pasos: Pacientes > QA Firulais > tarjeta "Carne de vacunacion" > estado vacio > "Registrar dosis" > Biologico > Polivalente > Guardar dosis.
- Esperado: estado vacio; preview "Proxima" = hoy+21 con "Dosis 2 de 3"; snackbar "Dosis registrada. Proxima: ...".
- Observado: estado vacio "Sin vacunas registradas / Registra la primera dosis de Firulais ..."; preview `Proxima: 23/10/2026` (02/10 + 21), contexto `Dosis 1 de 3 · Dosis 2 de 3`; snackbar `Dosis registrada. Proxima: 23/10/2026`; carne con `Polivalente, Dosis 1 de 3, al dia, ... proxima el 23/10/2026`.
- Evidencia: `qa/05-F1-carne-vacio.png`, `qa/05-F1-preview.png`, `qa/05-F1-snackbar.png`.
- Gap G1 (menor, copy): UI-SPEC pide la linea de contexto "Dosis 2 de 3 · en 21 dias"; la app muestra "Dosis 1 de 3 · Dosis 2 de 3" (concatena etiquetaDosis de la dosis aplicada + etiquetaProxima, sin "en N dias"). Causa probable: `lib/features/vaccination/presentation/widgets/proxima_preview.dart:60-63`.
- Observacion: el estado vacio muestra "Firulais" (nombre anterior) tras renombrar a "QA Firulais"; en el formulario ya sale "QA Firulais" (`carne_screen.dart:220`, dato cacheado del carne; menor).

### F2 - PASS (observacion G2)
- Pasos: Registrar dosis > Antirrabica > chip "Duracion 3 anos" > Guardar.
- Observado: chips "1 ano" (preseleccionado, proxima 02/10/2027) y "3 anos"; con 3 anos snackbar `Proxima: 01/10/2029`.
- Esperado: +3 anos (02/10/2029). Observado 01/10/2029: el servidor usa intervalos en dias (3 anos = 1095 dias; 2028 es bisiesto). Mismo patron: "6 meses" = 180 dias (31/03/2027 en F3), "1 mes" = 30 dias (14/09 desde 15/08 en F6). Para recordatorios a escala de anos es un desfase de 1-2 dias; decision de producto (G2, menor).
- Evidencia: `qa/05-F2-3anios.png`.

### F3 - PASS
- Pasos: Registrar dosis > Otro... > nombre "Giardia" > intervalo "6 meses" > activar "Guardar en mi catalogo" > Guardar. Luego Mas > Protocolos.
- Observado: dosis "Giardia ... proxima el 31/03/2027"; Protocolos lista `Giardia / 1 dosis · refuerzo cada 6 meses / Personalizado`.
- Evidencia: `qa/05-F3-otro.png`, `qa/05-F10-protocolos.png`.
- Nota de interaccion: el interruptor "Guardar en mi catalogo" arranco sin marcar y hay que tocar el switch (derecha de la fila).

### F4 - PASS
- Pasos: Bordetella, fecha 15/09/2026 ("Fecha pasada: se registrara como dosis historica."), "Aplicada en otra clinica", nombre `QA Clinica Externa`.
- Observado: carne `Primera dosis / Al dia / Otra clinica / Aplicada: 15/09/2026 / Proxima: 15/09/2027 / Aplicada en QA Clinica Externa`.
- Evidencia: `qa/05-F4-externa.png`, `qa/05-F5-historial.png` (tarjeta Bordetella).

### F5 - PASS (observacion G3)
- Pasos: Anular Giardia (unica dosis) con "Error de registro"; despues registrar Polivalente dosis 2, anularla.
- Observado: sheet "Anular dosis / Giardia · 02/10/2026 / Motivo: Error de registro, Dosis duplicada, Otro motivo / La dosis quedara tachada y no contara para la proxima fecha. No se puede deshacer."; snackbar `Dosis anulada. Registra la correcta.`; el carne de Polivalente vuelve a `Dosis 1 de 3 ... proxima 23/10/2026` y `Historial (1)`; al expandir: `Anulada / Aplicada: 02/10/2026 / Anulada: Error de registro / 02/10/2026`.
- Evidencia: `qa/05-F5-anular-sheet.png`, `qa/05-F5-anulada.png`, `qa/05-F5-historial.png`.
- Observacion G3 (menor): cuando la unica dosis de un biologico se anula (Giardia), el biologico desaparece del carne y la dosis anulada no queda visible en ningun Historial (el contador "dosis" baja). La anulacion solo es visible cuando hay otra dosis vigente del mismo biologico. Causa probable: la lista `biologicos` del servidor omite biologicos sin dosis vigente (`carne.dart:194-197`, `carne_screen.dart:268`). Decidir si es intencional.

### F6 - FAIL parcial
- Pasos: Desparasitacion externa, fecha 15/08/2026 (1 mes -> vence 14/09/2026). Revisar carne, Pacientes, Inicio, Vacunas pendientes.
- Observado OK: carne `Vencida / 1 pendientes`, tarjeta `Primera dosis / Vencida / Vencio hace 18 dias`; lista Pacientes `QA Firulais ... Vencida`; Vacunas pendientes `Vencidas (1) ... Desparasitacion externa · Refuerzo / Vencio el 14/09/2026 · hace 18 dias`; tras reiniciar la app Inicio muestra `Vacunas pendientes / Vencida / 1 vencidas`.
- Gap G4 (mayor): la tarjeta "Vacunas pendientes" de Inicio NO se actualiza tras registrar (ni anular) una dosis: siguio mostrando "Todo al dia" aunque Pacientes ya decia Vencida y la pantalla de pendientes (abierta desde esa misma tarjeta) listaba la alerta. Solo se corrigio al cerrar y reabrir la app. Esperado: 1 vencida al volver a Inicio. Causa probable: `registrar_dosis_providers.dart:67-68` y `anular_dosis_providers.dart:21-22` invalidan `carneProvider` y `resumenVacunasMascotasProvider` pero no `resumenVacunasProvider` ni `vacunasPendientesProvider` (que si se invalidan en `alertas_providers.dart:37-38` y `pendiente_tile.dart:82-83`).
- Evidencia: `qa/05-F6-carne.png`, `qa/05-F6-inicio-stale.png` (Todo al dia, desactualizado), `qa/05-F6-pendientes.png`, `qa/05-F6-inicio.png` (tras reiniciar).

### F7 - FAIL (Agendar)
- "Descartar o posponer": sheet "¿Que hacemos con esta alerta?" con Posponer 7 dias / 30 dias / Mascota fallecida / Cambio de veterinario / Otro motivo / Volver / Aplicar. "Posponer 7 dias" -> lista `Todo al dia` + snackbar `Alerta pospuesta hasta el 09/10/2026`; "Deshacer" -> la tarjeta vuelve. PASS.
- "Recordar": WhatsApp no esta instalado en el emulador; snackbar `No pudimos abrir WhatsApp.` y la tarjeta no muestra "Recordatorio enviado". PASS.
- "Agendar": FAIL. Al pulsarlo (desde Vacunas pendientes abierta desde la tarjeta de Inicio) la app muestra pantalla roja de error: `'package:flutter/src/widgets/navigator.dart': Failed assertion: line 4049 pos 18: '!keyReservation.contains(key)': is not true.` Reproducido 2 veces (relanzando la app). Esperado: abrir Nueva cita con cliente, mascota y motivo prefijados (Desparasitacion). Causa probable: `pendiente_tile.dart:66-74` hace `context.push('/agenda/nueva?...')` desde una ruta raiz (`vacunacionRoutes`, `app_router.dart:~88`) hacia una subruta de la rama Agenda del `StatefulShellRoute` (`app_router.dart:~91-102`, `agenda_routes.dart:33`), lo que duplica la pagina del shell en el Navigator raiz. Recomendado `/gsd-debug`.
- Evidencia: `qa/05-F7-descartar-sheet.png`, `qa/05-F7-pospuesto.png`, `qa/05-F7-recordar.png`, `qa/05-F7-agendar-crash.png`.

### F8 - PASS
- Pasos: Agenda > Nueva cita (Cliente QA41, QA Firulais, motivo Vacunacion, hoy 5:00 p. m.) > Guardar (`Cita agendada`) > Completar.
- Observado: pantalla "Completar cita / ¿Registrar la consulta?" con fila `QA Firulais / Pendiente / Registrar dosis aplicada, QA Firulais`; se abre el selector de biologico (sin preseleccion); Leptospirosis -> Guardar -> la fila pasa a `Dosis registrada: Leptospirosis` + snackbar `Dosis registrada. Proxima: 23/10/2026`; "Completar sin consulta" -> cita `Completada`, snackbar `Cita completada`.
- Evidencia: `qa/05-F8-completar.png`, `qa/05-F8-dosis-registrada.png`.
- Nota de interaccion: al elegir cliente, la mascota quedo preseleccionada; tocarla otra vez la deselecciona ("Elige al menos una mascota.").

### F9 - PASS
- Pasos: Inicio > Vacunar > buscar "QA Fir" > QA Firulais (`Perro · Cliente QA41 / Vencida`) > Biologico "Desparasitacion interna" > Guardar.
- Observado: vuelve a Inicio con snackbar `Dosis registrada. Proxima: 31/12/2026` (90 dias).
- Evidencia: `qa/05-F9-buscar.png`, `qa/05-F9-registrada.png`.

### F10 - PASS
- Pasos: Mas > Protocolos > Polivalente > "Duracion 28 dias" > Guardar cambios; abrir formulario de dosis y elegir Polivalente; luego Polivalente > "Restablecer valores estandar" > Restablecer.
- Observado: lista `Polivalente / 3 dosis cada 28 dias · refuerzo anual / Personalizado`; preview de la siguiente dosis `Proxima: 30/10/2026 / Dosis 2 de 3 · Dosis 3 de 3` (+28); snackbar `Protocolo guardado`. Tras restablecer: `Polivalente / 3 dosis cada 21 dias · refuerzo anual` (sin "Personalizado"), snackbar `Valores estandar restablecidos`; dialogo "¿Restablecer valores estandar? Se usaran los intervalos estandar para Polivalente. Las dosis ya registradas no cambian."
- Observacion menor: en el editor, "Duraciones disponibles al registrar" lista el chip "3 meses" dos veces. 
- Evidencia: `qa/05-F10-protocolos.png`, `qa/05-F10-polivalente-28.png`, `qa/05-F10-preview-28.png`, `qa/05-F10-restablecido.png`.

### F11 - PASS
- Pasos: Carne > Compartir carne.
- Observado: sheet "Compartir carne de QA Firulais" con enlace `stevenescobarc.github.io/…098a`, "Quien tenga el enlace podra ver el carne.", `Enviar por WhatsApp al dueno / Dueno: Cliente QA41 · +57 300 987 6543`, Compartir enlace, Descargar PDF, Copiar enlace (`Enlace copiado`), `Regenerar enlace / El enlace anterior dejara de funcionar`. "Descargar PDF" abre la hoja del sistema `Sharing 1 file / Carne_QA_Firulais_2026-10-02.pdf`. Dialogo `¿Regenerar el enlace del carne? El enlace anterior dejara de funcionar. Quien lo tenga vera un aviso de enlace no valido. Debera compartir el nuevo.` (Volver / Regenerar); tras confirmar el enlace pasa a `…bb47`.
- Evidencia: `qa/05-F11-compartir.png`, `qa/05-F11-copiado.png`, `qa/05-F11-pdf.png`, `qa/05-F11-regenerar-dialogo.png`, `qa/05-F11-regenerado.png`.
- No se abrio el contenido del PDF (verificacion de tablas/Aplico: queda para el telefono real, Task 3).

### F12 - PASS
- Pasos: enlace copiado pegado en Chrome sin sesion; despues regenerar y reabrir el enlace viejo en una pestana nueva; despues pegar el enlace nuevo.
- Observado (enlace `…098a`): carne publico con `QA Firulais / Perro / Propietario: Cliente Q.` (formato "Nombre I."), chip global `Vencida`, `Actualizado el 02/10/2026`, tarjetas por biologico con fechas dd/mm/aaaa, `Aplico: Dr(a). QA Admin Cuarenta`, pie con datos de la clinica, aviso informativo y `Hecho con VetApp`. No aparece la dosis Polivalente anulada ni texto "Anulada". Sin logo (no hay logo configurado, ver F13). Placeholder de inicial "Q" en lugar de foto de mascota (la foto de mascota se cargo despues).
- Tras regenerar: el enlace viejo muestra `Este enlace no es valido / Es posible que haya sido reemplazado. Pidale a su veterinario que le envie el enlace actualizado.` + `Hecho con VetApp`. El enlace nuevo (`…bb47`) renderiza el carne (footer "Hecho con VetApp", sin aviso de invalido).
- Estilo: publicado antes de los fixes de marca; diferencias visuales = pendiente de push.
- Evidencia: `qa/05-F12-publico-1.png`, `qa/05-F12-publico-footer.png`, `qa/05-F12-viejo-invalido.png`, `qa/05-F12-nuevo-valido.png`.

### F13 - FAIL (G6) / subpasos BLOCKED
- Hecho: Mas > "Datos de la clinica" como admin muestra el formulario editable (Logo "Agregar logo", Tomar foto, Elegir de galeria, nombre/ciudad/direccion/telefono, Guardar cambios).
- Imagen de prueba: PNG azul "LOGO QA" 400x400 (y copia JPEG) generada y enviada a la galeria del emulador (`/sdcard/Pictures/logo_qa.png`, `logo_qa2.jpg`).
- FAIL G6 (mayor): al elegir la imagen en "Elegir de galeria" (probado con PNG y JPEG) y tambien con "Tomar foto" (camara virtual, aceptando permiso "Solo esta vez"), la pantalla vuelve **sin vista previa** y sin mensaje de error: sigue "Agregar logo". Verificacion adicional: se edito el telefono (`30012345709`) antes de elegir la imagen y al volver del selector el campo estaba revertido a `3001234570`, es decir la pantalla se reconstruyo y el estado local (`_preview`) se perdio. El mismo selector funciona en la ficha de la mascota (foto de paciente), asi que el problema es especifico de esta pantalla. Esperado: preview del logo -> "Guardar cambios" -> `Datos de la clinica guardados`. Causa probable: `datos_clinica_screen.dart:178-188` (`_elegir` retorna si `!mounted`, y `miClinicaProvider` autoDispose que depende de `authProfileProvider`, `clinica_providers.dart:18-23`, hace que `clinica.when(loading: ...)` en `datos_clinica_screen.dart:~17-45` descarte el `_Formulario` al volver de la actividad externa). Recomendado `/gsd-debug`; reproducir tambien en telefono real.
- BLOCKED (dependen de poder fijar el logo): logo junto al nombre en el carne en la app, en el PDF y en la pagina publica; "Quitar logo" + guardar; re-agregar el logo al final.
- BLOCKED: comprobacion de solo lectura como veterinario no administrador (`Solo los administradores pueden cambiar los datos de la clinica.`). En la clinica QA no hay veterinario no admin ACTIVO: `colega2` fue retirado en 4.1 (acceso revocado) y `colega1` pertenece a Papon Vet (clinica real, no se uso). No se invito ni registro a nadie. Pendiente para el telefono real / otra cuenta.
- Evidencia: `qa/05-F13-preview-logo.png`, `qa/05-F13-preview-logo-jpg.png`, `qa/05-F13-logo-no-preview.png`.

## Estado final de los datos de prueba (para la verificacion del orquestador con token real)
- Mascota QA: **QA Firulais** (dueno Cliente QA41), clinica "QA Clinica 41".
- Enlace compartido: **ACTIVO** (token terminado en `…bb47`, generado en la regeneracion de F11/F12; no se regenero despues).
- Logo de la clinica: **NO establecido** (G6 impidio fijarlo). No se pudo cumplir el requisito "dejar el logo puesto".
- Dosis: Polivalente (1 vigente + 1 anulada), Antirrabica 3 anos, Bordetella externa, Desparasitacion externa vencida (15/08/2026), Desparasitacion interna, Leptospirosis; Giardia anulada y presente en el catalogo como "Personalizado". Cita Vacunacion completada hoy. Protocolo Polivalente restablecido a 21 dias.
- La foto de la mascota quedo como la imagen "LOGO QA" (se uso para comprobar el selector).

## Cambios al dispositivo
- `pm clear`: NO.
- APK reinstalado con `adb install -r` (sin perder sesion).
- Zona horaria: sin cambios (el emulador esta en GMT).
- Permisos: camara concedida "Solo esta vez" a com.vetapp.vetapp (se revoca sola); sin cambios a POST_NOTIFICATIONS.
- Archivos agregados a la galeria: `/sdcard/Pictures/logo_qa.png`, `/sdcard/Pictures/logo_qa2.jpg` (y una foto de la camara virtual); se dejan en el emulador.
- Chrome del emulador: se completo el onboarding ("Stay signed out", "No thanks", "Never translate Spanish"); 2 pestanas abiertas.
- Estado de la app al terminar: sesion de `qa.vet41.admin` iniciada, en primer plano.

## Gaps (para `/gsd-plan-phase 5 --gaps`)
1. G6 (mayor) - Logo de clinica no se puede establecer: preview no aparece / estado de la pantalla se reinicia al volver del selector. Bloquea D-26 en la practica.
2. G5 (mayor) - "Agendar" en Vacunas pendientes provoca pantalla roja (assert de Navigator).
3. G4 (mayor) - Tarjeta "Vacunas pendientes" de Inicio y lista de pendientes no se refrescan tras registrar/anular dosis.
4. G1 (menor) - Linea de contexto del preview: "Dosis 1 de 3 · Dosis 2 de 3" en lugar de "Dosis 2 de 3 · en 21 dias".
5. G2 (menor, producto) - Intervalos en dias fijos (3 anos = 1095 d, 6 meses = 180 d, 1 mes = 30 d).
6. G3 (menor) - Biologico cuya unica dosis se anula desaparece del carne sin dejar rastro en Historial.
7. Menores: nombre de mascota desactualizado en el estado vacio del carne tras renombrar; chip "3 meses" duplicado en el editor de protocolos.

## Pendiente para telefono real (Task 3)
- WhatsApp real (Recordar, Enviar por WhatsApp), contenido del PDF (dos tablas, "Aplico: Dr(a). ... · Mat. ..."), logo en PDF/pagina publica, solo lectura de no-admin, G6 y G5 en dispositivo fisico.

QA: FAIL — F6 (G4), F7 (G5 Agendar crash) y F13 (G6 logo no se puede establecer) fallan; F13 solo lectura y subpasos de logo BLOCKED
