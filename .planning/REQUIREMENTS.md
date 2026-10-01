# Requirements: VetApp

**Defined:** 2026-09-24
**Core Value:** El veterinario puede llevar toda su consulta — pacientes, historia clínica, agenda — desde el celular, sin depender de un computador ni de una recepcionista.

## v1 Requirements

Requisitos para el primer release real (reemplazo del UI mockeado por datos reales de Supabase). Cada uno se mapea a una fase del roadmap.

### Fundación (FOUND)

- [x] **FOUND-01**: Existe un proyecto Supabase real en la nube, enlazado al repo, con `schema.sql` aplicado
- [x] **FOUND-02**: La navegación de la app usa `go_router` con las 5 secciones del bottom nav (Inicio, Pacientes, Agenda, Clientes, Más)
- [x] **FOUND-03**: El estado de la app se maneja con Riverpod (`Notifier`/`AsyncNotifier`), sin `setState` directo en pantallas de datos
- [x] **FOUND-04**: Existe una tabla `clientes` independiente de `perfiles`, para que el veterinario pueda registrar clientes sin que estos necesiten autenticarse
- [x] **FOUND-05**: Las políticas RLS de `clinicas`, `perfiles` y `mascotas` están probadas contra el rol `authenticated` (no solo service-role), incluyendo el fix de auto-escalación de privilegios en `perfiles`
- [x] **FOUND-06**: Se elimina el código muerto de la migración Firebase→Supabase (dominio de auth duplicado, `firebase.json`, `google-services.json`, `LoginScreen` duplicado)

### Clientes (CLI)

- [x] **CLI-01**: El veterinario puede crear un cliente (dueño) con nombre y teléfono, sin que el cliente necesite cuenta
- [x] **CLI-02**: El veterinario puede ver y editar los datos de un cliente
- [x] **CLI-03**: El veterinario puede buscar/filtrar clientes por nombre o teléfono
- [x] **CLI-04**: El veterinario puede ver las mascotas asociadas a un cliente
- [x] **CLI-05**: El veterinario puede generar un código/enlace de vinculación desde la ficha del cliente, para que el dueño reclame acceso a sus mascotas registradas cuando cree su propia cuenta (agregado 2026-09-24 — ver DIR-06 en Fase 9 para el lado del cliente)

### Pacientes (PAT)

- [x] **PAT-01**: El veterinario puede crear una ficha de mascota (especie, raza, edad, peso, foto, dueño asociado)
- [x] **PAT-02**: El veterinario puede ver y editar la ficha de una mascota
- [x] **PAT-03**: El veterinario puede subir/cambiar la foto de una mascota (Supabase Storage privado + URL firmada)
- [x] **PAT-04**: El veterinario puede buscar/filtrar mascotas por nombre, dueño o especie
- [x] **PAT-05**: Una mascota puede tener más de un peso registrado en el tiempo (historial de peso)

### Historia clínica (HIST)

- [x] **HIST-01**: El veterinario puede registrar una consulta con campos estructurados (anamnesis, examen físico, diagnóstico, tratamiento, evolución)
- [x] **HIST-02**: El veterinario puede ver la línea de tiempo de consultas de una mascota
- [x] **HIST-03**: El veterinario puede exportar la historia clínica de una mascota a PDF
- [x] **HIST-04**: Los registros de historia clínica son de solo-append (no se editan/borran después de guardados; se corrigen con una entrada nueva)

### Agenda (AGND)

- [x] **AGND-01**: El veterinario puede ver su agenda en vista de día/semana
- [x] **AGND-02**: El veterinario puede crear una cita asociada a un cliente y una mascota
- [x] **AGND-03**: El veterinario puede marcar una cita como confirmada/pendiente/completada
- [x] **AGND-04**: La app envía un recordatorio local (notificación) antes de una cita próxima
- [x] **AGND-05**: El veterinario puede enviar un recordatorio de cita por WhatsApp con un toque (deep-link `wa.me` con mensaje prellenado)
- [x] **AGND-06**: Al completar una cita, se puede crear una entrada de historia clínica vinculada

### Equipo de la clínica (TEAM)

