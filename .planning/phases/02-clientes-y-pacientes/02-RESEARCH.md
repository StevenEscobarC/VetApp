# Phase 2: Clientes y Pacientes - Research

**Researched:** 2026-09-24
**Domain:** Supabase (Postgres/RLS + Storage) CRUD for two related entities (`clientes`, `mascotas`) + Riverpod repository/provider pattern + camera-first photo upload, on top of a schema already applied and RLS-tested in Phase 1
**Confidence:** HIGH

## Summary

Phase 1 already applied and RLS-tested `public.clientes` and `public.mascotas` — this phase does **not** redesign multi-tenancy or auth. What it adds is: (1) two genuine schema gaps discovered by reconciling the existing Dart entities against the live `schema.sql` (a `foto_path` column and a brand-new `mascota_pesos` history table — neither exists today), (2) a private Supabase Storage bucket + `storage.objects` RLS policies for pet photos, (3) `SupabaseClienteRepository`/`SupabaseMascotaRepository` classes following the exact concrete-class-no-interface shape Phase 1 actually shipped for auth (not the idealized interface pattern in `ARCHITECTURE.md` that Phase 1 chose not to retrofit), (4) four new packages for camera capture/compression/caching/permissions — with one **critical version correction**: the project-level `STACK.md` recommendation of `cached_network_image ^4.0.2` is now incompatible with this project's pinned Dart SDK (`^3.11.1`) as of this package's very recent 4.0.0 release; the compatible version is `^3.4.1`, and (5) a hand-rolled `Timer`-based debounce for instant-as-you-type search against Postgres via `ilike`.

