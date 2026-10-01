# Fase 04 (agenda-y-citas) - Reporte QA en emulador

- Fecha: 2026-10-01
- Dispositivo: AVD Pixel_9_API_35 (emulator-5554), Android 15, sin WhatsApp, con Chrome y Google Maps
- Build: `flutter run -d emulator-5554 --dart-define-from-file=dart_define.json` sobre master (log: `qa/flutter-run.log`)
- Sesion: veterinario Sarah Medrano / Papon Vet (sesion ya iniciada, se conserva al final)
- Evidencia: `.planning/phases/04-agenda-y-citas/qa/*.png`

## Resumen

| Caso | Fuente | Resultado |
|------|--------|-----------|
| C1 Permiso: banner "Recordatorios desactivados", Activar -> prompt OS -> ajustes -> banner desaparece | VALIDATION Manual-Only #1 / UAT paso 1 | PASS (parcial: el rationale de primera vez no se pudo repetir sin `pm clear`) |
| C2 Notificacion a T-lead y tap abre `/agenda/:id` | VALIDATION #2 / UAT paso 2 | PASS |
| C3 Reinicio: recordatorio sobrevive y sin duplicados | VALIDATION #3 / UAT paso 3 | PASS |
| C4 Sin recordatorios tras cerrar sesion | VALIDATION #4 / UAT paso 4 | BLOCKED |
| C5 WhatsApp texto exacto / fallback / linea fija | VALIDATION #5 / UAT paso 5 | FAIL (fallback) / PASS (linea fija) |
| C6 "Recordar a todos los de manana" en serie | VALIDATION #6 / UAT paso 6 | PASS |
| C7 "Como llegar" abre Maps | VALIDATION #7 / UAT paso 7 | PASS |
| C8 Zona horaria UTC | VALIDATION #8 / UAT paso 8 | PASS |
| C9 WhatsApp real en telefono fisico | 04-HUMAN-UAT.md | REQUIERE-DISPOSITIVO |
| C10 Completar cita con 2 mascotas (consulta, omitir, Finalizar, historia clinica) | 04-11 Tarea 2 paso 9 | PASS |
| C11 Hueco sugerido dentro de 06:00-22:00 (ME-06) | REVIEW-FIX | PASS (parcial: solo se pudo probar de dia) |
| C12 Cita cancelada/No asistio: "Esta cita ya no se puede completar." (ME-04) | REVIEW-FIX | BLOCKED (sin ruta de UI) |
| C13 Editar cita: mascota con consulta bloqueada (ME-01/LO-05) | REVIEW-FIX | PASS |
| C14 Telefono "abc" no deja guardar cliente (ME-03) | REVIEW-FIX | PASS |

## Detalle por caso

### C1 Permiso de notificaciones - PASS (parcial)
- Estado inicial: POST_NOTIFICATIONS `granted=true` y el flag "rationale ya explicado" ya estaba puesto (`permiso_notificaciones.dart:26` retorna antes de mostrar el dialogo), por lo que el rationale '¿Te avisamos antes de tus citas?' no se pudo ver de nuevo sin `pm clear`. No se hizo `pm clear`.
- Pasos: `pm revoke ... POST_NOTIFICATIONS`, relanzar app, abrir Agenda.
- Observado: banner "Recordatorios desactivados / Activa las notificaciones para que te avisemos antes de cada cita." + boton "Activar" (`qa/04-C1-banner.png`). Activar -> prompt del SO "Allow vetapp to send you notifications?" (`qa/04-C1-os-prompt.png`). "Don't allow" y Activar de nuevo -> abre `Settings$AppNotificationSettingsActivity` (`qa/04-C1-settings.png`). Se activo el interruptor, `dumpsys package` -> `POST_NOTIFICATIONS: granted=true`. Al volver a la app el banner ya no esta (`qa/04-C1-banner-desaparece.png`).
- Nota: tras una sola negativa Activar ya abre ajustes (el SO deja de mostrar el prompt tras revocar+negar); no se probo el conteo "dos veces" de forma literal.