- [ ] **TEAM-01**: El admin de la clínica puede invitar a otro veterinario con un código de un solo uso que vence (el vet invitado lo ingresa al registrarse y queda en la misma clínica)
- [ ] **TEAM-02**: Dentro de una clínica existen dos roles — admin y veterinario — y solo el admin invita, retira y cambia roles (sin auto-escalación de privilegios; nunca queda una clínica sin admin)
- [ ] **TEAM-03**: Al retirar a un veterinario pierde el acceso de inmediato, pero sus consultas/citas/vacunas se conservan con su autoría (desactivar, nunca borrar)
- [ ] **TEAM-04**: Cada cita tiene un veterinario asignado (por defecto quien la crea, reasignable); la agenda muestra "Mías" por defecto con filtro "Todas", y los cruces y recordatorios locales se calculan por veterinario
- [ ] **TEAM-05**: El perfil del veterinario incluye matrícula profesional opcional (Comvezcol), usada en documentos como el carné de vacunación

### Vacunación (VAC)

- [ ] **VAC-01**: El veterinario puede registrar una vacuna/desparasitación aplicada a una mascota (biológico, fecha aplicada)
- [ ] **VAC-02**: El sistema calcula automáticamente la próxima fecha de dosis según el protocolo del biológico (no un campo de fecha editable a mano)
- [ ] **VAC-03**: El veterinario recibe alerta cuando una mascota tiene una dosis próxima o vencida
- [ ] **VAC-04**: El veterinario puede generar un link público de solo lectura con el carné de vacunación de una mascota (sin exponer historia clínica completa)
- [ ] **VAC-05**: El dueño puede ver el carné de vacunación compartido sin necesidad de cuenta

### Inventario (INV)

- [ ] **INV-01**: El veterinario puede registrar un producto/insumo con nombre, cantidad y umbral de stock mínimo
- [ ] **INV-02**: El veterinario recibe alerta cuando un producto cae por debajo del umbral de stock mínimo
- [ ] **INV-03**: El veterinario puede ajustar manualmente la cantidad de un producto

### Facturación (BILL)

- [ ] **BILL-01**: El veterinario puede generar una cotización o factura simple en PDF para un cliente
- [ ] **BILL-02**: Una factura puede incluir uno o más ítems (servicios/productos) con precio
- [ ] **BILL-03**: Al facturar un producto de inventario, el stock se descuenta automáticamente
- [ ] **BILL-04**: El veterinario puede marcar una factura como pagada/pendiente

### Dashboard y diseño (DASH)

- [ ] **DASH-01**: El veterinario ve un resumen al iniciar sesión (consultas del mes, ingresos del mes, pacientes nuevos)
- [ ] **DASH-02**: El veterinario ve sus próximas citas desde el dashboard
- [ ] **DASH-03**: El veterinario tiene accesos rápidos para crear paciente, cita o factura desde el dashboard
- [ ] **DASH-04**: Todas las pantallas de la app usan el diseño visual definitivo (paleta terracota/crema, tipografía Caprasimo + Figtree) del mockup aprobado

### Directorio de veterinarias (DIR)

<!-- Agregado 2026-09-24 — el cliente deja de estar atado a una sola clínica y puede explorar el directorio de veterinarias de la plataforma. Programado como Fase 9 (al final), después del núcleo de gestión de clínica, porque "Agendar cita" depende de Agenda (Fase 4) y la futura restricción de reseñas a citas reales también. -->

- [ ] **DIR-01**: El cliente puede ver un listado de las clínicas activas en la plataforma (nombre, ciudad, dirección, foto/logo si existe, calificación promedio)
- [ ] **DIR-02**: El cliente puede buscar veterinarias por nombre o ciudad, con resultados instantáneos mientras escribe
- [ ] **DIR-03**: El cliente puede filtrar el listado de veterinarias por ciudad
- [ ] **DIR-04**: El cliente puede ver el detalle de una veterinaria (contacto, horario si existe, calificación promedio, reseñas recientes)
- [ ] **DIR-05**: Desde el detalle de una veterinaria, el cliente puede iniciar el flujo de "Agendar cita"
- [ ] **DIR-06**: El cliente puede vincular su cuenta a un registro de cliente existente usando el código/enlace generado por el veterinario (CLI-05), para ver en "Mis mascotas" las mascotas que el veterinario ya le había registrado

### Reseñas de veterinarias (REV)

<!-- Agregado 2026-09-24 -->

- [ ] **REV-01**: El cliente puede dejar una reseña de una clínica (calificación de 1 a 5 estrellas + comentario opcional)
- [ ] **REV-02**: Si el cliente ya calificó una clínica, volver a calificarla edita su reseña existente en vez de crear una duplicada (una reseña por cliente por clínica)
- [ ] **REV-03**: Cualquier persona autenticada puede leer las reseñas públicas de cualquier clínica
- [ ] **REV-04**: Un cliente no puede editar ni borrar la reseña de otro cliente
- [ ] **REV-05**: La calificación promedio mostrada en el listado y el detalle coincide con el promedio real de las reseñas de esa clínica

