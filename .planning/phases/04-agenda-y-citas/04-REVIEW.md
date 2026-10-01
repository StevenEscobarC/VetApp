---
phase: 04-agenda-y-citas
reviewed: 2026-10-01T00:00:00Z
depth: standard
files_reviewed: 36
files_reviewed_list:
  - supabase/schema.sql
  - supabase/tests/rls_smoke_test.sql
  - lib/core/data/clock_provider.dart
  - lib/core/router/app_router.dart
  - lib/core/utils/formato_hora.dart
  - lib/core/utils/lanzador_externo.dart
  - lib/core/utils/telefono_co.dart
  - lib/core/utils/zona_bogota.dart
  - lib/core/widgets/status/app_status_chip.dart
  - lib/features/appointments/data/repositories/supabase_cita_repository.dart
  - lib/features/appointments/data/services/recordatorios_service.dart
  - lib/features/appointments/domain/cita_failure.dart
  - lib/features/appointments/domain/cita_solapes.dart
  - lib/features/appointments/domain/entities/cita.dart
  - lib/features/appointments/domain/motivos_cita.dart
  - lib/features/appointments/domain/recordatorios_plan.dart
  - lib/features/appointments/domain/whatsapp_recordatorio.dart
  - lib/features/appointments/presentation/agenda_routes.dart
  - lib/features/appointments/presentation/providers/citas_providers.dart
  - lib/features/appointments/presentation/providers/recordatorios_providers.dart
  - lib/features/appointments/presentation/screens/agenda_screen.dart
  - lib/features/appointments/presentation/screens/cita_detail_screen.dart
  - lib/features/appointments/presentation/screens/cita_form_screen.dart
  - lib/features/appointments/presentation/screens/completar_cita_screen.dart
  - lib/features/appointments/presentation/widgets/cita_acciones.dart
  - lib/features/appointments/presentation/widgets/cita_card.dart
  - lib/features/appointments/presentation/widgets/recordar_manana_sheet.dart
  - lib/features/appointments/presentation/widgets/time_stepper.dart
  - lib/features/clients/presentation/screens/cliente_detail_screen.dart
  - lib/features/clients/presentation/screens/nuevo_cliente_mascota_screen.dart
  - lib/features/clinical_history/data/repositories/supabase_consulta_repository.dart
  - lib/features/clinical_history/presentation/providers/consultas_providers.dart
  - lib/features/clinical_history/presentation/screens/consulta_form_screen.dart
  - lib/features/home/presentation/screens/mas_screen.dart
  - lib/features/patients/presentation/screens/mascota_detail_screen.dart
  - lib/main.dart
findings:
  critical: 0
  high: 2
  medium: 6
  low: 6
  warning: 8
  info: 6
  total: 14
status: issues_found
---

# Phase 4: Code Review Report

**Reviewed:** 2026-10-01
**Depth:** standard
**Files Reviewed:** 36 of 73 in the diff (`git diff --name-only aff72c0 HEAD -- lib test supabase`). The full list is in the frontmatter. Test files were read only where they affect reliability. The small presentational widgets (`day_strip`, `cita_card`, banners, `mascota_multi_select`, `cliente_search_field`) got a skim only.
**Status:** issues_found

Severity mapping: `critical` = BLOCKER; `high` and `medium` = WARNING (counted under `warning`); `low` = Info.

## Summary

There is no cross-tenant read or write bypass. Every new policy scopes `citas` and `cita_mascotas` by `es_veterinario() and clinica_id = mi_clinica_id()`. The composite `(x_id, clinica_id)` FKs pin bridge rows to one clinic. The RPCs are `security invoker` and grant execute only to `authenticated`.

The main problem is that the **same-owner and cita-membership invariants exist only inside the RPCs.** The RLS policies still allow direct table writes that skip them. That contradicts the threat model in 04-RESEARCH §Security Domain, which lists those RPC guards as the mitigation. The other big issue is a new `on delete cascade` on `citas.veterinario_id` that can wipe a clinic's agenda.

The Dart side has these problems:

- One mistranslated error. Removing a pet that already has a consulta tells the user "Elige al menos una mascota".
- A sign-out race that can re-schedule notifications containing client names after the session ends.
- Phone normalization can silently save a required phone as an empty string.
- The completar flow and the server let a cancelled or no-show cita become "completada".

## Critical Issues

None.

## Warnings

### HI-01 (high): Direct table writes bypass the RPC same-owner and cita-membership guards

