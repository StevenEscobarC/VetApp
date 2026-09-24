---
phase: 2
slug: clientes-y-pacientes
status: planned
nyquist_compliant: true
wave_0_complete: false
created: 2026-09-24
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (already used since Phase 1) |
| **Config file** | none — no dedicated test config exists |
| **Quick run command** | `flutter test test/clientes_providers_test.dart test/mascotas_providers_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~20-30 seconds (growing suite) |

---

## Sampling Rate

- **After every task commit:** Run `flutter analyze` + the task's own `<automated>` command (each plan names its slice's test files; `mascotas_providers_test.dart` only exists from Plan 06 on)
- **After every plan wave:** Run `flutter test` (full suite)
- **Before `/gsd:verify-work`:** Full suite must be green, and the extended RLS manual smoke test (clientes/mascotas/mascota_pesos/storage.objects, positive + negative) must be run and recorded
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

Plan/task IDs are assigned by the planner — this table maps each phase requirement to its verification method.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-T1/T2 | 01 | 1 | CLI-01, CLI-05, PAT-01, PAT-03, PAT-05 | T-02-STOR, T-02-VINC, T-02-RPC, T-02-PESO | Schema delta + smoke test files well-formed (grep gates) | static gate | see 02-01 Task 1/2 `<automated>` (SCHEMA2_OK / SMOKE2_FILES_OK) | ✅ (edits existing files) | ⬜ pending |
| 02-01-T3 | 01 | 1 | all | T-02-STOR, T-02-VINC | Delta live; anon refused on RPCs | probe + manual | `bash supabase/tests/verify_live_schema.sh` (LIVE_SCHEMA_OK) | ✅ | ⬜ pending |
| 02-02-T2 | 02 | 1 | PAT-03 | T-02-SC | Pinned packages resolve (cached_network_image 3.x) | static gate | `flutter analyze && flutter test` (DEPS_OK) | ✅ | ⬜ pending |
| 02-03-T1..T3 | 03 | 1 | CLI-03 | T-02-14, T-02-16 | Debounced search: 1 call 350 ms after last keystroke; `.or()` input sanitized | unit + widget (fake repository) | `flutter test test/clientes_providers_test.dart test/clientes_list_screen_test.dart` | ❌ Wave 0 (created in 02-03-T1) | ⬜ pending |
| 02-04-T1..T3 | 04 | 2 | CLI-01, PAT-01 | T-02-18, T-02-19 | Combined alta: 4 required fields gate submit; exactly one atomic RPC call; dd/mm/aaaa + comma kg parsing | widget + unit (fake repository) | `flutter test test/nuevo_cliente_mascota_screen_test.dart test/formato_test.dart` | ❌ Wave 0 (created in 02-04-T1) | ⬜ pending |
| 02-05-T1..T3 | 05 | 3 | PAT-03 | T-02-STOR, T-02-22 | Camera-first tap; upload after create returns stable path stored via actualizarFotoPath; `CachedNetworkImage.cacheKey` = foto_path | widget (asserts widget props, fake datasource) | `flutter test test/app_photo_picker_test.dart test/nuevo_cliente_mascota_screen_test.dart` | ❌ Wave 0 (created in 02-05-T1) | ⬜ pending |
| 02-06-T1..T3 | 06 | 3 | PAT-04 | T-02-26 | Owner-name search resolves owner ids BEFORE querying mascotas (call-order assertion on `buscarMascotasEnDosPasos`); chips filter client-side without re-query | unit + widget | `flutter test test/mascotas_providers_test.dart test/pacientes_list_screen_test.dart` | ❌ Wave 0 (created in 02-06-T1) | ⬜ pending |
| 02-07-T1..T3 | 07 | 3 | CLI-02, CLI-04, CLI-05 | T-02-VINC, T-02-29 | Ficha edit persists; lists only that cliente's mascotas; link code sheet shows/copies 6-digit 24 h code, reuses unexpired code | widget (fake repositories, clipboard mock) | `flutter test test/cliente_detail_screen_test.dart` | ❌ Wave 0 (created in 02-07-T1) | ⬜ pending |
| 02-08-T1..T3 | 08 | 4 | PAT-02, PAT-03, PAT-05 | T-02-PESO, T-02-STOR | Weight history newest-first, append-only (no edit/delete affordance); photo replace uploads + updates path + best-effort delete; cacheKey = foto_path | widget (fake repository + datasource) | `flutter test test/mascota_detail_screen_test.dart test/pacientes_list_screen_test.dart` | ❌ Wave 0 (created in 02-08-T1) | ⬜ pending |
| 02-09-T1..T3 | 09 | 5 | PAT-01, PAT-02 | T-02-FK, T-02-34 | D-03: new pet for existing owner never re-asks owner data; edit form persists, no peso field in edit | widget (real route trees + fakes) | `flutter test test/mascota_form_screen_test.dart` | ❌ Wave 0 (created in 02-09-T1) | ⬜ pending |
| 02-10-T1 | 10 | 6 | all | T-02-37 | Full suite + analyzer + live probe green | full suite | `flutter analyze && flutter test` | ✅ | ⬜ pending |
| 02-01-T3 | 01 | 1 | PAT-03 | T-02-STOR | Cross-tenant Storage object read/write blocked (Vet A cannot touch Vet B's prefix) | manual (SQL Editor smoke D16-D18, E3, F3, F4; fallback UAT step 11) | n/a — extended RLS smoke test | n/a | ⬜ pending |
| 02-01-T3 | 01 | 1 | CLI-01..05, PAT-01..05 | T-02-RPC, T-02-PESO, T-02-VINC | RLS on `clientes`/`mascotas`/`mascota_pesos` + RPCs blocks cross-clinic access as `authenticated` (53 checks) | manual (SQL Editor, extends Phase 1 script) | n/a — extended RLS smoke test | n/a | ⬜ pending |
| 02-10-T2 | 10 | 6 | CLI-01..05, PAT-01..05 | — | End-to-end device UAT against live project (camera, Storage, signed URLs, debounce feel) | manual | n/a — UAT checklist in 02-10-PLAN | n/a | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Each vertical slice creates its own failing tests as its Task 1 (MVP mode: failing test first), before any production code of that slice.

- [ ] `test/helpers/fake_clientes.dart` (02-03-T1), `test/helpers/fake_mascotas.dart` (02-04-T1) — fakes mirroring `fake_auth.dart`'s shape (+ `test/helpers/router_harness.dart` 02-03-T1, `test/helpers/fake_fotos.dart` 02-05-T1)
- [ ] `test/clientes_providers_test.dart` (02-03-T1), `test/mascotas_providers_test.dart` (02-06-T1) — cover CLI-03, PAT-04 (+ `clientes_list_screen_test.dart`, `pacientes_list_screen_test.dart`)
- [ ] `test/cliente_detail_screen_test.dart` (02-07-T1), `test/mascota_detail_screen_test.dart` (02-08-T1) — cover CLI-02/04/05, PAT-02/03/05
- [ ] Additional slice tests: `test/nuevo_cliente_mascota_screen_test.dart` + `test/formato_test.dart` (02-04-T1, CLI-01/PAT-01), `test/app_photo_picker_test.dart` (02-05-T1, PAT-03), `test/mascota_form_screen_test.dart` (02-09-T1, PAT-01/PAT-02)
- [ ] No framework install needed — `flutter_test` already present; do NOT import `package:fake_async` (undeclared → `depend_on_referenced_packages`); debounce tests use the `testWidgets` fake clock

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| RLS blocks cross-clinic access on `clientes`/`mascotas`/`mascota_pesos`/`storage.objects`, as the `authenticated` role | CLI-01..05, PAT-01..05 | Locked by Phase 1's D-03 convention — manual smoke test only, no automated pgTAP/CI suite this milestone | Extend `supabase/tests/rls_smoke_test.sql` (from Phase 1) with positive/negative cases for the two new tables and the Storage bucket, using the same two throwaway clinics; record pass/fail per check before closing the phase |
| Photo upload/download round-trips correctly against the real Storage bucket, and a vet-only-scoped signed URL cannot be used to read another clinic's photo | PAT-03 | Requires a live Storage bucket and real signed URLs, not mockable without losing the thing being tested | Upload a test photo as a real vet account, confirm it displays; attempt to fetch another clinic's photo path directly, confirm denial |
| Generating and later claiming a link code (CLI-05 generation this phase; full claim flow deferred to Phase 9) | CLI-05 | The generation half is automatable (see unit test above), but confirming the vet-only RLS boundary on the new columns is manual per the same D-03 convention | As part of the extended RLS smoke test, confirm Vet B cannot read/update Vet A's `clientes.codigo_vinculacion` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (4 new test files + 2 new fakes)
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter (set once planner confirms coverage)

**Approval:** pending