### C2 Notificacion a T-lead y tap - PASS
- Recordatorios puestos en "15 minutos antes" (Mas > Recordatorios). Cita QA (Luna, Steven) 12:15 p. m. creada con "Agendar igual" (dialogo de cruce funciona, `qa/04-C2-overlap.png`).
- `dumpsys alarm`: alarma `origWhen=17:00:00 UTC` = 12:00 Bogota (T-15). Disparo real a las 17:03 GMT: `android.title=String (Cita en 15 min)`, canal `citas`.
- Tap en la notificacion (app en segundo plano) -> detalle de la cita Luna 12:15-12:45 (`qa/04-C2-tap-detalle.png`).
- Segundo ciclo tras reinicio (ver C3): notificacion 17:37 GMT, tap con la app sin actividad abierta -> detalle de Snowy 12:45-1:15 (`qa/04-C2-cold-tap.png`). Nota: el proceso existia (lo levanta el receptor de la alarma), no es un arranque en frio puro.
- Observacion (no bloqueante): las alarmas son inexactas (`window=+16m56s`, flags 0x20); las notificaciones llegaron 3 y 7 minutos tarde. Coherente con "allow minutes of slack" pero relevante para el producto.

### C3 Reinicio sin duplicados - PASS
- Cita Snowy 12:45 con alarma 17:30 UTC. `adb reboot`. Tras el arranque, sin abrir la app: `dumpsys alarm` seguia mostrando `origWhen 1790875800000` (17:30 UTC) para com.vetapp.vetapp. La notificacion se disparo a las 17:37 GMT, 1 sola `NotificationRecord` de com.vetapp.vetapp; tras abrir la app (resync) sigue habiendo 1 sola alarma por cita y 0 notificaciones nuevas.
- Estado final de alarmas pendientes: 02:45, 12:45, 13:15, 13:45 UTC del 02/10, una por cita futura, sin duplicados.

### C4 Sin recordatorios tras cerrar sesion - BLOCKED
- Cerrar sesion destruye la sesion de prueba y no hay credenciales de prueba en seeds/README/tests (`supabase/` solo tiene schema, config y verify_live_schema.sh). Se omitio para dejar la sesion iniciada, como se pidio. Pendiente para el humano (o una corrida donde se pueda re-iniciar sesion). El comportamiento de cancelacion al cerrar sesion (ME-02) esta cubierto por `test/recordatorios_providers_test.dart` segun 04-REVIEW-FIX.md, no por este QA.

### C5 WhatsApp - FAIL (fallback), PASS (linea fija)
- Linea fija: cliente "Sarah x2" (312333111) -> tarjeta muestra "Este numero parece un telefono fijo; no se puede enviar WhatsApp." y el boton se ve atenuado (arbol: `Este número parece un teléfono fijo; no se puede enviar WhatsApp.`). PASS.
- Fallback sin WhatsApp: se pulso "WhatsApp" en la cita de Steven (celular). Esperado: SnackBar "No pudimos abrir WhatsApp. ¿Está instalado?". Observado: se abrio Chrome (`com.android.chrome ... FirstRunActivity`, `qa/04-C5-chrome.png`) con el enlace `https://wa.me/...`, y al volver la app mostro "Marcado como recordatorio enviado" y "Enviado 01/10 11:51 a. m." (se deshizo con Deshacer). No se envio ningun mensaje.
- Causa probable: `lib/core/utils/lanzador_externo.dart:17` usa `launchUrl(uri, mode: LaunchMode.externalApplication)` con la URL `https://wa.me/...` (`lib/features/appointments/domain/whatsapp_recordatorio.dart:29`); cualquier navegador resuelve esa URL, asi que `abrir()` devuelve true aunque WhatsApp no este instalado, y la cita queda marcada como enviada sin que se haya enviado nada.
- No verificable en emulador: texto exacto con tildes/"—"/"SÍ" dentro de WhatsApp (ver C9).
- Recomendacion: `/gsd-debug` (bug puntual de detectar WhatsApp / no marcar como enviado si solo abrio el navegador).

### C6 Recordar a todos los de manana - PASS
- Se crearon 3 citas el vie 02/10 (Steven/Papon 8:00, Steven/Luna 8:30, "QA Cliente..." /QA Mascota 9:00). El dia muestra "Mañana, vie 02/10 / 3 citas" y "Recordar a todos los de mañana (3)" (`qa/04-C6-manana.png`).
- Hoja "Recordar a los de mañana": 3 filas "Pendiente de enviar" y "Enviar a Steven" (`qa/04-C6-lote-1.png`). "Enviar a Steven" abrio Chrome (sin WhatsApp); al volver la fila 1 paso a "Enviado" y el boton avanzo al siguiente. "Marcar como enviado" manual marco las filas 2 y 3 (`qa/04-C6-lote-2.png`) y termino con "Listo, recordaste a 3 clientes." 
- Nota: el avance al volver tambien ocurre cuando solo se abrio el navegador (misma causa que C5).

