# Phase 4: Agenda y Citas - Research

**Researched:** 2026-09-30
**Domain:** Flutter + Supabase appointment scheduling, local notifications (Android), WhatsApp deep links, Colombian phone normalization
**Confidence:** HIGH on stack/Android setup (verified against pub.dev + plugin source), MEDIUM on PostgREST composite-FK embeds and WhatsApp return detection (need on-device / live checks)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
(Copied verbatim from `04-CONTEXT.md` `<decisions>`)

**Crear una cita**
- **D-01:** La duración se fija **según el motivo**: chips de motivo (Consulta general, Vacunación, Control, Desparasitación, Baño/peluquería, Cirugía…) que traen una duración por defecto (ej. 30 min); el vet puede cambiarla. Se guarda inicio + duración.
- **D-02:** **Domicilio**: interruptor "A domicilio"; al activarlo la dirección se prellena con `clientes.direccion` y se puede cambiar para esa cita. En la tarjeta/detalle, botón "Cómo llegar" que abre Google Maps (sin pedir permisos de ubicación).
- **D-03:** Una cita puede incluir **varias mascotas del mismo dueño** (ej. Rocky y Luna juntos) — modelo de datos con relación cita↔mascotas (tabla puente), no un solo `mascota_id`.
- **D-04:** Si el cliente no está registrado: búsqueda instantánea del cliente; si no aparece, "+ Nuevo cliente y mascota" usa el **alta combinada existente** (Fase 2) y vuelve a la cita con cliente y mascota ya seleccionados. No se permiten citas sin cliente registrado.
- **D-05:** Campos obligatorios: **cliente, al menos una mascota, fecha y hora**. Motivo tiene valor por defecto "Consulta general". Notas y domicilio son opcionales. (Fricción cero.)
- **D-06:** Hora: la app **sugiere el primer hueco libre** del día elegido; se ajusta con botones grandes en pasos de 15 min (no el reloj analógico de Material).
- **D-07:** Puntos de entrada para crear cita: **botón "Nueva cita" en Agenda** y **"Agendar cita" desde la ficha de mascota/cliente** (con cliente y mascota preseleccionados).

**Vista y estados**
- **D-08:** Vista: **tira de días LUN–DOM + lista de citas por hora** del día seleccionado (como el mockup). La tira indica cuántas citas hay por día; navegación entre semanas; abre siempre en "Hoy". No se usa paquete de calendario de terceros (table_calendar/syncfusion).
- **D-09:** Cruces: si una cita nueva o editada se solapa con otra, **avisar sin bloquear** ("Se cruza con Luna 10:00 — ¿agendar igual?"). Nada de constraint de exclusión en BD.
- **D-10:** Estados: **pendiente, confirmada, completada, cancelada, no_asistió**. Además, **`solicitada` reservado en la base de datos para Fase 9** (cita pedida por el cliente desde el directorio), sin UI en esta fase. Preferir `text` + `check` sobre enum de Postgres para poder ampliar.
- **D-11:** El estado se cambia con **botones visibles en la tarjeta y en el detalle** (Confirmar / Completar / No asistió / Cancelar), con "Deshacer" en snackbar. Sin gestos de deslizar.

**Recordatorios**
- **D-12:** Recordatorio local: **1 hora antes por defecto**, configurable globalmente en Más > Recordatorios (15/30/60/120 min). No por cita.
- **D-13:** Permiso de notificaciones (Android 13+) se pide **en contexto al crear la primera cita**, explicando para qué sirve. Si se niega, aviso persistente (no error) en Agenda.
- **D-14:** Mensaje de WhatsApp en **tono formal con "usted"**. Plantilla base: *"Hola {cliente}, le recordamos la cita de {mascota(s)} el {ddd dd/mm} a las {h:mm a. m.} {en el consultorio | a domicilio en {dirección}}. — {veterinario}, {clínica}. Responda SÍ para confirmar."*
- **D-15:** **"Recordar a todos los de mañana"**: botón en la vista del día siguiente que abre WhatsApp cliente por cliente en serie y marca cada cita como "recordatorio enviado" (fecha/hora). Cada cita también tiene su botón WhatsApp individual con la misma marca.
- **D-16:** Teléfono: **normalizar a formato +57** al usarlo y al guardar en formularios de cliente ("300 123 4567" → `573001234567`); aviso suave si no parece celular colombiano; números fijos sin botón WhatsApp (deshabilitado con explicación); números con otro indicativo "+" se respetan. Sin migración masiva de datos existentes.

**Completar → consulta**
- **D-17:** "Completar" **ofrece registrar consulta, pero es opcional**: abre el formulario de consulta ya vinculado a la cita; también existe "Completar sin consulta" (vacuna rápida, etc.).
- **D-18:** Con varias mascotas: **una consulta por mascota** — se muestra la lista de mascotas de la cita y se registra cada una (se puede saltar alguna). La cita queda completada al cerrar ese flujo.
- **D-19:** La consulta se **precarga con el motivo (y notas) de la cita en anamnesis**, editable antes de guardar. La consulta guarda referencia a la cita (vínculo formal cita→consulta). Las consultas siguen siendo solo-append (HIST-04 / Fase 3 D-01): solo se agrega la referencia al crearla.

### Claude's Discretion
- Esquema exacto: tablas `citas` / `cita_mascotas`, columnas (`fecha_hora timestamptz`, `duracion_min`, `modalidad`, `direccion`, `motivo`, `notas`, `estado`, `recordatorio_enviado_at`), FK compuestas por `clinica_id` como en `mascotas`, índices, RLS (via agente `vetapp-supabase`) y extensión de `supabase/tests/rls_smoke_test.sql`.
- Mecanismo del vínculo cita→consulta (p. ej. `consultas.cita_id` nullable + parámetro nuevo en `registrar_consulta`, o RPC nueva) y si completar la cita va en la misma transacción.
- Si cancelar reemplaza al borrado (recomendado: no borrar citas, solo cancelar).
- Paquete de notificaciones locales (p. ej. `flutter_local_notifications` + `timezone`), modo de programación (preferir inexacto sin permiso de alarma exacta), reprogramación idempotente al abrir app / cambiar sesión, `cancelAll()` al cerrar sesión, compatibilidad con Dart `^3.11.1` y requisitos de build Android (desugaring, compileSdk).
- Zona horaria: guardar `timestamptz`, mostrar en America/Bogota (UTC-5 fijo); rangos de "día" calculados en hora de Bogotá.
- `url_launcher` como dependencia directa para `wa.me` y Maps; detección de regreso de WhatsApp en el envío en serie (fallback: marcar manualmente).
- Lista exacta de motivos y sus duraciones por defecto; dónde vive la utilidad de normalización de teléfono (`lib/core/utils/`).
- Diseño visual de tarjeta, detalle y formulario — resolver en `/gsd-ui-phase 4` siguiendo el mockup.

### Deferred Ideas (OUT OF SCOPE)
- "¿Agendar control en 8/15/30 días?" al guardar una consulta — no seleccionado como entrada en esta fase; candidato a backlog/Fase 8.
- Cola offline de cambios de estado de citas (atención en zonas sin señal) — backlog junto con estrategia offline-first general.
- Plantilla de WhatsApp editable por el veterinario — se eligió plantilla fija formal; posible mejora futura.
- Sincronización con Google Calendar, citas recurrentes — descartadas para v1.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AGND-01 | Ver agenda día/semana | Single week-range query on `citas` with embeds; Bogota day-range helper; DayStrip + hourly list from one provider (Architecture, Pattern 2) |
| AGND-02 | Crear cita con cliente y mascota(s) | `citas` + `cita_mascotas` schema, `crear_cita` RPC (atomic, same-owner guard), overlap + free-slot pure functions, combined-alta return mode |
| AGND-03 | Marcar confirmada/pendiente/completada (+cancelada/no_asistió) | `estado` text+check, plain RLS-guarded UPDATE with undo; reopen -> pendiente |
| AGND-04 | Recordatorio local antes de cita | `flutter_local_notifications` 22.3.1 + `timezone`, `inexactAllowWhileIdle`, idempotent cancelAll+reschedule service behind an interface, boot receiver, POST_NOTIFICATIONS |
| AGND-05 | Recordatorio WhatsApp un toque | `url_launcher` direct dep, `wa.me` URL builder (encodeComponent), phone normalizer, lifecycle-based return detection for batch |
| AGND-06 | Completar cita -> consulta vinculada | `consultas.cita_id` + new `registrar_consulta` signature (drop old), partial unique index (cita_id, mascota_id), CompletarCitaScreen flow |
</phase_requirements>

## Summary

Phase 4 adds the first feature that spans four existing areas (clients, patients, clinical history, shell navigation) and the first time-based/OS-integrated behavior (local notifications, external app launches). Everything on the Supabase side follows patterns already shipped: composite `(x_id, clinica_id)` FKs, `es_veterinario()`/`mi_clinica_id()` RLS, `security invoker` RPCs for multi-table atomicity, and append-only `consultas`. Everything on the Flutter side follows the Phase 2/3 pattern: `Supabase*Repository` with two-tier error translation to a `*Failure`, Riverpod `FutureProvider.autoDispose.family` + an action class that invalidates after writes, and a `routes` file mounted in the shell branch.

