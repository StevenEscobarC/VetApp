---
phase: 01-fundacion
verified: 2026-09-24T00:00:00Z
status: passed
score: 8/8 must-haves verified
overrides_applied: 0
---

# Phase 1: Fundación Verification Report

**Phase Goal:** Existe un backend Supabase real y confiable (RLS probado contra el rol `authenticated`) y la app usa Riverpod/go_router de verdad para estado y navegación, en vez de mocks y `setState`/`Navigator` directos.
**Verified:** 2026-09-24
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Real Supabase cloud project exists, `schema.sql` applied, tenant tables reachable (FOUND-01) | ✓ VERIFIED | Live-ran `bash supabase/tests/verify_live_schema.sh` against `apjonrmhkpyzbofupokb.supabase.co` just now: `OK clinicas 200`, `OK perfiles 200`, `OK clientes 200`, `OK mascotas 200`, `OK anon insert rechazado 401`, `LIVE_SCHEMA_OK` (exit 0). This is current, first-hand evidence, not a re-statement of the SUMMARY. |
| 2 | `clientes` table exists independent of `perfiles`, clients don't need auth (FOUND-04) | ✓ VERIFIED | `supabase/schema.sql:31-42` defines `public.clientes` with its own `id`/`clinica_id`, no FK to `auth.users`/`perfiles`; `mascotas.dueno_id` re-pointed at `clientes(id, clinica_id)` via composite FK (`schema.sql:70`). |
| 3 | RLS on `clinicas`/`perfiles`/`clientes`/`mascotas` tested against `authenticated` role, including the perfiles self-escalation fix (FOUND-05) | ✓ VERIFIED | `supabase/tests/rls_smoke_test.sql` (305 lines, 27 `checks := checks + 1` increments, confirmed by grep) impersonates `authenticated` via `set_config('role','authenticated', true)` + JWT claims for 2 vets (different clinics) + 1 cliente, covering cross-tenant reads/writes and the self-escalation attack (C5/C6). SUMMARY records the user ran it in the live SQL Editor and got `RLS SMOKE: PASS (27 checks)` — matches the file's own check count exactly, and 01-REVIEW.md independently traced the `perfiles_update` WITH CHECK fix (`schema.sql:148-155`) through Postgres RLS evaluation order and found no bypass. This SQL requires direct `auth.users` insert access (service/postgres role via SQL Editor), which the verifier cannot execute from the anon REST client — the human-run result is the only obtainable evidence for this specific check and is corroborated by an independent code-review trace. |
| 4 | Firebase-era dead code removed (FOUND-06) | ✓ VERIFIED | `firebase.json`, `android/app/google-services.json` absent; zero `firebase\|firestore` matches in `lib/**/*.dart`; no `google-services`/`com.google.gms` in Gradle files; `lib/features/auth/domain/repositories/auth_repository.dart`, `domain/entities/veterinario.dart`, `domain/usecases/` all deleted. |
| 5 | App navigation uses real `go_router` with 5 bottom-nav sections (FOUND-02) | ✓ VERIFIED | `lib/core/router/app_router.dart` defines `routerProvider` (`Provider<GoRouter>`) with a `redirect` callback and `StatefulShellRoute.indexedStack` with 5 branches (`/inicio`, `/pacientes`, `/agenda`, `/clientes`, `/mas`); `lib/main.dart` uses `MaterialApp.router(routerConfig: ref.watch(routerProvider))`. Zero `Navigator.push`/`MaterialPageRoute` and zero `AuthGate` references anywhere in `lib/`. |
| 6 | App state managed with Riverpod (`Notifier`/`AsyncNotifier`), no `setState` in data screens (FOUND-03) | ✓ VERIFIED | `AuthProfileNotifier extends AsyncNotifier<AuthProfile?>` (`auth_providers.dart:23`) wired to `authStateChangesProvider` via `ref.listen` + `ref.invalidateSelf()`. `InicioScreen` is a `ConsumerWidget` using `profileAsync.when(data/loading/error)` with zero `setState`. `setState` only remains in the 3 auth *form* screens (login/register/reset-password) for local form UI state (loading/validation), not data screens — consistent with the requirement's own wording. |
| 7 | Terracota/crema visual identity applied (design pre-condition for FOUND-02 execution) | ✓ VERIFIED | `lib/core/theme/app_colors.dart:8` `primary = Color(0xFFC67139)` (terracota) matches plan's exact hex; `AppTypography` provides Caprasimo/Figtree tokens consumed by `AppTheme`. |
| 8 | Full automated gate is green (regression check for the whole phase) | ✓ VERIFIED | Ran independently just now: `flutter analyze` → "No issues found!"; `flutter test` → 26/26 passing. |

