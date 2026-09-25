---
phase: 02-clientes-y-pacientes
plan: 02
subsystem: dependencies-and-permissions
tags: [flutter, pubspec, android-permissions, ios-permissions, pub.dev-legitimacy, agp-compatibility]
status: complete
dependency-graph:
  requires: []
  provides:
    - "image_picker ^1.2.3 installed and pinned"
    - "flutter_image_compress ^2.5.1 installed and pinned"
    - "permission_handler ^12.0.3 installed and pinned (downgraded from the originally-approved ^13.0.2 — see Decisions)"
    - "cached_network_image ^3.4.1 installed and pinned (deliberately not 4.x)"
    - "Android CAMERA + INTERNET permissions declared"
    - "iOS NSCameraUsageDescription + NSPhotoLibraryUsageDescription declared"
    - "flutter build apk --debug succeeds with all four packages installed"
  affects:
    - "Plan 05 (camera-first photo capture in alta) — unblocked, can proceed"
    - "Plan 08 (change photo from ficha) — unblocked, can proceed"
tech-stack:
  added:
    - "image_picker ^1.2.3"
    - "flutter_image_compress ^2.5.1"
    - "permission_handler ^12.0.3"
    - "cached_network_image ^3.4.1"
  patterns: []
key-files:
  created: []
  modified:
    - pubspec.yaml
    - pubspec.lock
    - android/app/src/main/AndroidManifest.xml
    - ios/Runner/Info.plist
    - linux/flutter/generated_plugin_registrant.cc
    - linux/flutter/generated_plugin_registrant.h
    - linux/flutter/generated_plugins.cmake
    - macos/Flutter/GeneratedPluginRegistrant.swift
    - windows/flutter/generated_plugin_registrant.cc
    - windows/flutter/generated_plugin_registrant.h
    - windows/flutter/generated_plugins.cmake
decisions:
  - "User approved all four pub.dev packages at the exact pins presented (image_picker ^1.2.3, flutter_image_compress ^2.5.1, permission_handler ^13.0.2, cached_network_image ^3.4.1) — exact response: \"sí, apruébalos\""
  - "Discovered permission_handler ^13.0.2 hard-depends on permission_handler_android ^14.1.0, whose Gradle Kotlin DSL build script requires AGP 9's built-in-Kotlin support — incompatible with this project's AGP 8.11.1/Kotlin 2.2.20/Gradle 8.14 toolchain. Tested an exploratory AGP 9.0.1/Kotlin 2.3.20/Gradle 9.1.0 bump; it surfaced a second, larger blocker (Flutter's own documented AGP-9 migration: the explicit kotlin-android plugin in android/app/build.gradle.kts must be removed). Reverted all toolchain files to original values and presented three options to the user as a Rule 4 architectural checkpoint: (1) do the AGP 9 migration now, (2) downgrade permission_handler to ^12.x, (3) defer the decision into Plan 05."
  - "User's final decision: Option 2 — downgrade permission_handler from ^13.0.2 to ^12.0.3 (latest 12.x), which resolves to permission_handler_android 13.0.1 (a standard Groovy build.gradle, fully AGP-8.11.1-compatible). User's exact instruction: \"downgrade permission_handler from ^13.0.2 to ^12.x ... This supersedes the earlier ^13.0.2 approval — user explicitly re-approved this narrower change to unblock the build without a toolchain migration.\" No AGP/Kotlin/Gradle toolchain files were touched in the final state."
metrics:
  duration: "~2.5 hours (including blocked investigation, toolchain probing, and the re-approved downgrade)"
  completed: "2026-09-24"
---

# Phase 2 Plan 2: Photo Package Prerequisites Summary

Installed and pinned the four camera/photo packages required by later plans (`image_picker`, `flutter_image_compress`, `permission_handler`, `cached_network_image` pinned to `^3.4.1`, not `4.x`) after an explicit human pub.dev-legitimacy approval, declared the Android/iOS permissions needed for the camera-first pet photo flow, and — after discovering and resolving an upstream Gradle/AGP incompatibility in `permission_handler_android` 14.x via a second, narrower user-approved downgrade — confirmed the Android debug APK builds successfully with all four packages installed.

## What Was Done

### Task 1: Package legitimacy checkpoint (COMPLETE)

Presented the four packages with their pub.dev URLs, expected publishers, and version pins to the user via the orchestrator. **User's exact response: "sí, apruébalos"**, approving all four packages at the exact pins: `image_picker ^1.2.3`, `flutter_image_compress ^2.5.1`, `permission_handler ^13.0.2`, `cached_network_image ^3.4.1` (explicitly NOT the newer `^4.0.2`, per the Dart SDK `^3.11.1` constraint).

### Task 2: Install packages and declare permissions (COMPLETE)