The three new packages all resolve against this project today (`flutter pub add --dry-run` succeeded): `flutter_local_notifications ^22.3.1` (requires Dart `^3.10.0`, Flutter `>=3.38.1`; project is Dart `^3.11.1` / Flutter 3.41.4), `timezone ^0.11.1` (Dart `^3.10.0`), and `url_launcher ^6.3.2` (already locked transitively at 6.3.2; only needs promotion). v22.3.1's Android build uses AGP 8.11.1 + compileSdk 36, which exactly match this project's `settings.gradle.kts` (AGP 8.11.1) and Flutter 3.41.4's `compileSdkVersion = 36`. Do NOT use `23.0.0-dev.*` (needs Dart 3.12 / AGP 9.1.1 / compileSdk 37).

Five non-obvious traps will bite the planner if not tasked explicitly: (1) the app has **no localization setup and never calls `initializeDateFormatting`**, so `es_CO` formatting, `showDatePicker` language, and "a. m." output need an explicit decision (recommendation: hand-written Spanish formatters + `flutter_localizations` for the date picker); (2) `mascotas` has **no `unique(id, clinica_id)`**, so `cita_mascotas` cannot get a composite FK to mascotas until it is added; (3) `registrar_consulta` must be **dropped and recreated** (adding a defaulted param otherwise creates an ambiguous overload for PostgREST); (4) Dart's `String.hashCode` is not stable across runs, so notification ids must come from a deterministic hash; (5) Dart `Uri` query encoding uses `+` for spaces, so build the `wa.me` URL with `Uri.encodeComponent`.

**Primary recommendation:** Build in three waves — (A) SQL via `vetapp-supabase` (tables, `unique` on mascotas, `crear_cita`/`actualizar_cita` RPCs, new `registrar_consulta`, RLS smoke checks) in parallel with pure-Dart utilities (Bogota time, phone normalizer, overlap/free-slot, WhatsApp message/URL, notification id/schedule planner) all unit-tested; (B) repository + providers + Agenda/Form/Detail/Completar screens against fakes; (C) notification service + Android Gradle/manifest changes + url_launcher + Más>Recordatorios, ending with `vetapp-gate`, `vetapp-brand-ui`, and a device UAT.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Tenant isolation of citas | Database (RLS + composite FKs) | — | Project rule: multi-tenancy enforced only in Postgres |
| Atomic cita create/edit with mascotas, same-owner check | Database (RPC `security invoker`) | API client (repository) | Multi-table write must be one transaction; same pattern as `registrar_cliente_con_mascota` |
| Cita -> consulta link, one-per-mascota | Database (column + partial unique index + RPC guard) | Flutter flow state | Integrity must not depend on the UI |
| Day/week range ("día" in Bogota) | Flutter client (pure util) | Database (timestamptz filter) | Fixed UTC-5, no DST; client computes UTC bounds |
| Overlap warning & free-slot suggestion | Flutter client (pure functions over the loaded day) | — | D-09: warn-only, no BD constraint; single-vet clinic |
| State transitions + Deshacer | Flutter notifier | Database (UPDATE via RLS) | Simple column update; undo = update back |
| Local reminder scheduling | OS (AlarmManager via plugin) | Flutter service | Source of truth is Supabase; OS schedule is a derived cache rebuilt on open |
| Notification permission & settings deep link | Android OS | Flutter service | POST_NOTIFICATIONS runtime request (Android 13+) |
| WhatsApp / Maps launch | External apps via `url_launcher` | Flutter widgets | No server involved (DIFF-01 API excluded) |
| Phone normalization | Flutter util (`lib/core/utils/`) | — | Applied at save time (forms) and at use time (WhatsApp) |
| Reminder lead-time setting | Device storage (`shared_preferences`) | — | Per-device setting (D-12), not per-cita |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter_local_notifications` | `^22.3.1` (published 2026-09-13) | Local scheduled notifications on Android (iOS optional) | De-facto plugin; v22.3.1 min Dart `^3.10.0`/Flutter `>=3.38.1`; AGP 8.11.1 + compileSdk 36 match project [VERIFIED: pub.dev API + plugin CHANGELOG + `flutter pub add --dry-run` resolves] |
| `timezone` | `^0.11.1` (2026-06-29) | `TZDateTime` required by `zonedSchedule`; fixed `America/Bogota` | Required by the plugin (already a transitive dep `^0.11.0`); lint `depend_on_referenced_packages` wants it direct [VERIFIED: pub.dev API, plugin README] |
| `url_launcher` | `^6.3.2` (already locked 6.3.2, transitive) | `https://wa.me/...` and Google Maps | Official flutter.dev package; promote to direct dependency [VERIFIED: pubspec.lock + pub.dev API] |
| `shared_preferences` | already locked transitively (via `supabase_flutter`); promote to direct, constrain to the locked major | Store reminder lead minutes (D-12) | Simplest per-device setting storage; already in the dependency graph [VERIFIED: pubspec.lock lists it; exact version to be read from lockfile at promotion time] |
| `flutter_localizations` (SDK) | sdk | Spanish `showDatePicker`/Material strings | Currently absent; without it the date picker renders in English [VERIFIED: grep shows no `localizationsDelegates`/`flutter_localizations` in lib or pubspec] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `permission_handler` | `^12.0.3` (already direct) | NOT needed for notifications | Plugin's own `requestNotificationsPermission()` / `areNotificationsEnabled()` / `openAppNotificationSettings()` cover it; do not add a second permission path |
| `flutter_riverpod` / `go_router` / `supabase_flutter` / `intl` | existing | state / routes / backend / number+date primitives | Reuse as in Phases 2-3 |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `flutter_local_notifications` | `awesome_notifications` | Heavier, different permission model; user/CONTEXT already named the first |
| `flutter_timezone` (detect device tz) | Fixed `tz.getLocation('America/Bogota')` | Detecting device tz adds a dependency and is wrong for the product: day boundaries must be Bogota regardless of device tz (UI-SPEC). Use fixed location |
| `table_calendar` | Hand-built `DayStrip` | Locked by D-08 (no third-party calendar package) |
| `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM` | `AndroidScheduleMode.inexactAllowWhileIdle` | Exact alarms are denied by default on Android 14+ for non-alarm/calendar apps and `USE_EXACT_ALARM` is subject to store policy review; 15-120 min lead makes minutes of slack irrelevant [CITED: developer.android.com/about/versions/14/changes/schedule-exact-alarms; plugin README] |

**Installation:**
```bash
flutter pub add flutter_local_notifications:^22.3.1 timezone:^0.11.1 url_launcher:^6.3.2
flutter pub add shared_preferences        # promote transitive -> direct (resolves to the locked version)
# flutter_localizations: add manually to pubspec.yaml
#   dependencies:
#     flutter_localizations:
#       sdk: flutter
```
`flutter pub add --dry-run flutter_local_notifications:^22.3.1 timezone:^0.11.1 url_launcher:^6.3.2` was run in this session and resolved cleanly ("Would change 8 dependencies"; no conflict with `pdf: 3.12.0`/`printing: 5.14.3` pins).

**Version verification:** versions above confirmed 2026-09-30 from `https://pub.dev/api/packages/<pkg>`. Popularity (pub.dev metrics): flutter_local_notifications ~2.9M downloads/30d, timezone ~3.6M, url_launcher ~6.8M.

## Package Legitimacy Audit

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| flutter_local_notifications | pub.dev | many yrs (v22.3.1, Sep 2026), 7.3k likes | ~2.9M/30d | github.com/MaikuB/flutter_local_notifications | not available (Python tool is npm-oriented; `slopcheck` binary not found after pip install) | Approved (named in CONTEXT/UI-SPEC; widely used; verified publisher dexterx.dev) |
| timezone | pub.dev | many yrs, 594 likes | ~3.6M/30d | github.com/srawlins/timezone | not available | Approved (already a transitive dep) |
| url_launcher | pub.dev | official flutter.dev, 8.1k likes | ~6.8M/30d | github.com/flutter/packages | not available | Approved (already in lockfile) |
| shared_preferences | pub.dev | official flutter.dev | already in lockfile | github.com/flutter/packages | not available | Approved (already in lockfile) |

**Packages removed due to slopcheck [SLOP] verdict:** none (slopcheck could not run).
**Packages flagged as suspicious [SUS]:** none. Dart packages have no npm-style `postinstall` scripts. Because slopcheck was unavailable, the planner may optionally add a trivial `checkpoint:human-verify` before the first `flutter pub add`; risk is very low since 3 of 4 packages are already in `pubspec.lock` and all four are publisher-verified, high-usage packages.

## Architecture Patterns

### System Architecture Diagram