**File:** `supabase/schema.sql:617-620` (`citas_update`), `:629-631` (`cita_mascotas_insert`), `:511-519` (`consultas_insert`, which now has a writable `cita_id`, `:596`)

**Issue:** `crear_cita`, `actualizar_cita` and `registrar_consulta` are `security invoker`, so the caller already has the same table privileges the RPC uses. Any vet can call PostgREST directly and break each guard:

1. `insert into cita_mascotas (cita_id, mascota_id, clinica_id)` with a pet owned by a **different client** of the same clinic. The policy only checks `clinica_id`, so the owner guard in `crear_cita` and `actualizar_cita` is bypassed.
2. `update citas set cliente_id = <other client>`. The `citas_update` policy places no column restriction. This leaves `cita_mascotas` pointing at another owner's pets, and the WhatsApp reminder then goes to the wrong person with the wrong pets. The same path allows any `estado` transition, including `completada -> pendiente`, `cancelada -> completada`, and the reserved `'solicitada'`. It can also rewrite `fecha_hora` on a terminal cita, which `actualizar_cita` explicitly forbids.
3. `insert into consultas (..., cita_id)` through the `consultas_insert` policy with **any** `cita_id`. The FK is single-column (`references citas(id)`), and FK checks ignore RLS, so the cita can even belong to **another clinic**. This skips the membership guard at `:838-847`.

The research threat table ("Attaching a mascota of another owner", "Linking a consulta to a foreign cita") claims these are mitigated, but they are not. The smoke test has no negative cases for these direct-write paths.

**Fix:**
```sql
-- 1) cita_mascotas: enforce same owner in the policy
create policy cita_mascotas_insert on public.cita_mascotas for insert to authenticated
with check (
  public.es_veterinario() and clinica_id = public.mi_clinica_id()
  and exists (
    select 1 from public.citas c join public.mascotas m on m.id = cita_mascotas.mascota_id
    where c.id = cita_mascotas.cita_id and m.dueno_id = c.cliente_id
  )
);

-- 2) citas: freeze immutable columns + state machine in a BEFORE UPDATE trigger
create or replace function public.citas_guardar_update() returns trigger
language plpgsql as $$
begin
  if new.cliente_id <> old.cliente_id or new.clinica_id <> old.clinica_id
     or new.veterinario_id <> old.veterinario_id then
    raise exception 'No se puede cambiar el cliente de la cita.' using errcode = 'check_violation';
  end if;
  if new.estado = 'solicitada' and old.estado <> 'solicitada' then
    raise exception 'Estado no permitido.' using errcode = 'check_violation';
  end if;
  -- (optionally) restrict fecha_hora/duracion/... edits when old.estado is terminal
  return new;
end $$;

-- 3) consultas.cita_id: make the FK clinic-scoped or validate in consultas_insert
--    e.g. add to consultas_insert WITH CHECK:
--    and (cita_id is null or exists (select 1 from public.cita_mascotas cm
--         where cm.cita_id = consultas.cita_id and cm.mascota_id = consultas.mascota_id
--           and cm.clinica_id = public.mi_clinica_id()))
```
Add negative smoke-test cases for each of the three paths.

### HI-02 (high): Deleting a vet's auth user cascades away the clinic's appointments

**File:** `supabase/schema.sql:546`

**Issue:** `veterinario_id uuid not null references auth.users(id) on delete cascade`. In a multi-vet clinic, removing one vet's account (offboarding, or deleting a duplicated account) silently **deletes every cita that vet created**. Their `cita_mascotas` rows cascade with them, and the linked consultas lose their `cita_id` through `on delete set null`. This contradicts the design rule "cancelar es un cambio de estado, nunca un borrado" and D-20, which only allows a cascade from the client.

**Fix:** Use `on delete restrict`, or make the column nullable with `on delete set null` so the appointment history survives:
```sql
veterinario_id uuid references auth.users(id) on delete set null,
```
For an existing deployment, the constraint has to be dropped and re-added in the idempotent delta.

### ME-01 (medium): Removing a pet that has a consulta shows "Elige al menos una mascota."

**File:** `lib/features/appointments/data/repositories/supabase_cita_repository.dart:214-223`; `lib/features/appointments/presentation/screens/cita_form_screen.dart:475-486`

**Issue:** `actualizar_cita` raises `23514` with the message "No puedes quitar una mascota que ya tiene consulta registrada en esta cita." `_messageFor` checks `m.contains('mascota')` before anything more specific, so the user sees "Elige al menos una mascota.", even though one or more pets are still selected. The form also does not disable pets in `cita.mascotasConConsulta`, so this error path is easy to reach.

