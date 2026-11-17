# Phase 8: Dashboard y Diseño Visual - Pattern Map

**Mapped:** 2026-11-17
**Files analyzed:** 27 new/modified files (plus the 19-file `TextButton` sweep, grouped)
**Analogs found:** 26 / 27. The only file with no analog is the DASH-04 grep gate script.
**Inputs read:** `08-CONTEXT.md`, `08-RESEARCH.md`, `08-BRAND-BASELINE.md`, `08-UI-SPEC.md` (now final).

> **Naming locked by UI-SPEC (overrides RESEARCH):**
> - The short COP helper is **`formatearCopCorto(int pesos)`** in `lib/core/utils/formato.dart`. It is **not** `formatearCopAbreviado`.
> - Widgets: `inicio_encabezado.dart`, `metricas_mes.dart` (`MetricasMes`, `MetricaTarjeta`), `accesos_rapidos.dart` (`AccesosRapidos`, `AccesoRapido`), `proximas_citas.dart` (`ProximasCitas`, `ProximaCitaFila`) and `bloque_error.dart` (`BloqueError`). All go in `lib/features/home/presentation/widgets/`. **No new `lib/core/widgets` file.**
> - Both `inicioResumenProvider` **and `proximasCitasProvider`** live in `lib/features/home/presentation/providers/inicio_providers.dart`. They do **not** go in `citas_providers.dart`, as RESEARCH suggested.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `supabase/schema.sql`: add `inicio_resumen()` at the end, before `notify pgrst` | migration (RPC) | request-response, read aggregate | `cobros_resumen()` in `schema.sql:5356-5379` plus grants `:5638-5639` | exact |
| `supabase/tests/rls_smoke_test.sql`: new block T33+ | test (SQL) | batch | T25 `:6196-6250`, T30 `:6509-6562`, header `:38`, footer `:6625-6633` | exact |
| `supabase/tests/verify_live_schema.sh` | test (shell) | request-response | RPC loop `:110`, `cobros_resumen)` case `:209-210`, 404 case `:238-240` | exact |
| `lib/features/home/domain/resumen_inicio.dart` (`ResumenInicio`) | model | n/a | `ResumenCobros` in `billing/domain/entities/cobro.dart:218-228` | exact |
| `lib/features/home/domain/inicio_failure.dart` (`InicioFailure`) | model (error) | n/a | `billing/domain/cobro_failure.dart` | role-match |
| `lib/features/home/data/supabase_inicio_repository.dart` | service (repo) | request-response | `SupabaseCobrosRepository._run`/`_filas`/`resumen()` at `supabase_cobros_repository.dart:31-34, 81-100, 137-146` | exact |
| `lib/features/home/presentation/providers/inicio_providers.dart` | provider | request-response | `cobros_providers.dart:11-13, 36-38`, `plan_providers.dart:24-26` | exact |
| `lib/core/data/inicio_revision.dart` | store (counter) | event-driven | `CitasRevision` in `citas_providers.dart:33-45` | exact |
| `lib/features/appointments/data/repositories/supabase_cita_repository.dart`: add `proximas()` | service (repo) | request-response | `entre()` at the same file, `:25-41` | exact |
| `test/helpers/fake_citas.dart`: add `proximas()` override | test helper | n/a | `FakeCitaRepository.entre` at `fake_citas.dart:190-200` | exact |
| `test/helpers/fake_inicio.dart` (`FakeInicioRepository`) | test helper | n/a | `FakeCobrosRepository` at `fake_cobros.dart:100-171, 277-290` | exact |
| `lib/features/home/presentation/screens/inicio_screen.dart` (rewrite) | component (screen) | request-response | current `inicio_screen.dart:1-116`, `RefreshIndicator` in `cobros_screen.dart:260-275` | exact |
| `.../home/presentation/widgets/metricas_mes.dart` | component | request-response | `billing/presentation/widgets/resumen_cobros_card.dart:39-189` | exact |
| `.../home/presentation/widgets/accesos_rapidos.dart` | component | event-driven (tap) | Vacunar button in `inicio_screen.dart:27-37, 93-105`, plus `control_escritura.dart` | exact |
| `.../home/presentation/widgets/proximas_citas.dart` | component (list) | request-response | `appointments/presentation/widgets/cita_card.dart:44-125`, `VetAvatar` | exact |
| `.../home/presentation/widgets/inicio_encabezado.dart` | component | n/a | greeting `AppCard` in `inicio_screen.dart:72-88` | exact |
| `.../home/presentation/widgets/bloque_error.dart` | component | n/a | error branch in `resumen_cobros_card.dart:70-89` | role-match |
| `lib/features/home/presentation/app_shell.dart` (focus hook) | component | event-driven | its own `didUpdateWidget` at `app_shell.dart:22-40` | exact |
| `lib/core/utils/formato.dart`: add `formatearCopCorto` | utility | transform | `formatearMiles`/`formatearCop` at `formato.dart:125-139` | exact |
| `lib/core/theme/app_theme.dart`: component themes | config | n/a | `textButtonTheme`/`chipTheme`/`navigationBarTheme` at `app_theme.dart:98-154` | exact |
| `lib/core/widgets/buttons/app_button.dart` | component (core) | n/a | itself: the `destructive` variant **already exists** at `:6, :70-80` | exact |
| `TextButton` → `AppButton` sweep (19 files) | component | n/a | `cita_detail_screen.dart:414-426` (destructive), `cita_form_screen.dart:327` (text) | exact |
| `citas_providers.dart` (`CitaActions`: increment the Inicio counter) | provider | event-driven | its own `citasRevisionProvider` increments at `:94, :123, :129, :135` | exact |
| `clinical_history/.../consultas_providers.dart` (`RegistrarConsulta`) | provider | event-driven | its own invalidations at `:70-77` | exact |
| `billing/.../cobros_providers.dart` (`invalidarCobros`) | provider | event-driven | its own `invalidarCobros` at `:82-104` | exact |
| `patients/.../mascota_form_screen.dart:185-190`, `clients/.../nuevo_cliente_mascota_screen.dart:166-170` | component | event-driven | the `ref.invalidate(miPlanProvider)` line next to it | exact |
| Delete `home/presentation/screens/coming_soon_screen.dart` and fix 2 doc comments | n/a | n/a | n/a | n/a |
| Tests: `test/supabase_inicio_repository_test.dart`, `test/inicio_invalidacion_test.dart`, plus extensions to `inicio_screen_test.dart`, `formato_test.dart`, `app_theme_test.dart` | test | n/a | `supabase_cita_repository_test.dart`, `cobros_invalidacion_test.dart:36-80`, `inicio_screen_test.dart:1-60` | exact |
| DASH-04 grep gate script | test (gate) | batch | none (grep lines are in UI-SPEC `:523-534`) | no analog |