```
                           ┌─────────────── Supabase (Postgres + RLS) ───────────────┐
                           │ citas ─┬─ cita_mascotas ── mascotas ── clientes         │
                           │        └─ consultas.cita_id (nullable, partial unique)  │
                           │ RPCs: crear_cita, actualizar_cita, registrar_consulta   │
                           └──────▲───────────────────────────────────▲──────────────┘
                                  │ week range select (+embeds)        │ rpc / update estado
 ┌───────────── Flutter ──────────┴────────────────────────────────────┴────────────┐
 │ SupabaseCitaRepository (CitaFailure, Spanish msgs)                                │
 │        │                                                                          │
 │        ▼                                                                          │
 │ Riverpod: agendaSemanaProvider(weekStartBogota) ─► DayStrip(counts) + hourly list │
 │           citaProvider(id) ─► CitaDetailScreen / CompletarCitaScreen              │
 │           CitaActions (crear/actualizar/cambiarEstado/marcarRecordatorio) ─┐      │
 │                                                                            │ after every write:
 │                                                                            ▼
 │                         invalidate(week providers) + RecordatoriosService.reprogramar()
 │                                                                            │
 │   pure utils (lib/core/utils): zona_bogota · telefono_co · cita_solapes ·  │
 │   whatsapp_mensaje                                                         ▼
 │                                              flutter_local_notifications ─► AlarmManager (inexact)
 │ Entry points: Nueva cita btn · ficha cliente/mascota "Agendar cita" · notification tap (payload=citaId)
 │ Outbound: url_launcher ─► WhatsApp (wa.me) / Google Maps (https)
 │ Triggers for reprogramar(): login/auth ready, AppLifecycleState.resumed, lead-time change, any cita write
 │ cancelAll(): on sign-out (authProfileProvider -> null)
 └───────────────────────────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure
```
lib/
├── core/utils/
│   ├── zona_bogota.dart          # UTC-5 fixed helpers: toBogota, bogotaDayRangeUtc, startOfWeek (Mon)
│   ├── telefono_co.dart          # normalizarTelefono(), clase de teléfono, formato "+57 300 123 4567"
│   └── formato_hora.dart         # hand-written "h:mm a. m.", "ddd dd/mm", duration "1 h 30 min"
├── features/appointments/
│   ├── domain/
│   │   ├── entities/cita.dart            # REWRITE: clinicaId, clienteId, mascotas[], duracionMin, modalidad, direccion, estado, recordatorioEnviadoAt
│   │   ├── cita_failure.dart
│   │   ├── cita_solapes.dart             # solapa(), primerHuecoLibre() pure
│   │   ├── motivos_cita.dart             # motivo -> default duration table
│   │   └── whatsapp_recordatorio.dart    # mensaje D-14 + wa.me URL builder
│   ├── data/
│   │   ├── repositories/supabase_cita_repository.dart
│   │   └── services/recordatorios_service.dart   # interface + LocalNotificationsRecordatorios impl
│   └── presentation/
│       ├── agenda_routes.dart            # GoRoute('/agenda') mounted in app_router shell
│       ├── providers/{citas_providers,recordatorios_providers}.dart
│       ├── screens/{agenda,cita_form,cita_detail,completar_cita,recordatorios}_screen.dart
│       └── widgets/{day_strip,cita_card,time_stepper,cliente_search_field,mascota_multi_select,proxima_banner,notificaciones_banner}.dart
supabase/schema.sql                       # Fase 4 delta section (idempotent)
supabase/tests/rls_smoke_test.sql         # + J.. checks
test/helpers/{fake_citas.dart,fake_recordatorios.dart,fake_url_launcher.dart}
```

### Pattern 1: Schema (follow `mascotas` + `consultas` exactly) [VERIFIED: supabase/schema.sql read]
```sql
-- ===== Fase 4: Agenda y Citas (delta idempotente) =====
-- mascotas necesita (id, clinica_id) unique para poder ser blanco de FK compuesta.
do $$ begin
  alter table public.mascotas add constraint mascotas_id_clinica_id_key unique (id, clinica_id);
exception when duplicate_object or duplicate_table then null; end $$;

create table if not exists public.citas (
  id uuid primary key default gen_random_uuid(),
  clinica_id uuid not null references public.clinicas(id) on delete cascade,
  cliente_id uuid not null,
  veterinario_id uuid not null references auth.users(id) on delete cascade,
  fecha_hora timestamptz not null,
  duracion_min integer not null default 30 check (duracion_min between 5 and 480),
  modalidad text not null default 'consultorio' check (modalidad in ('consultorio','domicilio')),
  direccion text not null default '',
  motivo text not null default 'Consulta general' check (length(trim(motivo)) > 0),
  notas text not null default '',
  estado text not null default 'pendiente'
    check (estado in ('solicitada','pendiente','confirmada','completada','cancelada','no_asistio')),
  recordatorio_enviado_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint citas_id_clinica_id_key unique (id, clinica_id),
  constraint citas_cliente_misma_clinica_fkey foreign key (cliente_id, clinica_id)
    references public.clientes(id, clinica_id) on delete cascade,
  constraint citas_domicilio_requiere_direccion
    check (modalidad <> 'domicilio' or length(trim(direccion)) > 0)
);
create index if not exists citas_clinica_fecha_idx on public.citas(clinica_id, fecha_hora);
-- reutiliza public.tocar_updated_at() (ya existe) con un trigger citas_tocar_updated_at

create table if not exists public.cita_mascotas (
  cita_id uuid not null,
  mascota_id uuid not null,
  clinica_id uuid not null,
  primary key (cita_id, mascota_id),
  constraint cita_mascotas_cita_fkey foreign key (cita_id, clinica_id)
    references public.citas(id, clinica_id) on delete cascade,
  constraint cita_mascotas_mascota_fkey foreign key (mascota_id, clinica_id)
    references public.mascotas(id, clinica_id) on delete cascade
);
create index if not exists cita_mascotas_mascota_idx on public.cita_mascotas(mascota_id);

alter table public.consultas
  add column if not exists cita_id uuid references public.citas(id) on delete set null;
-- una consulta por (cita, mascota): hace idempotente "Registrar consulta" y alimenta "Consulta registrada"
create unique index if not exists consultas_cita_mascota_key
  on public.consultas(cita_id, mascota_id) where cita_id is not null;
```
RLS (mirror `mascotas_*`): `citas` select/insert/update `to authenticated using/with check (public.es_veterinario() and clinica_id = public.mi_clinica_id())`; **no delete policy** (cancel replaces delete, so FK `consultas.cita_id on delete set null` is only a safety net); `cita_mascotas` select/insert/delete same predicate, **no update**. Phase 9 (DIR-05) will add its own client-facing policies later — do not add them now.

Design notes the planner must carry:
- The composite FK on `cita_mascotas` guarantees mascota and cita are in the same clinica, but **not** that the mascota belongs to the cita's cliente (D-03: "mismo dueño"). Enforce inside the RPCs (`mascotas.dueno_id = p_cliente_id`) and add an RLS smoke check; optionally a `before insert` trigger on `cita_mascotas` as defense in depth.
- `veterinario_id` mirrors `consultas.veterinario_id` (references `auth.users`); RLS insert should require `veterinario_id = auth.uid()`.
- `ON DELETE CASCADE` from `clientes` matches the mascotas pattern; flag for the user that deleting a cliente deletes its citas (same already true for mascotas/consultas via cascade).
- Do not use a Postgres enum for estado (D-10); the `check` list already includes `'solicitada'`.

### Pattern 2: Atomic RPCs `security invoker` (same shape as `registrar_cliente_con_mascota`)
```sql
create or replace function public.crear_cita(
  p_cliente_id uuid, p_mascota_ids uuid[], p_fecha_hora timestamptz,
  p_duracion_min integer default 30, p_modalidad text default 'consultorio',
  p_direccion text default '', p_motivo text default 'Consulta general', p_notas text default ''
) returns uuid language plpgsql security invoker set search_path = public as $$
declare v_clinica uuid := public.mi_clinica_id(); v_id uuid;
begin
  if not public.es_veterinario() or v_clinica is null then
    raise exception 'Solo un veterinario con clínica asignada puede crear citas.' using errcode = 'insufficient_privilege';
  end if;
  if coalesce(array_length(p_mascota_ids,1),0) = 0 then
    raise exception 'Elige al menos una mascota.' using errcode = 'check_violation';
  end if;
  if exists (select 1 from unnest(p_mascota_ids) m(id)
             where not exists (select 1 from public.mascotas x
                               where x.id = m.id and x.dueno_id = p_cliente_id and x.clinica_id = v_clinica)) then
    raise exception 'El cliente o la mascota no existe en tu clínica.' using errcode = 'foreign_key_violation';
  end if;
  insert into public.citas(clinica_id, cliente_id, veterinario_id, fecha_hora, duracion_min, modalidad, direccion, motivo, notas)
  values (v_clinica, p_cliente_id, auth.uid(), p_fecha_hora, p_duracion_min, p_modalidad, trim(p_direccion), trim(p_motivo), trim(p_notas))
  returning id into v_id;
  insert into public.cita_mascotas(cita_id, mascota_id, clinica_id)
    select v_id, m, v_clinica from unnest(p_mascota_ids) m;
  return v_id;
end $$;
-- revoke all ... from public, anon; grant execute ... to authenticated;
```
`actualizar_cita(p_cita_id, ...)` same params: guard cita belongs to clinic and estado in ('pendiente','confirmada'), update columns, `delete from cita_mascotas where cita_id = ...` then re-insert (cliente is not changeable on edit per UI-SPEC). Do NOT delete/replace a mascota that already has a consulta linked (edit is not offered for terminal estados, so this is safe, but add a guard).

**Estado changes:** plain `update citas set estado = ...` through the table (RLS update policy). Reopen = `pendiente`. Completar = update `estado='completada'` AFTER the flow; consultas are created earlier one by one through `registrar_consulta`. Recommended: do NOT merge completion and consultas into one transaction (the UI-SPEC flow lets the vet register consulta 1, back out, return, register consulta 2; each consulta is independently durable and append-only; Deshacer reverts only estado). A server-side check "all mascotas have consulta or were skipped" is not representable (skips are not stored) so it stays a UI rule.

### Pattern 3: `registrar_consulta` signature change (drop first)
```sql
drop function if exists public.registrar_consulta(
  uuid, text, text, text, text, numeric, numeric, integer, integer, text);
