# Phase 5: Vacunación y Desparasitación - Context

**Gathered:** 2026-10-01
**Status:** Ready for planning (después de la Fase 4.1)

<domain>
## Phase Boundary

El veterinario lleva el **carné de vacunación y desparasitación** de cada mascota: registra dosis aplicadas, la app **calcula sola la próxima dosis** a partir de un catálogo de protocolos y del historial de dosis (series de cachorro/gatito incluidas), muestra **alertas** de dosis próximas/vencidas con acciones rápidas, y genera un **link público de solo lectura** del carné (más PDF) que el dueño abre sin cuenta. Requisitos: VAC-01..05.

Depende de la **Fase 4.1** (Equipo de la clínica): cada dosis registra qué veterinario la aplicó, y el carné muestra nombre + matrícula del veterinario.

</domain>

<decisions>
## Implementation Decisions

### Principio rector (heredado)
- **D-00:** Fricción cero (Fase 2 D-01): mínimo de campos, búsqueda instantánea, nada de fechas escritas a mano.

### Protocolos y cálculo de la próxima dosis (VAC-02)
- **D-01:** **Catálogo base editable**: la app trae precargados los protocolos estándar de Colombia (ver tablas en `05-PROTOCOLOS-RESEARCH.md`); cada clínica puede **ajustar intervalos o agregar biológicos propios** en Más > Protocolos. (Modelo sugerido: protocolos globales semilla + sobrescrituras/biológicos por `clinica_id`.)
- **D-02:** **Serie automática**: el protocolo sabe cuántas dosis tiene la serie primaria (ej. polivalente 3 dosis cada 21 días) y cuándo pasa a refuerzo (anual). La app infiere qué dosis toca según el historial de la mascota y muestra "Dosis 2 de 3" / "Refuerzo". La próxima se calcula desde la **fecha real** de aplicación. La próxima dosis **nunca es un campo guardado editable** (Pitfall 7) — se deriva del protocolo + historial.
- **D-03:** Cuando el producto tiene una duración distinta al estándar (antirrábica 1 vs 3 años, desparasitante externo 1 mes / 5 semanas / 3 meses), el vet elige con **chips de duración** al registrar, con la del protocolo preseleccionada. Nunca se escribe una fecha.
- **D-04:** Biológico **"Otro"**: nombre libre + chips de intervalo (21 días, 1 mes, 3 meses, 6 meses, 1 año, sin refuerzo), con opción "Guardar en mi catálogo".

### Registrar una dosis (VAC-01)
- **D-05:** Puntos de entrada: **(a)** pestaña/sección **Carné** en la ficha de la mascota ("+ Registrar dosis", camino principal); **(b)** al **completar una cita** con motivo Vacunación/Desparasitación (se ofrece registrar la dosis, como hoy se ofrece la consulta — Fase 4 D-17); **(c)** **acceso rápido global "Vacunar"** (Inicio/Agenda): buscar mascota → registrar. *No* se agrega sección de vacunas dentro del formulario de consulta.
- **D-06:** Obligatorios: **biológico + fecha** (fecha precargada en hoy). Opcionales: producto/marca comercial, lote, observaciones. (Sugerencia del research: autocompletar con los últimos productos/lotes usados por la clínica.)
- **D-07:** Se permiten **dosis históricas o aplicadas en otra clínica** (mascota que llega con carné de papel): fecha pasada + switch **"Aplicada en otra clínica"** (nombre opcional). Cuentan para la serie y el cálculo; el carné las muestra diferenciadas.
- **D-08:** Corrección: **anular con motivo** (la dosis queda tachada, no cuenta para el cálculo) y registrar la correcta. Sin edición ni borrado — coherente con el estilo solo-append de historia clínica (HIST-04).
- **D-09:** Cada dosis guarda el **veterinario que la registró/aplicó** (Fase 4.1).

