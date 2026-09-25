---
phase: 02-clientes-y-pacientes
plan: 07
subsystem: clients
tags: [flutter, riverpod, supabase, postgrest-rpc, go_router, clipboard]

# Dependency graph
requires:
  - phase: 02-clientes-y-pacientes
    plan: 01
    provides: generar_codigo_vinculacion RPC, clientes.perfiles_id/codigo_vinculacion/codigo_expira_en columns (all LIVE)
  - phase: 02-clientes-y-pacientes
    plan: 03
    provides: Cliente entity, ClienteFailure, clienteRepositoryProvider, clientesProvider, ClientesListScreen, clientesRoute, routerHarness, fake_clientes.dart
  - phase: 02-clientes-y-pacientes
    plan: 04
    provides: Mascota entity + Especie.etiqueta, mascotaRepositoryProvider, mascotasDeClienteProvider, fake_mascotas.dart
provides:
  - "ClienteDetailScreen at /clientes/:id — always-editable ficha (CLI-02), per-owner Mascotas section (CLI-04), Vincular cuenta / Cuenta vinculada row (CLI-05)"
  - "VinculacionSheet + top-level textoVigencia(DateTime, DateTime) helper"
  - "SupabaseClienteRepository.obtener/actualizar/generarCodigoVinculacion + CodigoVinculacion record typedef"
  - "clienteProvider (FutureProvider.autoDispose.family<Cliente, String>)"
  - "FakeClienteRepository.obtener/actualizar/generarCodigoVinculacion (configurable codigoResultado/errorCodigo, actualizados log)"
affects: [09-directorio-de-veterinarias]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Vet-side-only account-linking generate/display (D-07 scope boundary): the claim RPC (reclamar_codigo_cliente) and its CLIENTE-facing UI stay entirely out of this plan, deferred to Phase 9 (DIR-06) — grep-verified absent from lib/ and test/"
    - "Ficha screens keep a local '_original' Cliente snapshot as the dirty-check baseline, filled once from the first AsyncData emission; re-fetches after invalidate() never stomp in-progress edits because _original is only ever reassigned from a direct repository call result, not from the watched provider's rebuild"
    - "Cliente updates are built as a fresh Cliente(...) literal, never via copyWith — copyWith's `?? this.field` pattern cannot express 'clear this optional field to null', which the ficha's empty-Correo/Dirección/Notas case requires"

key-files:
  created:
    - lib/features/clients/presentation/screens/cliente_detail_screen.dart
    - lib/features/clients/presentation/widgets/vinculacion_sheet.dart
    - test/cliente_detail_screen_test.dart
  modified:
    - lib/features/clients/data/repositories/supabase_cliente_repository.dart
    - lib/features/clients/presentation/providers/clientes_providers.dart
    - lib/features/clients/presentation/clientes_routes.dart
    - lib/features/clients/presentation/screens/clientes_list_screen.dart
    - test/helpers/fake_clientes.dart

key-decisions:
  - "Fields are always editable inline (no separate 'Editar' toggle) — fewer taps, consistent with D-01's zero-friction principle and one of the two options the UI-SPEC explicitly allowed"
  - "textoVigencia takes `ahora` as an explicit parameter (never calls DateTime.now() internally) so its three time-band branches are unit-testable without a fake clock"
  - "'Guardar cambios' payload is built directly from controllers as a new Cliente(...), passing through perfilesId/codigoVinculacion/codigoExpiraEn/numeroMascotas unchanged from the last-saved snapshot — the repository's actualizar() already whitelists its own update payload, this is the second layer (never even construct those fields as vet-editable)"

requirements-completed: [CLI-02, CLI-04, CLI-05]

# Metrics
duration: ~50min
completed: 2026-09-25
---

# Phase 2 Plan 07: Ficha de Cliente (edit + mascotas + vinculación) Summary