---

## Pattern Assignments

### 1. `inicio_resumen()` (migration, read aggregate)

**Analog:** `supabase/schema.sql:5356-5379` (`cobros_resumen`). Copy its header, guard and `#variable_conflict` exactly:
```sql
-- RPC: cobros_resumen (tarjeta de Cobros, D-17): cobrado este mes de Bogotá, por cobrar y pendientes. Solo cuentas
-- de cobro; las anuladas y las cotizaciones nunca cuentan.
drop function if exists public.cobros_resumen();
create or replace function public.cobros_resumen()
returns table (cobrado_mes bigint, por_cobrar bigint, pendientes int)
language plpgsql
stable
security definer set search_path = public
as $$
#variable_conflict use_column
declare
  v_clinica uuid := public.mi_clinica_id();
  v_hoy date := public._hoy_bogota();
begin
  if not public.es_veterinario() or v_clinica is null then
    raise exception 'Solo un veterinario de una clínica puede ver los cobros.' using errcode = 'insufficient_privilege';
  end if;

  return query
    select
      coalesce(sum(total_cop) filter (where estado = 'pagada' and pagada_el >= date_trunc('month', v_hoy)::date and pagada_el <= v_hoy), 0)::bigint,
      ...
    from public.cobros
    where clinica_id = v_clinica and tipo = 'cuenta_cobro';
end;
$$;
```

**Ingresos parity:** the ingresos sub-select must use the same predicate, character for character: `tipo='cuenta_cobro' and estado='pagada' and pagada_el >= date_trunc('month', v_hoy)::date and pagada_el <= v_hoy`. Do not touch `cobros_resumen`.

**Helpers it relies on:**
- `_hoy_bogota()` at `schema.sql:2045-2047` (`(now() at time zone 'America/Bogota')::date`).
- `es_veterinario()`/`mi_clinica_id()`, redefined in the Phase 4.1 block (`:1090-1100`) to filter active members.

**Grants pattern** (`schema.sql:5638-5639`). Put them next to the new function and before the final `notify pgrst, 'reload schema';` (`:5649`):
```sql
revoke all on function public.cobros_resumen() from public, anon;
grant execute on function public.cobros_resumen() to authenticated;
```

**SQL rules:**
- Full body: RESEARCH Pattern 1 (`08-RESEARCH.md:144-177`).
- `consultas` has no `clinica_id`: always `join public.mascotas m on m.id = c.mascota_id where m.clinica_id = v_clinica`.
- Compare `c.fecha` and `mascotas.created_at` against timestamptz bounds computed `at time zone 'America/Bogota'`. Never cast the column.

### 2. Smoke block (`rls_smoke_test.sql`)

**Analog T25** (`:6196-6250`). Per-check skeleton: impersonate, act, assert, reset role.
```sql
  checks := checks + 1;
  begin
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
    perform set_config('request.jwt.claims', json_build_object('sub', t_vet_otro, 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
    ...
    select * into t_row from public.cobros_resumen();
    if t_row.cobrado_mes is distinct from 100000::bigint or ... then
      failures := failures || format('T25 resumen esperado 100000/50000/1, llegó %s/%s/%s', ...);
    end if;
    perform set_config('role', 'postgres', true);
    perform set_config('request.jwt.claims', '', true);
  exception when others then
    failures := failures || ('T25 error inesperado: ' || sqlerrm);
  end;
```

**What T25 already gives you:**
- An isolated clinic (`t_c_otro`/`t_vet_otro`/`t_cli_otro`) with a paid CC of 100000, a pending one of 50000, a paid-then-voided one, a quote, and a paid one from last month (`:6205-6224`).
- A parity check can then be `select * from inicio_resumen()` vs `select * from cobros_resumen()` for the same JWT.
- Expected ingresos for `t_c_otro` = 100000.

**Privilege check:** copy T30's array loop (`:6516-6539`). Either add `'public.inicio_resumen()'` to a new array in the new block, or to T30's array (which then counts no new check).

**Read-only colleague:**
- Pattern at `:6540-6553`: set `clinica_planes` to read-only, impersonate `t_vet_col`.
- Here the RPC must **succeed** (D-06). Invert the T30 expectation: no exception, so a `when others` means failure.

**Free numbers:**
- T31 and T32 are taken (`:6564`, `:6620`). Start at **T33**.
- Update the header line `:38` ("Total esperado: 293" → new total) and add a "Fase 8 (bloque T33..)" line.
- Footer `:6625-6633` is unchanged.

### 3. `verify_live_schema.sh`

- `:110` is the RPC `for rpc in ... ; do` list. Append `inicio_resumen` (after `cobros_resumen`).
- `:209-210`: add `cobros_resumen|inicio_resumen)` or a sibling case `inicio_resumen) payload='{}' ;;`.
- `:238`: add `inicio_resumen` to the `case "$rpc" in crear_cuenta_cobro|...|cobros_resumen|...) true` list, so a 404 for anon counts as protected and not "no aplicada". Copy the comment style at `:239`.

### 4. `ResumenInicio` + `InicioFailure` (domain)

**Analog:** `billing/domain/entities/cobro.dart:218-228`.
```dart
class ResumenCobros {
  const ResumenCobros({
    this.cobradoMes = 0,
    this.porCobrar = 0,
    this.pendientes = 0,
  });

  final int cobradoMes;
  final int porCobrar;
  final int pendientes;
}
```
Use `ResumenInicio({this.consultasMes = 0, this.ingresosMes = 0, this.pacientesNuevos = 0})` with a `///` doc comment (it is a domain entity, per CLAUDE.md).

**`InicioFailure`:**
- `class InicioFailure implements Exception { const InicioFailure(this.message, {this.sinConexion = false}); final String message; ... }`.
- Simplified from `cobro_failure.dart` (no `ConLimitePlan`: the RPC never raises LP00x).

