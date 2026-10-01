# Phase 4: Agenda y Citas - Context

**Gathered:** 2026-09-30
**Status:** Ready for planning

<domain>
## Phase Boundary

El veterinario gestiona su agenda desde el celular: ve sus citas por día/semana (AGND-01), crea citas asociadas a un cliente y una o varias mascotas (AGND-02), cambia su estado (AGND-03), recibe un recordatorio local antes de cada cita (AGND-04), le recuerda la cita al cliente por WhatsApp con un toque vía `wa.me` (AGND-05) y, al completar una cita, registra consulta(s) de historia clínica vinculadas (AGND-06).

Fuera de esta fase: agenda multi-veterinario (excluida en REQUIREMENTS.md), recordatorios automáticos por WhatsApp Business API (DIFF-01, v2), push desde servidor (FCM está excluido con Firebase), citas solicitadas por el cliente (UI en Fase 9), dashboard de próximas citas (DASH-02, Fase 8).

Insumo previo: informe de `vetapp-opportunity-research` (2026-09-30) — las recomendaciones adoptadas quedan registradas abajo como decisiones.

</domain>

<decisions>
## Implementation Decisions

### Crear una cita
- **D-01:** La duración se fija **según el motivo**: chips de motivo (Consulta general, Vacunación, Control, Desparasitación, Baño/peluquería, Cirugía…) que traen una duración por defecto (ej. 30 min); el vet puede cambiarla. Se guarda inicio + duración.
- **D-02:** **Domicilio**: interruptor "A domicilio"; al activarlo la dirección se prellena con `clientes.direccion` y se puede cambiar para esa cita. En la tarjeta/detalle, botón "Cómo llegar" que abre Google Maps (sin pedir permisos de ubicación).
- **D-03:** Una cita puede incluir **varias mascotas del mismo dueño** (ej. Rocky y Luna juntos) — modelo de datos con relación cita↔mascotas (tabla puente), no un solo `mascota_id`.
- **D-04:** Si el cliente no está registrado: búsqueda instantánea del cliente; si no aparece, "+ Nuevo cliente y mascota" usa el **alta combinada existente** (Fase 2) y vuelve a la cita con cliente y mascota ya seleccionados. No se permiten citas sin cliente registrado.
- **D-05:** Campos obligatorios: **cliente, al menos una mascota, fecha y hora**. Motivo tiene valor por defecto "Consulta general". Notas y domicilio son opcionales. (Fricción cero.)
- **D-06:** Hora: la app **sugiere el primer hueco libre** del día elegido; se ajusta con botones grandes en pasos de 15 min (no el reloj analógico de Material).
- **D-07:** Puntos de entrada para crear cita: **botón "Nueva cita" en Agenda** y **"Agendar cita" desde la ficha de mascota/cliente** (con cliente y mascota preseleccionados).

### Vista y estados
- **D-08:** Vista: **tira de días LUN–DOM + lista de citas por hora** del día seleccionado (como el mockup). La tira indica cuántas citas hay por día; navegación entre semanas; abre siempre en "Hoy". No se usa paquete de calendario de terceros (table_calendar/syncfusion).
- **D-09:** Cruces: si una cita nueva o editada se solapa con otra, **avisar sin bloquear** ("Se cruza con Luna 10:00 — ¿agendar igual?"). Nada de constraint de exclusión en BD.
- **D-10:** Estados: **pendiente, confirmada, completada, cancelada, no_asistió**. Además, **`solicitada` reservado en la base de datos para Fase 9** (cita pedida por el cliente desde el directorio), sin UI en esta fase. Preferir `text` + `check` sobre enum de Postgres para poder ampliar.
- **D-11:** El estado se cambia con **botones visibles en la tarjeta y en el detalle** (Confirmar / Completar / No asistió / Cancelar), con "Deshacer" en snackbar. Sin gestos de deslizar.

