# Phase 3: Historia Clínica - Research

**Researched:** 2026-09-26
**Domain:** Supabase (Postgres/RLS) append-only clinical-record schema + atomic RPC feeding a Phase 2 table + client-side PDF generation/native share in Flutter, on top of the CRUD/repository/provider patterns already shipped in Phases 1-2
**Confidence:** HIGH

## Summary

This phase adds one new table (`consultas`), one new atomic RPC (`registrar_consulta`), and one new capability class the codebase has never needed before: client-side PDF generation with native share. Everything else — repository shape, error handling, `AsyncNotifier` providers, nested `go_router` routes, append-only RLS — is a direct, proven copy of patterns Phase 1/2 already shipped and verified in production.

The two genuinely new risks this phase must manage are the same shape as risks already hit once before: (1) **another Dart-SDK version trap**, this time on the `pdf`/`printing` packages — `pdf ^3.13.0` and `printing ^5.15.0` (both published within the last ~3 months) both silently raise their minimum SDK to `>=3.12.0`, incompatible with this project's locked `sdk: ^3.11.1` (identical failure mode to `cached_network_image` in Phase 2), and (2) **entity/schema mismatch** on the pre-existing `Consulta`/`ExamenFisico` scaffolding — `anamnesis`/`diagnostico`/`tratamiento` are currently typed as non-nullable `String` in the entity, which contradicts D-03 (only diagnóstico + tratamiento are actually required; anamnesis/evolución/examen físico must be optional and stay `null`, not `''`, when skipped).

The mockup (`DESIGN-REFERENCE.md`, screen 4 "Ficha de paciente / Historia clínica") already answers the UI-SPEC discretion item left open in CONTEXT.md: the timeline lives **inline in the same ficha screen** as the patient's basic data (next to/below "Historial de peso," which Phase 2 already built there), not a separate screen — with a primary button "Nueva consulta." This phase should extend `mascota_detail_screen.dart` with a "Historia clínica" section following the exact `_HistorialPeso`/`_RegistrarPesoSheet` structural pattern already in that file, not invent a new screen-navigation paradigm.

**Primary recommendation:** Add `consultas` as a flat-column (not JSONB), append-only table with the same `es_veterinario()`/`mi_clinica_id()`-scoped RLS as `mascota_pesos`; register every consulta through one new `security invoker` RPC (`registrar_consulta`, modeled exactly on `registrar_mascota`) that atomically inserts into both `consultas` and — only when a peso is supplied — `mascota_pesos`; pin `pdf: 3.12.0` and `printing: 5.14.3` as **exact versions** (not `^`, since the caret would silently resolve to the SDK-incompatible 3.13.x/5.15.x); and use `Printing.sharePdf(bytes:, filename:)` directly for HIST-03/D-05 — no `share_plus` dependency is needed, since `printing`'s own share function already opens the native OS share sheet.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Consulta CRUD (insert/select only) | Database / Storage (Postgres RLS, append-only) | App/Client (Riverpod repository + `AsyncNotifier`) | Same pattern as every other table — RLS is the sole security boundary; no update/delete policy exists at all, enforcing HIST-04 at the tier that can't be bypassed by a future UI mistake |
| Consulta + peso atomic write (D-02) | Database / Storage (single Postgres RPC, atomic) | App/Client (one repository method calling `.rpc()`) | Mirrors `registrar_mascota`/`registrar_cliente_con_mascota` exactly — a peso captured mid-consulta must land in the same `mascota_pesos` row-set Phase 2 built, in the same transaction as the consulta insert, so a partial failure never creates a consulta with no matching weight row or vice versa |
| Clinical-record confidentiality (only the clinic's own vet sees it) | Database / Storage (RLS scoped by `mascotas.clinica_id`) | — | Reuses the exact `es_veterinario()`/`mi_clinica_id()` helpers every other table already uses — no new access-control primitive |
| Timeline rendering (HIST-02) | App/Client (Flutter widget, single unpaginated query) | Database / Storage (indexed `order by fecha desc`) | At this project's confirmed scale (one clinic, one independent vet, per `ARCHITECTURE.md`'s own "no caching/pagination layer needed yet" conclusion, reaffirmed in Phase 2 research) a single ordered query is sufficient; flagged as an Open Question below for the multi-year-growth case |
| PDF document assembly (HIST-03/D-04) | App/Client (Dart `pdf` package, in-process) | — | Pure client-side rendering from already-fetched `Consulta` rows — no server involvement, no Edge Function, matches D-05's "vet-only, no public link" scope exactly |
| Native share/save of the generated PDF (D-05) | Browser/Client (OS share sheet via `printing` plugin) | — | `Printing.sharePdf` hands the bytes to the platform's native share intent (Android)/UIActivityViewController (iOS) — no custom intent-wrapper code, no upload |

## Project Constraints (from CLAUDE.md)

