---
phase: 02-clientes-y-pacientes
plan: 05
subsystem: patients
tags: [flutter, riverpod, supabase-storage, image_picker, flutter_image_compress, permission_handler, cached_network_image]

# Dependency graph
requires:
  - phase: 02-clientes-y-pacientes
    plan: 01
    provides: mascota-fotos private bucket + storage.objects RLS, mascotas.foto_path column (all LIVE)
  - phase: 02-clientes-y-pacientes
    plan: 02
    provides: image_picker/flutter_image_compress/permission_handler/cached_network_image installed and pinned, camera/gallery permissions declared
  - phase: 02-clientes-y-pacientes
    plan: 04
    provides: NuevoClienteMascotaScreen, MascotaCamposSection (foto slot), SupabaseMascotaRepository.actualizarFotoPath, mascotaRepositoryProvider, fake_mascotas.dart
provides:
  - "FuenteFoto enum + CapturadorFoto typedef + capturarFotoComprimida (lib/core/utils/captura_foto.dart) — camera-first capture with permission_handler pre-flight and flutter_image_compress before upload"
  - "MascotaFotoDatasource — upload/signedUrlFor(1h)/eliminar against the private mascota-fotos bucket, upload() always returns the object path"
  - "mascotaFotoDatasourceProvider, mascotaFotoUrlProvider, capturadorFotoProvider (test seam) — lib/features/patients/presentation/providers/mascota_foto_providers.dart"
  - "AppPhotoPicker (lib/core/widgets/media/app_photo_picker.dart) — reusable camera-first avatar (placeholder/local preview/cached network photo/uploading states), cacheKey pinned to fotoPath"
  - "NuevoClienteMascotaScreen wired to AppPhotoPicker: photo captured -> compressed -> uploaded after the RPC returns mascotaId -> foto_path persisted; upload failure never blocks the already-saved cliente/mascota"
  - "test/helpers/fake_fotos.dart — FakeMascotaFotoDatasource, kFotoPrueba, capturadorFalso test seam, reusable by Plans 08/09"
affects: [02-08, 02-09, 02-10]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Test seam via a Riverpod Provider<CapturadorFoto> (capturadorFotoProvider) so widget tests never touch image_picker/flutter_image_compress/permission_handler — mirrors the existing repository-provider override pattern"
    - "Always resolve AsyncNotifierProvider values via ref.read(provider.future) when the provider is not watched anywhere else in the widget — ref.read(provider).value alone can race the notifier's build() and silently return null on first access"
    - "cacheKey pinned to the stable Storage object path (never the signed URL) on every CachedNetworkImage construction, enforced via a single static AppPhotoPicker.imagenRed constructor so there is exactly one call site to audit"

key-files:
  created:
    - lib/core/utils/captura_foto.dart
    - lib/features/patients/data/datasources/mascota_foto_datasource.dart
    - lib/features/patients/presentation/providers/mascota_foto_providers.dart
    - lib/core/widgets/media/app_photo_picker.dart
    - test/helpers/fake_fotos.dart
    - test/app_photo_picker_test.dart
  modified:
    - lib/features/clients/presentation/screens/nuevo_cliente_mascota_screen.dart
    - test/nuevo_cliente_mascota_screen_test.dart

key-decisions:
  - "cacheKey test route: the pumped CachedNetworkImage widget-property assertion worked on the first attempt — no MissingPluginException from flutter_cache_manager/path_provider surfaced, so the fallback route (asserting cacheKey only via AppPhotoPicker.imagenRed's pure construction) was not needed. Both routes are covered by tests regardless: one pumped, one pure-construction."
  - "kFotoPrueba/FakeMascotaFotoDatasource contracts specify 'const Uint8List' but Uint8List.fromList has no const constructor — declared as top-level final instead (functionally equivalent single immutable instance for tests)."
  - "Dropped the Tooltip wrapper the UI-SPEC suggested around the camera badge ('Semantics(label...)/tooltip since it is icon-only') — kept only Semantics(label: 'Tomar foto'). Tooltip's own gesture/overlay machinery was the root of an early false lead while debugging a widget-test tap failure; Semantics alone satisfies the CONTRACTS requirement (bySemanticsLabel) and the a11y need without extra overlay complexity."