1. Ran `flutter pub add image_picker:^1.2.3 flutter_image_compress:^2.5.1 permission_handler:^13.0.2`, then `flutter pub add cached_network_image:^3.4.1` as a separate command (per plan, to force the resolver to respect the 3.x pin). `flutter pub add` rewrote the pins without carets (e.g. `image_picker: 1.2.3`); corrected all four back to caret ranges by hand and re-ran `flutter pub get` — resolved cleanly.
2. Added `<uses-permission android:name="android.permission.CAMERA" />` and `<uses-permission android:name="android.permission.INTERNET" />` to `android/app/src/main/AndroidManifest.xml` (neither existed before).
3. Added `NSCameraUsageDescription` ("VetApp necesita la cámara para tomar fotos de las mascotas.") and `NSPhotoLibraryUsageDescription` ("VetApp necesita acceso a tus fotos para elegir la foto de la mascota.") to `ios/Runner/Info.plist`.
4. `flutter analyze`: **No issues found.**
5. `flutter test`: **All 26 tests passed.**
6. `flutter build apk --debug`: **initially FAILED** — see "Blocking Issue and Resolution" below. Resolved after the user's follow-up approval; **now succeeds** (`build/app/outputs/flutter-apk/app-debug.apk` produced, ~158MB debug build).

Committed in two steps:
- `5859d61` — install all four packages (as originally approved, `permission_handler ^13.0.2`) + declare Android/iOS permissions. Build was not yet verified at this commit.
- `a0faf1e` — downgrade `permission_handler` to `^12.0.3` after the user's second approval, confirmed `flutter build apk --debug` succeeds.

## Blocking Issue and Resolution

**What was found:** `permission_handler` `13.0.2` (the originally approved pin) unconditionally depends on `permission_handler_android: ^14.1.0` — confirmed both `14.0.0` and `14.1.0` have an identical bug: their own `android/build.gradle.kts` uses the top-level `kotlin { compilerOptions { ... } }` Gradle Kotlin DSL block without applying the Kotlin Android Gradle plugin in their own `plugins {}` block (only `com.android.library` is applied). This only resolves under **AGP 9.x's built-in-Kotlin support**. This project is pinned to AGP `8.11.1` / Kotlin Gradle Plugin `2.2.20` / Gradle `8.14`, so the build failed at Gradle script-compilation time with `Unresolved reference: compilerOptions / jvmTarget`.

**Investigated and ruled out:**
- Forcing the Kotlin plugin onto that subproject externally via `subprojects { afterEvaluate { ... } }` in the root `android/build.gradle.kts` — fails with `Cannot run Project.afterEvaluate(Action) when the project is already evaluated`; the broken script's `kotlin {}` reference is resolved by Gradle's two-phase Kotlin-DSL accessor generation *before* any external plugin application can run.
- Bumping the whole toolchain to AGP `9.0.1` / Kotlin `2.3.20` / Gradle `9.1.0` (tested, then reverted) — got past the original error but surfaced a second, confirmed-real blocker: AGP 9 forbids the explicit `id("kotlin-android")` plugin already applied in `android/app/build.gradle.kts`, because Kotlin support is now built into AGP itself. Flutter's own tooling printed a pointer to its official migration guide (`https://docs.flutter.dev/release/breaking-changes/migrate-to-agp-9`) — a genuine, documented breaking-change migration, out of scope for a dependency-installation plan.

**Presented to the user as a Rule 4 architectural checkpoint** with three options: (1) do the AGP 9 migration now, (2) downgrade `permission_handler` to the `^12.x` line, (3) defer the decision into Plan 05.

**User's decision: Option 2.** Verified via the pub.dev API that `permission_handler ^12.0.3` (the latest 12.x release) depends on `permission_handler_android: ^13.0.0`, and that the resolved implementation version (`13.0.1`, the latest satisfying that constraint) uses a plain **Groovy** `build.gradle` (not Kotlin DSL) with no `kotlin {}` extension reference at all — fully compatible with the current AGP `8.11.1` toolchain, no risk of the same bug recurring.

**Applied the fix:**
1. Changed `permission_handler: ^13.0.2` → `permission_handler: ^12.0.3` in `pubspec.yaml`.
2. `flutter pub get` — resolved `permission_handler_android` to `13.0.1` as predicted.
3. `flutter analyze` — no issues.
4. `flutter test` — 26/26 passing (no regression).
5. `flutter build apk --debug` — **succeeded** (`build/app/outputs/flutter-apk/app-debug.apk`, confirmed present on disk).
6. Confirmed via `git diff` that no AGP/Kotlin/Gradle toolchain files (`android/settings.gradle.kts`, `android/build.gradle.kts`, `android/app/build.gradle.kts`, `android/gradle/wrapper/gradle-wrapper.properties`) were left modified — the fix is fully contained to the `permission_handler` pin.

