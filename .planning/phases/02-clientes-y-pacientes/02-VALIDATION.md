---
phase: 2
slug: clientes-y-pacientes
status: draft
nyquist_compliant: false
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

- **After every task commit:** Run `flutter analyze && flutter test test/clientes_providers_test.dart test/mascotas_providers_test.dart`
- **After every plan wave:** Run `flutter test` (full suite)
- **Before `/gsd:verify-work`:** Full suite must be green, and the extended RLS manual smoke test (clientes/mascotas/mascota_pesos/storage.objects, positive + negative) must be run and recorded
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

Plan/task IDs are assigned by the planner — this table maps each phase requirement to its verification method.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | CLI-01 | — | Create cliente with valid data succeeds; empty nombre/telefono blocked client-side | unit/widget (fake repository) | `flutter test test/clientes_providers_test.dart` | ❌ Wave 0 | ⬜ pending |
| TBD | TBD | TBD | CLI-02, CLI-04 | — | Cliente detail: view/edit, lists only that cliente's mascotas | widget (fake repository) | `flutter test test/cliente_detail_screen_test.dart` | ❌ Wave 0 | ⬜ pending |
| TBD | TBD | TBD | CLI-03 | — | Debounced search calls repository once after the debounce window, not once per keystroke | unit (fakeAsync) | `flutter test test/clientes_providers_test.dart` | ❌ Wave 0 | ⬜ pending |
| TBD | TBD | TBD | CLI-05 | T-02-VINC | Generating a link code sets `codigo_vinculacion`/`codigo_expira_en`; only the owning clinic's vet can generate (existing RLS) | unit (fake repository) + manual (RLS) | `flutter test test/clientes_providers_test.dart` | ❌ Wave 0 | ⬜ pending |
| TBD | TBD | TBD | PAT-01, PAT-02 | — | Mascota create/edit round-trips through the reconciled entity fields | unit (fake repository) | `flutter test test/mascotas_providers_test.dart` | ❌ Wave 0 | ⬜ pending |
| TBD | TBD | TBD | PAT-03 | T-02-STOR | Photo upload returns a stable path; `CachedNetworkImage` uses `cacheKey` = stable path, not the signed URL | widget (asserts widget tree props) | `flutter test test/mascota_detail_screen_test.dart` | ❌ Wave 0 | ⬜ pending |
| TBD | TBD | TBD | PAT-04 | — | Search-by-dueño-name resolves owner ids before querying mascotas (two-step, not embedded `.or()`) | unit (fake repository, call-sequence assertion) | `flutter test test/mascotas_providers_test.dart` | ❌ Wave 0 | ⬜ pending |
| TBD | TBD | TBD | PAT-05 | — | Weight history renders multiple entries in reverse-chronological order, append-only | widget (fake repository, 2+ entries) | `flutter test test/mascota_detail_screen_test.dart` | ❌ Wave 0 | ⬜ pending |
| TBD | TBD | TBD | PAT-03 | T-02-STOR | Cross-tenant Storage object read blocked (Vet A cannot read Vet B's pet photo) | manual (SQL Editor / two-session RLS test) | n/a — extended RLS smoke test | n/a | ⬜ pending |
| TBD | TBD | TBD | CLI-01..05, PAT-01..05 | — | RLS on `clientes`/`mascotas`/`mascota_pesos` blocks cross-clinic access as `authenticated` role | manual (SQL Editor, extends Phase 1 script) | n/a — extended RLS smoke test | n/a | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/helpers/fake_clientes.dart`, `test/helpers/fake_mascotas.dart` — new fakes mirroring `fake_auth.dart`'s shape
- [ ] `test/clientes_providers_test.dart`, `test/mascotas_providers_test.dart` — new, cover CLI-01/03/05, PAT-01/02/04
- [ ] `test/cliente_detail_screen_test.dart`, `test/mascota_detail_screen_test.dart` — new widget tests, cover CLI-02/04, PAT-03/05
- [ ] No framework install needed — `flutter_test` already present

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