requirements-completed: [PAT-03]

# Metrics
duration: ~70min
completed: 2026-09-24
---

# Phase 2 Plan 5: Camera-First Photo Capture Summary

**Camera-first `AppPhotoPicker` wired into the combined cliente+mascota alta: one tap opens the camera (no menu), the photo is compressed on-device and uploaded to the private `mascota-fotos` bucket only after `registrar_cliente_con_mascota` returns the real `mascotaId`, with `cacheKey` pinned to the stable `foto_path` everywhere a cached photo is rendered.**

## Performance

- **Duration:** ~70 min
- **Tasks:** 3 of 3 completed
- **Files modified:** 8 (6 created, 2 modified)

## Accomplishments

- `captura_foto.dart`: `capturarFotoComprimida` implements the full D-05 flow — `Permission.camera` pre-flight (request if denied), an explanatory `AlertDialog` + `openAppSettings()` if permanently denied/restricted, `ImagePicker().pickImage` (camera or gallery), then `FlutterImageCompress.compressWithFile` before upload (falling back to the raw file bytes if compression returns null).
- `MascotaFotoDatasource`: `upload`/`signedUrlFor(1h)`/`eliminar` against the private `mascota-fotos` bucket (live since Plan 01) — `upload()` always returns the object path, never the signed URL, matching the two-tier error-handling shape already established by `SupabaseMascotaRepository`.
- `mascota_foto_providers.dart`: `mascotaFotoDatasourceProvider`, `mascotaFotoUrlProvider` (`autoDispose.family`), and `capturadorFotoProvider` — the last one is the test seam, defaulting to the real `capturarFotoComprimida` and overridden in every test with `capturadorFalso`.
- `AppPhotoPicker`: circular avatar with a strict content priority (`localBytes` > `fotoPath`+`signedUrl` via `cacheKey: fotoPath` > paw placeholder), a directly-tappable camera badge (no intermediate menu/sheet), an `isUploading` dimmed+spinner state, and a secondary "Elegir de galería" text action shown only when `onElegirGaleria` is supplied.
- `NuevoClienteMascotaScreen`: the photo picker now sits in `MascotaCamposSection`'s `foto` slot; capturing a photo just updates local preview state, and only after `registrarClienteConMascota` succeeds does the screen upload the photo (using the real `mascotaId`) and call `actualizarFotoPath` — an upload failure shows a snackbar but the cliente/mascota records (already saved) are never rolled back or blocked.
- Fixed a real bug found via TDD: reading `ref.read(authProfileProvider).value?.clinicaId` on a provider never watched elsewhere in this screen raced the `AsyncNotifier`'s `build()` and returned `null` on first access, silently skipping every photo upload. Switched to `await ref.read(authProfileProvider.future)`.

## Task Commits

1. **Task 1: Failing tests for the camera-first picker and photo upload in the alta (RED)** - `26dd6c3` (test)
2. **Task 2: Capture helper, Storage datasource, photo providers and AppPhotoPicker (GREEN for picker test)** - `5e657f7` (feat)
3. **Task 3: Wire the photo into the combined alta (GREEN for alta test)** - `c7f9443` (feat)

_TDD plan: RED → GREEN → GREEN, with one additional in-place fix (Tooltip removal + clinicaId race) folded into the Task 3 commit once discovered during the GREEN run — see Deviations._

## Files Created/Modified

