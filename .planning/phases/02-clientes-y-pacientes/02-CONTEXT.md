# Phase 2: Clientes y Pacientes - Context

**Gathered:** 2026-09-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Esta fase entrega CRUD real (Supabase, no mock) de dos entidades centrales: **clientes** (dueños de mascotas, gestionados por el veterinario, sin necesitar cuenta propia — tabla `clientes` ya creada en Fase 1) y **pacientes** (mascotas). Incluye: crear/ver/editar cliente, crear/ver/editar ficha de mascota (especie, raza, edad, peso, foto, dueño), subir foto vía Supabase Storage privado, historial de peso en el tiempo, y búsqueda/filtro de ambos.

No incluye: historia clínica (Fase 3), agenda (Fase 4), vacunación (Fase 5), inventario/facturación (Fases 6-7), dashboard con métricas (Fase 8).

</domain>

<decisions>
## Implementation Decisions

### Principio rector: fricción cero
- **D-01:** La ventaja competitiva de VetApp no es una función aislada sino que TODA acción se sienta rápida, fácil e intuitiva — para que al veterinario (y eventualmente al dueño) no le dé pereza usarla. Este principio ya quedó registrado en `PROJECT.md` como guía transversal para todas las fases futuras, no solo esta.

### Flujo de alta
- **D-02:** Cuando llega un cliente nuevo con su mascota, el flujo es **combinado y continuo**: datos del dueño → datos de la mascota, en la misma secuencia, sin navegar a otra pantalla ni tener que "guardar y volver a entrar". Esto es el caso más común (cliente nuevo) y debe ser el camino principal.
- **D-03:** Cuando el cliente **ya existe** y trae otra mascota (ej. ya tenía a "Rocky" y ahora trae a "Luna"), el flujo es: buscar al dueño ya registrado (aparece al instante mientras escribe) → tocar "Nueva mascota" desde su ficha → no se repiten los datos del dueño.
- **D-04:** Campos obligatorios al crear son el **mínimo absoluto**: cliente = nombre + teléfono; mascota = nombre + especie. Todo lo demás (raza, edad, peso, dirección del cliente, etc.) es opcional al crear y se puede completar después editando la ficha. No bloquear el alta pidiendo datos que no son esenciales en el momento.

### Foto de mascota
- **D-05:** La acción principal al tocar "agregar foto" es **abrir la cámara directamente** (un toque, sin menú intermedio) — el veterinario le toma la foto ahí mismo en el consultorio. Elegir de galería puede existir como opción secundaria, pero cámara es el camino por defecto.

### Búsqueda
- **D-06:** La búsqueda (tanto de clientes como de mascotas) es **instantánea mientras se escribe** — resultados aparecen conforme el usuario teclea, sin botón "buscar" ni tecla Enter.

### Claude's Discretion
- Diseño exacto de la UI del flujo combinado cliente+mascota (¿un wizard de 2 pasos en la misma pantalla? ¿scroll continuo con ambas secciones?) — el UI-SPEC de esta fase debe resolverlo siguiendo D-02 y el mockup ya aprobado.
- Mecanismo exacto de debounce para la búsqueda instantánea (para no disparar una query por cada tecla).
- Estructura exacta de la tabla/entidad de historial de peso (nueva tabla vs. campo de auditoría en `mascotas`) — research/planner deciden con base en PAT-05.
- Manejo de permisos de cámara/galería (ya hay precedente: `permission_handler` recomendado en `.planning/research/STACK.md`).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Estado y decisiones del proyecto
- `.planning/PROJECT.md` — incluye ahora el principio de fricción cero (Constraints) que aplica a esta fase y a todas las futuras
- `.planning/REQUIREMENTS.md` — CLI-01 a CLI-04, PAT-01 a PAT-05 (requisitos exactos de esta fase)
- `.planning/ROADMAP.md` — Fase 2: objetivo y criterios de éxito

