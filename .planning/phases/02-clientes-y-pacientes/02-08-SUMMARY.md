---
phase: 02-clientes-y-pacientes
plan: 08
subsystem: patients
tags: [flutter, riverpod, supabase, go_router, cached_network_image, append-only-history]

# Dependency graph
requires:
  - phase: 02-clientes-y-pacientes
    plan: 04
    provides: Mascota entity, MascotaFailure, SupabaseMascotaRepository base, mascotaRepositoryProvider, fake_mascotas.dart
  - phase: 02-clientes-y-pacientes
    plan: 05
    provides: AppPhotoPicker, MascotaFotoDatasource (upload/signedUrlFor/eliminar), mascotaFotoDatasourceProvider/mascotaFotoUrlProvider/capturadorFotoProvider, captura_foto.dart, test/helpers/fake_fotos.dart
  - phase: 02-clientes-y-pacientes
    plan: 06
    provides: SupabaseMascotaRepository.buscar, MascotasNotifier/mascotasProvider, pacientesRoute, PacientesListScreen (rows with no onTap/photo yet)
  - phase: 02-clientes-y-pacientes
    plan: 07
    provides: ClienteDetailScreen mascota mini-rows (no onTap yet), clientesRoute ':id' child
provides:
  - "PesoRegistro: immutable, append-only weight-history entry (no copyWith) — lib/features/patients/domain/entities/peso_registro.dart"
  - "SupabaseMascotaRepository.obtener/pesos/registrarPeso — mascotaProvider/pesosProvider (autoDispose families)"
  - "MascotaFotoAvatar — resolves the signed URL for a foto_path and renders AppPhotoPicker, always falling back to the placeholder on loading/error"
  - "MascotaDetailScreen at /pacientes/:id and /clientes/:id/mascotas/:mascotaId — the pet ficha (view, change photo, weight history)"
  - "PacientesListScreen rows: 56px photo thumbnail + row onTap to the ficha; ClienteDetailScreen mini-rows: onTap to the ficha"
affects: [02-09, 03]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Defensive re-sort at the presentation layer: MascotaDetailScreen's weight-history widget sorts by registradoEn descending itself instead of trusting the repository's ORDER BY — the fake used in tests deliberately returns pesos unsorted (as seeded) to force this behavior to be real, not incidental"
    - "Photo replacement sequencing: upload -> actualizarFotoPath -> best-effort eliminar(oldPath) in its own try/catch that swallows failures (T-02-32) — losing the old Storage object is never a data-loss event, so it never blocks the flow or surfaces an error"
    - "MascotaFotoAvatar wraps mascotaFotoUrlProvider + AppPhotoPicker so every screen showing a mascota photo (ficha at 96px, list row at 56px) shares one place that resolves the signed URL and falls back to the placeholder on loading/error, instead of each screen re-deriving that fallback logic"

key-files:
  created:
    - lib/features/patients/domain/entities/peso_registro.dart
    - lib/features/patients/presentation/widgets/mascota_foto_avatar.dart
    - lib/features/patients/presentation/screens/mascota_detail_screen.dart
    - test/mascota_detail_screen_test.dart
  modified:
    - lib/features/patients/data/repositories/supabase_mascota_repository.dart
    - lib/features/patients/presentation/providers/mascotas_providers.dart
    - lib/features/patients/presentation/pacientes_routes.dart
    - lib/features/patients/presentation/screens/pacientes_list_screen.dart
    - lib/features/clients/presentation/clientes_routes.dart
    - lib/features/clients/presentation/screens/cliente_detail_screen.dart
    - test/helpers/fake_mascotas.dart
    - test/pacientes_list_screen_test.dart

key-decisions:
  - "mascotaRocky (test fixture, id 'm-1') now carries fotoPath 'cli-1/m-1/1.jpg' per CONTRACTS — verified no existing test in the suite asserted Rocky had no photo before adding it, so no other test file needed adjustment."
  - "'Registrar peso' bottom sheet is a private widget local to mascota_detail_screen.dart (_RegistrarPesoSheet), not a separate exported file — the plan's CONTRACTS section only names public members for PesoRegistro/repository methods/providers/MascotaFotoAvatar/MascotaDetailScreen, and this sheet has no downstream consumer, unlike VinculacionSheet (Plan 07) which the plan named explicitly."
  - "Dropped the plan action text's 'autofocus' detail on the Peso (kg) field — AppTextField (shared core widget, not in this plan's files_modified) has no autofocus parameter, and no test/acceptance-criteria bullet requires it; adding the parameter would have been out-of-scope widening of a shared component for a purely cosmetic detail."
  - "Owner ('Dueño') row falls back to 'Sin registrar' + no tap handler when duenoNombre is null (defensive — every real row from buscar/porCliente/obtener currently embeds the owner, but the entity's own doc comment flags duenoNombre as only 'present when the query embeds it')."