- `lib/core/utils/captura_foto.dart` - `FuenteFoto`, `CapturadorFoto`, `capturarFotoComprimida`
- `lib/features/patients/data/datasources/mascota_foto_datasource.dart` - Storage-only datasource (upload/signedUrlFor/eliminar)
- `lib/features/patients/presentation/providers/mascota_foto_providers.dart` - datasource/URL/capturador providers
- `lib/core/widgets/media/app_photo_picker.dart` - reusable camera-first avatar widget
- `test/helpers/fake_fotos.dart` - `FakeMascotaFotoDatasource`, `kFotoPrueba`, `capturadorFalso`
- `test/app_photo_picker_test.dart` - widget tests for the picker (placeholder, cacheKey, camera-first tap, galería, uploading/preview states)
- `lib/features/clients/presentation/screens/nuevo_cliente_mascota_screen.dart` - wired `AppPhotoPicker`, `_capturar`, post-create upload
- `test/nuevo_cliente_mascota_screen_test.dart` - extended with 3 new alta cases + `ensureVisible` fixes for pre-existing chip taps

## Decisions Made

- Followed the plan's exact CONTRACTS (enum/typedef/class/provider/widget signatures) verbatim so Plans 08/09 can depend on them unchanged.
- `kFotoPrueba` declared `final` instead of `const` (see key-decisions) — `Uint8List.fromList` has no const constructor.
- Kept the `capturadorFotoProvider` test seam as a plain `Provider<CapturadorFoto>` (not a family) — one capture flow, no per-mascota parameterization needed.
- `MascotaFotoDatasource.eliminar` implemented now (per CONTRACTS) even though no caller exists yet this plan — Plan 08 (change photo from ficha) will use it to remove the superseded object.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `ref.read(authProfileProvider).value?.clinicaId` returned null on first access**
- **Found during:** Task 3, running the alta's new "con foto" test (GREEN)
- **Issue:** `authProfileProvider` is never `ref.watch`'d anywhere else in `NuevoClienteMascotaScreen`. The first `ref.read` of an `AsyncNotifierProvider` returns the provider's *current* state synchronously without awaiting `build()` — since nothing had warmed the provider yet, `.value` was `null` even though the fake profile (`clinicaId: 'cli-1'`) was configured, so the photo upload was silently skipped every time.
- **Fix:** Changed to `final clinicaId = (await ref.read(authProfileProvider.future))?.clinicaId;`, which awaits the notifier's build() Future and is correct regardless of whether any ancestor widget already watches the provider.
- **Files modified:** `lib/features/clients/presentation/screens/nuevo_cliente_mascota_screen.dart`
- **Verification:** `flutter test test/nuevo_cliente_mascota_screen_test.dart` — the "con foto" and "si subir la foto falla" cases now pass; full suite green (73/73).
- **Committed in:** `c7f9443` (Task 3 commit)

**2. [Rule 1 - Bug] Dropped `Tooltip` around the camera badge**
- **Found during:** Task 3, while diagnosing a widget-test tap-hit-test warning (later found to be a red herring unrelated to the actual failure above)
- **Issue:** The UI-SPEC's phrasing ("`Semantics(label: "Tomar foto")`/tooltip since it is icon-only") was implemented literally as `Semantics(child: Tooltip(...))`. This added an extra overlay/gesture layer with no functional requirement behind it — the CONTRACTS section only requires the badge to be findable via `bySemanticsLabel('Tomar foto')`, which `Semantics` alone satisfies.
- **Fix:** Removed the `Tooltip` wrapper, kept `Semantics(label: 'Tomar foto', child: <badge Container>)`.
- **Files modified:** `lib/core/widgets/media/app_photo_picker.dart`
- **Verification:** `flutter test test/app_photo_picker_test.dart` (camera-badge/Semantics-label case) passes; `grep -q "cacheKey: fotoPath"` and the no-bottom-sheet/no-dialog gate still pass.
- **Committed in:** `c7f9443` (Task 3 commit)

**3. [Rule 1 - Bug] Pre-existing Plan 04 chip taps needed `ensureVisible` added**
- **Found during:** Task 3, running the full `nuevo_cliente_mascota_screen_test.dart` suite after wiring the photo picker
- **Issue:** `AppPhotoPicker` (with its "Elegir de galería" secondary button) added enough vertical height above the especie chips that `tester.tap(find.text('Perro'/'Gato'))` calls that previously worked without scrolling started landing off the default 800x600 test viewport.
- **Fix:** Added `await tester.ensureVisible(...)` immediately before every tap on a species chip (in `_llenarCamposRequeridos` and the two tests that tap chips directly), plus a taller test-surface override (`tester.view.physicalSize`) for the two new photo-upload test cases that also tap the camera badge. Plan 04's test *assertions* and *scenarios* are unchanged — only the scroll/visibility mechanics needed to reach the same widgets were added.
- **Files modified:** `test/nuevo_cliente_mascota_screen_test.dart`
- **Verification:** Full suite green, including all pre-existing Plan 04 cases, after the fix.
- **Committed in:** `c7f9443` (Task 3 commit)

