---
phase: 02-clientes-y-pacientes
plan: 10
subsystem: docs+validation
tags: [flutter, readme, validation-gate, uat, checkpoint]

# Dependency graph
requires:
  - phase: 02-clientes-y-pacientes
    plan: 01
    provides: live schema delta (link-code columns, foto_path, mascota_pesos, 3 RPCs, mascota-fotos bucket), 53-check RLS smoke test
  - phase: 02-clientes-y-pacientes
    plan: 02
    provides: image_picker/flutter_image_compress/permission_handler/cached_network_image pins, Android/iOS camera permissions
  - phase: 02-clientes-y-pacientes
    plan: "03-09"
    provides: full CRUD vertical slices for clientes y mascotas (search, combined alta, camera photo, ficha edit, link code, pet ficha with weight history, add-pet-to-existing-owner, edit)
provides:
  - "README.md Fase 2 setup section (schema re-apply steps, mascota-fotos bucket check, 4 package pins, Android/iOS/macOS camera permission notes)"
  - "02-VALIDATION.md: wave_0_complete true, all automated + prior manual RLS-smoke rows marked green, sign-off checklist ticked"
  - "Automated gate confirmed green: flutter analyze clean, flutter test 111/111, flutter build apk --debug succeeded"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created:
    - .planning/phases/02-clientes-y-pacientes/02-10-SUMMARY.md
  modified:
    - README.md
    - .planning/phases/02-clientes-y-pacientes/02-VALIDATION.md

key-decisions:
  - "verify_live_schema.sh cannot run from this sandboxed worktree agent (no SUPABASE_URL/SUPABASE_ANON_KEY env vars, no dart_define.json at the worktree root) — same limitation already documented in 02-01-SUMMARY.md. Folded the LIVE_SCHEMA_OK re-run into the user's Task 2 device session, since the user's machine already has dart_define.json to run `flutter run --dart-define-from-file=dart_define.json` for the UAT."
  - "The manual RLS-smoke rows (cross-tenant storage isolation, clientes/mascotas/mascota_pesos RLS) were already confirmed PASS (53/53 checks) by the user during Plan 01's checkpoint — marked green here rather than re-asking the user to re-run the same SQL Editor script, since nothing in Plans 02-09 touched schema.sql or rls_smoke_test.sql again."

requirements-completed: []  # None of CLI-01..05/PAT-01..05 are newly completed by this plan — they were completed by Plans 01-09; this plan is the phase-closing verification gate, not a feature plan. Full traceability already recorded against 02-01..02-09's requirements-completed fields.

# Metrics
duration: ~35min (Task 1 only; Task 2 is a blocking human checkpoint, not yet run)
completed: 2026-09-25
---

# Phase 2 Plan 10: Phase-Closing Gate (README + Automated Validation + Device UAT) Summary

**Task 1 complete: README.md documents the full Fase 2 setup (schema re-apply, mascota-fotos bucket, 4 new packages, camera permissions incl. the macOS Podfile macro fix), and the automated gate is green (`flutter analyze` clean, `flutter test` 111/111, `flutter build apk --debug` succeeded, all VALIDATION.md automated + prior manual rows marked ✅). Task 2 (12-step end-to-end UAT on a real device against the live cloud project) is a blocking `checkpoint:human-verify` this sandboxed worktree agent cannot perform — awaiting the user.**

## Performance

- **Duration:** ~35 min (Task 1)
- **Tasks:** 1 of 2 completed (Task 2 is the blocking checkpoint, awaiting the user)
- **Files modified:** 2 (README.md, 02-VALIDATION.md)

## Accomplishments

