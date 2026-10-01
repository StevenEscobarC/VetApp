# Phase 4: Agenda y Citas - Pattern Map

**Mapped:** 2026-09-30
**Files analyzed:** 41 (new/modified)
**Analogs found:** 36 / 41 (5 without a codebase analog, see "No Analog Found")

Conventions inherited from CLAUDE.md that apply to every Dart file below: relative imports only (no barrels, no aliases), Spanish domain names, `///` doc comments explaining "why" on domain/shared classes, `const` aggressively, errors translated to a feature `*Failure` with Spanish messages, Riverpod `FutureProvider.autoDispose.family` for reads plus a `Ref`-holding action class for writes, one `*_routes.dart` per tab.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match |
|---|---|---|---|---|
| `supabase/schema.sql` (Fase 4 delta: `citas`, `cita_mascotas`, `unique(id,clinica_id)` on mascotas, `consultas.cita_id`, RLS, `crear_cita`, `actualizar_cita`, new `registrar_consulta`) | migration | CRUD + atomic RPC | `schema.sql` mascotas (l.60-71), policies (l.181-196), `registrar_cliente_con_mascota` (l.269-310), Fase 3 `consultas` + `registrar_consulta` (l.468-584) | exact |
| `supabase/tests/rls_smoke_test.sql` (+ J.. checks) | test | request-response | same file, G/H/I blocks (l.~700-780) | exact |
| `lib/features/appointments/domain/entities/cita.dart` (REWRITE) | model | transform | `lib/features/clinical_history/domain/entities/consulta.dart`, existing draft `cita.dart` | role-match |
| `lib/features/appointments/domain/cita_failure.dart` | model (exception) | request-response | `lib/features/clinical_history/domain/consulta_failure.dart` | exact |
| `lib/features/appointments/domain/cita_solapes.dart` | utility | transform | `lib/core/utils/formato.dart` (pure functions + records) | partial |
| `lib/features/appointments/domain/motivos_cita.dart` | utility/config | transform | `lib/core/widgets/status/app_status_chip.dart` (record lookup table) | partial |
| `lib/features/appointments/domain/whatsapp_recordatorio.dart` | utility | transform | `lib/core/utils/formato.dart` | partial |
| `lib/core/utils/zona_bogota.dart` | utility | transform | `lib/core/utils/formato.dart` | role-match |
| `lib/core/utils/telefono_co.dart` | utility | transform | `lib/core/utils/formato.dart` (`parsearFecha` record result) | role-match |
| `lib/core/utils/formato_hora.dart` | utility | transform | `lib/core/utils/formato.dart` (comment l.16-19 on no `initializeDateFormatting`) | role-match |
| `lib/features/appointments/data/repositories/supabase_cita_repository.dart` | service (repo) | CRUD + RPC | `lib/features/clinical_history/data/repositories/supabase_consulta_repository.dart` | exact |
| `lib/features/appointments/data/services/recordatorios_service.dart` | service | event-driven (OS alarms) | `lib/features/clinical_history/data/services/historia_clinica_pdf_service.dart` (service behind provider) | role-match |
| `lib/features/appointments/presentation/agenda_routes.dart` | route | request-response | `lib/features/patients/presentation/pacientes_routes.dart` / `clientes_routes.dart` | exact |
| `lib/core/router/app_router.dart` (MODIFY: replace `/agenda` ComingSoon, add `/mas/recordatorios`) | route | request-response | itself, l.77-102 | exact |
| `lib/features/appointments/presentation/providers/citas_providers.dart` | provider | CRUD | `lib/features/clinical_history/presentation/providers/consultas_providers.dart` | exact |
| `lib/features/appointments/presentation/providers/recordatorios_providers.dart` | provider | event-driven | `lib/features/auth/presentation/providers/auth_providers.dart` + `_AuthRefreshNotifier` in `app_router.dart` | role-match |
| `.../screens/agenda_screen.dart` | component (screen) | request-response | `lib/features/clients/presentation/screens/clientes_list_screen.dart` | role-match |
| `.../screens/cita_form_screen.dart` | component (screen) | CRUD | `lib/features/clinical_history/presentation/screens/consulta_form_screen.dart` | exact |
| `.../screens/cita_detail_screen.dart` | component (screen) | request-response | `lib/features/clients/presentation/screens/cliente_detail_screen.dart` | role-match |
| `.../screens/completar_cita_screen.dart` | component (screen) | request-response | `consulta_form_screen.dart` + `mascota_detail_screen.dart` list rows | partial |
| `.../screens/recordatorios_screen.dart` | component (screen) | CRUD (local prefs) | `lib/features/home/presentation/screens/mas_screen.dart` | partial |
| `.../widgets/day_strip.dart`, `cita_card.dart`, `time_stepper.dart`, `proxima_banner.dart`, `notificaciones_banner.dart` | component | request-response | `lib/core/widgets/chips/app_filter_chip.dart`, `cards/app_card.dart`, `status/app_status_chip.dart` | role-match |
| `.../widgets/cliente_search_field.dart` | component | request-response | `clientes_list_screen.dart` search + `clientes_providers.dart` `ClientesNotifier` | exact |
| `.../widgets/mascota_multi_select.dart` | component | request-response | `AppFilterChip` + `mascotasProvider` list | partial |
| `lib/core/widgets/status/app_status_chip.dart` (MODIFY: add `noShow`) | component | transform | itself | exact |
| `lib/features/clinical_history/presentation/screens/consulta_form_screen.dart` (MODIFY: `citaId`, prefill) | component | CRUD | itself | exact |
| `lib/features/clinical_history/data/repositories/supabase_consulta_repository.dart` (MODIFY: `p_cita_id`) | service | RPC | itself | exact |
| `lib/features/clinical_history/presentation/providers/consultas_providers.dart` (MODIFY) | provider | CRUD | itself | exact |
| `lib/features/clients/presentation/screens/nuevo_cliente_mascota_screen.dart` (MODIFY: return mode, normalize phone) | component | CRUD | itself | exact |
| `lib/features/clients/presentation/screens/cliente_detail_screen.dart` (MODIFY: "Agendar cita", normalize phone) | component | CRUD | itself | exact |
| `lib/features/patients/presentation/screens/mascota_detail_screen.dart` (MODIFY: "Agendar cita") | component | request-response | itself l.263-267 | exact |
| `lib/features/clients/presentation/clientes_routes.dart` / `pacientes_routes.dart` (MODIFY if consulta route gains `citaId`) | route | request-response | themselves | exact |
| `lib/features/home/presentation/screens/mas_screen.dart` (MODIFY: "Recordatorios" entry) | component | request-response | itself | exact |
| `lib/main.dart` (MODIFY: locale + `flutter_localizations`) | config | - | itself l.24-37 | exact |
| `android/app/build.gradle.kts`, `AndroidManifest.xml` (MODIFY) | config | - | themselves | exact |
| `pubspec.yaml` (MODIFY) | config | - | itself | exact |
| `test/helpers/fake_citas.dart` | test | CRUD | `test/helpers/fake_consultas.dart` | exact |
| `test/helpers/fake_recordatorios.dart`, `fake_url_launcher.dart` | test | event-driven | `test/helpers/fake_pdf.dart`, `fake_fotos.dart` | role-match |
| `test/helpers/fake_consultas.dart` (MODIFY: `citaId` param) | test | CRUD | itself | exact |
| `test/*_test.dart` (util, provider, screen tests) | test | - | `test/formato_test.dart`, `consultas_providers_test.dart`, `consulta_form_screen_test.dart` | exact |

