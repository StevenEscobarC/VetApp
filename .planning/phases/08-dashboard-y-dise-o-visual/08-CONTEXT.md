# Phase 8: Dashboard y Diseño Visual - Context

**Gathered:** 2026-11-16
**Status:** Ready for planning
**Modo:** decisiones tomadas por el orquestador con la opción recomendada en cada punto, por instrucción permanente del usuario ("no esperes confirmación mía, siempre haz lo recomendado", 2026-11-14). Cada decisión cita la decisión previa en la que se apoya.

<domain>
## Phase Boundary

Inicio deja de ser un esqueleto (saludo y tarjetas de alerta) y pasa a ser el resumen operativo real de la clínica:
- 3 métricas del mes: consultas, ingresos cobrados y pacientes nuevos;
- las próximas citas;
- accesos rápidos para crear paciente, cita y cuenta de cobro.

Además, toda la app queda alineada con el diseño visual definitivo del mockup aprobado: paleta terracota y crema, Caprasimo + Figtree, y los widgets de `lib/core`. Sin restos de pantallas "Próximamente" ni del dashboard mockeado.

Requisitos: DASH-01..04.

Fuera de alcance:
- gráficas y comparación con meses anteriores;
- notificaciones push;
- modo sin conexión;
- el indicador "Sincronizado" del mockup, porque no hay sincronización offline;
- reportes exportables;
- metas e indicadores por veterinario.

</domain>

<decisions>
## Implementation Decisions

### Métricas del mes (DASH-01)
- **D-01:** Son **3 tarjetas de métrica** con las 3 métricas del requisito, en una fila (o una cuadrícula de 3 en anchos pequeños):
  - **Consultas del mes:** las consultas registradas en el mes calendario actual.
  - **Ingresos del mes:** lo cobrado este mes, es decir, las cuentas de cobro `pagada` con `pagada_el` en el mes. Es el mismo número que "Cobrado este mes" en Cobros (Fase 7 D-17) y se calcula con la misma regla.
  - **Pacientes nuevos:** las mascotas creadas en el mes.
- **D-02:** El mes es el **mes calendario de Bogotá**, con `_hoy_bogota()` en el servidor. Los totales son **de la clínica**, no por veterinario, igual que las alertas de vacunas (Fase 5 D-14) y Cobros.
- **D-03:** Todo sale de **una sola RPC** `inicio_resumen()`, `security definer` con validación de clínica (patrón de la Fase 6/7), que devuelve los 3 números.
  - Las anuladas y las cotizaciones nunca cuentan en ingresos.
  - Así se evitan 3 consultas y se mantiene una sola regla de mes.
- **D-04:** **Tocar una tarjeta lleva a su sección:** Ingresos va a Cobros (Cuentas de cobro) y Pacientes nuevos va a Pacientes. Consultas no navega, porque no hay lista global de consultas; no se crea una en esta fase.
- **D-05:** Formato: COP sin decimales con `formatearCop`, y abreviado cuando no cabe (por ejemplo, "$ 3,8 M", como el mockup). Las cifras usan `formatearMiles`.
- **D-06:** Los colegas en solo lectura (Fase 5.1 D-12) **ven todo el resumen**, porque leer nunca se bloquea.

### Próximas citas (DASH-02)
- **D-07:** Se muestran **las próximas 5 citas pendientes o confirmadas desde ahora**, de toda la clínica, ordenadas por hora. Hoy primero; si hay menos de 5 hoy, siguen los días siguientes con un separador de fecha ("Mañana", "lun 18/11").
  - Cada fila lleva hora, mascota, cliente, motivo y chip de estado (Confirmada/Pendiente, como el mockup).
  - En una clínica con varios veterinarios, la fila lleva el color o inicial del veterinario. Reutiliza `indicesColorVetProvider` de la agenda (Fase 4.1).
- **D-08:** Tocar una cita abre su detalle (`/agenda/...`, la ruta de detalle existente). Un enlace "Ver agenda" lleva a la pestaña Agenda. Si no hay próximas citas, el estado vacío dice "No tienes citas próximas." y ofrece "Agendar cita".
- **D-09:** Sale del repositorio de citas existente (una consulta por rango) o de la misma RPC de D-03. El planner elige; recomendado: una consulta de citas por rango, porque ya existe el mapeo de `Cita`.

### Accesos rápidos (DASH-03)
- **D-10:** Hay **4 accesos rápidos** en una fila de chips o botones grandes (48 dp o más):
  - **Paciente:** el alta combinada de cliente y mascota (Fase 2 D-02).
  - **Cita:** el formulario de nueva cita.
  - **Cobro:** abre `/cobros/nuevo`. **Nunca "Factura"** (Fase 7 D-01): el mockup dice "Factura", pero la etiqueta es "Cobro".
  - **Vacunar:** ya existe en Inicio (Fase 5 D-10) y se integra aquí en vez de quedar como botón suelto.
- **D-11:** En solo lectura los 4 accesos muestran el **candado** y abren la hoja del plan (`ControlEscritura`, Fase 5.1), igual que el resto de la app.

### Orden de Inicio
- **D-12:** De arriba abajo:
  1. Encabezado "Hola, {nombre}" con el nombre de la clínica (como el mockup).
  2. `PlanBanner` (Fase 5.1), solo cuando aplica.
  3. Fila de métricas.
  4. Accesos rápidos.
  5. "Próximas citas".
  6. Tarjetas de alerta: vacunas pendientes (Fase 5) y stock bajo (Fase 6). Siguen apareciendo solo cuando tienen algo.
