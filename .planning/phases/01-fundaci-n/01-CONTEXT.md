# Phase 1: Fundación - Context

**Gathered:** 2026-09-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Esta fase establece la base técnica real sobre la que se construyen las 7 fases siguientes: un backend Supabase real (no local/mock) con `schema.sql` aplicado y RLS endurecido, más el wiring real de Riverpod (estado) y go_router (navegación) reemplazando `setState`/`Navigator` manual. Como es la Fase 1 de un proyecto nuevo en modo MVP, se entrega además un **Walking Skeleton**: la prueba end-to-end más delgada posible de que todo el stack (Supabase real + Riverpod + go_router + diseño visual) funciona junto.

No incluye: construir los módulos de negocio (pacientes, clientes, historia clínica, etc. — eso es Fase 2+). No incluye: modo offline (diferido). No incluye: WhatsApp/DIAN/IA (fuera de alcance v1).

</domain>

<decisions>
## Implementation Decisions

### Alcance del Walking Skeleton
- **D-01:** El Walking Skeleton debe mostrar un **Dashboard real mínimo**: la pantalla de Inicio consulta datos reales de Supabase (nombre del veterinario autenticado, nombre de su clínica) a través de un provider Riverpod, navegado con go_router, y usando el diseño visual ya aprobado (paleta terracota/crema, Caprasimo/Figtree) — no una pantalla técnica genérica ni el mock estático actual de `home_screen.dart`.
- **D-02:** Esto reemplaza únicamente la parte "resumen/saludo" del dashboard mockeado (los datos reales del veterinario/clínica); las tarjetas de métricas de negocio (consultas, ingresos, próximas citas) siguen siendo responsabilidad de fases posteriores (Fase 8) porque dependen de datos que aún no existen.

### Rigor de pruebas RLS
- **D-03:** Para esta fase, corregir el bug de auto-escalación de privilegios en `perfiles` (restringir columnas actualizables vía `WITH CHECK`) y validar con **pruebas manuales** contra el rol `authenticated` (positivas: la clínica A ve sus datos; negativas: la clínica A no ve datos de la clínica B). No se requiere una suite automatizada (pgTAP/CI) en esta fase — se prioriza avanzar rápido sobre cobertura exhaustiva.
- **D-04:** Las políticas de `clinicas`, `perfiles`, `mascotas` (y la nueva tabla `clientes`) deben quedar todas cubiertas por este smoke test manual antes de cerrar la fase.

### Registro de veterinarios
- **D-05:** El auto-registro abierto de cuentas `VETERINARIO` (sin aprobación manual) se mantiene como está — es aceptable para uso personal/beta en esta etapa. No se agrega ningún flujo de aprobación en esta fase. Revisar si el producto escala a más usuarios.

### Modelo de clientes (ya decidido en REQUIREMENTS.md/ROADMAP.md — FOUND-04)
- **D-06:** Se crea una tabla `clientes` nueva, independiente de `perfiles`, propiedad de `clinica_id`, para que el veterinario pueda registrar dueños de mascotas sin que necesiten autenticarse. `mascotas.dueno_id` (o el campo equivalente que hoy apunte a `perfiles`) debe apuntar a esta nueva tabla `clientes` en vez de a `perfiles`. Esta decisión ya fue tomada en la fase de requisitos (recomendación de `.planning/research/ARCHITECTURE.md`); aquí solo se confirma el alcance de implementación — el diseño exacto de columnas queda a criterio del research/planner de esta fase.

### Claude's Discretion
- Diseño exacto de columnas de la tabla `clientes` (más allá de que exista y esté desacoplada de `perfiles`).
- Estructura exacta de los providers Riverpod (`Notifier` vs `AsyncNotifier`) y de las rutas go_router — seguir el patrón ya documentado en `.planning/research/ARCHITECTURE.md`.
- Orden exacto de tareas dentro de la fase (schema → RLS → wiring → skeleton UI).
- Mecánica exacta de limpieza del código muerto Firebase (un commit vs. varios).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Investigación de dominio (Fase 1)
- `.planning/research/SUMMARY.md` — síntesis general, roadmap con rationale, confianza por área
- `.planning/research/ARCHITECTURE.md` — patrón Riverpod/go_router recomendado, decisión de tabla `clientes`, capas y orden de construcción
- `.planning/research/PITFALLS.md` — riesgo de auto-escalación de privilegios en RLS, fragilidad del trigger de signup, entidades vs. schema
- `.planning/research/STACK.md` — versiones de paquetes recomendadas (go_router ^17.3.0, sin bump a 18.x; Riverpod manual sin codegen)