## Pattern Assignments

### `supabase/schema.sql` Fase 4 delta (migration)

**Analog:** `schema.sql` mascotas + clientes (composite-FK shape), `registrar_cliente_con_mascota`, Fase 3 `consultas`/`registrar_consulta`.

**Composite-FK table shape** (l.60-71, copy for `citas` and `cita_mascotas`):
```sql
create table if not exists public.mascotas (
  id uuid primary key default gen_random_uuid(),
  dueno_id uuid not null,
  clinica_id uuid not null references public.clinicas(id) on delete cascade,
  ...
  constraint mascotas_dueno_misma_clinica_fkey foreign key (dueno_id, clinica_id)
    references public.clientes(id, clinica_id) on delete cascade
);
```
Note: `clientes` already has `constraint clientes_id_clinica_id_key unique (id, clinica_id)` (l.41). `mascotas` does NOT, so the delta must first add `mascotas_id_clinica_id_key` (RESEARCH Pattern 1, idempotent `do $$ ... exception when duplicate_object or duplicate_table then null; end $$`).

**updated_at trigger** (l.44-57): reuse `public.tocar_updated_at()`:
```sql
drop trigger if exists clientes_tocar_updated_at on public.clientes;
create trigger clientes_tocar_updated_at before update on public.clientes
for each row execute procedure public.tocar_updated_at();
```
Add `citas_tocar_updated_at` the same way.

