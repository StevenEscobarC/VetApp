# Roadmap: VetApp

## Overview

VetApp pasa de ser una app Flutter con UI mockeada a una herramienta real de gestión veterinaria sobre Supabase. El camino empieza asegurando la base (backend en la nube, RLS probado, Riverpod/go_router realmente conectados) porque todo lo demás depende de esa base siendo confiable. Sobre esa fundación se construyen, en orden de dependencia, los registros centrales (clientes y pacientes) de los que dependen la historia clínica, la agenda, la vacunación y la facturación. El inventario se resuelve en paralelo a esas fases porque solo depende de la fundación. Facturación cierra el ciclo operativo (consulta → cobro → descuento de stock). El dashboard y la aplicación final del diseño visual van al final porque agregan datos de todos los módulos anteriores y no pueden mostrarse como "reales" hasta que el resto lo sea.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Fundación** - Proyecto Supabase real, RLS probado y Riverpod/go_router realmente conectados (completed 2026-09-24)
- [x] **Phase 2: Clientes y Pacientes** - CRUD real de dueños y mascotas con foto y búsqueda (completed 2026-09-26)
- [ ] **Phase 3: Historia Clínica** - Registro estructurado, línea de tiempo y exportación a PDF por paciente
- [ ] **Phase 4: Agenda y Citas** - Calendario de citas con recordatorios locales y por WhatsApp
- [ ] **Phase 5: Vacunación y Desparasitación** - Carné digital con cálculo automático de próxima dosis y enlace compartible
- [ ] **Phase 6: Inventario** - Control de stock de medicamentos/insumos con alertas de mínimo
- [ ] **Phase 7: Facturación** - Cotizaciones/facturas en PDF con descuento automático de inventario
- [ ] **Phase 8: Dashboard y Diseño Visual** - Resumen operativo real y diseño terracota/crema aplicado a toda la app
- [ ] **Phase 9: Directorio de Veterinarias** - El cliente explora, busca y califica las clínicas de la plataforma, con reseñas públicas

## Phase Details

### Phase 1: Fundación

**Goal**: Existe un backend Supabase real y confiable (RLS probado contra el rol `authenticated`) y la app usa Riverpod/go_router de verdad para estado y navegación, en vez de mocks y `setState`/`Navigator` directos.
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: FOUND-01, FOUND-02, FOUND-03, FOUND-04, FOUND-05, FOUND-06
**Success Criteria** (what must be TRUE):

  1. La app se conecta a un proyecto Supabase real en la nube (no mock/local) con `schema.sql` aplicado
  2. La navegación de la app usa `go_router` con las 5 secciones del bottom nav, y las pantallas de datos manejan su estado con Riverpod (`Notifier`/`AsyncNotifier`), sin `setState` directo
  3. El veterinario puede crear un cliente en una tabla `clientes` independiente de `perfiles`, sin que el cliente necesite autenticarse
  4. Las políticas RLS de `clinicas`, `perfiles` y `mascotas` bloquean el acceso entre clínicas cuando se prueban como rol `authenticated` (no solo service-role), y `perfiles` no permite auto-escalación de privilegios
  5. No queda código muerto de la migración Firebase→Supabase (`firebase.json`, `google-services.json`, dominio de auth duplicado, `LoginScreen` duplicado)

**Plans**: 6 plans

Plans:
**Wave 1**

- [x] 01-01-PLAN.md — Harden schema.sql (clientes, mascotas->clientes, perfiles_update fix), RLS smoke test, apply to cloud project (BLOCKING human step)
- [x] 01-02-PLAN.md — Walking skeleton core: Riverpod auth AsyncNotifier, go_router 5-tab shell, real Inicio (test-first)
- [x] 01-03-PLAN.md — Terracota/crema palette + Caprasimo/Figtree typography tokens
- [x] 01-04-PLAN.md — Remove Firebase config/Gradle plugin and dead auth domain layer

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 01-05-PLAN.md — Auth screens on Riverpod/go_router with brand block; delete AuthGate + mock home

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 01-06-PLAN.md — README + full gate + human-verified skeleton run on a real device

