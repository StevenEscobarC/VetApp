# VetApp

## What This Is

App móvil en Flutter para veterinarios independientes y clínicas pequeñas en Colombia que atienden sin recepcionista ni computador fijo (consultorio propio o a domicilio). Permite gestionar pacientes (mascotas), clientes (dueños), historia clínica, agenda, vacunación, inventario y facturación básica desde el celular, con Supabase como backend real y una identidad visual propia (no Material genérico).

## Core Value

El veterinario puede llevar toda su consulta — pacientes, historia clínica, agenda — desde el celular, sin depender de un computador ni de una recepcionista.

## Requirements

### Validated

<!-- Funcionalidad existente y funcionando en el código actual. -->

- ✓ Autenticación por correo/contraseña contra Supabase (registro, login, sesión) — existente en `lib/features/auth`

### Active

<!-- Alcance actual: reconstruir la app mockeada con backend y lógica reales (Fase 1). -->

- [ ] Crear y enlazar un proyecto Supabase real en la nube; aplicar `supabase/schema.sql`; configurar variables de entorno
- [ ] Wiring real de gestión de estado (Riverpod) y navegación (go_router) — hoy están declarados en `pubspec.yaml` pero sin usar
- [ ] Gestión de pacientes (mascotas) con datos reales: crear, ver, editar ficha (especie, raza, edad, peso, foto, dueño asociado)
- [ ] Gestión de clientes (dueños) con datos reales: contacto, mascotas asociadas, historial
- [ ] Historia clínica digital real: registro de consultas (anamnesis, examen físico, diagnóstico, tratamiento, evolución), línea de tiempo por paciente, exportable a PDF
- [ ] Agenda y citas reales con recordatorios
- [ ] Carné de vacunación y desparasitación digital con alertas automáticas de próxima dosis
- [ ] Inventario básico de medicamentos/insumos con alertas de stock mínimo
- [ ] Facturación simple (cotización/recibo en PDF)
- [ ] Reemplazar el dashboard mockeado (`lib/features/home/home_screen.dart`, 1400 líneas estáticas) por uno con datos reales
- [ ] Aplicar el diseño visual definitivo del mockup (paleta terracota/crema, tipografía Caprasimo + Figtree) a todas las pantallas
- [ ] Eliminar código muerto heredado de la migración Firebase→Supabase (dominio de auth duplicado, `firebase.json` huérfano, pantalla de login duplicada)

### Out of Scope

<!-- Fuera de la Fase 1 — siguen siendo parte de la visión (Fase 2/3 del documento original), pero no bloquean "hacerlo real" ahora. -->

- Recordatorios automáticos por WhatsApp — diferenciador de fase 2, no v1
- Facturación electrónica DIAN — requiere integración con proveedor externo autorizado (Siigo/Alegra/Factus), fase 2
- Notas de voz transcritas por IA y sugerencias de diagnóstico/dosificación asistidas por IA — fase 2/3
- App complementaria para el dueño de la mascota, multi-usuario (varios veterinarios en una clínica), telemedicina — fase 3
- Modo offline con sincronización — parte de la visión original (importante en zonas rurales), pero se evalúa después de tener el CRUD online funcionando end-to-end sobre datos reales

## Context

- Proyecto brownfield: el código Flutter ya existe pero la mayoría es UI mockeada sin lógica real (ver `.planning/codebase/CONCERNS.md`). Solo el módulo de auth está implementado end-to-end; el resto de módulos (pacientes, clientes, agenda, vacunación, inventario, facturación, dashboard) son pantallas estáticas o carpetas de dominio vacías.
- Backend ya decidido: Supabase (Postgres + RLS), no Firebase — el schema ya está definido en `supabase/schema.sql`, pero aún no existe un proyecto en la nube creado ni enlazado. El usuario todavía no tiene cuenta en supabase.com; crearla es la primera tarea técnica de la Fase 1.
- Mercado: los competidores colombianos (Vetlogy, GVET, Panacea) e internacionales (Digitail, IDEXX Neo) están pensados para clínicas con recepción y computador fijo. El hueco identificado es mobile-first para el veterinario que atiende solo o a domicilio.
- Diseño visual definitivo ya aportado por el usuario: mockup de 9 pantallas (login, dashboard/inicio, pacientes, ficha de paciente con historia clínica, clientes, agenda, carné de vacunación, inventario, facturación). Paleta cálida terracota/crema, tipografía Caprasimo (headings) + Figtree (cuerpo), bottom nav de 5 secciones. Ver `.planning/design/DESIGN-REFERENCE.md` y `.planning/design/vetapp-mobile-designs.html`.
- Contexto Colombia: moneda COP, formato de fecha dd/mm/aaaa, biológicos de vacunación comunes (antirrábica, óctuple/polivalente), estructura de historia clínica al estilo veterinario local.
- Documento fuente original de la visión del producto: `prompt-app-veterinaria-colombia.md` (en la raíz del repo) — el usuario confirmó que sigue vigente sin cambios.

## Constraints

- **Tech stack**: Flutter + Supabase (Postgres/RLS) — decisión ya tomada, no se reevalúa en v1.
- **Diseño**: debe seguir el mockup ya aprobado por el usuario (paleta terracota/crema, Caprasimo + Figtree) — no usar Material 3 genérico ni paleta "sobria" del prompt original.
- **Backend real, no mocks**: cada módulo de la Fase 1 debe conectar a Supabase real; no se sigue construyendo sobre datos falsos.
- **Mercado objetivo**: Colombia — moneda COP, formato de fecha dd/mm/aaaa.
- **Cuenta Supabase pendiente**: el usuario aún no tiene cuenta creada en supabase.com; es un bloqueante para conectar el backend real y debe resolverse al inicio de la Fase 1.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Backend: Supabase (no Firebase) | Ya implementado en el módulo de auth y en `schema.sql` (Postgres/RLS); `firebase.json` es un vestigio sin uso de un intento anterior | ✓ Good |
| Fase 1 = reconstruir con datos reales, no seguir agregando mocks | El usuario pidió explícitamente "lo más real que se pueda" | — Pending |
| Diseño visual: mockup terracota/crema + Caprasimo/Figtree es la dirección definitiva | El usuario confirmó que es el diseño final, abierto a sugerencias puntuales | — Pending |
| Modo offline se evalúa después del CRUD online real | La visión original lo pedía desde el inicio, pero el estado actual (todo mockeado) hace prioritario un backend real funcionando primero | — Pending |

## Evolution

Este documento evoluciona en las transiciones de fase y en los límites de milestone.

**Después de cada transición de fase** (vía `/gsd-transition`):
1. ¿Requisitos invalidados? → Mover a Out of Scope con la razón
2. ¿Requisitos validados? → Mover a Validated con referencia de fase
3. ¿Nuevos requisitos emergieron? → Agregar a Active
4. ¿Decisiones que registrar? → Agregar a Key Decisions
5. ¿"What This Is" sigue siendo preciso? → Actualizar si hay desviación

**Después de cada milestone** (vía `/gsd:complete-milestone`):
1. Revisión completa de todas las secciones
2. Chequeo de Core Value — ¿sigue siendo la prioridad correcta?
3. Auditar Out of Scope — ¿las razones siguen siendo válidas?
4. Actualizar Context con el estado actual

---
*Last updated: 2026-09-24 after initialization*
