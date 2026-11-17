# Phase 8: Dashboard y Diseño Visual - Research

**Researched:** 2026-11-16
**Domain:** Flutter (Riverpod 3 + go_router) + Supabase RPC (plpgsql, security definer) + barrido de diseño
**Confidence:** HIGH (todo verificado leyendo el código y el schema del repo; sin librerías nuevas)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** 3 tarjetas de métrica (Consultas del mes, Ingresos del mes, Pacientes nuevos), en una fila (o cuadrícula de 3 en anchos pequeños). Ingresos = cuentas de cobro `pagada` con `pagada_el` en el mes, misma regla que "Cobrado este mes" de Cobros (Fase 7 D-17).
- **D-02:** Mes calendario de Bogotá con `_hoy_bogota()` en el servidor. Totales de la clínica, no por veterinario.
- **D-03:** Una sola RPC `inicio_resumen()`, `security definer` con validación de clínica (patrón Fase 6/7), que devuelve los 3 números. Anuladas y cotizaciones nunca cuentan en ingresos.
- **D-04:** Ingresos navega a Cobros (Cuentas de cobro); Pacientes nuevos va a Pacientes; Consultas no navega.
- **D-05:** COP sin decimales con `formatearCop`, abreviado cuando no cabe ("$ 3,8 M"). Cifras con `formatearMiles`.
- **D-06:** Colegas en solo lectura ven todo el resumen.
- **D-07:** Próximas 5 citas pendientes o confirmadas desde ahora, de toda la clínica, por hora; hoy primero y luego días siguientes con separador de fecha ("Mañana", "lun 18/11"). Fila: hora, mascota, cliente, motivo, chip de estado; en multi-vet, color/inicial del veterinario con `indicesColorVetProvider`.
- **D-08:** Tocar cita abre `/agenda/...` (detalle). Enlace "Ver agenda". Vacío: "No tienes citas próximas." + "Agendar cita".
- **D-09:** Citas desde el repositorio existente (consulta por rango) o la RPC. El planner elige; recomendado: consulta de citas por rango.
- **D-10:** 4 accesos rápidos (>= 48 dp): Paciente (alta combinada), Cita, Cobro (`/cobros/nuevo`, nunca "Factura"), Vacunar (se integra, no queda suelto).
- **D-11:** En solo lectura los 4 accesos muestran candado y abren la hoja del plan (`ControlEscritura`).
- **D-12:** Orden: encabezado "Hola, {nombre}" + clínica; `PlanBanner` si aplica; métricas; accesos rápidos; "Próximas citas"; tarjetas de alerta (vacunas pendientes, stock bajo).
- **D-13:** Pull-to-refresh recarga todo Inicio. Se invalida al volver a la app (patrón et0) y tras cualquier mutación de citas, consultas, cobros o mascotas, en `finally`, como en Fases 6/7.
- **D-14:** Estados: esqueletos por bloque; error por bloque con mensaje + "Reintentar" sin tumbar los demás; sin conexión: "Sin conexión. Inténtalo de nuevo cuando tengas señal."
- **D-15:** Barrido de diseño en todas las pantallas: primero auditoría completa con `vetapp-brand-ui` por feature; luego planes de corrección por feature en paralelo sin solapar archivos.
- **D-16:** Se corrige: colores fuera de `AppColors`, tamaños/fuentes sueltos, espaciados fuera de `AppSpacing`; widgets Material crudos donde existe uno de core; áreas táctiles < 48 dp, semántica faltante, fechas/montos sin formato colombiano. BLOCKER y WARN se corrigen; INFO a Linear salvo triviales (incluye WARN de Fases 6 y 7: VET-57, VET-78).
- **D-17:** Se elimina `ComingSoonScreen` si ninguna ruta la usa, y cualquier texto "Próximamente".
- **D-18:** Modo oscuro se mantiene como está en `app_colors.dart`; solo se verifica contraste de pantallas nuevas.
- **D-19:** No cambian flujo ni reglas: el barrido es visual y de accesibilidad. Problemas funcionales se registran aparte.
- **D-20:** Sin límite nuevo de plan; Inicio está en todos los planes.

### Claude's Discretion
- Forma de la RPC (columnas o JSON), si las citas van en la RPC o en consulta aparte, y layout exacto de las tarjetas (UI-SPEC).
- Cómo dividir el barrido de DASH-04 en planes.

### Deferred Ideas (OUT OF SCOPE)
- Gráficas y comparación con mes anterior; métricas por veterinario; lista global de consultas; indicador "Sincronizado" y modo sin conexión; rediseño del modo oscuro; descontar stock al registrar dosis; revisión con contador del texto de la cuenta de cobro.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DASH-01 | Resumen al iniciar sesión (consultas del mes, ingresos del mes, pacientes nuevos) | RPC `inicio_resumen()` (sección Patrón 1), provider, invalidación, formato abreviado |
| DASH-02 | Próximas citas desde el dashboard | Método nuevo `proximas()` en `SupabaseCitaRepository` (Patrón 2), color de vet, rutas |
| DASH-03 | Accesos rápidos paciente / cita / cobro | Rutas existentes + `ControlEscritura` (Patrón 4) |
| DASH-04 | Todas las pantallas con el diseño visual definitivo | Inventario del barrido y reparto en planes (sección DASH-04) |
</phase_requirements>

## Summary

La fase no necesita librerías nuevas: todo se construye con lo que ya hay (Riverpod 3, go_router, supabase_flutter, widgets de `lib/core`). Inicio hoy tiene 116 líneas (saludo, `PlanBanner`, `VacunasPendientesCard`, `StockBajoCard`, botón Vacunar) y se reescribe. El backend es una RPC nueva `inicio_resumen()` que copia el patrón de `cobros_resumen()` (security definer, `mi_clinica_id()`, `es_veterinario()`, `_hoy_bogota()`), más un método nuevo de repositorio para las próximas citas.

El hallazgo más importante del barrido (DASH-04): el código ya está muy limpio. Hay 0 `Color(0x` y 0 `Colors.xxx` de Material en `lib/features` (todos los "Colors." son `AppColors.`), 0 `AppBar(`, 0 `TextField(`/`TextFormField(` crudos, 0 `Chip(` crudos y 0 `ElevatedButton` fuera de `core/`. Lo único cuantificable es: 47 usos de `TextButton` crudo en 19 archivos, ~10 `EdgeInsets` con literales en features de UI, y `fontSize:` solo en los 3 servicios de PDF (paquete `pdf`, no Flutter: legítimo). El barrido real depende de la auditoría `vetapp-brand-ui` (contraste, 48 dp, semántica, formato), no de greps.

`ComingSoonScreen` ya no tiene ningún uso en rutas ni en código: solo dos comentarios la mencionan. Se borra el archivo y se ajustan los dos doc comments.