**Fix:**
```dart
case '23514':
  final m = e.message.toLowerCase();
  if (m.contains('domicilio')) return 'Escribe la dirección para la visita a domicilio.';
  if (m.contains('ya tiene consulta')) {
    return 'No puedes quitar una mascota que ya tiene consulta registrada en esta cita.';
  }
  if (m.contains('al menos una mascota')) return 'Elige al menos una mascota.';
  ...
```
Also, in edit mode, pass `mascotasConConsulta` into `MascotaMultiSelect` and lock those checkboxes.

### ME-02 (medium): Reminders containing client names can be re-scheduled after sign-out

**File:** `lib/features/appointments/presentation/providers/recordatorios_providers.dart:104-109, 168-181`

**Issue:** Sign-out calls `cancelarTodo()`, but a `sincronizar()` run may already be in flight. `_una()` reads the profile at line 170, then awaits the permission check and `entre(...)`, then calls `servicio.reprogramar(...)`. If sign-out lands during those awaits, `cancelAll()` runs first and `reprogramar` then schedules up to 60 notifications with client and pet names (`cuerpoRecordatorio`) for a signed-out device. This defeats the mitigation listed in the research doc ("PII left in OS notification tray after logout").

**Fix:** Re-check the session immediately before scheduling, and make sign-out serialize behind the in-flight run:
```dart
final citas = await _ref.read(citaRepositoryProvider).entre(...);
final sigue = _ref.read(authProfileProvider).value;
if (sigue?.id != perfil.id || !sigue!.esVeterinario) return;
await servicio.reprogramar(planificar(citas, minutos, ahora));
```
On sign-out, also do `await _enCurso; await servicio.cancelarTodo();` (or set a generation counter that `_una` checks).

### ME-03 (medium): A required phone can be saved as an empty string after normalization

**File:** `lib/features/clients/presentation/screens/cliente_detail_screen.dart:103,119`; `lib/features/clients/presentation/screens/nuevo_cliente_mascota_screen.dart:86,119`; `lib/core/utils/telefono_co.dart:29-32,83-86`

**Issue:** The required check is `_telefonoCtrl.text.trim().isNotEmpty`. For input with no digits ("abc", "---", "N/A"), the check passes, but `normalizarTelefono(...).guardado` returns `''`, which is then saved. `requiereAvisoTelefono` returns `false` for `vacio`, so the user gets no warning. The required "Teléfono *" field ends up blank in the DB, and WhatsApp reminders are disabled with no explanation at the time of saving.

**Fix:** Validate on the normalized value:
```dart
bool get _telefonoValido => normalizarTelefono(_telefonoCtrl.text).clase != ClaseTelefono.vacio;
// _puedeGuardar: ... && _telefonoValido
```
Have `requiereAvisoTelefono` (or a separate error text) flag non-empty input that normalizes to `vacio`.

### ME-04 (medium): Cancelled or no-show citas can be "completed" and receive consultas

**File:** `lib/features/appointments/presentation/screens/completar_cita_screen.dart:36-59`; `supabase/schema.sql:838-848`; `lib/features/appointments/data/repositories/supabase_cita_repository.dart:129-130`

**Issue:** `CompletarCitaScreen._finalizar` only short-circuits for `completada`. If the screen is opened from a stale agenda card or a deep link (`/agenda/:id/completar`) for a `cancelada` or `no_asistio` cita, "Finalizar cita" flips it to `completada`. `cambiarEstado` does an unconditional `update`, and the DB has no transition guard (see HI-01). `registrar_consulta(p_cita_id)` also does not check `estado`, so consultas can be attached to cancelled citas.

**Fix:**
- In `CompletarCitaScreen`, render a "Esta cita ya no se puede completar" state when `cita.estado.esTerminal && cita.estado != EstadoCita.completada`.
- In `registrar_consulta`, add `and c.estado in ('pendiente','confirmada','completada')` to the membership `exists`.
- Enforce allowed transitions with the trigger from HI-01, for example `cancelada`/`no_asistio` -> only `pendiente` via undo.

### ME-05 (medium): The consulta form overwrites anamnesis text the vet already typed

**File:** `lib/features/clinical_history/presentation/screens/consulta_form_screen.dart:161-171`

**Issue:** The precarga writes `_anamnesisCtrl.text` inside `build()` the first time `citaProvider` has data. If the cita is not already cached (deep link, invalidated by a previous `registrarConsulta`, or a slow network), the vet can start typing before the data arrives, and that text is then replaced without warning. Changing a controller inside `build` also triggers listener notifications during the build phase.