### C7 Como llegar - PASS
- Cita QA a domicilio (Papon y Luna, Steven) con direccion. Detalle (scroll) -> "Cómo llegar" -> `topResumedActivity=com.google.android.apps.maps/...MapsActivity`. VetApp no declara ni pidio permisos de ubicacion (el unico prompt fue de Maps: "Allow Maps to access this device's location?", se nego). Captura: `qa/04-C7-como-llegar.png` (pantalla de bienvenida de Maps; no se verifico visualmente el destino dentro de Maps).
- Nota de QA: la direccion quedo guardada como `Carrera%2010%20%2312-34%20Bogota` porque se tecleo con `adb input text` usando codificacion URL; no es un bug de la app (ver Notas del QA).

### C8 Zona horaria - PASS
- El dispositivo ya estaba en `persist.sys.timezone=GMT` (UTC) al empezar y despues del reinicio. No se cambio ninguna zona.
- Con el dispositivo en UTC (`date` -> `16:47 GMT` mientras la app mostraba "Hoy, jue 01/10" y la hora Bogota 11:47): las citas se muestran en hora Bogota. Se creo una cita a las 10:00 p. m. del jue 01/10 (el stepper se detiene en 10:00 p. m., no permite 11:30 p. m.; 10:00 p. m. Bogota = 03:00 UTC del 02/10): aparece en "Jueves 1" y no en "Viernes 2" (`qa/04-C8-2200-jueves.png`); su recordatorio esta en `02:45 UTC` = 9:45 p. m. Bogota, y los de las 8:00/8:30/9:00 a. m. de manana en 12:45/13:15/13:45 UTC = 7:45/8:15/8:45 Bogota. Los limites de dia y horas de recordatorio son Bogota-correctos.

### C9 WhatsApp real - REQUIERE-DISPOSITIVO
- 04-HUMAN-UAT.md test 1 queda `[pending]`: abrir el chat con el texto D-14 prellenado y "Recordatorio enviado" solo es verificable en un telefono con WhatsApp.

### C10 Completar cita con 2 mascotas - PASS
- Cita "Papon y Luna" (12:30). Completar: "¿Registrar la consulta?" con filas Papon/Luna "Pendiente" (`qa/04-C9-completar.png`). Registrar consulta para Papon: formulario con pill "Cita del jue 01/10 · 12:30 p. m." y anamnesis precargada "Consulta general." (`qa/04-C9-consulta-form.png`, `qa/04-C9-consulta-llena.png`); tras guardar: "Consulta guardada", Papon "Consulta registrada" (`qa/04-C9-tras-guardar.png`). Luna -> Omitir -> "Omitida". "Finalizar cita" -> agenda con la cita "Completada" y snackbar "Cita completada" + "Deshacer" (`qa/04-C9-finalizada.png`).
- Historia clinica de Papon: entrada "01/10/2026 / QA diagnostico prueba" (`qa/04-C9-historia.png`).

### C11 ME-06 hueco sugerido - PASS (parcial)
- Los huecos sugeridos observados (12:30, 1:00 p. m., 1:15 p. m., 8:00 a. m. para manana) estan dentro de 06:00-22:00 y no en el pasado ("Primer hueco libre sugerido"; al modificar la hora cambia a "Hora elegida"). El stepper se detiene en 10:00 p. m. (`qa/04-C8-2330.png` muestra el tope). No se pudo probar el caso "ahora son las 22:xx" sin cambiar el reloj del emulador.