**UI hint**: yes

### Phase 2: Clientes y Pacientes

**Goal**: El veterinario puede gestionar clientes y mascotas reales de principio a fin, sin datos mockeados.
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: CLI-01, CLI-02, CLI-03, CLI-04, CLI-05, PAT-01, PAT-02, PAT-03, PAT-04, PAT-05
**Success Criteria** (what must be TRUE):

  1. El veterinario puede crear un cliente (dueño) con nombre y teléfono, sin que el cliente necesite cuenta
  2. El veterinario puede ver, editar y buscar/filtrar clientes por nombre o teléfono
  3. El veterinario puede ver las mascotas asociadas a un cliente
  4. El veterinario puede crear, ver y editar la ficha de una mascota (especie, raza, edad, peso, foto, dueño)
  5. El veterinario puede subir/cambiar la foto de una mascota (Storage privado + URL firmada), ver el historial de peso en el tiempo, y buscar/filtrar mascotas por nombre, dueño o especie
  6. El veterinario puede generar un código/enlace de vinculación desde la ficha del cliente para que el dueño reclame acceso a sus mascotas cuando cree su cuenta (habilita DIR-06 en Fase 9)

**Plans**: 10 plans

Plans:
**Wave 1**

- [x] 02-01-PLAN.md — Schema delta (foto_path, mascota_pesos, link-code columns, 3 security-invoker RPCs, private mascota-fotos bucket + Storage RLS), 53-check RLS smoke test, apply to cloud project (BLOCKING human step)
- [x] 02-02-PLAN.md — Photo packages legitimacy gate (BLOCKING human step) + install (cached_network_image ^3.4.1) + Android/iOS camera permissions
- [x] 02-03-PLAN.md — Slice: Clientes list with instant debounced search (CLI-03)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 02-04-PLAN.md — Slice: combined alta cliente+mascota in one screen via atomic RPC (CLI-01, PAT-01)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 02-05-PLAN.md — Slice: camera-first pet photo in the alta, private Storage + cacheKey rule (PAT-03)
- [x] 02-06-PLAN.md — Slice: Pacientes list with two-step search by nombre/dueño/especie + species chips (PAT-04)
- [x] 02-07-PLAN.md — Slice: client ficha — edit, their pets, 'Vincular cuenta' 6-digit code (CLI-02, CLI-04, CLI-05)

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 02-08-PLAN.md — Slice: pet ficha — data, append-only weight history, photo replacement, list thumbnails/navigation (PAT-02, PAT-03, PAT-05)

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 02-09-PLAN.md — Slice: 'Nueva mascota' for existing owner (D-03) + pet edit form (PAT-01, PAT-02)

**Wave 6** *(blocked on Wave 5 completion)*

- [x] 02-10-PLAN.md — README + full gate + validation sign-off + human-verified device UAT against the live backend
**UI hint**: yes

### Phase 3: Historia Clínica

**Goal**: El veterinario puede llevar una historia clínica digital estructurada, trazable y exportable por paciente.
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: HIST-01, HIST-02, HIST-03, HIST-04
**Success Criteria** (what must be TRUE):

  1. El veterinario puede registrar una consulta con campos estructurados (anamnesis, examen físico, diagnóstico, tratamiento, evolución)
  2. El veterinario puede ver la línea de tiempo de consultas de una mascota
  3. El veterinario puede exportar la historia clínica de una mascota a PDF
  4. Las entradas de historia clínica guardadas no se pueden editar ni borrar — las correcciones se hacen con una entrada nueva

**Plans**: 6 plans

Plans:
**Wave 1**