**`ClienteDetailScreen` at `/clientes/:id`: always-editable cliente fields with a single "Guardar cambios" CTA, a per-owner Mascotas list (never another owner's pets), and a "Vincular cuenta" bottom sheet that generates/displays a 6-digit, 24-hour link code — vet-side only per D-07, with the Phase 9 claim RPC confirmed absent.**

## Performance

- **Duration:** ~50 min
- **Tasks:** 3 of 3 completed
- **Files modified:** 8 (3 created, 5 modified)

## Accomplishments

- Extended `FakeClienteRepository` with `obtener`/`actualizar` (logged in a new `actualizados` list)/`generarCodigoVinculacion` (configurable `codigoResultado` defaulting to `('482915', now+24h, false)`, optional `errorCodigo`) — no test in this plan touches a real Supabase client.
- `test/cliente_detail_screen_test.dart`: 8 widget tests + a 3-case `textoVigencia` unit-test group covering every behavior bullet in the plan (heading/prefill, save-button gating including the "clear Nombre re-disables it" case, per-owner Mascotas filtering — Rocky/Luna shown, Michi never shown, empty-mascotas copy, the vinculación sheet's code/vigencia/copy-to-clipboard flow via a mocked `SystemChannels.platform`, the expired-code notice, the error-with-retry state, and the already-linked "Cuenta vinculada" state).
- `SupabaseClienteRepository`: added `obtener(id)`, `actualizar(cliente)` (whitelisted payload — nombre/telefono/email/direccion/notas only, never `clinica_id` or any link-code column), and `generarCodigoVinculacion(clienteId)` calling the live `generar_codigo_vinculacion` RPC and returning a new `CodigoVinculacion` record typedef; extended `_messageFor` with a `P0002` → "cliente no encontrado" mapping and a `'vinculada'` substring match → "ya tiene una cuenta vinculada".
- `clienteProvider` (`FutureProvider.autoDispose.family<Cliente, String>`) added to `clientes_providers.dart`.
- `ClienteDetailScreen`: fills its five controllers exactly once from the first loaded `Cliente`, gates "Guardar cambios" on dirty + both required fields non-blank + correo empty-or-containing-`@`, builds the update payload as a fresh `Cliente(...)` (never `copyWith`, which cannot clear an optional field to `null`), and on success invalidates both `clienteProvider(id)` and `clientesProvider` before showing "Cambios guardados". The Mascotas section renders each pet from `mascotasDeClienteProvider(clienteId)` — already scoped server-side by `dueno_id`, so CLI-04's "never another owner's pets" guarantee comes from the query itself. The vinculación row shows "Cuenta vinculada" (non-tappable) when `cliente.tieneVinculacion`, otherwise an `AppCard` row opening `VinculacionSheet` via `showModalBottomSheet`.
- `VinculacionSheet`: generates the code in `initState` (no separate "generate" button), shows a loading spinner, an error state with an "Intentar de nuevo" retry action, or the code (large, letter-spaced, tabular-figure styled) with the expired-code notice when `reemplazoExpirado`, the `textoVigencia` line, and "Copiar código" (`Clipboard.setData` + a "Código copiado" snackbar).
- `clientes_routes.dart`: added the `':id'` child route after `'nuevo'` (order-verified by the plan's own grep gate). `clientes_list_screen.dart`: each cliente row now navigates to `/clientes/{id}`.

## Task Commits

1. **Task 1: Failing widget tests for the client ficha, its pets and the link code (RED)** - `bc2616f` (test)
2. **Task 2: Repository obtener/actualizar/generarCodigoVinculacion + clienteProvider** - `4e372d5` (feat)
3. **Task 3: ClienteDetailScreen + VinculacionSheet wired at /clientes/:id (GREEN)** - `72f3df9` (feat)

_TDD plan: RED → GREEN → GREEN. `flutter analyze` was not clean until Task 3 landed (Task 1's RED test imports `ClienteDetailScreen`/`textoVigencia`, only created in Task 3) — this is the same inherent Task1→Task3 gap already documented in Plan 04's summary, not a defect in this run. Task 2's own production files (`supabase_cliente_repository.dart`, `clientes_providers.dart`) were verified analyzer-clean with a scoped `dart analyze` before Task 3 started._

## Files Created/Modified

- `lib/features/clients/presentation/screens/cliente_detail_screen.dart` - ficha screen (view/edit + Mascotas + Vincular cuenta)
- `lib/features/clients/presentation/widgets/vinculacion_sheet.dart` - vinculación bottom sheet + `textoVigencia`
- `lib/features/clients/data/repositories/supabase_cliente_repository.dart` - `obtener`/`actualizar`/`generarCodigoVinculacion` + `CodigoVinculacion` typedef, extended `_messageFor`
- `lib/features/clients/presentation/providers/clientes_providers.dart` - added `clienteProvider`
- `lib/features/clients/presentation/clientes_routes.dart` - added `':id'` child route
- `lib/features/clients/presentation/screens/clientes_list_screen.dart` - row `onTap` navigates to the ficha
- `test/helpers/fake_clientes.dart` - `FakeClienteRepository.obtener/actualizar/generarCodigoVinculacion`, `actualizados` log
- `test/cliente_detail_screen_test.dart` - CLI-02/CLI-04/CLI-05 widget tests + `textoVigencia` unit tests

## Decisions Made

- Followed the plan's CONTRACTS exactly (typedef name/shape, method signatures, provider name) — no renaming, since this plan's contracts are consumed by no downstream plan directly but keep the codebase's existing naming conventions intact.
- Kept fields always-editable (no "Editar" toggle) per the UI-SPEC's explicit "planner's implementation choice" note — fewer taps, consistent with every other decision this phase has made under D-01.
- `_buildVinculacionRow`/`_buildMascotas` read the live `cliente`/`mascotasAsync` from the watched providers (not the cached `_original` snapshot) so a saved change to vinculación-adjacent state or a newly added pet from another screen shows up without needing to leave and re-enter the ficha — only the five text controllers stay pinned to the load-time/post-save baseline to avoid stomping in-progress edits.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `vinculacion_sheet.dart`'s own doc comment tripped the plan's negative grep gate for "no separate Generar-código button / no WhatsApp integration"**
- **Found during:** Task 3, running the acceptance-criteria check (`vinculacion_sheet.dart contains no 'Generar código' button text and no url_launcher/WhatsApp reference`)
- **Issue:** The class doc comment explained the design decision by literally using the words "Generar código" and "WhatsApp" (to say those things are absent) — the same substrings the grep gate forbids. Same false-positive class already documented in Plan 04's SUMMARY.md for `NuevoClienteMascotaScreen`'s doc comment.
- **Fix:** Reworded the comment to convey the same design intent ("la generación ocurre automáticamente al abrir la hoja, sin ningún botón adicional"; "ningún canal de mensajería externo está integrado aquí") without using the forbidden literal substrings.
- **Files modified:** `lib/features/clients/presentation/widgets/vinculacion_sheet.dart`
- **Verification:** `! grep -q "Generar código" ... && ! grep -qi "url_launcher\|whatsapp" ...` → prints `NO_GENERAR_BOTON_OK`
- **Committed in:** `72f3df9` (Task 3 commit)

**Total deviations:** 1 auto-fixed (Rule 1, doc-comment wording only — no functional change).
**Impact on plan:** None — wording-level only, no scope creep, no architectural change.

## Issues Encountered

- `flutter analyze`/`flutter test` runs on this Windows machine regenerate `linux/flutter/generated_plugin_registrant.*`, `windows/flutter/generated_plugin_registrant.*`/`generated_plugins.cmake`, and `macos/Flutter/GeneratedPluginRegistrant.swift` with line-ending-only diffs (no content change per `git diff`). Left uncommitted/unstaged in every task commit per the "stage task-related files individually" rule — this is tooling churn from the local Flutter SDK install, not caused by any change in this plan, and not part of `files_modified` for this plan.

## User Setup Required

None — no external service configuration required (uses the same live Supabase project and `generar_codigo_vinculacion` RPC already applied/verified in Plan 01).

## Next Phase Readiness

- CLI-02 done: a client's data is viewable/editable inline and persists to Supabase via `actualizar`.
- CLI-04 done: a client's ficha lists exactly their own mascotas (server-scoped by `dueno_id`, never denormalized).
- CLI-05 (vet side, per D-07) done: the vet can generate, view, and copy a 6-digit, 24-hour link code from the ficha; a cliente that already has `perfilesId` set shows "Cuenta vinculada" instead. The CLIENTE-side claim (`reclamar_codigo_cliente`, DIR-06) was deliberately **not** built — confirmed absent via `grep -r "reclamar_codigo_cliente" lib/ test/` (no matches) — and stays reserved for Phase 9.
- `ClienteDetailScreen`, `VinculacionSheet`, `textoVigencia`, `CodigoVinculacion`, and `clienteProvider` are now stable contracts. The "Nueva mascota" button referenced by D-03 (existing owner, new pet) is explicitly **not** part of this plan — it lands in Plan 09 per the plan's own `<objective>` note; the Mascotas section here has no add-pet entry point yet.
- No blockers. `lib/features/clients/presentation/screens/clientes_list_screen.dart` and `lib/features/clients/presentation/clientes_routes.dart` were touched (both owned by Plan 03/04 in earlier waves, extended here) — no conflicts expected with sibling Wave 3 plans 02-05/02-06 (disjoint files per the plan's own parallel-execution note).

## Self-Check

- `lib/features/clients/presentation/screens/cliente_detail_screen.dart`: FOUND, contains "Guardar cambios"
- `lib/features/clients/presentation/widgets/vinculacion_sheet.dart`: FOUND, contains "Copiar código"
- `lib/features/clients/data/repositories/supabase_cliente_repository.dart`: FOUND, contains `generar_codigo_vinculacion`, `obtener`, `actualizar`
- `lib/features/clients/presentation/providers/clientes_providers.dart`: FOUND, contains `clienteProvider`
- `test/cliente_detail_screen_test.dart`: FOUND
- `test/helpers/fake_clientes.dart`: FOUND, extended with `obtener`/`actualizar`/`generarCodigoVinculacion`
- Commit `bc2616f` (Task 1): FOUND in `git log --oneline`
- Commit `4e372d5` (Task 2): FOUND in `git log --oneline`
- Commit `72f3df9` (Task 3): FOUND in `git log --oneline`
- `flutter analyze`: clean (No issues found!)
- `flutter test` (full suite): 75/75 passed
- `reclamar_codigo_cliente` absent from `lib/` and `test/`: CONFIRMED (no matches)

## Self-Check: PASSED

---
*Phase: 02-clientes-y-pacientes*
*Completed: 2026-09-25*
