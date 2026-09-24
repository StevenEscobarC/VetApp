---
phase: 01-fundaci-n
plan: 06
subsystem: docs
tags: [readme, walking-skeleton, supabase, real-device-verification]

# Dependency graph
requires:
  - phase: 01-fundacion (Plan 01, schema/RLS)
    provides: live cloud schema, RLS smoke test, verify_live_schema.sh
  - phase: 01-fundacion (Plan 02, app spine)
    provides: routerProvider, authProfileProvider, AppShell, InicioScreen
  - phase: 01-fundacion (Plan 05, auth screen extraction)
    provides: Riverpod/go_router auth screens, dead-code removal
provides:
  - "README.md: setup + run instructions for the real Supabase backend and the current lib/ structure"
affects: ["Phase 2-8 (README is the onboarding doc for every future phase)"]

tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - README.md

key-decisions:
  - "README's 'Confirm email' guidance states the Supabase default (ON) explicitly rather than asserting a specific toggle state, since 01-01-SUMMARY.md recorded that the user never explicitly reported changing it — documents both the dev shortcut (turn off temporarily) and the hard requirement to re-enable before real users"

requirements-completed: [FOUND-01, FOUND-02, FOUND-03]

# Metrics
duration: ~45min (Task 1 + human verification round-trip)
completed: 2026-09-24
---

# Phase 1 Plan 6: Walking Skeleton Real-Device Verification Summary

**README.md rewritten to document the live Supabase project, the RLS smoke test / live-schema probe, `dart_define.json`, and the current `lib/` structure; the full automated gate (`flutter analyze`, `flutter test`, `verify_live_schema.sh`, Firebase-reference grep) passes together, and the app ran live on an Android emulator against the real cloud project. The human verification checkpoint is **approved** — the walking skeleton works end-to-end on a real device against the real backend.**

## Status: COMPLETE

This plan was `autonomous: false` by design. Task 1 (README rewrite + automated gate) was completed and committed by the executor agent. Task 2 (`checkpoint:human-verify`) was completed by the user directly on the running Android emulator (`emulator-5554`), confirming the login screen appearance, VETERINARIO account creation, Inicio showing real name/clinic data, tab navigation, session restore after app restart, and sign-out/sign-in. **Approved by the user.**

## Performance

- **Duration:** ~45 min (Task 1 ~15 min + human verification round-trip, including one bug found and fixed live)
- **Tasks:** 2 of 2 complete
- **Files modified:** 2 (README.md, supabase_auth_repository.dart)

## Accomplishments

- Rewrote `README.md` in Spanish: intro trimmed to drop the stale "Módulo de autenticación y roles" framing; `## Supabase` section now documents the 5-step live setup (schema apply, RLS smoke test with the expected `RLS SMOKE: PASS` rollback-by-design message, `verify_live_schema.sh` → `LIVE_SCHEMA_OK`, the "Confirm email" toggle with its dev-vs-real-users tradeoff, and the password-reset redirect URL); `## Ejecutar Flutter` documents creating `dart_define.json` (gitignored) and running `flutter run --dart-define-from-file=dart_define.json`, keeping the inline `--dart-define=...` form as an alternative, plus `flutter analyze`/`flutter test`; `## Estructura principal` now lists `lib/core/data`, `lib/core/router`, `lib/core/theme`, `lib/features/auth/{data,presentation/providers,presentation/screens}`, `lib/features/home/presentation`, `supabase/schema.sql`, `supabase/tests/` — all `AuthGate`/"panel existente de veterinario" references removed.
- Ran the full automated gate specified by the plan's Task 1 `<verify>` command: `flutter analyze` → "No issues found!"; `flutter test` → 26 tests, all green; `bash supabase/tests/verify_live_schema.sh` → `OK clinicas 200` / `OK perfiles 200` / `OK clientes 200` / `OK mascotas 200` / `OK anon insert rechazado 401` / `LIVE_SCHEMA_OK`; `grep -rniE "firebase|firestore" lib --include=*.dart` → 0 matches; `firebase.json` absent. Combined command prints `GATE_OK`.
- Launched an Android emulator (`Pixel_9_API_35` → `emulator-5554`, Android 15 / API 35) since none was already running, then started `flutter run --dart-define-from-file=dart_define.json -d emulator-5554` in the background. Build succeeded (`Running Gradle task 'assembleDebug'` → `Built build\app\outputs\flutter-apk\app-debug.apk`), the APK installed, and the log shows `supabase.supabase_flutter: INFO: ***** Supabase init completed *****` with no errors — the app is live on the emulator, connected to the real cloud project, and ready for the user to walk through the checkpoint's steps 1-8.

## Task Commits

1. **Task 1: Update README for the real backend + run the full automated gate** - `4a1c1c9` (docs)
2. **Task 2: Human verification + live bugfix** - `50efd62` (fix, orchestrator-applied during checkpoint)

## Files Created/Modified

- `README.md` - real-backend setup instructions (schema apply, RLS smoke test, live-schema probe, Confirm-email guidance, dart_define.json run command), updated structure section

## Decisions Made

