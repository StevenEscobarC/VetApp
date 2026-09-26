---
phase: 02-clientes-y-pacientes
audited: 2026-09-25
asvs_level: 1
block_on: none-declared-use-default
threats_total: 36
threats_closed: 36
threats_open: 0
status: SECURED
---

# Phase 2 — Security Audit: Clientes y Pacientes

Verifies every threat declared across the 10 plan files' `<threat_model>` blocks against the
implemented code (`supabase/schema.sql`, `supabase/tests/rls_smoke_test.sql`,
`supabase/tests/verify_live_schema.sh`, `lib/**`, `pubspec.yaml`/`.lock`,
`android/app/src/main/AndroidManifest.xml`, `README.md`) and the validation record
(`02-VALIDATION.md`, `02-REVIEW.md`, `02-0X-SUMMARY.md`). Recurring threat IDs
(`T-02-STOR`, `T-02-VINC`, `T-02-FK`, `T-02-PESO`) are the same trust boundary touched at
multiple implementation sites and are verified once, across all sites, below.

No implementation file was modified during this audit. Findings that are genuinely open
would be BLOCKER-level per this project's adversarial-audit contract; there are none.

## Threat Verification

| Threat ID | Category | Disposition | Evidence |
|---|---|---|---|
| T-02-STOR | Info. Disclosure | mitigate | `supabase/schema.sql:416-455` — private bucket (`public=false`), 4 policies (`select`/`insert`/`update`/`delete`) all keyed on `(storage.foldername(name))[1] = public.mi_clinica_id()::text`. Smoke checks D16-D18, E3, F3, F4 present and exercised (`supabase/tests/rls_smoke_test.sql:476-504,523-531,565-583`); `02-01-SUMMARY.md:68` records live `RLS SMOKE: PASS (53 checks)` on the real project, bucket confirmed private via dashboard screenshot. Reinforced at upload/read (`lib/features/patients/data/datasources/mascota_foto_datasource.dart:22-62`, path prefix = `clinicaId` from `authProfileProvider`/RLS-filtered row, never user input; signed URL 3600s, never persisted) and at device UAT step 2-4/11-12 (`02-10-SUMMARY.md:66,71`, no cross-clinic photo exposure observed). |
| T-02-VINC | Info. Disclosure / Tampering | mitigate | `supabase/schema.sql:359-412` — `generar_codigo_vinculacion` is `security invoker` with explicit `es_veterinario()` guard, 6-digit format check (`schema.sql:210-211`), global partial unique index (`schema.sql:218`), 24h expiry logic (`schema.sql:392-393`). Smoke D10-D15, E2, E4 present and green (`rls_smoke_test.sql:402-458,518-521,533-541`). Client never writes the code (`lib/features/clients/data/repositories/supabase_cliente_repository.dart:83-107` whitelist excludes `codigo_vinculacion`/`codigo_expira_en`/`perfiles_id`). |
| T-02-RPC | Elev. of Privilege | mitigate | All 3 RPCs `security invoker` + explicit `if not public.es_veterinario() ... raise exception ... insufficient_privilege` guard (`schema.sql:288-289,332-333,371-373`) + `revoke all ... from public, anon` / `grant ... to authenticated` (`schema.sql:309-310,349-350,411-412`). Smoke D7-D9 (positive) and F2 (anon-role rejection) present and green (`rls_smoke_test.sql:365-400,555-563`). `verify_live_schema.sh:68-98` probes all 3 RPCs as `anon`, asserting 401/403. |
| T-02-FK | Tampering | mitigate | Composite FK `mascotas_dueno_misma_clinica_fkey (dueno_id, clinica_id) -> clientes(id, clinica_id)` (`schema.sql:69-70`). Smoke D8/A15 assert `foreign_key_violation` on cross-clinic dueño (`rls_smoke_test.sql:205-214,382-390`). Reinforced in `registrar_mascota` (Plan 09 threat re-touch): `clinica_id` forced to `mi_clinica_id()` server-side, never client-supplied (`supabase_mascota_repository.dart:160-188` — no `clinicaId`/`clinica_id` param in `registrarMascota`). |
| T-02-PESO | Repudiation / Tampering | mitigate | `mascota_pesos` has only `select`/`insert` RLS policies, no `update`/`delete` policy exists (`schema.sql:242-263`); `check (peso_kg > 0)` (`schema.sql:232`). Smoke D4-D6 assert 0 rows affected on update/delete and `check_violation` on peso 0 (`rls_smoke_test.sql:343-363`). Client-side: `SupabaseMascotaRepository` exposes only `pesos()`/`registrarPeso()`, no update/delete method (`supabase_mascota_repository.dart:257-295`); edit form omits the peso field (`mascota_form_screen.dart:339` — `pesoController: esEdicion ? null : _pesoCtrl`). |
| T-02-09 | Repudiation/Tampering | mitigate | `rls_smoke_test.sql:591-596` — script unconditionally ends in `raise exception 'RLS SMOKE: PASS/FAIL ...'`, guaranteeing rollback of every insert (including `storage.objects` seeds) regardless of outcome. |
| T-02-10 | Spoofing | mitigate | `reclamar_codigo_cliente` absent from `supabase/schema.sql` (only referenced inside a comment, `schema.sql:457-459`) and absent from `lib/**` (0 matches). Deferred to Phase 9 per `02-01-SUMMARY.md:39`. |
| T-02-11 | Info. Disclosure | mitigate | `verify_live_schema.sh:12,40-98` — every `curl` call uses `-o /dev/null -w '%{http_code}'`; the script only ever echoes `OK`/`FAIL <status>` lines, never the key value. Key sourced from gitignored `dart_define.json` (`verify_live_schema.sh:21-29`), never committed. |
| T-02-SC | Tampering | mitigate | `02-02-SUMMARY.md:56-58` — human legitimacy checkpoint run before install, user approved exact pins ("sí, apruébalos"); re-confirmed for the narrower `permission_handler` downgrade. `pubspec.yaml:42-45` shows exact caret pins; `pubspec.lock` committed with resolved shas. |
| T-02-12 | Elev. of Privilege | mitigate | `android/app/src/main/AndroidManifest.xml:2-3` — only `CAMERA` and `INTERNET` declared; no `READ_EXTERNAL_STORAGE`/`READ_MEDIA_IMAGES` (system photo picker used for gallery per `captura_foto.dart:40-47`, `ImageSource.gallery` via `image_picker`). |
| T-02-13 | Denial of Service | mitigate | `pubspec.yaml:45` pins `cached_network_image: ^3.4.1`; `pubspec.lock:83` resolves `version: "3.4.1"` (confirmed 3.x, not the Dart-3.11-incompatible 4.x line). |
| T-02-14 | Tampering | mitigate | `lib/core/data/busqueda.dart:12-15` — `sanitizarBusqueda` strips `,`/`(`/`)` via regex before any `.or()` interpolation; used by `filtroOrIlike` (`busqueda.dart:25-38`), consumed by `SupabaseClienteRepository.buscar` (`supabase_cliente_repository.dart:39-45`). Unit-tested per `02-VALIDATION.md:46`. |
| T-02-15 | Info. Disclosure | mitigate | `supabase_cliente_repository.dart:35-38` — `buscar()` adds `.eq('clinica_id', clinicaId)` sourced from `authProfileProvider` (signed-in profile), never from user input, on top of the enforcing vet-only `clientes` RLS (`schema.sql:163-165`). |
| T-02-16 | Denial of Service | mitigate | `clientes_providers.dart:33,61-80` — 350ms `Timer` debounce plus `_sequence` monotonic counter that discards stale responses (`if (!ref.mounted || sequence != _sequence) return;`). |
| T-02-17 | Info. Disclosure | mitigate | `supabase_cliente_repository.dart:161-176` — `_messageFor` maps `PostgrestException.code` to fixed Spanish strings; generic `catch (_)` never surfaces `e.message`/SDK text. |
| T-02-18 | Tampering | mitigate | Client: `lib/core/utils/formato.dart:17-58` — `parsearFecha` (strict `dd/MM/yyyy`, real-calendar-day check, rejects future dates) and `parsearPeso` (`0 < x < 1000`); especie always sent as `mascotaEspecie.name` (enum). Server backstop: `check (peso_kg > 0)` (`schema.sql:232`), `check (length(trim(nombre)) > 0)` on `clientes`/`mascotas` (`schema.sql:34,64`). |
| T-02-19 | Tampering | mitigate | `registrar_cliente_con_mascota` is one atomic RPC (`schema.sql:269-307`) — cliente+mascota+peso in a single call, no sequential inserts from Dart. `test/nuevo_cliente_mascota_screen_test.dart:220` — `expect(repo.registros, hasLength(1))` asserts exactly one repository call per submit. |
| T-02-20 | Elev. of Privilege | mitigate | `schema.sql:284,329` — `v_clinica_id uuid := public.mi_clinica_id()` computed server-side inside the RPC; `supabase_mascota_repository.dart:59-72,160-188` — neither `registrarClienteConMascota` nor `registrarMascota`'s `params` map includes a `clinica_id` key. |
| T-02-21 | Info. Disclosure | mitigate | `supabase_mascota_repository.dart:325-338` — `_messageFor` fixed Spanish copy by `PostgrestException.code`; generic catch-all fallback never surfaces raw text. |
| T-02-22 | Info. Disclosure | mitigate | `mascota_foto_datasource.dart:22-40` — `upload()` returns the object `path` string; `actualizarFotoPath` persists that path, never a signed URL (`supabase_mascota_repository.dart:221-236`). |
| T-02-23 | Denial of Service | mitigate | `lib/core/utils/captura_foto.dart:43-56` — `ImagePicker().pickImage(imageQuality: 85, maxWidth: 1600)` then `FlutterImageCompress.compressWithFile(minWidth: 1024, minHeight: 1024, quality: 80, format: jpeg)` before any upload. |
| T-02-24 | Tampering | **accept** | Accepted-risk log entry below. Compensating controls present: bucket is private + clinic-scoped RLS (`schema.sql:420-455`); `contentType: 'image/jpeg'` forced on every upload (`mascota_foto_datasource.dart:35-38`); only the uploading clinic's `authenticated` vet can ever read the object. |
| T-02-25 | Elev. of Privilege | mitigate | `captura_foto.dart:27-38` — `Permission.camera.status`/`.request()` pre-flight before opening the camera; `isPermanentlyDenied`/`isRestricted` routes to `_mostrarDialogoPermisoDenegado` → `openAppSettings()` instead of re-prompting. |
| T-02-26 | Tampering | mitigate | `buscarMascotasEnDosPasos` (`supabase_mascota_repository.dart:18-33`) calls `sanitizarBusqueda`/`filtroOrIlike` (same shared helper as T-02-14); owner ids folded into `.in.()` are DB-sourced UUIDs from `resolverDuenos`, never raw user text (`supabase_mascota_repository.dart:94-110`). |
| T-02-27 | Info. Disclosure | mitigate | Both queries in `buscar()` add `.eq('clinica_id', clinicaId)` (`supabase_mascota_repository.dart:99,116`), on top of the enforcing `clientes`/`mascotas` RLS. |
| T-02-28 | Denial of Service | mitigate | `resolverDuenos` caps at `.limit(50)` (`supabase_mascota_repository.dart:101`); `MascotasNotifier` mirrors the same 350ms debounce + sequence guard as `ClientesNotifier` (`mascotas_providers.dart:50,80-89`). |
| T-02-29 | Tampering | mitigate | `SupabaseClienteRepository.actualizar` (`supabase_cliente_repository.dart:83-107`) sends only `nombre`/`telefono`/`email`/`direccion`/`notas`; no `clinica_id`, `perfiles_id`, or code columns in the update payload. Enforced further by `clientes_update` RLS (`schema.sql:171-174`). |
| T-02-30 | Info. Disclosure | **accept** | Accepted-risk log entry below. Compensating controls present: explicit vet tap required (`vinculacion_sheet.dart:87-95` `_copiar()`), no external messaging integration wired (per Plan 07's negative grep gate, `02-07-SUMMARY.md:107-112`), code expires in 24h (`schema.sql:393`, surfaced via `textoVigencia`, `vinculacion_sheet.dart:14-24`). |
| T-02-31 | Elev. of Privilege | mitigate | `reclamar_codigo_cliente` — 0 matches anywhere in `lib/` (grep confirmed). Claim flow deferred to Phase 9 per plan. |
| T-02-32 | Tampering | mitigate | `mascota_detail_screen.dart:67-74` — `fotoAnterior = mascota.fotoPath` is read from the already-loaded, RLS-filtered `mascota` object (via `mascotaProvider`/`obtener()`), never from a user-suppliable parameter, before calling `MascotaFotoDatasource.eliminar`. Best-effort failure is swallowed intentionally (comment cites T-02-32 directly). Storage `delete` RLS additionally restricts to the caller's own clinic prefix (`schema.sql:449-455`). |
| T-02-33 | Info. Disclosure | **accept** | Accepted-risk log entry below. Compensating control: `mascota.duenoId` originates from the RLS-filtered `mascotas` row (`supabase_mascota_repository.dart:240-255,310`); the destination `ClienteDetailScreen` route is itself protected by the same vet-only `clientes` RLS. |
| T-02-34 | Tampering | mitigate | `SupabaseMascotaRepository.actualizar` (`supabase_mascota_repository.dart:194-217`) sends only `nombre`/`especie`/`raza`/`fecha_nacimiento`; `dueno_id`/`clinica_id`/`foto_path` never included. Enforced further by `mascotas_update` RLS (`schema.sql:189-192`). |
| T-02-35 | Repudiation | mitigate | `mascota_form_screen.dart:339` — `pesoController: esEdicion ? null : _pesoCtrl`; the peso field is not rendered at all in edit mode, only via `registrarPeso` (append-only). |
| T-02-36 | Tampering | mitigate | Every call site sends `especie.name`/`mascota.especie.name` (an `Especie` enum value), never a free-text string — confirmed across `registrarClienteConMascota`, `registrarMascota`, and `actualizar` (`supabase_mascota_repository.dart:65,172,200`). |
| T-02-37 | Info. Disclosure | mitigate | `README.md` — no `eyJ` substring present (grep confirmed); `02-10-SUMMARY.md:61,116` records the same check ("CONFIRMED"). Key only ever lives in gitignored `dart_define.json`. |
| T-02-38 | Tampering | **accept** | Accepted-risk log entry below. `02-10-SUMMARY.md:37-39,71` — dev-only project (`apjonrmhkpyzbofupokb`), no real users yet; UAT/smoke residue is deletable from the dashboard; the automated smoke test itself (T-02-09) always rolls back — only the *manual* device-UAT records persist, by design, until manually cleared. |

## Accepted Risks Log

| Threat ID | Risk | Justification | Owner |
|---|---|---|---|
| T-02-24 | Non-image bytes could theoretically be uploaded to `mascota-fotos` despite the app forcing `content-type: image/jpeg` on every upload (a client can send any bytes with a forged content-type header). | Bucket is private and RLS-scoped to the uploading clinic only (`schema.sql:420-455`); blast radius is limited to that clinic's own storage, not a cross-tenant or public exposure. Accepted at ASVS Level 1. | Project owner (stevenescobaraw@gmail.com) |
| T-02-30 | The 6-digit vinculación code is exposed to the OS clipboard when the vet taps "Copiar código," where any other app with clipboard read access could observe it during its 24h validity window. | Requires an explicit vet action to expose; no external messaging integration reads it automatically; window is time-boxed to 24h and the code is single-purpose (account linking only, no PII/financial access). Accepted at ASVS Level 1. | Project owner (stevenescobaraw@gmail.com) |
| T-02-33 | `MascotaDetailScreen`'s "Dueño" link navigates using `mascota.duenoId` taken from an already-fetched row, without re-validating clinic ownership at the navigation layer itself. | The value's provenance is exclusively the RLS-filtered `mascotas` row (server already proved the caller's clinic owns it), and the destination screen (`ClienteDetailScreen`) is independently protected by the same vet-only `clientes` RLS — a forged `duenoId` would simply 404/RLS-empty, not leak cross-clinic data. Accepted at ASVS Level 1. | Project owner (stevenescobaraw@gmail.com) |
| T-02-38 | End-to-end device UAT (Plan 10) created real client/mascota/photo records in the live cloud project `apjonrmhkpyzbofupokb`, which are not auto-rolled-back the way the SQL smoke test (T-02-09) is. | Project has no real users yet (pre-launch, dev-only); test records are identifiable and deletable via the Supabase dashboard at any time before real users are onboarded. Accepted at ASVS Level 1. | Project owner (stevenescobaraw@gmail.com) |

## Unregistered Flags

None. Only `02-02-SUMMARY.md` contains an explicit `## Threat Flags` section, and it maps
cleanly to already-registered `T-02-SC`/`T-02-12`/`T-02-13` (no new surface). The other 9
`02-0X-SUMMARY.md` files carry no `## Threat Flags` section; their `## Deviations from Plan`
sections were reviewed individually and contain only test-flakiness/doc-comment/tooling
fixes (Riverpod async-race fixes, grep-gate false positives from doc comments, Windows
plugin-registrant churn, worktree branch resets) — none introduce new attack surface.

`02-REVIEW.md` (independent code review, 48 files, 2026-09-25) found 0 critical and 0
security-classified issues; its 4 warnings (WR-01..04) are UI-state/navigation correctness
bugs with explicitly no backend/security risk per the reviewer's own summary. Its 2 info
items are notable but do not reopen any threat above:
- **IN-02** (`sanitizarBusqueda` doesn't neutralize `ILIKE` wildcards `%`/`_`) — this is a
  documented, accepted functional quirk already called out in the function's own doc
  comment (`busqueda.dart:8-11`: "no permite alterar la estructura del filtro, no es un
  problema de seguridad"). T-02-14/T-02-26's mitigation claim is specifically about
  preventing `.or()` structural injection via `,`/`(`/`)`, which IN-02 does not affect —
  it changes match breadth, not query structure. Recorded here for completeness, not as
  an open threat.
- **IN-01** (grammar bug in `textoVigencia` at exactly 1h remaining) — cosmetic, no
  security relevance to T-02-VINC/T-02-30.

## Summary

**Threats Closed:** 36/36
**ASVS Level:** 1
**Disposition breakdown:** 32 mitigate (all closed with code+SQL+test evidence), 4 accept
(all logged above with compensating controls and explicit owner sign-off point).

All three RLS/RPC-boundary threats with live-database evidence (`T-02-STOR`, `T-02-VINC`,
`T-02-RPC`, `T-02-FK`, `T-02-PESO`) were verified not only via source (schema.sql,
rls_smoke_test.sql) but via the recorded live-project execution: `RLS SMOKE: PASS
(53 checks)` (`02-01-SUMMARY.md:68`) and a 12-step device UAT approved against the same
live project (`02-VALIDATION.md:93`, `02-10-SUMMARY.md:65-72`).
