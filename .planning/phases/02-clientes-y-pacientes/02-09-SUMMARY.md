---
phase: 02-clientes-y-pacientes
plan: 09
subsystem: patients
tags: [flutter, riverpod, supabase, go_router, tdd]

# Dependency graph
requires:
  - phase: 02-clientes-y-pacientes
    plan: 01
    provides: registrar_mascota RPC (atomic pet + first weight for an existing owner)
  - phase: 02-clientes-y-pacientes
    plan: 04
    provides: MascotaCamposSection, mascotaRepositoryProvider, Mascota/Especie, MascotaFailure
  - phase: 02-clientes-y-pacientes
    plan: 05
    provides: AppPhotoPicker, MascotaFotoDatasource, capturadorFotoProvider, fake_fotos.dart
  - phase: 02-clientes-y-pacientes
    plan: 07
    provides: ClienteDetailScreen, clienteProvider/clientesProvider, clientesRoute ':id'
  - phase: 02-clientes-y-pacientes
    plan: 08
    provides: MascotaDetailScreen({mascotaId, rutaBase}), MascotaFotoAvatar, mascotaProvider/pesosProvider, both route trees' ':id' children
provides:
  - "MascotaFormScreen(clienteId | mascotaId): create mode (D-03, owner known/read-only, no telefono re-ask) and edit mode (PAT-02, no peso field), reusing MascotaCamposSection/AppPhotoPicker"
  - "SupabaseMascotaRepository.registrarMascota (registrar_mascota RPC, atomic pet+first-weight) and .actualizar (whitelisted nombre/especie/raza/fecha_nacimiento update)"
  - "Routes: clientesRoute ':id/nueva-mascota', both ':id/editar' (pacientes) and 'mascotas/:mascotaId/editar' (clientes) child routes"
  - "ClienteDetailScreen outline 'Nueva mascota' button; MascotaDetailScreen primary 'Editar' CTA"
affects: [03]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "One ConsumerStatefulWidget, two exclusive modes selected by which constructor arg is non-null (assert enforces exactly one) — avoids forking a near-identical edit screen, mirrors the single MascotaCamposSection reused by both this screen and NuevoClienteMascotaScreen"
    - "Edit-mode 'something changed' gating compares every controller/especie/foto against a snapshot taken once from the first provider emission (_original), never re-taken on rebuild — same shape as ClienteDetailScreen's own _esDirty getter (Plan 07)"
    - "registrarMascota builds its RPC params map as a named local variable before the call so the line fits under dart format's wrap width and the call stays single-line — deliberate deviation from registrarClienteConMascota's multi-line inline-map style in the same file, kept only where an automated grep check required the single-line form"

key-files:
  created:
    - lib/features/patients/presentation/screens/mascota_form_screen.dart
    - test/mascota_form_screen_test.dart
  modified:
    - lib/features/patients/data/repositories/supabase_mascota_repository.dart
    - lib/features/clients/presentation/clientes_routes.dart
    - lib/features/patients/presentation/pacientes_routes.dart
    - lib/features/clients/presentation/screens/cliente_detail_screen.dart
    - lib/features/patients/presentation/screens/mascota_detail_screen.dart
    - test/helpers/fake_mascotas.dart
    - test/mascota_detail_screen_test.dart

key-decisions:
  - "registrarMascota's RPC params extracted to a local `params` variable (not inlined) purely so the `_client.rpc('registrar_mascota', params: params)` call stays on one line — the plan's automated Task 2 verification greps for the literal substring `rpc('registrar_mascota'`, which `dart format` breaks across lines when the map is passed inline (as registrarClienteConMascota already does elsewhere in the same file)."
  - "mascota_detail_screen.dart's new 'Editar' AppButton pushed 'Registrar peso' below the fixed 800x600 test viewport in the pre-existing mascota_detail_screen_test.dart — added `tester.ensureVisible` before that tap (Rule 1: bug caused directly by this plan's UI change to a file this plan modifies)."
  - "Two mascota_form_screen_test.dart assertions originally checked `find.text('Rita Gómez')`/`find.text('Rocky')` to confirm navigation back to the owner/pet ficha, but both strings are also present in that ficha's own pre-filled Nombre TextFormField, so the finder matched two widgets. Swapped for each ficha's unique AppTopBar title ('Cliente' / 'Paciente') instead of adding more specific ancestor finders — simpler and matches how other screen tests in this phase assert 'still on screen X'."

requirements-completed: [PAT-01, PAT-02]

# Metrics
duration: ~90min
completed: 2026-09-25
---

# Phase 2 Plan 09: Nueva Mascota (Dueño Existente) y Edición Summary