**RLS policy shape** (l.181-196). `citas`: select/insert/update with this predicate, NO delete policy (cancel replaces delete). `cita_mascotas`: select/insert/delete, NO update. Add `veterinario_id = auth.uid()` to citas insert (as `consultas_insert`, l.510-518):
```sql
drop policy if exists mascotas_select on public.mascotas;
create policy mascotas_select on public.mascotas for select to authenticated
using (public.es_veterinario() and clinica_id = public.mi_clinica_id());
...
create policy mascotas_update on public.mascotas for update to authenticated
using (public.es_veterinario() and clinica_id = public.mi_clinica_id())
with check (public.es_veterinario() and clinica_id = public.mi_clinica_id());
```
Remember `alter table ... enable row level security;` (see l.240 `mascota_pesos`, l.498 `consultas`; the `do $$ declare table_name` block at l.131 only covers the Fase 1 tables).

**RPC shape (security invoker, guard, revoke/grant)** (l.269-310):
```sql
create or replace function public.registrar_cliente_con_mascota(...)
returns table (cliente_id uuid, mascota_id uuid)
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_clinica_id uuid := public.mi_clinica_id();
begin
  if not public.es_veterinario() or v_clinica_id is null then
    raise exception 'Solo un veterinario con clínica asignada puede registrar clientes.' using errcode = 'insufficient_privilege';
  end if;
  ...
end;
$$;
revoke all on function public.registrar_cliente_con_mascota(text, text, ...) from public, anon;
grant execute on function public.registrar_cliente_con_mascota(text, text, ...) to authenticated;
```
Use for `crear_cita` / `actualizar_cita` (full bodies in RESEARCH Pattern 2). Error codes to use: `insufficient_privilege`, `check_violation`, `foreign_key_violation` (the Dart `_messageFor` maps `42501`, `23514`, `23503`).

**`registrar_consulta` replacement** (l.530-584): the current definition has 10 params and a revoke/grant block with that exact signature (l.579-584). Per RESEARCH Pattern 3: `drop function if exists public.registrar_consulta(uuid, text, text, text, text, numeric, numeric, integer, integer, text);` immediately before a `create or replace` with trailing `p_cita_id uuid default null`; edit the Fase 3 block in place (not only a delta) so a full-file re-run never recreates the 10-arg overload; update revoke/grant to the 11-arg signature. Keep the existing guard:
```sql
if not exists (
  select 1 from public.mascotas m where m.id = p_mascota_id and m.clinica_id = v_clinica_id
) then
  raise exception 'La mascota no existe en tu clínica.' using errcode = 'foreign_key_violation';
end if;
```
and add the analogous `cita_mascotas` join check when `p_cita_id is not null`.

---

### `supabase/tests/rls_smoke_test.sql` (test, request-response)

**Analog:** same file, blocks G/H/I (impersonation + numbered checks).

**Role switch + check idiom** (l.~733-790):
```sql
perform set_config('role', 'postgres', true);
perform set_config('request.jwt.claims', json_build_object('sub', vet_b_id, 'role', 'authenticated')::text, true);
perform set_config('role', 'authenticated', true);

-- H2: registrar_consulta contra mascota A -> foreign_key_violation.
checks := checks + 1;
begin
  perform public.registrar_consulta(mascota_a_id, 'x', 'y');
  failures := failures || 'H2 vet B pudo registrar consulta contra mascota de otra clinica';
exception
  when foreign_key_violation then null;
  when others then failures := failures || ('H2 error inesperado: ' || sqlerrm);
end;

-- count/rowcount style
checks := checks + 1;
update public.consultas set diagnostico = 'editado' where mascota_id = mascota_b_id;
get diagnostics n = row_count;
if n <> 0 then failures := failures || format('H3 ... afectó %s filas, esperaba 0', n); end if;
```
New checks (J..): vet B cannot select/crear_cita against A's cliente/mascota; `crear_cita` with a mascota of another dueno in same clinica -> `foreign_key_violation`; delete on `citas` -> 0 rows; update on `cita_mascotas` -> 0 rows; cliente role -> `insufficient_privilege`; `registrar_consulta` with mismatched `p_cita_id`/mascota -> `foreign_key_violation`; second consulta for same `(cita_id, mascota_id)` -> `unique_violation`; deleting cliente cascades citas (D-20). Insert the J block BEFORE the final "Volver a postgres y reportar" section and update the header comment ("Fase 4: citas, cita_mascotas ..."). New declared variables go in the top `declare` block (l.23-43). Script must end in the same always-raise PASS/FAIL exception.

---

### `lib/features/appointments/data/repositories/supabase_cita_repository.dart` (repo, CRUD + RPC)