- **D-13:** **Refresco:** deslizar hacia abajo para recargar todo Inicio. Se invalida al volver a la app (mismo patrón que el plan, tarea rápida et0) y después de cualquier mutación de citas, consultas, cobros o mascotas, en `finally`, igual que en las Fases 6/7.
- **D-14:** **Estados:**
  - carga: esqueletos por bloque;
  - error por bloque: el mensaje y "Reintentar", sin tumbar los demás bloques;
  - sin conexión: un error con el texto "Sin conexión. Inténtalo de nuevo cuando tengas señal."

### Diseño visual en toda la app (DASH-04)
- **D-15:** Se hace un **barrido de diseño en todas las pantallas** contra `.planning/design/DESIGN-REFERENCE.md` y el mockup:
  - primero una auditoría completa con `vetapp-brand-ui`, por feature;
  - después planes de corrección agrupados por feature, que se pueden correr en paralelo sin solapar archivos.
- **D-16:** **Qué se corrige:**
  - colores fuera de `AppColors`, tamaños de letra o fuentes sueltos, y espaciados fuera de `AppSpacing`;
  - widgets Material crudos donde existe uno de core: `ElevatedButton`/`TextButton`/`AppBar`/`TextField`/`Chip` frente a `AppButton`/`AppTopBar`/`AppTextField`/`AppFilterChip`;
  - áreas táctiles de menos de 48 dp, semántica que falta, y fechas o montos sin el formato colombiano.
  - Los BLOCKER y WARN se corrigen. Los INFO quedan como deuda en Linear, salvo los triviales. Esto incluye los WARN que quedaron de las auditorías de las Fases 6 y 7 (VET-57 y VET-78, partes de marca).
- **D-17:** **Se elimina `ComingSoonScreen`** si ya no la usa ninguna ruta, junto con cualquier texto "Próximamente".
- **D-18:** **El modo oscuro se mantiene** tal como lo define `app_colors.dart`. El barrido verifica el contraste de las pantallas nuevas en ambos modos, pero no rediseña el modo oscuro.
- **D-19:** **No cambian el flujo ni las reglas** de las pantallas existentes: el barrido es solo visual y de accesibilidad. Si aparece un problema funcional, se registra aparte.

### Plan y permisos
- **D-20:** No hay límite nuevo de plan: Inicio está en todos los planes (regla de 4 límites, Fase 5.1 D-01).

### Claude's Discretion
- La forma de la RPC (columnas o JSON), si las citas van en la RPC o en una consulta aparte (D-09), y el layout exacto de las tarjetas dentro del UI-SPEC.
- Cómo dividir el barrido de DASH-04 en planes, según lo que encuentre la auditoría.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Alcance y requisitos
- `.planning/ROADMAP.md`, Phase 8: objetivo y los 4 criterios de éxito.
- `.planning/REQUIREMENTS.md`: DASH-01..04.

### Diseño
- `.planning/design/DESIGN-REFERENCE.md`, pantalla 2 (Inicio): métricas, próximas citas, accesos rápidos y tokens.
- `.planning/design/vetapp-mobile-designs.html`: el mockup aprobado.
- Los UI-SPEC aprobados de las Fases 5, 5.1, 6 y 7: tokens, candado de solo lectura y estados.

### Decisiones previas que atan esta fase
- `.planning/phases/07-facturaci-n/07-CONTEXT.md`: D-01 (nunca "Factura"), D-17 ("Cobrado este mes").
- `.planning/phases/05.1-planes-y-l-mites/05.1-CONTEXT.md`: D-01 (4 límites) y D-12 (solo lectura).
- `.planning/phases/05-vacunaci-n-y-desparasitaci-n/05-CONTEXT.md`: D-10 (tarjeta y acción Vacunar en Inicio) y D-14 (alertas de clínica).
- `.planning/phases/06-inventario/06-CONTEXT.md`: D-08 (tarjeta de stock bajo en Inicio).
- `.planning/phases/04.1-equipo-de-la-cl-nica/04.1-CONTEXT.md`: colores por veterinario.

### Arquitectura
- `.claude/skills/arquitecto-vetapp/SKILL.md` y `references/modelo-dominio.md`.
- `supabase/schema.sql`: `cobros_resumen` (la regla de ingresos que se reutiliza), consultas, mascotas y citas.

</canonical_refs>

<code_context>
## Existing Code Insights

- `lib/features/home/presentation/screens/inicio_screen.dart` (116 líneas) tiene:
  - el saludo;
  - `PlanBanner`;
  - `VacunasPendientesCard` y `StockBajoCard`;
  - el botón Vacunar.

  El "dashboard mockeado de 1400 líneas" del roadmap ya no existe. Inicio se reescribe sobre la base actual.
- `ComingSoonScreen` existe (22 líneas). Las listas de clientes y pacientes ya no la usan; hay que confirmar si queda alguna ruta que sí.
- Para reutilizar:
  - `cobros_resumen`;
  - el repositorio de citas;
  - `indicesColorVetProvider` y `esClinicaMultiVetProvider`;
  - `ControlEscritura` / `iconoEscritura` / `puedeEscribirProvider`;
  - `formatearCop` / `formatearMiles` / `formatearFecha`;
  - `AppCard` / `AppButton` / `AppTopBar`.

</code_context>

<deferred>
## Deferred Ideas

- Gráficas y comparación con el mes anterior.
- Métricas por veterinario.
- Lista global de consultas (para que la tarjeta de consultas navegue).
- Indicador "Sincronizado" y modo sin conexión.
- Rediseño del modo oscuro.
- Descontar stock al registrar una dosis (Fase 6 D-05, IDEAS #50).
- La revisión con un contador del texto de la cuenta de cobro: está en manos del usuario.

</deferred>

---

*Phase: 08-dashboard-y-diseño-visual*
*Context gathered: 2026-11-16*