### Alertas (VAC-03)
- **D-10:** Dónde: **tarjeta en Inicio** ("Vacunas pendientes: 3 vencidas, 5 esta semana"), **pantalla "Vacunas pendientes"** agrupada en Vencidas / Próximas, y **badge** "Vencida"/"Próxima" en lista de pacientes y ficha. **Sin notificación push/local diaria** en esta fase.
- **D-11:** Ventana de "Próxima" **por tipo de dosis** (ajustado tras el research, reemplaza los 7 días fijos de la entidad actual): refuerzo anual/trianual → **14 días antes**; dosis de serie de cachorro/gatito → **3 días antes**; desparasitación → **5 días antes**. "Vencida" desde D+1.
- **D-12:** Acciones rápidas desde una alerta: **Recordar por WhatsApp** (tono formal con "usted", como Fase 4 D-14; marca "recordatorio enviado" con fecha), **Agendar cita** (cliente, mascota y motivo Vacunación/Desparasitación prellenados), **Registrar dosis** (biológico preseleccionado), **Descartar/posponer** (mascota fallecida, cambió de veterinario, etc.).
- **D-13:** Vencidas hace **más de 6 meses** salen de la lista activa (siguen marcadas en el carné).
- **D-14:** Las alertas son **de toda la clínica** (cualquier veterinario las ve), no por veterinario.

### Carné público (VAC-04, VAC-05)
- **D-15:** Contenido **tipo certificado**: mascota (nombre, especie, raza, foto), clínica, veterinario con matrícula, y por dosis: biológico, producto, lote, fecha aplicada, vigencia/próxima y estado (Al día / Próxima / Vencida). Dosis externas marcadas. **Nada de historia clínica**, ni datos de contacto del dueño más allá de lo mínimo. Alineado con lo que pide la Res. ICA 100164/2021 y lo que revisan guarderías.
- **D-16:** **Un link permanente por mascota**, que siempre muestra el carné actualizado, y **revocable**: "Regenerar link" invalida el anterior. Token no adivinable.
- **D-17:** Compartir: **WhatsApp al dueño** (mensaje formal + link al teléfono +57 del cliente), **hoja de compartir nativa**, y **PDF descargable** del carné (`pdf`/`printing`, ya instalados). Sin código QR en esta fase.
- **D-18:** El dueño lo ve **sin cuenta** (VAC-05).

### Claude's Discretion
- Schema exacto: tabla de dosis aplicadas (con `anulada`, `motivo_anulacion`, `externa`, `clinica_externa`, `producto`, `lote`, `duracion_elegida`/intervalo, `veterinario_id`), tablas de protocolos (global semilla + por clínica), cálculo de próxima dosis/estado (vista SQL o función vs dominio Dart — que no se desincronice), RLS y tests (vía `vetapp-supabase`). Reconciliar con la entidad existente `vacuna.dart` (eliminar `proximaDosis` como campo guardado, ampliar `TipoBiologico` o reemplazar el enum por el catálogo).
- **Mecanismo de la página pública**: Edge Function de Supabase que sirve HTML, RPC anónima `security definer` por token consumida por una página web estática, u otro — research evalúa (hosting, costo cero, branding terracota/crema, que no exponga más que D-15). El token debe ser revocable (D-16).
- Ajustes del catálogo base (intervalos por defecto dentro de los rangos del research); conviene validarlos con veterinarios reales.
- Sugerencia de "reiniciar serie" cuando pasa demasiado tiempo entre dosis de serie (research §3.6) — como sugerencia, nunca bloqueo.
- Plantilla exacta del WhatsApp de recordatorio de vacuna y del envío del carné.
- Diseño visual del carné en la app, la página pública y el PDF — resolver en `/gsd-ui-phase 5` siguiendo el mockup (pantalla "Carné de vacunación": tarjetas por vacuna, estados, botón "Compartir carné").

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Dominio de vacunación
- `.planning/phases/05-vacunaci-n-y-desparasitaci-n/05-PROTOCOLOS-RESEARCH.md` — Protocolos por especie (Colombia/WSAVA/ESCCAP), puntos legales (ICA 100164/2021, antirrábica anual), manejo de duración por producto, ventanas de alerta, fuentes
- `.planning/research/PITFALLS.md` §Pitfall 7 — No modelar la próxima dosis como un campo; modelo dosis aplicadas + protocolos
- `.planning/research/FEATURES.md` — Carné compartible como diferenciador; el link público debe ser una vista estrecha (nunca la historia clínica)