### Recordatorios
- **D-12:** Recordatorio local: **1 hora antes por defecto**, configurable globalmente en Más > Recordatorios (15/30/60/120 min). No por cita.
- **D-13:** Permiso de notificaciones (Android 13+) se pide **en contexto al crear la primera cita**, explicando para qué sirve. Si se niega, aviso persistente (no error) en Agenda.
- **D-14:** Mensaje de WhatsApp en **tono formal con "usted"**. Plantilla base: *"Hola {cliente}, le recordamos la cita de {mascota(s)} el {ddd dd/mm} a las {h:mm a. m.} {en el consultorio | a domicilio en {dirección}}. — {veterinario}, {clínica}. Responda SÍ para confirmar."*
- **D-15:** **"Recordar a todos los de mañana"**: botón en la vista del día siguiente que abre WhatsApp cliente por cliente en serie y marca cada cita como "recordatorio enviado" (fecha/hora). Cada cita también tiene su botón WhatsApp individual con la misma marca.
- **D-16:** Teléfono: **normalizar a formato +57** al usarlo y al guardar en formularios de cliente ("300 123 4567" → `573001234567`); aviso suave si no parece celular colombiano; números fijos sin botón WhatsApp (deshabilitado con explicación); números con otro indicativo "+" se respetan. Sin migración masiva de datos existentes.

### Completar → consulta
- **D-17:** "Completar" **ofrece registrar consulta, pero es opcional**: abre el formulario de consulta ya vinculado a la cita; también existe "Completar sin consulta" (vacuna rápida, etc.).
- **D-18:** Con varias mascotas: **una consulta por mascota** — se muestra la lista de mascotas de la cita y se registra cada una (se puede saltar alguna). La cita queda completada al cerrar ese flujo.
- **D-19:** La consulta se **precarga con el motivo (y notas) de la cita en anamnesis**, editable antes de guardar. La consulta guarda referencia a la cita (vínculo formal cita→consulta). Las consultas siguen siendo solo-append (HIST-04 / Fase 3 D-01): solo se agrega la referencia al crearla.

### Claude's Discretion
- Esquema exacto: tablas `citas` / `cita_mascotas`, columnas (`fecha_hora timestamptz`, `duracion_min`, `modalidad`, `direccion`, `motivo`, `notas`, `estado`, `recordatorio_enviado_at`), FK compuestas por `clinica_id` como en `mascotas`, índices, RLS (via agente `vetapp-supabase`) y extensión de `supabase/tests/rls_smoke_test.sql`.
- Mecanismo del vínculo cita→consulta (p. ej. `consultas.cita_id` nullable + parámetro nuevo en `registrar_consulta`, o RPC nueva) y si completar la cita va en la misma transacción.
- Si cancelar reemplaza al borrado (recomendado: no borrar citas, solo cancelar).
- Paquete de notificaciones locales (p. ej. `flutter_local_notifications` + `timezone`), modo de programación (preferir inexacto sin permiso de alarma exacta), reprogramación idempotente al abrir app / cambiar sesión, `cancelAll()` al cerrar sesión, compatibilidad con Dart `^3.11.1` y requisitos de build Android (desugaring, compileSdk).
- Zona horaria: guardar `timestamptz`, mostrar en America/Bogota (UTC-5 fijo); rangos de "día" calculados en hora de Bogotá.
- `url_launcher` como dependencia directa para `wa.me` y Maps; detección de regreso de WhatsApp en el envío en serie (fallback: marcar manualmente).
- Lista exacta de motivos y sus duraciones por defecto; dónde vive la utilidad de normalización de teléfono (`lib/core/utils/`).
- Diseño visual de tarjeta, detalle y formulario — resolver en `/gsd-ui-phase 4` siguiendo el mockup.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Alcance y requisitos
- `.planning/ROADMAP.md` §"Phase 4: Agenda y Citas" — objetivo y 6 criterios de éxito
- `.planning/REQUIREMENTS.md` — AGND-01..06; DIR-05 (Fase 9 depende de `citas`); exclusiones (multi-veterinario, WhatsApp API)
- `.planning/PROJECT.md` — principio de fricción cero; Colombia (COP, dd/mm/aaaa)