create or replace function public.registrar_consulta(
  p_mascota_id uuid, p_diagnostico text, p_tratamiento text,
  p_anamnesis text default null, p_evolucion text default null,
  p_peso_kg numeric default null, p_temperatura_c numeric default null,
  p_frecuencia_cardiaca integer default null, p_frecuencia_respiratoria integer default null,
  p_mucosas text default null,
  p_cita_id uuid default null          -- NEW, appended last
) returns uuid ...
```
Inside: when `p_cita_id is not null`, verify `exists (select 1 from cita_mascotas cm join citas c on c.id=cm.cita_id where cm.cita_id=p_cita_id and cm.mascota_id=p_mascota_id and c.clinica_id=v_clinica)` else raise `foreign_key_violation`; insert `cita_id`. Why drop: a new function with a different arg list does not replace the old one, so PostgREST would see two overloads and RPC calls that omit `p_cita_id` become ambiguous. Re-issue `revoke ... from public, anon; grant ... to authenticated` with the NEW signature (the old grant lines in schema.sql must be updated/removed so re-running the whole file stays idempotent — `drop function if exists` placed BEFORE the create, in the Fase 4 delta; also edit the earlier Fase 3 `create or replace function` block so a full-file re-run does not recreate the old overload: simplest is to move/replace the Fase 3 definition with the new one and keep the `drop` just above it). Update `SupabaseConsultaRepository.registrarConsulta` to send `'p_cita_id': citaId` (always present, null allowed), `FakeConsultaRepository`, `RegistrarConsulta`, and the `consultas_providers` invalidation (also invalidate the cita provider so "Consulta registrada" updates).

### Pattern 4: Flutter data/provider layer (existing conventions) [VERIFIED: read supabase_consulta_repository.dart, consultas_providers.dart]
- `SupabaseCitaRepository(SupabaseClient)`: `semana(DateTime lunesBogota)` → one `select` with embeds, `obtener(id)`, `crear(...)` → `rpc('crear_cita')`, `actualizar(...)`, `cambiarEstado(id, EstadoCita)`, `marcarRecordatorioEnviado(id, DateTime? at)` (null = undo). `PostgrestException` → `CitaFailure` via a single `_messageFor` (codes `42501`, `23503`, `23514`, `23505`); catch-all Spanish message.
- Week query (single round trip; counts, list and overlap checks all derive from it):
```dart
final rows = await _client
    .from('citas')
    .select('*, clientes(nombre, telefono, direccion), cita_mascotas(mascotas(id, nombre, especie, foto_path))')
    .gte('fecha_hora', inicioUtc.toIso8601String())
    .lt('fecha_hora', finUtc.toIso8601String())
    .order('fecha_hora');
```
  Embedding `clientes` goes through the composite FK `citas_cliente_misma_clinica_fkey`; PostgREST supports composite-FK relationships but if ambiguity/shape errors appear, pin the relationship with the hint syntax `clientes!citas_cliente_misma_clinica_fkey(...)`. [ASSUMED] — verify in the first repository smoke run against the live project (see Open Questions).
- Providers: `agendaSemanaProvider = FutureProvider.autoDispose.family<List<Cita>, DateTime>` keyed by the Monday (Bogota) date; `citaProvider(id)`; `CitaActions` class holding `Ref` (non-autoDispose provider, like `RegistrarConsulta`) that invalidates `agendaSemanaProvider`/`citaProvider` and calls `RecordatoriosService.reprogramar()` after every successful write. Use a `clockProvider` (`DateTime Function()`) so "Hoy", "Próxima: en 25 min", and free-slot suggestion are testable without real time.
- Router (`/agenda` branch in `app_router.dart`): create `agenda_routes.dart` exporting `GoRoute agendaRoute` with children in this order: `nueva` (query params `clienteId`, `mascotaId`, `fecha`), `:id`, `:id/editar` (nested under `:id`), `:id/completar`. `nueva` MUST precede `:id` (same rule documented in `clientes_routes.dart`). Replace the `ComingSoonScreen` GoRoute with `agendaRoute`. Add `/mas/recordatorios` as a child of the `/mas` GoRoute (MasScreen currently only has "Cerrar sesión").
- `NuevoClienteMascotaScreen` currently ends with `context.pop()` (line ~157) and returns nothing. Add an optional "return result" mode (constructor flag or route extra) that pops `({String clienteId, String mascotaId})` — `registrarClienteConMascota` already returns `(clienteId, mascotaId)`. The form then awaits `context.push<...>('/clientes/nuevo?retorno=1')`. Minimal change; existing tests keep passing because default behavior is unchanged.
- `ConsultaFormScreen` takes `mascotaId` only; add optional `citaId` (query param on the existing `/pacientes/:id/consultas/nueva` and clientes route, or a new route `/agenda/:id/completar/consulta/:mascotaId`), prefill anamnesis with `"{motivo}. {notas}"`, show the "Cita del mié 30/09 · 10:30 a. m." pill, and pass `citaId` to `RegistrarConsulta`.
- `AppStatus` gains `noShow` (label "No asistió", `textMuted`, `Icons.person_off_outlined`); add a `EstadoCita -> AppStatus` mapper; `solicitada` is not exposed in the UI enum this phase (map defensively to pending if a row ever appears).

### Pattern 5: Bogota time handling (fixed UTC-5, no DST) [CITED: IANA America/Bogota has had no DST since 1993; ASSUMED stable]
```dart
// lib/core/utils/zona_bogota.dart
const _bogota = Duration(hours: 5); // UTC-5
/// Reloj de pared en Bogota representado como DateTime "UTC-flagged" (solo para componer/mostrar).
DateTime aBogota(DateTime instante) => instante.toUtc().subtract(_bogota);
/// Instante UTC real a partir de un reloj de pared Bogota (y, m, d, h, min).
DateTime deBogota(int y, int m, int d, [int h = 0, int min = 0]) =>
    DateTime.utc(y, m, d, h, min).add(_bogota);
({DateTime inicio, DateTime fin}) rangoDiaUtc(int y, int m, int d) =>
    (inicio: deBogota(y, m, d), fin: deBogota(y, m, d + 1)); // Dart normaliza d+1
DateTime lunesDeSemana(DateTime bogotaWall) { // weekday: Mon=1..Sun=7
  final d = DateTime.utc(bogotaWall.year, bogotaWall.month, bogotaWall.day);
  return d.subtract(Duration(days: d.weekday - 1));
}
```
Never use `toLocal()` for agenda display: the device timezone can differ from Bogota (travel, emulator in UTC), which would shift day boundaries. Existing code uses `toLocal()` for consultas — leave it, but agenda code goes through `aBogota`.

### Pattern 6: Notification service (interface + idempotent reschedule)
```dart
abstract class RecordatoriosService {
  Future<void> inicializar();                       // tz init + plugin init + channel
  Future<bool> permisoConcedido();                  // areNotificationsEnabled()
  Future<bool> solicitarPermiso();                  // requestNotificationsPermission()
  Future<void> abrirAjustes();                      // openAppNotificationSettings() (v22.3.0+)
  Future<void> reprogramar(List<Cita> proximas, int minutosAntes); // cancelAll + schedule
  Future<void> cancelarTodo();                      // sign-out
}
```
Implementation sketch (verified signatures from plugin source v22.3.1: `zonedSchedule({required int id, required TZDateTime scheduledDate, required NotificationDetails notificationDetails, required AndroidScheduleMode androidScheduleMode, String? title, String? body, String? payload, ...})`, `cancelAll()`, `initialize({...})`, `pendingNotificationRequests()`):
```dart
tz_data.initializeTimeZones();                       // package:timezone/data/latest.dart (smaller than latest_all)
tz.setLocalLocation(tz.getLocation('America/Bogota')); // fixed; no flutter_timezone

await plugin.cancelAll();
for (final c in proximas) {                           // only pendiente/confirmada, future, capped (e.g. next 30 days / 60 items)
  final cuando = c.fechaHora.toUtc().subtract(Duration(minutes: minutosAntes));
  if (!cuando.isAfter(ahora)) continue;               // never schedule in the past
  await plugin.zonedSchedule(
    id: idEstable(c.id),                              // deterministic FNV-1a(uuid) & 0x7fffffff, NOT String.hashCode
    scheduledDate: tz.TZDateTime.from(cuando, tz.getLocation('America/Bogota')),
    notificationDetails: const NotificationDetails(android: AndroidNotificationDetails(
        'citas', 'Recordatorios de citas', importance: Importance.high, priority: Priority.high)),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    title: titulo, body: cuerpo, payload: c.id);
}
```
Separate the **planning** (which citas, which instants, ids, texts: pure `List<NotificacionPlan> planificar(citas, minutosAntes, ahora)`) from the **plugin call** so the plan is unit-tested without the plugin. `reprogramar` is idempotent because it always starts with `cancelAll()` — safe because this app schedules no other notifications.

When to call `reprogramar()`: after the auth profile becomes available (cold start / login), on `AppLifecycleState.resumed`, after the lead-time setting changes, after any cita create/update/state change. Source of truth is Supabase; fetch pending/confirmed citas from now to +30 days (a dedicated repository method `proximas(desde, hasta)`, not the visible week). Reboot: the plugin's `ScheduledNotificationBootReceiver` re-registers alarms after reboot/app update [CITED: plugin README]; the resume-time resync is the second safety net (also covers OEM task killers). `cancelAll()` on sign-out: add a `ref.listen(authProfileProvider, ...)` that calls `cancelarTodo()` when the profile transitions to null (same listening pattern as `_AuthRefreshNotifier` in `app_router.dart`) — notification bodies contain client names (PII) and must not outlive the session on a shared phone.

Permission flow (D-13): after first successful cita save, if `!await permisoConcedido()` and the "rationale shown" flag (in `shared_preferences`) is unset → show UI-SPEC rationale dialog → `solicitarPermiso()`. If denied (or "Ahora no"), `NotificacionesBanner` shows whenever `!permisoConcedido()`; re-evaluate on `resumed` (user may flip it in Settings). After two denials Android stops showing the OS prompt, so the banner's "Activar" must call `abrirAjustes()` (`openAppNotificationSettings()`), not re-request. Reminders should still be scheduled even if permission is not yet granted? No — scheduling without permission is harmless but pointless; call `reprogramar` after a grant too (permission change via `resumed` handler).

Tap handling: `onDidReceiveNotificationResponse` → read `response.payload` (cita id) → navigate `router.push('/agenda/$id')`; cold-start taps via `getNotificationAppLaunchDetails()` checked once after the router/auth is ready (the callback does not fire for the launch notification) [CITED: plugin README]. Reach the router from a Riverpod provider (the `routerProvider`), not a global.

### Pattern 7: WhatsApp + Maps
```dart
// whatsapp_recordatorio.dart (pure)
Uri whatsappUri(String telefonoNormalizado, String mensaje) =>
    Uri.parse('https://wa.me/$telefonoNormalizado?text=${Uri.encodeComponent(mensaje)}');