- Followed the plan's exact section-by-section instructions verbatim (intro, Supabase, Ejecutar Flutter, Estructura principal).
- For the "Confirm email" line, since 01-01-SUMMARY.md recorded that the toggle state was never explicitly reported back by the user (Supabase's own default is ON), the README states the default explicitly and gives both options (turn off temporarily for dev convenience vs. the hard requirement to have it ON before real users) rather than asserting a specific current state that cannot be confirmed from the available record.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Reverted unrelated `flutter pub get`/tooling-generated changes to desktop plugin registrant files**
- **Found during:** Task 1, after running the automated gate (`flutter analyze`/`flutter test` trigger a `pub get` which regenerates plugin registrant files for all configured desktop platforms)
- **Issue:** `git status --short` showed 7 modified files outside this task's scope (`linux/flutter/generated_plugin_registrant.{cc,h}`, `linux/flutter/generated_plugins.cmake`, `macos/Flutter/GeneratedPluginRegistrant.swift`, `windows/flutter/generated_plugin_registrant.{cc,h}`, `windows/flutter/generated_plugins.cmake`) — tool-regenerated build artifacts with no real content diff (line-ending noise only), which would have polluted this plan's single-file commit.
- **Fix:** `git checkout --` those 7 files before staging, keeping only `README.md` in the commit.
- **Files modified:** none (reverted, not committed)
- **Verification:** `git status --short` showed only `README.md` after the revert.
- **Committed in:** n/a (not committed — correctly excluded)

---

**Total deviations:** 1 auto-fixed (1 Rule 3 scope-boundary correction)
**Impact on plan:** No behavior change, no scope creep into unrelated generated files.

## Issues Encountered

- The worktree's base commit did not match the wave's expected base (`git merge-base HEAD 121c150...` returned `97b3ba5`, the worktree's own creation point, predating Waves 1-2). Corrected per the `worktree_branch_check` protocol via `git reset --hard 121c15041a7313e4aee245488a1e6045cbcbea9d` before starting any work — the worktree branch had no prior commits of its own beyond that point, so nothing was lost.
- `dart_define.json` is gitignored and therefore not present in a fresh worktree checkout. Copied it from the main repo checkout (`C:\Trabajo\VetApp\dart_define.json`) into this worktree purely to run `verify_live_schema.sh` and `flutter run` — its contents were never read or printed, and it remains gitignored/untracked in this worktree.
- No Android device or already-running emulator was available at start. `flutter emulators --launch Pixel_9_API_35` was run in the background and polled every 10s until it appeared in `flutter devices` (~70s), then `flutter run --dart-define-from-file=dart_define.json -d emulator-5554` was started in the background — this is automation the plan's `<important_note>` explicitly asked for ("starting the app on whatever device/emulator is available if possible") rather than asking the user to run it.

## Known Stubs

None introduced by this plan — Task 1 only touched `README.md`.

## Threat Flags

None. This task modified only documentation; no new network endpoints, auth paths, file access patterns, or schema changes were introduced.

## Human Verification Result (Task 2)

Performed by the user on Android emulator `emulator-5554`, package `com.vetapp.vetapp`, against the live cloud project.

- Steps 1-7 (login look, VETERINARIO signup, Inicio real name/clinic, tab placeholders, session restore, sign-out/sign-in): **all passed**.
- Step 8 (optional CLIENTE account): also tested by the user, and led to discovering the bug below.
- **Result: approved.**

### Bug found live during verification, fixed by the orchestrator

**[Rule 1 - Bug] `_messageFor()` masked Supabase's "email rate limit exceeded" error as "Ingresa un correo válido"**
- **Found during:** Task 2 human verification — the user registered a CLIENTE account first (with "Confirm email" still ON at the time), which consumed Supabase's default free-tier email quota (~2-4/hour). The subsequent VETERINARIO signup attempt failed with a Supabase `AuthException` containing "rate limit", which `lib/features/auth/data/repositories/supabase_auth_repository.dart`'s `_messageFor()` matched against the generic `message.contains('email')` branch, showing the misleading "Ingresa un correo válido" instead of the real cause.
- **Fix:** Added a specific `message.contains('rate limit')` branch before the generic email fallback, returning a clear Spanish message that explains the rate limit and points at the "Confirm email" toggle as the workaround.
- **Root cause resolution (user action, not a code fix):** the user turned off "Confirm email" in Supabase (Authentication → Providers → Email), which stops the rate-limited email sends entirely; after that, VETERINARIO signup succeeded immediately.
- **Files modified:** `lib/features/auth/data/repositories/supabase_auth_repository.dart`
- **Verification:** `flutter analyze` → No issues found; `flutter test` → 26/26 passing.
- **Committed in:** `50efd62`

### Known non-blocking friction (documented, not fixed this phase)

- Supabase's default email-confirmation link redirects to `Site URL` (default `localhost:3000`), which doesn't exist for this mobile-only app — clicking the confirmation link shows a browser "connection refused" page. The confirmation itself still succeeds server-side before the redirect (verified: the user was able to sign in immediately after). Proper deep-link redirect configuration is out of scope for Phase 1 (no web/app-link target exists yet) — flagged for whichever future phase adds a proper redirect target (e.g., a custom scheme or a hosted confirmation page).

## Next Phase Readiness

- **Phase 1 is complete.** FOUND-01 through FOUND-06 are all closed: real Supabase backend live and RLS-hardened (Plan 01), Riverpod/go_router walking skeleton (Plan 02), terracota/crema design tokens (Plan 03), Firebase dead code removed (Plan 04), auth screens migrated off the legacy AuthGate/mock home (Plan 05), and the full stack verified end-to-end on a real device against the real backend with a live bug found and fixed (Plan 06).
- Phase 2 (Clientes y Pacientes) can now build on a trustworthy `authProfileProvider`/`routerProvider`/RLS foundation.

---
*Phase: 01-fundaci-n*
*Status: COMPLETE — approved by user, 2026-09-24*

## Self-Check: PASSED

`README.md` confirmed present on disk with the updated content; commits `4a1c1c9` and `50efd62` confirmed present in `git log --oneline`. All 26 tests passing, `flutter analyze` clean, user approved the real-device walking-skeleton verification.