**`MascotaFormScreen` reused in two exclusive modes — create (D-03: existing owner's ficha → "Nueva mascota", owner never re-asked) and edit (PAT-02: any pet ficha → "Editar", weight history untouched) — both wired into both route trees and calling the atomic `registrar_mascota` RPC / a whitelisted `actualizar` update respectively.**

## Performance

- **Duration:** ~90 min
- **Tasks:** 3 of 3 completed
- **Files modified:** 9 (2 created, 7 modified)

## Accomplishments

- `SupabaseMascotaRepository.registrarMascota`: one atomic call to `registrar_mascota` (pet + optional first weight together — never a separate insert followed by `registrarPeso`).
- `SupabaseMascotaRepository.actualizar`: whitelists `nombre`/`especie`/`raza`/`fecha_nacimiento` only — never sends `dueno_id`, `clinica_id` or `foto_path`, and never touches `mascota_pesos` (T-02-34/T-02-35).
- `MascotaFormScreen({clienteId} | {mascotaId})`: create mode shows a read-only "Dueño: {nombre}" line (no telefono field, D-03) and submits via `registrarMascota`, then optionally uploads a captured photo and calls `actualizarFotoPath` (photo failure never blocks the save, same pattern as `NuevoClienteMascotaScreen`). Edit mode pre-fills from `mascotaProvider` once, hides the peso field entirely (weight is append-only via `MascotaDetailScreen`'s "Registrar peso"), stays disabled until something actually changed, and on save replaces the photo with the same upload → `actualizarFotoPath` → best-effort `eliminar(oldPath)` sequencing as `MascotaDetailScreen._cambiarFoto`.
- Routes: `clientesRoute`'s `':id'` gained `'nueva-mascota'`; `'mascotas/:mascotaId'` (clientes tree) and `pacientesRoute`'s `':id'` (pacientes tree) both gained an `'editar'` child — the edit form is reachable identically from either entry point.
- `ClienteDetailScreen`: outline `AppButton` "Nueva mascota" below the mascotas list. `MascotaDetailScreen`: primary `AppButton` "Editar" → `'$rutaBase/editar'`.

## Task Commits

1. **Task 1: Failing tests for "Nueva mascota" (existing owner) and pet editing (RED)** - `7850984` (test)
2. **Task 2: Repository registrarMascota (RPC) + actualizar** - `f84edba` (feat)
3. **Task 3: MascotaFormScreen (create/edit) + entry points + routes (GREEN)** - `5e45070` (feat)

_TDD plan: RED → GREEN → GREEN. `flutter analyze` clean and full `flutter test` (111/111) green after Task 3._

## Files Created/Modified

- `lib/features/patients/presentation/screens/mascota_form_screen.dart` - `MascotaFormScreen` (new)
- `lib/features/patients/data/repositories/supabase_mascota_repository.dart` - added `registrarMascota`/`actualizar`
- `lib/features/clients/presentation/clientes_routes.dart` - added `'nueva-mascota'` and `'mascotas/:mascotaId/editar'` child routes
- `lib/features/patients/presentation/pacientes_routes.dart` - added `':id/editar'` child route
- `lib/features/clients/presentation/screens/cliente_detail_screen.dart` - outline "Nueva mascota" button
- `lib/features/patients/presentation/screens/mascota_detail_screen.dart` - primary "Editar" CTA
- `test/helpers/fake_mascotas.dart` - `registrarMascota`/`actualizar` (`registrosMascota`/`actualizados` logs)
- `test/mascota_form_screen_test.dart` - PAT-01 (D-03 path) + PAT-02 edit widget tests (new)
- `test/mascota_detail_screen_test.dart` - `ensureVisible` fix for the "Registrar peso" tap (see Deviations)

## Decisions Made

- Followed the plan's CONTRACTS exactly (method/screen/route signatures) so no downstream plan needs to change call sites.
- Kept the RPC params-as-local-variable formatting workaround scoped to `registrarMascota` only — `registrarClienteConMascota`'s existing inline-map style was left untouched since no automated check depends on its exact line layout.
- See key-decisions for the full rationale on both fixes.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `mascota_detail_screen_test.dart`'s "Registrar peso" tap needed `ensureVisible`**
- **Found during:** Task 3 (adding the "Editar" CTA to `MascotaDetailScreen`)
- **Issue:** The new button pushed the pre-existing "Registrar peso" text action below the fixed 800x600 test viewport in a Plan 08 test that tapped it without scrolling first, so the tap missed and the test failed.
- **Fix:** Added `await tester.ensureVisible(find.text('Registrar peso'));` before the tap, matching the `ensureVisible`-before-tap pattern already used throughout the other screen tests in this phase.
- **Files modified:** test/mascota_detail_screen_test.dart
- **Verification:** `flutter test test/mascota_detail_screen_test.dart` — 8/8 passing.
- **Committed in:** `5e45070` (Task 3 commit)

**2. [Rule 1 - Bug] Ambiguous `find.text` finders in two new form-screen tests**
- **Found during:** Task 3 (running the new `mascota_form_screen_test.dart` against the finished `MascotaFormScreen`)
- **Issue:** `find.text('Rita Gómez')` (create-mode test) and `find.text('Rocky')` (edit-mode test), used to confirm the screen popped back to the owner/pet ficha, each matched two widgets — the ficha's heading `Text` AND its own pre-filled Nombre `TextFormField`, which also contains that exact string.
- **Fix:** Swapped both assertions for `find.text('Cliente')` / `find.text('Paciente')` — each destination ficha's unique `AppTopBar` title.
- **Files modified:** test/mascota_form_screen_test.dart
- **Verification:** `flutter test test/mascota_form_screen_test.dart` — 6/6 passing.
- **Committed in:** `5e45070` (Task 3 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1, both test-only bugs surfaced by this plan's own UI additions).
**Impact on plan:** No scope creep — both fixes are in test files this plan's own changes broke, no production code behavior changed as a result.

## Issues Encountered

- `dart format` breaks a `_client.rpc('name', params: {...})` call across multiple lines once the inline map literal doesn't fit on one line (as it already does for `registrarClienteConMascota` elsewhere in the same file). Task 2's automated verification greps for the literal single-line substring `rpc('registrar_mascota'`, so the params map was extracted to a local variable first (`final params = {...}; final id = await _client.rpc('registrar_mascota', params: params);`) — this keeps the call itself on one line without disabling formatting anywhere. Purely a formatting/verification-compatibility choice, no behavior difference.
- Same pre-existing Windows/Flutter tooling churn documented in Plans 07/08's summaries: `flutter analyze`/`flutter test` regenerate `linux/flutter/generated_plugin_registrant.*`, `windows/flutter/generated_plugin_registrant.*`/`generated_plugins.cmake`, and `macos/Flutter/GeneratedPluginRegistrant.swift` with line-ending-only diffs. Left unstaged in every task commit, per the "stage task-related files individually" rule — not caused by this plan.
- The executor's worktree branch was found drifted (5 commits behind the assigned base commit `63ce300...`, pointing at an old pre-Phase-02-execution snapshot) at startup — reset to the correct base per the orchestrator's explicit `<worktree_branch_check>` instruction before any work began; no work was lost since nothing had been committed yet on the drifted branch. A later mid-session rate-limit pause also occurred after Task 2's commit; work resumed correctly from the existing commits per the coordinator's follow-up message.

## User Setup Required

None — no external service configuration required (uses the same live Supabase project and `registrar_mascota` RPC already live since Plan 01).

## Next Phase Readiness

- PAT-01 (D-03 add-pet-to-existing-owner path) and PAT-02 (edit) are both done: any client's ficha can add another pet without re-entering owner data, and any pet ficha (from either `PacientesListScreen` or a client's ficha) can be corrected via "Editar".
- This closes out the phase's core CRUD vertical slices for clientes y mascotas (create combined, search both, view+photo+peso ficha, add pet to existing owner, edit pet). Remaining Phase 02 plans (03 search, 10 if any) can build on a fully stable `MascotaFormScreen`/`SupabaseMascotaRepository` surface — no signatures introduced here are expected to change.
- No blockers.

## Self-Check

- `lib/features/patients/presentation/screens/mascota_form_screen.dart`: FOUND, contains `class MascotaFormScreen`, reuses `MascotaCamposSection`, no `Teléfono` field
- `lib/features/patients/data/repositories/supabase_mascota_repository.dart`: FOUND, contains `rpc('registrar_mascota'`, `actualizar` update map has no `dueno_id`/`clinica_id`/`foto_path` key
- `lib/features/clients/presentation/clientes_routes.dart`: FOUND, contains `nueva-mascota`
- `lib/features/patients/presentation/pacientes_routes.dart`: FOUND, contains `'editar'`
- `lib/features/clients/presentation/screens/cliente_detail_screen.dart`: FOUND, contains `AppButtonVariant.outline`
- `lib/features/patients/presentation/screens/mascota_detail_screen.dart`: FOUND, contains `rutaBase/editar`
- `test/mascota_form_screen_test.dart`: FOUND, 6/6 passing
- Commit `7850984` (Task 1): FOUND in `git log --oneline`
- Commit `f84edba` (Task 2): FOUND in `git log --oneline`
- Commit `5e45070` (Task 3): FOUND in `git log --oneline`
- `flutter analyze`: No issues found
- `flutter test` (full suite): 111/111 passed

## Self-Check: PASSED

---
*Phase: 02-clientes-y-pacientes*
*Completed: 2026-09-25*