**Analog:** `supabase_consulta_repository.dart` (exact) and `supabase_cliente_repository.dart` (select with embed, `_fromRow`, `_messageFor` with message-substring pre-check).

**Imports + class shell** (consulta repo l.1-21):
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/formato.dart';
import '../../domain/consulta_failure.dart';
import '../../domain/entities/consulta.dart';

class SupabaseConsultaRepository {
  SupabaseConsultaRepository(this._client);
  final SupabaseClient _client;
```
**Read with two-tier catch** (l.24-41):
```dart
try {
  final rows = await _client.from('consultas').select().eq('mascota_id', mascotaId).order('fecha', ascending: false);
  return (rows as List).map((row) => _fromRow(row as Map<String, dynamic>)).toList();
} on PostgrestException catch (e) {
  throw ConsultaFailure(_messageFor(e));
} catch (_) {
  throw const ConsultaFailure('No pudimos cargar la historia clínica. Intenta de nuevo.');
}
```
**RPC write, all `p_` keys always present** (l.49-82): `await _client.rpc('registrar_consulta', params: {'p_mascota_id': ..., 'p_anamnesis': blancoANull(anamnesis), ...}); return id as String;`. Copy for `crear_cita`/`actualizar_cita` (params: `p_cliente_id`, `p_mascota_ids` as a `List<String>`, `p_fecha_hora` as `toUtc().toIso8601String()`, ...).

**Embed select + `single()`** (cliente repo l.63-67): `.select('*, mascotas(count)').eq('id', id).single()`. For week query use RESEARCH Pattern 4 (`'*, clientes(nombre, telefono, direccion), cita_mascotas(mascotas(id, nombre, especie, foto_path))'`); if PostgREST reports ambiguity pin `clientes!citas_cliente_misma_clinica_fkey(...)` (open risk, verify live).

**`_messageFor` by `PostgrestException.code`** (consulta repo l.104-117; cliente repo l.161-176 also does a lowercased-substring pre-check). Codes: `42501`, `23503`, `23514/23502/22003`, `23505`, `PGRST116/P0002`. Add all new mappings here, never inline.

**Constraint reminder:** like the consulta repo, no delete method (cancel = `update estado`).

---

### `lib/features/appointments/domain/cita_failure.dart` (exception)

**Analog:** `lib/features/clinical_history/domain/consulta_failure.dart` (copy verbatim, rename):
```dart
class ConsultaFailure implements Exception {
  const ConsultaFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
```

---

### `lib/features/appointments/domain/entities/cita.dart` (REWRITE, model)

**Analog:** existing draft (`const` ctor + `copyWith`, `enum EstadoCita`) and the `Consulta` entity. Keep style (`const` constructor, `copyWith`, doc `///` explaining why), but replace fields: `clinicaId`, `clienteId`, `veterinarioId`, `fechaHora` (UTC instant), `duracionMin`, `modalidad`, `direccion`, `motivo`, `notas`, `estado`, `recordatorioEnviadoAt`, plus embedded `clienteNombre/Telefono/Direccion` and `List<MascotaResumen>`. `EstadoCita` must become `{pendiente, confirmada, completada, cancelada, noAsistio}` with a text<->enum mapper (`no_asistio`, and defensive `solicitada` -> pendiente). Entities in this repo contain no JSON; mapping lives in the repository `_fromRow` (consulta repo l.84-100: `DateTime.parse(row['fecha'] as String)`; for the agenda use `aBogota`, not `.toLocal()`).

---

### `lib/core/utils/{zona_bogota,telefono_co,formato_hora}.dart` and domain utils (`cita_solapes`, `motivos_cita`, `whatsapp_recordatorio`)

**Analog:** `lib/core/utils/formato.dart`: top-level pure functions, `///` docs in Spanish explaining edge cases, Dart records as result types, no locale init.

**Record result convention** (formato.dart l.30-56):
```dart
({DateTime? valor, String? error}) parsearFecha(String texto) {
  final t = texto.trim();
  if (t.isEmpty) return (valor: null, error: null);
  ...
  return (valor: fecha, error: null);
}
```
`normalizarTelefono` should return `({String guardado, ClaseTelefono clase, String formateado})` in the same style. `blancoANull` (l.11-14) already exists; reuse for notes/dirección.

**No-locale constraint** (l.16-19): "la app nunca llama `initializeDateFormatting`". `formato_hora.dart` must hand-write const Spanish day/month lists (RESEARCH Pitfall 4). `formatearFecha` (dd/MM/yyyy) is reusable as-is for the "Cita del ..." pills.

**Lookup table as record** (app_status_chip.dart l.19-40) is the model for `motivos_cita.dart`: `({String label, int duracionMin})` consts.

**Tests:** mirror `test/formato_test.dart` (`group(...)` + `test(...)`, `package:vetapp/...` imports).

---

### `lib/features/appointments/presentation/providers/citas_providers.dart` (provider, CRUD)

**Analog:** `consultas_providers.dart` (exact).

**Repository provider + autoDispose.family read** (l.9-23):
```dart
final consultaRepositoryProvider = Provider<SupabaseConsultaRepository>((ref) {
  return SupabaseConsultaRepository(ref.watch(supabaseClientProvider));
});
final consultasProvider = FutureProvider.autoDispose.family<List<Consulta>, String>((ref, mascotaId) {
  return ref.watch(consultaRepositoryProvider).porMascota(mascotaId);
});
```
-> `agendaSemanaProvider` (family keyed by Monday-Bogota `DateTime`), `citaProvider(id)`.

**Action class holding `Ref`, non-autoDispose, invalidate after write** (l.34-79):
```dart
class RegistrarConsulta {
  RegistrarConsulta(this._ref);
  final Ref _ref;
  Future<String> call({...}) async {
    final id = await _ref.read(consultaRepositoryProvider).registrarConsulta(...);
    _ref.invalidate(consultasProvider(mascotaId));
    return id;
  }
}
final registrarConsultaProvider = Provider<RegistrarConsulta>((ref) => RegistrarConsulta(ref));
```
-> `CitaActions` (crear/actualizar/cambiarEstado/marcarRecordatorio) invalidating `agendaSemanaProvider`/`citaProvider` and then calling `RecordatoriosService.reprogramar()`.

**Modify** `RegistrarConsulta.call` to accept `String? citaId`, forward it, and also `_ref.invalidate(citaProvider(citaId))` when non-null.

**Awaiting auth before reads** (clientes_providers.dart l.46): `(await ref.watch(authProfileProvider.future))?.clinicaId` rather than `.value`. Use this in any provider needing `clinicaId`/`veterinarioId`.

**Client search for the form:** reuse `clientesProvider`/`ClientesNotifier.search` (350ms debounce, sequence guard) as-is (clientes_providers.dart l.28-110); do not write a new search.

---

### `lib/features/appointments/presentation/agenda_routes.dart` + `app_router.dart` (route)

**Analog:** `clientes_routes.dart` l.14-56 / `pacientes_routes.dart`.

```dart
final GoRoute clientesRoute = GoRoute(
  path: '/clientes',
  builder: (_, _) => const ClientesListScreen(),
  routes: [
    GoRoute(path: 'nuevo', builder: (_, _) => const NuevoClienteMascotaScreen()),   // MUST precede ':id'
    GoRoute(path: ':id', builder: (_, state) => ClienteDetailScreen(clienteId: state.pathParameters['id']!),
      routes: [ GoRoute(path: 'nueva-mascota', ...), ... ]),
  ],
);
```
`agendaRoute`: `nueva` (query params `state.uri.queryParameters['clienteId'|'mascotaId'|'fecha']`) first, then `:id` with children `editar`, `completar`, and `completar/consulta/:mascotaId` if chosen. In `app_router.dart` replace l.87-94:
```dart
StatefulShellBranch(routes: [GoRoute(path: '/agenda', builder: (_, _) => const ComingSoonScreen(title: 'Agenda'))]),
```
with `StatefulShellBranch(routes: [agendaRoute])` (like l.86 `pacientesRoute`, l.95 `clientesRoute`), remove the unused `ComingSoonScreen` import if nothing else uses it, and change `/mas` (l.98) into a `GoRoute` with child `recordatorios`. `rutaBase: state.uri.path` (clientes_routes l.36) is the pattern for passing the current location to children.

**Combined-alta return mode:** the nueva-cita form does `await context.push<({String clienteId, String mascotaId})>('/clientes/nuevo?retorno=1')`; `NuevoClienteMascotaScreen` reads the flag (constructor param fed from `state.uri.queryParameters`) and at l.157 replaces `context.pop()` with `context.pop((clienteId: resultado.clienteId, mascotaId: resultado.mascotaId))` when in return mode. `resultado` is already `({String clienteId, String mascotaId})` (supabase_mascota_repository.dart l.49).

---

### `.../screens/cita_form_screen.dart` (screen, CRUD)

**Analog:** `consulta_form_screen.dart` (exact for form skeleton).

**State skeleton** (l.32-77): controllers disposed in `dispose`, `addListener(_onCamposCambiaron)` -> `setState`, `_puedeGuardar` getter gating the button, `_loading`, `_error`.

**Submit pattern** (l.79-147): validate parsers first and return with field errors; then
```dart
setState(() { ...; _loading = true; _error = null; });
try {
  await ref.read(registrarConsultaProvider)(...);
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Consulta guardada')));
  context.pop();
} on ConsultaFailure catch (e) {
  if (mounted) setState(() => _error = e.message);
} finally {
  if (mounted) setState(() => _loading = false);
}
```
Catch only `CitaFailure`. D-09 overlap warning: before the call, run `solapa(...)` against the loaded day and `showDialog` confirmation (warn, never block).

**Layout pieces:** `Scaffold(appBar: const AppTopBar(title: ...), body: SingleChildScrollView(padding: EdgeInsets.all(AppSpacing.md), child: Column(...)))`, `AppTextField(label: 'Diagnóstico *', controller:..., maxLines: 4, keyboardType: TextInputType.multiline)`, collapsible "Agregar más detalles" row (l.173-199), error text (l.253-261), `AppButton(label:..., onPressed: _puedeGuardar ? _submit : null, isLoading: _loading)`. Reason chips: `AppFilterChip(label, selected, onTap)` (single-select, designed for reuse per its doc).

**Combined-alta embedding:** NuevoClienteMascotaScreen uses `AppCard` sections with `headlineSmall` title (l.175-193).

---

### `.../screens/agenda_screen.dart` (screen, request-response)

**Analog:** `clientes_list_screen.dart`.

**Async `.when` + empty/error copy + FAB** (l.35-72, 86-113):
```dart
final clientesAsync = ref.watch(clientesProvider);
return Scaffold(
  appBar: const AppTopBar(title: 'Clientes'),
  body: ...clientesAsync.when(
    data: (clientes) => _ClientesBody(...),
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (_, _) => const Center(child: Text('No pudimos cargar la lista. Intenta de nuevo.')),
  ),
  floatingActionButton: FloatingActionButton.extended(
    onPressed: () => context.push('/clientes/nuevo'),
    icon: const Icon(Icons.add), label: const Text('Nuevo cliente')),
);
```
List: `RefreshIndicator` + `ListView.separated(padding: EdgeInsets.all(AppSpacing.md), separatorBuilder: SizedBox(height: AppSpacing.md))` with `AppCard(onTap: () => context.push('/clientes/${cliente.id}'), child: Column(...))` and `textTheme.bodyLarge` w600 / `bodyMedium` + `AppColors.textSecondary|textMuted` (l.115-153). Card actions >= `AppSpacing.touchTarget`. Use `clockProvider` (not `DateTime.now()`) for "Hoy"; day math through `zona_bogota.dart`.

---

### `.../screens/cita_detail_screen.dart` (screen, request-response)

**Analog:** `cliente_detail_screen.dart` (detail + AppButtons stacked, `ref.watch(provider).when`) and `mascota_detail_screen.dart` l.220-267 for action buttons:
```dart
AppButton(label: 'Nueva consulta', icon: Icons.add, onPressed: () => context.push('$rutaBase/consultas/nueva')),
AppButton(label: 'Registrar peso', icon: Icons.add, variant: AppButtonVariant.text, expand: false, onPressed: _abrirRegistrarPeso),
```
Variants available: `primary`, `outline`, `text`. One accent CTA per screen (UI-SPEC). State changes with "Deshacer": `ScaffoldMessenger...showSnackBar(SnackBar(content:..., action: SnackBarAction(label: 'Deshacer', onPressed: ...)))` (snackbar usage pattern: consulta_form l.138-140). Status chip: `AppStatusChip(status: ...)` via a new `EstadoCita -> AppStatus` mapper.

---

### `.../screens/completar_cita_screen.dart` (screen, request-response)

**Analog:** no exact. List of mascotas as `AppCard` rows (clientes_list_screen l.123-150) each pushing `ConsultaFormScreen` with `citaId`; "Consulta registrada" derives from `consultasProvider`/cita-linked data. State flow lives in the screen; `estado='completada'` update goes through `CitaActions` after the flow (RESEARCH Pattern 2: not one transaction).

---

### `consulta_form_screen.dart` (MODIFY)

Add `final String? citaId;` to the widget (current ctor l.23: `const ConsultaFormScreen({super.key, required this.mascotaId});`). Prefill in `initState` after the existing listeners (l.52-56): `_anamnesisCtrl.text = "{motivo}. {notas}"` from `citaProvider(citaId)` and set `_detallesExpandidos = true` when prefilled (anamnesis is behind the expander, l.200-207). Pass `citaId: widget.citaId` into the `registrarConsultaProvider` call (l.125-136). Existing test (`consulta_form_screen_test.dart`) builds the route with only `mascotaId`; keep it optional so those tests keep passing. Route options: add `citaId` via `state.uri.queryParameters['citaId']` in the two existing routes (`pacientes_routes.dart` l.27-31, `clientes_routes.dart` l.45-50).

### `supabase_consulta_repository.dart` / `fake_consultas.dart` (MODIFY)

Add `String? citaId` to `registrarConsulta` and `'p_cita_id': citaId` to the params map (l.62-73, always present, null allowed). In `FakeConsultaRepository` add `String? citaId` to the `registros` record type (l.34-47) and the override signature (l.60-72) and record it (l.73-84). Add a `PostgrestException` `23505` mapping ("Ya registraste una consulta para esta mascota en esta cita.") in `_messageFor`.

### `app_status_chip.dart` (MODIFY)

Add `noShow` to `enum AppStatus` (l.6) and a branch in the `_spec` switch (l.19-40): `color: AppColors.textMuted, icon: Icons.person_off_outlined, label: 'No asistió'`. The switch is exhaustive so the compiler flags any missed case.

### `mascota_detail_screen.dart`, `cliente_detail_screen.dart` (MODIFY: "Agendar cita")

Insert an `AppButton(label: 'Agendar cita', icon: Icons.event_outlined, variant: AppButtonVariant.outline, onPressed: () => context.push('/agenda/nueva?clienteId=...&mascotaId=...'))` next to the existing action buttons (mascota detail after l.263-267 using `mascota.duenoId`; cliente detail near l.220-226 "Nueva mascota" which is already `outline`). Phone: cliente_detail saves `_telefonoCtrl.text.trim()` (l.114) and `nuevo_cliente_mascota_screen` sends `_telefonoCtrl.text.trim()` (l.109): replace with `normalizarTelefono(...).guardado`, never blocking (D-16).

---

### `.../services/recordatorios_service.dart` + providers (service, event-driven)

**Analog:** `historia_clinica_pdf_service.dart` with `historia_clinica_pdf_providers.dart` and `test/helpers/fake_pdf.dart`: an injectable service exposed via a `Provider`, overridden in tests with a fake. Use RESEARCH Pattern 6 for the interface (`inicializar`, `permisoConcedido`, `solicitarPermiso`, `abrirAjustes`, `reprogramar`, `cancelarTodo`) and keep the plan builder (`planificar(citas, minutosAntes, ahora)`) pure. No-op on non-Android (`defaultTargetPlatform`). `cancelarTodo()` on sign-out: copy the listener idiom from `app_router.dart` l.22-26:
```dart
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authProfileProvider, (previous, next) => notifyListeners());
  }
}
```
(call `cancelarTodo()` when `next.value == null`). Navigation on notification tap should use `ref.read(routerProvider)` (provider at `app_router.dart` l.30).

---

### Config files

- `lib/main.dart` l.24-37: add to `MaterialApp.router(...)`: `locale: const Locale('es','CO')`, `supportedLocales`, `localizationsDelegates: GlobalMaterialLocalizations.delegates` (+ `flutter_localizations` sdk dep). `test/helpers/router_harness.dart` builds its own `MaterialApp.router` (l.23-27); add the same locale options there only for tests that open a date picker.
- `android/app/build.gradle.kts`: add `isCoreLibraryDesugaringEnabled = true` inside the existing `compileOptions` (l.12-15), `multiDexEnabled = true` in `defaultConfig` (l.22-30), and a NEW top-level `dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") }` block (none exists today; place before `flutter { ... }`).
- `AndroidManifest.xml`: add `RECEIVE_BOOT_COMPLETED` next to the existing `<uses-permission>` lines (l.2-3), the two plugin receivers inside `<application>` (after the `flutterEmbedding` meta-data, l.~32), and, only if `canLaunchUrl` is used, an https `<intent>` in the existing `<queries>` block. Do not add exact-alarm permissions.
- `pubspec.yaml`: add `flutter_local_notifications`, `timezone`, `url_launcher`, `shared_preferences`, `flutter_localizations` (sdk).

---

### Test files

**`test/helpers/fake_citas.dart`** (analog `fake_consultas.dart`): class `FakeCitaRepository implements SupabaseCitaRepository` with named ctor params (`citas`, `this.error`, `idResultado`), `if (error != null) throw error!;` at the top of each method, a typed-record call log (`registros` in fake_consultas l.34-48) and fixtures as top-level `final` (DateTime is not const, l.127-173). Do NOT sort in the fake (l.50-53 comment: test that provider/screen sorts).

**Screen tests** (analog `consulta_form_screen_test.dart`): `routerHarness(initialLocation:, routes:, overrides:)` with `authProfileProvider.overrideWith(() => FakeAuthProfileNotifier(profile: vetProfile))`, `xRepositoryProvider.overrideWithValue(fake)`, `find.byType(TextFormField).at(index)` with documented field-order constants (l.17-25), `AppButton` onPressed null assertion for disabled state. New providers to override: `citaRepositoryProvider`, `recordatoriosServiceProvider`, `clockProvider`, a url-launcher wrapper provider.

**Provider tests**: mirror `test/consultas_providers_test.dart`. **Util tests**: mirror `test/formato_test.dart`.

## Shared Patterns

### Tenant isolation / auth
**Source:** `supabase/schema.sql` l.181-196, `mi_clinica_id()` / `es_veterinario()`. **Apply to:** every new table/RPC. Client code never filters by clinic except where a repository already takes `clinicaId` for search (clientes). Citas queries rely on RLS only.

### Two-tier error translation
**Source:** `supabase_consulta_repository.dart` l.24-41, 102-117. **Apply to:** `SupabaseCitaRepository` every method. `on PostgrestException` -> `CitaFailure(_messageFor(e))`, catch-all -> Spanish generic. Screens catch only `CitaFailure`.

### Action-class + invalidate
**Source:** `consultas_providers.dart` l.34-79. **Apply to:** `CitaActions`; also `RegistrarConsulta` after adding `citaId`.

### Await auth profile
**Source:** `clientes_providers.dart` l.40-47 and `nuevo_cliente_mascota_screen.dart` l.122-127. **Apply to:** any provider/screen needing `clinicaId` or veterinarian name/clinic for the WhatsApp template (`AuthProfile.nombre`, `clinicaNombre`).

### Null-not-empty optionals
**Source:** `formato.dart` `blancoANull`. **Apply to:** notas, direccion (Note: `citas.notas`/`direccion` are `not null default ''`, so send `''`/trimmed text for those columns, not null; use `blancoANull` only for `consultas.anamnesis`).

### Screen layout/theme
**Source:** `AppTopBar`, `AppCard`, `AppTextField`, `AppButton`, `AppFilterChip`, `AppStatusChip`, `AppSpacing` (`md`, `sm`, `xs`, `lg`, `xl`, `touchTarget`, `radiusLg`), `AppColors` (`textSecondary`, `textMuted`, `success`, `warning`, `destructive`, `primary`). **Apply to:** all new screens/widgets; never raw `Card`/`Chip` (see doc comments warning about Google Fonts width bug).

### Dates and time
**Source:** `formato.dart` (`formatearFecha` dd/MM/yyyy, no locale init) + new `zona_bogota.dart`. **Apply to:** all agenda code; never `toLocal()`/`DateTime.now()` directly in agenda widgets.

### Router registration
**Source:** `clientes_routes.dart` header comment (child ordering rule: static segment before `:id`). **Apply to:** `agenda_routes.dart`.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `recordatorios_service.dart` OS-alarm impl (`flutter_local_notifications`) | service | event-driven | No plugin/OS integration exists; only the provider-wrapped service shape is reusable. Use RESEARCH Pattern 6 |
| `whatsapp_recordatorio.dart` launcher wrapper (`url_launcher`) | utility | external launch | No external-app launching in codebase; use RESEARCH Pattern 7 |
| `day_strip.dart` (7-cell week strip, counts) | component | request-response | No calendar/strip widget; compose from `AppFilterChip` styling + UI-SPEC |
| `time_stepper.dart` (15-minute +/- buttons) | component | request-response | No stepper widget exists; build with `AppButton`/`InkWell` at `AppSpacing.touchTarget` |
| Batch WhatsApp sheet with `WidgetsBindingObserver` return detection | component | event-driven | No lifecycle-observer code or bottom-sheet batch flow (closest: `vinculacion_sheet.dart` for sheet structure, `lib/features/clients/presentation/widgets/vinculacion_sheet.dart`) |

## Metadata

**Analog search scope:** `lib/core`, `lib/features/{clients,patients,clinical_history,appointments,home,auth}`, `test/` and `test/helpers`, `supabase/schema.sql`, `supabase/tests/rls_smoke_test.sql`, `android/app`.
**Files scanned/read:** ~30 (plus targeted line-range reads of `schema.sql`, `rls_smoke_test.sql`, detail screens).
**Pattern extraction date:** 2026-09-30