**Primary recommendation:** una RPC `inicio_resumen()` (returns table de 3 columnas, ingresos con la misma expresión que `cobros_resumen` y una prueba de paridad en el smoke); próximas citas con un método nuevo `proximas()` (una consulta, filtro de estado en SQL, límite 5); invalidación con un contador `inicioRevisionProvider` en `lib/core/data/` (sin ciclos), incrementado desde `CitaActions`, `RegistrarConsulta`, `invalidarCobros` y los 2 sitios de alta de mascota; barrido en 1 auditoría + 5 planes de corrección sin solapar archivos.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Totales del mes (consultas, ingresos, nuevos) | Database (RPC) | API client (repo) | Una sola regla de mes Bogotá y aislamiento por clínica en el servidor (D-02, D-03) |
| Próximas citas | Database (query + RLS) | Client (mapeo `Cita`) | RLS ya aísla; filtro de estado y límite en SQL |
| Formato COP abreviado, "Mañana"/"lun 18/11" | Client (utils) | — | Presentación pura, testeable sin red |
| Invalidación tras mutaciones | Client (Riverpod) | — | Estado de UI; el servidor no empuja cambios |
| Candado solo lectura en accesos | Client (`ControlEscritura`) | Database (`guard_solo_lectura`) | El servidor ya rechaza escrituras (LP004); la UI solo lo anticipa |
| Barrido visual | Client (UI) | — | Sin cambios de backend (D-19) |

## Standard Stack

### Core (todo ya instalado, sin cambios en `pubspec.yaml`)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_riverpod | 3.3.2 | Providers del resumen y de las citas | Ya es el patrón del repo (`FutureProvider.autoDispose`) [VERIFIED: pubspec.lock via CLAUDE.md] |
| go_router | 17.3.0 | Navegación a `/agenda/:id`, `/citas/nueva`, `/cobros/nuevo`, `/clientes/nuevo` | Rutas ya existen [VERIFIED: codebase grep] |
| supabase_flutter | 2.17.2 | `rpc('inicio_resumen')` y query de citas | Ya usado en todos los repos |
| intl | 0.20.3 | Formato | Ya usado en `formato.dart` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Contador `inicioRevisionProvider` | `ref.invalidate(inicioResumenProvider)` directo desde cada action | Provoca ciclo de imports (home importa appointments y viceversa); el contador evita el ciclo |
| 2 queries (RPC + citas) | Citas dentro de la RPC (jsonb) | Obligaría a reescribir el mapeo de `Cita` (embed de mascotas, cliente, veterinario) en jsonb; D-09 recomienda la consulta existente |
| Helper SQL compartido para "cobrado del mes" | Copiar la expresión | Tocar `cobros_resumen` (ya verificada en vivo) por reutilización es riesgo sin beneficio; copiar y probar paridad |

**Installation:** ninguna. **Package Legitimacy Audit:** no se instalan paquetes externos en esta fase; no aplica.

## Architecture Patterns

### System Architecture Diagram

```
App abre / pull-to-refresh / vuelve a primer plano (onResume)
        |
        v
 InicioScreen (ConsumerWidget, ListView + RefreshIndicator)
   |-- Encabezado <- authProfileProvider
   |-- PlanBanner <- miPlanProvider
   |-- MetricasInicio <- inicioResumenProvider --(rpc)--> inicio_resumen()  [security definer]
   |        |                                              |-> consultas JOIN mascotas (clinica) por fecha Bogotá
   |        |                                              |-> cobros pagada (misma regla que cobros_resumen)
   |        |                                              '-> mascotas.created_at en el mes
   |        '-- tap: Ingresos -> /cobros ; Nuevos -> /pacientes ; Consultas -> (nada)
   |-- AccesosRapidos --> ControlEscritura(puedeEscribirProvider)
   |        '-- Paciente /clientes/nuevo | Cita /citas/nueva | Cobro /cobros/nuevo | Vacunar (sheet)
   |-- ProximasCitas <- proximasCitasProvider --> SupabaseCitaRepository.proximas(desde: ahora, limite: 5)
   |        '-- indicesColorVetProvider + esClinicaMultiVetProvider (color/inicial)
   |        '-- tap fila -> /agenda/:id ; "Ver agenda" -> /agenda
   '-- VacunasPendientesCard / StockBajoCard (existentes)

Mutaciones (CitaActions.*, RegistrarConsulta, invalidarCobros, alta de mascota)
        '--> inicioRevisionProvider.increment() (core/data, sin imports de features)
                  '--> inicioResumenProvider y proximasCitasProvider hacen ref.watch(inicioRevisionProvider) y se recargan
```

### Recommended Project Structure
```
lib/core/data/inicio_revision.dart                       # Notifier<int> + incrementar() (sin imports de features)
lib/core/utils/formato.dart                              # + formatearCopAbreviado()
lib/features/home/domain/resumen_inicio.dart             # ResumenInicio {consultasMes, ingresosMes, pacientesNuevos}
lib/features/home/data/supabase_inicio_repository.dart   # rpc + traducción de errores a Spanish
lib/features/home/presentation/providers/inicio_providers.dart
lib/features/home/presentation/widgets/{metricas_inicio,accesos_rapidos,proximas_citas}.dart
lib/features/appointments/data/repositories/supabase_cita_repository.dart  # + proximas()
lib/features/appointments/presentation/providers/citas_providers.dart      # + proximasCitasProvider
supabase/schema.sql                                      # + inicio_resumen() al final
supabase/tests/rls_smoke_test.sql                        # + bloque nuevo (T31+)
supabase/tests/verify_live_schema.sh                     # + inicio_resumen en la lista de RPC (línea ~110)
```
Si se quiere evitar la carpeta `home/data`, el repositorio puede vivir en `lib/features/home/data/`; el CLAUDE.md muestra que features nuevos siguen la estructura data/domain/presentation. Mantener el manejo de errores del repo: `on PostgrestException` + catch genérico con mensaje en español; el mensaje de red usa el texto D-14.

### Pattern 1: RPC `inicio_resumen()` (DASH-01)

**Columna de fecha correcta para consultas:** `consultas.fecha` (timestamptz, `default now()`). `registrar_consulta` NO recibe fecha: inserta sin `fecha`, así que vale `now()` del servidor [VERIFIED: schema.sql líneas 473-500 y 1012-1020]. `created_at` también existe y es igual hoy; usar `fecha` porque es la columna de dominio y la del índice `consultas_mascota_id_idx (mascota_id, fecha desc)`.

**Tenant:** `consultas` no tiene `clinica_id`; la clínica sale de `mascotas.clinica_id` (así lo hace la policy `consultas_select`). Hay que unir `consultas c join mascotas m on m.id = c.mascota_id where m.clinica_id = v_clinica`.