### Investigación de dominio
- `.planning/research/ARCHITECTURE.md` — patrón de repositorio/provider/pantalla ya usado en Fase 1 (auth), a replicar para `clientes`/`mascotas`
- `.planning/research/STACK.md` — librerías recomendadas para foto (`image_picker`, `flutter_image_compress`, `cached_network_image`, `permission_handler`) y Storage privado con URLs firmadas
- `.planning/research/PITFALLS.md` — modelado de multi-mascota-por-dueño desde el inicio (no como edge case)

### Fase 1 (fundación ya construida)
- `.planning/phases/01-fundaci-n/01-RESEARCH.md` — patrón exacto de Riverpod (`AsyncNotifier`) + go_router ya implementado, a seguir para los nuevos providers de clientes/pacientes
- `.planning/phases/01-fundaci-n/01-PATTERNS.md` — analogías de código de la fase anterior
- `supabase/schema.sql` — tabla `clientes` (independiente de `perfiles`) y `mascotas` ya creadas y con RLS vet-only probado; esta fase construye la UI/lógica sobre ese schema existente, no lo modifica salvo que surja un gap real

### Diseño visual
- `.planning/design/DESIGN-REFERENCE.md` — pantallas de Pacientes, ficha de mascota y Clientes ya están en el mockup aprobado (paleta terracota/crema, Caprasimo/Figtree)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/core/data/supabase_client_provider.dart` — provider único de cliente Supabase (Fase 1), reutilizar para los nuevos repositorios.
- `lib/core/widgets/**` (`AppButton`, `AppCard`, `AppTextField`, `AppStatusChip`, `AppTopBar`) — widgets ya con la paleta terracota/crema aplicada, reutilizar en las nuevas pantallas.
- `lib/core/theme/**` — tokens ya correctos desde Fase 1, no requieren cambios.
- `lib/features/auth/data/repositories/supabase_auth_repository.dart` — patrón de manejo de errores (dos niveles: `AuthException`/`PostgrestException` específico + catch-all genérico, ambos traducidos a español) a replicar para `ClienteRepository`/`MascotaRepository`.
- `lib/features/auth/presentation/providers/auth_providers.dart` — patrón de `AsyncNotifier` a replicar.
- `lib/features/patients/domain/entities/mascota.dart`, `lib/features/clients/domain/entities/cliente.dart` — entidades de dominio ya existentes (del scaffolding original) — revisar si sus campos coinciden con `supabase/schema.sql` antes de reutilizarlas (research de Fase 1 encontró desalineaciones entidad-schema en otros módulos).

### Established Patterns
- Convención de nombres: dominio en español, plomería en inglés (establecida en Fase 1).
- `_ComingSoonScreen` en las rutas de Pacientes/Clientes debe reemplazarse por las pantallas reales de esta fase.

### Integration Points
- `lib/core/router/app_router.dart` — rutas `/pacientes` y `/clientes` actualmente apuntan a `ComingSoonScreen`; esta fase las repunta a las pantallas reales.

</code_context>

<specifics>
## Specific Ideas

- El usuario fue explícito: "quiero que sea rápido, fácil e intuitivo de usar para que a la gente no le dé pereza reservar o hacer alguna de las acciones de la app" — esta frase debe ser la vara de medir para cada decisión de flujo en esta fase y las siguientes.
- Caso de uso principal a optimizar: veterinario atendiendo, cliente nuevo llega con mascota — todo el alta debe sentirse como un solo gesto, no un trámite.

</specifics>

<deferred>
## Deferred Ideas

- Aplicar el principio de fricción cero a fases futuras (Agenda, Vacunación, Facturación, etc.) — no es un "deferred" en el sentido de descartado, sino que ya quedó registrado en PROJECT.md para que cada discuss-phase futuro lo retome explícitamente.

### Reviewed Todos (not folded)
None — no había todos pendientes que revisar para esta fase.

</deferred>

---

*Phase: 2-Clientes y Pacientes*
*Context gathered: 2026-09-24*
