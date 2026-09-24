# VetApp

## What This Is

App móvil en Flutter para veterinarios independientes y clínicas pequeñas en Colombia que atienden sin recepcionista ni computador fijo (consultorio propio o a domicilio). Permite gestionar pacientes (mascotas), clientes (dueños), historia clínica, agenda, vacunación, inventario y facturación básica desde el celular, con Supabase como backend real y una identidad visual propia (no Material genérico).

## Core Value

El veterinario puede llevar toda su consulta — pacientes, historia clínica, agenda — desde el celular, sin depender de un computador ni de una recepcionista.

## Requirements

### Validated

<!-- Funcionalidad existente y funcionando en el código actual. -->

- ✓ Autenticación por correo/contraseña contra Supabase (registro, login, sesión) — existente en `lib/features/auth`
- ✓ Proyecto Supabase real en la nube, enlazado y con `schema.sql` aplicado (incluye tabla `clientes` independiente de `perfiles` y RLS multi-tenant probado contra el rol `authenticated`, con el fix de auto-escalación de privilegios) — Fase 1
- ✓ Wiring real de estado (Riverpod `AsyncNotifier`) y navegación (`go_router`, 5 secciones del bottom nav) reemplazando `setState`/`Navigator` manual — Fase 1
- ✓ Código muerto de la migración Firebase→Supabase eliminado (dominio de auth duplicado, `firebase.json`, `google-services.json`, `LoginScreen` duplicado, dashboard mock de 1400 líneas) — Fase 1

### Active

<!-- Alcance actual: reconstruir la app mockeada con backend y lógica reales, módulo por módulo. -->

- [ ] Gestión de pacientes (mascotas) con datos reales: crear, ver, editar ficha (especie, raza, edad, peso, foto, dueño asociado)
- [ ] Gestión de clientes (dueños) con datos reales: contacto, mascotas asociadas, historial
- [ ] Historia clínica digital real: registro de consultas (anamnesis, examen físico, diagnóstico, tratamiento, evolución), línea de tiempo por paciente, exportable a PDF
- [ ] Agenda y citas reales con recordatorios
- [ ] Carné de vacunación y desparasitación digital con alertas automáticas de próxima dosis
- [ ] Inventario básico de medicamentos/insumos con alertas de stock mínimo
- [ ] Facturación simple (cotización/recibo en PDF)
- [ ] Reemplazar el dashboard mockeado por uno con datos reales completos (métricas, próximas citas, accesos rápidos — el saludo con nombre/clínica reales ya quedó resuelto en Fase 1; falta el resto, Fase 8)
- [ ] Aplicar el diseño visual definitivo del mockup (paleta terracota/crema, tipografía Caprasimo + Figtree) al resto de pantallas (Login e Inicio ya lo tienen desde Fase 1; faltan pacientes/clientes/agenda/vacunación/inventario/facturación)

### Out of Scope

<!-- Fuera de la Fase 1 — siguen siendo parte de la visión (Fase 2/3 del documento original), pero no bloquean "hacerlo real" ahora. -->

- Recordatorios automáticos por WhatsApp — diferenciador de fase 2, no v1
- Facturación electrónica DIAN — requiere integración con proveedor externo autorizado (Siigo/Alegra/Factus), fase 2
- Notas de voz transcritas por IA y sugerencias de diagnóstico/dosificación asistidas por IA — fase 2/3
- App complementaria para el dueño de la mascota, multi-usuario (varios veterinarios en una clínica), telemedicina — fase 3
- Modo offline con sincronización — parte de la visión original (importante en zonas rurales), pero se evalúa después de tener el CRUD online funcionando end-to-end sobre datos reales

## Context

- **Fase 1 (Fundación) completa y verificada (2026-09-24).** El proyecto ya no es brownfield-sin-backend: Supabase real está en producción (`apjonrmhkpyzbofupokb.supabase.co`), RLS multi-tenant probado (27/27 checks, incluyendo el ataque de auto-escalación de privilegios), y la app tiene un walking skeleton real (Riverpod + go_router + Inicio con datos reales) verificado en un dispositivo Android real. El resto de módulos (pacientes, clientes, agenda, vacunación, inventario, facturación, dashboard completo) siguen siendo pantallas placeholder ("Próximamente") o carpetas de dominio vacías — eso es el trabajo de las Fases 2-8.
- Backend decidido y en producción: Supabase (Postgres + RLS), no Firebase — `schema.sql` aplicado al proyecto real, cuenta de Supabase del usuario ya creada.
- Mercado: los competidores colombianos (Vetlogy, GVET, Panacea) e internacionales (Digitail, IDEXX Neo) están pensados para clínicas con recepción y computador fijo. El hueco identificado es mobile-first para el veterinario que atiende solo o a domicilio.
- Diseño visual definitivo ya aportado por el usuario: mockup de 9 pantallas (login, dashboard/inicio, pacientes, ficha de paciente con historia clínica, clientes, agenda, carné de vacunación, inventario, facturación). Paleta cálida terracota/crema, tipografía Caprasimo (headings) + Figtree (cuerpo), bottom nav de 5 secciones. Ver `.planning/design/DESIGN-REFERENCE.md` y `.planning/design/vetapp-mobile-designs.html`.
- Contexto Colombia: moneda COP, formato de fecha dd/mm/aaaa, biológicos de vacunación comunes (antirrábica, óctuple/polivalente), estructura de historia clínica al estilo veterinario local.
- Documento fuente original de la visión del producto: `prompt-app-veterinaria-colombia.md` (en la raíz del repo) — el usuario confirmó que sigue vigente sin cambios.

## Constraints

- **Tech stack**: Flutter + Supabase (Postgres/RLS) — decisión ya tomada, no se reevalúa en v1.
- **Diseño**: debe seguir el mockup ya aprobado por el usuario (paleta terracota/crema, Caprasimo + Figtree) — no usar Material 3 genérico ni paleta "sobria" del prompt original.
- **Backend real, no mocks**: cada módulo de la Fase 1 debe conectar a Supabase real; no se sigue construyendo sobre datos falsos.
- **Mercado objetivo**: Colombia — moneda COP, formato de fecha dd/mm/aaaa.
- **Cuenta Supabase**: creada y proyecto en producción desde Fase 1 (`apjonrmhkpyzbofupokb.supabase.co`) — ya no es un bloqueante.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Backend: Supabase (no Firebase) | Ya implementado en el módulo de auth y en `schema.sql` (Postgres/RLS); `firebase.json` es un vestigio sin uso de un intento anterior | ✓ Good — confirmado en producción, Fase 1 |
| Fase 1 = reconstruir con datos reales, no seguir agregando mocks | El usuario pidió explícitamente "lo más real que se pueda" | ✓ Good — walking skeleton verificado en dispositivo real contra el backend real |
| Tabla `clientes` independiente de `perfiles` (no requiere autenticación del dueño) | Recomendación de `.planning/research/ARCHITECTURE.md`, confirmada en discuss-phase de Fase 1 | ✓ Good — implementada y probada con RLS vet-only |
| Diseño visual: mockup terracota/crema + Caprasimo/Figtree es la dirección definitiva | El usuario confirmó que es el diseño final, abierto a sugerencias puntuales | ✓ Good — aplicado a Login/Inicio en Fase 1, sin objeciones tras verificación |
| Modo offline se evalúa después del CRUD online real | La visión original lo pedía desde el inicio, pero el estado actual (todo mockeado) hace prioritario un backend real funcionando primero | — Pending (aún no se ha evaluado; el CRUD online real recién empieza en Fase 2) |

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
*Last updated: 2026-09-24 after Phase 1 (Fundación) completion*
