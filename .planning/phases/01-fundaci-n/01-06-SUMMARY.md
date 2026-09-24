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

requirements-completed: []

# Metrics
duration: pending (checkpoint reached; human verification still required)
completed: pending
---

# Phase 1 Plan 6: Walking Skeleton Real-Device Verification Summary

**README.md rewritten to document the live Supabase project, the RLS smoke test / live-schema probe, `dart_define.json`, and the current `lib/` structure; the full automated gate (`flutter analyze`, `flutter test`, `verify_live_schema.sh`, Firebase-reference grep) passes together, and the app is running live on an Android emulator against the real cloud project, awaiting the human verification checkpoint.**

## Status: TASK 1 COMPLETE — CHECKPOINT REACHED (Task 2 requires human verification)

This plan is `autonomous: false` by design. Task 1 (README rewrite + automated gate) is complete and committed. Task 2 is a `checkpoint:human-verify` — the executor has done all the automation it can (started the app on a real Android emulator against the live cloud project) and is now stopped, awaiting the user's visual/functional confirmation per the plan's `<how-to-verify>` steps 1-8.

## Performance

- **Duration (Task 1):** ~15 min
- **Tasks:** 1 of 2 complete (Task 2 is the human checkpoint)
- **Files modified:** 1 (README.md)

## Accomplishments

- Rewrote `README.md` in Spanish: intro trimmed to drop the stale "Módulo de autenticación y roles" framing; `## Supabase` section now documents the 5-step live setup (schema apply, RLS smoke test with the expected `RLS SMOKE: PASS` rollback-by-design message, `verify_live_schema.sh` → `LIVE_SCHEMA_OK`, the "Confirm email" toggle with its dev-vs-real-users tradeoff, and the password-reset redirect URL); `## Ejecutar Flutter` documents creating `dart_define.json` (gitignored) and running `flutter run --dart-define-from-file=dart_define.json`, keeping the inline `--dart-define=...` form as an alternative, plus `flutter analyze`/`flutter test`; `## Estructura principal` now lists `lib/core/data`, `lib/core/router`, `lib/core/theme`, `lib/features/auth/{data,presentation/providers,presentation/screens}`, `lib/features/home/presentation`, `supabase/schema.sql`, `supabase/tests/` — all `AuthGate`/"panel existente de veterinario" references removed.
- Ran the full automated gate specified by the plan's Task 1 `<verify>` command: `flutter analyze` → "No issues found!"; `flutter test` → 26 tests, all green; `bash supabase/tests/verify_live_schema.sh` → `OK clinicas 200` / `OK perfiles 200` / `OK clientes 200` / `OK mascotas 200` / `OK anon insert rechazado 401` / `LIVE_SCHEMA_OK`; `grep -rniE "firebase|firestore" lib --include=*.dart` → 0 matches; `firebase.json` absent. Combined command prints `GATE_OK`.
- Launched an Android emulator (`Pixel_9_API_35` → `emulator-5554`, Android 15 / API 35) since none was already running, then started `flutter run --dart-define-from-file=dart_define.json -d emulator-5554` in the background. Build succeeded (`Running Gradle task 'assembleDebug'` → `Built build\app\outputs\flutter-apk\app-debug.apk`), the APK installed, and the log shows `supabase.supabase_flutter: INFO: ***** Supabase init completed *****` with no errors — the app is live on the emulator, connected to the real cloud project, and ready for the user to walk through the checkpoint's steps 1-8.

## Task Commits

1. **Task 1: Update README for the real backend + run the full automated gate** - `4a1c1c9` (docs)

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

## User Setup Required

**Task 2 (this plan's checkpoint) requires the user to perform the real-device verification themselves.** The app is already running (Android emulator `emulator-5554`, package `com.vetapp.vetapp`, built and installed via `flutter run --dart-define-from-file=dart_define.json`, connected to the live Supabase project). The user needs to:
1. Look at the emulator window (or reconnect to it) and follow the plan's `<how-to-verify>` steps 1-8: confirm the login screen look, register a VETERINARIO test account, confirm Inicio shows the real name/clinic, check `clinicas`/`perfiles` rows in the Supabase Table Editor, tap through Pacientes/Agenda/Clientes, fully restart the app to confirm session restore, sign out from Más, and optionally register+verify a CLIENTE account.
2. Report back "approved" or list which step numbers failed and what was observed (per the plan's `<resume-signal>`).
3. Report the test vet's email (never the password) so it can be recorded in this SUMMARY per T-01-29.

## Next Phase Readiness

- Not yet ready — Phase 1 cannot close until Task 2's human checkpoint is approved and this SUMMARY is updated with the device, test vet email, and pass/fail per step 1-7 (per the plan's `acceptance_criteria`).
- All automation this executor can perform is complete: README documents the real setup, the full automated gate (`GATE_OK`) passes, and the app is live on a real Android emulator against the real cloud project — the remaining work is purely the human's visual/functional confirmation.

---
*Phase: 01-fundaci-n*
*Status: CHECKPOINT — awaiting human verification (Task 2)*

## Self-Check: PASSED

`README.md` confirmed present on disk with the updated content; commit `4a1c1c9` confirmed present in `git log --oneline`.