**Mes Bogotá sargable** (no casteo la columna, comparo contra límites calculados; así usa el índice):
```sql
-- Source: patrón cobros_resumen (schema.sql ~5359) + _hoy_bogota (schema.sql 2045)
drop function if exists public.inicio_resumen();
create or replace function public.inicio_resumen()
returns table (consultas_mes int, ingresos_mes bigint, pacientes_nuevos int)
language plpgsql
stable
security definer set search_path = public
as $$
#variable_conflict use_column
declare
  v_clinica uuid := public.mi_clinica_id();
  v_hoy date := public._hoy_bogota();
  v_ini date := date_trunc('month', v_hoy)::date;
  v_ini_ts timestamptz := (v_ini::timestamp) at time zone 'America/Bogota';
  v_fin_ts timestamptz := ((v_ini + interval '1 month')::timestamp) at time zone 'America/Bogota';
begin
  if not public.es_veterinario() or v_clinica is null then
    raise exception 'Solo un veterinario de una clínica puede ver el resumen de Inicio.'
      using errcode = 'insufficient_privilege';
  end if;

  return query select
    (select count(*)::int from public.consultas c
       join public.mascotas m on m.id = c.mascota_id
      where m.clinica_id = v_clinica and c.fecha >= v_ini_ts and c.fecha < v_fin_ts),
    (select coalesce(sum(total_cop), 0)::bigint from public.cobros
      where clinica_id = v_clinica and tipo = 'cuenta_cobro' and estado = 'pagada'
        and pagada_el >= v_ini and pagada_el <= v_hoy),
    (select count(*)::int from public.mascotas
      where clinica_id = v_clinica and created_at >= v_ini_ts and created_at < v_fin_ts);
end;
$$;
revoke all on function public.inicio_resumen() from public, anon;
grant execute on function public.inicio_resumen() to authenticated;
```
- **Ingresos, misma regla que `cobros_resumen`:** `tipo='cuenta_cobro'`, `estado='pagada'`, `pagada_el` entre el primer día del mes y `v_hoy` (ambos `date`, ya en Bogotá). Las anuladas (estado `anulada`) y las cotizaciones (`tipo='cotizacion'`) quedan fuera por construcción. [VERIFIED: schema.sql 5356-5379]. Recomendación: copiar la expresión en la RPC nueva (no extraer helper) y blindar con un check de paridad `inicio_resumen().ingresos_mes = cobros_resumen().cobrado_mes` en el smoke.
- **Forma:** `returns table` de 3 columnas, igual que `cobros_resumen`/`vacunas_resumen`; el repo lee `rows.first` (la RPC de tabla vuelve como lista). Mirar `supabase_cobros_repository.dart resumen()` y copiar su manejo.
- **Costo/índices:** consultas: `mascotas_clinica_id_idx` -> nested loop sobre `consultas_mascota_id_idx (mascota_id, fecha desc)`; para una clínica pequeña es trivial. Cobros: `cobros_lista_idx (clinica_id, tipo, fecha desc, numero desc)` cubre `clinica_id, tipo`; filtra `estado/pagada_el` en memoria (igual que `cobros_resumen` hoy). Mascotas: `mascotas_clinica_id_idx` + filtro por `created_at`. No se necesita ningún índice nuevo en v1 [ASSUMED: volumen de una clínica pequeña, <10k filas por tabla; si un cliente llegara a 100k+ consultas, añadir índice parcial; no es tema de esta fase].
- **`stable`:** válido porque solo lee; `now()` se usa vía `_hoy_bogota()` (también `stable`).
- **Solo lectura (D-06):** no hay trigger `guard_solo_lectura` en SELECT/RPC `stable`, así que el colega en solo lectura la ejecuta. Confirmar con un check de smoke.
- **Redondeo/null:** `coalesce(...,0)`; `count(*)` nunca es null. Clínica vacía devuelve ceros.

### Pattern 2: Próximas citas (DASH-02)

La consulta existente `entre(inicio, fin)` NO sirve tal cual: filtra solo por rango, no por estado, y `EstadoCita.desdeValor` mapea `solicitada` y desconocidos a `pendiente` (cita.dart), así que filtrar en Dart mostraría solicitudes. Añadir un método:
```dart
// Source: supabase_cita_repository.dart (entre) + postgrest-dart inFilter
Future<List<Cita>> proximas({required DateTime desdeUtc, int limite = 5}) async {
  try {
    final rows = await _client
        .from('citas')
        .select(_select)
        .inFilter('estado', ['pendiente', 'confirmada'])
        .gte('fecha_hora', desdeUtc.toUtc().toIso8601String())
        .order('fecha_hora')
        .limit(limite);
    return (rows as List).map((r) => citaDesdeFila(r as Map<String, dynamic>)).toList();
  } on PostgrestException catch (e) {
    throw CitaFailure(_messageFor(e), limite: limitePlanDe(e));
  } catch (_) {
    throw const CitaFailure('No pudimos cargar las próximas citas. Intenta de nuevo.');
  }
}
```
- Reusa el `_select` (cliente, mascotas del embed, veterinario) y `citaDesdeFila`; usa `citas_clinica_fecha_idx (clinica_id, fecha_hora)`; RLS aísla por clínica (no hay filtro de clínica en cliente). `inFilter` existe en postgrest-dart v2 (la API vigente); verificar el nombre al implementar [ASSUMED: nombre del método en la versión resuelta; si no existe usar `.filter('estado','in','(pendiente,confirmada)')`].
- **Zona horaria:** "ahora" = `ref.watch(clockProvider)` (existe `core/data/clock_provider.dart`; verificar su forma) para que los tests fijen la hora. Los separadores de fecha se calculan con `aBogota(cita.fechaHora)` / `diaBogota` / `mismoDia` de `zona_bogota.dart`: "Hoy" (sin separador, es el primer grupo), "Mañana", y `lun 18/11` para el resto. No hay locale de nombres de día cargado (la app nunca llama `initializeDateFormatting`, ver `formato.dart`): construir los nombres de día con una lista const `['lun','mar','mié','jue','vie','sáb','dom']`, no con `DateFormat.E('es')`. Un helper puro en `core/utils/` (testeable) es lo recomendado.
- **Multi-vet:** `ref.watch(esClinicaMultiVetProvider)` decide si se muestra el color/inicial; el color sale de `indicesColorVetProvider[cita.veterinarioId]` y el widget existente `VetAvatar` (`core/widgets/status/vet_avatar.dart`), igual que `cita_card.dart` (línea ~59). Copiar de `cita_card.dart` el uso exacto en lugar de inventar. Una cita ya comenzada pero aún no cerrada (hoy 09:00 mientras son las 09:10) queda excluida por `gte ahora`; aceptado por D-07 ("desde ahora").
- **Estado visual:** `estadoAStatus()` de `estado_cita_ui.dart` + `AppStatusChip` (solo `pending`/`confirmed` aparecen aquí).
- **Rutas:** detalle `/agenda/:id` (`agenda_routes.dart`; el segmento `nueva` va antes que `:id`); nueva cita desde Inicio con la ruta de primer nivel `/citas/nueva` (comentario en `agenda_routes.dart` líneas 51-55: empujar la ruta de una rama del shell desde otra rama rompe la pila), igual que `/cobros/nuevo`; alta combinada: ruta `nuevo` bajo clientes (`clientes_routes.dart` línea 20, comprobar su path completo, `/clientes/nuevo`). "Ver agenda" = `context.go('/agenda')`. Hay tests `router_*_cross_shell_test.dart` que muestran por qué importa: seguir ese patrón para las rutas de primer nivel.

