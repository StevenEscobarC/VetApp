# Phase 3: Historia Clínica - Pattern Map

**Mapped:** 2026-09-26
**Files analyzed:** 18 (new/edited)
**Analogs found:** 15 exact/role-match / 18 total (3 have no direct precedent — analog is 03-RESEARCH.md's already-reviewed Code Examples, cross-checked against the live files below)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `supabase/schema.sql` (EDIT: add `consultas` table+RLS, `registrar_consulta` RPC) | migration | CRUD | `supabase/schema.sql` itself (`mascota_pesos` table lines 229-260, `registrar_mascota` RPC lines 315-350) | exact |
| `lib/features/clinical_history/domain/entities/consulta.dart` (EDIT: reconcile) | model | CRUD | the file itself (current scaffold, read this session) + `lib/features/patients/domain/entities/peso_registro.dart` (no-`copyWith` append-only precedent) | exact |
| `lib/features/clinical_history/domain/consulta_failure.dart` (NEW) | model (exception) | request-response | `lib/features/patients/domain/mascota_failure.dart` | exact |
| `lib/features/clinical_history/data/repositories/supabase_consulta_repository.dart` (NEW) | service (repository) | CRUD | `lib/features/patients/data/repositories/supabase_mascota_repository.dart` | exact |
| `lib/features/clinical_history/data/services/historia_clinica_pdf_service.dart` (NEW) | service | transform + file-I/O | none in codebase (first PDF/document-assembly service) — shell mirrors repository constructor-injection shape; body is new, use 03-RESEARCH.md Pattern 5 verbatim | new-pattern |
| `lib/features/clinical_history/presentation/providers/consultas_providers.dart` (NEW) | provider | CRUD + event-driven (dual invalidation) | `lib/features/patients/presentation/providers/mascotas_providers.dart` (repo `Provider` + `FutureProvider.autoDispose.family` shape) | exact |
| `lib/features/clinical_history/presentation/screens/consulta_form_screen.dart` (NEW) | component (screen) | request-response (RPC call) | `lib/features/clients/presentation/screens/nuevo_cliente_mascota_screen.dart` (manual validation + `_puedeGuardar` gate + `AppButton.isLoading` submit) | role-match |
| `lib/features/clinical_history/presentation/widgets/historia_clinica_timeline.dart` (NEW) | component (widget) | request-response | `lib/features/patients/presentation/screens/mascota_detail_screen.dart`'s `_HistorialPeso` (private `ConsumerWidget`, defensive client-side sort, empty-state copy) | exact |
| `lib/features/patients/presentation/screens/mascota_detail_screen.dart` (EDIT: add timeline section + PDF action + demote "Editar") | component (screen) | request-response | the file itself (extend, not replace) | exact |
| `lib/features/patients/presentation/pacientes_routes.dart` (EDIT: add `consultas/nueva` child route) | route | request-response | the file itself (existing `editar` child route shape) | exact |
| `lib/features/clients/presentation/clientes_routes.dart` (EDIT: add matching `consultas/nueva` child route) | route | request-response | the file itself (existing `editar` child route under `mascotas/:mascotaId`) | exact |
| `pubspec.yaml` (EDIT: add `pdf: 3.12.0`, `printing: 5.14.3`) | config | — | the file itself (existing exact-pin absence — first exact-pinned deps in the file, per Phase 2's `cached_network_image` caret-trap lesson) | n/a |
| `test/helpers/fake_consultas.dart` (NEW) | test (helper) | request-response | `test/helpers/fake_mascotas.dart` (`FakeMascotaRepository` "fixed data/fixed error + call log" shape) | exact |
| `test/consultas_providers_test.dart` (NEW) | test | request-response | `test/mascotas_providers_test.dart` (`_containerWith`, `ProviderContainer` + fake-repo override pattern) | exact |
| `test/consulta_form_screen_test.dart` (NEW) | test | request-response | `test/nuevo_cliente_mascota_screen_test.dart` (widget test over a manual-validation create form) | role-match |
| `test/historia_clinica_pdf_service_test.dart` (NEW) | test | request-response | none — first PDF-service test; plain `test()` unit calling `.generar()` and asserting non-empty bytes, no fake/mock needed | new-pattern |
| `test/mascota_detail_screen_test.dart` (EDIT: extend with HIST-02 timeline assertions) | test | request-response | the file itself (existing `_appUnderTest`/`routerHarness` helper, `_HistorialPeso` ordering-test precedent) | exact |
| `supabase/tests/rls_smoke_test.sql` (EDIT: extend with `consultas` positive/negative cases) | test | CRUD | the file itself (existing two-clinic `vet_a`/`vet_b` smoke-test setup) | exact |

## Pattern Assignments

### `supabase/schema.sql` (migration, CRUD)

**Analog:** the file itself — `mascota_pesos` table block (lines 229-260) and `registrar_mascota` RPC (lines 315-350), confirmed via direct grep this session.

**Table + RLS shape to mirror exactly** (`mascota_pesos`, lines 229-260):
```sql
create table if not exists public.mascota_pesos (...);
create index if not exists mascota_pesos_mascota_id_idx
  on public.mascota_pesos(mascota_id, registrado_en desc);
alter table public.mascota_pesos enable row level security;

drop policy if exists mascota_pesos_select on public.mascota_pesos;
create policy mascota_pesos_select on public.mascota_pesos for select to authenticated
using (
  public.es_veterinario()
  and exists (
    select 1 from public.mascotas m
    where m.id = mascota_pesos.mascota_id and m.clinica_id = public.mi_clinica_id()
  )
);
-- insert policy mirrors select's `exists(...)` clause; no update/delete policy exists at all.
```
Apply the identical shape to `consultas` — swap table/column names only. `es_veterinario()`/`mi_clinica_id()` (defined lines 119-129) are the only tenant-scoping primitives; never re-derive scoping inline.

**RPC shape to mirror exactly** (`registrar_mascota`, lines 315-350):
```sql
create or replace function public.registrar_mascota(...)
returns uuid language plpgsql security invoker set search_path = public
as $$
declare v_clinica_id uuid := public.mi_clinica_id(); v_mascota_id uuid;
begin
  if not public.es_veterinario() or v_clinica_id is null then
    raise exception '...' using errcode = 'insufficient_privilege';
  end if;
  insert into public.mascotas (...) returning id into v_mascota_id;
  if mascota_peso_kg is not null then
    insert into public.mascota_pesos (mascota_id, peso_kg) values (v_mascota_id, mascota_peso_kg);
  end if;
  return v_mascota_id;
end; $$;
revoke all on function public.registrar_mascota(...) from public, anon;
grant execute on function public.registrar_mascota(...) to authenticated;
```
`registrar_consulta` (03-RESEARCH.md Pattern 2, already fully written) follows this exact shape — `security invoker`, guard-then-insert-then-conditional-second-insert, `revoke`+`grant` pair. Full SQL for both `consultas` (table+RLS) and `registrar_consulta` (RPC) is already written verbatim in `03-RESEARCH.md` Patterns 1-2 — copy those blocks, do not re-derive.

---

### `lib/features/clinical_history/domain/entities/consulta.dart` (model, CRUD)

**Analog:** the file itself (current scaffold, read this session, confirmed to exactly match 03-RESEARCH.md's description) + `lib/features/patients/domain/entities/peso_registro.dart` (no-`copyWith` doc-comment precedent, read this session).

**Current (broken) shape — confirmed live in the repo:**
```dart
// lib/features/clinical_history/domain/entities/consulta.dart:22-48 (current)
class Consulta {
  const Consulta({
    required this.id, required this.mascotaId, required this.veterinarioId,
    required this.fecha, required this.anamnesis, required this.examenFisico,
    required this.diagnostico, required this.tratamiento,
    this.evolucion, this.proximaCita, this.adjuntoUrls = const [],
  });
  final String anamnesis;       // WRONG — D-03 requires this nullable
  final String diagnostico;     // correct — required
  final String tratamiento;     // correct — required
  final DateTime? proximaCita;  // remove — no backing column this phase
  final List<String> adjuntoUrls; // remove — no backing column this phase
}
```
`ExamenFisico` fields are already all-nullable (correct) — no change needed there beyond field order/naming.

**No-`copyWith` precedent to copy the reasoning from** (`peso_registro.dart:1-6`):
```dart
/// ... Sin `copyWith` a propósito: no existe un caso de uso legítimo para
/// "modificar" un registro ya guardado.
```
Apply the identical doc-comment convention to `Consulta` — full reconciled target shape is already written in `03-RESEARCH.md` Pattern 3 (verbatim, `anamnesis` → `String?`, `proximaCita`/`adjuntoUrls` removed).

---

### `lib/features/clinical_history/domain/consulta_failure.dart` (model/exception, request-response)

**Analog:** `lib/features/patients/domain/mascota_failure.dart` (full file, 13 lines, read this session) — copy verbatim, substitute the class name:
```dart
// lib/features/patients/domain/mascota_failure.dart:1-12
class MascotaFailure implements Exception {
  const MascotaFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
```
`ConsultaFailure` is the exact same shape (`implements Exception`, single `message` field, `toString()` override) — this is the codebase's one established per-feature-exception convention (`AuthFailure`, `ClienteFailure`, `MascotaFailure`, all identical).

---

### `lib/features/clinical_history/data/repositories/supabase_consulta_repository.dart` (service, CRUD)

**Analog:** `lib/features/patients/data/repositories/supabase_mascota_repository.dart` (full file, 339 lines, read this session).

**Constructor + two-tier error handling — copy exactly** (`supabase_mascota_repository.dart:39-42`, `156-188`):
```dart
class SupabaseMascotaRepository {
  SupabaseMascotaRepository(this._client);
  final SupabaseClient _client;
  ...
  Future<String> registrarMascota({...}) async {
    try {
      final id = await _client.rpc('registrar_mascota', params: params);
      return id as String;
    } on PostgrestException catch (e) {
      throw MascotaFailure(_messageFor(e));
    } catch (_) {
      throw const MascotaFailure('No pudimos guardar los datos. Intenta de nuevo.');
    }
  }
```
`SupabaseConsultaRepository.registrarConsulta()` is the identical shape calling `registrar_consulta` instead — full body already written in `03-RESEARCH.md` Pattern 2's "Dart call site" block, copy verbatim.

**`porMascota()` (list query) — copy shape from `pesos()`** (`supabase_mascota_repository.dart:257-277`):
```dart
Future<List<PesoRegistro>> pesos(String mascotaId) async {
  try {
    final rows = await _client.from('mascota_pesos').select()
        .eq('mascota_id', mascotaId).order('registrado_en', ascending: false);
    return (rows as List).map((row) => _pesoFromRow(row as Map<String, dynamic>)).toList();
  } on PostgrestException catch (e) {
    throw MascotaFailure(_messageFor(e));
  } catch (_) {
    throw const MascotaFailure('No pudimos cargar el historial de peso. Intenta de nuevo.');
  }
}
```
`SupabaseConsultaRepository.porMascota()` mirrors this exactly, ordering by `fecha desc` — full body (including `_fromRow` mapping `peso_kg`/`temperatura_c`/etc. into `ExamenFisico`) already written in `03-RESEARCH.md`'s "Code Examples" section, copy verbatim.

**`_messageFor` centralized-translation pattern — copy structure from** (`supabase_mascota_repository.dart:323-338`):
```dart
String _messageFor(PostgrestException e) {
  switch (e.code) {
    case '42501': return 'No tienes permiso para realizar esta acción.';
    case '23503': return 'El dueño seleccionado no existe en tu clínica.';
    case '23514': return 'Revisa los datos ingresados.';
    default: return 'No pudimos guardar los datos. Intenta de nuevo.';
  }
}
```
`ConsultaRepository._messageFor` swaps the `23503` message to "La mascota no existe en tu clínica." (per Copywriting Contract) — same `switch`-on-`.code` shape, no new pattern.

**No `actualizar`/`eliminar` method — this is HIST-04's structural enforcement at the Dart layer** (mirrors the fact that `SupabaseMascotaRepository` has no `actualizarPeso`/`eliminarPeso` either, per its own doc comment on `pesos()`, line 258-259).

---

### `lib/features/clinical_history/data/services/historia_clinica_pdf_service.dart` (service, transform + file-I/O) — NEW PATTERN

**Analog:** none in the codebase (first PDF/document-assembly service) — structurally mirrors the repository constructor-injection shell (no `SupabaseClient` dependency here, just a pure function of `Mascota`+`List<Consulta>` → `Uint8List`). Full implementation already written and reviewed in `03-RESEARCH.md` Pattern 5 — copy verbatim:
```dart
class HistoriaClinicaPdfService {
  Future<Uint8List> generar({required Mascota mascota, required List<Consulta> consultas}) async {
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));
    doc.addPage(pw.MultiPage(...));
    return doc.save();
  }
}
```
Register via a plain `Provider<HistoriaClinicaPdfService>` (no `SupabaseClient` injection needed) — same `Provider` wiring shape as every other service provider, e.g. `mascotaRepositoryProvider` (`mascotas_providers.dart:11-13`).

---

### `lib/features/clinical_history/presentation/providers/consultas_providers.dart` (provider, CRUD + event-driven)

**Analog:** `lib/features/patients/presentation/providers/mascotas_providers.dart` (full file, 117 lines, read this session).

**Repository-provider + `FutureProvider.autoDispose.family` shape — copy exactly** (`mascotas_providers.dart:11-13`, `23-30`, `34-37`):
```dart
final mascotaRepositoryProvider = Provider<SupabaseMascotaRepository>((ref) {
  return SupabaseMascotaRepository(ref.watch(supabaseClientProvider));
});

final mascotaProvider = FutureProvider.autoDispose.family<Mascota, String>((ref, mascotaId) {
  return ref.watch(mascotaRepositoryProvider).obtener(mascotaId);
});

final pesosProvider = FutureProvider.autoDispose.family<List<PesoRegistro>, String>((ref, mascotaId) {
  return ref.watch(mascotaRepositoryProvider).pesos(mascotaId);
});
```
`consultaRepositoryProvider` + `consultasProvider = FutureProvider.autoDispose.family<List<Consulta>, String>((ref, mascotaId) => ref.watch(consultaRepositoryProvider).porMascota(mascotaId))` follow this identical shape — no `AsyncNotifier`/debounce needed here (unlike `MascotasNotifier`, there is no search-as-you-type requirement for a timeline).

**Dual invalidation after save (D-02/Pitfall 3) — mirrors `_cambiarFoto`'s existing dual-invalidation** (`mascota_detail_screen.dart:77-78`):
```dart
ref.invalidate(mascotaProvider(widget.mascotaId));
ref.read(mascotasProvider.notifier).refrescar();
```
`ConsultaFormScreen`'s save handler must do the equivalent: `ref.invalidate(consultasProvider(mascotaId))` **and**, only if `pesoKg != null`, `ref.invalidate(pesosProvider(mascotaId))` — same "invalidate every provider whose underlying data just changed" rule, applied to two providers instead of one.

---

### `lib/features/clinical_history/presentation/widgets/historia_clinica_timeline.dart` (component/widget, request-response)

**Analog:** `_HistorialPeso` in `lib/features/patients/presentation/screens/mascota_detail_screen.dart:239-302` (private `ConsumerWidget`, read this session).

**Defensive client-side sort + `AsyncValue.when` shape — copy exactly** (`mascota_detail_screen.dart:245-269`):
```dart
class _HistorialPeso extends ConsumerWidget {
  const _HistorialPeso({required this.mascotaId});
  final String mascotaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pesosAsync = ref.watch(pesosProvider(mascotaId));
    return pesosAsync.when(
      data: (pesos) {
        if (pesos.isEmpty) { /* empty-state copy */ }
        final ordenados = List<PesoRegistro>.of(pesos)
          ..sort((a, b) => b.registradoEn.compareTo(a.registradoEn));
        return Column(children: [ /* rows */ ]);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Text('No pudimos cargar el historial de peso. Intenta de nuevo.'),
    );
  }
}
```
`HistoriaClinicaTimeline` (public, since it's referenced from `mascota_detail_screen.dart`) is the identical shape watching `consultasProvider(mascotaId)`, sorting by `fecha` descending, rendering `AppCard`-per-consulta with the expand/collapse `bool` local to each card (per `03-UI-SPEC.md`'s "New Component Patterns" section — expand state is per-card, no navigation). Empty-state copy per Copywriting Contract: "Aún no hay consultas registradas" / "Usa "Nueva consulta" para agregar la primera." — exact wording sourced from `03-UI-SPEC.md`, not invented ad hoc, mirroring how `_HistorialPeso`'s own empty-state copy (`mascota_detail_screen.dart:255-263`) was sourced from `02-UI-SPEC.md`.

**Expand/collapse chevron icon pair — copy exactly from `MascotaCamposSection`'s disclosure** (`mascota_campos_section.dart:85-90`):
```dart
Icon(
  detallesExpandidos ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
  color: AppColors.textMuted,
)
```
Per `03-UI-SPEC.md`: this exact icon pair, not a different family, for the timeline card's own expand/collapse chevron.

---

### `lib/features/patients/presentation/screens/mascota_detail_screen.dart` (EDIT — extend, not replace)

**Analog:** the file itself (full file, 396 lines, read this session).

**Insertion point — after the existing "Historial de peso" section** (`mascota_detail_screen.dart:169-180`):
```dart
const SizedBox(height: AppSpacing.xl),
Text('Historial de peso', style: textTheme.titleMedium),
const SizedBox(height: AppSpacing.md),
_HistorialPeso(mascotaId: widget.mascotaId),
const SizedBox(height: AppSpacing.sm),
AppButton(
  label: 'Registrar peso', icon: Icons.add,
  variant: AppButtonVariant.text, expand: false,
  onPressed: _abrirRegistrarPeso,
),
```
Add, immediately after, the new "Historia clínica" section using the exact same `titleMedium` heading treatment, then `HistoriaClinicaTimeline(mascotaId: widget.mascotaId)`, then the primary "Nueva consulta" `AppButton` (`AppButtonVariant.primary`, `icon: Icons.add`) pushing `'$rutaBase/consultas/nueva'` — same `context.push('$rutaBase/...')` mechanism the existing "Editar" button already uses (line 147).

**Required change — demote "Editar" to outline** (`mascota_detail_screen.dart:144-148`, current):
```dart
AppButton(
  label: 'Editar',
  icon: Icons.edit_outlined,
  onPressed: () => context.push('$rutaBase/editar'),
),
```
Add `variant: AppButtonVariant.outline` — per `03-UI-SPEC.md`'s "Required change to already-shipped Phase 2 UI," this is the one accent-CTA-per-screen rule reassigning the slot to "Nueva consulta."

**"Exportar PDF" top-bar action** — extend the existing static `AppTopBar` (line 104, `const AppTopBar(title: 'Paciente')`) with an `actions` list containing the icon button; loading-state icon-swap mirrors `AppButton.isLoading`'s existing spinner-swap pattern (no new widget needed, just a local `bool _exportando` analogous to `_subiendoFoto` at line 41).

---

### `lib/features/patients/presentation/pacientes_routes.dart` / `lib/features/clients/presentation/clientes_routes.dart` (route, request-response)

**Analog:** the files themselves — existing `editar` child `GoRoute`s.

**`pacientes_routes.dart:20-26` (current):**
```dart
routes: [
  GoRoute(
    path: 'editar',
    builder: (_, state) => MascotaFormScreen(mascotaId: state.pathParameters['id']!),
  ),
],
```
Add a sibling `GoRoute(path: 'consultas/nueva', builder: (_, state) => ConsultaFormScreen(mascotaId: state.pathParameters['id']!))` inside the same `routes:` list.

**`clientes_routes.dart:37-45` (current, under `mascotas/:mascotaId`):**
```dart
routes: [
  GoRoute(
    path: 'editar',
    builder: (_, state) => MascotaFormScreen(mascotaId: state.pathParameters['mascotaId']!),
  ),
],
```
Add the equivalent sibling route reading `state.pathParameters['mascotaId']!` — both route files must gain the child so `'$rutaBase/consultas/nueva'` resolves identically whichever parent screen opened the ficha (exact same dual-route-file requirement Phase 2 already established for `editar`).

---

### `lib/features/clinical_history/presentation/screens/consulta_form_screen.dart` (component/screen, request-response)

**Analog:** `lib/features/clients/presentation/screens/nuevo_cliente_mascota_screen.dart` (full file, 244 lines, read this session) for the manual-validation + submit-gate + `AppButton.isLoading` shape; `lib/features/patients/presentation/widgets/mascota_campos_section.dart` (full file, 121 lines, read this session) for the collapsed-optional-details disclosure pattern.

**Submit-gate boolean — copy shape from** (`nuevo_cliente_mascota_screen.dart:74-78`):
```dart
bool get _puedeGuardar =>
    _clienteNombreCtrl.text.trim().isNotEmpty &&
    _telefonoCtrl.text.trim().isNotEmpty &&
    _mascotaNombreCtrl.text.trim().isNotEmpty &&
    _especie != null;
```
`ConsultaFormScreen._puedeGuardar` is `_diagnosticoCtrl.text.trim().isNotEmpty && _tratamientoCtrl.text.trim().isNotEmpty` only (D-03) — no other field gates submission, per `03-UI-SPEC.md`.

**Submit handler try/finally shape — copy exactly** (`nuevo_cliente_mascota_screen.dart:86-163`, condensed):
```dart
Future<void> _submit() async {
  final peso = parsearPeso(_pesoCtrl.text);
  if (peso.error != null) { setState(() => _pesoError = peso.error); return; }
  setState(() { _pesoError = null; _loading = true; _error = null; });
  try {
    await ref.read(consultaRepositoryProvider).registrarConsulta(...);
    ref.invalidate(consultasProvider(widget.mascotaId));
    if (pesoIngresado) ref.invalidate(pesosProvider(widget.mascotaId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Consulta guardada')));
    context.pop();
  } on ConsultaFailure catch (e) {
    if (mounted) setState(() => _error = e.message);
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}
```
Numeric-field validation for temperatura/frecuencias reuses `parsearPeso`'s validation-message wording family ("Ingresa un valor numérico válido") per Copywriting Contract — do not invent a new validator shape.

**Collapsed-optional-details disclosure — copy exactly** (`mascota_campos_section.dart:69-94`):
```dart
InkWell(
  onTap: onToggleDetalles,
  child: Container(
    constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
    alignment: Alignment.centerLeft,
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text('Agregar más detalles', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textMuted)),
      Icon(detallesExpandidos ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.textMuted),
    ]),
  ),
),
if (detallesExpandidos) ...[ /* optional AppTextFields */ ],
```
Applied to consulta fields: anamnesis, examen físico sub-fields (peso/temperatura/frecuencias/mucosas), evolución — all collapsed by default, per `03-UI-SPEC.md`. This is a feature-local `Column` inline in `ConsultaFormScreen`, not a new shared widget (per UI-SPEC: "no new widget goes into `core/widgets/**` this phase").

---

### `pubspec.yaml` (config)

**Analog:** the file itself, current dependency block (lines 30-45, read this session) — no exact-pinned (non-`^`) dependency exists yet in the file; this phase introduces the first one, per the `cached_network_image` caret-trap lesson already learned in Phase 2 (see `02-RESEARCH.md`).
```yaml
dependencies:
  ...
  cached_network_image: ^3.4.1   # existing — caret, already-resolved-safe version

  # NEW this phase — exact pins, NOT caret (03-RESEARCH.md Pitfall 1):
  pdf: 3.12.0
  printing: 5.14.3
```
Manual edit only — never `flutter pub add pdf printing` (would resolve to the incompatible latest). Run `flutter pub get`, not `flutter pub upgrade`.

---

### `test/helpers/fake_consultas.dart` (test helper, request-response)

**Analog:** `test/helpers/fake_mascotas.dart` (full file, 233 lines, read this session) — `FakeMascotaRepository`'s "fixed data/fixed error + call-log record list" shape.

**Shape to copy** (`fake_mascotas.dart:12-26`, `94-115`):
```dart
class FakeConsultaRepository implements SupabaseConsultaRepository {
  FakeConsultaRepository({List<Consulta> consultas = const [], this.error, this.idResultado = 'con-nueva'})
      : consultas = List.of(consultas);
  final List<Consulta> consultas;
  final Object? error;
  final String idResultado;

  final List<({String mascotaId, String diagnostico, String tratamiento, /* ...opcionales */})> registros = [];

  @override
  Future<List<Consulta>> porMascota(String mascotaId) async {
    if (error != null) throw error!;
    return consultas.where((c) => c.mascotaId == mascotaId).toList();
  }

  @override
  Future<String> registrarConsulta({required String mascotaId, required String diagnostico, required String tratamiento, ...}) async {
    registros.add((mascotaId: mascotaId, diagnostico: diagnostico, tratamiento: tratamiento));
    if (error != null) throw error!;
    return idResultado;
  }
}
```
Deliberately do NOT sort `consultas` in the fake's `porMascota()` — same reasoning as `fake_mascotas.dart:28-32`'s comment on `pesosPorMascota`: the fake returns data unsorted so the test verifies the *screen* (or provider) does the defensive sort, not the fake.

---

### `test/consultas_providers_test.dart` (test, request-response)

**Analog:** `test/mascotas_providers_test.dart` (full file, 191 lines, read this session) — `_containerWith` + `ProviderContainer.overrides` pattern.

**Container-setup shape — copy exactly** (`mascotas_providers_test.dart:20-37`):
```dart
ProviderContainer _containerWith({required FakeConsultaRepository repo, AuthProfile? profile = vetProfile}) {
  return ProviderContainer(
    retry: (retryCount, error) => null,
    overrides: [
      authProfileProvider.overrideWith(() => FakeAuthProfileNotifier(profile: profile)),
      consultaRepositoryProvider.overrideWithValue(repo),
    ],
  );
}
```
`retry: (retryCount, error) => null` disables Riverpod 3's default retry so a thrown `ConsultaFailure` settles into `AsyncError` immediately — same non-negotiable line every provider test in this repo already carries.

**D-02 single-RPC-call assertion (per 03-RESEARCH.md's test map)** — assert `repo.registros` has exactly one entry after a `registrarConsulta(..., pesoKg: 4.2)` call, mirroring how `mascotas_providers_test.dart`'s debounce test asserts `repo.busquedas` call *count*, not just content (lines 163-189).

---

### `test/consulta_form_screen_test.dart` (test, request-response)

**Analog:** `test/nuevo_cliente_mascota_screen_test.dart` (widget test over a manual-validation create form — not read in full this session, but its sibling `mascota_detail_screen_test.dart`'s `routerHarness` + fake-override wiring, read this session, is the shared scaffolding both use).

**`routerHarness` + override wiring — copy exactly** (`mascota_detail_screen_test.dart:42-80`):
```dart
Widget _appUnderTest({required FakeConsultaRepository repo, String initialLocation = '/pacientes/m-1/consultas/nueva'}) {
  return routerHarness(
    initialLocation: initialLocation,
    routes: [ /* nest ConsultaFormScreen under /pacientes/:id/consultas/nueva */ ],
    overrides: [
      authProfileProvider.overrideWith(() => FakeAuthProfileNotifier(profile: vetProfile)),
      consultaRepositoryProvider.overrideWithValue(repo),
    ],
  );
}
```
Core assertion (HIST-01/D-03, per 03-RESEARCH.md's test map): the "Guardar consulta" button stays disabled while diagnóstico/tratamiento are empty, and becomes tappable — never gated by anamnesis/examen físico/evolución — mirroring how `nuevo_cliente_mascota_screen.dart:74-78`'s `_puedeGuardar` boolean is the thing under test, not a `Form.validate()` call.

---

### `test/historia_clinica_pdf_service_test.dart` (test, request-response) — NEW PATTERN

**Analog:** none — first PDF-service test in the codebase. Plain `test()` (not `testWidgets`) calling `HistoriaClinicaPdfService().generar(mascota: ..., consultas: [...])` and asserting `bytes.isNotEmpty` — no fake/mock needed since the service takes no `SupabaseClient`/network dependency other than the font fetch (03-RESEARCH.md flags this may need a slower integration-style test or a stubbed font loader — Assumptions Log A3 already documents the one open verification gap, real-device UAT for `Printing.sharePdf` permissions, separately from this unit test).

---

### `test/mascota_detail_screen_test.dart` (EDIT — extend)

**Analog:** the file itself (existing `_appUnderTest`/`routerHarness` scaffolding, `_pesosRocky` deliberately-unsorted seed pattern, lines 18-40, read this session).

**HIST-02 ordering-assertion pattern — mirror the existing (implied) weight-ordering test exactly**, seeding `consultas` deliberately out of chronological order (same technique as `_pesosRocky`) and asserting the rendered timeline shows them newest-first — add a `FakeConsultaRepository` override alongside the existing `FakeMascotaRepository`/`FakeMascotaFotoDatasource` overrides in `_appUnderTest`.

---

### `supabase/tests/rls_smoke_test.sql` (EDIT — extend)

**Analog:** the file itself — existing two-clinic (`vet_a`/`vet_b`) throwaway setup, per 03-RESEARCH.md's Validation Architecture section (file not re-read in full this session; shape confirmed via 03-RESEARCH.md's direct citation of it as a primary source). Extend with `consultas` positive (own-clinic select/insert succeed) and negative (cross-clinic select/insert denied, update/delete denied for the owning vet) cases, following the exact same test-case shape already used for `mascota_pesos`/`mascotas`.

## Shared Patterns

### Two-tier error handling (domain `Failure` exception + `PostgrestException` translation)
**Source:** `lib/features/patients/data/repositories/supabase_mascota_repository.dart:78-84, 323-338`
**Apply to:** `SupabaseConsultaRepository` — every method wraps its Supabase/`.rpc()` call in `try { ... } on PostgrestException catch (e) { throw ConsultaFailure(_messageFor(e)); } catch (_) { throw const ConsultaFailure('...'); }`.

### Single Supabase-client injection point
**Source:** `lib/core/data/supabase_client_provider.dart` (never touch `Supabase.instance.client` inline)
**Apply to:** `consultaRepositoryProvider` — `SupabaseConsultaRepository(ref.watch(supabaseClientProvider))`, identical to `mascotaRepositoryProvider` (`mascotas_providers.dart:11-13`).

### Atomic multi-table write via RPC, never sequential client calls
**Source:** `supabase/schema.sql`'s `registrar_mascota` (lines 315-350) + `lib/features/patients/data/repositories/supabase_mascota_repository.dart:160-188` (Dart call site)
**Apply to:** `registrar_consulta` + `SupabaseConsultaRepository.registrarConsulta()` — a peso captured mid-consulta is written to `mascota_pesos` inside the same RPC transaction, never a second client-side `.insert()`.

### Dual-provider invalidation after a cross-cutting write
**Source:** `lib/features/patients/presentation/screens/mascota_detail_screen.dart:77-78` (`_cambiarFoto`)
**Apply to:** `ConsultaFormScreen`'s save handler — invalidate `consultasProvider(mascotaId)` and, only if a `pesoKg` was entered, `pesosProvider(mascotaId)`.

### No `copyWith` / no update-delete method on append-only entities
**Source:** `lib/features/patients/domain/entities/peso_registro.dart:1-6` (doc comment) + `SupabaseMascotaRepository`'s absent `actualizarPeso`/`eliminarPeso`
**Apply to:** reconciled `Consulta` entity (no `copyWith`) and `SupabaseConsultaRepository` (no `actualizar`/`eliminar` method) — HIST-04 enforced at every client-side layer, backed by Postgres having no `update`/`delete` policy at all.

### Reusable widget wrapping (never raw Material widgets)
**Source:** `lib/core/widgets/{app_bar/app_top_bar,buttons/app_button,cards/app_card,inputs/app_text_field}.dart`
**Apply to:** `ConsultaFormScreen`, `HistoriaClinicaTimeline` — `AppTopBar`/`AppButton`/`AppCard`/`AppTextField` mandatory; per `03-UI-SPEC.md`, the one new visual pattern (timeline card) stays feature-local in `lib/features/clinical_history/presentation/widgets/**`, not promoted to `core/widgets/**`.

### Manual field validation before submit (no `Form`/`validator` widgets)
**Source:** `lib/features/clients/presentation/screens/nuevo_cliente_mascota_screen.dart:74-78, 86-102`
**Apply to:** `ConsultaFormScreen` — `setState`-driven `_puedeGuardar` boolean gates the submit button's `onPressed`; numeric-field parsing reuses `parsearPeso`-style `({double? valor, String? error})` record return shape (`lib/core/utils/formato.dart:49-58`) for temperatura/frecuencias, not a new validator convention.

### Concrete repository classes, no `domain/repositories/` interface
**Source:** `lib/features/patients/data/repositories/supabase_mascota_repository.dart` (no `implements`, no interface file)
**Apply to:** `SupabaseConsultaRepository` — do not add a `domain/repositories/consulta_repository.dart` interface, consistent with every other feature's repository in this codebase.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `lib/features/clinical_history/data/services/historia_clinica_pdf_service.dart` | service | transform + file-I/O | First PDF-document-assembly service in the codebase; no `pdf`/`printing` usage anywhere in `lib/`. Use `03-RESEARCH.md` Pattern 5 (fully written, cites official `pdf`/`printing` docs) verbatim. |
| `test/historia_clinica_pdf_service_test.dart` | test | request-response | First PDF-service test; no fake/mock precedent needed since the service has no `SupabaseClient` dependency — plain `test()` asserting non-empty bytes. |
| `Printing.sharePdf(...)` native-share call site (inside `mascota_detail_screen.dart`'s new "Exportar PDF" action) | component (behavior only) | file-I/O | First native-OS-share-sheet integration; no `share_plus`/`MethodChannel` precedent anywhere in `lib/`. Use `03-RESEARCH.md` Pattern 5's call-site block verbatim — one line, no custom platform code. |

## Metadata

**Analog search scope:** `lib/features/patients/**`, `lib/features/clients/**`, `lib/features/clinical_history/**`, `lib/core/{data,utils,widgets,theme}/**`, `supabase/schema.sql`, `test/**`, `test/helpers/**`
**Files scanned:** 16 Dart files + `pubspec.yaml` + `supabase/schema.sql` (targeted grep) directly read this session, plus `02-PATTERNS.md` (Phase 2's own pattern map) as secondary corroboration for conventions already established before this phase
**Pattern extraction date:** 2026-09-26
