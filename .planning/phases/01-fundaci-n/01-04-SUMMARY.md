---
phase: 01-fundaci-n
plan: 04
subsystem: infra
tags: [flutter, android, gradle, firebase-cleanup, dead-code]

# Dependency graph
requires: []
provides:
  - "firebase.json and android/app/google-services.json removed from the repo"
  - "android Gradle config no longer applies com.google.gms.google-services"
  - "lib/features/auth/domain/ reduced to only the live AuthFailure exception type"
  - "AuthFailure doc comment now describes the Supabase translation path instead of Firebase"
affects: [01-fundaci-n plan 05 (LoginScreen/AuthGate/mock-home removal, depends on new router)]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - android/app/build.gradle.kts
    - android/settings.gradle.kts
    - lib/features/auth/domain/auth_failure.dart

key-decisions:
  - "Kept AuthFailure byte-identical except its doc comment (live exception type, only Firebase-era wording was wrong)"
  - "Left duplicate LoginScreen/AuthGate/mock-home untouched — that removal belongs to Plan 05 which depends on the new router"

patterns-established: []

requirements-completed: [FOUND-06]

# Metrics
duration: 10min
completed: 2026-09-24
---

# Phase 01 Plan 04: Remove Firebase→Supabase migration leftovers Summary

**Deleted orphaned Firebase config (firebase.json, google-services.json, the Gradle google-services plugin) and the unused Firebase-era auth domain layer (AuthRepository interface, Veterinario entity, 5 usecases), leaving AuthFailure as the only file in lib/features/auth/domain/ with its doc comment corrected to reference Supabase.**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-09-24T18:48:00Z
- **Completed:** 2026-09-24T18:57:37Z
- **Tasks:** 2 completed
- **Files modified:** 11 (2 deleted config files, 2 edited Gradle files, 7 deleted domain files, 1 edited doc comment — auth_failure.dart counted once)

## Accomplishments
- Removed `firebase.json` and `android/app/google-services.json`, and stripped the `com.google.gms.google-services` plugin from both `android/app/build.gradle.kts` and `android/settings.gradle.kts`; confirmed `flutter build apk --debug` still succeeds
- Deleted the entire unused Firebase-era auth domain layer: `AuthRepository` interface, `Veterinario` entity, and 5 usecases (`SignInWithEmail`, `SignInWithGoogle`, `SignUpWithEmail`, `SignOut`, `WatchCurrentVeterinario`) — verified via `grep` that nothing outside the deleted files imported them
- Rewrote `AuthFailure`'s doc comment to describe the real Supabase (`AuthException`) translation path instead of the stale Firebase/Firestore wording, keeping the class body byte-identical
- `flutter analyze` reports "No issues found!" and `flutter test` passes after the deletions

## Task Commits

Each task was committed atomically:

1. **Task 1: Remove Firebase config and the google-services Gradle plugin** - `15411f0` (chore)
2. **Task 2: Delete the dead Firebase-era auth domain layer and fix AuthFailure's doc comment** - `284f69d` (chore)

**Plan metadata:** (this SUMMARY commit, made separately per worktree protocol)

## Files Created/Modified
- `firebase.json` - deleted (orphaned FlutterFire project config for `vetapp-colombia`)
- `android/app/google-services.json` - deleted (orphaned Firebase Android config)
- `android/app/build.gradle.kts` - removed `com.google.gms.google-services` plugin block
- `android/settings.gradle.kts` - removed `com.google.gms.google-services` plugin declaration
- `lib/features/auth/domain/repositories/auth_repository.dart` - deleted (unused `AuthRepository` interface)
- `lib/features/auth/domain/entities/veterinario.dart` - deleted (unused `Veterinario` entity)
- `lib/features/auth/domain/usecases/sign_in_with_email.dart` - deleted (unused usecase)
- `lib/features/auth/domain/usecases/sign_in_with_google.dart` - deleted (unused usecase)
- `lib/features/auth/domain/usecases/sign_up_with_email.dart` - deleted (unused usecase)
- `lib/features/auth/domain/usecases/sign_out.dart` - deleted (unused usecase)
- `lib/features/auth/domain/usecases/watch_current_veterinario.dart` - deleted (unused usecase)
- `lib/features/auth/domain/auth_failure.dart` - doc comment rewritten to reference Supabase/`AuthException` instead of Firebase; class body unchanged

## Decisions Made
- Kept `AuthFailure` as the live exception type and only fixed its doc comment, per the plan — it is actively used by `SupabaseAuthRepository` and `auth_screens.dart`
- Did not touch `lib/features/auth/presentation/auth_screens.dart` or `lib/features/home/home_screen.dart` (duplicate LoginScreen/AuthGate/mock-home removal is explicitly Plan 05's scope, which depends on the new router)

## Deviations from Plan

None - plan executed exactly as written. The `grep -rln "auth_repository.dart\|veterinario.dart\|usecases/" lib test` pre-check (Task 2) matched `lib/features/auth/presentation/auth_screens.dart`, but on inspection this was a substring false-positive (`import '../data/repositories/supabase_auth_repository.dart'` contains the substring `auth_repository.dart` but is a different, live file, not the domain interface being deleted) — no actual import of the deleted files existed outside themselves, so deletion proceeded as planned.

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required. Note per the plan's threat register (T-01-19): the deleted Firebase project ids and Android API key for `vetapp-colombia` remain visible in git history — if that Firebase project still exists, the user may want to delete it or restrict the API key in the Google Cloud console, but this is optional cleanup outside the repo.

## Next Phase Readiness
- `lib/features/auth/domain/` now contains only `auth_failure.dart`, ready for Plan 05 to build the new router/AuthGate replacement without dead-code confusion
- Android Gradle config is clean of Firebase; `flutter build apk --debug` confirmed working
- No blockers for subsequent Phase 1 plans

---
*Phase: 01-fundaci-n*
*Completed: 2026-09-24*

## Self-Check: PASSED

All claimed deletions, files, and commit hashes verified present in the worktree and git history.
