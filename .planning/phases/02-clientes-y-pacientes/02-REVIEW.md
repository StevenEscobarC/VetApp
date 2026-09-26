---
phase: 02-clientes-y-pacientes
reviewed: 2026-09-25T00:00:00Z
depth: standard
files_reviewed: 48
files_reviewed_list:
  - README.md
  - android/app/src/main/AndroidManifest.xml
  - ios/Runner/Info.plist
  - lib/core/data/busqueda.dart
  - lib/core/router/app_router.dart
  - lib/core/utils/captura_foto.dart
  - lib/core/utils/formato.dart
  - lib/core/widgets/chips/app_filter_chip.dart
  - lib/core/widgets/inputs/app_text_field.dart
  - lib/core/widgets/media/app_photo_picker.dart
  - lib/features/clients/data/repositories/supabase_cliente_repository.dart
  - lib/features/clients/domain/cliente_failure.dart
  - lib/features/clients/domain/entities/cliente.dart
  - lib/features/clients/presentation/clientes_routes.dart
  - lib/features/clients/presentation/providers/clientes_providers.dart
  - lib/features/clients/presentation/screens/cliente_detail_screen.dart
  - lib/features/clients/presentation/screens/clientes_list_screen.dart
  - lib/features/clients/presentation/screens/nuevo_cliente_mascota_screen.dart
  - lib/features/clients/presentation/widgets/vinculacion_sheet.dart
  - lib/features/patients/data/datasources/mascota_foto_datasource.dart
  - lib/features/patients/data/repositories/supabase_mascota_repository.dart
  - lib/features/patients/domain/entities/mascota.dart
  - lib/features/patients/domain/entities/peso_registro.dart
  - lib/features/patients/domain/mascota_failure.dart
  - lib/features/patients/presentation/pacientes_routes.dart
  - lib/features/patients/presentation/providers/mascota_foto_providers.dart
  - lib/features/patients/presentation/providers/mascotas_providers.dart
  - lib/features/patients/presentation/screens/mascota_detail_screen.dart
  - lib/features/patients/presentation/screens/mascota_form_screen.dart
  - lib/features/patients/presentation/screens/pacientes_list_screen.dart
  - lib/features/patients/presentation/widgets/mascota_campos_section.dart
  - lib/features/patients/presentation/widgets/mascota_foto_avatar.dart
  - pubspec.yaml
  - supabase/schema.sql
  - supabase/tests/rls_smoke_test.sql
  - supabase/tests/verify_live_schema.sh
  - test/app_photo_picker_test.dart
  - test/cliente_detail_screen_test.dart
  - test/clientes_list_screen_test.dart
  - test/clientes_providers_test.dart
  - test/formato_test.dart
  - test/helpers/fake_clientes.dart
  - test/helpers/fake_fotos.dart
  - test/helpers/fake_mascotas.dart
  - test/helpers/router_harness.dart
  - test/mascota_detail_screen_test.dart
  - test/mascota_form_screen_test.dart
  - test/mascotas_providers_test.dart
  - test/nuevo_cliente_mascota_screen_test.dart
  - test/pacientes_list_screen_test.dart
  - test/widget_test.dart
findings:
  critical: 0
  warning: 4
  info: 2
  total: 6
status: issues_found
---

# Phase 2: Code Review Report

**Reviewed:** 2026-09-25T00:00:00Z
**Depth:** standard
**Files Reviewed:** 48
**Status:** issues_found

## Summary

Reviewed the Fase 2 "Clientes y Pacientes" implementation: Supabase-backed CRUD for `clientes`/`mascotas`, the atomic `registrar_cliente_con_mascota`/`registrar_mascota` RPCs, the private-Storage camera-first photo pipeline, append-only weight history, and the vet-side account-linking code flow, plus the accompanying schema, RLS smoke test, and widget/provider tests.

