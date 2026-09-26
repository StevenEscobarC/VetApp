# Phase 3: Historia Clínica - Context

**Gathered:** 2026-09-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Esta fase entrega historia clínica digital real (Supabase, no mock): el veterinario registra consultas con campos estructurados (anamnesis, examen físico, diagnóstico, tratamiento, evolución) sobre una mascota ya existente (Fase 2), ve la línea de tiempo cronológica de consultas de esa mascota, y puede exportar toda la historia clínica del paciente a PDF (uso propio del veterinario, no pensado para compartir con el dueño esta fase). Las entradas guardadas son de solo-append: no se editan ni se borran; una corrección se hace registrando una consulta nueva.

No incluye: adjuntos (fotos/documentos por consulta — diferido), vínculo formal entre una consulta correctiva y la original (la corrección es simplemente una entrada nueva en la línea de tiempo), agendar la "próxima cita" sugerida (esa es la Fase 4 — Agenda, no se construye nada de eso aquí), PDF pensado para el dueño o con link compartible (Fase 9 en adelante si se decide), exportación de una consulta individual (solo la historia completa del paciente).

</domain>

<decisions>
## Implementation Decisions

### Corrección de entradas (HIST-04)
- **D-01:** Cuando el veterinario registra una consulta para corregir un error de una anterior, **no queda ningún vínculo formal** entre ambas — la nueva entrada simplemente aparece como la más reciente en la línea de tiempo cronológica. No hay campo `corrige_a` ni UI para "seleccionar la consulta a corregir". El vet explica la corrección en el texto de la consulta nueva (anamnesis/evolución) si lo considera necesario.

### Peso: consulta ↔ historial de la Fase 2
- **D-02:** Si el veterinario registra un peso dentro del examen físico de una consulta, ese peso **alimenta automáticamente el mismo historial `mascota_pesos`** construido en la Fase 2 (append-only) — no son registros separados. El vet nunca registra el mismo peso dos veces. Esto implica que el flujo de guardado de una consulta con peso debe insertar también en `mascota_pesos` (probablemente vía RPC atómica, siguiendo el mismo patrón que `registrar_cliente_con_mascota` de la Fase 2 — research/planner deciden el mecanismo exacto).

### Campos obligatorios al registrar (principio de fricción cero)
- **D-03:** Los únicos campos obligatorios para guardar una consulta son **diagnóstico y tratamiento**. Anamnesis, examen físico (incluyendo peso) y evolución son opcionales al crear. Importante: como las entradas son de solo-append (D-01/HIST-04), "opcional al crear" significa que si el vet no los llena en el momento, esa entrada específica queda así permanentemente — no hay edición posterior. Esto es intencional y coherente con el principio de fricción cero (PROJECT.md): una consulta rápida de control no debe sentirse como un trámite largo.

### Alcance y destinatario del PDF (HIST-03)
- **D-04:** El botón "Exportar PDF" genera un solo documento con **toda la historia clínica del paciente** (todas las consultas en orden cronológico), no exportación por consulta individual.
- **D-05:** El PDF es **solo para uso del veterinario** — se comparte/guarda vía el mecanismo nativo de compartir del dispositivo (WhatsApp, correo, guardar en archivos), igual que cualquier archivo del sistema. No requiere link público, autenticación del dueño, ni lenguaje adaptado a un lector no-veterinario. El dueño no tiene experiencia propia en la app hasta la Fase 9.

### Claude's Discretion
- Mecanismo exacto de la RPC atómica que registra consulta + (opcionalmente) peso — research/planner deciden basados en el patrón ya establecido en Fase 2 (`registrar_cliente_con_mascota`).
- Librería/enfoque exacto de generación de PDF en Flutter (ninguna está instalada aún — research debe evaluarla, considerando el mismo cuidado de compatibilidad de Dart SDK `^3.11.1` que ya mordió a `cached_network_image` en la Fase 2).
- Diseño exacto de la UI de la línea de tiempo (¿cards por consulta, expandibles? ¿vista compacta con detalle al tocar?) — el UI-SPEC de esta fase debe resolverlo siguiendo el mockup aprobado y el principio de fricción cero.
- Estructura exacta de la tabla `consultas`/`examen_fisico` en Postgres (columnas separadas vs. JSONB para examen físico) — research/planner deciden con base en el entity ya existente (`lib/features/clinical_history/domain/entities/consulta.dart`).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Estado y decisiones del proyecto
- `.planning/PROJECT.md` — principio de fricción cero (Constraints), aplica a esta fase
- `.planning/REQUIREMENTS.md` — HIST-01 a HIST-04 (requisitos exactos de esta fase)
- `.planning/ROADMAP.md` — Fase 3: objetivo y criterios de éxito

