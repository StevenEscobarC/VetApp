---
phase: 3
slug: historia-cl-nica
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-09-26
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (already in use since Phase 1) |
| **Config file** | none — same convention as Phases 1-2 |
| **Quick run command** | `flutter test test/consultas_providers_test.dart test/consulta_form_screen_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~10-15 seconds (growing suite, currently 111 tests) |

---

## Sampling Rate

- **After every task commit:** Run `flutter analyze && flutter test test/consultas_providers_test.dart test/consulta_form_screen_test.dart`
- **After every plan wave:** Run `flutter test` (full suite)
- **Before `/gsd:verify-work`:** Full suite must be green, and the extended RLS manual smoke test (`consultas` insert/select allow+deny, update/delete both denied) must be run and recorded
- **Max feedback latency:** ~15 seconds

---

## Per-Task Verification Map

Plan/task IDs assigned by the planner (2026-09-26). Additional per-plan coverage: D-02 end-to-end (form -> ficha weight history) in `test/mascota_detail_screen_test.dart` (03-04-T1); PDF export action loading/error/share in `test/mascota_detail_screen_test.dart` (03-05-T1); numeric parsing in `test/formato_test.dart` (03-03-T1); extra helper `test/helpers/fake_pdf.dart` (03-05-T1).

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-03-T1/T2 | 03-03 | 1 | HIST-01 | — | Consulta create succeeds with only diagnóstico+tratamiento filled; other fields stay `null` | unit (fake repository) | `flutter test test/consultas_providers_test.dart` | ❌ Wave 0 | ⬜ pending |
| 03-03-T1/T3 | 03-03 | 1 | HIST-01 | — | Form blocks submission only when diagnóstico or tratamiento is empty — never blocks on anamnesis/examen físico/evolución | widget | `flutter test test/consulta_form_screen_test.dart` | ❌ Wave 0 | ⬜ pending |
| 03-04-T1/T2 | 03-04 | 2 | HIST-02 | — | Timeline renders consultas ordered by fecha descending, defensively re-sorted client-side | widget (fake repository, 2+ unordered entries) | `flutter test test/mascota_detail_screen_test.dart` | ❌ Wave 0 (extend existing) | ⬜ pending |
| 03-05-T1/T2 | 03-05 | 3 | HIST-03, D-04 | — | `HistoriaClinicaPdfService.generar()` returns non-empty bytes for a list of consultas; includes every consulta, not just the latest | unit | `flutter test test/historia_clinica_pdf_service_test.dart` | ❌ Wave 0 | ⬜ pending |
| 03-03-T2, 03-06-T1 | 03-03, 03-06 | 1, 4 | HIST-04 | T-03-APPEND | No `copyWith`/update path exists on `Consulta`; repository exposes no `actualizar`/`eliminar` method | static/manual code-review check | grep gates DATA3_OK (03-03-T2) and GATE3_OK (03-06-T1) | n/a — static gate | ⬜ pending |
| 03-03-T1/T2 | 03-03 | 1 | D-02 | T-03-PESO | `registrarConsulta` with a non-null `pesoKg` triggers exactly one RPC call carrying both the consulta fields and the peso — never two separate repository calls | unit (fake repository, call-count/args assertion) | `flutter test test/consultas_providers_test.dart` | ❌ Wave 0 | ⬜ pending |
| 03-01-T2/T3 | 03-01 | 1 | HIST-01..04 | T-03-RLS, T-03-APPEND | RLS on `consultas` blocks cross-clinic access as `authenticated` role; no update/delete succeeds even for the owning vet | manual (SQL Editor, extends Phase 1-2 script) | n/a — extended RLS smoke test | n/a | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/helpers/fake_consultas.dart` — new fake mirroring `test/helpers/fake_mascotas.dart`'s shape
- [ ] `test/consultas_providers_test.dart` — new, covers HIST-01/D-02
- [ ] `test/consulta_form_screen_test.dart` — new widget test, covers HIST-01's min-required-fields rule
- [ ] `test/historia_clinica_pdf_service_test.dart` — new, covers HIST-03/D-04 (whole-history export)
- [ ] Extend `test/mascota_detail_screen_test.dart` — add HIST-02 timeline-ordering assertions
- [ ] No framework install needed — `flutter_test` already present
- [ ] Extend `supabase/tests/rls_smoke_test.sql` — new `consultas` checks (positive/negative select/insert, update/delete both denied)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| RLS blocks cross-clinic access on `consultas`, as the `authenticated` role; no update/delete succeeds even for the owning vet | HIST-01..04 | Locked by Phase 1's D-03 convention — manual smoke test only, no automated pgTAP/CI suite this milestone | Extend `supabase/tests/rls_smoke_test.sql` with positive/negative cases for `consultas`, using the same two throwaway clinics already in the script; record pass/fail per check before closing the phase |
| PDF export produces a readable, complete document and the native share sheet opens correctly on a real device | HIST-03 | Requires a real device/emulator to confirm `Printing.sharePdf` OS-level behavior and permission prompts, not mockable without losing the thing being tested | Generate a PDF for a patient with 2+ consultas, confirm the share sheet opens, confirm the PDF content includes every consulta in chronological order |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (5 new test files + 1 new fake)
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter (planner confirmed coverage 2026-09-26)

**Approval:** pending
