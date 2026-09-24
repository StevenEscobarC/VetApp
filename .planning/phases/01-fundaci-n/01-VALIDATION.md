---
phase: 1
slug: fundaci-n
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-09-24
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (bundled with Flutter SDK, already a dev dependency) |
| **Config file** | none — no dedicated test config exists; `test/widget_test.dart` uses the default `flutter_test` + `pumpWidget` style |
| **Quick run command** | `flutter test test/widget_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~10-20 seconds (small suite) |

---

## Sampling Rate

- **After every task commit:** Run `flutter analyze && flutter test test/widget_test.dart`
- **After every plan wave:** Run `flutter test` (full suite)
- **Before `/gsd:verify-work`:** Full suite must be green, and the manual RLS smoke test script must be fully run and recorded (pass/fail per table × direction)
- **Max feedback latency:** ~20 seconds

---

## Per-Task Verification Map

Plan/task IDs are assigned by the planner — this table maps each phase requirement to its verification method; the planner fills in exact Task ID/Plan/Wave when tasks are created.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | FOUND-01 | — | Schema applies cleanly, signup trigger still works | manual-only | n/a — SQL Editor + real signup smoke check | n/a | ⬜ pending |
| TBD | TBD | TBD | FOUND-02 | — | App boots to `/login` when unauthenticated, routes to `/inicio` after sign-in | widget | `flutter test test/widget_test.dart` (rewritten for `MaterialApp.router` + `ProviderScope`) | ❌ Wave 0 (update existing file) | ⬜ pending |
| TBD | TBD | TBD | FOUND-03 | — | No `setState` on data screens; `authProfileProvider` drives `InicioScreen` | widget | `flutter test` (new `test/inicio_screen_test.dart`, fake repo override) | ❌ Wave 0 (new file) | ⬜ pending |
| TBD | TBD | TBD | FOUND-04 | — | `clientes` table exists, decoupled from `perfiles` | manual-only | n/a — SQL Editor insert as vet, confirm no `auth.users` FK requirement | n/a | ⬜ pending |
| TBD | TBD | TBD | FOUND-05 | T-01-RLS | RLS blocks cross-tenant access + self-escalation, tested as `authenticated` (not just service-role) | manual-only | n/a — RLS smoke test script (see 01-RESEARCH.md) | n/a | ⬜ pending |
| TBD | TBD | TBD | FOUND-06 | — | No Firebase dead code remains | static check | `grep -ril "firebase\|Firestore" lib/ --include=*.dart` (zero matches) + `flutter analyze` | n/a | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/widget_test.dart` — currently asserts on `AuthGate`/`LoginScreen` copy directly; must be rewritten for the `MaterialApp.router` + `ProviderScope` boot path (covers FOUND-02)
- [ ] `test/inicio_screen_test.dart` — new file, covers FOUND-03's "no direct setState" requirement with an assertion against a fake `authProfileProvider` override (no live Supabase required)
- [ ] No framework install needed — `flutter_test` is already present

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `schema.sql` (with FOUND-04/FOUND-05 changes) applies cleanly to the real cloud project; signup trigger still creates a `perfiles` row | FOUND-01, FOUND-04 | No automated DB test harness this phase (D-03: manual smoke test, no pgTAP/CI suite) | Paste the updated `supabase/schema.sql` into the Supabase SQL Editor for `apjonrmhkpyzbofupokb`; sign up a test `VETERINARIO` and a test `CLIENTE`; confirm `perfiles`/`clientes` rows are created as expected |
| RLS blocks cross-clinic access and blocks `perfiles` self-escalation, as the `authenticated` role | FOUND-05 | Locked by CONTEXT.md D-03 — manual smoke test only, no automated suite this phase | Run the positive/negative smoke-test script from `01-RESEARCH.md` in the SQL Editor (or via two authenticated test sessions) against `clinicas`, `perfiles`, `mascotas`, `clientes`; record pass/fail per table × direction before closing the phase |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (`test/inicio_screen_test.dart`, rewritten `test/widget_test.dart`)
- [ ] No watch-mode flags
- [ ] Feedback latency < 20s
- [ ] `nyquist_compliant: true` set in frontmatter (set once planner confirms coverage)

**Approval:** pending