## v2 Requirements

Reconocidos pero diferidos — no forman parte del roadmap actual.

### Diferenciadores avanzados

- **DIFF-01**: Recordatorios automáticos por WhatsApp Business API (sin toque manual del veterinario)
- **DIFF-02**: Facturación electrónica DIAN vía proveedor autorizado (Siigo/Alegra/Factus)
- **DIFF-03**: Notas de voz transcritas automáticamente a historia clínica
- **DIFF-04**: Sugerencias de dosificación asistidas por IA, basadas en tabla determinística (nunca cálculo libre de un LLM)
- **DIFF-05**: Modo offline con sincronización en segundo plano

### Escalamiento

- **SCALE-01**: App complementaria para el dueño de la mascota (ver historial, citas, carné) — el subconjunto de directorio + reseñas (DIR-*, REV-*) ya se adelantó a la Fase 9; lo que queda diferido aquí es ver historial clínico/carné propio y gestionar citas desde el lado del dueño
- **SCALE-02**: ~~Multi-usuario / multi-veterinario por clínica~~ — adelantado a v1 como TEAM-01..05 (Fase 4.1, 2026-10-01); queda diferido aquí: rol auxiliar/recepcionista y un veterinario en varias clínicas a la vez
- **SCALE-03**: Telemedicina veterinaria (videollamada de seguimiento)

## Out of Scope

Exclusiones explícitas. Documentadas para prevenir scope creep.

| Feature | Reason |
|---------|--------|
| Agenda multi-recurso (salas, equipos) | Sobre-ingeniería para esta etapa. Nota: varios veterinarios por clínica SÍ entra en v1 (TEAM-*, Fase 4.1, decidido 2026-10-01) |
| App para dueños de mascotas (login propio) | Duplica superficie de producto (segunda app, segundo auth) antes de validar el producto core del veterinario. Distinto del directorio+reseñas (DIR-*/REV-*, Fase 9): eso reutiliza el rol CLIENTE ya existente en la misma app, no crea una app ni un login separado |
| Telemedicina / videollamada | Conflicto directo con el perfil rural/offline objetivo; infraestructura de video no es prioridad |
| DIAN construido in-house (sin proveedor autorizado) | Requiere habilitación legal/técnica compleja; se integra vía proveedor autorizado, nunca se construye desde cero |
| Dosificación por IA sin tabla determinística | Riesgo de seguridad animal y responsabilidad legal — solo con tabla de referencia validada, nunca cálculo libre de LLM |
| Inventario multi-bodega / por lote | Sobre-ingeniería para un veterinario solo; se reevalúa solo si un cliente real lo pide por razones regulatorias |
| Sincronización en tiempo real (estilo Google Docs) | Conflicto directo con el diseño offline-first futuro — no se puede tener sync en vivo y escritura offline-durable con la misma arquitectura simple |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUND-01..06 | Phase 1 — Fundación | Complete |
| CLI-01..05 | Phase 2 — Clientes y Pacientes | Complete |
| PAT-01..05 | Phase 2 — Clientes y Pacientes | Complete |
| HIST-01..04 | Phase 3 — Historia Clínica | Complete |
| AGND-01..06 | Phase 4 — Agenda y Citas | Pending |
| TEAM-01..05 | Phase 4.1 — Equipo de la clínica | Pending |
| VAC-01..05 | Phase 5 — Vacunación y Desparasitación | Pending |
| INV-01..03 | Phase 6 — Inventario | Pending |
| BILL-01..04 | Phase 7 — Facturación | Pending |
| DASH-01..04 | Phase 8 — Dashboard y Diseño Visual | Pending |
| DIR-01..06 | Phase 9 — Directorio de Veterinarias | Pending |
| REV-01..05 | Phase 9 — Directorio de Veterinarias | Pending |

**Coverage:**
- v1 requirements: 58 total (41 originales + 10 de DIR/REV + CLI-05/DIR-06 de vinculación de cuenta, agregadas 2026-09-24 + TEAM-01..05, agregadas 2026-10-01)
- Mapped to phases: 58/58 ✓
- Unmapped: 0 ✓

---
*Requirements defined: 2026-09-24*
*Last updated: 2026-10-01 after adding Phase 4.1 (Equipo de la clínica)*