Uri mapsUri(String direccion) => Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(direccion)}');
// launcher wrapper (injectable for tests)
Future<bool> abrirExterno(Uri u) async {
  try { return await launchUrl(u, mode: LaunchMode.externalApplication); }
  catch (_) { return false; }                         // -> snackbar "No pudimos abrir WhatsApp..."
}
```
- `wa.me` requires the number in international format with no `+`, spaces or leading zeros (`573001234567`), message URL-encoded. [CITED: WhatsApp click-to-chat docs, standard format; ASSUMED re-verified at implementation time — low risk]
- Use `Uri.encodeComponent`, not `Uri(queryParameters: ...)`: Dart's `queryParameters` encoding turns spaces into `+` (form encoding), and `wa.me` treats `+` literally in some clients. Add a unit test asserting `%20` and correct encoding of `á`, `—`, `SÍ`, `¿`/`?` and newlines. [ASSUMED Dart behavior from `Uri.encodeQueryComponent` docs; the test settles it]
- Call `launchUrl` directly in try/catch. `canLaunchUrl` on Android 11+ requires `<queries>` entries for each scheme or it returns false [CITED: pub.dev/packages/url_launcher]; skipping `canLaunchUrl` avoids needing manifest `<queries>` for https. Since the project's manifest already has a `<queries>` block (PROCESS_TEXT), you may optionally add `<intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>` if the planner chooses to use `canLaunchUrl`; recommended path is NOT to. Verify on a real device with and without WhatsApp installed (UAT).
- Return detection for the serial batch (D-15): in the batch sheet's state, mix in `WidgetsBindingObserver`; set `_esperandoRetorno = true` just before `launchUrl`; require the sequence `paused`/`hidden` → `resumed` while the flag is set, then mark the cita as sent (via `marcarRecordatorioEnviado(id, now)`) and advance to the next. A bare `resumed` without a preceding `paused/hidden` (e.g., a permission dialog) must not count. Always keep the manual fallback "Marcar como enviado" and "Cerrar" (UI-SPEC). Individual button (outside batch): mark immediately at launch with undo, per UI-SPEC.
- Phone gating: WhatsApp enabled only for `ClaseTelefono.celularCo` and `ClaseTelefono.internacional`; disabled with the exact UI-SPEC strings for fixed/unknown/empty.

### Pattern 8: Colombian phone normalizer (`lib/core/utils/telefono_co.dart`)
Facts [CITED: CRC dialing scheme effective 2021-12-01, via dplnews/El Universal/Portafolio search results; mobile 3XX prefixes widely documented]: mobile numbers are 10 digits starting with `3`; landlines are dialed as 10 digits `60` + 1-digit area code + 7 digits (`601` Bogotá, `602` Cali, `604` Medellín, `605`, `606`, `607`, `608`); country code `+57`; legacy 7/8-digit local landline numbers may still be stored by users.
Algorithm (pure, idempotent, unit-tested):
1. `raw.trim()`; keep a leading `+`; strip every non-digit otherwise. Empty → `vacio`.
2. Leading `+`: if digits start with `57` → treat the rest as a national number; else → `internacional`, return `'+' + digits` (kept with `+` so re-normalizing never misreads a foreign number as Colombian).
3. Leading `00`: drop it and treat as the `+` case (`0057...` → `57...`; `001...` → foreign).
4. No `+`: 12 digits starting `573` → mobile already (`celularCo`); 10 digits starting `3` → prefix `57` → `celularCo`; 10 digits starting `60` → `fijoCo` (store `57` + digits); 7 or 8 digits → `desconocido` (keep as typed digits, soft warning); 12 digits `5760...` → `fijoCo`; anything else (e.g. 11 digits not starting 57, 9 digits) → `desconocido` (keep digits, soft warning).
5. Output: `({String guardado, ClaseTelefono clase, String formateado})`; stored form = `573001234567` for Colombian numbers (D-16) and `+<digits>` for foreign; formatted display `+57 300 123 4567`; `esCelularColombianoPlausible` powers the blur-time soft warning ("Parece que este número no es un celular colombiano...").
Apply: on save in `NuevoClienteMascotaScreen` and cliente edit (D-16: normalize on save, never block), and again at WhatsApp time on legacy unnormalized rows (no data migration). `clientes.telefono` stays `text not null default ''`; empty string is "no phone".

### Pattern 9: Overlap + free slot (pure, `cita_solapes.dart`)
```dart
bool solapa(DateTime aIni, int aMin, DateTime bIni, int bMin) =>
    aIni.isBefore(bIni.add(Duration(minutes: bMin))) &&
    bIni.isBefore(aIni.add(Duration(minutes: aMin)));      // back-to-back (end == start) is NOT an overlap
DateTime primerHuecoLibre({required List<(DateTime ini, int min)> ocupados,
    required DateTime desde, required int duracionMin, DateTime? limite});
// steps of 15 min starting at roundUp15(desde) until no overlap; stop at limite (22:00) -> fall back to desde
```
Inputs come from the already-loaded day (week provider) excluding `cancelada` (UI-SPEC says "non-cancelled"; consider also excluding `no_asistio`, which also frees the slot — planner picks, document in the plan). When editing, exclude the cita being edited from `ocupados`. If the day is not in the loaded week (form opened for a far date), fetch that day on demand; on failure use the UI-SPEC fallback copy.

### Anti-Patterns to Avoid
- **Using `String.hashCode` (or `Object.hash`) for notification ids:** not stable across app runs/isolates; reschedule would orphan or duplicate alarms. Use a deterministic FNV-1a over the UUID string masked to 31 bits.
- **`DateTime.now()` / `toLocal()` for agenda days:** use `clockProvider` + `zona_bogota.dart`.
- **Using `Uri(queryParameters:)` for `wa.me`:** spaces become `+`.
- **Calling `plugin.initialize` on desktop/web dev runs:** the plugin throws `ArgumentError` when platform settings are missing; the repo scaffolds Windows/Linux/macOS (git status already shows regenerated plugin registrants). Guard: initialize/schedule only when `defaultTargetPlatform` is android (or iOS if you configure Darwin settings); otherwise the service is a no-op. In tests always use the fake.
- **Deleting citas:** cancelar replaces borrar; no delete RLS policy.
- **Adding a defaulted parameter to `registrar_consulta` without dropping the old function** (overload ambiguity).
- **Embedding mascota rows via `cita_mascotas` without the composite-FK hint when PostgREST reports ambiguity** — pin the relationship name.
- **Third accent CTA:** UI-SPEC permits exactly one accent CTA per screen; the batch sheet is its own surface.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Scheduling alarms/boot persistence | Custom AlarmManager/WorkManager Kotlin | `flutter_local_notifications` `zonedSchedule` + its boot/schedule receivers | Handles reboot re-registration, channels, tap payloads |
| Time-zone math | Manual offset arithmetic inside scheduling code | `timezone` `TZDateTime.from(utcInstant, America/Bogota)` for the plugin; `zona_bogota.dart` for UI only | The plugin requires `TZDateTime`; keep the one fixed-offset helper tiny and tested |
| Opening WhatsApp/Maps | Platform channels / intents | `url_launcher` `launchUrl(..., mode: externalApplication)` | Official; no permissions |
| Atomic cita+mascotas write | Two client-side inserts | `crear_cita` / `actualizar_cita` RPCs | Partial failure leaves a cita without mascotas; same rationale as `registrar_cliente_con_mascota` |
| Tenant isolation | Client-side `where clinica_id` checks | RLS + composite FKs | Project constraint |
| Calendar widgets | `table_calendar`/syncfusion | Hand-built `DayStrip` (7 cells) | Locked by D-08 |
| Per-device settings storage | A custom file/JSON store | `shared_preferences` | Already in the dependency graph |
| Instant client search | New search query code | existing `lib/core/data/busqueda.dart` `filtroOrIlike` + `clientesProvider` search | Phase 2 asset (UI-SPEC says reuse) |

**Key insight:** every "hard" part here (alarms across reboot, DST-free-but-device-tz-dependent day boundaries, URL encoding, composite-FK tenant integrity, atomic multi-row writes) already has a vetted primitive; the work is wiring plus a handful of small pure utilities that are cheap to unit-test and are where the bugs would otherwise live.

## Common Pitfalls

### Pitfall 1: Android build fails after adding the plugin (desugaring)
**What goes wrong:** `checkDebugAarMetadata` error requiring core library desugaring, or compileSdk too low.
**Why:** `flutter_local_notifications` >=10 requires `isCoreLibraryDesugaringEnabled = true` even if scheduling is unused [CITED: plugin README]. Project currently has Java 17 + Kotlin plugin 2.2.20 + AGP 8.11.1 + Gradle 8.14 and `compileSdk = flutter.compileSdkVersion` (= 36 for Flutter 3.41.4 [VERIFIED: FlutterExtension.kt read]); `minSdk = flutter.minSdkVersion` (= 24) satisfies the plugin's API 24 minimum.
**How to avoid:** edit `android/app/build.gradle.kts`: `defaultConfig { multiDexEnabled = true }`, `compileOptions { isCoreLibraryDesugaringEnabled = true; ...17 }`, `dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") }` (the project file currently has no `dependencies {}` block — add one). The README says plugin is built with AGP 9.1.1 and "aim for same at minimum" — but the 22.x CHANGELOG says AGP 8.11.1 (the README on `master` reflects the 23.0.0-dev line). **Risk to verify with a first `flutter build apk --debug`** (Wave 0 spike); if it fails on AGP version, report it rather than upgrading AGP blindly.
**Warning signs:** Gradle error mentioning `desugar_jdk_libs`, `minCompileSdk`, or `AGP version`; crash on Android 12L+ (README suggests adding `androidx.window:window:1.0.0` and `window-java` if it appears).