---

**Total deviations:** 3 auto-fixed (2 bugs in new code, 1 test-mechanics fix required by the new UI's added height). No architectural changes, no scope creep.
**Impact on plan:** All three were necessary for correctness (the clinicaId fix is the only one that would have caused a real, silent runtime failure — photos would never have uploaded from any real device either, since no other screen in this phase currently watches `authProfileProvider` ahead of `NuevoClienteMascotaScreen` mounting).

## Issues Encountered

- Spent significant investigation time on a widget-test tap "would not hit test" warning that turned out to be an unrelated, non-fatal diagnostic (Flutter's `tap()` still dispatches the event even when the warning fires); the actual failure cause was the `clinicaId` race described in Deviation 1. The taller test-surface change and the `Tooltip` removal were both applied during this investigation; only the `ensureVisible` additions turned out to be strictly necessary going forward, but all three are harmless and are kept.

## User Setup Required

None - no external service configuration required (uses the same live Supabase project, `mascota-fotos` bucket, and packages already installed/verified in Plans 01/02).

## Next Phase Readiness

- PAT-03 (upload half) done: pet photo captured camera-first, compressed, stored in the private bucket, path persisted via `actualizarFotoPath`.
- D-05 honoured: one tap on the avatar opens the camera directly; "Elegir de galería" is a clearly secondary text action.
- `AppPhotoPicker`, `MascotaFotoDatasource`, `mascotaFotoDatasourceProvider`/`mascotaFotoUrlProvider`/`capturadorFotoProvider`, `captura_foto.dart`, and `test/helpers/fake_fotos.dart` are now stable contracts — Plan 08 (change photo from the ficha, using `eliminar` to remove the superseded object) and Plan 09 (standalone `MascotaFormScreen`, reusing the same `foto` slot) build directly on top of them without renaming anything.
- No blockers. `lib/features/clients/presentation/screens/nuevo_cliente_mascota_screen.dart` was touched again in this wave (previously Plan 04); no conflicts expected since this wave's sibling plans (02-06, 02-07) do not touch this file.

## Self-Check

- `lib/core/utils/captura_foto.dart`: FOUND (contains `openAppSettings`, `ImageSource.camera`)
- `lib/features/patients/data/datasources/mascota_foto_datasource.dart`: FOUND (contains `createSignedUrl(path, 3600)`)
- `lib/features/patients/presentation/providers/mascota_foto_providers.dart`: FOUND (exports `mascotaFotoDatasourceProvider`, `mascotaFotoUrlProvider`, `capturadorFotoProvider`)
- `lib/core/widgets/media/app_photo_picker.dart`: FOUND (contains `cacheKey: fotoPath`, no `showModalBottomSheet`/`showDialog`)
- `test/helpers/fake_fotos.dart`: FOUND (`implements MascotaFotoDatasource`)
- `test/app_photo_picker_test.dart`: FOUND, 6/6 passing
- `lib/features/clients/presentation/screens/nuevo_cliente_mascota_screen.dart`: FOUND (contains `capturadorFotoProvider`, `actualizarFotoPath`)
- Commit `26dd6c3` (Task 1): FOUND in `git log --oneline`
- Commit `5e657f7` (Task 2): FOUND in `git log --oneline`
- Commit `c7f9443` (Task 3): FOUND in `git log --oneline`
- `flutter analyze`: No issues found
- `flutter test` (full suite): 73/73 passed

## Self-Check: PASSED

---
*Phase: 02-clientes-y-pacientes*
*Completed: 2026-09-24*