### Pattern 3: Invalidación sin ciclos (D-13)

Estado actual: ya hay helpers centrales `invalidarCobros` (cobros), `invalidarVacunas` (vacunas), `invalidarInventario`, y un contador `citasRevisionProvider`. Las acciones de citas y consultas invalidan providers propios en línea. Sitios de alta de mascota invalidan en la pantalla (`mascota_form_screen.dart` ~186, `nuevo_cliente_mascota_screen.dart` ~168).

Diseño recomendado:
```dart
// lib/core/data/inicio_revision.dart  (no importa nada de features)
class InicioRevision extends Notifier<int> {
  @override int build() => 0;
  void incrementar() => state++;
}
final inicioRevisionProvider = NotifierProvider<InicioRevision, int>(InicioRevision.new);
```
Y en `inicio_providers.dart`:
```dart
final inicioResumenProvider = FutureProvider.autoDispose<ResumenInicio>((ref) {
  ref.watch(inicioRevisionProvider);          // se recarga al incrementar
  return ref.watch(inicioRepositoryProvider).resumen();
});
```
`proximasCitasProvider` (en `citas_providers.dart`) también hace `ref.watch(inicioRevisionProvider)`. Ninguna action importa `home/`, solo `core/data/`. (Alternativa válida si se prefiere `ref.invalidate`: mismo patrón que `citasRevisionProvider`.)

Mutaciones que deben incrementar (todas en `finally`/tras éxito, como Fases 6/7; el patrón actual de CitaActions incrementa tras `await`, no en `finally`; decidir y ser consistente: para el contador conviene `finally` porque una falla parcial igual pudo escribir):
| Mutación | Sitio | Afecta |
|----------|-------|--------|
| Crear/actualizar/reasignar/cambiar estado de cita | `CitaActions.crear/actualizar/reasignar/cambiarEstado` (NO `marcarRecordatorioEnviado`) | próximas citas |
| Registrar consulta | `RegistrarConsulta.registrar` (`consultas_providers.dart`) | consultas del mes; si completa cita, también próximas |
| Crear/marcar pagada/anular/editar cobro | `invalidarCobros()` en `cobros_providers.dart` (un solo punto; cubre las 6 llamadas) | ingresos |
| Alta de cliente+mascota | `nuevo_cliente_mascota_screen.dart` (junto a `ref.invalidate(miPlanProvider)`) | pacientes nuevos |
| Alta de mascota | `mascota_form_screen.dart` (rama de creación, no la de edición) | pacientes nuevos |
No existe borrado de clientes/mascotas en `data/` (grep sin `.delete(`), por lo que no hay mutaciones de baja. Dosis de vacuna ya usa `invalidarVacunas` (tarjeta propia, no cambia las 3 métricas).

Refresco al volver a la app: copiar `AppLifecycleListener(onResume: ref.invalidateSelf)` de `plan_providers.dart` (línea 25), con `ref.onDispose(lifecycle.dispose)`. Al enfocar la pestaña Inicio ya existe el hook de `AppShell` (`_ramasQueRefrescanPlan`): añadir ahí `ref.read(inicioRevisionProvider.notifier).incrementar()` en el `addPostFrameCallback` (igual que `miPlanProvider`); es el lugar que ya resuelve "Riverpod no permite invalidar hasta el frame".
Pull-to-refresh: `RefreshIndicator(onRefresh: ...)` sobre el `ListView` (con `AlwaysScrollableScrollPhysics`), que incrementa el contador y `await ref.read(inicioResumenProvider.future)` para que el spinner dure lo justo; también invalidar `vacunasPendientesProvider`/`resumenVacunasProvider` (`invalidarAlertasVacunas(ref)`) y el provider del resumen de stock bajo (`invalidarInventario`) para "recarga todo Inicio".

### Pattern 4: Accesos rápidos y candado (DASH-03, D-10/D-11)
Copiar el patrón actual del botón Vacunar: `ControlEscritura(puedeEscribir: ..., label: ..., onTap: ..., child: ...)` con `iconoEscritura(puedeEscribir, icono)`, y `asegurarEscritura(context, ref, plan: ...)` para abrir la hoja del plan. Cada acceso mide >= `AppSpacing.touchTarget` (48). 4 accesos en una fila de 360 dp = ~80 dp por ancho: usar `Row` con `Expanded` (cada uno columna ícono + etiqueta corta "Paciente", "Cita", "Cobro", "Vacunar") o `Wrap`; el UI-SPEC decide. Etiqueta "Cobro", nunca "Factura".

### Pattern 5: Estados por bloque (D-14)
Cada bloque (`MetricasInicio`, `ProximasCitas`) usa `AsyncValue.when` con `loading` -> esqueleto (no `CircularProgressIndicator` a pantalla completa) y `error` -> mensaje + `AppButton(variant: text, 'Reintentar')` que incrementa el contador o `ref.invalidate`. Los fallos de red de `supabase_flutter` llegan como `SocketException`/`ClientException` y no como `PostgrestException`: el catch genérico del repo debe devolver el texto "Sin conexión. Inténtalo de nuevo cuando tengas señal." [ASSUMED: la forma exacta de la excepción de red; en el repo no hay ninguna distinción hoy: confirmar o usar un único mensaje]. El `error:` actual del perfil muestra solo texto; mantener y no tumbar los demás bloques.

### Anti-Patterns to Avoid
- **No** casteo `c.fecha at time zone ...::date` en el WHERE de consultas (anula el índice); comparar contra límites timestamptz calculados.
- **No** extraer un helper SQL compartido tocando `cobros_resumen` (ya verificada en vivo).
- **No** importar `home/` desde `appointments/`/`billing/` (ciclo); usar el contador del core.
- **No** filtrar estado de cita en Dart (`solicitada` se mapea a `pendiente`).
- **No** usar `DateFormat('EEE','es')` (no hay `initializeDateFormatting`; lanzaría `LocaleDataException`).
- **No** llamar "Factura" a nada (D-10); el mockup dice "Factura", la UI dice "Cobro".

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Zona horaria Bogotá | offset a mano | `aBogota`, `deBogota`, `diaBogota`, `mismoDia` de `zona_bogota.dart` | Ya probados (`zona_bogota_test.dart`) |
| Estado de cita -> chip | colores propios | `estadoAStatus()` + `AppStatusChip` | Mapeo oficial |
| Color/inicial de veterinario | paleta nueva | `VetAvatar` + `indicesColorVetProvider` | Colores estables de la Fase 4.1 |
| Candado de solo lectura | `if (!puedeEscribir)` por pantalla | `ControlEscritura` / `iconoEscritura` / `asegurarEscritura` | Comportamiento uniforme |
| Refresco al volver a la app | `WidgetsBindingObserver` propio | `AppLifecycleListener(onResume: ref.invalidateSelf)` (plan_providers.dart) | Mismo patrón de et0 |
| Montos | `NumberFormat` ad hoc | `formatearCop` / `formatearMiles` + helper abreviado nuevo | Un solo formato |
| Esqueletos de carga | paquete `shimmer` | `Container` con `AppColors.surfaceMuted` (sin dependencia nueva) | Evita paquete externo y su auditoría de legitimidad |