### 5. `supabase_inicio_repository.dart` (repo)

**Analog:** `billing/data/repositories/supabase_cobros_repository.dart`.

Imports (`:1-16`). Reuse the network detector through a `show` import, the same way billing does (`:8-9`):
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../inventory/data/repositories/supabase_inventario_repository.dart'
    show esErrorDeRed;
import '../domain/inicio_failure.dart';
import '../domain/resumen_inicio.dart';
```
(Paths are relative from `lib/features/home/data/`. `esErrorDeRed` is at `supabase_inventario_repository.dart:330-333`: `TimeoutException`, `http.ClientException`, or `SocketException` by runtime type.)

Offline copy constant (`:31-34`). Copy the exact D-14 text:
```dart
const String kMensajeSinConexionLectura =
    'Sin conexión. Inténtalo de nuevo cuando tengas señal.';
```

Two-tier catch wrapper (`:81-100`):
```dart
  Future<T> _run<T>(Future<T> Function() op, String generico, {String sinConexion = kMensajeSinConexionLectura}) async {
    try {
      return await op();
    } on PostgrestException catch (e) {
      throw cobroFailureDe(e);
    } catch (e) {
      if (esErrorDeRed(e)) {
        throw CobroFailure(sinConexion, tipo: ErrorCobro.sinConexion);
      }
      throw CobroFailure(generico);
    }
  }

  List<Map<String, dynamic>> _filas(Object? r) => [
    for (final f in (r as List? ?? const [])) f as Map<String, dynamic>,
  ];
```

RPC read (`:137-146`). This is the method to mirror. Note the `isEmpty` fallback and the null-safe `num` casts:
```dart
  Future<ResumenCobros> resumen() => _run(() async {
    final r = _filas(await _client.rpc('cobros_resumen'));
    if (r.isEmpty) return const ResumenCobros();
    final f = r.first;
    return ResumenCobros(
      cobradoMes: (f['cobrado_mes'] as num?)?.toInt() ?? 0,
      ...
    );
  }, _kErrorLectura);