requirements-completed: [PAT-02, PAT-03, PAT-05]

# Metrics
duration: ~65min
completed: 2026-09-24
---

# Phase 2 Plan 08: Ficha de Mascota (foto, datos, peso) Summary

**`MascotaDetailScreen` reachable from both `PacientesListScreen` and a client's ficha: photo (96px, camera-first replace with best-effort cleanup of the old object), read-only especie/raza/fecha-edad/dueño fields (dueño name jumps to the client ficha), and an append-only weight timeline (newest first) with a one-field "Registrar peso" sheet — plus 56px photo thumbnails and row navigation on both list screens.**

## Performance

- **Duration:** ~65 min
- **Tasks:** 3 of 3 completed
- **Files modified:** 12 (4 created, 8 modified)

## Accomplishments

- `PesoRegistro`: immutable weight-history entry with no `copyWith` (append-only by design — corrections are new entries, matching `mascota_pesos`'s missing update/delete RLS policy).
- `SupabaseMascotaRepository`: `obtener(id)` (same owner-embed select as `buscar`), `pesos(mascotaId)` (`order('registrado_en', ascending: false)`, never update/delete), `registrarPeso(mascotaId, pesoKg)` (insert-only; the server assigns `registrado_en`).
- `mascotaProvider`/`pesosProvider` (`autoDispose.family`) added to `mascotas_providers.dart`.
- `MascotaFotoAvatar`: resolves the signed URL for a `foto_path` via `mascotaFotoUrlProvider` and renders `AppPhotoPicker`, always handing the picker `fotoPath: null` on loading/error so a broken image never appears.
- `MascotaDetailScreen`: heading (mascota's nombre), 96px `MascotaFotoAvatar` (camera-first tap to replace), read-only rows (Especie/Raza/Fecha de nacimiento+edad/Dueño — the last one link-styled and tappable, jumping to `/clientes/{duenoId}` via `context.go`), a defensively-resorted weight-history list (plain rows + `Divider`, no edit/delete affordance anywhere), and a "Registrar peso" `AppButtonVariant.text` action opening a bottom sheet with one `parsearPeso`-validated field.
- Photo replacement sequencing: capture -> upload -> `actualizarFotoPath` -> best-effort `eliminar(oldPath)` in its own try/catch that swallows failures (T-02-32) -> invalidate `mascotaProvider`/`mascotasProvider`. No confirmation dialog (replacing is not destructive, per UI-SPEC).
- Routes: `pacientesRoute` gained the `':id'` child; `clientesRoute`'s `':id'` child gained `'mascotas/:mascotaId'`. Both build `MascotaDetailScreen` with `rutaBase: state.uri.path` so Plan 09 can push `'$rutaBase/editar'` regardless of which list the vet arrived from.
- `PacientesListScreen` rows now show a 56px read-only `MascotaFotoAvatar` thumbnail and navigate to the ficha on row tap (not the thumbnail). `ClienteDetailScreen`'s per-owner mascota mini-rows now navigate to `/clientes/{clienteId}/mascotas/{mascotaId}` on tap.

## Task Commits

1. **Task 1: Failing widget tests for the pet ficha, weight history and photo change (RED)** - `60946b6` (test)
2. **Task 2: PesoRegistro, repository obtener/pesos/registrarPeso, providers and MascotaFotoAvatar** - `1955038` (feat)
3. **Task 3: MascotaDetailScreen, routes from both lists, and Pacientes thumbnails (GREEN)** - `3eb23ed` (feat)

_TDD plan: RED → GREEN → GREEN. `flutter analyze` clean and full `flutter test` (105/105) green after Task 3._

## Files Created/Modified

- `lib/features/patients/domain/entities/peso_registro.dart` - `PesoRegistro` (new)
- `lib/features/patients/data/repositories/supabase_mascota_repository.dart` - added `obtener`/`pesos`/`registrarPeso`
- `lib/features/patients/presentation/providers/mascotas_providers.dart` - added `mascotaProvider`/`pesosProvider`
- `lib/features/patients/presentation/widgets/mascota_foto_avatar.dart` - `MascotaFotoAvatar` (new)
- `lib/features/patients/presentation/screens/mascota_detail_screen.dart` - ficha screen (new)
- `lib/features/patients/presentation/pacientes_routes.dart` - added `':id'` child route
- `lib/features/patients/presentation/screens/pacientes_list_screen.dart` - photo thumbnail + row `onTap`
- `lib/features/clients/presentation/clientes_routes.dart` - added `'mascotas/:mascotaId'` child route
- `lib/features/clients/presentation/screens/cliente_detail_screen.dart` - mini-row `onTap`
- `test/helpers/fake_mascotas.dart` - `obtener`/`pesos`/`registrarPeso`, `pesosPorMascota`, `pesosRegistrados`; `mascotaRocky` gets `fotoPath`
- `test/mascota_detail_screen_test.dart` - PAT-02/03/05 widget tests (new)
- `test/pacientes_list_screen_test.dart` - photo datasource override + row-tap navigation case

## Decisions Made

- Followed the plan's CONTRACTS exactly (entity/method/provider/widget signatures) so Plan 09 (standalone edit form) can build on top unchanged.
- Kept `_RegistrarPesoSheet` private to `mascota_detail_screen.dart` (see key-decisions) — no other screen needs it.
- Left `AppTextField` untouched (no `autofocus` param added) — see key-decisions for the scope reasoning.

## Deviations from Plan

None — plan executed as written; the only implementation liberty taken (dropping `autofocus` on the weight-entry field) is documented above as a decision, not a deviation, since it does not affect any test or acceptance criterion.

## Issues Encountered

- Same pre-existing Windows/Flutter tooling churn documented in Plan 07's summary: `flutter analyze`/`flutter test` regenerate `linux/flutter/generated_plugin_registrant.*`, `windows/flutter/generated_plugin_registrant.*`/`generated_plugins.cmake`, and `macos/Flutter/GeneratedPluginRegistrant.swift` with line-ending-only diffs. Left unstaged in every task commit, per the "stage task-related files individually" rule — not caused by this plan.
- The executor's worktree branch was found drifted 8 commits behind the assigned base commit (`f42eaad...`) at startup — reset to the correct base per the orchestrator's explicit `<worktree_branch_check>` instruction before any work began; no work was lost since nothing had been committed yet on the drifted branch.

## User Setup Required

None — no external service configuration required (uses the same live Supabase project, `mascota-fotos` bucket, and `mascota_pesos` table already live since Plan 01).

## Next Phase Readiness

- PAT-02 (view), PAT-03 (change photo), PAT-05 (weight history) all done: the pet ficha is reachable from both lists, shows every required field, supports one-tap photo replacement with best-effort cleanup of the superseded object, and records/display an append-only weight timeline newest-first.
- `PesoRegistro`, `SupabaseMascotaRepository.obtener/pesos/registrarPeso`, `mascotaProvider`/`pesosProvider`, `MascotaFotoAvatar`, and `MascotaDetailScreen({mascotaId, rutaBase})` are now stable contracts — Plan 09 (standalone `MascotaFormScreen` for create/edit, reached via `'$rutaBase/editar'`) builds directly on top without renaming anything.
- No blockers.

## Self-Check

- `lib/features/patients/domain/entities/peso_registro.dart`: FOUND, contains `class PesoRegistro`
- `lib/features/patients/data/repositories/supabase_mascota_repository.dart`: FOUND, contains `order('registrado_en', ascending: false)`, no `mascota_pesos` update/delete call
- `lib/features/patients/presentation/providers/mascotas_providers.dart`: FOUND, contains `mascotaProvider`, `pesosProvider`
- `lib/features/patients/presentation/widgets/mascota_foto_avatar.dart`: FOUND, contains `mascotaFotoUrlProvider`
- `lib/features/patients/presentation/screens/mascota_detail_screen.dart`: FOUND, contains `Historial de peso`, no `showDialog`
- `lib/features/patients/presentation/pacientes_routes.dart`: FOUND, contains `':id'`
- `lib/features/clients/presentation/clientes_routes.dart`: FOUND, contains `mascotas/:mascotaId`
- `lib/features/patients/presentation/screens/pacientes_list_screen.dart`: FOUND, contains `MascotaFotoAvatar`
- `test/mascota_detail_screen_test.dart`: FOUND, 8/8 passing
- Commit `60946b6` (Task 1): FOUND in `git log --oneline`
- Commit `1955038` (Task 2): FOUND in `git log --oneline`
- Commit `3eb23ed` (Task 3): FOUND in `git log --oneline`
- `flutter analyze`: No issues found
- `flutter test` (full suite): 105/105 passed

## Self-Check: PASSED

---
*Phase: 02-clientes-y-pacientes*
*Completed: 2026-09-24*