## Formato COP abreviado (D-05)
`formato.dart` NO tiene helper abreviado: solo `formatearMiles(int)` (línea 128) y `formatearCop(int)` = `'\$ ${formatearMiles(pesos)}'` (línea 139) [VERIFIED: grep]. Hay que añadir `formatearCopAbreviado(int pesos)` en `formato.dart` con tests en `test/formato_test.dart`:
- `< 1.000.000` -> `formatearCop(pesos)` ("$ 950.000").
- `>= 1.000.000` -> `"\$ ${m} M"` con una decimal y coma (colombiano): `"$ 3,8 M"`; `3.800.000 -> "$ 3,8 M"`, `3.000.000 -> "$ 3 M"` (quitar ",0"), `12.340.000 -> "$ 12,3 M"`.
- Truncar (no redondear) a una decimal con enteros: `final decimas = pesos ~/ 100000; entero = decimas ~/ 10; dec = decimas % 10;` para no mostrar de más (ej. 3.960.000 -> "$ 3,9 M"). [ASSUMED: truncar vs redondear; el mockup solo muestra 3,8 M. Confirmar en UI-SPEC.]
- Cuándo abreviar: la tarjeta es ~1/3 del ancho (≈100 dp). Regla simple y determinista: abreviar siempre que `pesos >= 1.000.000` (no medir texto en runtime). Usar `Semantics(label: formatearCop(pesos))` con el valor completo para lectores de pantalla y para el tap-hint.
Las pruebas de widget deben buscar el texto exacto abreviado.

## DASH-04: Inventario del barrido

### Pantallas/features existentes (conteo desde `lib/features`)
| Feature | Archivos | Líneas | `TextButton` crudo | `ElevatedButton`/Outlined | `AppBar(`/`TextField(`/`Chip(` crudos | `Color(0x`/`Colors.` Material | `fontSize:` | `EdgeInsets` con literal |
|---|---|---|---|---|---|---|---|---|
| appointments | 29 | 5.782 | 11 | 2* | 0/0/0 | 0/0 | 0 | 2 (`day_strip.dart`) |
| billing | 34 | 7.533 | 14 | 0 | 0/0/0 | 0/0 | 11 (PDF) | 4 (PDF) |
| vaccination | 40 | 6.118 | 0 | 0 | 0/0/0 | 0/0 | 12 (PDF) | 5 (PDF 4 + `dosis_card.dart` 1) |
| inventory | 19 | 3.973 | 5 | 2* | 0/0/0 | 0/0 | 0 | 0 |
| plan | 16 | 2.180 | 2 | 0 | 0/0/0 | 0/0 | 0 | 0 |
| team | 18 | 2.174 | 5 | 0 | 0/0/0 | 0/0 | 0 | 0 |
| patients | 13 | 2.155 | 0 | 0 | 0/0/0 | 0/0 | 0 | 0 |
| clients | 9 | 1.623 | 0 | 0 | 0/0/0 | 0/0 | 0 | 0 |
| clinical_history | 10 | 1.223 | 0 | 0 | 0/0/0 | 0/0 | 2 (PDF) | 0 |
| clinic | 8 | 953 | 0 | 0 | 0/0/0 | 0/0 | 0 | 0 |
| auth | 8 | 795 | 2 | 0 | 0/0/0 | 0/0 | 0 | 1 (`client_home_screen.dart`: 24) |
| home | 4 | 535 | 0 | 0 | 0/0/0 | 0/0 | 0 | 0 |
*Los `Elevated/Outlined` listados por el primer conteo se refieren a `OutlinedButton`/`FilledButton`; el segundo conteo (solo `ElevatedButton`) da 0 fuera de `core/`. Revisar `appointments` e `inventory` por `OutlinedButton`/`FilledButton`.

Resumen de grep (todo `lib/`): `Color(0x`: 0. `Colors.xxx` Material no transparente: 0 (los 400+ "Colors." son `AppColors.`). `fontSize:`: solo `app_typography.dart` (tema) y los 3 `*_pdf_service.dart` (paquete `pdf`, no Flutter; legítimos). `EdgeInsets` literales de UI: `day_strip.dart` (2, 6), `client_home_screen.dart` (24), `main.dart` (24), `dosis_card.dart` (12), `app_status_chip.dart` (vertical: 6). `TextButton` crudo fuera de `core/`: 47 usos en 19 archivos (lista en los planes de abajo); `AppButton(variant: text)` es el reemplazo y `AppButton.destructive` ya cubre el rojo con 48 dp. Los cuadros de 40x40 (`cobro_fila.dart`, `movimiento_tile.dart`) son decorativos (íconos), no táctiles; verificar en la auditoría. `BorderRadius.circular(<literal>)`: 1 uso. Confirmado que el mapa de widgets de `core` contiene solo: `AppTopBar`, `AppButton`, `AppCard`, `AppFilterChip`, `AppTextField`, `AppPhotoPicker`, `AppStatusChip`, `DosisEstadoChip`, `VetAvatar`. No existe un widget de tarjeta de métrica: se crea en `home/presentation/widgets/` (o en `core/widgets/cards/app_metric_card.dart`, preferible si otras pantallas lo van a usar; decisión del UI-SPEC).

Conclusión: la mayor parte del trabajo de DASH-04 es (a) 47 `TextButton` -> `AppButton`, (b) la auditoría de contraste/48 dp/semántica/formatos que ningún grep captura, (c) los WARN heredados de VET-57/VET-78, (d) pantallas del flujo de auth y la pantalla de cliente (`client_home_screen`) que quizá no usan `AppTopBar`/`AppCard`. Calibrar el esfuerzo a la auditoría; no asumir un refactor masivo.

### `ComingSoonScreen`
Sin usos: `grep` en `lib/` y `test/` devuelve solo la definición (`coming_soon_screen.dart`) y dos doc comments (`clientes_list_screen.dart:16`, `pacientes_list_screen.dart:21`). No aparece en `app_router.dart`. Acción: borrar `coming_soon_screen.dart`, reescribir los 2 comentarios para no mencionarla, y `grep -rn "Próximamente" lib test` debe devolver 0. Ojo: el texto "Próximamente" también aparece dentro de la propia pantalla (línea 17); comprobar que `mas_screen.dart` no tiene entradas "Próximamente" ni ítems deshabilitados (`grep -n` de la auditoría).

