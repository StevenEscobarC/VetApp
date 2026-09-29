---
phase: 03-historia-cl-nica
plan: 02
subsystem: dependencies
tags: [pubspec, pdf, printing, android-build]

# Dependency graph
requires: []
provides:
  - "pdf: 3.12.0 (exact pin) - PDF document generation, publisher nfet.net, user-approved"
  - "printing: 5.14.3 (exact pin) - native share/print sheet, publisher nfet.net, user-approved"
affects: [03-05, 03-06]

# Tech tracking
tech-stack:
  added:
    - "pdf 3.12.0"
    - "printing 5.14.3"
  patterns:
    - "Exact version pin (no caret) when a package's newer minors require a higher Dart SDK than the project's ^3.11.1 constraint - same pattern as cached_network_image in Phase 2"

key-files:
  created: []
  modified:
    - pubspec.yaml
    - pubspec.lock

key-decisions:
  - "Edited pubspec.yaml by hand instead of `flutter pub add pdf printing`, which would have written a caret constraint resolving to the SDK-incompatible pdf 3.13.x/printing 5.15.x"
  - "No share_plus added - Printing.sharePdf already opens the native share sheet, confirmed absent from pubspec.yaml by the plan's grep gate"

requirements-completed: [HIST-03]

# Metrics
duration: ~15min
completed: 2026-09-28
---

# Phase 3 Plan 02: PDF/printing dependency install Summary

**pdf 3.12.0 and printing 5.14.3 installed as exact pins after user approval of both packages' pub.dev legitimacy (publisher nfet.net). `flutter analyze` clean, `flutter test` 111/111 passing, debug APK build succeeds.**

## Performance

- **Duration:** ~15 min
- **Tasks:** 2 of 2 completed

## Accomplishments

- **Task 1 (human checkpoint):** User approved both `pdf` (v3.12.0) and `printing` (v5.14.3) after reviewing publisher `nfet.net` on pub.dev — verbatim approval: "Sí, apruebo" (via AskUserQuestion, recommended option).
- **Task 2:** Added `pdf: 3.12.0` and `printing: 5.14.3` (no caret) to `pubspec.yaml` with an explanatory Spanish comment; ran `flutter pub get` (not `upgrade`) — `pubspec.lock` resolved exactly to those two versions. `flutter analyze` clean, full `flutter test` suite green, `flutter build apk --debug` succeeded (`build/app/outputs/flutter-apk/app-debug.apk`), confirming the `printing` plugin's Android side builds against the current compileSdk/minSdk with no manifest changes needed.

## Task Commits

1. **Task 1: BLOCKING — verify pdf and printing are legitimate before install** - no code commit (human approval only, recorded above)
2. **Task 2: Install pdf 3.12.0 and printing 5.14.3 as exact pins and prove the build** - `68a73aa` (feat)

## Files Created/Modified

- `pubspec.yaml` - added `pdf: 3.12.0` and `printing: 5.14.3` under `dependencies:`, with a comment explaining the exact-pin reasoning
- `pubspec.lock` - resolved 12 changed dependencies (pdf, printing, and their transitive deps)

## Decisions Made

- Manual `pubspec.yaml` edit instead of `flutter pub add`, to avoid a caret constraint that would resolve to a Dart-SDK-incompatible version — the exact same trap `cached_network_image` hit in Phase 2.

## Deviations from Plan

None. Both tasks executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None further — approval already given and recorded above.

## Next Phase Readiness

- Plan 03-05 (PDF export service) can now import `package:pdf` and `package:printing` directly.
- No blockers.

## Self-Check

- `pdf: 3.12.0` / `printing: 5.14.3` present, no caret: CONFIRMED via grep
- `pubspec.lock` resolved to exactly those versions: CONFIRMED via grep
- `share_plus` absent from pubspec.yaml: CONFIRMED via grep
- `flutter analyze`: No issues found
- `flutter test`: 111/111 passing
- `flutter build apk --debug`: succeeded
- Commit `68a73aa`: FOUND in `git log --oneline`

## Self-Check: PASSED

---
*Phase: 03-historia-cl-nica*
*Completed: 2026-09-28*