**Score:** 8/8 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `supabase/schema.sql` | `clientes` table + hardened RLS, mascotas FK repoint | ✓ VERIFIED | Confirmed table def, composite FK, vet-only mascotas policies (select/insert/update/delete), `perfiles_update` fix. |
| `supabase/tests/rls_smoke_test.sql` | Single-paste 27-check RLS smoke test, ends `RLS SMOKE: PASS/FAIL` | ✓ VERIFIED | 305 lines, 27 checks, exception message pattern present at lines 300/303. |
| `supabase/tests/verify_live_schema.sh` | Anon REST probe, 4 tables + anon-write rejection | ✓ VERIFIED + RE-RUN | Executed live against the real project during this verification; exit 0, `LIVE_SCHEMA_OK`. |
| `lib/core/data/supabase_client_provider.dart` | `supabaseClientProvider` | ✓ VERIFIED | Present, used by `authRepositoryProvider`. |
| `lib/features/auth/presentation/providers/auth_providers.dart` | `authRepositoryProvider`, `authStateChangesProvider`, `AuthProfileNotifier`, `authProfileProvider` | ✓ VERIFIED | All 4 present and wired. |
| `lib/core/router/app_router.dart` | `routerProvider` with redirect + `StatefulShellRoute.indexedStack` (5 branches) | ✓ VERIFIED | Confirmed. |
| `lib/features/home/presentation/app_shell.dart` | `AppShell` bottom nav over `StatefulNavigationShell` | ✓ VERIFIED (exists, imported by router) | |
| `lib/features/home/presentation/screens/inicio_screen.dart` | Real nombre + clinicaNombre via `authProfileProvider` | ✓ VERIFIED | Full source read; `ref.watch(authProfileProvider)`, `.when(data/loading/error)`. |
| `lib/main.dart` | `MaterialApp.router` fed by `routerProvider` | ✓ VERIFIED | Confirmed. |
| `test/inicio_screen_test.dart`, `test/widget_test.dart` | Data/empty/error + router/redirect/nav/sign-out tests | ✓ VERIFIED | 26 tests total, all passing (re-run). |
| `lib/core/theme/app_colors.dart`, `app_theme.dart`, `app_typography.dart` | Terracota/crema tokens, Caprasimo/Figtree | ✓ VERIFIED | Confirmed hex values and typography tokens. |
| `lib/features/auth/domain/auth_failure.dart` | `AuthFailure`, Supabase-accurate doc | ✓ VERIFIED (exists) | |
| `android/app/build.gradle.kts` | No `com.google.gms.google-services` plugin | ✓ VERIFIED | Confirmed absent. |
| `README.md` | Setup/run docs for real backend | ✓ VERIFIED | `--dart-define-from-file=dart_define.json` and RLS smoke test steps present (per SUMMARY; file exists and is the only file in the 01-06 commit `4a1c1c9`). |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `public.mascotas.dueno_id` | `public.clientes(id, clinica_id)` | composite FK | ✓ WIRED | `schema.sql:70` |
| `perfiles_update` policy | pre-update `perfiles` row | correlated-subquery `WITH CHECK` | ✓ WIRED | `schema.sql:148-155`, independently traced sound by 01-REVIEW.md |
| `lib/main.dart` | `lib/core/router/app_router.dart` | `ref.watch(routerProvider)` → `MaterialApp.router` | ✓ WIRED | Confirmed |
| `app_router.dart` | `authProfileProvider` | `redirect` reads `ref.read(authProfileProvider)`; `_AuthRefreshNotifier` listens for changes | ✓ WIRED | Confirmed |
| `AuthProfileNotifier.build` | `authStateChangesProvider` | `ref.listen` + `ref.invalidateSelf()` | ✓ WIRED | Confirmed |
| `auth_providers.dart` | `supabase_client_provider.dart` | `ref.watch(supabaseClientProvider)` | ✓ WIRED | Confirmed present in file |
| `supabase/tests/verify_live_schema.sh` | live Supabase REST endpoint | curl + anon key from `dart_define.json` | ✓ WIRED, RE-EXECUTED | Ran live during this verification, `LIVE_SCHEMA_OK` |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Live backend reachable + RLS-safe writes rejected | `bash supabase/tests/verify_live_schema.sh` | `LIVE_SCHEMA_OK`, exit 0 | ✓ PASS |
| Static analysis clean | `flutter analyze` | "No issues found!" | ✓ PASS |
| Full test suite green | `flutter test` | 26/26 passing | ✓ PASS |
| No Firebase remnants | `grep -rniE "firebase\|firestore" lib` + `firebase.json` check | 0 matches, file absent | ✓ PASS |
| No direct-Navigator / AuthGate remnants | `grep -rn "Navigator.push\|MaterialPageRoute\|AuthGate" lib/` | 0 matches | ✓ PASS |

### Probe Execution