### Reparto en planes sin solapar archivos (propuesta)
Wave A (dependen entre sí; primero):
1. **Auditoría** `vetapp-brand-ui` por feature (solo lectura; produce hallazgos BLOCKER/WARN/INFO en `.planning/phases/08-.../08-AUDITORIA.md` y Linear para INFO). Sin archivos de `lib/`.
Wave B (paralelo; cada plan es dueño exclusivo de su carpeta, sin tocar `core/`):
2. **Backend + dominio de Inicio**: `schema.sql`, smoke, `verify_live_schema.sh`, repo/provider de resumen, `formatearCopAbreviado`, `inicio_revision.dart` y los incrementos en `CitaActions`, `RegistrarConsulta`, `invalidarCobros` y los 2 sitios de alta (toca `appointments/presentation/providers/citas_providers.dart`, `clinical_history/.../consultas_providers.dart`, `billing/.../cobros_providers.dart`, `patients/.../mascota_form_screen.dart`, `clients/.../nuevo_cliente_mascota_screen.dart`). **Estos 5 archivos solo los toca este plan**; los planes de barrido de esas features deben dejar esos archivos fuera o ir después.
3. **UI de Inicio** (`home/**`, `app_router.dart` si hace falta, borra `coming_soon_screen.dart`, `test/inicio_screen_test.dart`). Depende de 2.
Wave C (paralelo, tras la auditoría y tras 2 por los archivos compartidos):
4. appointments (+ `proximas()` si no entró en el plan 2; incluye `day_strip.dart`) ; 5. billing ; 6. vaccination ; 7. inventory + plan ; 8. team + patients + clients + clinic + clinical_history + auth + `main.dart` + `client_home_screen`.
Cambios en `lib/core/**` (si la auditoría pide tocar `AppButton`, `AppCard`, `AppStatusChip`): un único plan dueño de `core/` en la wave B o C-previa, y los planes por feature solo consumen. Cada plan de feature incluye sus tests de widget existentes (hay 127 archivos de test; el cambio `TextButton` -> `AppButton` puede romper `find.byType(TextButton)` en tests: grep antes).

## Common Pitfalls

### Pitfall 1: Mes en UTC en vez de Bogotá
**What goes wrong:** Una consulta registrada el último día del mes a las 21:00 Bogotá cae en el mes siguiente en UTC.
**How to avoid:** límites calculados con `at time zone 'America/Bogota'` (ver SQL) y un check de smoke en el borde (00:00 Bogotá del día 1 incluida; 23:59 del día anterior excluida).

### Pitfall 2: `consultas` sin `clinica_id`
**What goes wrong:** Un count directo sobre `consultas` en una RPC `security definer` (que salta RLS) cuenta consultas de todas las clínicas.
**How to avoid:** join explícito con `mascotas.clinica_id = v_clinica`; smoke con una segunda clínica.

### Pitfall 3: `security definer` salta RLS
**What goes wrong:** Sin la comprobación `es_veterinario()` y `mi_clinica_id()` la RPC filtra datos.
**How to avoid:** copiar el guard de `cobros_resumen`; `revoke ... from public, anon`; `grant ... to authenticated`; `set search_path = public`.

### Pitfall 4: `ref.invalidate` durante el build
**What goes wrong:** Riverpod lanza si se invalida en `build`/`didUpdateWidget`.
**How to avoid:** `addPostFrameCallback` (como `app_shell.dart`).

### Pitfall 5: Providers `autoDispose` bajo `StatefulShellBranch`
**What goes wrong:** La rama de Inicio sigue montada, así que el provider no se recarga solo al volver (lo dicen los comentarios de `invalidar_vacunas.dart`/`invalidarCobros`).
**How to avoid:** el contador + el hook de `AppShell` + `onResume`.

### Pitfall 6: Cambio `TextButton` -> `AppButton` rompe tests
**How to avoid:** `grep -rn "TextButton" test` antes de cada plan de feature; actualizar los finders.

### Pitfall 7: Tarjetas de 100 dp con texto escalado
**What goes wrong:** con `textScaler` 1.3+ o "$ 3,8 M" en Caprasimo se desborda.
**How to avoid:** `FittedBox(fit: BoxFit.scaleDown)` en la cifra y prueba de widget con `textScaler` alto; etiqueta de 1 línea o 2 con ellipsis.

### Pitfall 8: Tests con red
No usar `Supabase.instance` en tests: los fakes de `test/helpers/` (`fake_auth`, `fake_plan`, `fake_vacunas`, `fake_inventario`, `router_harness`) y `inicio_screen_test.dart` ya existente muestran el patrón. Añadir `FakeInicioRepository` en `test/helpers/`.

## Code Examples

### Repositorio de resumen
```dart
// Source: patrón de supabase_cobros_repository.dart resumen() (leer allí el parseo exacto)
Future<ResumenInicio> resumen() async {
  try {
    final rows = await _client.rpc('inicio_resumen') as List;
    final r = rows.first as Map<String, dynamic>;
    return ResumenInicio(
      consultasMes: (r['consultas_mes'] as num).toInt(),
      ingresosMes: (r['ingresos_mes'] as num).toInt(),
      pacientesNuevos: (r['pacientes_nuevos'] as num).toInt(),
    );
  } on PostgrestException {
    throw const InicioFailure('No pudimos cargar el resumen. Intenta de nuevo.');
  } catch (_) {
    throw const InicioFailure('Sin conexión. Inténtalo de nuevo cuando tengas señal.');
  }
}
```
(Seguir la convención del repo: un `InicioFailure implements Exception` con `message`, y la UI captura solo ese tipo.)

### Etiqueta de día
```dart
// core/utils/formato.dart o formato_hora.dart (verificar si ya hay algo en formato_hora.dart)
const _dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
String etiquetaDia(DateTime dia, DateTime hoy) {
  if (mismoDia(dia, hoy)) return 'Hoy';
  if (mismoDia(dia, hoy.add(const Duration(days: 1)))) return 'Mañana';
  return '${_dias[dia.weekday - 1]} ${dia.day.toString().padLeft(2, '0')}/${dia.month.toString().padLeft(2, '0')}';
}
```
Revisar `core/utils/formato_hora.dart` antes de crear: puede que ya exista un helper de etiqueta de día usado en la agenda (reutilizar si sí).

## State of the Art

| Old | Current | Impact |
|-----|---------|--------|
| Roadmap: "dashboard mockeado de 1400 líneas" | Ya no existe; Inicio tiene 116 líneas | Se reescribe sobre la base actual |
| `ComingSoonScreen` en `/pacientes`, `/clientes` | Reemplazada por listas reales | Código muerto; borrar |
| Riverpod `StateNotifier` | `Notifier`/`AsyncNotifier` (Riverpod 3) | Usar `Notifier<int>` para el contador |

