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

- [ ] **CLI-01**: El veterinario puede crear un cliente (dueño) con nombre y teléfono, sin que el cliente necesite cuenta
- [ ] **CLI-02**: El veterinario puede ver y editar los datos de un cliente
- [ ] **CLI-03**: El veterinario puede buscar/filtrar clientes por nombre o teléfono
- [ ] **CLI-04**: El veterinario puede ver las mascotas asociadas a un cliente

### Pacientes (PAT)

- [ ] **PAT-01**: El veterinario puede crear una ficha de mascota (especie, raza, edad, peso, foto, dueño asociado)
- [ ] **PAT-02**: El veterinario puede ver y editar la ficha de una mascota
- [ ] **PAT-03**: El veterinario puede subir/cambiar la foto de una mascota (Supabase Storage privado + URL firmada)
- [ ] **PAT-04**: El veterinario puede buscar/filtrar mascotas por nombre, dueño o especie
- [ ] **PAT-05**: Una mascota puede tener más de un peso registrado en el tiempo (historial de peso)

### Historia clínica (HIST)

- [ ] **HIST-01**: El veterinario puede registrar una consulta con campos estructurados (anamnesis, examen físico, diagnóstico, tratamiento, evolución)
- [ ] **HIST-02**: El veterinario puede ver la línea de tiempo de consultas de una mascota
- [ ] **HIST-03**: El veterinario puede exportar la historia clínica de una mascota a PDF
- [ ] **HIST-04**: Los registros de historia clínica son de solo-append (no se editan/borran después de guardados; se corrigen con una entrada nueva)

### Agenda (AGND)

- [ ] **AGND-01**: El veterinario puede ver su agenda en vista de día/semana
- [ ] **AGND-02**: El veterinario puede crear una cita asociada a un cliente y una mascota
- [ ] **AGND-03**: El veterinario puede marcar una cita como confirmada/pendiente/completada
- [ ] **AGND-04**: La app envía un recordatorio local (notificación) antes de una cita próxima
- [ ] **AGND-05**: El veterinario puede enviar un recordatorio de cita por WhatsApp con un toque (deep-link `wa.me` con mensaje prellenado)
- [ ] **AGND-06**: Al completar una cita, se puede crear una entrada de historia clínica vinculada

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

## v2 Requirements

Reconocidos pero diferidos — no forman parte del roadmap actual.

### Diferenciadores avanzados

- **DIFF-01**: Recordatorios automáticos por WhatsApp Business API (sin toque manual del veterinario)
- **DIFF-02**: Facturación electrónica DIAN vía proveedor autorizado (Siigo/Alegra/Factus)
- **DIFF-03**: Notas de voz transcritas automáticamente a historia clínica
- **DIFF-04**: Sugerencias de dosificación asistidas por IA, basadas en tabla determinística (nunca cálculo libre de un LLM)
- **DIFF-05**: Modo offline con sincronización en segundo plano

### Escalamiento

- **SCALE-01**: App complementaria para el dueño de la mascota (ver historial, citas, carné)
- **SCALE-02**: Multi-usuario / multi-veterinario por clínica
- **SCALE-03**: Telemedicina veterinaria (videollamada de seguimiento)

## Out of Scope

Exclusiones explícitas. Documentadas para prevenir scope creep.

| Feature | Reason |
|---------|--------|
| Agenda multi-veterinario/multi-recurso | Contradice la premisa de veterinario independiente sin recepcionista; sobre-ingeniería para esta etapa |
| App para dueños de mascotas (login propio) | Duplica superficie de producto (segunda app, segundo auth) antes de validar el producto core del veterinario |
| Telemedicina / videollamada | Conflicto directo con el perfil rural/offline objetivo; infraestructura de video no es prioridad |
| DIAN construido in-house (sin proveedor autorizado) | Requiere habilitación legal/técnica compleja; se integra vía proveedor autorizado, nunca se construye desde cero |
| Dosificación por IA sin tabla determinística | Riesgo de seguridad animal y responsabilidad legal — solo con tabla de referencia validada, nunca cálculo libre de LLM |
| Inventario multi-bodega / por lote | Sobre-ingeniería para un veterinario solo; se reevalúa solo si un cliente real lo pide por razones regulatorias |
| Sincronización en tiempo real (estilo Google Docs) | Conflicto directo con el diseño offline-first futuro — no se puede tener sync en vivo y escritura offline-durable con la misma arquitectura simple |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUND-01..06 | Phase 1 — Fundación | Complete |
| CLI-01..04 | Phase 2 — Clientes y Pacientes | Pending |
| PAT-01..05 | Phase 2 — Clientes y Pacientes | Pending |
| HIST-01..04 | Phase 3 — Historia Clínica | Pending |
| AGND-01..06 | Phase 4 — Agenda y Citas | Pending |
| VAC-01..05 | Phase 5 — Vacunación y Desparasitación | Pending |
| INV-01..03 | Phase 6 — Inventario | Pending |
| BILL-01..04 | Phase 7 — Facturación | Pending |
| DASH-01..04 | Phase 8 — Dashboard y Diseño Visual | Pending |

**Coverage:**
- v1 requirements: 41 total (corregido; el conteo previo de 37 estaba desactualizado)
- Mapped to phases: 41/41 ✓
- Unmapped: 0 ✓

---
*Requirements defined: 2026-09-24*
*Last updated: 2026-09-24 after roadmap creation (`/gsd:roadmapper`)*