| Probe | Command | Result | Status |
|-------|---------|--------|--------|
| `supabase/tests/verify_live_schema.sh` | `bash supabase/tests/verify_live_schema.sh` | exit 0, `LIVE_SCHEMA_OK` | PASS |

`supabase/tests/rls_smoke_test.sql` is not an independently re-runnable probe from this environment (requires direct `auth.users` insert privileges only available via the Supabase SQL Editor / service role, not the anon REST key available here). Its result is accepted as human-verification evidence (SUMMARY-reported `RLS SMOKE: PASS (27 checks)`, matching the file's own check count) corroborated by an independent code-review trace of the fix in 01-REVIEW.md.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|--------------|--------|----------|
| FOUND-01 | 01-01, 01-06 | Real Supabase project, schema applied | ✓ SATISFIED | Live probe re-run, `LIVE_SCHEMA_OK` |
| FOUND-02 | 01-02, 01-03, 01-05, 01-06 | go_router w/ 5 bottom-nav sections | ✓ SATISFIED | `app_router.dart` StatefulShellRoute, 5 branches |
| FOUND-03 | 01-02, 01-05, 01-06 | Riverpod state, no setState on data screens | ✓ SATISFIED | `AsyncNotifier`, `ConsumerWidget`, `.when()` in InicioScreen |
| FOUND-04 | 01-01 | Independent `clientes` table | ✓ SATISFIED | `schema.sql:31-42` |
| FOUND-05 | 01-01 | RLS tested against `authenticated`, self-escalation fixed | ✓ SATISFIED | `rls_smoke_test.sql` (27 checks) + review trace of fix |
| FOUND-06 | 01-04, 01-05 | Firebase/dead-code removal | ✓ SATISFIED | No firebase files/refs, domain scaffolding deleted |

No orphaned requirements — all 6 FOUND-IDs declared in ROADMAP/REQUIREMENTS.md are claimed by at least one plan and independently confirmed in code.

**Note (documentation lag, non-blocking):** `.planning/REQUIREMENTS.md` still shows `[ ]` unchecked for FOUND-01/04/05/06 and its Traceability table still says "Pending" for Phase 1, despite the underlying work being complete and verified. This is a stale-checklist bookkeeping gap, not a code/goal gap — flagged as an info item, not a blocker.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/features/auth/presentation/screens/client_home_screen.dart` | 35, 41 | No-op `onPressed: () {}` on "Agregar mascota"/"Agendar cita" | ℹ️ Info | Pre-existing, flagged in 01-REVIEW.md (IN-02) as UX polish for out-of-scope future features (Phase 2/4), not a Phase 1 goal blocker. |
| `supabase/schema.sql` | 138-140 | `clinicas` has no UPDATE/DELETE RLS policy | ℹ️ Info | Pre-existing gap noted in 01-REVIEW.md (IN-03), not a regression, not required by Phase 1 goal. |
| `.planning/REQUIREMENTS.md` | 12-17 | Checkboxes/traceability not updated to reflect Phase 1 completion | ℹ️ Info | Documentation lag, does not affect code-level goal achievement. |

No TBD/FIXME/XXX debt markers found in any file modified by this phase. No blocker or warning-level anti-patterns found — the two warnings raised in 01-REVIEW.md (WR-01 reset-password red-styled success message, WR-02 internal ops copy leaked to users) were both fixed in commit `c3b6a02` and independently re-verified in this pass (`_success`/`_error` fields separated in `reset_password_screen.dart`; rate-limit message no longer mentions the Supabase dashboard).

### Human Verification Required

None. The one item that structurally requires human/manual execution (Task 2 of Plan 01-06: real Android emulator run against the live cloud project, and the RLS smoke test execution in the SQL Editor for Plan 01-01 Task 3) was already performed by the user and is documented with specific, falsifiable evidence (exact check counts, exact log lines, a live bug found and fixed) in 01-01-SUMMARY.md and 01-06-SUMMARY.md — per this task's explicit instruction, this is treated as completed human verification evidence, not as pending.

### Gaps Summary

No gaps. All 6 FOUND requirements are independently verified against the live codebase and, where possible, against the live Supabase project itself (re-executed during this verification, not merely re-stated from the SUMMARY). `flutter analyze` and `flutter test` were re-run and are clean. Dead Firebase-era code and the old `AuthGate`/`Navigator`-based UI are fully removed. The two warning-level findings from `01-REVIEW.md` were fixed in a follow-up commit and that fix was independently re-verified here. Remaining info-level items (no-op future-feature buttons, missing `clinicas` UPDATE/DELETE policy, stale REQUIREMENTS.md checkboxes) are pre-existing, out-of-scope-for-this-phase, or purely cosmetic bookkeeping — none block the phase goal.

---

*Verified: 2026-09-24*
*Verifier: Claude (gsd-verifier)*