## Runtime State Inventory
Fase aditiva (no es renombre/migración). Datos almacenados: ninguno nuevo (RPC solo lee). Config de servicios vivos: la RPC debe aplicarse al Supabase vivo (paso de "live apply" como en 07-17; pegar `schema.sql` o la porción nueva en el SQL Editor / MCP de Supabase según las reglas del proyecto). Estado OS, secretos, artefactos: ninguno.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK / `flutter test` | tests de widget | ✓ (proyecto activo) | stable | — |
| Supabase vivo (proyecto) | live apply + `verify_live_schema.sh` + smoke | ✓ (usado en 07-17) | — | Si no hay acceso, dejar el check de apply como paso humano |
| `psql`/SQL Editor para smoke | rls_smoke_test.sql | ✓ (usado en fases previas) | — | pegar en el SQL Editor y leer "RLS SMOKE: PASS" |

(No se ejecutó `flutter --version` en esta investigación; se asume instalado por el historial de 7 fases.)

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) + fakes en `test/helpers/` (127 archivos de test) ; smoke SQL en `supabase/tests/rls_smoke_test.sql` |
| Config file | `analysis_options.yaml` (flutter_lints); sin config de test |
| Quick run command | `flutter test test/inicio_screen_test.dart test/formato_test.dart` |
| Full suite command | `flutter test` + `flutter analyze` + smoke SQL (total esperado hoy: 293 checks) |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DASH-01 | RPC cuenta consultas por mes Bogotá y borde 00:00 | SQL smoke | smoke bloque nuevo (T31+) | ❌ Wave 0 |
| DASH-01 | RPC ignora otra clínica (consultas/cobros/mascotas) | SQL smoke | idem | ❌ |
| DASH-01 | ingresos = `cobros_resumen().cobrado_mes`; excluye anulada, cotización, pendiente y mes anterior | SQL smoke | idem | ❌ |
| DASH-01 | pacientes nuevos por `created_at` del mes | SQL smoke | idem | ❌ |
| DASH-01 | no veterinario o sin clínica -> `insufficient_privilege`; anon sin execute; colega solo lectura SÍ ejecuta | SQL smoke | idem (ampliar T30) | ❌ |
| DASH-01 | clínica vacía devuelve ceros | SQL smoke | idem | ❌ |
| DASH-01 | tarjetas muestran cifras con `formatearMiles` y abreviado; tap navega (Ingresos/Nuevos), Consultas no | widget | `flutter test test/inicio_screen_test.dart` | ✅ existe, ampliar |
| DASH-01 | `formatearCopAbreviado` (950.000, 1.000.000, 3.800.000, 3.000.000, 12.340.000, 3.960.000) | unit | `flutter test test/formato_test.dart` | ✅ existe, ampliar |
| DASH-01 | mapeo del repositorio (`rows.first` -> `ResumenInicio`) y errores | unit | `flutter test test/supabase_inicio_repository_test.dart` | ❌ Wave 0 |
| DASH-02 | `proximas()` pide `estado in (pendiente,confirmada)`, `gte` ahora, límite 5 | unit (fake client, ver `supabase_cita_repository_test.dart`) | `flutter test test/supabase_cita_repository_test.dart` | ✅ existe, ampliar |
| DASH-02 | filas con separadores Hoy/Mañana/lun dd/mm; vacío con "No tienes citas próximas." y "Agendar cita"; color vet solo en multi-vet; tap -> `/agenda/:id` | widget | `flutter test test/inicio_screen_test.dart` | ✅ ampliar |
| DASH-02 | etiqueta de día | unit | `flutter test test/formato_hora_test.dart` o nuevo | ✅/❌ |
| DASH-03 | 4 accesos con 48 dp; rutas correctas; "Cobro" no "Factura"; en solo lectura candado + hoja del plan | widget | `flutter test test/inicio_screen_test.dart` | ✅ ampliar |
| DASH-03/D-13 | tras `CitaActions.crear`, `RegistrarConsulta`, `invalidarCobros`, alta de mascota el contador sube y el resumen recarga | unit | `flutter test test/inicio_invalidacion_test.dart` (modelo: `cobros_invalidacion_test.dart`, `vacunas_invalidacion_test.dart`) | ❌ Wave 0 |
| D-14 | esqueleto, error por bloque con "Reintentar" sin tumbar los demás, mensaje de sin conexión | widget | `flutter test test/inicio_screen_test.dart` | ✅ ampliar |
| DASH-04 | sin `ComingSoonScreen`/"Próximamente" | grep (gate) | `grep -rn "ComingSoonScreen\|Próximamente" lib test` = 0 | — |
| DASH-04 | sin `Color(0x`, `Colors.<material>`, `AppBar(`, `TextField(` y `TextButton(` crudos fuera de `core/` | grep (gate) | script de gate con los patrones de arriba | ❌ Wave 0 |
| DASH-04 | tema consistente / contraste | unit/widget | `flutter test test/app_theme_test.dart` | ✅ |
| DASH-04 | áreas táctiles >= 48 en pantallas nuevas | widget (`tester.getSize`) | en `inicio_screen_test.dart` | ✅ ampliar |
| DASH-04 | verificación visual en emulador (ambos modos) | manual/QA agent `vetapp-qa` | captura en `qa/` | manual (justificado: apariencia) |

### Sampling Rate
- **Per task commit:** `flutter analyze` + el test del archivo tocado.
- **Per wave merge:** `flutter test` completo (regla del proyecto: verificar y documentar cada plan; ✅/❌ por tarea en VALIDATION.md).
- **Phase gate:** `flutter test` + `flutter analyze` + smoke SQL en vivo con el total nuevo (293 + checks nuevos) + `verify_live_schema.sh` + gates de grep de DASH-04.

### Smoke SQL: checks nuevos propuestos (total 293 -> 293 + N)
Nuevo bloque (siguiente a T30; usar el siguiente número libre y el mismo estilo `checks := checks + 1; begin ... exception when others then failures := failures || ...`): (1) conteo de consultas del mes con borde Bogotá, (2) aislamiento entre clínicas, (3) ingresos: pagada del mes cuenta; anulada/cotización/pendiente/mes anterior no, (4) paridad con `cobros_resumen`, (5) pacientes nuevos, (6) ceros en clínica vacía, (7) guard de privilegios (no vet/sin clínica -> `insufficient_privilege`), (8) privilegios: anon no ejecuta, authenticated sí (añadir `public.inicio_resumen()` a la lista de T30), colega solo lectura sí. Son ~8 checks (nuevo total ≈ 301; el planner fija el número exacto). Actualizar el encabezado del archivo ("Total esperado: ...") y `verify_live_schema.sh`: lista de RPC en la línea ~110 y los dos `case` de las líneas ~209/238 donde se trata el 404 de RPC nuevas, copiando cómo se tratan `cobros_resumen` y compañía.