- Reset the worktree branch to the assigned base commit (`3c42fcf...`) — it was found 20 commits behind at startup (stale, no unique local work), per the standard `<worktree_branch_check>` protocol.
- Added a "Fase 2 — Clientes y Pacientes" setup section to `README.md`: idempotent schema re-apply steps (`schema.sql` then `rls_smoke_test.sql`, expected `RLS SMOKE: PASS (53 checks)`), `verify_live_schema.sh` → `LIVE_SCHEMA_OK`, `mascota-fotos` private-bucket + 4-policy check, the four pinned packages (`image_picker ^1.2.3`, `flutter_image_compress ^2.5.1`, `permission_handler ^12.0.3`, `cached_network_image ^3.4.1` — noting it stays on 3.x until a Dart SDK bump), Android CAMERA/INTERNET permissions, iOS `Info.plist` usage strings, and the macOS-only `Podfile` `PERMISSION_CAMERA=1`/`PERMISSION_PHOTOS=1` preprocessor-macro fix. No key values included anywhere (verified: no `eyJ` substring).
- Ran the full automated gate: `flutter analyze` → No issues found; `flutter test` → 111/111 passed; `flutter build apk --debug` → succeeded (`build/app/outputs/flutter-apk/app-debug.apk` produced).
- Attempted `bash supabase/tests/verify_live_schema.sh` — failed with `FAIL config: falta SUPABASE_URL / SUPABASE_ANON_KEY`, confirming the same sandboxed-worktree credential limitation already documented in `02-01-SUMMARY.md` (no `dart_define.json`, no env vars in this worktree). This check requires the user's own machine and is folded into the Task 2 device session below.
- Updated `02-VALIDATION.md`: `status: complete`, `wave_0_complete: true`, every automated per-task row and the two previously-confirmed manual RLS-smoke rows (cross-tenant storage isolation + clientes/mascotas/mascota_pesos RLS, both PASS 53/53 checks per Plan 01) marked ✅ green, Wave 0 and Sign-Off checkboxes ticked. The UAT row (`02-10-T2`) and `**Approval:**` remain pending — they can only be closed by the user completing Task 2.

## Task Commits

1. **Task 1: Update README, run the full automated gate, finalize VALIDATION.md** - `530468d` (docs)

**Task 2 (blocking checkpoint, not yet executed):** End-to-end UAT on a device against the live backend — see "CHECKPOINT REACHED" below.

## Files Created/Modified

- `README.md` - added "Fase 2 — Clientes y Pacientes" setup section (schema re-apply, packages, permissions, macOS macro)
- `.planning/phases/02-clientes-y-pacientes/02-VALIDATION.md` - `wave_0_complete: true`, all automated/manual rows green, sign-off ticked, UAT + Approval left pending

## Decisions Made

- Left the UAT row and final `**Approval:**` in `02-VALIDATION.md` as pending, per the plan's own Task 1 instruction ("leave the Manual-Only rows ⬜ pending until Task 2 resolves them") — only the user's device confirmation can close those.
- Did not attempt to fabricate or skip the `LIVE_SCHEMA_OK` probe — reported the exact sandbox limitation and pointed the user to run it as part of their own device session, since they already need `dart_define.json` there for `flutter run`.

## Deviations from Plan

None — Task 1 executed exactly as written. No Rule 1-4 auto-fixes were needed; no bugs, missing functionality, blocking issues, or architectural changes encountered while writing the README section or updating VALIDATION.md.

## Issues Encountered

- **Worktree branch drift at startup:** found 20 commits behind the assigned base (`3c42fcf...`), pointing at a pre-Phase-2 snapshot (`docs: create roadmap`). No unique commits existed on the branch, so `git reset --hard 3c42fcf...` was safe (no work lost) — done per the mandatory `<worktree_branch_check>` protocol before any file edits.
- **`verify_live_schema.sh` not executable from this sandbox** (same limitation as Plan 01; no `SUPABASE_URL`/`SUPABASE_ANON_KEY`/`dart_define.json` available here) — not a regression, a credentials-availability gap of the sandboxed worktree. Folded into the Task 2 device session.

## User Setup Required

**This plan ends at a blocking human checkpoint (Task 2).** See "CHECKPOINT REACHED" below for the exact steps.

## Next Phase Readiness

- Once Task 2's UAT is approved and any resulting fixes are committed, Phase 2 (`clientes-y-pacientes`) is fully closed: all 6 ROADMAP success criteria (CLI-01/02/03/04/05, PAT-01/02/03/04/05) will have been proven end-to-end on a real device against the live cloud project (`apjonrmhkpyzbofupokb`).
- No blockers for Phase 3 beyond the user completing Task 2.

## Self-Check

- `README.md` contains "mascota-fotos": FOUND
- `README.md` contains "PERMISSION_CAMERA=1": FOUND
- `README.md` contains "rls_smoke_test.sql": FOUND
- `README.md` contains no "eyJ" substring: CONFIRMED
- `.planning/phases/02-clientes-y-pacientes/02-VALIDATION.md` contains "wave_0_complete: true": FOUND
- `flutter analyze`: No issues found — confirmed
- `flutter test`: 111/111 passed — confirmed
- `flutter build apk --debug`: succeeded, `build/app/outputs/flutter-apk/app-debug.apk` present — confirmed
- Commit `530468d` (Task 1): FOUND in `git log --oneline`
- No unexpected file deletions in the Task 1 commit: CONFIRMED (`git diff --diff-filter=D` empty)

## Self-Check: PASSED

---
*Phase: 02-clientes-y-pacientes*
*Status: Task 1 complete, Task 2 (blocking checkpoint) awaiting user*