### Diseño
- `.planning/design/DESIGN-REFERENCE.md` §6 Agenda — tira de días + lista por hora + "Nueva cita"
- `.planning/design/vetapp-mobile-designs.html` — mockup aprobado

### Decisiones previas
- `.planning/phases/02-clientes-y-pacientes/02-CONTEXT.md` — alta combinada, búsqueda instantánea, campos mínimos
- `.planning/phases/03-historia-cl-nica/03-CONTEXT.md` — consulta solo-append, obligatorios diagnóstico+tratamiento

### Investigación y riesgos
- `.planning/research/PITFALLS.md` — conciliar entidad `Cita` con schema; varias mascotas por cita; estados de carga/vacío/error
- `.planning/research/STACK.md`, `.planning/research/FEATURES.md` — stack recomendado y WhatsApp como canal principal
- `.claude/LOOPING.md` — uso de agentes vetapp-supabase / vetapp-gate / vetapp-brand-ui en la fase

### Backend
- `supabase/schema.sql` — `clientes` (l.31), `mascotas` (l.60, FK compuesta por clinica_id), `registrar_cliente_con_mascota` (l.269), `consultas` (l.468), `registrar_consulta` (l.530)
- `supabase/tests/rls_smoke_test.sql` — patrón de pruebas RLS con rol `authenticated`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/core/router/app_router.dart`: rama `/agenda` del shell ya existe (hoy `ComingSoonScreen`) — reemplazar con rutas de la feature, siguiendo `lib/features/patients/presentation/pacientes_routes.dart`.
- `lib/core/widgets/status/app_status_chip.dart`: chip con confirmed/pending/cancelled/completed — ampliar con "No asistió".
- `lib/features/clients/presentation/screens/nuevo_cliente_mascota_screen.dart` + RPC `registrar_cliente_con_mascota`: alta combinada reutilizable desde el flujo de nueva cita.
- `lib/features/clinical_history/presentation/screens/consulta_form_screen.dart` (recibe `mascotaId`) + RPC `registrar_consulta`: base para completar cita → consulta.
- `lib/features/appointments/domain/entities/cita.dart`: borrador sin conciliar (usa `veterinarioId`, sin `clinicaId`, duración, dirección ni lista de mascotas) — reescribir según schema.

### Established Patterns
- Riverpod `Notifier`/`AsyncNotifier` + go_router; repositorios con traducción de errores a fallos en español.
- RPCs `security invoker` para operaciones atómicas multi-tabla.
- RLS por `clinica_id` con `es_veterinario()` / `mi_clinica_id()`; FK compuestas `(x_id, clinica_id)`.
- Teléfono hoy es texto libre (`nuevo_cliente_mascota_screen.dart`, `cliente_detail_screen.dart`) — D-16 lo cambia.

### Integration Points
- Ficha de cliente/mascota → botón "Agendar cita" (D-07).
- Formulario de consulta → recibe referencia de cita y precarga (D-19).
- Más > Recordatorios (ajuste global de anticipación, D-12).
- Cierre de sesión → cancelar notificaciones programadas.

</code_context>

<specifics>
## Specific Ideas

- Franja superior en Agenda tipo "Próxima: Luna 10:30 · en 25 min" (sugerida por research; a validar en UI-SPEC).
- Tarjeta de cita con acciones directas ≥48dp: WhatsApp, Cómo llegar (si domicilio), Completar.
- Vista "Hoy" por defecto: la pregunta real entre citas es "¿quién sigue, dónde y cómo le aviso?".

</specifics>

<deferred>
## Deferred Ideas

- "¿Agendar control en 8/15/30 días?" al guardar una consulta — no seleccionado como entrada en esta fase; candidato a backlog/Fase 8.
- Cola offline de cambios de estado de citas (atención en zonas sin señal) — backlog junto con estrategia offline-first general.
- Plantilla de WhatsApp editable por el veterinario — se eligió plantilla fija formal; posible mejora futura.
- Sincronización con Google Calendar, citas recurrentes — descartadas para v1.

</deferred>

---

*Phase: 04-agenda-y-citas*
*Context gathered: 2026-09-30*
