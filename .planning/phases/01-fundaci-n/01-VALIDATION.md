---
phase: 1
slug: fundaci-n
status: draft
nyquist_compliant: true
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

**Exception:** `01-04-PLAN.md` Task 1's automated verify runs `flutter build apk --debug` (first build can take several minutes) to confirm the app still compiles after removing the Firebase Gradle plugin. This intentionally exceeds the ~20s latency budget — it is a one-off build-integrity check for a Gradle/dependency change, not a per-task TDD-style sampling loop, and is not repeated on subsequent task commits within the plan.

---

## Per-Task Verification Map

Plan/task IDs are assigned by the planner — this table maps each phase requirement to its verification method; the planner fills in exact Task ID/Plan/Wave when tasks are created.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-T1 | 01-01 | 1 | FOUND-04, FOUND-05 | T-01-RLS, T-01-04 | clientes table, composite FK, vet-only mascotas RLS, perfiles_update pins rol/clinica_id | static | grep gate in plan (prints SCHEMA_OK) | n/a | ⬜ pending |
| 01-01-T2 | 01-01 | 1 | FOUND-05 | T-01-RLS, T-01-06 | Smoke test covers 27 checks (4 tables x positive/negative + escalation); anon probe | static + CLI | bash -n + grep gate (SMOKE_FILES_OK) | created by task | ⬜ pending |
| 01-01-T3 | 01-01 | 1 | FOUND-01, FOUND-04, FOUND-05 | T-01-RLS | Schema live in cloud; RLS SMOKE: PASS as authenticated role | manual (SQL Editor, D-03) + CLI | bash supabase/tests/verify_live_schema.sh (LIVE_SCHEMA_OK) | ✅ after T2 | ⬜ pending |
| 01-02-T1 | 01-02 | 1 | FOUND-02, FOUND-03 | — | Wave 0: failing router + Inicio tests with fake notifier | widget (RED) | flutter test test/widget_test.dart test/inicio_screen_test.dart (must fail) | ❌ Wave 0 (created here) | ⬜ pending |
| 01-02-T2 | 01-02 | 1 | FOUND-03 | T-01-13, T-01-14 | authProfileProvider drives Inicio; no setState | widget | flutter test test/inicio_screen_test.dart | ✅ after T1 | ⬜ pending |
| 01-02-T3 | 01-02 | 1 | FOUND-02 | T-01-11, T-01-12 | Boot -> /login; vet -> /inicio; 5 tabs; sign-out; cliente -> /cliente | widget | flutter analyze && flutter test | ✅ after T1 | ⬜ pending |
| 01-03-T1 | 01-03 | 1 | FOUND-02 (D-01) | — | Terracota/crema palette, terracota active nav | unit | flutter test test/app_theme_test.dart | created by task | ⬜ pending |
| 01-03-T2 | 01-03 | 1 | FOUND-02 (D-01) | — | Caprasimo + Figtree scale | unit | flutter test test/app_theme_test.dart | ✅ | ⬜ pending |
| 01-04-T1 | 01-04 | 1 | FOUND-06 | T-01-19, T-01-20 | Firebase config + Gradle plugin removed, APK builds | static + build | grep gate && flutter build apk --debug | n/a | ⬜ pending |
| 01-04-T2 | 01-04 | 1 | FOUND-06 | T-01-21 | Dead auth domain removed | static | grep -rniE "firebase|firestore" lib/features/auth (0) && flutter analyze && flutter test | n/a | ⬜ pending |
| 01-05-T1 | 01-05 | 2 | FOUND-02, FOUND-03 | T-01-22 | Auth screens via providers + context.push; brand block | widget | flutter test test/widget_test.dart (green after T2) | ✅ | ⬜ pending |
| 01-05-T2 | 01-05 | 2 | FOUND-06, FOUND-02 | T-01-24, T-01-25 | AuthGate + mock home deleted; no Navigator.push | static + widget | grep gate && flutter analyze && flutter test | ✅ | ⬜ pending |
| 01-06-T1 | 01-06 | 3 | FOUND-01 | T-01-27, T-01-28 | Full gate incl. live probe | CLI | flutter analyze && flutter test && bash supabase/tests/verify_live_schema.sh | ✅ | ⬜ pending |
| 01-06-T2 | 01-06 | 3 | FOUND-01, FOUND-02, FOUND-03 | — | Real device: signup write, Inicio real read, tabs, restore, sign-out | manual (human-verify) | bash supabase/tests/verify_live_schema.sh | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/widget_test.dart` (Plan 01-02 Task 1) — currently asserts on `AuthGate`/`LoginScreen` copy directly; must be rewritten for the `MaterialApp.router` + `ProviderScope` boot path (covers FOUND-02)
- [ ] `test/inicio_screen_test.dart` (Plan 01-02 Task 1) — new file, covers FOUND-03's "no direct setState" requirement with an assertion against a fake `authProfileProvider` override (no live Supabase required)
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