No further downgrades were needed or attempted, consistent with the user's instruction to stop and report rather than trying further downgrades unilaterally if `^12.x` had shown any issue.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Build config] `flutter pub add` dropped the caret from all four version pins**
- **Found during:** Task 2, step 1
- **Issue:** `flutter pub add <pkg>:^X.Y.Z` wrote exact-version pins (`image_picker: 1.2.3`) instead of caret ranges into `pubspec.yaml`.
- **Fix:** Manually restored `^` prefixes for all four packages, re-ran `flutter pub get` — resolved identically.
- **Files modified:** `pubspec.yaml`
- **Commit:** `5859d61`

**2. [Rule 3 - attempted, reverted] AGP/Kotlin/Gradle toolchain bump**
- **Found during:** Task 2, step 6 (debug APK build)
- **Issue:** See "Blocking Issue and Resolution" above.
- **Fix attempted:** Bumped `android/settings.gradle.kts` (AGP `8.11.1`→`9.0.1`, Kotlin `2.2.20`→`2.3.20`) and `android/gradle/wrapper/gradle-wrapper.properties` (Gradle `8.14`→`9.1.0`) to test whether it resolved the issue. It got past the original error but surfaced a second, larger migration requirement (Flutter's official AGP-9 migration guide). **Reverted both files to their original values** — escalated as a Rule 4 architectural decision instead of proceeding unilaterally.
- **Files modified (reverted, no net change):** `android/settings.gradle.kts`, `android/gradle/wrapper/gradle-wrapper.properties`
- **Commit:** none (reverted before committing)

### Rule 4 — Architectural decision (resolved with user approval)

**[Rule 4] `permission_handler` version downgrade from `^13.0.2` to `^12.0.3`**
- **Found during:** Task 2, step 6
- **What was proposed:** Downgrade the just-approved `permission_handler` pin to unblock the Android debug build without migrating the whole project to AGP 9.
- **Why needed:** `permission_handler ^13.0.2`'s Android implementation is incompatible with this project's current Gradle/AGP/Kotlin toolchain (see above); AGP 9 migration is a large, separate, deliberate effort out of scope for this plan.
- **User's decision:** Approved the downgrade — "downgrade `permission_handler` from `^13.0.2` to `^12.x` ... This supersedes the earlier `^13.0.2` approval."
- **Impact:** `permission_handler` API surface (`Permission.camera.status`/`.request()`/`openAppSettings()`, used by the camera pre-flight pattern documented in `02-RESEARCH.md`) is stable across the 12.x→13.x major-version boundary — no code in this codebase yet calls the package (Plans 05/08 haven't been written), so there is no call-site migration needed.
- **Files modified:** `pubspec.yaml`, `pubspec.lock`
- **Commit:** `a0faf1e`

## Known Stubs

None — this plan touches only dependency/permission declarations, no UI or data code.

## Threat Flags

None beyond what the plan's own threat model already covers (T-02-SC package legitimacy — mitigated via the Task 1 checkpoint, re-confirmed for the `permission_handler` downgrade since it's the same publisher/package, only a lower version; T-02-12 Android permission scope — mitigated, only CAMERA+INTERNET declared; T-02-13 dependency resolution break — mitigated, `cached_network_image` confirmed resolved to `3.4.1`).

## Self-Check

- `pubspec.yaml` contains `permission_handler: ^12.0.3` (not `^13.0.2`): **FOUND**
- `pubspec.yaml` contains the other three pins unchanged (`image_picker: ^1.2.3`, `flutter_image_compress: ^2.5.1`, `cached_network_image: ^3.4.1`), plus `sdk: ^3.11.1` and `go_router: ^17.3.0` untouched: **FOUND**
- `pubspec.lock` resolves `permission_handler` to `12.0.3` and `permission_handler_android` to `13.0.1`: **FOUND**
- `pubspec.lock` resolves `cached_network_image` to `3.4.1`: **FOUND**
- `android/app/src/main/AndroidManifest.xml` contains `android.permission.CAMERA` and `android.permission.INTERNET`: **FOUND**
- `ios/Runner/Info.plist` contains `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription`: **FOUND**
- `flutter analyze`: **No issues found** — confirmed
- `flutter test`: **26/26 passed** — confirmed
- `flutter build apk --debug`: **succeeds** — confirmed, `build/app/outputs/flutter-apk/app-debug.apk` present on disk
- `android/settings.gradle.kts`, `android/build.gradle.kts`, `android/app/build.gradle.kts`, `android/gradle/wrapper/gradle-wrapper.properties`: **unmodified** — confirmed via `git diff` (empty)
- Commits `5859d61` and `a0faf1e` exist on `worktree-agent-a904bfd9ecaac2124`: **FOUND** (`git log --oneline` confirms both)

## Self-Check: PASSED