- [ ] 03-01-PLAN.md — Schema delta (append-only consultas + RLS, atomic registrar_consulta RPC feeding mascota_pesos), 70-check RLS smoke test, apply to cloud project (BLOCKING human step)
- [x] 03-02-PLAN.md — PDF packages legitimacy gate (BLOCKING human step) + install exact pins pdf 3.12.0 / printing 5.14.3
- [x] 03-03-PLAN.md — Slice: 'Nueva consulta' from the pet ficha — reconciled Consulta entity, repository/RPC, 2-required-field form, weight feeds weight history (HIST-01, HIST-04, D-02, D-03)

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 03-04-PLAN.md — Slice: clinical timeline inline in the pet ficha, newest first, expandable, no edit/delete (HIST-02, HIST-04)

**Wave 3** *(blocked on Wave 2 completion)*

- [ ] 03-05-PLAN.md — Slice: export the whole history to PDF via the native share sheet (HIST-03, D-04, D-05)

**Wave 4** *(blocked on Wave 3 completion)*

- [ ] 03-06-PLAN.md — README + full gate + HIST-04 structural check + validation sign-off + human-verified device UAT against the live backend
**UI hint**: yes

### Phase 4: Agenda y Citas

**Goal**: El veterinario puede gestionar su agenda de citas y avisar a sus clientes, sin depender de una recepcionista.
**Mode:** mvp
**Depends on**: Phase 2, Phase 3
**Requirements**: AGND-01, AGND-02, AGND-03, AGND-04, AGND-05, AGND-06
**Success Criteria** (what must be TRUE):

  1. El veterinario puede ver su agenda en vista de día/semana
  2. El veterinario puede crear una cita asociada a un cliente y una mascota
  3. El veterinario puede marcar una cita como confirmada/pendiente/completada
  4. El veterinario recibe un recordatorio local (notificación) antes de una cita próxima
  5. El veterinario puede enviar un recordatorio de cita por WhatsApp con un toque (deep-link `wa.me` con mensaje prellenado)
  6. Al completar una cita, el veterinario puede crear una entrada de historia clínica vinculada

**Plans**: TBD
**UI hint**: yes

### Phase 5: Vacunación y Desparasitación

**Goal**: El veterinario puede llevar el carné de vacunación/desparasitación de cada mascota con alertas automáticas, y compartirlo sin exponer la historia clínica completa.
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: VAC-01, VAC-02, VAC-03, VAC-04, VAC-05
**Success Criteria** (what must be TRUE):

  1. El veterinario puede registrar una vacuna/desparasitación aplicada a una mascota (biológico, fecha aplicada)
  2. La próxima fecha de dosis se calcula automáticamente según el protocolo del biológico (no es un campo editable a mano)
  3. El veterinario recibe una alerta cuando una mascota tiene una dosis próxima o vencida
  4. El veterinario puede generar un link público de solo lectura con el carné de vacunación de una mascota, sin exponer la historia clínica completa
  5. El dueño puede ver el carné de vacunación compartido sin necesidad de cuenta

**Plans**: TBD
**UI hint**: yes

### Phase 6: Inventario

**Goal**: El veterinario puede controlar el stock de medicamentos/insumos y anticipar cuándo reabastecer.
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: INV-01, INV-02, INV-03
**Success Criteria** (what must be TRUE):

  1. El veterinario puede registrar un producto/insumo con nombre, cantidad y umbral de stock mínimo
  2. El veterinario recibe una alerta cuando un producto cae por debajo del umbral de stock mínimo
  3. El veterinario puede ajustar manualmente la cantidad de un producto

**Plans**: TBD
**UI hint**: yes

### Phase 7: Facturación

**Goal**: El veterinario puede cobrar sus consultas y productos con una cotización/factura simple, y el inventario se actualiza solo.
**Mode:** mvp
**Depends on**: Phase 2, Phase 6
**Requirements**: BILL-01, BILL-02, BILL-03, BILL-04
**Success Criteria** (what must be TRUE):

  1. El veterinario puede generar una cotización o factura simple en PDF para un cliente
  2. Una factura puede incluir uno o más ítems (servicios/productos) con precio
  3. Al facturar un producto de inventario, el stock se descuenta automáticamente
  4. El veterinario puede marcar una factura como pagada/pendiente

**Plans**: TBD
**UI hint**: yes

