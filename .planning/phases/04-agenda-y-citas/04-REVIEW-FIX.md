---
phase: 04-agenda-y-citas
fixed_at: 2026-10-01T00:00:00Z
review_path: .planning/phases/04-agenda-y-citas/04-REVIEW.md
iteration: 1
findings_in_scope: 9
fixed: 7
skipped: 2
status: all_fixed
---

# Phase 4: Code Review Fix Report

**Fixed at:** 2026-10-01
**Source review:** .planning/phases/04-agenda-y-citas/04-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 9. That is the 8 warnings (HI-01, HI-02, ME-01 to ME-06) plus LO-05, which was requested because it pairs with ME-01.
- Fixed: 7 (the Dart side of ME-04 only)
- Skipped: 2 (HI-01 and HI-02 are database work owned by the parallel DB fix agent)

This run only changed Dart code; nothing under `supabase/` was touched. After the last commit, `flutter test` passes all 364 tests and `flutter analyze` reports no issues.

## Fixed Issues

### ME-01: Removing a pet that has a consulta shows "Elige al menos una mascota."

**Files modified:** `lib/features/appointments/data/repositories/supabase_cita_repository.dart`, `lib/features/appointments/presentation/screens/cita_form_screen.dart`, `lib/features/appointments/presentation/widgets/mascota_multi_select.dart`, `test/cita_form_screen_test.dart`, `test/supabase_cita_repository_test.dart`
**Commit:** 0b3f04c
**Applied fix:**
- The 23514 translation moved into a top-level `mensajeErrorCita`, marked `@visibleForTesting`.
- It now checks the full phrase "ya tiene consulta" before "al menos una mascota".
- In edit mode, `MascotaMultiSelect` receives `bloqueadas` (the cita's `mascotasConConsulta`). It disables those checkboxes and labels them "· Consulta registrada", and the form ignores any attempt to uncheck them.

### ME-02: Reminders containing client names can be re-scheduled after sign-out

**Files modified:** `lib/features/appointments/presentation/providers/recordatorios_providers.dart`, `test/helpers/fake_recordatorios.dart`, `test/recordatorios_providers_test.dart`
**Commit:** 0ec5468
**Applied fix:**
- A `_generacion` counter goes up on every sign-out.
- `_una()` captures the counter when it starts. Right before `reprogramar` it checks that the counter is unchanged and that the same vet is still signed in, and returns early otherwise.
- Sign-out (`_cerrarSesion`) cancels all reminders at once. If a sync was in flight, it waits for that sync to finish and cancels again.
- A regression test holds the permission check open while sign-out happens. It fails without the fix.

### ME-03: A required phone can be saved as an empty string after normalization

**Files modified:** `lib/core/utils/telefono_co.dart`, `lib/features/clients/presentation/screens/cliente_detail_screen.dart`, `lib/features/clients/presentation/screens/nuevo_cliente_mascota_screen.dart`, `test/telefono_co_test.dart`, `test/nuevo_cliente_mascota_screen_test.dart`
**Commit:** 1139bbf
**Applied fix:**
- Added `telefonoGuardable` and `telefonoSinDigitos`, plus the message `kErrorTelefonoSinDigitos`.
- Both client screens now decide "can save" from the normalized phone, not from `trim().isNotEmpty`.
- Once the phone field has been touched, input with no digits shows a field error.

### ME-04: Cancelled or no-show citas can be "completed" and receive consultas (Dart side only)

**Files modified:** `lib/features/appointments/presentation/screens/completar_cita_screen.dart`, `test/completar_cita_screen_test.dart`
**Commit:** 0037e62
**Applied fix:**
- For `cancelada` and `no_asistio` citas, `CompletarCitaScreen` now shows "Esta cita ya no se puede completar." with the reason, and none of the actions.
- `_finalizar` also refuses these citas.
- The server-side guard (the `registrar_consulta` status check and the transition trigger) belongs to the DB fix agent.

### ME-05: The consulta form overwrites anamnesis text the vet already typed

**Files modified:** `lib/features/clinical_history/presentation/screens/consulta_form_screen.dart`, `test/consulta_form_screen_test.dart`
**Commit:** 77aed46
**Applied fix:**
- The anamnesis precarga no longer runs inside `build()`. It now runs from `ref.listenManual(citaProvider(id), ..., fireImmediately: true)` in `initState`.
- It runs once, and only fills the field if it is still empty.
- A test with a slow cita repository confirms that text typed before the cita arrives is kept.

### ME-06: The "first free slot" suggestion can be in the past or outside the stepper range

**Files modified:** `lib/features/appointments/domain/cita_solapes.dart`, `lib/features/appointments/presentation/screens/cita_form_screen.dart`, `test/cita_solapes_test.dart`
**Commit:** 3f0bae4
**Status:** fixed: requires human verification (logic change)
**Applied fix:**
- New `inicioBusquedaHueco` keeps the search start between 06:00 and 22:00.
- `primerHuecoLibre` now returns `DateTime?`. It returns `null` when nothing fits or when today is already past 22:00.
- In that case the form shows "No hay huecos libres este día; elige la hora u otro día." with an in-range fallback hour, and does not call it a free slot.
- The old test "sin hueco devuelve el candidato inicial" was replaced with tests for the `null` result, the past-22:00 case and the 06:00 clamp.

### LO-05: Pets with a consulta can be unchecked, and the date picker accepts any past date

**Files modified:** `lib/features/appointments/presentation/screens/cita_form_screen.dart`, `test/cita_form_screen_test.dart`
**Commit:** e198be0 (date picker). The pet lock shipped in 0b3f04c with ME-01.
**Applied fix:**
- The date picker's `firstDate` is now today in Bogotá.
- If the cita's own day is already in the past (an edit, or a date passed in the route), that earlier day stays selectable.

### Additional: DB guard error translations (requested by the coordinator)

**Files modified:** `lib/features/appointments/data/repositories/supabase_cita_repository.dart`, `lib/features/clinical_history/data/repositories/supabase_consulta_repository.dart`, `test/supabase_cita_repository_test.dart`, `test/supabase_consulta_repository_test.dart`
**Commit:** 214868d
**Applied fix:**
- `mensajeErrorCita` maps "estado no permitido" to "Esta cita ya no puede cambiar a ese estado.".
- It maps "No se puede cambiar el cliente…" to "No se puede cambiar el cliente de una cita.".
- Both checks run before the mascota/domicilio branches.
- The consulta translation is now a top-level `mensajeErrorConsulta` and maps "no admite consultas" to "Esta cita ya no admite consultas.".

## Skipped Issues

### HI-01: Direct table writes bypass the RPC same-owner and cita-membership guards

**File:** `supabase/schema.sql:617-620, 629-631, 511-519`
**Reason:** skipped: handled by DB fix agent. This run was limited to Dart, and `supabase/` was not touched.
**Original issue:** The RLS policies on `cita_mascotas`, `citas` and `consultas` allow direct PostgREST writes that skip the RPCs' same-owner, state-machine and cita-membership guards.

### HI-02: Deleting a vet's auth user cascades away the clinic's appointments

**File:** `supabase/schema.sql:546`
**Reason:** skipped: handled by DB fix agent. This run was limited to Dart, and `supabase/` was not touched.
**Original issue:** `citas.veterinario_id ... on delete cascade` deletes every cita a vet created when that vet's account is removed.

---

_Fixed: 2026-10-01_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_

## Database findings (fixed in parallel by vetapp-supabase)

HI-01, HI-02, ME-04 (server side) and LO-06 were fixed directly on master in four `fix(04-review):` commits touching `supabase/schema.sql`, `supabase/tests/rls_smoke_test.sql` (95 → 115 checks) and `README.md`. Pending: human re-applies schema.sql and the smoke test must report `RLS SMOKE: PASS (115 checks)`.
