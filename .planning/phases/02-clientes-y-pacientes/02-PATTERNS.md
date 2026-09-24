# Phase 2: Clientes y Pacientes - Pattern Map

**Mapped:** 2026-09-24
**Files analyzed:** 24 (new/edited, excluding pure SQL migration statements already fully specified in 02-RESEARCH.md)
**Analogs found:** 20 exact/role-match / 24 total (4 are new widget/entity shapes with no direct precedent — analog is 02-RESEARCH.md's already-reviewed Code Examples)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/features/clients/domain/entities/cliente.dart` (EDIT: reconcile to schema) | model | CRUD | `lib/features/auth/data/repositories/supabase_auth_repository.dart` (`AuthProfile` shape) | role-match |
| `lib/features/patients/domain/entities/mascota.dart` (EDIT: reconcile to schema) | model | CRUD | same as above | role-match |
| `lib/features/patients/domain/entities/peso_registro.dart` (NEW) | model | CRUD | none — new entity shape; 02-RESEARCH.md Code Examples | new-pattern |
| `lib/features/clients/data/repositories/supabase_cliente_repository.dart` (NEW) | service (repository) | CRUD | `lib/features/auth/data/repositories/supabase_auth_repository.dart` | exact |
| `lib/features/patients/data/repositories/supabase_mascota_repository.dart` (NEW) | service (repository) | CRUD | `lib/features/auth/data/repositories/supabase_auth_repository.dart` | exact |
| `lib/features/patients/data/datasources/mascota_foto_datasource.dart` (NEW) | service (datasource) | file-I/O | `lib/features/auth/data/repositories/supabase_auth_repository.dart` (constructor-injected `SupabaseClient` shape only) | role-match |
| `lib/features/clients/presentation/providers/clientes_providers.dart` (NEW) | provider | CRUD + event-driven (debounced search) | `lib/features/auth/presentation/providers/auth_providers.dart` | role-match |
| `lib/features/patients/presentation/providers/mascotas_providers.dart` (NEW) | provider | CRUD + event-driven | `lib/features/auth/presentation/providers/auth_providers.dart` | role-match |
| `lib/core/router/app_router.dart` (EDIT: repoint `/clientes`, `/pacientes`, add detail/form/nuevo routes) | route/config | request-response | `lib/core/router/app_router.dart` (itself) | exact |
| `lib/features/clients/presentation/screens/clientes_list_screen.dart` (NEW) | component (screen) | request-response | `lib/features/home/presentation/screens/inicio_screen.dart` (`AsyncValue.when` + `AppTopBar`/`AppCard` shape) | role-match |
| `lib/features/clients/presentation/screens/cliente_detail_screen.dart` (NEW) | component (screen) | request-response | `lib/features/home/presentation/screens/inicio_screen.dart` | role-match |
| `lib/features/clients/presentation/screens/nuevo_cliente_mascota_screen.dart` (NEW) | component (screen) | request-response (RPC call) | `lib/features/auth/presentation/screens/register_screen.dart` (multi-field form + manual validation + `AppButton.isLoading` submit) | role-match |
| `lib/features/patients/presentation/screens/pacientes_list_screen.dart` (NEW) | component (screen) | request-response | `lib/features/clients/presentation/screens/clientes_list_screen.dart` (sibling, same phase) | exact (intra-phase) |
| `lib/features/patients/presentation/screens/mascota_detail_screen.dart` (NEW) | component (screen) | request-response | `lib/features/clients/presentation/screens/cliente_detail_screen.dart` (sibling, same phase) | exact (intra-phase) |
| `lib/features/patients/presentation/screens/mascota_form_screen.dart` (NEW) | component (screen) | request-response | `lib/features/auth/presentation/screens/register_screen.dart` | role-match |
| `lib/core/widgets/chips/app_filter_chip.dart` (NEW) | component (shared widget) | transform | `lib/core/widgets/status/app_status_chip.dart` | role-match |
| `lib/core/widgets/media/app_photo_picker.dart` (NEW) | component (shared widget) | file-I/O | `lib/core/widgets/cards/app_card.dart` (`StatelessWidget` shell shape only — camera/upload logic itself has no analog) | role-match (shell) / new-pattern (behavior) |
| `supabase/schema.sql` (EDIT: `foto_path`, `mascota_pesos` table, `perfiles_id`/`codigo_vinculacion`/`codigo_expira_en`, `registrar_cliente_con_mascota` RPC, storage bucket+RLS) | migration | CRUD | `supabase/schema.sql` (itself — `clientes`/`mascotas` tables+RLS, `mi_clinica_id()`/`es_veterinario()` helpers) | exact |
| `test/helpers/fake_clientes.dart` (NEW) | test (helper) | request-response | `test/helpers/fake_auth.dart` | exact |
| `test/helpers/fake_mascotas.dart` (NEW) | test (helper) | request-response | `test/helpers/fake_auth.dart` | exact |
| `test/clientes_providers_test.dart` (NEW) | test | request-response | `test/inicio_screen_test.dart` (only provider-override test pattern in repo) | role-match |
| `test/mascotas_providers_test.dart` (NEW) | test | request-response | `test/inicio_screen_test.dart` | role-match |
| `test/cliente_detail_screen_test.dart` (NEW) | test | request-response | `test/inicio_screen_test.dart` | role-match |
| `test/mascota_detail_screen_test.dart` (NEW) | test | request-response | `test/inicio_screen_test.dart` | role-match |

## Pattern Assignments

### `lib/features/clients/domain/entities/cliente.dart` (model, CRUD)

**Analog:** the file itself (current scaffolded shape, must be reconciled to `supabase/schema.sql:31-42`, read this session).

**Current (broken) shape to replace entirely:**
```dart
class Cliente {
  const Cliente({
    required this.id,
    required this.veterinarioId,   // WRONG — schema has clinica_id, not a per-vet column
    required this.nombre,
    required this.telefono,
    this.email,
    this.direccion,
    this.mascotaIds = const [],    // WRONG — not a stored column, would drift out of sync
  });
  ...
}
```

**Target shape** (per 02-RESEARCH.md "Pattern 1", already reviewed against the live schema — `clientes` columns are `id, clinica_id, nombre, telefono, email, direccion, notas, created_at, updated_at`, plus this phase's `perfiles_id`/`codigo_vinculacion`/`codigo_expira_en` additions):
```dart
class Cliente {
  const Cliente({
    required this.id,
    required this.clinicaId,
    required this.nombre,
    required this.telefono,
    this.email,
    this.direccion,
    this.notas,
    this.perfilesId,
    this.codigoVinculacion,
    this.codigoExpiraEn,
  });

  final String id;
  final String clinicaId;
  final String nombre;
  final String telefono;
  final String? email;
  final String? direccion;
  final String? notas;
  final String? perfilesId;
  final String? codigoVinculacion;
  final DateTime? codigoExpiraEn;

  bool get tieneVinculacion => perfilesId != null;

  Cliente copyWith({String? nombre, String? telefono, String? email, String? direccion, String? notas}) =>
      Cliente(id: id, clinicaId: clinicaId, nombre: nombre ?? this.nombre,
          telefono: telefono ?? this.telefono, email: email ?? this.email,
          direccion: direccion ?? this.direccion, notas: notas ?? this.notas,
          perfilesId: perfilesId, codigoVinculacion: codigoVinculacion, codigoExpiraEn: codigoExpiraEn);
}
```
`copyWith` shape (named-optional params, `?? this.field`) copied from the existing `Mascota.copyWith` (`lib/features/patients/domain/entities/mascota.dart:47-72`, read this session) — that is this codebase's one established `copyWith` convention. `mascotaIds` is permanently removed — mascotas-for-cliente is always a live query, never denormalized (per 02-RESEARCH.md Schema Gaps table).

---

### `lib/features/patients/domain/entities/mascota.dart` (model, CRUD)

**Analog:** the file itself (current scaffolded shape, must be reconciled to `supabase/schema.sql:60-71`).

**Fields to remove** (confirmed absent from schema and out of PAT-01..05 scope): `veterinarioId` (→ `clinicaId`), `sexo`, `color`, `esterilizado`, mutable `pesoKg` (→ separate `mascota_pesos` query via `peso_registro.dart`). **Field to add:** `fotoPath` (object key, `mascotas.foto_path`, new column this phase — never store the signed URL, per 02-RESEARCH.md Anti-Patterns and Pitfall 1).

**Target shape:**
```dart
enum Especie { perro, gato, otro }

class Mascota {
  const Mascota({
    required this.id,
    required this.duenoId,      // clientes.id — schema column name is dueno_id
    required this.clinicaId,
    required this.nombre,
    required this.especie,
    this.raza,
    this.fechaNacimiento,
    this.fotoPath,
  });

  final String id;
  final String duenoId;
  final String clinicaId;
  final String nombre;
  final Especie especie;
  final String? raza;
  final DateTime? fechaNacimiento;
  final String? fotoPath;

  int? get edadEnAnios {
    if (fechaNacimiento == null) return null;
    final now = DateTime.now();
    var edad = now.year - fechaNacimiento!.year;
    if (now.month < fechaNacimiento!.month ||
        (now.month == fechaNacimiento!.month && now.day < fechaNacimiento!.day)) {
      edad--;
    }
    return edad;
  }

  Mascota copyWith({String? nombre, Especie? especie, String? raza, DateTime? fechaNacimiento, String? fotoPath}) =>
      Mascota(id: id, duenoId: duenoId, clinicaId: clinicaId, nombre: nombre ?? this.nombre,
          especie: especie ?? this.especie, raza: raza ?? this.raza,
          fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento, fotoPath: fotoPath ?? this.fotoPath);
}
```
`edadEnAnios` getter copied verbatim from the existing file (`mascota.dart:36-45`) — this computed-getter pattern is already correct and schema-independent, keep it as-is. `Sexo` enum is deleted entirely (no `sexo` column, no requirement references it).

---

### `lib/features/patients/domain/entities/peso_registro.dart` (model, CRUD) — NEW PATTERN

**Analog:** none — first weight-history entity. Use 02-RESEARCH.md's Code Examples block verbatim (already reviewed):
```dart
class PesoRegistro {
  const PesoRegistro({required this.id, required this.mascotaId, required this.pesoKg, required this.registradoEn});
  final String id;
  final String mascotaId;
  final double pesoKg;
  final DateTime registradoEn;
}
```
No `copyWith` — per the append-only design decision (02-RESEARCH.md "no update/delete policy": corrections happen via a new row, never an edit), this entity is immutable and never mutated after creation.

---

### `lib/features/clients/data/repositories/supabase_cliente_repository.dart` (service, CRUD)

**Analog:** `lib/features/auth/data/repositories/supabase_auth_repository.dart` (full file, read this session).

**Constructor + failure-type pattern to copy exactly** (`supabase_auth_repository.dart:27-34` for the constructor shape; `AuthFailure` at `lib/features/auth/domain/auth_failure.dart` for the failure-type shape):
```dart
class ClienteFailure implements Exception {
  const ClienteFailure(this.message);
  final String message;
}

class SupabaseClienteRepository {
  SupabaseClienteRepository(this._client);
  final SupabaseClient _client;
  ...
}
```

**Two-tier error handling — copy verbatim from `signIn()`** (`supabase_auth_repository.dart:36-53`):
```dart
try {
  final row = await _client.from('clientes')
      .insert({'clinica_id': clinicaId, 'nombre': nombre.trim(), 'telefono': telefono.trim()})
      .select().single();
  return _fromRow(row);
} on PostgrestException catch (e) {
  throw ClienteFailure(_messageFor(e));
} catch (_) {
  throw const ClienteFailure('No fue posible crear el cliente. Intenta de nuevo.');
}
```
Note the SDK exception type changes from `AuthException` (auth feature) to `PostgrestException` (every other feature's Postgres calls) — this is the only substitution needed in the two-tier shape itself.

**`_messageFor` centralized-translation pattern — copy the *structure* from `supabase_auth_repository.dart:134-157`** (lowercased/coded substring checks → fixed Spanish string, generic catch-all last):
```dart
String _messageFor(PostgrestException e) {
  if (e.code == '23505') return 'Ya existe un cliente con estos datos.';
  return 'No fue posible completar la solicitud. Intenta de nuevo.';
}
```
Add new `PostgrestException.code`/`.message` mappings here as they're discovered — never inline a translation at a call site, per the established convention.

**Full CRUD + debounced search method bodies:** copy verbatim from 02-RESEARCH.md "Pattern 1" (`create()`, `search()`, `_fromRow()` already fully written and reviewed there) and "Pattern 3" (two-step owner-name search — `SupabaseMascotaRepository.search()` is the one that needs this, `SupabaseClienteRepository.search()` only needs its own-table `.or()`). Add `.update()`/`.getById()` following the exact same try/on-`PostgrestException`/catch-all shape shown above — no new pattern needed for those two methods.

---

### `lib/features/patients/data/repositories/supabase_mascota_repository.dart` (service, CRUD)

**Analog:** same as `SupabaseClienteRepository` above — `lib/features/auth/data/repositories/supabase_auth_repository.dart` for the two-tier error shape.

**Two-step search (own-field `.or()` + resolved-owner-id `.in.()`):** copy verbatim from 02-RESEARCH.md "Pattern 3" (already fully written, cites documented PostgREST filter-operator limitations for why the two-step approach is required instead of a single embedded-resource `.or()`).

**Combined create RPC call site:** copy verbatim from 02-RESEARCH.md "Pattern 4" Dart call-site block (`registrarClienteConMascota(...)` calling `_client.rpc('registrar_cliente_con_mascota', params: {...})`, unpacking the returned record). The matching SQL function (also in Pattern 4) is a `supabase/schema.sql` addition, not Dart code — see that file's assignment below.

**Weight-history methods (`pesos()`, `registrarPeso()`):** copy verbatim from 02-RESEARCH.md Code Examples block (already fully written).

---

### `lib/features/patients/data/datasources/mascota_foto_datasource.dart` (service/datasource, file-I/O) — NEW PATTERN (shell role-matches repositories)

**Analog:** structurally mirrors `SupabaseClienteRepository`'s constructor-injection shape (`this._client`, `final SupabaseClient _client`) but talks to Storage, not Postgres — no existing datasource file in the codebase to copy from (every `data/datasources/` folder in other features is empty per `01-PATTERNS.md`'s finding).

**Full implementation — copy verbatim from 02-RESEARCH.md "Supabase Storage" section** (`upload()`/`signedUrlFor()`, already fully written and cited against the `supabase_flutter` Storage API):
```dart
class MascotaFotoDatasource {
  MascotaFotoDatasource(this._client);
  final SupabaseClient _client;
  static const _bucket = 'mascota-fotos';

  Future<String> upload({required String clinicaId, required String mascotaId, required Uint8List bytes}) async {
    final path = '$clinicaId/$mascotaId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from(_bucket).uploadBinary(
      path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
    );
    return path;
  }

  Future<String> signedUrlFor(String path) => _client.storage.from(_bucket).createSignedUrl(path, 3600);
}
```
Constructor-inject via a new `mascotaFotoDatasourceProvider = Provider<MascotaFotoDatasource>((ref) => MascotaFotoDatasource(ref.watch(supabaseClientProvider)))` — same `Provider` + `supabaseClientProvider.watch` shape as `authRepositoryProvider` (`lib/features/auth/presentation/providers/auth_providers.dart:8-10`), never construct `Supabase.instance.client` inline.

---

### `lib/features/clients/presentation/providers/clientes_providers.dart` (provider, CRUD + debounced search)

**Analog:** `lib/features/auth/presentation/providers/auth_providers.dart` (full file, read this session) for the `Provider`/`AsyncNotifierProvider` wiring shape; 02-RESEARCH.md "Pattern 2" for the new debounce behavior.

**Repository-provider shape — copy exactly** (`auth_providers.dart:8-10`):
```dart
final clienteRepositoryProvider = Provider<SupabaseClienteRepository>((ref) {
  return SupabaseClienteRepository(ref.watch(supabaseClientProvider));
});
```

**`AsyncNotifier` + `Timer` debounce — copy verbatim from 02-RESEARCH.md "Pattern 2"** (already fully written, including the `ref.onDispose(() => _debounce?.cancel())` cleanup and the `AsyncValue.guard` call). The `build()` method's `ref.watch(authProfileProvider).value?.clinicaId` dependency mirrors how `AuthProfileNotifier.build()` itself reads `ref.watch(authRepositoryProvider)` (`auth_providers.dart:26`) — never re-derive `clinicaId` any other way (e.g. never re-query `perfiles` directly from this notifier).

**Pitfall to enforce (already flagged in 01-PATTERNS.md Pitfall 3, restated in 02-RESEARCH.md):** never cache `ref.read(clientesProvider.notifier)` in a local variable across an `await` — always `ref.read(...)` inline, exactly as `AuthProfileNotifier.signOut()` does (`auth_providers.dart:49-53`).

---

### `lib/features/patients/presentation/providers/mascotas_providers.dart` (provider, CRUD + debounced search)

**Analog:** same as `clientes_providers.dart` above — identical `AsyncNotifier`/`Timer`/`Provider` shape, swapping `Cliente`→`Mascota` and `SupabaseClienteRepository`→`SupabaseMascotaRepository`.

---

### `lib/core/router/app_router.dart` (route/config, request-response)

**Analog:** the file itself (full file, 125 lines, read this session).

**Exact stub routes being replaced** (lines 86-89, 102-105):
```dart
GoRoute(path: '/pacientes', builder: (_, _) => const ComingSoonScreen(title: 'Pacientes')),
...
GoRoute(path: '/clientes', builder: (_, _) => const ComingSoonScreen(title: 'Clientes')),
```
Replace each `builder` with the real list screen, and add nested/sibling `GoRoute`s for detail/form/create — following the same flat, no-nested-shell-route convention already used for `/cliente` (`ClientHomeScreen`, line 74) rather than introducing a new `StatefulShellBranch`. Suggested additions (planner's exact paths, consistent with existing `snake-case`-free `/kebab` convention seen in `/reset-password`):
```dart
GoRoute(path: '/clientes/nuevo', builder: (_, _) => const NuevoClienteMascotaScreen()),
GoRoute(path: '/clientes/:id', builder: (_, state) => ClienteDetailScreen(clienteId: state.pathParameters['id']!)),
GoRoute(path: '/pacientes/:id', builder: (_, state) => MascotaDetailScreen(mascotaId: state.pathParameters['id']!)),
```
These new routes stay **inside** the existing `StatefulShellRoute.indexedStack`'s `/clientes` and `/pacientes` branches (each `StatefulShellBranch.routes` list can hold more than one `GoRoute`, matching go_router's own nested-route support) — do not create a new top-level shell branch, since the bottom-nav tab count must stay fixed at 5 (per Phase 1's `AppShell`).

**`redirect:` logic (lines 34-61) requires no change** — clientes/mascotas routes are all vet-only screens reached through the existing `StatefulShellRoute`, already gated by the `!profile.esVeterinario` branch (line 47-49).

---

### `lib/features/clients/presentation/screens/clientes_list_screen.dart` / `pacientes_list_screen.dart` (component/screen, request-response)

**Analog:** `lib/features/home/presentation/screens/inicio_screen.dart` for the `AsyncValue.when` + `AppTopBar`/`AppCard` composition shape (per 02-RESEARCH.md Pattern reference and `01-PATTERNS.md`'s already-reviewed `InicioScreen` example):
```dart
class ClientesListScreen extends ConsumerWidget {
  const ClientesListScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientesAsync = ref.watch(clientesProvider);
    return Scaffold(
      appBar: const AppTopBar(title: 'Clientes'),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppTextField(label: '', hintText: 'Buscar por nombre o teléfono',
              onChanged: (q) => ref.read(clientesProvider.notifier).search(q)),
        ),
        Expanded(
          child: clientesAsync.when(
            data: (clientes) => clientes.isEmpty
                ? const Center(child: Text('Aún no tienes clientes'))
                : ListView.builder(itemCount: clientes.length, itemBuilder: (_, i) =>
                    AppCard(onTap: () => context.push('/clientes/${clientes[i].id}'),
                        child: Text(clientes[i].nombre))),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Center(child: Text('No pudimos cargar la lista. Intenta de nuevo.')),
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/clientes/nuevo'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```
Widgets referenced (`AppTopBar`, `AppCard`, `AppTextField`, `AppSpacing`) all read this session — see their own files at `lib/core/widgets/{app_bar,cards,inputs}/*.dart`. `error:` copy text sourced from `02-UI-SPEC.md`'s Copywriting Contract table, not invented ad hoc.

---

### `lib/features/clients/presentation/screens/cliente_detail_screen.dart` / `mascota_detail_screen.dart` (component/screen, request-response)

**Analog:** `inicio_screen.dart`'s `AsyncValue.when` shape (same as list screens above), composed with `AppTextField` for the editable-fields section and `AppButton` for the "Guardar cambios" CTA (`lib/core/widgets/buttons/app_button.dart`, full file read this session — note `AppButton.isLoading` already handles the disable+spinner state, no custom loading logic needed).

**"Vincular cuenta" bottom sheet (CLI-05):** no direct analog exists (first bottom-sheet in the codebase) — use `showModalBottomSheet` with the same `AppCard`/`AppButton` content composition as the rest of the screen; trigger the code-generation `UPDATE` via a new `SupabaseClienteRepository.generarCodigoVinculacion(clienteId)` method following the exact same two-tier `PostgrestException`/catch-all shape as every other repository method in this phase.

---

### `lib/features/clients/presentation/screens/nuevo_cliente_mascota_screen.dart` / `mascota_form_screen.dart` (component/screen, request-response)

**Analog:** `lib/features/auth/presentation/screens/register_screen.dart` for the multi-field-form + manual-validation + submit pattern (register screen already the codebase's only multi-section form with a loading-gated submit button).

**Manual validation-before-submit convention to preserve** (per `01-PATTERNS.md`'s note on `login_screen.dart`/`register_screen.dart`): checkbox-style `setState`-driven field checks, **not** a `Form`/`validator` widget tree — do not introduce `Form` widgets for these new screens, matching the established codebase convention.

**Exact scroll/section structure — copy verbatim from 02-RESEARCH.md "Combined Creation Screen UI" block** (already fully specified: `SingleChildScrollView` → two `AppCard` sections → single `AppButton`, no `PageView`/stepper per D-02).

**Submit handler — calls the RPC, not two sequential repository calls:**
```dart
Future<void> _submit() async {
  setState(() => _loading = true);
  try {
    await ref.read(mascotaRepositoryProvider).registrarClienteConMascota(
      clienteNombre: _nombreClienteCtrl.text, clienteTelefono: _telefonoCtrl.text,
      mascotaNombre: _nombreMascotaCtrl.text, mascotaEspecie: _especie!.name,
    );
    if (mounted) context.pop();
  } on MascotaFailure catch (e) {
    setState(() => _error = e.message);
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}
```
Catch pattern (`on MascotaFailure catch (e)`, never generic `Exception`) mirrors `register_screen.dart`'s existing `on AuthFailure catch (error)` convention exactly.

---

### `lib/core/widgets/chips/app_filter_chip.dart` (component/shared widget, transform)

**Analog:** `lib/core/widgets/status/app_status_chip.dart` (full file, 68 lines, read this session) — closest existing "small stateless indicator with an active/inactive visual state" shape in `core/widgets/`.

**Shape to follow (private record-based spec getter, `Container` + `BorderRadius.circular`, not `Chip`):**
```dart
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? Colors.white : null)),
      ),
    );
  }
}
```
Same reasoning as `AppStatusChip`'s doc comment (avoid raw `Chip`'s size-animation/font-swap clipping bug) applies here too — do not use `FilterChip`/`ChoiceChip` from Material, build on `Container`+`InkWell` per the existing precedent. Per `02-UI-SPEC.md`: pill radius (`AppSpacing.radiusLg` or greater), Label typography role, 44px minimum touch target (`AppSpacing.touchTarget`, existing token).

---

### `lib/core/widgets/media/app_photo_picker.dart` (component/shared widget, file-I/O) — NEW PATTERN

**Analog:** no behavioral precedent (first camera/upload widget) — `AppCard`'s `StatelessWidget` shell shape (`lib/core/widgets/cards/app_card.dart`, full file read this session) is the closest structural analog for "wraps a child in consistent visual chrome," but the camera-capture/upload/loading-state logic itself must follow 02-RESEARCH.md's "Camera-first capture flow" and "Common Pitfalls / Pitfall 1" sections verbatim:
```dart
Future<XFile?> capturePetPhoto(BuildContext context) async {
  var status = await Permission.camera.status;
  if (status.isDenied) status = await Permission.camera.request();
  if (status.isPermanentlyDenied) return null; // show dialog + openAppSettings(), per UI-SPEC Error Copy
  return ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 1600);
}
```
**Non-negotiable requirement (Pitfall 1):** every `CachedNetworkImage` inside this widget must pass `cacheKey: fotoPath` (the stable Storage object path), never relying on `imageUrl` alone as the cache key — the signed URL's query string changes on every fetch and silently defeats caching if `cacheKey` is omitted.

---

### `supabase/schema.sql` (migration, CRUD)

**Analog:** the file itself — follow its own established conventions exactly (Spanish `snake_case`, `drop policy if exists` + `create policy` pairing, `security definer`/`security invoker` helper-function reuse), confirmed via direct read of lines 1-75 and 87-196 this session.

**Existing helper functions to reuse as-is, never re-derive tenant scoping inline** (lines 123-129 area, confirmed present):
```sql
create or replace function public.mi_clinica_id() ...
create or replace function public.es_veterinario() ...
```
Every new policy this phase (`mascota_pesos`, `storage.objects`) must call these two functions, exactly matching the existing `clientes_select`/`mascotas_select` policy shape (lines 163-196):
```sql
drop policy if exists clientes_select on public.clientes;
create policy clientes_select on public.clientes for select to authenticated
using (public.es_veterinario() and clinica_id = public.mi_clinica_id());
```
**All net-new SQL (columns, `mascota_pesos` table+RLS, `registrar_cliente_con_mascota` RPC, `mascota-fotos` bucket+`storage.objects` RLS, `reclamar_codigo_cliente` design note for Phase 9) is already fully written and reviewed in 02-RESEARCH.md** — copy those blocks verbatim rather than re-deriving; the file's own existing `clientes`/`mascotas` table blocks (lines 31-71) are the "house style" reference confirming the additions match established constraint/index/trigger naming (`<table>_tocar_updated_at`, `<table>_<column>_idx`).

---

### `test/helpers/fake_clientes.dart` / `fake_mascotas.dart` (test helper, request-response)

**Analog:** `test/helpers/fake_auth.dart` (full file, 62 lines, read this session) — the only fake-notifier helper in the repo.

**Exact shape to copy** (`fake_auth.dart:11-27`, substituting `AuthProfileNotifier`→`ClientesNotifier`/`MascotasNotifier` and the return type):
```dart
class FakeClientesNotifier extends ClientesNotifier {
  FakeClientesNotifier({this.clientes = const [], this.error});
  final List<Cliente> clientes;
  final Object? error;

  @override
  Future<List<Cliente>> build() async {
    if (error != null) throw error!;
    return clientes;
  }
}
```
Usage mirrors `fake_auth.dart:52-62`'s `appUnderTest()` helper: `ProviderScope(overrides: [clientesProvider.overrideWith(() => FakeClientesNotifier(clientes: [...]))], child: ...)`.

---

### `test/{clientes,mascotas}_providers_test.dart`, `test/{cliente,mascota}_detail_screen_test.dart` (test, request-response)

**Analog:** `test/inicio_screen_test.dart` (only test file exercising a provider-backed screen; structural shape confirmed via `01-PATTERNS.md`'s prior read — `testWidgets` + `ProviderScope(overrides: [...])` + `pumpWidget` + `find.text`). Follow the same override-the-notifier-under-test pattern rather than mocking the repository/Supabase client directly.

## Shared Patterns

### Two-tier error handling (domain `Failure` exception + SDK-error translation)
**Source:** `lib/features/auth/data/repositories/supabase_auth_repository.dart:36-53, 134-157`
**Apply to:** `SupabaseClienteRepository`, `SupabaseMascotaRepository`, `MascotaFotoDatasource` (all methods touching Postgres/Storage this phase). Swap `AuthException`→`PostgrestException` (or, for `MascotaFotoDatasource`, `StorageException` where the Storage SDK throws its own type) as the specific branch; keep the generic `catch (_)` fallback with a Spanish message in every method.

### Single Supabase-client injection point
**Source:** `lib/core/data/supabase_client_provider.dart` (full file, 10 lines, read this session)
**Apply to:** every new repository/datasource `Provider` this phase (`clienteRepositoryProvider`, `mascotaRepositoryProvider`, `mascotaFotoDatasourceProvider`) — always `ref.watch(supabaseClientProvider)`, never `Supabase.instance.client` inline. This is the file's own doc comment: *"The ONLY place in the app allowed to touch `Supabase.instance.client`."*

### `AsyncNotifier` + inline `ref.read`/`ref.watch` (never cache the notifier across an `await`)
**Source:** `lib/features/auth/presentation/providers/auth_providers.dart:23-53`
**Apply to:** `ClientesNotifier`, `MascotasNotifier` — both their `build()` methods and their `search()`/mutation methods.

### Concrete repository classes, no `domain/repositories/` interface
**Source:** `lib/features/auth/data/repositories/supabase_auth_repository.dart` (no `implements AuthRepository`, no interface file consumed anywhere per `01-PATTERNS.md`'s finding)
**Apply to:** `SupabaseClienteRepository`, `SupabaseMascotaRepository` — explicitly do **not** add a `domain/repositories/cliente_repository.dart` interface, per 02-RESEARCH.md's "Alternatives Considered" table (introducing interfaces for only 2 of 3 features would make the codebase inconsistent).

### Reusable widget wrapping (never raw Material widgets for shared UI)
**Source:** `lib/core/widgets/{cards/app_card,inputs/app_text_field,buttons/app_button,status/app_status_chip}.dart`
**Apply to:** every new screen this phase — `AppTopBar`/`AppCard`/`AppTextField`/`AppButton` are mandatory instead of raw `AppBar`/`Card`/`TextFormField`/`ElevatedButton`; the two new widgets (`AppFilterChip`, `AppPhotoPicker`) must go in `lib/core/widgets/**` (not feature-local) so Phases 4-8 can reuse them, per `02-UI-SPEC.md`'s explicit instruction.

### Manual field validation before submit (no `Form`/`validator` widgets)
**Source:** `lib/features/auth/presentation/screens/{login,register}_screen.dart` (per `01-PATTERNS.md`'s documented convention)
**Apply to:** `NuevoClienteMascotaScreen`, `MascotaFormScreen` — `setState`-driven manual checks gate the submit button's `onPressed`, matching the existing codebase convention exactly.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `lib/features/patients/domain/entities/peso_registro.dart` | model | CRUD | First append-only history entity in the codebase; no `copyWith`-mutable-entity precedent applies (deliberately immutable). Use 02-RESEARCH.md Code Examples verbatim. |
| `lib/core/widgets/media/app_photo_picker.dart` (camera/upload behavior, not the shell) | component | file-I/O | First camera-capture/Storage-upload widget; no prior `image_picker`/`flutter_image_compress`/`cached_network_image` usage anywhere in `lib/`. Use 02-RESEARCH.md "Camera-first capture flow" + "Pitfall 1" sections verbatim. |
| `lib/features/patients/data/datasources/mascota_foto_datasource.dart` | service/datasource | file-I/O | Every `data/datasources/` folder in the codebase (per `01-PATTERNS.md`'s inventory) is currently empty — first datasource actually implemented. Shell mirrors repository constructor-injection shape; body is new Storage-API usage, use 02-RESEARCH.md "Storage" section verbatim. |
| "Vincular cuenta" bottom sheet trigger | component | request-response | First `showModalBottomSheet` usage in the codebase — compose from existing `AppCard`/`AppButton`, no dedicated sheet-wrapper widget exists to copy from. |

## Metadata

**Analog search scope:** `lib/features/auth/**`, `lib/features/home/**`, `lib/core/{router,data,widgets,theme}/**`, `lib/features/clients/domain/**`, `lib/features/patients/domain/**`, `supabase/schema.sql`, `test/**`
**Files scanned:** 18 Dart files + 1 SQL file directly read this session, plus 2 upstream planning docs (02-RESEARCH.md, 02-UI-SPEC.md) and Phase 1's own pattern map (01-PATTERNS.md) as secondary corroboration
**Pattern extraction date:** 2026-09-24