### Fases anteriores (patrones a replicar)
- `.planning/phases/02-clientes-y-pacientes/02-CONTEXT.md` — D-01 a D-07, especialmente D-01 (fricción cero) y D-07 (patrón de RPC atómica)
- `.planning/phases/02-clientes-y-pacientes/02-RESEARCH.md` — patrón de repositorio/provider/pantalla, pitfalls ya encontrados (ej. corrección de versión de `cached_network_image`)
- `.planning/phases/02-clientes-y-pacientes/02-PATTERNS.md` — analogías de código de la fase anterior
- `.planning/phases/01-fundaci-n/01-RESEARCH.md` — patrón exacto de Riverpod (`AsyncNotifier`) + go_router
- `supabase/schema.sql` — tablas `mascotas`, `mascota_pesos` (Fase 2, append-only) ya creadas; esta fase agrega `consultas` (y posiblemente `examen_fisico` si se modela aparte) sobre ese schema existente

### Diseño visual
- `.planning/design/DESIGN-REFERENCE.md` — si el mockup aprobado incluye pantallas de historia clínica/consulta, son la referencia visual

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/features/clinical_history/domain/entities/consulta.dart` — entity `Consulta` y `ExamenFisico` ya existen del scaffolding original, con la estructura correcta (anamnesis, examenFisico, diagnostico, tratamiento, evolucion, proximaCita, adjuntoUrls) — revisar campo por campo contra el schema real antes de reutilizar (ya hubo desalineaciones entidad-schema en otras fases). `proximaCita` y `adjuntoUrls` quedan sin usar esta fase (D-04/D-05 del scope boundary — diferidos).
- `lib/core/data/supabase_client_provider.dart` — provider único de cliente Supabase, reutilizar.
- `lib/core/widgets/**` (`AppButton`, `AppCard`, `AppTextField`, `AppStatusChip`, `AppTopBar`) — widgets con la paleta terracota/crema ya aplicada.
- `lib/features/patients/data/repositories/supabase_mascota_repository.dart` — ya tiene `registrarPeso`/`pesos()` sobre `mascota_pesos`; la nueva funcionalidad de peso-desde-consulta (D-02) debe integrarse con esto, no duplicarlo.
- `lib/features/patients/presentation/screens/mascota_detail_screen.dart` — la ficha de mascota (Fase 2) es probablemente donde vive la línea de tiempo de consultas (HIST-02) y el botón de exportar PDF (HIST-03) — research/planner confirman el punto de entrada exacto en la navegación.

### Established Patterns
- Convención de nombres: dominio en español, plomería en inglés.
- Patrón de repositorio con manejo de errores de dos niveles (`PostgrestException` específico + catch-all genérico, ambos traducidos a español) — establecido en Fase 1, replicado en Fase 2.
- RPCs atómicas `security invoker` con guard `es_veterinario()` — patrón establecido en Fase 2 para operaciones que tocan más de una tabla en un solo submit.
- Tablas append-only (sin política update/delete) para historiales — ya establecido con `mascota_pesos` en Fase 2; `consultas` sigue el mismo patrón (HIST-04).

### Integration Points
- `lib/core/router/app_router.dart` — necesita una ruta nueva (ej. `/pacientes/:id/consultas` o `/pacientes/:id/historia`) para la línea de tiempo y el registro de consulta.
- No hay ningún stub/ComingSoonScreen actual para historia clínica en el router — esta fase agrega la ruta desde cero, no reemplaza un placeholder existente.

</code_context>

<specifics>
## Specific Ideas

- El usuario confirmó dos veces durante esta discusión que el principio de fricción cero (ya registrado en PROJECT.md) sigue siendo la vara de medir: mínimo de campos obligatorios, sin pasos extra innecesarios.
- El peso registrado en una consulta debe fluir al mismo historial de peso que ya ve el vet en la ficha del paciente (Fase 2) — el usuario fue explícito en que no quiere que el vet registre el mismo dato dos veces.

</specifics>

<deferred>
## Deferred Ideas

- **Adjuntos por consulta** (`adjuntoUrls` — fotos/documentos) — el campo ya existe en el entity del scaffolding original, pero el usuario decidió dejarlo fuera de esta fase. Podría ser una mejora futura reutilizando el patrón de Storage privado de la Fase 2 (fotos de mascotas).
- **"Próxima cita" con efecto real** (`proximaCita`) — el campo existe en el entity, pero no se construye nada de agendamiento real esta fase; eso es explícitamente la Fase 4 (Agenda y Citas). Anticiparlo aquí se descartaría o duplicaría trabajo cuando llegue esa fase.
- **PDF pensado para el dueño / compartible por link** — el usuario decidió que el PDF es solo para el veterinario esta fase. Si más adelante se quiere una versión para el dueño (lenguaje más simple, link compartible sin cuenta), sería una mejora de una fase posterior (candidato: Fase 9, donde el dueño ya tiene su propia experiencia en la app).
- **Vínculo formal entre consulta correctiva y original** — el usuario decidió que no hace falta un campo `corrige_a` ni UI de selección; si en el futuro se necesita trazabilidad más fuerte (ej. para auditoría legal), sería una mejora posterior, no un rediseño de esta fase.

### Reviewed Todos (not folded)
None — no había todos pendientes que coincidieran con el alcance de esta fase (`todo.match-phase` devolvió 0 resultados).

</deferred>

---

*Phase: 3-Historia Clínica*
*Context gathered: 2026-09-26*