### Requisitos y roadmap
- `.planning/REQUIREMENTS.md` — VAC-01..05
- `.planning/ROADMAP.md` §Phase 5 — Goal y success criteria (depende de Fase 2 y Fase 4.1)

### Diseño
- `.planning/design/DESIGN-REFERENCE.md` — pantalla 7 "Carné de vacunación"
- `.planning/design/vetapp-mobile-designs.html` — mockup aprobado

### Multi-veterinario
- `.planning/phases/04.1-equipo-de-la-cl-nica/04.1-CONTEXT.md` — veterinario asignado/autoría, matrícula
- `.planning/research/MULTI-VET.md` §4 — impacto en Fase 5

### Decisiones previas aplicables
- `.planning/phases/04-agenda-y-citas/04-CONTEXT.md` — D-14 (WhatsApp formal), D-16 (teléfono +57), D-17 (completar cita ofrece registro)
- `.planning/phases/03-historia-cl-nica/03-CONTEXT.md` — D-01/HIST-04 (solo-append), D-04/D-05 (patrón PDF)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/features/vaccination/domain/entities/vacuna.dart` — entidad scaffold (enum `TipoBiologico`, `proximaDosis` editable que hay que eliminar, ventana fija de 7 días que hay que reemplazar).
- `lib/features/appointments/domain/motivos_cita.dart` — ya tiene motivos "Vacunación" y "Desparasitación" (enlace con D-05b y D-12 "Agendar cita").
- `lib/features/appointments/presentation/screens/completar_cita_screen.dart` — flujo de completar cita donde se ofrece registrar la dosis.
- `lib/features/patients/presentation/screens/mascota_detail_screen.dart` — ficha donde vive la sección Carné.
- Generación de PDF de historia clínica (Fase 3, `pdf: 3.12.0` / `printing: 5.14.3` fijados por compatibilidad con Dart `^3.11.1`).
- `lib/core/utils/lanzador_externo.dart`, `telefono_co.dart`, `formato.dart`, `zona_bogota.dart` — WhatsApp, +57, fechas dd/mm/aaaa, día en hora de Bogotá.

### Established Patterns
- RPCs `security definer` atómicas + RLS por `clinica_id = mi_clinica_id()`; repositorios Supabase con traducción de errores a español; Riverpod + go_router.
- Solo-append con corrección por entrada nueva (historia clínica) → anulación de dosis.

### Integration Points
- Inicio (`lib/features/home/presentation`): tarjeta "Vacunas pendientes".
- Lista de pacientes: badge de estado de vacunación.
- Agenda: "Agendar cita" prellenado desde una alerta; completar cita → registrar dosis.
- Más: pantalla "Protocolos" (catálogo editable por clínica).
- Superficie pública nueva (sin auth) para el carné — primera superficie anónima de la app.

</code_context>

<specifics>
## Specific Ideas

- Vista "¿Puede ir a guardería?" (semáforo con polivalente + antirrábica + bordetella + desparasitación vigentes) — idea del research, ver Deferred.
- El ICA exige en certificados: producto, lote, fecha de aplicación, vigencia, y firma/matrícula del veterinario → por eso D-15 y la matrícula de la Fase 4.1.

</specifics>

<deferred>
## Deferred Ideas

- **Notificación local diaria** con resumen de vacunas pendientes — no seleccionada; posible mejora (reutiliza `flutter_local_notifications`).
- **Sección "Vacunas aplicadas" dentro del formulario de consulta** — no seleccionada.
- **Código QR** del carné en pantalla — no seleccionado.
- **Vista "¿Puede ir a guardería?"** (semáforo de requisitos de guardería) — nueva capacidad, backlog.
- **Recordatorio automático al dueño** (sin toque manual) — es DIFF-01 (WhatsApp Business API), v2.
- **Descuento de inventario al aplicar una vacuna** — pertenece a Fase 6/7.

</deferred>

---

*Phase: 05-vacunacion-y-desparasitacion*
*Context gathered: 2026-10-01*
