# Roadmap: VetApp

## Overview

VetApp pasa de ser una app Flutter con UI mockeada a una herramienta real de gestión veterinaria sobre Supabase. El camino empieza asegurando la base (backend en la nube, RLS probado, Riverpod/go_router realmente conectados) porque todo lo demás depende de esa base siendo confiable. Sobre esa fundación se construyen, en orden de dependencia, los registros centrales (clientes y pacientes) de los que dependen la historia clínica, la agenda, la vacunación y la facturación. El inventario se resuelve en paralelo a esas fases porque solo depende de la fundación. Facturación cierra el ciclo operativo (consulta → cobro → descuento de stock). El dashboard y la aplicación final del diseño visual van al final porque agregan datos de todos los módulos anteriores y no pueden mostrarse como "reales" hasta que el resto lo sea.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Fundación** - Proyecto Supabase real, RLS probado y Riverpod/go_router realmente conectados
- [ ] **Phase 2: Clientes y Pacientes** - CRUD real de dueños y mascotas con foto y búsqueda
- [ ] **Phase 3: Historia Clínica** - Registro estructurado, línea de tiempo y exportación a PDF por paciente
- [ ] **Phase 4: Agenda y Citas** - Calendario de citas con recordatorios locales y por WhatsApp
- [ ] **Phase 5: Vacunación y Desparasitación** - Carné digital con cálculo automático de próxima dosis y enlace compartible
- [ ] **Phase 6: Inventario** - Control de stock de medicamentos/insumos con alertas de mínimo
- [ ] **Phase 7: Facturación** - Cotizaciones/facturas en PDF con descuento automático de inventario
- [ ] **Phase 8: Dashboard y Diseño Visual** - Resumen operativo real y diseño terracota/crema aplicado a toda la app

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
**Plans**: TBD
**UI hint**: yes

### Phase 2: Clientes y Pacientes
**Goal**: El veterinario puede gestionar clientes y mascotas reales de principio a fin, sin datos mockeados.
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: CLI-01, CLI-02, CLI-03, CLI-04, PAT-01, PAT-02, PAT-03, PAT-04, PAT-05
**Success Criteria** (what must be TRUE):
  1. El veterinario puede crear un cliente (dueño) con nombre y teléfono, sin que el cliente necesite cuenta
  2. El veterinario puede ver, editar y buscar/filtrar clientes por nombre o teléfono
  3. El veterinario puede ver las mascotas asociadas a un cliente
  4. El veterinario puede crear, ver y editar la ficha de una mascota (especie, raza, edad, peso, foto, dueño)
  5. El veterinario puede subir/cambiar la foto de una mascota (Storage privado + URL firmada), ver el historial de peso en el tiempo, y buscar/filtrar mascotas por nombre, dueño o especie
**Plans**: TBD
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
**Plans**: TBD
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
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Fundación | 0/TBD | Not started | - |
| 2. Clientes y Pacientes | 0/TBD | Not started | - |
| 3. Historia Clínica | 0/TBD | Not started | - |
| 4. Agenda y Citas | 0/TBD | Not started | - |
| 5. Vacunación y Desparasitación | 0/TBD | Not started | - |
| 6. Inventario | 0/TBD | Not started | - |
| 7. Facturación | 0/TBD | Not started | - |
| 8. Dashboard y Diseño Visual | 0/TBD | Not started | - |