**Security/RLS:** `supabase/schema.sql` and `rls_smoke_test.sql` are solid. Every table and the `mascota-fotos` Storage bucket enforce clinic isolation server-side (`es_veterinario()` + `mi_clinica_id()`), the three new RPCs are `security invoker` (RLS still applies inside them) with an explicit vet+clinic guard, the composite FK (`dueno_id, clinica_id) -> clientes(id, clinica_id)`) blocks cross-clinic pet-to-owner assignment even if a vet forges `clinica_id`, and the linking-code column has both a format `check` constraint and a global unique index. The smoke test exercises positive and negative cases (including privilege-escalation attempts on `perfiles`) for all of this. No injection, hardcoded-secret, or auth-bypass issues found in the Dart client code either — `sanitizarBusqueda` correctly strips the two characters (`,` `(` `)`) that would let a search term break out of a PostgREST `.or()` filter, and the two-step dueño-name search only folds already-fetched UUIDs into the `.in.()` clause.

**Client code:** no crashes or data-loss bugs found, but several UI/state-management issues degrade correctness of "what the user sees" without any backend risk (see Warnings below): a missing cache invalidation leaves the Pacientes list stale after the primary combined create flow, invalidating either search provider from an unrelated screen silently drops the user's active search filter, two screens mutate `TextEditingController.text` directly inside `build()` in a way that only avoids crashing by relying on an undocumented Flutter internal detail, and one navigation call breaks the app's own "always `push`" convention. Test coverage for the phase is thorough (search debounce/sequencing, RLS-adjacent repository behavior via fakes, photo upload/cache-key discipline, append-only weight ordering, dirty-state gating on both forms) and no test correctness gaps were found.

## Warnings

### WR-01: Combined create flow never invalidates the Pacientes list

**File:** `lib/features/clients/presentation/screens/nuevo_cliente_mascota_screen.dart:151-156`
**Issue:** After `registrar_cliente_con_mascota` succeeds, `_submit()` only does `ref.invalidate(clientesProvider)`. It never invalidates `mascotasProvider`. Contrast with the equivalent path in `MascotaFormScreen._submitCrear` (`lib/features/patients/presentation/screens/mascota_form_screen.dart:181-185`), which invalidates `mascotasDeClienteProvider`, `clienteProvider`, `clientesProvider`, **and** `mascotasProvider`. Since `NuevoClienteMascotaScreen` is the phase's primary path (D-02) for creating a pet, a vet who has the Pacientes tab already loaded (even in the background `IndexedStack`) will not see the newly created mascota until they manually pull-to-refresh or the app restarts.
**Fix:**
```dart
if (!mounted) return;
ref.invalidate(clientesProvider);
ref.invalidate(mascotasProvider); // add this
ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text('Cliente y mascota guardados')),
);
context.pop();
```

### WR-02: Invalidating the search providers from unrelated screens silently discards the user's active search

**File:** `lib/features/clients/presentation/providers/clientes_providers.dart:28-52`, `lib/features/patients/presentation/providers/mascotas_providers.dart:45-65`
**Issue:** `ClientesNotifier`/`MascotasNotifier` keep the current search term in an instance field (`_query`), read by `build()`. Several unrelated save/edit/photo flows call `ref.invalidate(clientesProvider)` / `ref.invalidate(mascotasProvider)` (e.g. `cliente_detail_screen.dart:133`, `mascota_form_screen.dart:182-185/267`, `mascota_detail_screen.dart:78`). `ref.invalidate` on an `AsyncNotifierProvider` discards the notifier instance and creates a fresh one on next read, so `_query` resets to `''`. The screen's `TextEditingController` (a separate, unrelated piece of state) still displays whatever the user had typed, but the list the provider now returns is the full, **unfiltered** result set — the user sees a search box with text and a list that silently ignores it, until they type another character to re-trigger `search()`.
**Fix:** Either (a) re-issue the current search after invalidation instead of a bare `ref.invalidate`, e.g. expose a `refresh()` on the notifier that re-runs `buscar(_query, ...)` without resetting `_query`, or (b) derive the provider's search term from the screen's controller so invalidation can't diverge from what's visibly typed.

### WR-03: `TextEditingController.text` mutated directly inside `build()`, relying on an undocumented Flutter scoping detail to avoid crashing