The existing `Mascota`/`Cliente` domain entities (scaffolded before Phase 1's schema decisions) reference fields that don't exist anywhere in `schema.sql` (`veterinarioId`, `sexo`, `color`, `esterilizado`, a mutable `pesoKg`) and are missing fields the schema actually has (`clinicaId`). Per the project's own `PITFALLS.md` Pitfall 6 ("entities designed against an imagined schema"), this phase's first task must be reconciling both entities to the real schema before writing any repository code — this research does that reconciliation explicitly below.

**Primary recommendation:** Fix the two schema gaps first (bucket + `foto_path` + `mascota_pesos`, all additive `ALTER`/`CREATE`, safe against the now-populated `clientes`/`mascotas` tables), reconcile `Cliente`/`Mascota` entities to match, then build `clientes` end-to-end (list → search → detail → edit) before `mascotas`, since the combined create flow (D-02) needs a working `ClienteRepository` first.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Cliente/Mascota CRUD | Database / Storage (Postgres RLS) | App/Client (Riverpod repository + `AsyncNotifier`) | Same pattern as Phase 1 — RLS is the sole security boundary; the client only orchestrates, never re-implements tenant scoping |
| Combined cliente+mascota creation (D-02) | Database / Storage (single Postgres RPC, atomic) | App/Client (one repository method calling `.rpc()`) | Two related inserts that must not leave an orphaned `cliente` if the `mascota` insert fails — matches the project's own precedent (`crear_perfil_nuevo_usuario`) of using a Postgres function for a rigid, security-relevant, multi-row invariant rather than a client-side usecase |
| Pet photo storage | Database / Storage (private bucket + `storage.objects` RLS) | App/Client (upload/compress/signed-URL fetch in a dedicated datasource) | Mirrors the exact `clinica_id`-scoped RLS pattern already used for every table; photo bytes never pass through anything but Supabase Storage |
| Weight history | Database / Storage (`mascota_pesos` table) | App/Client (read-only list rendered as a timeline) | Must be derived/queried data, not a mutable field on `mascotas` — same "don't store a mutable derived value" lesson `PITFALLS.md` Pitfall 7 already flagged for vaccination |
| Instant search (clientes/mascotas) | Database / Storage (Postgres `ilike`, indexed) | App/Client (debounce timer before the query fires) | RLS-scoped `ilike` queries are cheap at this data volume (single clinic); debounce lives client-side purely to avoid a request per keystroke, not for correctness |
| Camera capture / compression / permission prompts | Browser/Client (device APIs via `image_picker`/`flutter_image_compress`/`permission_handler`) | — | Pure device-local concern, no server involvement until the compressed bytes are uploaded |

## Project Constraints (from CLAUDE.md)

- **Tech stack locked**: Flutter + Supabase — no alternative backend/state-management evaluation.
- **Backend real, no mocks**: every screen this phase ships must read/write the real cloud project; no seeded/mock data left behind once a screen "looks done."
- **Diseño**: terracota/crema palette, Caprasimo (headings) + Figtree (body) — already wired in `app_colors.dart`/`app_typography.dart` since Phase 1; new screens must reuse `AppCard`/`AppButton`/`AppTextField`/`AppTopBar`, never raw Material widgets.
- **Mercado objetivo**: Colombia — dates must render `dd/mm/aaaa` (use `intl`'s `DateFormat('dd/MM/yyyy', 'es_CO')`, already a pinned dependency); no currency formatting needed this phase (no money fields in `clientes`/`mascotas`).
- **GSD workflow enforcement**: implementation must happen through a GSD command — informational for the planner.
- **Established naming/error-handling conventions** (binding, per the generated stack profile and Phase 1's actual output): `snake_case.dart` files; Spanish domain nouns (`Cliente`, `Mascota`, `nombre`, `especie`) with English plumbing (`onPressed`, `isLoading`); two-tier error handling — a specific `on PostgrestException catch` branch translating to a Spanish message, plus a generic catch-all — mirroring `SupabaseAuthRepository`'s `_messageFor`/`AuthFailure` shape; repository classes named `Supabase<Domain>Repository`; Riverpod providers derive from `supabaseClientProvider`, never construct `Supabase.instance.client` inline.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CLI-01 | Crear cliente con nombre+teléfono, sin cuenta propia | `clientes` table already exists (Phase 1), no schema change; `SupabaseClienteRepository.create()` below |
| CLI-02 | Ver y editar datos de un cliente | `SupabaseClienteRepository.update()`/`.getById()`; detail/edit screen pattern below |
| CLI-03 | Buscar/filtrar clientes por nombre o teléfono | Debounced `ilike` search pattern below (own-table `.or()`, no join needed) |
| CLI-04 | Ver mascotas asociadas a un cliente | `SupabaseMascotaRepository.watchForCliente(clienteId)` — simple `eq('dueno_id', ...)` query, index already exists (`mascotas_dueno_id_idx`) |
| PAT-01 | Crear ficha de mascota (especie, raza, edad, peso, foto, dueño) | `especie`/`raza`/`fecha_nacimiento` (→ edad) already in schema; `foto_path` column gap + `mascota_pesos` table gap identified and fixed below |
| PAT-02 | Ver y editar ficha de mascota | `SupabaseMascotaRepository.update()`; entity reconciliation below |
| PAT-03 | Subir/cambiar foto (Storage privado + URL firmada) | Private bucket + `storage.objects` RLS + `createSignedUrl` pattern below |
| PAT-04 | Buscar/filtrar mascotas por nombre, dueño, especie | Two-step search (own-field `.or()` + resolved owner-id `.in.()`) below — avoids undocumented embedded-filter-`.or()` limitations |
| PAT-05 | Historial de peso en el tiempo | New `mascota_pesos` table (not a mutable field) — exact SQL below |

</phase_requirements>

## Standard Stack

### Core (already installed — no version change)

| Library | Version (pinned) | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter_riverpod` | `^3.3.2` (resolves `3.3.2`) | State/DI | Already wired app-wide since Phase 1; `AsyncNotifier` is the established pattern (`authProfileProvider`) |
| `go_router` | `^17.3.0` | Navigation | Already wired; new routes (`/pacientes/:id`, `/clientes/:id`, form routes) attach to the existing `StatefulShellRoute` branches |
| `supabase_flutter` | `^2.9.1` (locked `2.17.2`) | Backend client | Already the sole backend integration; Storage API (`.storage.from(bucket)`) stable across the 2.x line `[CITED: STACK.md Version Compatibility]` |
| `intl` | `^0.20.3` | `dd/mm/aaaa` date formatting | Already pinned; use for birthdate display/edit and weight-history timeline dates |

### New this phase

| Library | Version to pin | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `image_picker` | `^1.2.3` `[VERIFIED: pub.dev API, 2026-09-24 — latest stable, published 2026-06-30, sdk constraint ^3.10.0]` | Camera capture (default) / gallery picker (secondary) for pet photos | Flutter-team-adjacent, de-facto standard; supports `ImageSource.camera` directly (one-tap camera per D-05) and `maxWidth`/`imageQuality` params to downscale at pick time |
| `flutter_image_compress` | `^2.5.1` `[VERIFIED: pub.dev API, 2026-09-24 — latest stable, published 2026-07-25, sdk constraint >=2.12.0 <4.0.0]` | Client-side re-compression before upload | Some Android cameras return >5MB originals even with `imageQuality` set on `image_picker`; keeps mobile-data usage down for the "sin computador, todo desde el celular" use case |
| `cached_network_image` | **`^3.4.1`** — **NOT `^4.0.2`, see correction below** `[VERIFIED: pub.dev API, 2026-09-24 — 3.4.1 published with sdk constraint ^3.0.0, compatible; 4.0.0/4.0.1/4.0.2 all require sdk ^3.12.0]` | Disk+memory caching for pet-photo signed URLs | Standard caching layer for any list screen rendering photos repeatedly (patients list, ficha) |
| `permission_handler` | `^13.0.2` `[VERIFIED: pub.dev API, 2026-09-24 — latest stable, published 2026-09-04, sdk constraint ^3.6.0]` | Pre-flight camera/photo-library permission check + "permanently denied → open Settings" UX | `image_picker` triggers the native OS permission dialog on its own, but gives no way to pre-check state or recover from a permanently-denied permission without `permission_handler`'s `openAppSettings()` |

### ⚠️ Version correction vs. `.planning/research/STACK.md`

`STACK.md` (researched 2026-09-23, one day before this phase's research) recommended `cached_network_image ^4.0.2`. That exact patch version was published **2026-09-23** — the same day as `STACK.md`'s research — and its `pubspec.yaml` raises the minimum Dart SDK to `^3.12.0`. This project's `pubspec.yaml` still constrains `sdk: ^3.11.1` (unchanged since Phase 1, which explicitly decided not to bump `go_router` past 18.x for the same SDK-constraint reason). Installing `^4.0.2` today would fail dependency resolution exactly like the `go_router ^18.0.0` case Phase 1 already flagged. **Pin `cached_network_image: ^3.4.1`** instead (verified compatible, `sdk: ^3.0.0`) until a deliberate, separate Flutter/Dart SDK upgrade is planned. `[VERIFIED: pub.dev API version-list query, 2026-09-24]`

### Package Legitimacy Audit

`slopcheck` was installed successfully (`pip install slopcheck`, v0.6.1) but **does not support the pub.dev/Dart ecosystem** — its `install` subcommand only covers `pypi`, `npm`, `crates.io`, `go`, `rubygems`, `maven`, `packagist`. `[VERIFIED: slopcheck install --help output, 2026-09-24]` No automated hallucination check could run against pub.dev. Per the graceful-degradation rule, every package below is tagged `[ASSUMED]` for legitimacy (not existence — existence/version was independently confirmed live against the pub.dev API, see table above) and the planner should gate installation behind a `checkpoint:human-verify` task, even though all four are widely-known, long-established packages with no plausible hallucination risk (all four already appear, unmodified by name, in `.planning/research/STACK.md`'s project-level research from the prior day).

| Package | Registry | Publisher (known) | slopcheck | Disposition |
|---------|----------|---------------------|-----------|-------------|
| `image_picker` | pub.dev | flutter.dev (Flutter-team-adjacent, `flutter/packages` monorepo) | N/A — ecosystem unsupported | `[ASSUMED]` — checkpoint:human-verify before install |
| `flutter_image_compress` | pub.dev | OpenFlutter org | N/A — ecosystem unsupported | `[ASSUMED]` — checkpoint:human-verify before install |
| `cached_network_image` | pub.dev | Baseflow (long-standing Flutter plugin publisher) | N/A — ecosystem unsupported | `[ASSUMED]` — checkpoint:human-verify before install; **must be pinned `^3.4.1`, not `^4.0.2`** |
| `permission_handler` | pub.dev | Baseflow | N/A — ecosystem unsupported | `[ASSUMED]` — checkpoint:human-verify before install |

**Packages removed due to slopcheck `[SLOP]` verdict:** none (no check ran).
**Packages flagged as suspicious `[SUS]`:** none flagged, but all four carry the ecosystem-unsupported caveat above.

**Installation:**
```bash
flutter pub add image_picker flutter_image_compress permission_handler
flutter pub add cached_network_image:^3.4.1
```
(Split into two commands so `flutter pub add`'s own dependency resolver is forced to respect the `^3.4.1` pin rather than defaulting to whatever `^4.x` it would otherwise pick as "latest".)

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Concrete `SupabaseClienteRepository`/`SupabaseMascotaRepository`, no `domain/repositories/` interface | Abstract interface + impl (the ideal in `ARCHITECTURE.md`) | `ARCHITECTURE.md`'s Anti-Pattern 2 recommends interfaces, but Phase 1 **deleted** `auth`'s interface rather than retrofit it — `authRepositoryProvider` is typed to the concrete `SupabaseAuthRepository` class today. Introducing interfaces only for `clientes`/`mascotas` would make the codebase inconsistent (interfaces for 2 of 3 features). Recommend following the actual, already-shipped precedent for consistency; flag as Claude's Discretion if the planner prefers to retrofit all three at once. |
| Postgres RPC for combined cliente+mascota create | Two sequential client-side inserts (`ClienteRepository.create()` then `MascotaRepository.create()`) | Sequential inserts are simpler to write/test but risk an orphaned `cliente` row if the second insert throws (network blip, RLS denial) — acceptable risk for MVP if the team wants to defer the RPC; the RPC is one function, ~20 lines, and matches the existing `crear_perfil_nuevo_usuario` precedent for atomicity |
| `mascota_pesos` as its own table | A single mutable `peso_kg` column on `mascotas`, overwritten on each edit | Directly contradicts PAT-05 ("puede tener más de un peso registrado en el tiempo") and repeats the exact anti-pattern `PITFALLS.md` Pitfall 7 already flagged for vaccination dosing (mutable field instead of derived history) |
| Storage object path stored in `mascotas.foto_path`, signed URL generated on read | Storing the signed URL itself in the database | Signed URLs expire (this phase uses 1-hour expiry); storing an expiring value in a persistent column guarantees it goes stale — store the stable path, generate the URL fresh each read |

## Architecture Patterns

### System Architecture Diagram

```
┌───────────────────────────────────────────────────────────────────────────┐
│  ClientesListScreen / PacientesListScreen (ConsumerWidget)                 │
│    search TextField ──onChanged──▶ debounce Timer (350ms)                  │
└───────────────────────────────┬─────────────────────────────────────────────┘
                                 │ ref.read(...).search(query)
                                 ▼
┌───────────────────────────────────────────────────────────────────────────┐
│  ClientesNotifier / MascotasNotifier (AsyncNotifier<List<T>>)              │
│    build() → repository.search('') (initial, unfiltered)                   │
│    search(q) → cancel timer, schedule, then AsyncValue.guard(repo.search)  │
└───────────────────┬─────────────────────────────────┬─────────────────────┘
                     │                                 │
                     ▼                                 ▼
┌─────────────────────────────┐        ┌─────────────────────────────────────┐
│ SupabaseClienteRepository    │        │ SupabaseMascotaRepository            │
│  .search(q, clinicaId)       │        │  .search(q, clinicaId)               │
│  .create()/.update()         │        │  .registrarClienteYMascota() → RPC   │
│                               │        │  .pesos(mascotaId) / .registrarPeso()│
└───────────────┬───────────────┘        └──────────────┬──────────────────────┘
                │ .from('clientes')...                   │ .from('mascotas')... / .rpc(...)
                ▼                                         ▼
┌───────────────────────────────────────────────────────────────────────────┐
│  Supabase Postgres — RLS enforced as `authenticated`                       │
│  clientes / mascotas / mascota_pesos, all scoped by es_veterinario() +     │
│  mi_clinica_id() (Phase 1 helpers, reused as-is)                           │
└───────────────────────────────┬─────────────────────────────────────────────┘
                                 │ foto_path (object key, not a URL)
                                 ▼
┌───────────────────────────────────────────────────────────────────────────┐
│  MascotaFotoDatasource                                                     │
│    .upload(bytes, clinicaId, mascotaId) → object path                      │
│    .signedUrlFor(path) → createSignedUrl(path, 3600)                       │
└───────────────────┬─────────────────────────────────────────────────────────┘
                     ▼
┌───────────────────────────────────────────────────────────────────────────┐
│  Supabase Storage — private bucket `mascota-fotos`, RLS on storage.objects │
│  path convention: {clinica_id}/{mascota_id}/{timestamp}.jpg                │
└───────────────────────────────────────────────────────────────────────────┘
                     │ signed URL (query param changes every fetch)
                     ▼
┌───────────────────────────────────────────────────────────────────────────┐
│  CachedNetworkImage(imageUrl: signedUrl, cacheKey: fotoPath)  ← MUST pin   │
│  cacheKey to the stable object path, not the URL — see Pitfall below      │
└───────────────────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure (Phase 2 deltas)

```
lib/features/
├── clients/
│   ├── data/
│   │   └── repositories/
│   │       └── supabase_cliente_repository.dart      # NEW
│   ├── domain/
│   │   └── entities/
│   │       └── cliente.dart                          # EDIT — reconcile to schema (below)
│   └── presentation/
│       ├── providers/
│       │   └── clientes_providers.dart                # NEW — clienteRepositoryProvider, ClientesNotifier
│       └── screens/
│           ├── clientes_list_screen.dart               # NEW — replaces ComingSoonScreen at /clientes
│           ├── cliente_detail_screen.dart               # NEW — view/edit + mascotas list (CLI-04)
│           └── nuevo_cliente_mascota_screen.dart        # NEW — combined create flow (D-02/D-03)
└── patients/
    ├── data/
    │   ├── datasources/
    │   │   └── mascota_foto_datasource.dart            # NEW — Storage-only, separate from Postgres datasource
    │   └── repositories/
    │       └── supabase_mascota_repository.dart         # NEW
    ├── domain/
    │   └── entities/
    │       ├── mascota.dart                             # EDIT — reconcile to schema (below)
    │       └── peso_registro.dart                        # NEW — weight-history entity
    └── presentation/
        ├── providers/
        │   └── mascotas_providers.dart                   # NEW
        └── screens/
            ├── pacientes_list_screen.dart                 # NEW — replaces ComingSoonScreen at /pacientes
            ├── mascota_detail_screen.dart                  # NEW — ficha + weight timeline + photo
            └── mascota_form_screen.dart                    # NEW — create/edit fields (reused by combined flow)
```

### Pattern 1: Concrete repository, no `domain/repositories/` interface (matches Phase 1's actual shape)

**What:** `SupabaseClienteRepository`/`SupabaseMascotaRepository` are plain classes taking a `SupabaseClient` in their constructor, with the two-tier error handling copied from `SupabaseAuthRepository`. No abstract interface file, no `Provider<ClienteRepository>` — the provider is typed to the concrete class, exactly like `authRepositoryProvider: Provider<SupabaseAuthRepository>` today.
**When to use:** Every CRUD method in this phase.
**Example:**
```dart
// lib/features/clients/domain/entities/cliente.dart — RECONCILED to schema.sql
class Cliente {
  const Cliente({
    required this.id,
    required this.clinicaId,          // was `veterinarioId` — schema column is clinica_id
    required this.nombre,
    required this.telefono,
    this.email,
    this.direccion,
    this.notas,
  });
  // mascotaIds removed — not a stored column; mascotas-for-cliente is its own query
  // (SupabaseMascotaRepository.watchForCliente), never denormalized onto Cliente.

  final String id;
  final String clinicaId;
  final String nombre;
  final String telefono;
  final String? email;
  final String? direccion;
  final String? notas;

  Cliente copyWith({String? nombre, String? telefono, String? email, String? direccion, String? notas}) =>
      Cliente(id: id, clinicaId: clinicaId, nombre: nombre ?? this.nombre,
          telefono: telefono ?? this.telefono, email: email ?? this.email,
          direccion: direccion ?? this.direccion, notas: notas ?? this.notas);
}

// lib/features/clients/data/repositories/supabase_cliente_repository.dart
class ClienteFailure implements Exception {
  const ClienteFailure(this.message);
  final String message;
}

class SupabaseClienteRepository {
  SupabaseClienteRepository(this._client);
  final SupabaseClient _client;

  Future<Cliente> create({required String clinicaId, required String nombre, required String telefono}) async {
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
  }

  Future<List<Cliente>> search(String query, {required String clinicaId}) async {
    try {
      var builder = _client.from('clientes').select().eq('clinica_id', clinicaId);
      final q = query.trim();
      if (q.isNotEmpty) {
        final pattern = '%$q%';
        builder = builder.or('nombre.ilike.$pattern,telefono.ilike.$pattern');
      }
      final rows = await builder.order('nombre');
      return (rows as List).map((r) => _fromRow(r as Map<String, dynamic>)).toList();
    } on PostgrestException catch (e) {
      throw ClienteFailure(_messageFor(e));
    } catch (_) {
      throw const ClienteFailure('No fue posible cargar los clientes.');
    }
  }

  Cliente _fromRow(Map<String, dynamic> row) => Cliente(
      id: row['id'] as String, clinicaId: row['clinica_id'] as String,
      nombre: row['nombre'] as String, telefono: row['telefono'] as String,
      email: row['email'] as String?, direccion: row['direccion'] as String?,
      notas: row['notas'] as String?);

  String _messageFor(PostgrestException e) {
    if (e.code == '23505') return 'Ya existe un cliente con estos datos.';
    return 'No fue posible completar la solicitud. Intenta de nuevo.';
  }
}
```
Source: two-tier error handling copied verbatim from `lib/features/auth/data/repositories/supabase_auth_repository.dart:40-53` (already the codebase's established pattern, confirmed by direct read this session). `[VERIFIED: direct codebase read]`

### Pattern 2: `AsyncNotifier` + hand-rolled debounce for instant search

**What:** One `AsyncNotifier<List<T>>` per feature list, exposing a `search(query)` method that debounces via a plain `Timer`, matching the "no codegen" decision already locked in `STACK.md`.
**When to use:** `ClientesNotifier`/`MascotasNotifier` — the CLI-03/PAT-04 instant-search requirement (D-06).
**Example:**
```dart
// lib/features/clients/presentation/providers/clientes_providers.dart
final clienteRepositoryProvider = Provider<SupabaseClienteRepository>((ref) {
  return SupabaseClienteRepository(ref.watch(supabaseClientProvider));
});

class ClientesNotifier extends AsyncNotifier<List<Cliente>> {
  Timer? _debounce;
  static const _debounceDuration = Duration(milliseconds: 350);

  @override
  Future<List<Cliente>> build() async {
    ref.onDispose(() => _debounce?.cancel());
    final clinicaId = ref.watch(authProfileProvider).value?.clinicaId;
    if (clinicaId == null) return [];
    return ref.watch(clienteRepositoryProvider).search('', clinicaId: clinicaId);
  }

  /// Called on every TextField.onChanged — debounces internally, so callers
  /// never need their own Timer.
  void search(String query) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () async {
      final clinicaId = ref.read(authProfileProvider).value?.clinicaId;
      if (clinicaId == null) return;
      state = const AsyncLoading<List<Cliente>>().copyWithPrevious(state);
      state = await AsyncValue.guard(
        () => ref.read(clienteRepositoryProvider).search(query, clinicaId: clinicaId),
      );
    });
  }
}

final clientesProvider = AsyncNotifierProvider<ClientesNotifier, List<Cliente>>(ClientesNotifier.new);
```
`_debounceDuration` of 350ms is the standard middle-ground for search-as-you-type (fast enough to feel instant per D-06, slow enough to avoid a request per keystroke). Per `PITFALLS.md` Pitfall 3 (already flagged in Phase 1's own research): never cache `ref.read(clientesProvider.notifier)` in a local variable across an `await` — always `ref.read(...)` inline, as shown.
`[CITED: Riverpod 3 AsyncNotifier/Timer debounce — standard hand-rolled pattern, cross-checked against Riverpod's own `AsyncValue.guard` docs already used in Phase 1's `auth_providers.dart`]`

### Pattern 3: Two-step search for a joined "search by dueño name" filter (PAT-04)

**What:** PostgREST's `.or()` reliably combines multiple filters on the **same** table (`nombre.ilike...,especie.ilike...`), but combining an own-table filter with a filter on an embedded/joined table inside one `.or()` is not consistently supported. `[CITED: PostgREST resource-embedding docs + supabase/postgrest-js discussion #197 — "filter source table based on embedded table" requires `!inner`, and mixing that with a same-level `.or()` across the parent table has documented limitations]` The safe, fully-documented alternative is two round trips: resolve matching `cliente` ids first, then fold them into the `mascotas` query's own `.or()` via `.in.(...)`.
**When to use:** `SupabaseMascotaRepository.search()` — the only place this phase needs a cross-table text search.
**Example:**
```dart
Future<List<Mascota>> search(String query, {required String clinicaId}) async {
  final q = query.trim();
  var builder = _client.from('mascotas').select().eq('clinica_id', clinicaId);
  if (q.isEmpty) return _rows(await builder.order('nombre'));

  final pattern = '%$q%';
  final ownerRows = await _client.from('clientes').select('id')
      .eq('clinica_id', clinicaId).ilike('nombre', pattern);
  final ownerIds = (ownerRows as List).map((r) => r['id'] as String).toList();

  final orParts = ['nombre.ilike.$pattern', 'especie.ilike.$pattern'];
  if (ownerIds.isNotEmpty) {
    orParts.add('dueno_id.in.(${ownerIds.join(',')})');
  }
  return _rows(await builder.or(orParts.join(',')).order('nombre'));
}
```
This relies only on documented, stable filter operators (`ilike`, `or`, `in`) — no embedded-resource edge cases. `[CITED: PostgREST 12.2 resource_embedding docs]`

### Pattern 4: Combined cliente+mascota creation via a single Postgres RPC (D-02)

**What:** One `security invoker` Postgres function performing both inserts (and the optional first `mascota_pesos` row) inside one implicit transaction, called once from Flutter via `.rpc(...)`. `security invoker` (the default) means the function still runs as the calling vet's `authenticated` role, so every RLS policy on `clientes`/`mascotas`/`mascota_pesos` still applies inside the function — this is defense-in-depth, not a bypass.
**When to use:** The "new client + new pet in one continuous flow" path (D-02). The "existing client + new pet" path (D-03) does **not** use this — it calls `SupabaseMascotaRepository.create()` directly with the already-known `dueno_id`.
**Example (SQL — new migration on top of the applied `schema.sql`):**
```sql
create or replace function public.registrar_cliente_con_mascota(
  cliente_nombre text,
  cliente_telefono text,
  mascota_nombre text,
  mascota_especie text,
  mascota_raza text default '',
  mascota_fecha_nacimiento date default null,
  mascota_peso_kg numeric default null
)
returns table (cliente_id uuid, mascota_id uuid)
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_clinica_id uuid := public.mi_clinica_id();
  v_cliente_id uuid;
  v_mascota_id uuid;
begin
  if not public.es_veterinario() or v_clinica_id is null then
    raise exception 'Solo un veterinario con clínica asignada puede registrar clientes.';
  end if;

  insert into public.clientes (clinica_id, nombre, telefono)
  values (v_clinica_id, trim(cliente_nombre), trim(cliente_telefono))
  returning id into v_cliente_id;

  insert into public.mascotas (dueno_id, clinica_id, nombre, especie, raza, fecha_nacimiento)
  values (v_cliente_id, v_clinica_id, trim(mascota_nombre), mascota_especie,
          coalesce(mascota_raza, ''), mascota_fecha_nacimiento)
  returning id into v_mascota_id;

  if mascota_peso_kg is not null then
    insert into public.mascota_pesos (mascota_id, peso_kg) values (v_mascota_id, mascota_peso_kg);
  end if;

  return query select v_cliente_id, v_mascota_id;
end;
$$;

grant execute on function public.registrar_cliente_con_mascota(
  text, text, text, text, text, date, numeric
) to authenticated;
```
**Dart call site:**
```dart
Future<({String clienteId, String mascotaId})> registrarClienteConMascota({
  required String clienteNombre, required String clienteTelefono,
  required String mascotaNombre, required String mascotaEspecie,
  String mascotaRaza = '', DateTime? mascotaFechaNacimiento, double? mascotaPesoKg,
}) async {
  try {
    final rows = await _client.rpc('registrar_cliente_con_mascota', params: {
      'cliente_nombre': clienteNombre, 'cliente_telefono': clienteTelefono,
      'mascota_nombre': mascotaNombre, 'mascota_especie': mascotaEspecie,
      'mascota_raza': mascotaRaza,
      'mascota_fecha_nacimiento': mascotaFechaNacimiento?.toIso8601String().split('T').first,
      'mascota_peso_kg': mascotaPesoKg,
    });
    final row = (rows as List).first as Map<String, dynamic>;
    return (clienteId: row['cliente_id'] as String, mascotaId: row['mascota_id'] as String);
  } on PostgrestException catch (e) {
    throw MascotaFailure(_messageFor(e));
  }
}
```
`[CITED: supabase_flutter .rpc() API — stable across the 2.x line per STACK.md Version Compatibility; PostgREST function-call semantics official docs]`

### Anti-Patterns to Avoid

- **Storing the signed URL in `mascotas.foto_path` instead of the stable object path:** the URL expires; the path never does. Always store the path, generate the URL on read.
- **Passing the signed URL as `CachedNetworkImage`'s `cacheKey`:** defeats caching entirely, since the URL's token/expiry query params change on every fetch — see Common Pitfalls below.
- **Adding a `domain/repositories/` interface only for `clientes`/`mascotas`:** creates an inconsistent codebase (interfaces for 2 features, none for `auth`) — follow the concrete-class precedent Phase 1 actually shipped, or retrofit all three together as a deliberate, separate decision.
- **Filtering `mascotas` by dueño name using a single `.or()` mixing an embedded-resource filter with own-table filters:** not reliably supported by PostgREST — use the two-step resolve-then-`.in.()` pattern instead.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|--------------|-----|
| Camera capture + gallery fallback | A custom `MethodChannel` wrapping native camera/gallery intents | `image_picker` (`ImageSource.camera`/`.gallery`) | Already the ecosystem standard; handles per-platform permission dialogs and file access scoping |
| Image downscaling before upload | Manual `dart:ui`/`Image` pixel manipulation | `flutter_image_compress` | Handles JPEG re-encoding efficiently via native codecs; hand-rolled Dart-side resizing is slower and more failure-prone |
| Signed-URL image caching | A custom `Map<String, Uint8List>` in-memory cache, or raw `Image.network` | `cached_network_image` with an explicit `cacheKey` | Disk+memory caching, retry/error-widget support, and the `cacheKey` override (needed here specifically because of the signed-URL-expiry pitfall) are all solved problems |
| Instant-as-you-type search debounce | A `StreamController` + `debounceTime`-style rx operator (would require adding `rxdart`) | A plain `Timer` cancelled/rescheduled on every keystroke inside the `AsyncNotifier` | One new dependency (`rxdart`) is unjustified for a single debounce use — `Timer` alone is the documented Riverpod-community pattern for this exact need |
| Atomic multi-table create | A client-side "try cliente insert, catch, rollback manually" loop | The `registrar_cliente_con_mascota` Postgres function | Postgres transactions are the correct primitive for atomicity; client-side compensating-transaction logic is strictly worse and error-prone |

**Key insight:** every new capability this phase needs (camera, compression, caching, debounce, atomic multi-insert) already has a standard, narrow tool in the Flutter/Postgres ecosystem — the risk is under-using them (e.g. skipping `cacheKey`, skipping the RPC), not needing to build something custom.

## Schema Gaps Found (must fix before repository work — per `PITFALLS.md` Pitfall 6)

Reconciling `lib/features/patients/domain/entities/mascota.dart` and `lib/features/clients/domain/entities/cliente.dart` against the live `supabase/schema.sql` (applied in Phase 1) surfaces concrete mismatches:

| Entity field | Exists in schema? | Action |
|---|---|---|
| `Mascota.veterinarioId` | No — `mascotas` has `clinica_id`, not a per-vet column | Remove from entity; use `clinicaId` |
| `Mascota.sexo`, `Mascota.color`, `Mascota.esterilizado` | No — not in `mascotas`, not in any requirement (PAT-01 lists only especie/raza/edad/peso/foto/dueño) or the approved mockup (`DESIGN-REFERENCE.md` ficha section lists only raza/edad/peso) | Remove from entity — out of scope for v1, avoid scope creep |
| `Mascota.pesoKg` (single mutable field) | No — and per PAT-05 must not become one | Remove; replace with a separate `PesoRegistro` entity + `mascota_pesos` query |
| `Mascota.fotoUrl` | No — `mascotas` has no photo column at all | **Schema gap** — add `foto_path` (object path, not URL) |
| `Cliente.veterinarioId` | No — `clientes` has `clinica_id` | Remove from entity; use `clinicaId` |
| `Cliente.mascotaIds` | No — not a stored column, would drift out of sync | Remove; mascotas-for-cliente is always a live query (`SupabaseMascotaRepository.watchForCliente`) |
| Weight history (PAT-05) | No table exists | **Schema gap** — add `mascota_pesos` |

### Exact SQL for the two schema gaps

```sql
-- Gap 1: photo path on mascotas (object key in the private bucket, not a signed URL)
alter table public.mascotas add column if not exists foto_path text;

-- Gap 2: weight history — PAT-05 requires multiple weights over time, never a single mutable field
create table if not exists public.mascota_pesos (
  id uuid primary key default gen_random_uuid(),
  mascota_id uuid not null references public.mascotas(id) on delete cascade,
  peso_kg numeric(6,2) not null check (peso_kg > 0),
  registrado_en timestamptz not null default now(),
  created_at timestamptz not null default now()
);

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

drop policy if exists mascota_pesos_insert on public.mascota_pesos;
create policy mascota_pesos_insert on public.mascota_pesos for insert to authenticated
with check (
  public.es_veterinario()
  and exists (
    select 1 from public.mascotas m
    where m.id = mascota_pesos.mascota_id and m.clinica_id = public.mi_clinica_id()
  )
);

-- No update/delete policy: weight history is append-only by design (each visit adds
-- a new row; corrections happen via a new entry, matching the same append-only
-- philosophy PITFALLS.md Pitfall 8 recommends for clinical history in Phase 3 —
-- adopting it here too keeps the weight timeline trustworthy).
```

Both statements are additive (`add column if not exists`, `create table if not exists`) and safe to run against the now-live cloud project even though `clientes`/`mascotas` may already contain real rows from Phase 1 testing — no data migration/backfill needed since both are new, nullable/append-only additions.

## Supabase Storage: private bucket + RLS + signed URL (PAT-03)

### Exact bucket + RLS setup

```sql
-- Create the private bucket (idempotent)
insert into storage.buckets (id, name, public)
values ('mascota-fotos', 'mascota-fotos', false)
on conflict (id) do nothing;

-- Path convention: {clinica_id}/{mascota_id}/{timestamp}.jpg
-- storage.foldername(name) splits the object path on '/' — element [1] is clinica_id.

drop policy if exists mascota_fotos_select on storage.objects;
create policy mascota_fotos_select on storage.objects for select to authenticated
using (
  bucket_id = 'mascota-fotos'
  and public.es_veterinario()
  and (storage.foldername(name))[1] = public.mi_clinica_id()::text
);

drop policy if exists mascota_fotos_insert on storage.objects;
create policy mascota_fotos_insert on storage.objects for insert to authenticated
with check (
  bucket_id = 'mascota-fotos'
  and public.es_veterinario()
  and (storage.foldername(name))[1] = public.mi_clinica_id()::text
);

drop policy if exists mascota_fotos_update on storage.objects;
create policy mascota_fotos_update on storage.objects for update to authenticated
using (
  bucket_id = 'mascota-fotos'
  and public.es_veterinario()
  and (storage.foldername(name))[1] = public.mi_clinica_id()::text
)
with check (
  bucket_id = 'mascota-fotos'
  and public.es_veterinario()
  and (storage.foldername(name))[1] = public.mi_clinica_id()::text
);

drop policy if exists mascota_fotos_delete on storage.objects;
create policy mascota_fotos_delete on storage.objects for delete to authenticated
using (
  bucket_id = 'mascota-fotos'
  and public.es_veterinario()
  and (storage.foldername(name))[1] = public.mi_clinica_id()::text
);
```
`[CITED: Supabase Storage access-control docs — `storage.foldername()` folder-prefix RLS pattern, official example replaces `auth.jwt()->>'sub'` with any custom SQL condition; here substituted with the already-audited `public.mi_clinica_id()`/`public.es_veterinario()` helper functions from Phase 1's schema, consistent with the "call the helper, never re-derive tenant scoping inline" convention `01-PATTERNS.md` already establishes]`

### Upload + compress + signed-URL fetch (Dart)

```dart
// lib/features/patients/data/datasources/mascota_foto_datasource.dart
class MascotaFotoDatasource {
  MascotaFotoDatasource(this._client);
  final SupabaseClient _client;
  static const _bucket = 'mascota-fotos';

  Future<String> upload({
    required String clinicaId,
    required String mascotaId,
    required Uint8List bytes,
  }) async {
    final path = '$clinicaId/$mascotaId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from(_bucket).uploadBinary(
      path, bytes,
      fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
    );
    return path; // stored in mascotas.foto_path — NEVER store the signed URL
  }

  Future<String> signedUrlFor(String path) {
    return _client.storage.from(_bucket).createSignedUrl(path, 3600); // 1h — see rationale below
  }
}
```
`[CITED: `.uploadBinary()`/`.createSignedUrl()` — supabase_flutter Storage API, cross-verified against multiple official-docs-derived examples and the pattern already cited in project-level `STACK.md`]`

1-hour signed-URL expiry is deliberately short: because `CachedNetworkImage`'s `cacheKey` (below) is pinned to the stable `foto_path`, a fresh signed URL every time the ficha screen re-fetches costs nothing extra in bandwidth (cache hit on the image bytes regardless of URL churn) while keeping the exposed URL's live window small.

### Camera-first capture flow (D-05) with `permission_handler` pre-flight

```dart
Future<XFile?> capturePetPhoto(BuildContext context) async {
  var status = await Permission.camera.status;
  if (status.isDenied) status = await Permission.camera.request();
  if (status.isPermanentlyDenied) {
    // Show a dialog explaining why, with a button calling openAppSettings()
    return null;
  }
  final picker = ImagePicker();
  return picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 1600);
  // Gallery as secondary option: ImageSource.gallery, offered via a separate
  // "Elegir de galería" text button per D-05, not the primary tap target.
}

Future<Uint8List> compressForUpload(String path) async {
  final compressed = await FlutterImageCompress.compressWithFile(
    path, minWidth: 1024, minHeight: 1024, quality: 80, format: CompressFormat.jpeg,
  );
  return compressed!; // Uint8List — pass directly to uploadBinary, no temp file needed
}
```
`compressWithFile` returns `Uint8List?` directly (no intermediate file), simplifying the upload call above. `[CITED: flutter_image_compress package API — `compressWithFile` returns bytes, `compressAndGetFile` returns a file; either works, bytes avoids a temp-file cleanup step]`

### Required manifest/plist entries (concrete task for the planner)

- `android/app/src/main/AndroidManifest.xml`: add `<uses-permission android:name="android.permission.CAMERA" />` (image_picker's own manifest merge covers gallery access on modern Android, but explicit camera permission must be declared by the app for `permission_handler`'s `Permission.camera` to have anything to check).
- `ios/Runner/Info.plist`: add `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` string entries (Spanish copy, e.g. "VetApp necesita la cámara para tomar fotos de las mascotas.") — iOS refuses to show the permission dialog at all without these, silently killing the picker call.

## Common Pitfalls

### Pitfall 1: `cached_network_image`'s disk cache is keyed by URL — a signed URL defeats it silently

**What goes wrong:** `createSignedUrl()` appends a token/expiry query string that changes on every call. If `CachedNetworkImage(imageUrl: signedUrl)` is used without an explicit `cacheKey`, every screen visit (or every provider refresh) generates a "new" URL, and the cache never hits — every photo re-downloads every time, exactly defeating the point of adding `cached_network_image` at all. This is a documented, cross-referenced issue (not speculative). `[CITED: Baseflow/flutter_cached_network_image GitHub issues #428/#1005, cached_network_image official `CachedNetworkImage` API docs — `cacheKey` parameter exists precisely for this]`
**How to avoid:** Always pass `cacheKey: fotoPath` (the stable Storage object path) alongside `imageUrl: signedUrl`.
**Warning signs:** Network tab shows a photo re-downloading on every screen visit despite no change to the underlying file; `cached_network_image` added to `pubspec.yaml` but `cacheKey` never referenced in a grep of the codebase.
**Phase to address:** This phase, in the first screen that renders a pet photo (`mascota_detail_screen.dart` and any list-with-thumbnail screen) — establish the `cacheKey` convention there so every later feature that shows a photo (Phase 8 dashboard, Phase 5 vaccination card) copies it.

### Pitfall 2: Storing a peso value directly on `mascotas` "for convenience," then also building `mascota_pesos`

**What goes wrong:** It's tempting to add both a denormalized `mascotas.peso_actual_kg` (for fast list-screen display) and the `mascota_pesos` history table, syncing the former from the latter via a trigger. This reintroduces exactly the "mutable field that can drift out of sync with history" trap `PITFALLS.md` Pitfall 7 already flagged for vaccination — if the trigger is missed on one insert path (e.g. the combined-create RPC vs. a later "add weight" screen), the denormalized value silently lies.
**How to avoid:** No denormalized weight column. "Current weight" is always `SELECT peso_kg FROM mascota_pesos WHERE mascota_id = ? ORDER BY registrado_en DESC LIMIT 1` — a query, not a stored fact. At this data volume (one clinic, hundreds of pets) this is not a performance concern (`ARCHITECTURE.md`'s own Scaling Considerations table confirms no caching/pagination layer is needed yet).
**Warning signs:** A migration adds a `peso_kg`/`peso_actual_kg` column directly to `mascotas` alongside `mascota_pesos`.
**Phase to address:** This phase, at schema-design time (already resolved above by not including such a column).

### Pitfall 3: Combined create flow (D-02) silently orphans a `cliente` row on partial failure

**What goes wrong:** If the team defers the RPC (Pattern 4) in favor of two sequential client-side inserts "for simplicity," a network drop or RLS denial between the `cliente` insert and the `mascota` insert leaves a real `cliente` row with no pet — invisible in the UI (since the flow never completed) but polluting future searches/duplicate-detection.
**How to avoid:** Use the `registrar_cliente_con_mascota` RPC (Pattern 4) so both inserts commit or roll back together.
**Warning signs:** A support/QA report of "I see a client named X but they have no pets and I don't remember creating them."
**Phase to address:** This phase, when building the combined-create screen.

### Pitfall 4: `.or()` filter string built from unsanitized user input breaks on a literal comma or parenthesis

**What goes wrong:** PostgREST's `.or('nombre.ilike.%${query}%,...')` syntax uses commas and parentheses as structural delimiters. If a vet searches for a name containing a comma (rare but possible in a `notas`-adjacent free-text search, or a phone number formatted with parentheses) the filter string can be misparsed, causing a confusing empty result or a 400 error instead of a normal search.
**How to avoid:** For this phase's fields (`nombre`, `telefono`, `especie`), commas/parens in a search query are edge-case input, not the common case — but at minimum, strip commas/parens from the raw query before interpolating into the `.or()` string (`query.replaceAll(RegExp('[,()]'), '')`), and treat the interpolation as pattern content only (no other PostgREST-reserved characters `.`/`*`/`%` need escaping for `ilike` beyond `%` itself, which is intentionally part of the wildcard pattern here).
**Warning signs:** A search for a name with a comma or parenthesis in it returns zero results instead of the expected match, with no visible error to the user.
**Phase to address:** This phase, in both `SupabaseClienteRepository.search()` and `SupabaseMascotaRepository.search()`.

## Code Examples

### `PesoRegistro` entity + repository methods (PAT-05)

```dart
// lib/features/patients/domain/entities/peso_registro.dart
class PesoRegistro {
  const PesoRegistro({required this.id, required this.mascotaId, required this.pesoKg, required this.registradoEn});
  final String id;
  final String mascotaId;
  final double pesoKg;
  final DateTime registradoEn;
}
```
```dart
// SupabaseMascotaRepository additions
Future<List<PesoRegistro>> pesos(String mascotaId) async {
  final rows = await _client.from('mascota_pesos').select()
      .eq('mascota_id', mascotaId).order('registrado_en', ascending: false);
  return (rows as List).map((r) => PesoRegistro(
      id: r['id'] as String, mascotaId: r['mascota_id'] as String,
      pesoKg: (r['peso_kg'] as num).toDouble(),
      registradoEn: DateTime.parse(r['registrado_en'] as String))).toList();
}

Future<void> registrarPeso(String mascotaId, double pesoKg) async {
  await _client.from('mascota_pesos').insert({'mascota_id': mascotaId, 'peso_kg': pesoKg});
}
```

### Test-fake pattern for the new repositories (matches `test/helpers/fake_auth.dart`)

```dart
// test/helpers/fake_clientes.dart — mirrors FakeAuthProfileNotifier exactly
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
// Usage: ProviderScope(overrides: [clientesProvider.overrideWith(() => FakeClientesNotifier(clientes: [...]))], ...)
```

## Combined Creation Screen UI (D-02) — Concrete Structure

CONTEXT.md leaves the exact layout to Claude's Discretion, constrained by D-02 (continuous, no navigation) and the approved mockup's card/input/button visual language (`DESIGN-REFERENCE.md`). Recommended structure, given the design tokens already wired since Phase 1:

```
Scaffold(
  appBar: AppTopBar(title: 'Nuevo cliente'),
  body: SingleChildScrollView(          // one continuous scroll, NOT a PageView/stepper —
                                          // D-02 explicitly rules out "guardar y volver a entrar"
    child: Column(children: [
      AppCard(child: Column(children: [  // Section 1: Cliente
        Text('Datos del dueño', style: titleSmall),   // Caprasimo per DESIGN-REFERENCE headings rule
        AppTextField(label: 'Nombre *', controller: nombreClienteCtrl),
        AppTextField(label: 'Teléfono *', controller: telefonoCtrl, keyboardType: TextInputType.phone),
      ])),
      AppCard(child: Column(children: [  // Section 2: Mascota
        Text('Datos de la mascota', style: titleSmall),
        AppTextField(label: 'Nombre *', controller: nombreMascotaCtrl),
        // Especie: chips (Perro/Gato/Otro) matching the Pacientes-list filter chips
        // already documented in DESIGN-REFERENCE.md ("chips de filtro Todos/Perros/Gatos/Otros")
        // — reuse the same chip visual for the create-form's especie *selector*.
        _EspecieChips(...),
        // Raza / fecha de nacimiento / peso: all optional per D-04 — render as
        // collapsed "Agregar más detalles" expandable section, not inline required fields,
        // so the zero-friction minimum path (nombre + especie) stays visually short.
        _CamaraButton(...),  // one-tap camera per D-05; secondary "Elegir de galería" text button
      ])),
      AppButton(label: 'Guardar', onPressed: canSubmit ? _submit : null),
    ]),
  ),
)
```
For the D-03 "existing client, add pet" path: the same `mascota_form_screen.dart` fields render standalone (no Cliente section), reached from `cliente_detail_screen.dart`'s "Nueva mascota" button, pre-filled with the already-known `clienteId` — this reuses the exact same especie-chips/camera-button widgets, avoiding UI duplication between the two entry points.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `image_picker`, `flutter_image_compress`, `cached_network_image`, `permission_handler` are legitimate, non-hallucinated packages | Package Legitimacy Audit | Low — all four already appear by name in `.planning/research/STACK.md` (independent prior-day research) and were independently confirmed to exist with real version/publish-date metadata on the live pub.dev API this session; risk is essentially theoretical, but slopcheck could not mechanically confirm it since it doesn't cover pub.dev |
| A2 | `permission_handler` requires no additional Gradle/manifest wiring beyond the two manifest/plist entries listed | Storage/Camera section | Low-Medium — permission_handler's Android implementation sometimes needs a `compileSdkVersion`/`minSdkVersion` bump depending on which permission groups are requested; camera/photos are among the simplest and least likely to need this, but verify with a real device build before considering PAT-03 done |
| A3 | 1-hour signed-URL expiry is an adequate balance of security vs. UX for this app's usage pattern | Storage section | Low — if a vet leaves a ficha screen open for >1h without refreshing, the image could fail to load on a stale cached widget state (rare in practice since Flutter widgets re-fetch on rebuild); easy to lengthen later, not a locked decision |

## Open Questions

1. **Should `mascota_pesos.registrado_en` be a `date` (no time) or `timestamptz` (with time)?**
   - What we know: the mockup's ficha screen shows "datos básicos (raza, edad, peso)" with no visible timestamp granularity; PAT-05 only requires "más de un peso registrado en el tiempo."
   - What's unclear: whether the vet ever records weight twice in one day (e.g. before/after a procedure) — if so, `date` alone would collide.
   - Recommendation: use `timestamptz` (as specified above) — strictly more information than `date`, costs nothing, and the UI can always format it as `dd/MM/yyyy` for display while preserving same-day-multiple-entries capability if it ever comes up.

2. **Does the combined-create RPC need a `security invoker` explicit keyword, or is invoker the implicit default?**
   - What we know: Postgres functions default to `security invoker` unless `security definer` is specified — the existing `mi_perfil()`/`es_veterinario()`/`mi_clinica_id()` helpers explicitly use `security definer` (needed because they read `perfiles` a `CLIENTE` might not otherwise be allowed to read directly in every context) but `crear_perfil_nuevo_usuario` also uses `security definer` (needed because it writes rows the calling session has no direct insert grant for, at signup time before a session even exists).
   - What's unclear: nothing architecturally — `registrar_cliente_con_mascota` should stay `security invoker` since the calling vet already has full RLS-granted insert rights on both `clientes` and `mascotas`; explicitly writing `security invoker` in the function definition (as done above) is defensive documentation, not a functional requirement.
   - Recommendation: keep `security invoker` explicit as written — no open risk, just noting the reasoning for the planner/reviewer.

## Environment Availability

No external services beyond the already-provisioned Supabase cloud project (Phase 1) are required this phase. Camera/gallery/Storage all run through packages installed via `flutter pub add` (network-available, no local binary dependency to probe) and the Supabase Storage API (same project, same credentials as Phase 1 — already configured via `--dart-define`).

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Supabase cloud project | All CRUD + Storage | ✓ (provisioned Phase 1) | — | — |
| Physical device or emulator with camera | Manual verification of D-05 camera-first flow | Not probed this session (research-time, not build-time) | — | Emulators can simulate a camera feed for `image_picker` testing; real-device testing still recommended before considering PAT-03 done, per A2 above |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (already in use, `test/widget_test.dart`, `test/inicio_screen_test.dart`, `test/app_theme_test.dart`) |
| Config file | none — same convention as Phase 1 |
| Quick run command | `flutter test test/clientes_providers_test.dart test/mascotas_providers_test.dart` (new files, Wave 0) |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CLI-01 | Create cliente with valid data succeeds; empty nombre/telefono blocked client-side | unit/widget (fake repository override) | `flutter test test/clientes_providers_test.dart` | ❌ Wave 0 |
| CLI-03 | Debounced search calls repository once after the debounce window, not once per keystroke | unit (fake timer or `fakeAsync`) | `flutter test test/clientes_providers_test.dart` | ❌ Wave 0 |
| PAT-01/PAT-02 | Mascota create/edit round-trips through the reconciled entity fields | unit (fake repository) | `flutter test test/mascotas_providers_test.dart` | ❌ Wave 0 |
| PAT-03 | Photo upload returns a stable path; `CachedNetworkImage` receives `cacheKey` equal to that path | widget (assert widget tree props, no live Storage call) | `flutter test test/mascota_detail_screen_test.dart` | ❌ Wave 0 |
| PAT-04 | Search-by-dueño-name resolves owner ids before querying mascotas | unit (fake repository verifying the two-step call sequence) | `flutter test test/mascotas_providers_test.dart` | ❌ Wave 0 |
| PAT-05 | Weight history renders multiple entries in reverse-chronological order | widget (fake repository seeded with 2+ `PesoRegistro`) | `flutter test test/mascota_detail_screen_test.dart` | ❌ Wave 0 |
| CLI-04 | Cliente detail screen lists only that cliente's mascotas | widget (fake repository) | `flutter test test/cliente_detail_screen_test.dart` | ❌ Wave 0 |

RLS-level correctness (e.g., "vet cannot read another clinic's `clientes`/`mascota_pesos`/Storage objects") is **manual-only**, per the same D-03-locked convention Phase 1 established (no automated pgTAP suite this milestone) — extend the existing Phase 1 SQL Editor smoke-test script with `clientes`/`mascotas`/`mascota_pesos`/`storage.objects` positive+negative cases for the two throwaway clinics already created.

### Sampling Rate
- **Per task commit:** `flutter analyze && flutter test test/clientes_providers_test.dart test/mascotas_providers_test.dart`
- **Per wave merge:** `flutter test` (full suite)
- **Phase gate:** Full suite green + extended RLS manual smoke test (clientes/mascotas/mascota_pesos/storage.objects, both allow and deny cases) recorded before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/helpers/fake_clientes.dart` / `test/helpers/fake_mascotas.dart` — new fakes mirroring `fake_auth.dart`'s shape
- [ ] `test/clientes_providers_test.dart`, `test/mascotas_providers_test.dart` — new, cover CLI-01/03, PAT-01/02/04
- [ ] `test/cliente_detail_screen_test.dart`, `test/mascota_detail_screen_test.dart` — new widget tests, cover CLI-04, PAT-03/05
- [ ] No framework install needed — `flutter_test` already present

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | No change | Unchanged from Phase 1 — `clientes` explicitly have no auth credential by design (CLI-01) |
| V3 Session Management | No change | Unchanged |
| V4 Access Control | Yes — extended, not newly established | New `mascota_pesos` table and `storage.objects` policies both reuse the existing `es_veterinario()`/`mi_clinica_id()` functions — no new access-control primitive introduced, only new tables/buckets scoped by the existing one |
| V5 Input Validation | Yes | `check (peso_kg > 0)` constraint on `mascota_pesos` (server-side backstop); client-side required-field validation on nombre/especie per D-04; `.or()` filter-string sanitization per Pitfall 4 above |
| V6 Cryptography | No | Supabase Storage/Postgres encryption-at-rest defaults, unchanged |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|----------------------|
| Cross-tenant Storage object read (Vet A reads Vet B's pet photo via a guessed/leaked path) | Information Disclosure | `storage.objects` RLS scoped by `(storage.foldername(name))[1] = mi_clinica_id()`, verified via manual smoke test before considering PAT-03 done |
| RPC function inadvertently bypassing RLS via `security definer` | Elevation of Privilege | `registrar_cliente_con_mascota` explicitly uses `security invoker` (default) — the calling vet's own RLS grants are what allow the inserts, not an elevated function context |
| Denial-of-search via unescaped `.or()` filter string (Pitfall 4) | Tampering (query malformation, not data exposure) | Strip PostgREST-reserved characters from raw search input before interpolation |

## Sources

### Primary (HIGH confidence)
- Direct reads: `supabase/schema.sql`, `lib/features/patients/domain/entities/mascota.dart`, `lib/features/clients/domain/entities/cliente.dart`, `lib/core/router/app_router.dart`, `lib/core/data/supabase_client_provider.dart`, `lib/features/auth/presentation/providers/auth_providers.dart`, `lib/features/auth/data/repositories/supabase_auth_repository.dart`, `lib/core/widgets/cards/app_card.dart`, `lib/core/widgets/inputs/app_text_field.dart`, `lib/core/widgets/buttons/app_button.dart`, `test/helpers/fake_auth.dart`, `test/inicio_screen_test.dart`, `pubspec.yaml`, `pubspec.lock`, `.planning/config.json` — this session, 2026-09-24
- `pub.dev API` (`https://pub.dev/api/packages/<name>`) — live version/publish-date/SDK-constraint lookup for `image_picker`, `flutter_image_compress`, `cached_network_image` (including its full version history, which surfaced the SDK-constraint break at 4.0.0), `permission_handler` — queried 2026-09-24
- `slopcheck install --help` output (local run, v0.6.1) — confirmed the tool has no pub.dev/Dart ecosystem support
- `.planning/research/STACK.md`, `.planning/research/ARCHITECTURE.md`, `.planning/research/PITFALLS.md` — project-level research, 2026-09-23
- `.planning/phases/01-fundaci-n/01-RESEARCH.md`, `01-PATTERNS.md` — Phase 1 research/execution record, confirming what was actually shipped (concrete repository classes, no interfaces; `AsyncNotifier` + `Timer`-free auth pattern; exact schema as applied)
- `.planning/design/DESIGN-REFERENCE.md` — palette/typography/component patterns extracted from the approved mockup

### Secondary (MEDIUM confidence)
- [Supabase Storage access control docs](https://supabase.com/docs/guides/storage/security/access-control) (fetched via WebFetch) — `storage.foldername()` RLS pattern, official example
- Supabase `.rpc()`/`.createSignedUrl()`/`.uploadBinary()` API shape — cross-verified via WebSearch against multiple Supabase-docs-derived summaries (direct `supabase.com/docs/reference/dart/...` URLs returned 404 for the exact page slugs tried this session; content corroborated via search-result excerpts quoting the official docs, plus prior-session STACK.md citations of the same API)
- [PostgREST 12.2 resource embedding docs](https://docs.postgrest.org/en/v12/references/api/resource_embedding.html), [supabase/postgrest-js#197](https://github.com/supabase/postgrest-js/issues/197) — `!inner` embedded-filter behavior and its limitations when combined with top-level `.or()`
- [Baseflow/flutter_cached_network_image#428](https://github.com/Baseflow/flutter_cached_network_image/issues/428), [#1005](https://github.com/Baseflow/flutter_cached_network_image/issues/1005) — signed-URL/token cache-key defeat, corroborating the `cacheKey` pitfall

### Tertiary (LOW confidence)
- None — every claim above is either a direct codebase read, a live pub.dev API query, or an officially-sourced/cross-corroborated pattern.

## Metadata

**Confidence breakdown:**
- Standard stack (new packages + version pin): HIGH for existence/version/SDK-constraint (live pub.dev API queries this session, including the version-history query that caught the `cached_network_image` 4.x SDK break); MEDIUM for legitimacy (slopcheck ran but doesn't cover pub.dev — see Package Legitimacy Audit)
- Schema gaps (`foto_path`, `mascota_pesos`) and their SQL: HIGH — directly derived from reconciling the live, applied `schema.sql` against the requirements and existing entities; the fix pattern (append-only history table, `es_veterinario()`/`mi_clinica_id()` reuse) mirrors Phase 1's own already-verified conventions exactly
- Storage bucket/RLS pattern: HIGH for the `storage.foldername()` mechanism (official Supabase docs); MEDIUM for the exact `.rpc()`/`.createSignedUrl()` Dart call signatures (WebFetch to the specific reference pages 404'd this session; corroborated via WebSearch excerpts instead of a direct doc fetch — recommend a quick sanity-check against the installed `supabase_flutter` package's own API docs/autocomplete during implementation)
- Debounce/search patterns: HIGH — standard, narrow Riverpod/PostgREST patterns with no exotic API surface
- Combined-create RPC: HIGH for the SQL pattern (mirrors the already-shipped, already-audited `crear_perfil_nuevo_usuario` precedent); MEDIUM for the exact Dart-side record-return unpacking syntax (`({String clienteId, String mascotaId})` Dart records — a newer Dart language feature, verify against the project's Dart 3.11.1 which does support records, introduced in Dart 3.0)

**Research date:** 2026-09-24
**Valid until:** 14 days (schema/RLS patterns are stable; the one fast-moving element is the `cached_network_image` SDK-constraint situation — re-verify the pin if this phase doesn't start within two weeks, in case a `^3.4.x` patch or a project-wide Dart SDK bump changes the calculus)

---
*Research for: Phase 2 — Clientes y Pacientes (VetApp)*
*Researched: 2026-09-24*