```

**Changes from the RESEARCH example (`08-RESEARCH.md:355-369`):**
- Use `esErrorDeRed` for the offline message, not "every non-Postgrest error". That resolves assumption A3.
- `PostgrestException` maps to `'No pudimos cargar el resumen. Intenta de nuevo.'`.

### 6. `inicio_providers.dart` (providers)

**Analog:** `cobros_providers.dart:11-13, 36-38`.
```dart
final cobrosRepositoryProvider = Provider<SupabaseCobrosRepository>((ref) {
  return SupabaseCobrosRepository(ref.watch(supabaseClientProvider));
});
...
final resumenCobrosProvider = FutureProvider.autoDispose<ResumenCobros>((ref) {
  return ref.watch(cobrosRepositoryProvider).resumen();
});
```

On-resume refresh (`plan_providers.dart:24-26`). Put it inside **both** Inicio providers:
```dart
final miPlanProvider = FutureProvider.autoDispose<MiPlan?>((ref) async {
  final lifecycle = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(lifecycle.dispose);
```
That needs `import 'package:flutter/widgets.dart';`, as in `plan_providers.dart:1`.

**Shape:**
```dart
final inicioResumenProvider = FutureProvider.autoDispose<ResumenInicio>((ref) {
  final lifecycle = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(lifecycle.dispose);
  ref.watch(inicioRevisionProvider);
  return ref.watch(inicioRepositoryProvider).resumen();
});

final proximasCitasProvider = FutureProvider.autoDispose<List<Cita>>((ref) {
  // same lifecycle + revision watch; also ref.watch(citasRevisionProvider)
  final ahora = ref.watch(clockProvider)();      // core/data/clock_provider.dart
  return ref.watch(citaRepositoryProvider).proximas(desdeUtc: ahora, limite: 5);
});
```
- `home` may import `appointments/presentation/providers/citas_providers.dart` (for `citaRepositoryProvider`). Today **no feature imports `features/home/`** (grep-verified), so this keeps the graph acyclic.
- Also watching `citasRevisionProvider` means appointment writes refresh próximas even without the new counter. Keep the `inicioRevisionProvider` increment in `CitaActions` anyway, for consistency with D-13.

### 7. `lib/core/data/inicio_revision.dart` (counter)

**Analog:** `citas_providers.dart:33-45`. Copy it verbatim and rename:
```dart
/// Contador de "las citas cambiaron": se incrementa tras cada escritura
/// exitosa. Los proveedores de recordatorios locales lo escuchan para
/// resincronizarse (04-07).
class CitasRevision extends Notifier<int> {
  @override
  int build() => 0;

  void incrementar() => state++;
}

final citasRevisionProvider = NotifierProvider<CitasRevision, int>(
  CitasRevision.new,
);
```
The file may only import `package:flutter_riverpod/flutter_riverpod.dart` (same rule as `core/data/clock_provider.dart`).

### 8. `SupabaseCitaRepository.proximas()` (repo method)

**Analog:** `entre()` at `supabase_cita_repository.dart:25-41`. The `_select` is at `:17-23`; reuse it as is.
```dart
  /// Citas con `fecha_hora` en `[inicioUtc, finUtc)`, por hora ascendente.
  Future<List<Cita>> entre(DateTime inicioUtc, DateTime finUtc) async {
    try {
      final rows = await _client
          .from('citas')
          .select(_select)
          .gte('fecha_hora', inicioUtc.toUtc().toIso8601String())
          .lt('fecha_hora', finUtc.toUtc().toIso8601String())
          .order('fecha_hora');
      return (rows as List)
          .map((row) => citaDesdeFila(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw CitaFailure(_messageFor(e), limite: limitePlanDe(e));
    } catch (_) {
      throw const CitaFailure('No pudimos cargar la agenda. Intenta de nuevo.');
    }
  }
```

**What to add:**
- `.inFilter('estado', ['pendiente', 'confirmada'])` before `.gte`, and `.limit(limite)` after `.order`.
- `inFilter` **is confirmed** in this postgrest version: it is already used at `supabase_cobros_repository.dart:72`. That resolves assumption A2.
- Generic message: `'No pudimos cargar las próximas citas. Intenta de nuevo.'`.

**Hazard:**
- `FakeCitaRepository implements SupabaseCitaRepository` (`test/helpers/fake_citas.dart:10`). Adding `proximas()` without adding it to the fake **breaks compilation of every test that imports `fake_citas.dart`**.
- The same task must add the fake override. Model it on `fake_citas.dart:190-200` (`entre` logs `consultasEntre`, throws `error`, filters the list): filter to `pendiente`/`confirmada`, `!isBefore(desde)`, sort, `take(limite)`, and log the call.

**Test note:**
- `test/supabase_cita_repository_test.dart` only tests `mensajeErrorCita`/`limitePlanDe` (`:1-60`). There is **no fake Supabase client** in the repo, so the query shape (`inFilter`/`limit`) cannot be unit-tested as RESEARCH claimed.
- Instead, test the fake's semantics and the widget behaviour, and leave the query shape to live QA. Planner: do not promise a "query shape" unit test.

### 9. Fakes: `test/helpers/fake_inicio.dart`

**Analog:** `FakeCobrosRepository` (`fake_cobros.dart:100-171, 277-290`).
```dart
class FakeCobrosRepository implements SupabaseCobrosRepository {
  FakeCobrosRepository({ ..., this.resumenData, this.error, this.errorResumen, ... })
  final llamadas = <({String metodo, Map<String, Object?> args})>[];
  void _log(String metodo, [Map<String, Object?> args = const {}]) =>
      llamadas.add((metodo: metodo, args: args));
  void _falla(Object? propio) {
    final e = propio ?? error;
    if (e != null) throw e;
  }
  @override
  Future<ResumenCobros> resumen() async {
    _log('resumen');
    _falla(errorResumen);
    ...
```
- `FakeInicioRepository implements SupabaseInicioRepository` with `resumenData`, `error`, `llamadas`, and an optional `Completer` to hold the loading state (`bloqueoCrear` idea, `fake_cobros.dart:154-156`).
- Add an `inicioOverrides({...})` list helper like `planOverrides` (used in `inicio_screen_test.dart:46`).

### 10. `inicio_screen.dart` (rewrite)

**Current base (keep):**
- Imports at `:1-17`.
- The `_vacunar` gate at `:27-37`.
- The profile `.when` at `:47-113`.
- The null-profile body at `:49-67`.

The ControlEscritura wiring to reuse for every quick action (`:93-105`):
```dart
              ControlEscritura(
                puedeEscribir: puedeEscribir,
                label: 'Vacunar',
                onTap: () => _vacunar(context, ref),
                child: AppButton(
                  label: 'Vacunar',
                  icon: iconoEscritura(puedeEscribir, Icons.vaccines_outlined),
                  onPressed: () => _vacunar(context, ref),
                ),
              ),
```
And the gate itself (`:27-37`). `asegurarEscritura` comes from `plan/presentation/limite_plan_gate.dart`:
```dart
    if (!await asegurarEscritura(context, ref, plan: ref.read(miPlanProvider).value)) {
      return;
    }
    if (!context.mounted) return;
```

**Pull-to-refresh analog** (`billing/presentation/screens/cobros_screen.dart:260-271`):
```dart
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
```
For Inicio, use a `ListView(physics: const AlwaysScrollableScrollPhysics())`.

**`onRefresh` body:**
- `ref.read(inicioRevisionProvider.notifier).incrementar();`
- `ref.invalidate(resumenVacunasProvider); ref.invalidate(vacunasPendientesProvider); ref.invalidate(resumenInventarioProvider);`
- `await ref.read(inicioResumenProvider.future)` wrapped in `try/catch (_) {}`, so a block error does not throw from the indicator.
- **Hazard:** `invalidarAlertasVacunas(Ref)` and `invalidarInventario(Ref)` take a `Ref`, not a `WidgetRef` (`invalidar_vacunas.dart:21`, `inventario_providers.dart:52`). They cannot be called from the widget. Invalidate the 3 providers directly. Those providers are `resumenVacunasProvider` (watched by `vacunas_pendientes_card.dart:20`), `vacunasPendientesProvider`, and `resumenInventarioProvider` (watched by `stock_bajo_card.dart:20`).

**Routes, all existing:**
| Target | Route | Source |
|---|---|---|
| Cita | `context.push(rutaNuevaCita())` or `'/citas/nueva'` | `agenda_routes.dart:49-68`, root route, required from a root/other-branch context |
| Cobro | `context.push(rutaNuevoCobro())` | `cobros_rutas.dart:11-28`, defaults to `tipo=cc` |
| Paciente | `context.push('/clientes/nuevo')` | `mascota_search_sheet.dart:40`, `clientes_list_screen.dart:84` |
| Ingresos card | `context.go(kRutaCobros)` | `cobros_rutas.dart:6` |
| Pacientes card | `context.go('/pacientes')` | `pacientes_routes.dart:13` |
| Cita row | `context.push('/agenda/${cita.id}')` | `cita_card.dart:74` |
| "Ver agenda" | `context.go('/agenda')` | `agenda_routes.dart:75` |

Confirm `/cobros` is reachable with `go` from Inicio. It is a top-level route (`cobros_routes.dart:21`). Check `router_cobros_cross_shell_test.dart` to decide whether to use `push` or `go`.

### 11. `metricas_mes.dart` (`MetricasMes` / `MetricaTarjeta`)

**Analog:** `billing/presentation/widgets/resumen_cobros_card.dart`. Copy these four pieces:
- **Three-way state** without `.when` (`:44-97`): `async.value != null` → data; `async.hasError` → error; else → skeleton.
- **Text-scale stacking** (`:47`): `final apilar = MediaQuery.textScalerOf(context).scale(10) >= 13;`. UI-SPEC requires the metrics to stack at a 2.0 scale.
- **Number cell** (`:155-168`):
```dart
        Text(titulo, style: t.labelLarge?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(monto, style: t.displaySmall?.copyWith(color: AppColors.primaryText)),
        ),
```
- **Skeleton** (`:178-189`):
```dart
class _Bloque extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 72,
    decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
  );
}
```
UI-SPEC: bar heights 16/28 and `radiusSm`.

**Semantics:**
- `Semantics(label: ..., excludeSemantics: true, child: cuerpo)` (`:99-103`).
- Money semantics helper: `pesosSemantica(int)` at `billing/presentation/widgets/cobro_fila.dart:13`. Importing it from home is fine (acyclic). The UI-SPEC label uses `formatearCop(pesos)` instead (`08-UI-SPEC.md:452`); follow the UI-SPEC.

**Tap and color:**
- Tap: `AppCard(onTap: ...)` (`app_card.dart:7-33`, an InkWell with `radiusMd`).
- The Consultas card passes `onTap: null`, so it has no InkWell and no button role (UI-SPEC `:480`).
- **Dark-mode warning (UI-SPEC `:164`, SW-07):** `resumen_cobros_card` uses light-only `AppColors.textSecondary`/`primaryText`. Inicio must instead read `Theme.of(context).colorScheme.onSurfaceVariant`, and use `primaryHover` for numbers in dark. Copy the layout, not the color constants.

### 12. `accesos_rapidos.dart` (`AccesosRapidos` / `AccesoRapido`)

**Analogs:**
- §10 `ControlEscritura` + `iconoEscritura` + `asegurarEscritura`.
- `control_escritura.dart:11-35`: with `puedeEscribir` it returns `child` untouched; otherwise it adds a single merged `Semantics(button: true, label: semanticaEscritura(...), onTap:, excludeSemantics: true)`.

**Layout:**
- 56px circle + label, per UI-SPEC `:290-305`.
- Size the tap target with `AppSpacing.touchTarget` (48).
- Labels: "Paciente", "Cita", "Cobro", "Vacunar". **Never "Factura".**

### 13. `proximas_citas.dart` (`ProximasCitas` / `ProximaCitaFila`)

**Analog:** `appointments/presentation/widgets/cita_card.dart`.

Imports (`:1-21`), the relevant subset:
```dart
import '../../../../core/utils/formato_hora.dart';
import '../../../../core/utils/zona_bogota.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/status/app_status_chip.dart';
import '../../../../core/widgets/status/vet_avatar.dart';
import '../../../team/presentation/providers/team_providers.dart';
import '../../domain/entities/cita.dart';
import '../estado_cita_ui.dart';
```

Vet mark (`:58-70, 86-93`). Drop the `filtroAgendaProvider` condition (it is agenda-only) and keep only `esClinicaMultiVetProvider`:
```dart
    final marcarVet = ref.watch(esClinicaMultiVetProvider) && ...;
    final activos = ref.watch(miembrosActivosProvider);
    final miembro = activos.where((m) => m.id == cita.veterinarioId).firstOrNull;
    final retirado = activos.isNotEmpty && miembro == null;
    final indices = ref.watch(indicesColorVetProvider);
    final indice = indices[cita.veterinarioId] ?? 0;
    final nombreVet = (cita.veterinarioNombre ?? miembro?.nombre ?? '').trim();
    ...
                VetAvatar(nombre: nombreVet, indice: indice, size: 24, retirado: retirado),
```
- UI-SPEC uses `VetAvatar` at 40px (`:77`).
- `VetAvatar` is in `core/widgets/status/vet_avatar.dart:16-39`. `VetAvatar.colorDe(indice)` is available if a stripe is used.
- The providers are at `team_providers.dart:31-42`.

Row content (`:72-125`):
```dart
      onTap: onTap ?? () => context.push('/agenda/${cita.id}'),
      ...
                Text(rangoHoras(aBogota(cita.fechaHora), aBogota(cita.fin)), style: textTheme.labelLarge),
      ...
              AppStatusChip(status: estadoAStatus(cita.estado)),
      ...
          Text(cita.nombresMascotasCorto, ...),
          Text('${cita.clienteNombre} · ${cita.motivo}', ...),
```
For a single time, use `hora12(aBogota(cita.fechaHora))` (`formato_hora.dart:42`).

**Date separators: reuse an existing helper, do not create `etiquetaDia`.**
- `formato_hora.dart:89-95` already has:
```dart
/// `Hoy, mié 30/09` / `Mañana, jue 01/10` / `vie 02/10`.
String encabezadoDia(DateTime dia, DateTime hoy) {
  if (mismoDia(dia, hoy)) return 'Hoy, ${diaCorto(dia)}';
  final manana = DateTime.utc(hoy.year, hoy.month, hoy.day + 1);
  if (mismoDia(dia, manana)) return 'Mañana, ${diaCorto(dia)}';
  return diaCorto(dia);
}
```
- D-07 wants "Mañana" and "lun 18/11", and no separator for today.
- Use `diaCorto(dia)` (`:51-52`) for the other days. For tomorrow, either render "Mañana" alone (a thin wrapper) or accept `encabezadoDia`'s "Mañana, jue 01/10". Follow the UI-SPEC copy.
- Group by `diaBogota(cita.fechaHora)` (`zona_bogota.dart:18`) compared with `diaBogota(ref.watch(clockProvider)())`. Same idiom as `resumen_cobros_card.dart:45`.

**Empty state:**
- "No tienes citas próximas."
- `AppButton(variant: outline, icon: Icons.add, label: 'Agendar cita')`.
- In read-only mode, wrap it in `ControlEscritura` (it is a write).

### 14. `bloque_error.dart` (`BloqueError`)

**Analog:** the error branch of `resumen_cobros_card.dart:70-89`:
- muted text;
- neutral (not red) per UI-SPEC `:556`;
- `AppButton(variant: AppButtonVariant.text, label: 'Reintentar', expand: false, onPressed: ...)`.
- `onPressed` increments `inicioRevisionProvider` or invalidates the block's provider.
- Icons: `Icons.wifi_off` when `failure.sinConexion`, else `Icons.error_outline`.

### 15. `app_shell.dart` (focus hook)

**Analog:** itself, `app_shell.dart:22-40`:
```dart
const _ramasQueRefrescanPlan = {0, 4};
...
    if (indice != oldWidget.navigationShell.currentIndex &&
        _ramasQueRefrescanPlan.contains(indice)) {
      // Corre durante el build: Riverpod no permite invalidar hasta el frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.invalidate(miPlanProvider);
      });
    }
```
Inside the same callback, add `if (indice == 0) ref.read(inicioRevisionProvider.notifier).incrementar();`.

### 16. `formatearCopCorto` (utility)

**Analog:** `formato.dart:125-139`:
```dart
/// Agrupa [n] con punto como separador de miles (`85000` -> `'85.000'`).
/// Sin formateador con locale: la app nunca llama
/// `initializeDateFormatting` (mismo motivo que [_formatoFecha]).
String formatearMiles(int n) { ... }

/// Dinero en COP como entero, sin decimales ni IVA hasta la Fase 7 (D-16):
/// `85000` -> `'\$ 85.000'`.
String formatearCop(int pesos) => '\$ ${formatearMiles(pesos)}';
```
- Insert it directly after `formatearCop` (`:139`). Keep the same `///` style, with an example in backticks.
- Rules are in UI-SPEC `:254-259`:
  - `< 1.000.000` → `formatearCop`;
  - otherwise truncate to one decimal with a comma and drop `,0`;
  - `>= 1.000.000.000` → `"\$ ${formatearMiles(pesos ~/ 1000000)} M"`;
  - `assert(pesos >= 0)`.
- Test cases: 0, 85.000, 999.999, 1.000.000, 3.849.999, 12.500.000, 999.950.000 and 1.250.000.000. Add them to `test/formato_test.dart`.

### 17. `app_theme.dart` (component themes)

**Analog:** the existing entries in `_base(colorScheme, textTheme)` (`app_theme.dart:53-157`). Every theme reads `colorScheme` and `textTheme`, never `AppColors` directly. That keeps light and dark correct. Pattern to copy (`:98-103, 128-135`):
```dart
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          minimumSize: const Size(AppSpacing.touchTarget, AppSpacing.touchTarget),
        ),
      ),
      ...
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
      ),
```
Plus the `WidgetStateProperty.resolveWith((states) { final selected = states.contains(WidgetState.selected); ... })` idiom (`:141-153`). Use it for the `switchTheme` thumb/track and the `checkboxTheme` fill.

**Add (BRAND-BASELINE cross-cutting 2):**
- `switchTheme`, `checkboxTheme`;
- `floatingActionButtonTheme` (`backgroundColor: primary`, `foregroundColor: onPrimary`, `radiusLg` shape);
- `snackBarTheme`, `dialogTheme` (`DialogThemeData`, `surface`, `radiusLg`, `titleTextStyle: textTheme.titleLarge`);
- `datePickerTheme`, `bottomSheetTheme` (`BottomSheetThemeData`, top `radiusLg`).

**Placement and tests:**
- Insert them alphabetically or after `navigationBarTheme` (`:154`), before `visualDensity`.
- Tests: extend `test/app_theme_test.dart` (112 lines; it asserts on `AppTheme.light.colorScheme.*` and `textTheme` fonts at `:12-63`). Add one `expect` per new theme for light and dark.
- FAB tests (below) keep passing, because `FloatingActionButton` stays: it is themed, not replaced.

### 18. `AppButton` destructive variant + `TextButton` → `AppButton` migration

**The destructive variant already exists.** No core change is needed. `app_button.dart:6, 70-80`:
```dart
enum AppButtonVariant { primary, outline, text, destructive }
...
      AppButtonVariant.destructive => TextButton(
        onPressed: effectiveOnPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.destructive,
          minimumSize: const Size(AppSpacing.touchTarget, AppSpacing.touchTarget),
        ),
        child: child,
      ),
```
It is already used at `cita_detail_screen.dart:421`, `cobro_detail_screen.dart:336`, `cobro_form_screen.dart:539` and `anular_cobro_sheet.dart:162`.

- The only core fix in this widget is the BRAND-BASELINE WARN `app_button.dart:52`: `SizedBox(width: 8)` → `AppSpacing.sm`.
- If a plan wants a filled red destructive (`ElevatedButton` with a `destructive` background), it must be a **new enum value** owned by the core plan. No plan needs one today.

**Migration example (before):** `appointments/presentation/widgets/cita_acciones.dart:94-103`:
```dart
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Volver'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Cancelar cita'),
        ),
      ],
```
**After** (dialog actions must pass `expand: false`, because the default `expand: true` wraps the button in `SizedBox(width: double.infinity)`, `app_button.dart:83`):
```dart
      actions: [
        AppButton(
          label: 'Volver',
          variant: AppButtonVariant.text,
          expand: false,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
        AppButton(
          label: 'Cancelar cita',
          variant: AppButtonVariant.destructive,
          expand: false,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
```
**`TextButton.icon` with destructive style** (`cita_acciones.dart:178-182`): becomes `AppButton(label:, icon:, variant: AppButtonVariant.destructive, onPressed:)`. Keep the surrounding `SizedBox(width: double.infinity)` + `ControlEscritura`, or drop the SizedBox, since `expand: true` already does that.

**Existing text-variant reference:** `cita_form_screen.dart:327`, `cita_detail_screen.dart:227`, `completar_cita_screen.dart:315`.

**Test finders for raw buttons:**
- **`find.byType(TextButton)`: 0 hits in `test/`.**
- All raw `TextButton` finders use `find.widgetWithText(TextButton, …)` or `tester.widget<TextButton>`.
- `AppButton(variant: text|destructive)` still renders a `TextButton` internally (`app_button.dart:66-80`), so **`widgetWithText(TextButton, 'X')` keeps matching after migration**.
- The risks are a `TextButton.icon` (a different widget) turning into a `TextButton` inside a Row, or style reads on `tester.widget<TextButton>(…)`. For those, check that `onPressed` stays null while loading (AppButton nulls it via `isLoading`, `:31`).

| Test file:line | Finder | Under migration |
|---|---|---|
| `test/agenda_screen_test.dart:425, 451` | `widgetWithText(TextButton, 'Activar')` | `notificaciones_banner.dart:49` / `permiso_notificaciones.dart:39` |
| `test/anular_cobro_sheet_test.dart:132` | `widgetWithText(TextButton, 'Cancelar')` | `anular_cobro_sheet.dart:167` |
| `test/clientes_list_screen_test.dart:54` | `widgetWithText(TextButton, 'Buscar')` → `findsNothing` | safe |
| `test/cobro_form_screen_test.dart:639, 773, 812` | `'Descartar'` | `cobro_form_screen.dart` |
| `test/cobro_form_screen_test.dart:1645, 1669` | `'Volver'` | `cobro_form_screen.dart` |
| `test/historia_clinica_timeline_test.dart:184, 241, 254` | `'Cobrar'` | Cobrar button (billing `cobrar_boton`?), verify the widget type first |
| `test/mascota_detail_screen_test.dart:1203, 1270` | `'Cobrar'` | same |
| `test/protocolos_screen_test.dart:207, 238, 391, 402` | `'Restablecer'`, `'Desactivar'` | vaccination protocol sheets |
| `test/prueba_clinica_sheet_test.dart:146-147, 189-190` | `tester.widget<TextButton>(… 'Ahora no')` + `.onPressed` null | `prueba_clinica_sheet.dart` (plan); still a `TextButton` inside AppButton |

Other raw-widget finders that break **only if** the widget is replaced rather than themed:
- **FAB:** `clientes_list_screen_test:150`, `cobros_screen_test:585`, `inventario_screen_test:277/292/302`, `pacientes_list_screen_test:72`, `router_cobros_cross_shell_test:160`, `servicios_screen_test:146/193/373/392/435`. Recommendation: theme the FAB, do not replace it.
- **OutlinedButton:**
  - `cobrar_boton_test:78-80` (`byType(OutlinedButton)` findsOneWidget + 48 height);
  - `cita_detail_screen_test:206`.
  - `AppButton(variant: outline)` renders an `OutlinedButton`, so these are safe.
- **Switch/Checkbox:** `cita_form_screen_test` uses `byType(Switch)` ×2 and `byType(Checkbox)` ×5. Theme-only changes are safe.
- **ElevatedButton:** `agenda_screen_test:329`, `ajuste_sheet_test:70`, `clientes_list_screen_test:53`, `cobro_form_screen_test:957/989`, `cita_form_screen_test` ×16. `AppButton.primary` renders an `ElevatedButton`, so these are safe.

### 19. Invalidation sites (event-driven, 5 files)

| File | Insert after | Analog line |
|---|---|---|
| `citas_providers.dart` | each `_ref.read(citasRevisionProvider.notifier).incrementar();` at `:94, :123, :129, :135` (not in `marcarRecordatorioEnviado` `:139-147`) | same line |
| `consultas_providers.dart` (`RegistrarConsulta.call`, class at `:31`) | after the invalidations at `:70-77`, before `return id;` | `_ref.invalidate(consultasProvider(mascotaId));` |
| `cobros_providers.dart` | inside `invalidarCobros` (`:82-104`), one line: `ref.read(inicioRevisionProvider.notifier).incrementar();`. This covers all 6 callers, which already run in `finally` (`:111-119, 150-157`) | `ref.invalidate(resumenCobrosProvider);` `:89` |
| `mascota_form_screen.dart` | creation branch, next to `ref.invalidate(miPlanProvider);` `:186` (after `if (!mounted) return;` `:184`) | same |
| `nuevo_cliente_mascota_screen.dart` | next to `ref.invalidate(miPlanProvider);` `:168` | same |

- `CitaActions`/`RegistrarConsulta` increment after `await`, not in `finally`. D-13 says `finally`.
- If the plan converts them to `try/finally`, it must keep the existing invalidations' semantics, or document the choice in a single test (`test/inicio_invalidacion_test.dart`).
- Model that test on `cobros_invalidacion_test.dart:36-80`: a `ProviderContainer` with overrides, `c.listen(provider, (_, _) {})` to keep autoDispose providers alive, `_leer`, then count `llamadas`.

---

## Shared Patterns

### Error handling (data layer)
**Source:** `supabase_cobros_repository.dart:81-100`, plus `esErrorDeRed` at `supabase_inventario_repository.dart:330-333`.
**Apply to:** `supabase_inicio_repository.dart`, and `proximas()` (optional: keep the `entre()` style for consistency inside the cita repo).
- Two tiers: `on PostgrestException` → a Spanish `*Failure`; `catch (e)` → the offline message if `esErrorDeRed(e)`, else a generic message.
- The UI catches only the `*Failure` (or reads `AsyncError.error is InicioFailure`).

### Provider and repository wiring
**Source:** `core/data/supabase_client_provider.dart` (the only place that touches `Supabase.instance.client`), `cobros_providers.dart:11-13`.
**Apply to:** `inicioRepositoryProvider`.
- Tests **must** override `inicioRepositoryProvider` and `citaRepositoryProvider` (and the team providers for `esClinicaMultiVetProvider`) in `inicio_screen_test.dart`. Otherwise `Supabase.instance` throws.
- Today that test overrides auth, plan, vacunas, inventario, mascotas and fotos (`inicio_screen_test.dart:45-58`). Add `FakeInicioRepository`, `FakeCitaRepository`, and `FakeTeamRepository` (`test/helpers/fake_team.dart:8`, fixtures `miembroAna`/`miembroLuis`).

### Read-only lock
**Source:** `plan/presentation/widgets/control_escritura.dart:11-35`, `iconoEscritura`, `asegurarEscritura` (`plan/presentation/limite_plan_gate.dart`), `puedeEscribirProvider` (`plan_providers.dart:43+`).
**Apply to:** the 4 quick actions and the "Agendar cita" empty-state button.

### Refresh on resume / focus / pull
**Source:** `plan_providers.dart:25-26` (`AppLifecycleListener`), `app_shell.dart:30-39` (post-frame), `cobros_screen.dart:260-271` (`RefreshIndicator`).
**Apply to:** `inicio_providers.dart`, `app_shell.dart`, `inicio_screen.dart`.

### Formats
**Source:**
- `formato.dart`: `formatearMiles` `:128`, `formatearCop` `:139`, plus `formatearCopCorto` (new).
- `formato_hora.dart`: `hora12` `:42`, `diaCorto` `:51`, `rangoHoras` `:68`, `encabezadoDia` `:89`.
- `zona_bogota.dart`: `aBogota` `:9`, `diaBogota` `:18`, `mismoDia` `:42`.
- `clock_provider.dart`: `clockProvider` (`DateTime Function()`).

**Apply to:** all Inicio widgets. Never `DateFormat('EEE','es')` (there is no `initializeDateFormatting`).

### Design tokens
**Source:**
- `AppSpacing`: xs4, sm8, md16, lg24, xl32, radiusSm/Md/Lg, touchTarget48.
- `colorScheme.*` for dark-safe text.
- `AppColors.surfaceMuted` for skeletons.

**Apply to:** every new widget, and every sweep fix (BRAND-BASELINE cross-cutting 3).

---

## Shared-File Ownership Hazards (parallel plans)

| File | Touched by | Hazard / rule |
|---|---|---|
| `supabase/schema.sql`, `rls_smoke_test.sql`, `verify_live_schema.sh` | Inicio backend plan only | The smoke header total (`:38`) and the T-numbering are one sequence. A single owner; a live apply follows (a human step for smoke pastes). |
| `lib/core/utils/formato.dart` + `test/formato_test.dart` | Inicio data plan (`formatearCopCorto`) | Sweep plans fixing SW-08 must **not** edit `formato.dart`; they only call it. |
| `lib/core/theme/app_theme.dart` + `test/app_theme_test.dart` | Core plan only | Theme changes alter the rendering of every feature. Run the core plan **before** the feature sweep plans (Wave C-prior), so their QA screenshots reflect the final themes. |
| `lib/core/widgets/buttons/app_button.dart`, `status/app_status_chip.dart`, `inputs/app_text_field.dart` | Core plan only (spacing WARNs `:52`, `:51/61`, `:70`) | Feature plans consume them and never patch them locally (UI-SPEC SW-01). |
| `lib/core/data/inicio_revision.dart` | Inicio data plan (create) | The 5 increment sites import it, so it must exist **before** any of them is edited. Put it in the earliest Inicio plan. |
| `appointments/data/repositories/supabase_cita_repository.dart` **and** `test/helpers/fake_citas.dart` | Inicio data plan | **Compile coupling:** `FakeCitaRepository implements SupabaseCitaRepository`. Both files must change in the same task, or the whole test suite fails to compile. The appointments sweep plan must not touch either. |
| `appointments/presentation/providers/citas_providers.dart` | Inicio data plan (increments) | The appointments sweep (`agenda_screen`, `cita_form_screen`, `cita_acciones`, `day_strip`, …) must leave this file out, or run after. |
| `clinical_history/presentation/providers/consultas_providers.dart` | Inicio data plan | The clinical_history sweep is INFO-only (`historia_clinica_timeline.dart:182`), so there is no conflict if it leaves this file alone. |
| `billing/presentation/providers/cobros_providers.dart` | Inicio data plan | The billing sweep (~12 `TextButton`s in sheets and forms, 2 FABs, `linea_cobro_tile:242`) must not edit it. |
| `patients/presentation/screens/mascota_form_screen.dart` | Inicio data plan (increment) | It has raw-widget candidates (6 dialog/snackbar hits). The patients sweep must skip this file or go after. |
| `clients/presentation/screens/nuevo_cliente_mascota_screen.dart` | Inicio data plan (increment) | Same, for the clients sweep. |
| `clients/presentation/screens/clientes_list_screen.dart:16`, `patients/presentation/screens/pacientes_list_screen.dart:21` | Inicio UI plan (ComingSoon doc comments, D-17) **and** the clients/patients sweep (FAB `clientes_list_screen.dart:87`) | Give the two comment edits to the **clients/patients sweep plan**, or to the Inicio UI plan with the sweep skipping them. Pick one owner. |
| `home/presentation/app_shell.dart`, `home/**`, `test/inicio_screen_test.dart` | Inicio UI plan | The home sweep row (INFO: coming_soon) folds into this plan. |
| `test/helpers/fake_inicio.dart` (new), `test/helpers/fake_team.dart` | Inicio UI/data plans | `fake_team.dart` is read-only reuse; do not edit it. |
| `plan/presentation/widgets/plan_banner.dart:89` | plan sweep | `inicio_screen` only renders `PlanBanner`; no edit from the Inicio plan. |
| `inventory/presentation/widgets/stock_bajo_card.dart`, `vaccination/presentation/widgets/vacunas_pendientes_card.dart` | inventory and vaccination sweeps | The Inicio UI plan only places them. If a sweep restyles them, Inicio screenshots change. Acceptable; no file conflict. |
| `billing/presentation/widgets/cobro_fila.dart` (`pesosSemantica`) | billing sweep | If Inicio imports `pesosSemantica`, the billing sweep must not rename or move it. Safer: Inicio uses `formatearCop` in semantics, per UI-SPEC `:452`. |
| `lib/core/router/app_router.dart` | none expected | All routes exist. Deleting `coming_soon_screen.dart` needs no router change: it is not imported there (`app_router.dart:16` imports `inicio_screen.dart` only). |

---

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| DASH-04 grep gate (script or `test/` check) | test (gate) | batch | No grep-gate script exists in the repo. Use the exact commands in `08-UI-SPEC.md:523-534`, run from the plan's verify step (bash), with an exit code of 0 required. |

## Corrections to RESEARCH found during mapping

1. Helper name: **`formatearCopCorto`** (UI-SPEC), not `formatearCopAbreviado`.
2. `proximasCitasProvider` goes in `home/.../inicio_providers.dart` (UI-SPEC `:78`), not `citas_providers.dart`.
3. A day-label helper **already exists**: `encabezadoDia`/`diaCorto` in `formato_hora.dart:51, 89`. Do not create `etiquetaDia`.
4. `AppButtonVariant.destructive` **already exists** (`app_button.dart:70-80`). Migration needs no new variant.
5. `inFilter` is already used in the codebase (`supabase_cobros_repository.dart:72`). Assumption A2 is resolved.
6. Network detection already exists: `esErrorDeRed` (`supabase_inventario_repository.dart:330`). Assumption A3 is resolved.
7. `supabase_cita_repository_test.dart` has no fake client; it only tests error mapping. A query-shape unit test for `proximas()` is not feasible without a new client fake.
8. `invalidarAlertasVacunas`/`invalidarInventario` take `Ref`, not `WidgetRef`. Pull-to-refresh in the widget must invalidate the providers directly.
9. Smoke numbering: T31/T32 already exist. The next free number is **T33**.

## Metadata

- **Analog search scope:**
  - `supabase/schema.sql`, `supabase/tests/*`;
  - `lib/core/{data,utils,theme,widgets}`;
  - `lib/features/{home,appointments,billing,inventory,plan,team,vaccination,clinical_history,patients,clients}`;
  - `test/`, `test/helpers/`.
- **Files scanned:** about 40 read or grepped in a targeted way.
- **Pattern extraction date:** 2026-11-17.