### Estado actual del código
- `.planning/codebase/ARCHITECTURE.md` — arquitectura actual (solo auth wireado, resto mockeado)
- `.planning/codebase/STRUCTURE.md` — estructura de carpetas actual
- `.planning/codebase/CONCERNS.md` — deuda técnica detallada (dashboard mock de 1400 líneas, código Firebase muerto, etc.)
- `supabase/schema.sql` — schema actual, fuente de verdad a modificar (no reinventar los nombres/convenciones ya usados: español, `snake_case`)

### Diseño visual
- `.planning/design/DESIGN-REFERENCE.md` — paleta, tipografía (Caprasimo/Figtree), patrones de componentes — aplica al Dashboard real mínimo del walking skeleton

### Proyecto
- `.planning/PROJECT.md` — contexto y constraints generales
- `.planning/REQUIREMENTS.md` — FOUND-01 a FOUND-06 (requisitos exactos de esta fase)
- `.planning/ROADMAP.md` — Fase 1: objetivo y criterios de éxito

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/core/theme/app_theme.dart`, `app_colors.dart`, `app_typography.dart`, `app_spacing.dart`: tokens de diseño ya existentes — deben actualizarse/extenderse para reflejar la paleta terracota/crema del mockup aprobado (`DESIGN-REFERENCE.md`), no crearse desde cero.
- `lib/core/widgets/**` (`AppButton`, `AppCard`, `AppTextField`, `AppStatusChip`, `AppTopBar`): widgets reutilizables ya existentes, usar en el dashboard real mínimo.
- `lib/features/auth/data/repositories/supabase_auth_repository.dart`: patrón de manejo de errores (`try/on AuthException/catch` → `AuthFailure` con mensaje en español) a replicar en nuevos repositorios.
- `lib/features/auth/presentation/auth_screens.dart` (`AuthGate`): lógica de sesión/perfil a migrar hacia go_router `redirect:` + Riverpod, no descartar la lógica, sí su mecanismo (`Navigator`/`setState` manual).

### Established Patterns
- Convención de nombres: dominio en español (`Mascota`, `Cliente`, `Cita`), plomería en inglés (`onPressed`, `isLoading`) — mantener en todo código nuevo.
- Manejo de errores en dos niveles: excepción de dominio específica (`AuthFailure`-style) + traducción de errores del SDK a mensajes en español — replicar para nuevos repositorios (`ClienteRepository`, etc. en fases posteriores, pero el patrón se establece aquí).

### Integration Points
- `lib/main.dart`: punto de entrada actual con `MaterialApp` + `home: AuthGate()` — se reemplaza por `MaterialApp.router` con el `GoRouter` construido vía Riverpod `Provider`.
- `lib/core/router/` (vacío hoy): destino del nuevo `app_router.dart`.
- `lib/core/data/` (vacío hoy): destino del nuevo `supabase_client_provider.dart`.

</code_context>

<specifics>
## Specific Ideas

- El "walking skeleton" debe sentirse como progreso real y visible: el veterinario inicia sesión y ve su propio nombre/clínica reales en la pantalla de Inicio con el diseño terracota/crema — no una pantalla de prueba técnica.
- Prioridad explícita del usuario: avanzar rápido sobre exhaustividad en pruebas RLS por ahora (fix + smoke test manual, no suite automatizada).
- Auto-registro de veterinarios se mantiene abierto sin aprobación manual por ahora.

</specifics>

<deferred>
## Deferred Ideas

None — la discusión se mantuvo dentro del alcance de la fase.

### Reviewed Todos (not folded)
None — no había todos pendientes que revisar para esta fase.

</deferred>

---

*Phase: 1-Fundación*
*Context gathered: 2026-09-24*