### Wave 0 Gaps
- [ ] `test/supabase_inicio_repository_test.dart` — mapeo y errores de la RPC.
- [ ] `test/inicio_invalidacion_test.dart` — contador tras cada mutación (modelo `cobros_invalidacion_test.dart`).
- [ ] `test/helpers/fake_inicio.dart` — `FakeInicioRepository` + overrides.
- [ ] Ampliar `test/formato_test.dart`, `test/inicio_screen_test.dart`, `test/supabase_cita_repository_test.dart`.
- [ ] Bloque nuevo en `supabase/tests/rls_smoke_test.sql`.
- [ ] Script/gate de grep de DASH-04.
- Framework install: ninguno.

## Security Domain

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no (sin cambios) | sesión Supabase existente |
| V3 Session Management | no | — |
| V4 Access Control | **sí** | RPC `security definer` con `es_veterinario()` + `mi_clinica_id()`; join por `mascotas.clinica_id`; RLS para citas |
| V5 Input Validation | bajo (la RPC no recibe parámetros) | sin entradas de usuario; sin SQL dinámico |
| V6 Cryptography | no | — |

### Known Threat Patterns
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Fuga entre clínicas vía definer | Information disclosure | filtro de clínica en cada subconsulta + smoke con segunda clínica |
| Ejecución por `anon` | Elevation | `revoke all from public, anon`; check en T30 |
| search_path hijack en definer | Tampering | `set search_path = public` |
| Fuga de datos en caché de UI entre sesiones | Information disclosure | providers `autoDispose` y `authProfileProvider` se reinician al cerrar sesión; comprobar que `inicioRevisionProvider` no guarda datos (solo un entero) |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | No hace falta índice nuevo (volumen de clínica pequeña) | Patrón 1 | Latencia en clínicas grandes; fácil de añadir después |
| A2 | `inFilter` existe con ese nombre en la versión resuelta de postgrest-dart | Patrón 2 | Cambio trivial al método `.filter('estado','in',...)` |
| A3 | Los fallos de red no llegan como `PostgrestException` | Patrón 5 | El mensaje de "sin conexión" podría mostrarse en un error de servidor; mitigar con `catch` tipado (`SocketException`/`ClientException`) |
| A4 | Truncar (no redondear) a 1 decimal en "$ 3,8 M" | Formato COP | Diferencia de 0,1 M en pantalla; confirmar en UI-SPEC |
| A5 | `clockProvider` existe y es la fuente de "ahora" para tests | Patrón 2 | Hay que leer `core/data/clock_provider.dart`; si es otro formato, adaptar |
| A6 | "Ingresos" usa el mismo corte `pagada_el <= hoy` que `cobros_resumen` | Patrón 1 | Idéntico por copia; el smoke de paridad lo detecta |

## Open Questions (RESOLVED)

1. **¿Tarjeta de métrica en `core/widgets` o en `home/`?** RESOLVED: en `home/` (`lib/features/home/presentation/widgets/metricas_mes.dart`, `MetricasMes`/`MetricaTarjeta`). El UI-SPEC prohíbe widgets compartidos nuevos en `lib/core/widgets` en esta fase (08-06).
2. **"Consultas" no navega: ¿se ve como tarjeta táctil?** RESOLVED: no. `AppCard(onTap: null)`, sin chevron, sin ripple y sin rol de botón (UI-SPEC §3.3; probado en 08-06).
3. **Alcance exacto del plan de `core/`.** RESOLVED con la línea base de marca (08-BRAND-BASELINE): 7 temas de componente, el color AA de los botones de texto, los literales de espaciado de core, el modo cuadrado de `AppButton` para los dos steppers y el borrado de `ComingSoonScreen` (08-02). La re-auditoría del cierre (08-13) confirma que no queda nada más.

## Project Constraints (from CLAUDE.md)
- Stack Flutter + Supabase; diseño del mockup aprobado (terracota/crema, Caprasimo + Figtree); backend real, sin mocks.
- Colombia: COP y `dd/mm/aaaa`.
- Dominio en español; usecases sin sufijo `UseCase`; errores del data layer traducidos a un `*Failure` con mensaje en español (doble catch: específico + genérico); la UI captura solo el `Failure`.
- `///` solo en entidades de dominio, interfaces y widgets reutilizables de `core/widgets`; no documentar `_FooState`.
- Imports relativos dentro de `lib/`, sin barrel files; `flutter_lints` sin desactivar reglas.
- Todo cambio de archivos va por un workflow GSD (`/gsd-execute-phase`).
- Memoria del proyecto: verificar y documentar cada plan (gates + `flutter test` completo + ✅/❌ por tarea en VALIDATION.md); `.planning/business/` y `market/` son locales; marca "Rondavet" no se renombra aún; el usuario solo tiene un iPhone (verificaciones en emulador + Safari); autonomía: tomar la opción recomendada, parar solo ante smoke pastes y seguridad.

## Sources

### Primary (HIGH confidence) — lectura directa del repo
- `supabase/schema.sql`: `cobros_resumen` (5356-5379), `_hoy_bogota` (2045), `consultas` (473-520), `mascotas` (60-76), `citas` (548-583), `cobros` (4579-4690), `registrar_consulta` (1008-1030), `vacunas_resumen` (2845).
- `supabase/tests/rls_smoke_test.sql` (T25, T30, total esperado 293), `supabase/tests/verify_live_schema.sh`.
- `lib/features/home/**`, `appointments/**` (repositorio, providers, `estado_cita_ui.dart`, `agenda_routes.dart`), `billing/.../cobros_providers.dart`, `team/.../team_providers.dart`, `vaccination/.../invalidar_vacunas.dart`, `core/utils/formato.dart`, `zona_bogota.dart`, `core/widgets/**`, `core/router/app_router.dart`.
- `.planning/phases/08-.../08-CONTEXT.md`, `.planning/REQUIREMENTS.md`, `.planning/design/DESIGN-REFERENCE.md` (pantalla 2).

### Secondary / Tertiary
- Ninguna fuente externa consultada: la fase no introduce librerías nuevas. No se leyeron `vetapp-mobile-designs.html`, `STATE.md` ni `arquitecto-vetapp/SKILL.md` en esta pasada; el planner debe leer el skill (`modelo-dominio.md`) antes de planificar.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH (sin cambios; todo en el repo)
- RPC y SQL: HIGH en columnas y regla de ingresos (leído del schema); MEDIUM en rendimiento (A1)
- Citas / invalidación: HIGH (patrones y sitios verificados por grep)
- Barrido DASH-04: MEDIUM (greps fiables; falta la auditoría de contraste/semántica/48 dp)
- Formato abreviado: MEDIUM (decisión de truncar, A4)

**Research date:** 2026-11-16
**Valid until:** 30 días (código propio estable; revalidar si cambian `cobros_resumen` o el router)