### C12 ME-04 cita cancelada / No asistio - BLOCKED (sin ruta de UI)
- La pantalla Completar solo se alcanza desde botones que no existen en citas cancelada/no_asistio. Se cancelo la cita QA Luna: el detalle solo ofrece "Reabrir cita" (sin "Completar cita") y la tarjeta tampoco (`qa/04-C12-cancelada.png`). No hay deep link (el manifiesto solo tiene MAIN/LAUNCHER) para forzar `/agenda/:id/completar`, por lo que el texto "Esta cita ya no se puede completar." (`completar_cita_screen.dart:111`) no se pudo ver en pantalla. Cubierto solo por `test/completar_cita_screen_test.dart` segun REVIEW-FIX. No se probo "No asistio" (misma ruta). La cita Luna se restauro con Deshacer (Pendiente).

### C13 ME-01/LO-05 editar cita con consulta - PASS
- Editar cita "Papon y Luna" tras registrar la consulta de Papon: fila "Papon / Perro · Consulta registrada", checkbox `checked="true" enabled="false"`, y al tocarlo sigue marcado (`qa/04-C12-editar-bloqueada.png`). Luna (sin consulta) es editable.

### C14 ME-03 telefono "abc" - PASS
- Clientes > Nuevo cliente, telefono `abc`: campo en rojo con "Escribe un número de teléfono." (`qa/04-C12-telefono-abc2.png`); "Guardar cliente y mascota" con datos completos no guarda (sigue en el formulario, lista de clientes sin cambios) (`qa/04-C12-guardar-bloqueado.png`). Con `3000000001` guarda y aparece `573000000001` en la lista.

## Observaciones adicionales (no son FAIL de un caso)
- Back stack tras abrir el detalle desde la notificacion: "Atras" desde el detalle llevo a la pestana Pacientes y la pestana Agenda seguia mostrando el detalle (se vio al volver a Agenda). Reproducible pero no concluyente; evaluar `agenda_routes.dart`.
- Los snackbars con accion "Deshacer" no se auto-cierran bajo uiautomator y tapan los botones inferiores; es un artefacto de accesibilidad de la herramienta, no se reporta como bug.

## Datos de prueba dejados en Supabase
- Cliente "QA Cliente ABCQA MascotaQA Mascota" (3000000001) con mascota "QA Mascota" (el nombre salio concatenado por un error de tecleo del QA).
- Citas QA hoy: Luna 12:15 (Pendiente), Papon y Luna 12:30 (Completada, consulta de Papon "QA diagnostico prueba"), Snowy 12:45, QA Mascota 10:00 p. m.; manana: Papon 8:00, Luna 8:30, QA Mascota 9:00. Preferencia "Recordatorios" = 15 minutos antes (antes era 1 hora antes).

## Cambios al dispositivo
- `pm clear`: NO.
- Zona horaria: sin cambios (el AVD ya estaba en GMT/UTC).
- Permisos: POST_NOTIFICATIONS revocado y vuelto a conceder por el flujo de ajustes de la app (estado final: granted=true).
- Se reinicio el emulador una vez (C3) y se relanzo tras una caida durante la corrida; la sesion se mantuvo.
- Preferencia de la app "Recordatorios" cambiada de 1 hora a 15 minutos antes (sigue en 15 min; restaurar manualmente si se desea).

## Notas del QA
- `adb shell input text` NO decodifica `%20`/`%23`: solo `%s` equivale a espacio y los caracteres de shell (`#`, `&`, `(`, `)`, `;`, `<`, `>`, comillas) necesitan escape. Por eso la direccion del caso C7 se guardo como `Carrera%2010%20%2312-34%20Bogota`; es un artefacto del QA, no un bug de la app.
- `uiautomator` expone `content-desc` con saltos de linea como `&#10;`; los apostrofes tipograficos (`Don’t allow`) no se pueden pasar por argv desde bash, hay que tocar por coordenadas.
- La pantalla de la app es 1080x2424 (el dump usa 1080x2361 de area util); verificar siempre con dump antes de tocar.

## Pendiente
- FAIL C5: detectar ausencia de WhatsApp y no marcar "enviado" si solo se abrio el navegador (`/gsd-debug`).
- BLOCKED C4: cerrar sesion y esperar recordatorio (requiere re-login humano).
- BLOCKED C12: ver "Esta cita ya no se puede completar." solo verificable por test o con acceso a ruta directa.
- REQUIERE-DISPOSITIVO C9: WhatsApp real en telefono fisico.

QA: FAIL — C5 falla: sin WhatsApp el enlace wa.me abre el navegador y la cita se marca como enviada (lanzador_externo.dart:17); ademas C4 y C12 quedan BLOCKED
