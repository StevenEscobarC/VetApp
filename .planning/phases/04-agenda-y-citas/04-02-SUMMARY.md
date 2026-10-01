---
phase: 04-agenda-y-citas
plan: 02
subsystem: platform
tags: [flutter, localization, android, notifications, gradle]
requires: []
provides:
  - es_CO Material localization app-wide
  - flutter_local_notifications / timezone / url_launcher / shared_preferences as direct deps
  - Android desugaring + boot receivers (debug APK builds)
affects: [04-05, 04-07, 04-08, 04-10]
tech-stack:
  added: [flutter_local_notifications ^22.3.1, timezone ^0.11.1, url_launcher ^6.3.2, shared_preferences ^2.5.5, flutter_localizations (sdk)]
  patterns: [routerHarness optional locale]
key-files:
  modified: [pubspec.yaml, pubspec.lock, lib/main.dart, test/helpers/router_harness.dart, android/app/build.gradle.kts, android/app/src/main/AndroidManifest.xml]
key-decisions:
  - "intl constraint relaxed from ^0.20.3 to ^0.20.2 because flutter_localizations pins intl 0.20.2"
metrics:
  completed: 2026-09-30
---

# Phase 4 Plan 02: Platform layer for reminders, WhatsApp and es_CO Summary

Added the Phase 4 packages, switched both MaterialApps to es_CO, and configured Android (desugaring, multidex, boot receivers, no exact-alarm permissions); `flutter build apk --debug` succeeds.

## Tasks
1. Dependencies and es_CO localization - commit 473a432
2. Android Gradle + manifest and APK build spike - commit 5485b44

## Deviations from Plan

**1. [Rule 3 - Blocking] intl version conflict**
- **Found during:** Task 1
- **Issue:** `flutter_localizations` from the SDK requires `intl 0.20.2`; project had `intl ^0.20.3`, so resolution failed.
- **Fix:** Changed to `intl: ^0.20.2` (resolves to the SDK-pinned version).
- **Files:** pubspec.yaml, pubspec.lock
- **Commit:** 473a432

**2. [Minor] `flutter pub add` wrote exact pins** for flutter_local_notifications, timezone and url_launcher; edited to caret ranges per plan.

## Verification
- `flutter analyze`: no issues. `flutter test`: 154 passed (after Task 1).
- `flutter build apk --debug`: succeeded (build/app/outputs/flutter-apk/app-debug.apk).
- Manifest has no SCHEDULE_EXACT_ALARM / USE_EXACT_ALARM; receivers are exported=false. pdf/printing pins untouched.

## Notes
- The build regenerated linux/macos/windows plugin registrant files (working tree only, not committed, to avoid conflicts with the main checkout's already-modified copies).
- Android tests/analyze were not re-run after Task 2 (native-only changes); the APK build exercised them.

## Known Stubs
None.

## Self-Check: PASSED