**File:** `lib/features/clients/presentation/screens/cliente_detail_screen.dart:72-78,155-159`, `lib/features/patients/presentation/screens/mascota_form_screen.dart:89-98,287-291`
**Issue:** `_llenarControladores()` is called from inside the `data:` callback of `clienteAsync.when(...)`/`mascotaAsync.when(...)`, i.e. synchronously during `build()`. It sets `.text` on several controllers that all have a listener added in `initState()` calling `setState(() {})` (`_onCamposCambiaron`). Mutating `.text` triggers that listener synchronously, which calls `setState()` while the same element is still building. This does not currently throw only because the element calling `setState()` is the one Flutter's `_debugCurrentBuildTarget` scope check considers "in scope" (itself) — a well-known but fragile Flutter internal, not a documented contract. It causes one extra, unnecessary synchronous rebuild every time the initial data arrives, and the pattern will break (throwing "setState() or markNeedsBuild() called during build") the moment this fill logic is refactored into a helper widget, a `didUpdateWidget`, or anything that isn't literally the same State object mid-build.
**Fix:** Populate the controllers as a one-time side effect outside of `build()`, e.g. via `ref.listen(...)` with a guard, or schedule the fill with `WidgetsBinding.instance.addPostFrameCallback` the first time data arrives, instead of doing it inline inside `.when(data: ...)`.

### WR-04: "Dueño" link uses `context.go` instead of the app's `context.push` convention, breaking back-navigation and switching tabs

**File:** `lib/features/patients/presentation/screens/mascota_detail_screen.dart:167`
**Issue:** Every other navigation call in this phase uses `context.push(...)` (`cliente_detail_screen.dart:225,262`, `pacientes_list_screen.dart:178`, `mascota_detail_screen.dart:147`, etc.), preserving the back stack. The "Dueño" row is the sole exception: `onTapValor: ... () => context.go('/clientes/${mascota.duenoId}')`. Since `/pacientes/...` and `/clientes/...` live in different `StatefulShellBranch`es of the same `StatefulShellRoute.indexedStack` (`lib/core/router/app_router.dart:77-102`), `context.go` here switches the active bottom-nav tab to Clientes and replaces navigation history instead of pushing on top of it — a user who taps a pet's owner from the Pacientes tab cannot press back to return to that pet's ficha; they land in the Clientes tab's own stack instead.
**Fix:**
```dart
onTapValor: mascota.duenoNombre == null
    ? null
    : () => context.push('/clientes/${mascota.duenoId}'),
```

## Info

### IN-01: `textoVigencia` produces incorrect Spanish grammar at exactly 1 hour remaining

**File:** `lib/features/clients/presentation/widgets/vinculacion_sheet.dart:14-24`
**Issue:** When `restante` is exactly `Duration(hours: 1)`, the `restante < const Duration(hours: 1)` check is false (not strictly less), so execution falls through to `horas = (restante.inMinutes / 60).ceil()` → `1`, producing `'Válido por 1 horas más'` (should be singular "hora").
**Fix:**
```dart
if (restante <= const Duration(hours: 1)) {
  return 'Válido por menos de 1 hora';
}
```
(or special-case `horas == 1` to return the singular string).

### IN-02: `sanitizarBusqueda` doesn't neutralize SQL `ILIKE` wildcards

**File:** `lib/core/data/busqueda.dart:7-10`
**Issue:** `sanitizarBusqueda` strips `,`/`(`/`)` (the PostgREST `.or()` delimiters — correctly, this is the security-relevant part) but leaves `%` and `_` untouched before they're interpolated into `'$columna.ilike.%$q%'`. A search term containing `%` or `_` changes the `ILIKE` matching semantics (e.g. searching for a literal `%` widens the match instead of searching for that character), which is a minor functional quirk rather than a vulnerability (no query-structure injection is possible), but worth a doc-comment note since the function's own comment implies it fully neutralizes "special" search characters.
**Fix:** Consider escaping `%` and `_` (e.g. `q.replaceAll('%', r'\%').replaceAll('_', r'\_')`) if literal matches on those characters are ever expected, or add a comment clarifying that wildcard leakage is accepted/out of scope.

---

_Reviewed: 2026-09-25T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