### Pitfall 2: Reminders never fire (manifest)
**What goes wrong:** `zonedSchedule` succeeds but nothing shows, or alarms vanish after reboot.
**Why:** Since plugin v16 the plugin's manifest only declares POST_NOTIFICATIONS and VIBRATE; the app must declare the receivers and boot permission.
**How to avoid:** in `AndroidManifest.xml` add `<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>` and inside `<application>` the two receivers (`com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver` and `...ScheduledNotificationBootReceiver` with BOOT_COMPLETED, MY_PACKAGE_REPLACED, QUICKBOOT_POWERON, `com.htc.intent.action.QUICKBOOT_POWERON`). Do NOT declare `SCHEDULE_EXACT_ALARM` or `USE_EXACT_ALARM`. Provide a small monochrome notification icon (`@mipmap/ic_launcher` works for `AndroidInitializationSettings`, but a proper drawable is the Android guidance). For release builds, check the plugin's ProGuard/R8 notes (README "Release build configuration") — project release currently signs with debug keys and has no shrinker config; flag for the distribution phase.

### Pitfall 3: Inexact delivery is late
`setAndAllowWhileIdle` may deliver minutes late under Doze/OEM battery policies; some OEMs (Xiaomi/Huawei/etc.) kill background scheduling entirely [CITED: plugin README "Some Android OEMs restrict background app execution"]. Mitigations already in the design: the 15-120 min lead, resume-time resync, and the in-app "Próxima" banner. Do not promise exact timing in copy. Treat delivery under Doze as a **manual device check**, not an automated test.

### Pitfall 4: Spanish/`es_CO` formatting silently fails or renders in English
**What goes wrong:** `DateFormat('EEE', 'es_CO')` throws `LocaleDataException` (the app never calls `initializeDateFormatting` — `formato.dart` header documents this); `showDatePicker` shows English month/day names because `MaterialApp.router` has no `locale`/`localizationsDelegates`; `intl`'s `a. m.` output may contain non-breaking/narrow spaces that break string equality in tests and look odd in WhatsApp.
**How to avoid:** (a) hand-write `formato_hora.dart` using const Spanish lists (`['lun','mar','mié','jue','vie','sáb','dom']`, months) and a plain "h:mm a. m." builder with a normal space — deterministic, no locale init, same approach as `formatearFecha`; (b) add `flutter_localizations` + `localizationsDelegates: GlobalMaterialLocalizations.delegates`, `supportedLocales: [Locale('es','CO')]`, `locale: Locale('es','CO')` in `VetApp` so `showDatePicker`, `DatePickerDialog` "Aceptar/Cancelar" and tooltips are Spanish. Check `test/app_theme_test.dart`/`widget_test` for impact (harness builds its own `MaterialApp.router` — add the same locale options to `routerHarness` only if a test opens a date picker).

### Pitfall 5: Notification id collisions or orphans
Use FNV-1a (32-bit, masked `& 0x7fffffff`) over the UUID string. Collision probability for tens of notifications is negligible; because `reprogramar` starts with `cancelAll()` any theoretical collision self-heals on next resync. Never use `Object.hashCode`/`String.hashCode`. Unit-test determinism with a fixed uuid → fixed int.

### Pitfall 6: Scheduling in the past / far future
`zonedSchedule` rejects dates not in the future in some plugin versions. Filter `cuando.isAfter(ahora)`; cap the horizon (30 days, ≤60 items — also keeps iOS under its 64 pending limit if iOS is enabled later). Ignore estados other than pendiente/confirmada.

### Pitfall 7: Mascota-owner mismatch and FK target
Without `unique (id, clinica_id)` on `mascotas`, the `cita_mascotas` composite FK creation fails (`there is no unique constraint matching given keys`). Add the constraint first (idempotent `do $$` block, as Fase 2 does for clientes). Same-owner is not enforceable via FK — RPC + smoke test. Existing UI copy for that failure: "El cliente o la mascota no existe en tu clínica."

### Pitfall 8: Day-strip counts and "Hoy" drift
Count only non-cancelled citas (UI-SPEC). Compute the week's UTC bounds from the Bogota Monday; a cita at 11:30 p.m. Bogota is 04:30 UTC next day — queries by UTC calendar date would put it in the wrong day. Include a test with 23:30 and 00:15 Bogota boundary cases.

### Pitfall 9: Provider autoDispose + undo races
`Deshacer` must restore the previous estado even if the provider was disposed/recreated; capture `(id, estadoAnterior)` in the snackbar closure, and make `cambiarEstado` idempotent (update by id). Only the latest change is undoable (UI-SPEC).

### Pitfall 10: Router `extra` lost on rebuild
Pass `clienteId`/`mascotaId` as query parameters for `/agenda/nueva` rather than `extra` (survives restoration and is testable with the router harness); return values from the combined-alta use `context.pop(result)` with `await context.push<T>(...)`.

### Pitfall 11: Existing tests that pin behavior
`MasScreen` currently shows "Próximamente" + sign-out; `inicio_screen_test`, `widget_test` may reference the `/agenda` placeholder text. Run `flutter test` after replacing the placeholder and adding the Recordatorios row; update expectations in the same plan.

## Code Examples

### Stable notification id (pure Dart)
```dart
int idNotificacion(String citaId) {
  var h = 0x811c9dc5;                       // FNV-1a 32-bit
  for (final c in citaId.codeUnits) { h ^= c; h = (h * 0x01000193) & 0xffffffff; }
  return h & 0x7fffffff;                    // positive 31-bit, fits Android int id
}
```
(Pattern source: FNV-1a standard; plugin `id` is `int`.) [ASSUMED correctness of masking is trivial; covered by a unit test.]

### WhatsApp message (D-14, hand-formatted)
```dart
String mensajeRecordatorio({required String cliente, required List<String> mascotas,
    required DateTime inicioBogota, required bool domicilio, String? direccion,
    required String veterinario, required String clinica}) {
  final donde = domicilio ? 'a domicilio en $direccion' : 'en el consultorio';
  return 'Hola $cliente, le recordamos la cita de ${unirNombres(mascotas)} el '
      '${diaCorto(inicioBogota)} a las ${hora12(inicioBogota)} $donde. '
      '— $veterinario, $clinica. Responda SÍ para confirmar.';
}
// unirNombres: ['Luna'] -> 'Luna'; ['Luna','Rocky'] -> 'Luna y Rocky'; 3+ -> 'Luna, Rocky y Max'
```

### Android manifest additions
```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<!-- inside <application> -->
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
  <intent-filter>
    <action android:name="android.intent.action.BOOT_COMPLETED"/>
    <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
    <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
    <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
  </intent-filter>
</receiver>
```
Source: plugin README "AndroidManifest.xml setup" (fetched from GitHub master during this research).