- **Tech stack locked**: Flutter + Supabase — no alternative PDF-backend (e.g., a server-rendered PDF Edge Function) is in scope; generation stays 100% client-side per D-05.
- **Backend real, no mocks**: `consultas` must be a real table in the live Supabase project; no seeded/mock consulta data left behind.
- **Diseño**: terracota/crema palette, Caprasimo + Figtree — the new "Nueva consulta" form and the extended ficha timeline section must reuse `AppCard`/`AppButton`/`AppTextField`/`AppTopBar`, never raw Material widgets, exactly like every screen since Phase 1.
- **Mercado objetivo**: Colombia — dates rendered `dd/mm/aaaa` via the existing `formatearFecha` helper (`lib/core/utils/formato.dart`); reuse it for consulta dates rather than a new `DateFormat` instance.
- **Fricción cero** (constraint, explicitly re-affirmed by the user twice during this phase's discuss-phase per CONTEXT.md): diagnóstico + tratamiento are the only required fields (D-03) — the "Nueva consulta" form must not gate submission behind anything else, including peso/examen físico.
- **GSD workflow enforcement**: implementation must happen through a GSD command — informational for the planner.
- **Established conventions** (binding, per Phases 1-2's actual shipped code): `snake_case.dart` files; Spanish domain nouns/fields with English plumbing; two-tier error handling (`on PostgrestException catch` → Spanish message via a centralized `_messageFor` switch, plus a generic catch-all); repository classes named `Supabase<Domain>Repository` with no `domain/repositories/` interface; providers derive from `supabaseClientProvider`; append-only entities get **no** `copyWith` (see `PesoRegistro`'s explicit doc-comment precedent — `Consulta` should follow the same "no copyWith, no legitimate use case for modifying a saved record" rule).

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| HIST-01 | Registrar consulta con campos estructurados (anamnesis, examen físico, diagnóstico, tratamiento, evolución) | `consultas` table (flat columns, below) + `registrar_consulta` RPC + reconciled `Consulta`/`ExamenFisico` entity (below) |
| HIST-02 | Ver línea de tiempo de consultas de una mascota | `SupabaseConsultaRepository.porMascota()` (single `order by fecha desc` query) + inline timeline section in `mascota_detail_screen.dart`, per mockup screen 4 |
| HIST-03 | Exportar historia clínica de una mascota a PDF | `pdf` (document assembly) + `printing` (`Printing.sharePdf`, native share) — exact version pins and API below |
| HIST-04 | Registros de solo-append (no editar/borrar) | No `update`/`delete` RLS policy on `consultas` (same pattern as `mascota_pesos`); no edit screen ever built; `Consulta` entity has no `copyWith` |

</phase_requirements>

## Standard Stack

### Core (already installed — no version change)

| Library | Version (pinned) | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter_riverpod` | `^3.3.2` | State/DI | Already wired app-wide; `AsyncNotifier`/`FutureProvider.autoDispose.family` is the established pattern (`mascotaProvider`, `pesosProvider`) |
| `go_router` | `^17.3.0` | Navigation | New nested routes attach under the existing `pacientesRoute`/`clientesRoute` child-route lists, same shape as the existing `editar`/`nueva-mascota` children |
| `supabase_flutter` | `^2.9.1` (locked `2.17.2`) | Backend client | `.rpc()` call for `registrar_consulta`, `.from('consultas').select()` for the timeline |
| `intl` | `^0.20.3` | `dd/mm/aaaa` formatting | Reuse `formatearFecha` (`lib/core/utils/formato.dart`) for consulta dates |

### New this phase

| Library | Version to pin | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `pdf` | **`3.12.0`** (exact — not `^3.12.0`) `[VERIFIED: pub.dev API version-history query, 2026-09-26 — 3.12.0 published 2026-03-15 with sdk constraint >=2.19.0 <4.0.0 (compatible); 3.13.0/3.13.1 both raise the minimum to >=3.12.0 <4.0.0 (incompatible with this project's ^3.11.1)]` | Build the PDF document (`pw.Document`, `pw.MultiPage`, `pw.Text`, `pw.Table`) | De-facto standard Dart-native PDF generator (DavBfr/dart_pdf, publisher `nfet.net`), 1.55M downloads/30 days, 160/160 pub points, used by `printing` internally |
| `printing` | **`5.14.3`** (exact — not `^5.14.3`) `[VERIFIED: pub.dev API version-history query, 2026-09-26 — 5.14.3 published 2026-03-15 with sdk constraint >=3.3.0 <4.0.0 (compatible); 5.15.0/5.15.1 both raise the minimum to >=3.12.0 <4.0.0 (incompatible)]` | `Printing.sharePdf()` — native OS share sheet for the generated bytes; also supplies `PdfGoogleFonts` for Spanish-accented text | Same publisher/maintainer as `pdf` (DavBfr), 933K downloads/30 days, 160/160 pub points; `printing 5.14.3` depends on `pdf: ^3.10.0`, which is satisfied by the `pdf: 3.12.0` pin above — no version conflict between the two pins |

**No `share_plus` needed.** `Printing.sharePdf(bytes: ..., filename: ...)` already invokes the platform's native share intent (Android `Intent.ACTION_SEND` / iOS `UIActivityViewController`) directly from the `printing` plugin — adding a second sharing package would be redundant for this phase's exact need (D-05: native share/save only, no public link). `[CITED: pub.dev/packages/printing usage docs, WebFetch this session]`

### ⚠️ Version correction — same failure mode as Phase 2's `cached_network_image`

Both `pdf` and `printing` jumped their minimum Dart SDK from `2.19`/`3.3` to `3.12.0` in their most recent minor release (3.13.0 / 5.15.0, both published 2026-06-16 — three months before this research). This project's `pubspec.yaml` is still `sdk: ^3.11.1` (confirmed via `flutter --version`/`dart --version` this session: installed toolchain is Flutter 3.41.4 / Dart 3.11.1). Adding either package with a caret (`^3.12.0`, `^5.14.3`) would let `flutter pub get` silently resolve to the newest 3.13.x/5.15.x release the very next time anyone runs `flutter pub upgrade`, breaking the build exactly like the `cached_network_image ^4.0.2` incident in Phase 2. **Pin both as exact versions, no caret.**

### Package Legitimacy Audit

`slopcheck` was reconfirmed this session to have no pub.dev/Dart ecosystem support (`slopcheck install --help` only lists `pypi, npm, crates.io, go, rubygems, maven, packagist` — same finding as Phase 2). Per the graceful-degradation rule, both packages below are tagged `[ASSUMED]` for the mechanical slopcheck/legitimacy gate (not for existence — existence, version, and SDK constraints were independently confirmed live against the pub.dev registry API this session, including full version-history queries and pub.dev's own score endpoint).

| Package | Registry | Age (first published) | Downloads (30d) | Source Repo | slopcheck | Disposition |
|---------|----------|------------------------|------------------|--------------|-----------|-------------|
| `pdf` | pub.dev | 2018 (major-version history back to 3.6.x in 2021, package itself older) | 1,550,137 | `github.com/DavBfr/dart_pdf` | N/A — ecosystem unsupported | `[ASSUMED]` — checkpoint:human-verify before install; **must be pinned exactly `3.12.0`** |
| `printing` | pub.dev | Same org/monorepo as `pdf` | 932,893 | `github.com/DavBfr/dart_pdf` | N/A — ecosystem unsupported | `[ASSUMED]` — checkpoint:human-verify before install; **must be pinned exactly `5.14.3`** |

**Packages removed due to slopcheck `[SLOP]` verdict:** none (no check ran; not applicable to this ecosystem).
**Packages flagged as suspicious `[SUS]`:** none — both packages carry the ecosystem-unsupported `[ASSUMED]` caveat above, but pub.dev's own metrics (160/160 pub points, 900K-1.5M downloads/30 days, single well-known publisher `nfet.net` shared by both) leave essentially no plausible hallucination/typosquat risk.

**Installation (manual pubspec.yaml edit — do NOT use bare `flutter pub add pdf printing`, which would resolve to the incompatible latest):**
```yaml
dependencies:
  pdf: 3.12.0
  printing: 5.14.3
```
Then run `flutter pub get` (not `flutter pub upgrade`, which could re-resolve past the pin on a later run without an explicit version constraint change).

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `pdf` + `printing` (native share only) | `pdf` + `printing` + `share_plus` | `share_plus` would only be needed if a manual "save to a specific local path" flow were required outside the OS share sheet — D-05 explicitly asks for the native share/save mechanism only, which `Printing.sharePdf` already provides directly; adding `share_plus` would be an unused, unjustified dependency |
| `consultas.examen_fisico_*` as flat columns | A single `examen_fisico jsonb` column | No precedent anywhere in `schema.sql` for JSONB on a structured, fixed-shape field (the closest analog, `mascota_pesos`, `clientes`, `mascotas`, all use flat columns); flat columns keep `check (peso_kg > 0)`-style server-side validation, type safety, and straightforward joins/selects — JSONB would only pay off if the vital-signs shape were expected to change per-consulta or grow dynamically, which it isn't (HIST-01 lists a fixed set: anamnesis, examen físico, diagnóstico, tratamiento, evolución) |
| `PdfGoogleFonts.notoSansRegular()`/`.notoSansBold()` (network-fetched, cached) for Spanish accented text | Bundling a static TTF asset in `pubspec.yaml`'s `flutter.fonts` | The project has zero bundled font assets today — every typeface (Caprasimo, Figtree) is already fetched dynamically via `google_fonts` at runtime and cached; `PdfGoogleFonts` (shipped inside `printing`) follows the identical already-accepted pattern, so no new asset-bundling convention needs to be introduced for this phase alone |

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│  MascotaDetailScreen (extended, ConsumerStatefulWidget)                  │
│    "Historia clínica" section (new) ── below "Historial de peso"         │
│    AppButton "Nueva consulta" ──push──▶ ConsultaFormScreen                │
│    AppBar action "Exportar PDF" (new icon button)                        │
└───────────┬───────────────────────────────────────┬───────────────────────┘
            │ ref.watch(consultasProvider(mascotaId))│ onPressed: _exportarPdf()
            ▼                                         ▼
┌───────────────────────────────┐        ┌─────────────────────────────────┐
│ SupabaseConsultaRepository      │        │ HistoriaClinicaPdfService         │
│  .porMascota(mascotaId)         │        │  .generar(mascota, consultas)     │
│  .registrarConsulta(...) → RPC  │        │  → pw.Document → Uint8List bytes  │
└───────────────┬───────────────────┘        └───────────────┬─────────────────┘
                │ .from('consultas')... / .rpc(...)          │ bytes
                ▼                                             ▼
┌────────────────────────────────────────────┐   ┌──────────────────────────────┐
│ Supabase Postgres — RLS as `authenticated`  │   │ Printing.sharePdf(bytes,     │
│ consultas (insert+select only, no update/   │   │   filename) → native OS      │
│ delete) + mascota_pesos (fed atomically     │   │   share sheet (WhatsApp,     │
│ from registrar_consulta when peso given)    │   │   correo, guardar en archivos)│
└────────────────────────────────────────────┘   └──────────────────────────────┘
```

### Recommended Project Structure (Phase 3 deltas)

```
lib/features/clinical_history/
├── data/
│   ├── repositories/
│   │   └── supabase_consulta_repository.dart      # NEW
│   └── services/
│       └── historia_clinica_pdf_service.dart       # NEW
├── domain/
│   ├── entities/
│   │   └── consulta.dart                           # EDIT — reconcile to schema (below)
│   └── consulta_failure.dart                       # NEW — mirrors MascotaFailure
└── presentation/
    ├── providers/
    │   └── consultas_providers.dart                 # NEW — consultaRepositoryProvider, consultasProvider, pdfServiceProvider
    ├── screens/
    │   └── consulta_form_screen.dart                # NEW — "Nueva consulta" (D-03 min-fields)
    └── widgets/
        └── historia_clinica_timeline.dart           # NEW — extracted section, mirrors _HistorialPeso

lib/features/patients/presentation/screens/mascota_detail_screen.dart   # EDIT — add timeline section + "Exportar PDF" action
lib/features/patients/presentation/pacientes_routes.dart                # EDIT — add consultas/nueva child route
lib/features/clients/presentation/clientes_routes.dart                  # EDIT — add the same child route under the mascotas/:mascotaId branch
```

### Pattern 1: `consultas` table — flat columns, append-only, same RLS shape as `mascota_pesos`

**What:** Every vital-sign/text field is its own nullable column (never JSONB); no `update`/`delete` policy exists at all, so HIST-04 is enforced by Postgres itself, not by UI discipline.
**When to use:** The one and only schema addition this phase needs.
**Example (SQL — delta on top of the applied `schema.sql`):**
```sql
-- HIST-01/04: historia clínica — append-only, misma filosofía que mascota_pesos.
-- Examen físico como columnas planas (no jsonb): forma fija conocida (5 campos),
-- nunca dinámica; permite check() de validación y selects directos, igual que
-- el resto del schema.
create table if not exists public.consultas (
  id uuid primary key default gen_random_uuid(),
  mascota_id uuid not null references public.mascotas(id) on delete cascade,
  veterinario_id uuid not null references auth.users(id) on delete cascade,
  fecha timestamptz not null default now(),

  anamnesis text,

  -- Examen físico (D-03: todos opcionales; el peso también alimenta mascota_pesos, ver RPC)
  peso_kg numeric(6,2) check (peso_kg is null or peso_kg > 0),
  temperatura_c numeric(4,1) check (temperatura_c is null or temperatura_c > 0),
  frecuencia_cardiaca integer check (frecuencia_cardiaca is null or frecuencia_cardiaca > 0),
  frecuencia_respiratoria integer check (frecuencia_respiratoria is null or frecuencia_respiratoria > 0),
  mucosas text,

  diagnostico text not null check (length(trim(diagnostico)) > 0),
  tratamiento text not null check (length(trim(tratamiento)) > 0),
  evolucion text,

  created_at timestamptz not null default now()
);

create index if not exists consultas_mascota_id_idx
  on public.consultas(mascota_id, fecha desc);

alter table public.consultas enable row level security;

drop policy if exists consultas_select on public.consultas;
create policy consultas_select on public.consultas for select to authenticated
using (
  public.es_veterinario()
  and exists (
    select 1 from public.mascotas m
    where m.id = consultas.mascota_id and m.clinica_id = public.mi_clinica_id()
  )
);

drop policy if exists consultas_insert on public.consultas;
create policy consultas_insert on public.consultas for insert to authenticated
with check (
  public.es_veterinario()
  and veterinario_id = auth.uid()
  and exists (
    select 1 from public.mascotas m
    where m.id = consultas.mascota_id and m.clinica_id = public.mi_clinica_id()
  )
);

-- Sin política update/delete: la historia clínica es de solo-append (HIST-04) —
-- una corrección se registra como una fila nueva, nunca editando ni borrando.
```
`veterinario_id` references `auth.users(id)` directly (not `public.perfiles(id)`) to mirror `perfiles.id`'s own definition (`perfiles.id references auth.users(id)`) — both point at the same identity, and every other cross-reference to "the authenticated actor" in this schema (`clientes.perfiles_id`) does the same. `on delete cascade` matches this schema's existing convention for every other FK (`mascotas.dueno_id`, `mascota_pesos.mascota_id`, etc.) rather than introducing a new `set null` convention — flagged in Assumptions Log below since it means a deleted vet account would cascade-delete their historical consultas, which may be undesirable for a legal medical record; no vet-account-deletion feature exists yet in this app, so the risk is currently theoretical.

### Pattern 2: `registrar_consulta` — atomic RPC feeding `mascota_pesos` (D-02)

**What:** One `security invoker` Postgres function, modeled line-for-line on `registrar_mascota` (Phase 2), that inserts the consulta and — only if `p_peso_kg is not null` — a `mascota_pesos` row, inside one implicit transaction.
**When to use:** The only way a consulta is ever created — never a direct client-side `.from('consultas').insert(...)` call, exactly per D-02's requirement that peso never gets recorded twice.
**Example:**
```sql
create or replace function public.registrar_consulta(
  p_mascota_id uuid,
  p_diagnostico text,
  p_tratamiento text,
  p_anamnesis text default null,
  p_evolucion text default null,
  p_peso_kg numeric default null,
  p_temperatura_c numeric default null,
  p_frecuencia_cardiaca integer default null,
  p_frecuencia_respiratoria integer default null,
  p_mucosas text default null
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_clinica_id uuid := public.mi_clinica_id();
  v_consulta_id uuid;
begin
  if not public.es_veterinario() or v_clinica_id is null then
    raise exception 'Solo un veterinario con clínica asignada puede registrar consultas.'
      using errcode = 'insufficient_privilege';
  end if;

  if not exists (
    select 1 from public.mascotas m where m.id = p_mascota_id and m.clinica_id = v_clinica_id
  ) then
    raise exception 'La mascota no existe en tu clínica.' using errcode = 'insufficient_privilege';
  end if;

  insert into public.consultas (
    mascota_id, veterinario_id, anamnesis, peso_kg, temperatura_c,
    frecuencia_cardiaca, frecuencia_respiratoria, mucosas, diagnostico, tratamiento, evolucion
  ) values (
    p_mascota_id, auth.uid(), p_anamnesis, p_peso_kg, p_temperatura_c,
    p_frecuencia_cardiaca, p_frecuencia_respiratoria, p_mucosas,
    trim(p_diagnostico), trim(p_tratamiento), p_evolucion
  ) returning id into v_consulta_id;

  if p_peso_kg is not null then
    insert into public.mascota_pesos (mascota_id, peso_kg) values (p_mascota_id, p_peso_kg);
  end if;

  return v_consulta_id;
end;
$$;

revoke all on function public.registrar_consulta(
  uuid, text, text, text, text, numeric, numeric, integer, integer, text
) from public, anon;
grant execute on function public.registrar_consulta(
  uuid, text, text, text, text, numeric, numeric, integer, integer, text
) to authenticated;
```
`security invoker` (not `definer`) is correct here for the same reason `registrar_mascota` uses it: the calling vet already has full RLS-granted insert rights on both `consultas` and `mascota_pesos` — the function's only job is atomicity, not privilege elevation. The `diagnostico`/`tratamiento` non-empty checks are already enforced by the table's own `check` constraints (defense in depth); the function's `not exists (...)` guard on `mascota_id` is what `registrar_mascota` does NOT need (it creates the mascota itself) but this function does, since it must reject a `mascota_id` from another clinic even though the RLS `insert` policy would also catch it — failing fast with a clear message before hitting the constraint is better UX than surfacing a raw RLS-denial error.

**Dart call site:**
```dart
Future<String> registrarConsulta({
  required String mascotaId,
  required String diagnostico,
  required String tratamiento,
  String? anamnesis,
  String? evolucion,
  double? pesoKg,
  double? temperaturaC,
  int? frecuenciaCardiaca,
  int? frecuenciaRespiratoria,
  String? mucosas,
}) async {
  try {
    final id = await _client.rpc('registrar_consulta', params: {
      'p_mascota_id': mascotaId,
      'p_diagnostico': diagnostico.trim(),
      'p_tratamiento': tratamiento.trim(),
      'p_anamnesis': anamnesis?.trim(),
      'p_evolucion': evolucion?.trim(),
      'p_peso_kg': pesoKg,
      'p_temperatura_c': temperaturaC,
      'p_frecuencia_cardiaca': frecuenciaCardiaca,
      'p_frecuencia_respiratoria': frecuenciaRespiratoria,
      'p_mucosas': mucosas?.trim(),
    });
    return id as String;
  } on PostgrestException catch (e) {
    throw ConsultaFailure(_messageFor(e));
  } catch (_) {
    throw const ConsultaFailure('No pudimos guardar la consulta. Intenta de nuevo.');
  }
}
```
After a successful call, invalidate **both** `consultasProvider(mascotaId)` and (only if `pesoKg != null`) `pesosProvider(mascotaId)` — the weight history widget already built in Phase 2 must reflect the new row without the vet needing to separately open "Registrar peso."

### Pattern 3: Reconciled `Consulta`/`ExamenFisico` entity

**What:** The existing scaffolded entity (`lib/features/clinical_history/domain/entities/consulta.dart`) has three mismatches against D-03/the schema above: `anamnesis`, `diagnostico`, `tratamiento` are all currently non-nullable `String` — but only `diagnostico`/`tratamiento` are actually required; `anamnesis` must be nullable. `proximaCita` and `adjuntoUrls` have no backing columns this phase (both explicitly deferred per CONTEXT.md) and should be **removed** from the entity now, following the exact precedent Phase 2 set for `Mascota.sexo`/`.color`/`.esterilizado` (`PITFALLS.md` Pitfall 6: don't keep fields designed against an imagined/future schema) — they can be re-added, with real columns, whenever Phase 4 (agenda) or the deferred adjuntos feature actually builds them.
**When to use:** First task of this phase, before writing the repository (same ordering Phase 2 used for its own entity reconciliation).
**Example:**
```dart
// lib/features/clinical_history/domain/entities/consulta.dart — RECONCILED

/// Signos vitales del examen físico. Todos opcionales (D-03) — no todos se
/// toman en cada visita. [pesoKg], si se llena, alimenta también
/// `mascota_pesos` (D-02) vía la RPC `registrar_consulta`, nunca un insert
/// separado.
class ExamenFisico {
  const ExamenFisico({
    this.pesoKg,
    this.temperaturaC,
    this.frecuenciaCardiaca,
    this.frecuenciaRespiratoria,
    this.mucosas,
  });

  final double? pesoKg;
  final double? temperaturaC;
  final int? frecuenciaCardiaca;
  final int? frecuenciaRespiratoria;
  final String? mucosas;

  bool get estaVacio =>
      pesoKg == null &&
      temperaturaC == null &&
      frecuenciaCardiaca == null &&
      frecuenciaRespiratoria == null &&
      (mucosas == null || mucosas!.isEmpty);
}

/// Entrada de historia clínica (HIST-01/04) — append-only: sin `copyWith`,
/// a propósito, igual que [PesoRegistro] — no existe un caso de uso
/// legítimo para "editar" una consulta ya guardada. Solo [diagnostico] y
/// [tratamiento] son obligatorios (D-03); si [anamnesis]/[evolucion]/
/// [examenFisico] quedan sin llenar al crear, permanecen así para siempre
/// (D-01/D-03) — una corrección se registra como una consulta nueva.
class Consulta {
  const Consulta({
    required this.id,
    required this.mascotaId,
    required this.veterinarioId,
    required this.fecha,
    required this.diagnostico,
    required this.tratamiento,
    this.anamnesis,
    this.examenFisico = const ExamenFisico(),
    this.evolucion,
  });

  final String id;
  final String mascotaId;
  final String veterinarioId;
  final DateTime fecha;
  final String diagnostico;
  final String tratamiento;
  final String? anamnesis;
  final ExamenFisico examenFisico;
  final String? evolucion;
}
```
`proximaCita`/`adjuntoUrls` removed per the reasoning above — if the plan-checker or a human reviewer prefers to keep them as unused/nullable placeholder fields instead (matching CONTEXT.md's literal wording "quedan sin usar esta fase" rather than "se eliminan"), flag this as Claude's Discretion for the planner to confirm; removing is the recommendation because it matches the project's own established anti-scope-creep precedent, not because CONTEXT.md locks it explicitly.

### Pattern 4: Inline timeline section in `MascotaDetailScreen` (per approved mockup)

**What:** `DESIGN-REFERENCE.md` screen 4 ("Ficha de paciente / Historia clínica") shows the timeline **inside the same ficha screen** as "datos básicos (raza, edad, peso)," with a primary button "Nueva consulta" — this resolves the UI-SPEC discretion item in CONTEXT.md without needing a separate design decision. Structurally this is the same shape as the existing `_HistorialPeso` section (Phase 2) — a `ConsumerWidget` reading a `FutureProvider.autoDispose.family`, rendered as a list of compact rows below a section header.
**When to use:** Extend `mascota_detail_screen.dart`'s `_buildBody` — add a "Historia clínica" section after "Historial de peso" (or before it — either ordering is a UI-SPEC-level call, not locked here), each row showing `fecha` + a one-line summary (`diagnostico`, truncated), expandable or tap-to-detail for the full text (anamnesis/examen físico/tratamiento/evolución) — mockup's own summary language is "fecha, motivo, notas," i.e., compact by default.
**Example:**
```dart
// lib/features/clinical_history/presentation/widgets/historia_clinica_timeline.dart
class HistoriaClinicaTimeline extends ConsumerWidget {
  const HistoriaClinicaTimeline({super.key, required this.mascotaId});
  final String mascotaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consultasAsync = ref.watch(consultasProvider(mascotaId));
    final textTheme = Theme.of(context).textTheme;

    return consultasAsync.when(
      data: (consultas) {
        if (consultas.isEmpty) {
          return Text('Aún no hay consultas registradas', style: textTheme.bodyLarge);
        }
        final ordenadas = List<Consulta>.of(consultas)
          ..sort((a, b) => b.fecha.compareTo(a.fecha)); // defensivo, igual que _HistorialPeso
        return Column(
          children: [
            for (final c in ordenadas)
              _ConsultaCard(consulta: c), // AppCard: fecha + diagnóstico, onTap -> detalle expandido
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Text('No pudimos cargar la historia clínica. Intenta de nuevo.'),
    );
  }
}
```
The "Nueva consulta" `AppButton` (primary, per mockup) pushes `'$rutaBase/consultas/nueva'` — reusing the exact `rutaBase` mechanism `MascotaDetailScreen` already carries for the `editar` route, so the create-consulta form works identically whether reached from `/pacientes/:id` or `/clientes/:id/mascotas/:mascotaId`.

### Pattern 5: PDF generation + native share (HIST-03, D-04, D-05)

**What:** Fetch every consulta for the mascota (already available via `consultasProvider`), assemble one `pw.MultiPage` document covering the whole history in chronological order, get the bytes via `document.save()`, then hand them directly to `Printing.sharePdf` — no intermediate file write, no upload.
**When to use:** The "Exportar PDF" action, wherever it's placed in the ficha's `AppBar` (an icon button is enough — HIST-03 doesn't require it to be a primary button per the mockup's literal button list).
**Example:**
```dart
// lib/features/clinical_history/data/services/historia_clinica_pdf_service.dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class HistoriaClinicaPdfService {
  /// Genera el PDF de TODA la historia clínica del paciente (D-04) — nunca
  /// una consulta individual.
  Future<Uint8List> generar({
    required Mascota mascota,
    required List<Consulta> consultas, // ya ordenadas cronológicamente
  }) async {
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));

    doc.addPage(pw.MultiPage(
      header: (context) => pw.Text(
        'Historia clínica — ${mascota.nombre}',
        style: pw.TextStyle(font: bold, fontSize: 16),
      ),
      build: (context) => [
        for (final c in consultas) ...[
          pw.SizedBox(height: 12),
          pw.Text(formatearFecha(c.fecha), style: pw.TextStyle(font: bold)),
          if (c.anamnesis != null) pw.Text('Anamnesis: ${c.anamnesis}'),
          pw.Text('Diagnóstico: ${c.diagnostico}'),
          pw.Text('Tratamiento: ${c.tratamiento}'),
          if (c.evolucion != null) pw.Text('Evolución: ${c.evolucion}'),
          pw.Divider(),
        ],
      ],
    ));

    return doc.save();
  }
}

// Call site (mascota_detail_screen.dart AppBar action):
Future<void> _exportarPdf(Mascota mascota, List<Consulta> consultas) async {
  final bytes = await ref.read(historiaClinicaPdfServiceProvider).generar(
    mascota: mascota, consultas: consultas,
  );
  await Printing.sharePdf(bytes: bytes, filename: 'historia_${mascota.nombre}.pdf');
}
```
`PdfGoogleFonts` (not the base14 PDF fonts) is required for correct rendering of Spanish accented characters (á, é, í, ó, ú, ñ) — base PDF fonts like Helvetica frequently mis-render or drop non-ASCII glyphs without an explicit Unicode-capable font loaded. `[CITED: DavBfr/dart_pdf Fonts-Management wiki + GitHub issue #1100, cross-referenced via WebSearch this session]` `PdfGoogleFonts.notoSansRegular()`/`.notoSansBold()` fetch over the network on first use and cache locally — no different in kind from how `google_fonts` already fetches Caprasimo/Figtree for the app's own UI, so this introduces no new offline/connectivity risk category for this project.

### Anti-Patterns to Avoid

- **Building an "editar consulta" screen or adding an `update`/`delete` RLS policy on `consultas`:** directly violates HIST-04/D-01 — a correction is always a new row, never a mutation of an existing one.
- **Calling `.from('consultas').insert(...)` directly from Dart instead of the `registrar_consulta` RPC:** re-opens the exact "peso recorded twice" / "orphaned insert on partial failure" risk Phase 2's Pitfall 3 already flagged for the combined-create flow.
- **Adding `pdf`/`printing` with a caret version constraint:** will silently break the build on the next `flutter pub upgrade`, identical to the `cached_network_image` incident.
- **Storing `examen_fisico` as JSONB "for flexibility":** no other table in this schema uses JSONB for a fixed-shape field; it would forfeit `check()` validation and consistency with the rest of the codebase for a flexibility need that doesn't exist (the vital-signs shape is fixed by HIST-01).
- **Treating an empty-string `''` as equivalent to `null` for optional fields:** per D-03, an omitted anamnesis/evolución must render as genuinely absent ("Sin registrar," matching the exact copy `mascota_detail_screen.dart` already uses for missing raza/fecha de nacimiento), not as a blank paragraph in the PDF — send `null` (via `?.trim()` returning `null` for empty input), never `''`, from the form to the RPC.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|--------------|-----|
| PDF document assembly | Manually constructing raw PDF byte streams / drawing operations | `pdf` package's widget system (`pw.MultiPage`, `pw.Text`, `pw.Table`) | Handles pagination, font embedding, and page-break flow automatically — hand-rolling PDF byte-level structure is a well-known deep rabbit hole with no payoff here |
| Native share-sheet integration | A custom `MethodChannel` invoking `Intent.ACTION_SEND` (Android) / `UIActivityViewController` (iOS) directly | `Printing.sharePdf(bytes:, filename:)` | Already cross-platform (Android/iOS/desktop), already handles temp-file creation and cleanup internally, exactly the same "don't hand-roll what `image_picker` already solves for camera" lesson Phase 2 already applied to a different native-integration surface |
| Atomic consulta+peso write | Two sequential client-side calls (`registrarConsulta()` then `registrarPeso()`) | The `registrar_consulta` RPC | Identical reasoning to Phase 2's `registrar_cliente_con_mascota`/`registrar_mascota` — a network blip between the two calls would either double-record the weight or silently lose it, contradicting D-02's explicit "el vet nunca registra el mismo peso dos veces" |
| Spanish-accented text rendering in PDF | Manually mapping/escaping accented characters or stripping them | `PdfGoogleFonts.notoSansRegular()`/`.notoSansBold()` | Base PDF fonts have documented Unicode gaps; loading a real Unicode font is the standard, one-line fix |

**Key insight:** every new capability this phase needs (PDF assembly, native share, atomic multi-table write, accented-text rendering) already has a standard, narrow, well-maintained tool — same lesson Phase 1/2 research already drew for their own new capabilities.

## Common Pitfalls

### Pitfall 1: `pdf`/`printing` caret version constraints silently break the build (same shape as Phase 2's `cached_network_image` incident)

**What goes wrong:** `pdf: ^3.12.0` and `printing: ^5.14.3` both resolve to `<4.0.0`/`<6.0.0` respectively — which includes the newer 3.13.x/5.15.x releases that raise the minimum Dart SDK to `3.12.0`, incompatible with this project's `^3.11.1`. A caret pin passes today (whichever version happens to be cached/resolved) but can break on the next `flutter pub upgrade` or a fresh `flutter pub get` on a different machine.
**Why it happens:** Both packages are maintained by the same publisher and bumped their SDK floor in the same recent release wave — this is a real, currently-live trap, not a hypothetical one (confirmed by direct pub.dev API version-history query this session, published dates 2026-06-16, three months before this research).
**How to avoid:** Pin both packages as exact versions (no `^`) in `pubspec.yaml`: `pdf: 3.12.0`, `printing: 5.14.3`.
**Warning signs:** `flutter pub get` reports a Dart SDK version conflict mentioning `pdf` or `printing` requiring `>=3.12.0`.
**Phase to address:** This phase, at dependency-add time — before writing any PDF code.

### Pitfall 2: Entity/schema drift on `anamnesis`/`diagnostico`/`tratamiento` nullability

**What goes wrong:** The pre-existing scaffolded `Consulta` entity types `anamnesis`, `diagnostico`, and `tratamiento` all as non-nullable `String`. If the repository/form code is written against that scaffolding as-is, either (a) the form is forced to require anamnesis too (violating D-03's zero-friction requirement), or (b) the repository silently passes `''` for a skipped anamnesis, which then renders as an empty paragraph in the PDF instead of being omitted — the exact "entity designed against an imagined shape" trap `PITFALLS.md` Pitfall 6 already flagged once for `Mascota`/`Cliente` in Phase 2.
**How to avoid:** Reconcile the entity first (Pattern 3 above) — `anamnesis` becomes `String?`, `diagnostico`/`tratamiento` stay required, before writing the repository or the form.
**Warning signs:** A form validator requiring anamnesis to be non-empty; a PDF rendering "Anamnesis: " with nothing after the colon instead of omitting the line.
**Phase to address:** This phase, as the first task (mirrors Phase 2's own task ordering).

### Pitfall 3: Peso captured in a consulta not reflected in the weight-history widget without a manual refresh

**What goes wrong:** `registrar_consulta` writes to `mascota_pesos` server-side, but if the client only invalidates `consultasProvider(mascotaId)` after a successful save (forgetting `pesosProvider(mascotaId)`), the "Historial de peso" section built in Phase 2 will show stale data until the vet manually navigates away and back.
**How to avoid:** After a successful `registrarConsulta()` call that included a non-null `pesoKg`, invalidate both `consultasProvider(mascotaId)` and `pesosProvider(mascotaId)` — the exact same dual-invalidation `MascotaDetailScreen._cambiarFoto` already does for `mascotaProvider`/`mascotasProvider` after a photo change.
**Warning signs:** UAT step "register a consulta with a weight, then check the weight-history section without leaving the screen" shows the old weight list.
**Phase to address:** This phase, in the consulta-save success handler.

### Pitfall 4: Treating the mockup's "Grabar nota de voz" button as in-scope

**What goes wrong:** The approved mockup (screen 4) literally shows a "Grabar nota de voz" button alongside "Nueva consulta." Building any voice-recording/transcription UI this phase would silently pull in DIFF-03 ("Notas de voz transcritas automáticamente a historia clínica"), an explicit v2/diferenciador requirement, not part of HIST-01..04.
**How to avoid:** Render the ficha screen's new section with only "Nueva consulta" (and the new "Exportar PDF" action) wired to real functionality this phase; if the mockup's voice-note button is rendered at all for visual parity, it must be disabled/no-op, not connected to any recording logic.
**Warning signs:** A `record`/`speech_to_text`-family package appearing in `pubspec.yaml` this phase.
**Phase to address:** This phase's UI-SPEC — flag explicitly for the planner/UI-SPEC author.

## Code Examples

### `SupabaseConsultaRepository` — full shape (mirrors `SupabaseMascotaRepository`'s two-tier error handling)

```dart
// lib/features/clinical_history/data/repositories/supabase_consulta_repository.dart
class SupabaseConsultaRepository {
  SupabaseConsultaRepository(this._client);
  final SupabaseClient _client;

  Future<List<Consulta>> porMascota(String mascotaId) async {
    try {
      final rows = await _client
          .from('consultas')
          .select()
          .eq('mascota_id', mascotaId)
          .order('fecha', ascending: false);
      return (rows as List)
          .map((r) => _fromRow(r as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ConsultaFailure(_messageFor(e));
    } catch (_) {
      throw const ConsultaFailure('No pudimos cargar la historia clínica. Intenta de nuevo.');
    }
  }

  // registrarConsulta(...) — see Pattern 2 above for the full body.

  Consulta _fromRow(Map<String, dynamic> row) => Consulta(
    id: row['id'] as String,
    mascotaId: row['mascota_id'] as String,
    veterinarioId: row['veterinario_id'] as String,
    fecha: DateTime.parse(row['fecha'] as String).toLocal(),
    diagnostico: row['diagnostico'] as String,
    tratamiento: row['tratamiento'] as String,
    anamnesis: row['anamnesis'] as String?,
    evolucion: row['evolucion'] as String?,
    examenFisico: ExamenFisico(
      pesoKg: (row['peso_kg'] as num?)?.toDouble(),
      temperaturaC: (row['temperatura_c'] as num?)?.toDouble(),
      frecuenciaCardiaca: row['frecuencia_cardiaca'] as int?,
      frecuenciaRespiratoria: row['frecuencia_respiratoria'] as int?,
      mucosas: row['mucosas'] as String?,
    ),
  );

  /// Traducciones centralizadas de `PostgrestException.code` — mismo patrón
  /// que `SupabaseMascotaRepository._messageFor`.
  String _messageFor(PostgrestException e) {
    switch (e.code) {
      case '42501':
        return 'No tienes permiso para realizar esta acción.';
      case '23503':
        return 'La mascota no existe en tu clínica.';
      case '23514':
        return 'Revisa los datos ingresados.';
      default:
        return 'No pudimos guardar los datos. Intenta de nuevo.';
    }
  }
}
```

### Route wiring — new child route under BOTH existing route files

```dart
// lib/features/patients/presentation/pacientes_routes.dart — inside the ':id' GoRoute's `routes:` list
GoRoute(
  path: 'consultas/nueva',
  builder: (_, state) => ConsultaFormScreen(mascotaId: state.pathParameters['id']!),
),
```
```dart
// lib/features/clients/presentation/clientes_routes.dart — inside 'mascotas/:mascotaId' GoRoute's `routes:` list (alongside the existing 'editar' child)
GoRoute(
  path: 'consultas/nueva',
  builder: (_, state) => ConsultaFormScreen(mascotaId: state.pathParameters['mascotaId']!),
),
```
Both routes must exist — `MascotaDetailScreen.rutaBase` is set to whichever parent path actually rendered it (`/pacientes/:id` or `/clientes/:id/mascotas/:mascotaId`), and the "Nueva consulta" button does `context.push('$rutaBase/consultas/nueva')`, so the child route must be reachable from both trees, exactly like `editar` already is.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| `pdf ^3.11.x`/`printing ^5.13.x` compatible with Dart `>=2.19`/`>=3.3` | `pdf 3.13.x`/`printing 5.15.x` require Dart `>=3.12.0` | 2026-06-16 (both packages, same release wave) | Any future Dart SDK bump on this project past `^3.11.1` should re-check whether the exact pins above can finally be relaxed to a caret; until then, exact pins are mandatory |

**Deprecated/outdated:** None — both packages are actively maintained (last release within the last ~3 months as of this research).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `pdf`/`printing` are legitimate, non-hallucinated packages | Package Legitimacy Audit | Low — slopcheck doesn't cover pub.dev, but pub.dev's own registry independently confirms both at 160/160 pub points, 900K-1.5M downloads/30 days, single well-known publisher (`nfet.net`/DavBfr) shared by both — essentially theoretical risk |
| A2 | `veterinario_id references auth.users(id) on delete cascade` (rather than `set null`) is the right FK behavior | `consultas` table SQL | Medium-low — no vet-account-deletion feature exists yet, so untestable today; if one is ever built, cascading deletes on a clinical/legal record may be the wrong default and should be revisited then, not now |
| A3 | `Printing.sharePdf` requires no additional Android/iOS manifest/permission entries (unlike Phase 2's camera permission for `image_picker`) | Standard Stack / PDF section | Medium — WebFetch of the official docs did not explicitly confirm zero Android/iOS permission requirements (only macOS print-entitlement requirements were explicit); recommend verifying on a real device during this phase's UAT before considering HIST-03 done, same discipline Phase 2 used for its own camera-permission verification (A2 in `02-RESEARCH.md`) |
| A4 | Removing `proximaCita`/`adjuntoUrls` from the `Consulta` entity now (rather than keeping them as unused nullable fields) is the preferred reconciliation | Pattern 3 | Low — CONTEXT.md's literal wording ("quedan sin usar esta fase") is compatible with either keeping-but-unused or removing-now; removing matches the project's own established precedent (Phase 2's entity reconciliation), but a human reviewer could reasonably prefer the other reading |

## Open Questions

1. **Does the consulta timeline need pagination/virtualization for a multi-year-practice patient?**
   - What we know: `ARCHITECTURE.md`'s own Scaling Considerations (reaffirmed in Phase 2 research) concluded no caching/pagination layer is needed yet at this project's confirmed scale (one clinic, one independent vet).
   - What's unclear: unlike `mascota_pesos` (typically a handful of entries per pet), `consultas` could plausibly accumulate dozens of entries per chronic-condition patient over several years — still almost certainly well under any performance-relevant threshold for a single unpaginated query, but worth re-checking once real usage data exists.
   - Recommendation: ship the single unpaginated `order by fecha desc` query this phase (matches every other list in this codebase); revisit only if a future phase's UAT surfaces an actual slow-load complaint.

2. **Should the exported PDF include the veterinarian's name per consulta entry?**
   - What we know: `veterinario_id` is captured on every consulta (this phase's schema); the project is explicitly scoped to one independent vet per clinic in v1 (multi-vet/multi-usuario is SCALE-02, deferred to v2).
   - What's unclear: whether a "Dr./Dra. X" attribution line adds value for a solo practitioner exporting their own record, versus just being extra noise.
   - Recommendation: omit vet attribution from the PDF this phase (the data is already stored and queryable if a future multi-vet phase needs it) — keep the export focused on clinical content per D-05's "vet-only, informal" framing.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter/Dart toolchain | Everything this phase | ✓ | Flutter 3.41.4 / Dart 3.11.1 (confirmed via `flutter --version` this session) | — |
| Supabase cloud project | `consultas` table, RPC | ✓ (provisioned Phase 1, in active use since Phase 2) | — | — |
| Physical device or emulator with a share-sheet target (e.g., WhatsApp/Files installed) | Manual verification of D-05's native-share flow | Not probed this session (research-time, not build-time) | — | Emulators can still exercise the OS "Save to Files"/generic share target even without WhatsApp installed; real-device UAT recommended before considering HIST-03 done, same discipline as Phase 2's camera A2/A3 |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (already in use — `test/mascotas_providers_test.dart`, `test/mascota_detail_screen_test.dart`, etc.) |
| Config file | none — same convention as Phases 1-2 |
| Quick run command | `flutter test test/consultas_providers_test.dart test/consulta_form_screen_test.dart` (new files, Wave 0) |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| HIST-01 | Consulta create succeeds with only diagnóstico+tratamiento filled; other fields stay `null` | unit (fake repository) | `flutter test test/consultas_providers_test.dart` | ❌ Wave 0 |
| HIST-01 | Form blocks submission only when diagnóstico or tratamiento is empty — never blocks on anamnesis/examen físico/evolución | widget | `flutter test test/consulta_form_screen_test.dart` | ❌ Wave 0 |
| HIST-02 | Timeline renders consultas ordered by fecha descending, defensively re-sorted client-side | widget (fake repository seeded with 2+ unordered `Consulta`) | `flutter test test/mascota_detail_screen_test.dart` | ❌ Wave 0 (extend existing file) |
| HIST-03 | `HistoriaClinicaPdfService.generar()` returns non-empty bytes for a list of consultas; includes every consulta (D-04, not just the latest) | unit (no real font network call needed if test stubs the font loader, or accept a slower integration-style test) | `flutter test test/historia_clinica_pdf_service_test.dart` | ❌ Wave 0 |
| HIST-04 | No `copyWith`/update path exists on `Consulta`; repository exposes no `actualizar`/`eliminar` method | static/manual code-review check (not a runtime test) | N/A — verify by grep during code review | ❌ Wave 0 (documented, not automated) |
| D-02 | `registrarConsulta` with a non-null `pesoKg` triggers exactly one RPC call carrying both the consulta fields and the peso — never two separate repository calls | unit (fake repository verifying call count/args) | `flutter test test/consultas_providers_test.dart` | ❌ Wave 0 |

RLS-level correctness (vet cannot read/insert another clinic's `consultas`; direct insert bypassing the RPC still respects `veterinario_id = auth.uid()` and clinic scoping; no update/delete succeeds against `consultas` even as the owning vet) is **manual-only**, per the same convention Phases 1-2 established — extend `supabase/tests/rls_smoke_test.sql` with `consultas` positive/negative cases using the same two-clinic (`vet_a`/`vet_b`) throwaway setup already in that file.

### Sampling Rate
- **Per task commit:** `flutter analyze && flutter test test/consultas_providers_test.dart test/consulta_form_screen_test.dart`
- **Per wave merge:** `flutter test` (full suite)
- **Phase gate:** Full suite green + extended RLS manual smoke test (`consultas` insert/select allow+deny, update/delete both denied for the owning vet) recorded before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/helpers/fake_consultas.dart` — new fake mirroring `test/helpers/fake_mascotas.dart`'s shape
- [ ] `test/consultas_providers_test.dart` — new, covers HIST-01/D-02
- [ ] `test/consulta_form_screen_test.dart` — new widget test, covers HIST-01's min-required-fields rule
- [ ] `test/historia_clinica_pdf_service_test.dart` — new, covers HIST-03/D-04 (whole-history export)
- [ ] Extend `test/mascota_detail_screen_test.dart` — add HIST-02 timeline-ordering assertions
- [ ] No framework install needed — `flutter_test` already present
- [ ] `supabase/tests/rls_smoke_test.sql` — extend with `consultas` checks (positive/negative select/insert, update/delete both denied)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | No change | Unchanged from Phases 1-2 |
| V3 Session Management | No change | Unchanged |
| V4 Access Control | Yes — extended, not newly established | `consultas` reuses `es_veterinario()`/`mi_clinica_id()`; no new access-control primitive |
| V5 Input Validation | Yes | `check (length(trim(diagnostico)) > 0)`/`check (length(trim(tratamiento)) > 0)` server-side backstops; numeric vital-sign `check`s (`> 0` or null); client-side form validation mirrors these exactly, never relies on the server check alone for UX |
| V6 Cryptography | No | Unchanged — Supabase Postgres/Storage encryption-at-rest defaults |
| V13 API/Data Integrity (append-only records) | Yes — new for this phase | No `update`/`delete` RLS policy on `consultas` at all — the strongest possible enforcement of HIST-04's "never edit/delete a clinical record" requirement, since it's structurally impossible even for a compromised client to mutate an existing row via PostgREST |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|----------------------|
| A malicious/buggy client attempts to `UPDATE`/`DELETE` a `consultas` row directly via PostgREST | Tampering / Repudiation (clinical record integrity) | No `update`/`delete` policy exists — PostgREST returns a permission-denied error for any such attempt, by construction, not by application-level logic |
| A vet's session token is used to insert a consulta against a `mascota_id` belonging to a different clinic (cross-tenant write) | Elevation of Privilege | `registrar_consulta`'s explicit `not exists (...)` guard + the `consultas_insert` RLS policy's own `exists (... m.clinica_id = mi_clinica_id())` clause — double-enforced, fails closed at either layer |
| A generated PDF is exported to the wrong recipient via the OS share sheet | Information Disclosure (social/UX risk, not a code vulnerability) | Out of scope for a code-level mitigation per D-05 (explicitly vet-only, informal, native share) — this is an accepted risk of the "vet-only, no public link" design, not something this phase's code can/should prevent |

## Sources

### Primary (HIGH confidence)
- Direct reads this session: `supabase/schema.sql`, `lib/features/clinical_history/domain/entities/consulta.dart`, `lib/features/patients/data/repositories/supabase_mascota_repository.dart`, `lib/features/patients/domain/entities/mascota.dart`, `lib/features/patients/domain/entities/peso_registro.dart`, `lib/features/patients/presentation/screens/mascota_detail_screen.dart`, `lib/features/patients/presentation/providers/mascotas_providers.dart`, `lib/features/patients/presentation/pacientes_routes.dart`, `lib/features/clients/presentation/clientes_routes.dart`, `lib/core/router/app_router.dart`, `lib/core/utils/formato.dart`, `pubspec.yaml`, `supabase/tests/rls_smoke_test.sql`, `.planning/design/DESIGN-REFERENCE.md`, `.planning/config.json`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `.planning/PROJECT.md`, `.planning/phases/03-historia-cl-nica/03-CONTEXT.md`
- `pub.dev API` (`https://pub.dev/api/packages/<name>`, including full version-history and `/score` endpoints) — live queries this session for `pdf`, `printing`, `share_plus` (existence, version, SDK constraints, publish dates, download counts, pub points)
- `.planning/phases/02-clientes-y-pacientes/02-RESEARCH.md`, `.planning/phases/01-fundaci-n/01-RESEARCH.md` — prior-phase research confirming actual shipped patterns (repository/provider shape, RPC atomicity precedent, `cached_network_image` version-trap precedent)
- Local `flutter --version`/`dart --version` — confirmed installed toolchain (Flutter 3.41.4 / Dart 3.11.1) matches `pubspec.yaml`'s `sdk: ^3.11.1`

### Secondary (MEDIUM confidence)
- [pub.dev/packages/printing](https://pub.dev/packages/printing) usage docs (fetched via WebFetch this session) — `Printing.sharePdf`/`Printing.layoutPdf` API shape, platform support, macOS entitlement requirement
- [pub.dev/packages/pdf](https://pub.dev/packages/pdf) usage docs (fetched via WebFetch this session) — `pw.Document`/`pw.MultiPage` API shape, font-loading guidance
- [DavBfr/dart_pdf Fonts-Management wiki](https://github.com/DavBfr/dart_pdf/wiki/Fonts-Management), [DavBfr/dart_pdf#1100](https://github.com/DavBfr/dart_pdf/issues/1100) — accented/non-English character rendering requiring an explicit Unicode font

### Tertiary (LOW confidence)
- None flagged beyond what's already noted in the Assumptions Log (A3: exact Android/iOS permission requirements for `Printing.sharePdf` not explicitly confirmed by the fetched docs).

## Metadata

**Confidence breakdown:**
- Standard stack (new packages + version pins): HIGH for existence/version/SDK-constraint (live pub.dev API queries this session, including the version-history query that caught the same SDK-break pattern Phase 2 already hit once); MEDIUM for legitimacy (slopcheck ran but doesn't cover pub.dev, though pub.dev's own score/download metrics independently corroborate both packages strongly)
- Schema (`consultas` table + RLS + RPC): HIGH — directly derived from the live, applied `schema.sql`'s own `mascota_pesos`/`registrar_mascota` precedents, same helper functions, same conventions
- Entity reconciliation: HIGH — direct comparison of the existing scaffolded entity against D-03's explicit requirement text
- PDF/share architecture: MEDIUM-HIGH — API shape confirmed via official docs (WebFetch) and cross-referenced GitHub sources; the one open gap (exact mobile permission requirements) is flagged in the Assumptions Log, not asserted as fact
- UI placement (inline timeline vs. separate screen): HIGH — directly resolved by the approved mockup's own screen inventory (`DESIGN-REFERENCE.md`), not a guess

**Research date:** 2026-09-26
**Valid until:** 14 days (schema/RLS patterns are stable long-term; the fast-moving element is the `pdf`/`printing` SDK-constraint situation — both packages released their SDK-breaking versions only 3 months before this research, so re-verify the exact pins if this phase doesn't start within two weeks, in case another patch changes the calculus, exactly as flagged for `cached_network_image` in Phase 2)

---
*Research for: Phase 3 — Historia Clínica (VetApp)*
*Researched: 2026-09-26*