**Fix:** Do the precarga in `ref.listenManual(citaProvider(id), ..., fireImmediately: true)` from `initState`, and only fill the field if it is still empty:
```dart
if (_anamnesisCtrl.text.trim().isEmpty) _anamnesisCtrl.text = ...;
```

### ME-06 (medium): The "first free slot" suggestion can be in the past or outside the stepper range

**File:** `lib/features/appointments/domain/cita_solapes.dart:47-70`; `lib/features/appointments/presentation/screens/cita_form_screen.dart:146-160`; `lib/features/appointments/presentation/widgets/time_stepper.dart:23-24,55,61`

**Issue:**
- When today is selected after 22:00 Bogotá time, `inicial` is later than `limite`, so the function returns `limite`, which is 22:00 **today** and already in the past. The form then offers a past time as "Primer hueco libre sugerido".
- Before 06:00 (for example 00:10), it suggests 00:15. That is below `TimeStepper.minimo`, so the "−" button is disabled and the time shown is outside the stepper's domain.
- When nothing fits, it returns `inicial`, a slot it already found to overlap, and still labels it "hueco libre".

**Fix:** Clamp the start of the search to `max(inicial, 06:00)`. If the result is past `limite`, or nothing fits, return `null` and show "No hay huecos hoy; elige otro día". Do not label an overlapping or past time as free.

## Info

### LO-01 (low): Two citas with the same start time are never flagged as overlapping in the list

**File:** `lib/features/appointments/presentation/screens/agenda_screen.dart:327`

**Issue:** `o.fechaHora.isBefore(c.fechaHora)` is false in both directions when the start times are equal, so neither card shows the cruce warning, even though this is the most obvious kind of double booking.

**Fix:** Break ties by list order, for example compare the index in `delDia` (`indexOf(o) < indexOf(c)`) when `fechaHora` is equal.

### LO-02 (low): Notification ids can collide

**File:** `lib/features/appointments/domain/recordatorios_plan.dart:29-36`

**Issue:** The id is a 31-bit FNV-1a hash of the uuid. Two citas that hash to the same id overwrite each other in `zonedSchedule`, and one reminder is silently lost. This is unlikely with 60 items, but nothing detects it.

**Fix:** In `planificar`, check for duplicate ids and resolve them (for example with linear probing over a `Set<int>`), since the plan is rebuilt in full on every sync anyway.

### LO-03 (low): The "Termina a las" text wraps past midnight without a day indicator

**File:** `lib/features/appointments/presentation/screens/cita_form_screen.dart:546`; `time_stepper.dart:38-39`

**Issue:** 22:00 + 120 min renders as "12:00 a. m." with no "(día siguiente)". The overlap check also only looks at citas starting on the same Bogotá day (`_citasDelDia`), so a crossing into the next morning goes unnoticed.

**Fix:** Append " (día siguiente)" when `minutos + duracion >= 1440`. Also check overlaps for citas that start the following day.

### LO-04 (low): `Cita.copyWith` cannot clear the nullable fields

**File:** `lib/features/appointments/domain/entities/cita.dart:118-150`

**Issue:** `direccion`, `notas` and `recordatorioEnviadoAt` use `x ?? this.x`, so they can never be set back to `null`. The "Deshacer" for a sent reminder needs exactly that if it is ever done optimistically through `copyWith`.

**Fix:** Use a sentinel or a `ValueGetter<T?>?` parameter for nullable fields.

### LO-05 (low): The edit form lets a pet with a consulta be unchecked, and the date picker accepts any past date

**File:** `lib/features/appointments/presentation/screens/cita_form_screen.dart:221-233, 475-486`

**Issue:** `firstDate: DateTime(2020)` allows creating new citas years in the past, with no warning. Combined with ME-01, the edit form accepts input that the server will reject.

**Fix:** For new citas, use `firstDate` = today in Bogotá, or confirm when the chosen date is in the past. Lock pets that already have a consulta.

### LO-06 (low): The `mascotas_id_clinica_id_key` delta can mask unrelated errors

**File:** `supabase/schema.sql:529-537`

**Issue:** The `exception when duplicate_object or duplicate_table then null` block also swallows the case where a different relation already uses that name. In that case the composite FK below fails later with a less clear error.

**Fix:** Check `pg_constraint` by `conname` and `conrelid = 'public.mascotas'::regclass` before running `alter table`.

---

_Reviewed: 2026-10-01_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