### Test double for notifications / launcher (inject via Riverpod override)
```dart
class FakeRecordatoriosService implements RecordatoriosService {
  final List<NotificacionPlan> programadas = [];
  bool permiso = true; int cancelarTodoLlamadas = 0;
  @override Future<void> reprogramar(List<Cita> c, int m) async { programadas..clear()..addAll(planificar(c, m, ahora)); }
  @override Future<void> cancelarTodo() async => cancelarTodoLlamadas++;
  // ...
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Positional args in `zonedSchedule`/`initialize`/`show`/`cancel` | Named, required params (`id:`, `scheduledDate:`, `notificationDetails:`, `androidScheduleMode:`) | plugin v20.0.0 | Training-data/README snippets showing positional calls will not compile; copy signatures from v22.3.1 |
| `uiLocalNotificationDateInterpretation` param | Removed | v19.0.0 | Do not pass it |
| `androidAllowWhileIdle: bool` | `AndroidScheduleMode` enum | v16-17 era | Use `inexactAllowWhileIdle` |
| Plugin declared all permissions | Only POST_NOTIFICATIONS + VIBRATE; app adds boot perms/receivers | v16.0.0 | Manifest edit required |
| Exact alarms assumed available | Denied by default on Android 14+ (non-alarm/calendar apps); `USE_EXACT_ALARM` store-reviewed | Android 14 | Use inexact |
| `requestPermission()` | `requestNotificationsPermission()`; new `openAppNotificationSettings()` | v16.0.0 / v22.3.0 | Use for banner "Activar" |
| Desugaring optional | Required for the plugin on Android | v10.0.0 | Gradle edit |

**Deprecated/outdated:**
- `flutter_native_timezone`: replaced by `flutter_timezone`; neither needed here (fixed Bogota).
- `23.0.0-dev.*` plugin line: needs Flutter 3.44 / Dart 3.12 / compileSdk 37 / AGP 9.1.1 — project is pinned lower (see the `pdf`/`printing` pins in `pubspec.yaml` for the same Dart ceiling issue).

## Runtime State Inventory

Not a rename/refactor/migration phase — omitted. (One data note: existing `clientes.telefono` values are free text and are NOT migrated per D-16; normalization applies at save and at use time.)

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | PostgREST embeds through the composite FK (`clientes(...)`, `cita_mascotas(mascotas(...))`) work without a relationship hint; otherwise use `clientes!citas_cliente_misma_clinica_fkey(...)` | Pattern 4 | A repository query fails at runtime; fix = add the hint. Verify in first live smoke run |
| A2 | Dart `Uri(queryParameters:)` encodes spaces as `+` and `wa.me` mishandles it; `Uri.encodeComponent` (%20) is safe | Pattern 7 | Message text garbled in WhatsApp; unit test + device test settle it |
| A3 | `launchUrl` (without `canLaunchUrl`) for https links needs no `<queries>` manifest entry on Android 11+ | Pattern 7 | Launch fails on some devices; fallback: add the https `<queries>` intent |
| A4 | Plugin 22.3.1 builds with this project's AGP 8.11.1 despite the master README saying "AGP 9.1.1 at minimum" (CHANGELOG says 22.x uses AGP 8.11.1; 9.1.1 is the 23.0.0-dev change) | Pitfall 1 | Gradle build error; Wave 0 `flutter build apk --debug` spike confirms |
| A5 | America/Bogota remains UTC-5 with no DST | Pattern 5 | Wrong day boundaries/reminder times if Colombia ever adopts DST; low probability |
| A6 | Inexact allow-while-idle alarms are typically delivered within minutes of target under Doze | Pitfall 3 | Late reminders; mitigated by lead time, resync, and in-app banner; verify on device |
| A7 | `cita_mascotas`/`citas` `ON DELETE CASCADE` from `clientes` is acceptable (consistent with `mascotas`) | Pattern 1 | Deleting a cliente deletes its appointments; confirm with user if undesirable |
| A8 | `no_asistio` should free the slot for overlap/free-slot purposes (UI-SPEC only says non-cancelled) | Pattern 9 | Minor UX: false overlap warnings; planner decides |
| A9 | `shared_preferences` major version locked transitively is compatible with direct promotion | Standard Stack | `flutter pub add shared_preferences` resolves to the locked version; trivial |
| A10 | wa.me format (international number, no `+`, no leading zeros, URL-encoded text) | Pattern 7 | Wrong links; widely documented |

## Open Questions

1. **Does PostgREST need the relationship hint for composite-FK embeds?**
   - Known: `mascotas` uses composite FK to `clientes` today; existing repositories select `mascotas` with owner data (not verified in this session to use embeds).
   - Unclear: behavior with two embeds and a composite FK in the live project.
   - Recommendation: Task 1 of the repository plan = write the week query, run it against the live project (or `vetapp-supabase` verifies via REST), fall back to two simple queries or hint syntax.
2. **Android build with AGP 8.11.1 + plugin 22.3.1?**
   - Recommendation: Wave 0 spike `flutter build apk --debug` after the Gradle/manifest edits, before building any scheduling logic.
3. **iOS/desktop targets:** project scaffolds all platforms but VetApp's users are on Android phones. Recommendation: support Android only in this phase; notification service no-ops on other platforms; document iOS Darwin init as a follow-up.
4. **Cascade policy on `clientes` delete** (A7) — default to cascade for consistency; user may prefer `restrict` for citas.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | everything | yes | 3.41.4 stable (Dart ^3.11.1 compatible) | — |
| pub.dev access | `flutter pub add` | yes (`pub add --dry-run` resolved) | — | — |
| Android toolchain (Gradle 8.14, AGP 8.11.1, compileSdk 36) | notifications build | configured in repo (not built in this session) | — | Wave 0 build spike |
| Supabase project (live) | RLS smoke, repository checks | stated available in prior phases (schema applied manually via SQL Editor) | — | Fakes for UI tests; SQL applied by user (human step) |
| slopcheck | package audit | no | — | All four packages are official/high-usage or already in `pubspec.lock` |
| Physical Android device (13+) with and without WhatsApp | UAT of permission prompt, Doze delivery, wa.me, boot reschedule | unknown | — | Emulator covers permission/schedule basics; WhatsApp/Doze/boot need a real device |
| Node (for `verify_live_schema.sh`) | live schema check | yes (used in this session) | — | — |

**Missing dependencies with no fallback:** none blocking planning. Applying `supabase/schema.sql` to the cloud project is a **human step** (per `.claude/LOOPING.md`).
**Missing dependencies with fallback:** slopcheck (see Package Legitimacy Audit).

## Validation Architecture

> `workflow.nyquist_validation: true` in `.planning/config.json`.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (SDK) + Riverpod overrides; existing `test/helpers/{fake_*.dart, router_harness.dart}`; SQL smoke test `supabase/tests/rls_smoke_test.sql` (manual, run in Supabase SQL Editor, always ends with a rollback exception `RLS SMOKE: PASS/FAIL`) |
| Config file | none (default `flutter test`); lints via `analysis_options.yaml` |
| Quick run command | `flutter test test/<file>_test.dart` |
| Full suite command | `flutter analyze && flutter test` (the `vetapp-gate` agent runs analyze+test and returns `GATE: GREEN/RED/BLOCKED`) |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AGND-01 | Week bounds from Bogota Monday; 23:30/00:15 boundary; non-cancelled counts per day | unit | `flutter test test/zona_bogota_test.dart` | Wave 0 |
| AGND-01 | DayStrip shows counts/selection, opens on Hoy, week navigation, empty/error/loading states, "Próxima" banner (fake clock) | widget | `flutter test test/agenda_screen_test.dart` | Wave 0 |
| AGND-01 | RLS: vet A does not see vet B's citas/cita_mascotas; CLIENTE role sees 0 | SQL smoke | run `rls_smoke_test.sql` (expect `RLS SMOKE: PASS`) | extend existing |
| AGND-02 | `crear_cita` atomic with N mascotas; rejects mascota of another cliente/clínica; cross-clinic FK violation; domicilio requires dirección | SQL smoke | `rls_smoke_test.sql` | extend existing |
| AGND-02 | Cita form: required fields gate "Guardar cita", motivo -> default duration, domicilio prefill/validation, overlap dialog, first-free-slot, combined-alta return mode | widget + unit | `flutter test test/cita_form_screen_test.dart test/cita_solapes_test.dart` | Wave 0 |
| AGND-02 | Overlap/free-slot pure functions (back-to-back, edit-excludes-self, cancelled ignored, rounding to 15) | unit | `flutter test test/cita_solapes_test.dart` | Wave 0 |
| AGND-03 | Estado transitions via buttons, Deshacer restores previous estado, cancel confirmation dialog, reopen | widget/provider | `flutter test test/cita_actions_test.dart` | Wave 0 |
| AGND-03 | `estado` check rejects invalid values; `solicitada` accepted by DB but not exposed | SQL smoke | `rls_smoke_test.sql` | extend existing |
| AGND-04 | Plan builder: only pendiente/confirmada, future, lead-time applied, horizon cap, deterministic ids, texts | unit | `flutter test test/recordatorios_plan_test.dart` | Wave 0 |
| AGND-04 | Service orchestration with fake: reprogramar after create/edit/estado/setting change; `cancelarTodo` on sign-out; permission banner + rationale flow | provider/widget | `flutter test test/recordatorios_providers_test.dart` | Wave 0 |
| AGND-04 | Real notification at T-lead, after reboot, after Doze, tap opens detail, POST_NOTIFICATIONS prompt | manual device | see manual checks | n/a |
| AGND-05 | Phone normalizer (celular, 57-prefixed, +/00 foreign, fijo 60X, 7-digit, empty; idempotent) | unit | `flutter test test/telefono_co_test.dart` | Wave 0 |
| AGND-05 | Message template (D-14) exact text for 1/2/3+ mascotas, consultorio vs domicilio; `wa.me` URL encodes `%20`, `á`, `—`, `?`; disabled states; batch sheet state machine with fake launcher + lifecycle events | unit/widget | `flutter test test/whatsapp_recordatorio_test.dart test/recordar_manana_sheet_test.dart` | Wave 0 |
| AGND-05 | WhatsApp really opens with prefilled text; return detection | manual device | see manual checks | n/a |
| AGND-06 | `registrar_consulta` with `p_cita_id`: links, rejects mascota not in cita, second consulta same (cita,mascota) -> unique violation, append-only still holds (update/delete 0 rows) | SQL smoke | `rls_smoke_test.sql` | extend existing |
| AGND-06 | Completar flow per mascota (registrar/omitir/finalizar/completar sin consulta, Deshacer reverts only estado); ConsultaFormScreen with `citaId` prefill + link pill; existing consulta tests still pass with new RPC param | widget | `flutter test test/completar_cita_screen_test.dart test/consulta_form_screen_test.dart test/consultas_providers_test.dart` | new + existing |

### Sampling Rate
- **Per task commit:** the single relevant `flutter test test/<file>_test.dart` (< 30 s) + `dart analyze` on touched files
- **Per wave merge:** `flutter analyze && flutter test` (full suite) via `vetapp-gate`; SQL waves also run `rls_smoke_test.sql` via `vetapp-supabase` (human applies schema to the cloud project first)
- **Phase gate:** full suite green, `RLS SMOKE: PASS`, `vetapp-brand-ui` audit, then device UAT before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/helpers/fake_citas.dart`, `fake_recordatorios.dart`, `fake_url_launcher.dart` (abstraction around `launchUrl` so widgets are testable) — mirror `fake_consultas.dart` shape (fixed data or fixed error + call log)
- [ ] `test/zona_bogota_test.dart`, `telefono_co_test.dart`, `cita_solapes_test.dart`, `whatsapp_recordatorio_test.dart`, `recordatorios_plan_test.dart` (pure Dart, no Flutter bindings)
- [ ] Router harness reuse: `routerHarness` + overrides; add `Locale es_CO` + localization delegates only for tests that open the date picker
- [ ] `supabase/tests/rls_smoke_test.sql`: new sections (suggested ids `J*`..`M*`): cross-clinic select of `citas`/`cita_mascotas`; insert with foreign clinica/cliente (composite FK); `crear_cita` mascota-of-other-owner rejection; CLIENTE role gets 0 rows/`insufficient_privilege`; `estado` check; no delete policy (delete = 0 rows); `registrar_consulta(p_cita_id)` link + unique violation + wrong-mascota rejection; update `consultas` still 0 rows
- [ ] Android build spike (`flutter build apk --debug`) after Gradle/manifest changes