### Phase 8: Dashboard y Diseño Visual

**Goal**: El veterinario ve un resumen operativo real al iniciar sesión, y toda la app refleja el diseño visual definitivo aprobado (terracota/crema, Caprasimo + Figtree), sin restos del dashboard mockeado.
**Mode:** mvp
**Depends on**: Phase 2, Phase 3, Phase 4, Phase 6, Phase 7 (agrega datos de todos los módulos anteriores; el diseño toca además la Phase 5)
**Requirements**: DASH-01, DASH-02, DASH-03, DASH-04
**Success Criteria** (what must be TRUE):

  1. El veterinario ve un resumen real al iniciar sesión (consultas del mes, ingresos del mes, pacientes nuevos), reemplazando el dashboard mockeado de 1400 líneas
  2. El veterinario ve sus próximas citas desde el dashboard
  3. El veterinario tiene accesos rápidos para crear paciente, cita o factura desde el dashboard
  4. Todas las pantallas de la app usan el diseño visual definitivo (paleta terracota/crema, tipografía Caprasimo + Figtree) del mockup aprobado

**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Fundación | 6/6 | Complete    | 2026-09-24 |
| 2. Clientes y Pacientes | 10/10 | Complete   | 2026-09-26 |
| 3. Historia Clínica | 0/TBD | Not started | - |
| 4. Agenda y Citas | 0/TBD | Not started | - |
| 5. Vacunación y Desparasitación | 0/TBD | Not started | - |
| 6. Inventario | 0/TBD | Not started | - |
| 7. Facturación | 0/TBD | Not started | - |
| 8. Dashboard y Diseño Visual | 0/TBD | Not started | - |
| 9. Directorio de Veterinarias | 0/TBD | Not started | - |

### Phase 9: Directorio de Veterinarias

**Goal:** El cliente ya no está atado a una sola clínica: puede explorar, buscar y calificar las veterinarias de la plataforma, con reseñas públicas y un punto de entrada a agendar cita.
**Mode:** mvp
**Depends on:** Phase 2 (registro de cliente ya desacoplado de clínica; genera el código de vinculación que aquí se reclama), Phase 4 (Agenda — el botón "Agendar cita" enlaza ahí)
**Requirements**: DIR-01, DIR-02, DIR-03, DIR-04, DIR-05, DIR-06, REV-01, REV-02, REV-03, REV-04, REV-05
**Success Criteria** (what must be TRUE):
  1. El cliente puede ver el listado de clínicas activas (nombre, ciudad, dirección, foto/logo si existe, calificación promedio) sin tener que pertenecer a ninguna
  2. El cliente puede buscar veterinarias por nombre o ciudad con resultados instantáneos, y filtrar por ciudad
  3. El cliente puede ver el detalle de una veterinaria (contacto, horario si existe, calificación promedio, reseñas recientes) y desde ahí iniciar "Agendar cita"
  4. El cliente puede dejar una reseña (estrellas + comentario opcional) de una clínica; si ya la calificó, volver a calificar edita su reseña en vez de duplicarla
  5. Cualquier persona autenticada puede leer las reseñas públicas de una clínica, pero solo el autor puede editar/borrar la suya, y la calificación promedio mostrada coincide con el promedio real
  6. El cliente puede vincular su cuenta a un registro de cliente existente usando el código/enlace generado por el veterinario (Fase 2), y a partir de ahí ve en "Mis mascotas" las mascotas que el veterinario ya le había registrado
**Plans**: TBD
**UI hint**: yes

**Nota de alcance:** agregada el 2026-09-24 a partir de una propuesta del usuario. Deliberadamente al final del roadmap porque depende de Agenda (Fase 4) para el flujo "Agendar cita", y porque la regla de negocio "solo puede reseñar quien tuvo una cita real" (aún no exigible sin Agenda) debe revisarse una vez ese módulo exista — por ahora las reseñas quedan abiertas a cualquier cliente registrado, con esa restricción futura documentada en el research/plan de esta fase.