**Manual device checks (cannot be automated):**
1. Android 13+: first cita -> rationale dialog -> OS prompt; deny twice -> banner "Activar" opens system settings; grant -> banner disappears on return.
2. Create a cita 17 min out with 15-min lead -> notification arrives (allow minutes of slack); tap opens `/agenda/:id`; cold-start tap works.
3. Reboot with a pending reminder -> still fires (boot receiver) and app-open resync leaves no duplicates (`pendingNotificationRequests()` count equals expected).
4. Sign out -> no reminders fire afterwards.
5. WhatsApp individual button: opens chat with exact text; with WhatsApp not installed -> snackbar fallback; fixed-line number -> disabled with explanation.
6. "Recordar a todos los de mañana" with 3 clients: serial flow marks each as sent on return; manual fallback works.
7. "Cómo llegar" opens Google Maps with destination address.
8. Phone in a non-Bogota device timezone (e.g., set device to UTC) -> day boundaries and reminder times still Bogota.

## Security Domain

> `security_enforcement` is not set to false in config -> included.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no (unchanged) | existing Supabase Auth |
| V3 Session Management | yes (notifications must not outlive session) | `cancelAll()` on sign-out; no PII persisted outside Supabase except the OS notification payload (cita id only) |
| V4 Access Control | yes | RLS on `citas`/`cita_mascotas` (`es_veterinario()` + `clinica_id = mi_clinica_id()`), composite FKs, RPC guards for cliente-mascota ownership and cita-mascota membership; no delete policy |
| V5 Input Validation | yes | DB `check` constraints (estado, modalidad, duracion, domicilio-direccion), RPC guards, trimmed text, `Uri.encodeComponent` for outbound URLs, existing `sanitizarBusqueda` for search |
| V6 Cryptography | no | none hand-rolled |
| V8 Data Protection (client PII) | yes | Notification body contains client/pet names (shown on lock screen) — keep payload to the cita id, consider `visibility: private` for the Android notification so lock-screen content can be hidden; phone numbers only sent to WhatsApp via user-initiated deep link |

### Known Threat Patterns for Flutter + Supabase + Android

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Cross-tenant read/write of citas | Information disclosure / Tampering | RLS + composite `(x_id, clinica_id)` FKs; smoke-test negative cases for both vets |
| Attaching a mascota of another owner/clinic to a cita | Tampering | `crear_cita`/`actualizar_cita` ownership guard + `cita_mascotas` composite FK |
| Linking a consulta to a foreign cita | Tampering | `registrar_consulta` verifies `(cita_id, mascota_id)` membership in the caller's clinic |
| Privilege escalation via direct table insert bypassing RPC | Elevation | RLS insert policy requires `es_veterinario()` and own `veterinario_id`; `security invoker` RPCs (RLS still applies) |
| Query-filter injection through client search text | Tampering | existing `sanitizarBusqueda`/`filtroOrIlike` |
| URL/intent injection via client name/address in `wa.me`/Maps link | Tampering | percent-encode every dynamic component; fixed host; `externalApplication` mode |
| PII left in OS notification tray after logout | Information disclosure | `cancelAll()` on sign-out; private lock-screen visibility |
| Exported component abuse | Spoofing | plugin receivers declared `android:exported="false"` (boot receiver is invoked by the system only) |

## Project Constraints (from CLAUDE.md)

- Stack fixed: Flutter + Supabase; backend real (no mocks in production paths); Colombia (COP, dd/mm/aaaa, es-CO copy); visual identity = approved mockup (terracotta/cream, Caprasimo + Figtree), no generic Material 3.
- Naming: Spanish domain terms (`Cita`, `Cliente`, `Mascota`), English for framework plumbing; files `snake_case.dart`; usecase-like classes are imperative verb phrases without `UseCase` suffix; single `call()`; no barrel files; relative imports inside `lib/`.
- Error handling: data layer translates `PostgrestException` to a feature `*Failure` with Spanish messages (specific `on` branch + generic catch-all); presentation catches only the Failure type; add new mappings to the single `_messageFor`.
- Doc comments (`///`) for domain entities/repositories/shared widgets (explain why, not what); skip for private states and one-off screen sections; use `[Identifier]` links.
- `const` aggressively; `flutter_lints` defaults authoritative, do not disable rules.
- Domain layer note: existing features use concrete `Supabase*Repository` without domain interfaces — follow the Phase 2/3 convention (concrete repository + test fakes `implements` it), not the abandoned `AuthRepository` interface idea. The only new interface recommended is `RecordatoriosService` (needed to keep the plugin out of tests).
- Edits must go through a GSD workflow (`/gsd-execute-phase` etc.).
- **Project agents (see `.claude/LOOPING.md`):** use `vetapp-supabase` for the schema/RLS/RPC plan and the `rls_smoke_test.sql` extension (it edits `schema.sql`; never let two agents edit `schema.sql`, `app_router.dart` or `STATE.md` in parallel); `vetapp-gate` at the end of every plan (analyze + test + minimal fix, `GATE: GREEN/RED/BLOCKED`, usable inside `/loop` with a stop condition); `vetapp-brand-ui` after the new screens (Agenda, form, detail, completar, recordatorios) and before `/gsd-verify-work`. Suggested fan-out: SQL slice (worktree A, `vetapp-supabase`) in parallel with pure-Dart utilities + UI slice on fakes (worktree B); applying SQL to the cloud project and device UAT stay human steps.
- Project skills in `.claude/skills/` are design/marketing oriented (banner-design, brand, design, slides, ui-styling, ui-ux-pro-max); none apply to the Flutter implementation beyond the already-approved `04-UI-SPEC.md`.

## Sources

### Primary (HIGH confidence)
- pub.dev API (`/api/packages/flutter_local_notifications`, `timezone`, `url_launcher`, `flutter_timezone`) - versions, publish dates, Dart/Flutter constraints (fetched 2026-09-30)
- `flutter_local_notifications-22.3.1` archive source (`lib/src/flutter_local_notifications_plugin.dart`, `platform_flutter_local_notifications.dart`) - exact `zonedSchedule`, `cancelAll`, `initialize`, `areNotificationsEnabled`, `requestNotificationsPermission`, `pendingNotificationRequests` signatures
- Plugin CHANGELOG (github.com/MaikuB/flutter_local_notifications) - 20.0.0 named params, 21.0.0 compileSdk 36/Dart 3.10/API 24, 22.3.0 `openAppNotificationSettings`, 23.0.0-dev.1 requires Dart 3.12/AGP 9.1.1/compileSdk 37
- Plugin README (master) - Gradle desugaring, manifest receivers, POST_NOTIFICATIONS, scheduling/timezone usage, launch-details note
- Repository reads: `supabase/schema.sql`, `supabase/tests/rls_smoke_test.sql`, `lib/core/router/app_router.dart`, `lib/features/clinical_history/**`, `lib/features/clients/**`, `lib/core/utils/formato.dart`, `android/app/build.gradle.kts`, `AndroidManifest.xml`, `pubspec.yaml/lock`, Flutter `FlutterExtension.kt` (compileSdk 36, minSdk 24)
- `flutter pub add --dry-run` (dependency resolution proof)
- developer.android.com/about/versions/14/changes/schedule-exact-alarms - exact-alarm permission policy
- pub.dev/packages/url_launcher - `<queries>` requirement for `canLaunchUrl`

### Secondary (MEDIUM confidence)
- Web search results on CRC Colombian numbering reform (dplnews, El Universal 2021-06-11, Portafolio, Noticias Caracol, El Colombiano): 10-digit dialing, `60` + area code (601 Bogotá, 602 Cali, 604 Medellín, 606 Pereira), mobiles 3XX

### Tertiary (LOW confidence)
- Dart `Uri` `+` space encoding and wa.me treatment (A2), launchUrl without `<queries>` (A3), Doze delay magnitude (A6) - to be settled by unit/device tests

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - versions, constraints, signatures verified from pub.dev API/source; dry-run resolves
- Architecture: HIGH for schema/RLS/RPC patterns (mirror shipped code); MEDIUM for PostgREST embed shape and AGP compatibility (A1, A4)
- Pitfalls: HIGH for Android setup/known plugin behavior; MEDIUM for OEM/Doze behavior and WhatsApp return detection (device-dependent)

**Research date:** 2026-09-30
**Valid until:** 2026-10-30 for plugin versions (fast-moving 23.x dev line exists; stay on `^22.3.1`); schema/architecture guidance stable
