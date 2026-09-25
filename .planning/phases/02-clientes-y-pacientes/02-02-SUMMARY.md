---
phase: 02-clientes-y-pacientes
plan: 02
subsystem: dependencies-and-permissions
tags: [flutter, pubspec, android-permissions, ios-permissions, pub.dev-legitimacy, agp-migration]
status: checkpoint-blocked
dependency-graph:
  requires: []
  provides:
    - "image_picker ^1.2.3 installed and pinned"
    - "flutter_image_compress ^2.5.1 installed and pinned"
    - "permission_handler ^13.0.2 installed and pinned (dependency resolves; native Android build currently fails, see Blocking Issue)"
    - "cached_network_image ^3.4.1 installed and pinned (deliberately not 4.x)"
    - "Android CAMERA + INTERNET permissions declared"
    - "iOS NSCameraUsageDescription + NSPhotoLibraryUsageDescription declared"
  affects:
    - "Plan 05 (camera-first photo capture in alta) — blocked until debug APK build succeeds"
    - "Plan 08 (change photo from ficha) — blocked until debug APK build succeeds"
tech-stack:
  added:
    - "image_picker ^1.2.3"
    - "flutter_image_compress ^2.5.1"
    - "permission_handler ^13.0.2"
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
  - "Reverted an exploratory AGP 9.0.1 / Kotlin 2.3.20 / Gradle 9.1.0 toolchain bump after confirming it requires migrating off the kotlin-android Gradle plugin entirely (AGP 9's built-in-Kotlin breaking change) — too large a blast radius to apply without explicit user sign-off, flagged as a Rule 4 architectural checkpoint instead"
metrics:
  duration: "~90 min (including blocked investigation)"
  completed: "2026-09-24 (Task 1 approval) / checkpoint pending (Task 2 build step)"
---

# Phase 2 Plan 2: Photo Package Prerequisites Summary

Installed and pinned the four camera/photo packages required by later plans (image_picker, flutter_image_compress, permission_handler, cached_network_image ^3.4.1) after an explicit human legitimacy approval, and declared the Android/iOS permissions needed for the camera-first pet photo flow — but the Android debug APK build required by this plan's Task 2 acceptance criteria fails due to an upstream Gradle/AGP incompatibility in `permission_handler_android` 14.x, which needs a user decision to resolve.

## What Was Done

### Task 1: Package legitimacy checkpoint (COMPLETE)

Presented the four packages with their pub.dev URLs, expected publishers, and version pins to the user via the orchestrator. **User's exact response: "sí, apruébalos"** (relayed by the coordinator, approving all four packages at the exact pins: `image_picker ^1.2.3`, `flutter_image_compress ^2.5.1`, `permission_handler ^13.0.2`, `cached_network_image ^3.4.1` — explicitly NOT the newer `^4.0.2`, per the Dart SDK `^3.11.1` constraint).

### Task 2: Install packages and declare permissions (PARTIALLY COMPLETE — blocked at final build-verification step)

Completed and verified:
1. Ran `flutter pub add image_picker:^1.2.3 flutter_image_compress:^2.5.1 permission_handler:^13.0.2`, then `flutter pub add cached_network_image:^3.4.1` as a separate command (per plan, to force the resolver to respect the 3.x pin). `flutter pub add` rewrote the pins without carets (e.g. `image_picker: 1.2.3`); corrected all four back to caret ranges by hand in `pubspec.yaml` and re-ran `flutter pub get` — resolved cleanly, `pubspec.lock` confirms `cached_network_image: "3.4.1"` (verified with `grep -A8`, not `-A2` as the plan's automated check used — the plan's own `-A2` window is too narrow to reach the `version:` line in the current lock-file format; this is a plan-script issue, not a real failure, see Deviations).
2. Added `<uses-permission android:name="android.permission.CAMERA" />` and `<uses-permission android:name="android.permission.INTERNET" />` to `android/app/src/main/AndroidManifest.xml` (neither existed before).
3. Added `NSCameraUsageDescription` ("VetApp necesita la cámara para tomar fotos de las mascotas.") and `NSPhotoLibraryUsageDescription` ("VetApp necesita acceso a tus fotos para elegir la foto de la mascota.") to `ios/Runner/Info.plist`.
4. `flutter analyze`: **No issues found.**
5. `flutter test`: **All 26 tests passed** (no regressions from the new dependencies).
6. `flutter build apk --debug`: **FAILS** — see Blocking Issue below. Not resolved in this session; requires a user decision.

Committed as `feat(02-02): install pinned photo packages and declare camera permissions` (steps 1-5 above; the platform-generated plugin registrant files for linux/macos/windows were also updated by `flutter pub get` and committed alongside, harmless/expected fallout of adding four new plugins).

## Blocking Issue — Requires User Decision (Rule 4, unresolved)

**What was found:** `permission_handler` `13.0.2` unconditionally depends on `permission_handler_android: ^14.1.0` (no lower version satisfies this constraint — confirmed both `14.0.0` and `14.1.0` have the identical bug). That package's own `android/build.gradle.kts` uses the top-level `kotlin { compilerOptions { ... } } ` Gradle Kotlin DSL block without applying the Kotlin Android Gradle plugin anywhere in its own `plugins {}` block (only `com.android.library` is applied). This only resolves correctly under **AGP 9.x's built-in-Kotlin support** (AGP 9+ no longer needs a separate `kotlin-android` plugin at all). This project is currently pinned to AGP `8.11.1` / Kotlin Gradle Plugin `2.2.20` / Gradle `8.14`, so the build fails at Gradle script-compilation time with:
```
Unresolved reference. None of the following candidates is applicable because of receiver type mismatch: ...
Unresolved reference: compilerOptions / jvmTarget
```

**Investigated and ruled out:**
- Forcing the Kotlin plugin onto that one subproject from the root `android/build.gradle.kts` via `subprojects { afterEvaluate { ... } }` — fails with `Cannot run Project.afterEvaluate(Action) when the project is already evaluated`; the broken script's `kotlin {}` reference is resolved by Gradle's two-phase Kotlin-DSL accessor generation *before* any external plugin application can run, so this can't be patched from outside that file.
- No compatible lower version of `permission_handler_android` exists while keeping `permission_handler` at the approved `^13.0.2` pin (`13.0.2`'s own `pubspec.yaml` hard-requires `permission_handler_android: ^14.1.0`).
- Bumping the whole toolchain to match what `permission_handler_android` needs (AGP `9.0.1` / Kotlin `2.3.20` / Gradle `9.1.0`, the exact versions declared in its own `buildscript {}` block) **does** get past the original error, but surfaces a second, confirmed-real blocker: AGP 9 forbids explicitly applying `id("kotlin-android")` in `android/app/build.gradle.kts` (already present in this project) because Kotlin support is now built into AGP itself. Flutter's own tooling detected this and printed a pointer to its official migration guide: `https://docs.flutter.dev/release/breaking-changes/migrate-to-agp-9`. This is a genuine, documented Flutter/AGP breaking-change migration, not a narrow config tweak — reverted the exploratory toolchain-version edits (`android/settings.gradle.kts`, `android/gradle/wrapper/gradle-wrapper.properties`) back to their original values; **no toolchain files were left modified.**

**Proposed options (needs explicit user decision before Plan 05/08 can proceed):**
1. **Do the AGP 9 migration now** (Flutter's official guide) — bumps AGP/Kotlin/Gradle project-wide, removes the explicit `kotlin-android` plugin application from `android/app/build.gradle.kts`, and requires re-verifying every other installed plugin (image_picker_android, flutter_image_compress_common, etc.) still builds under AGP 9's built-in Kotlin. Largest blast radius, but resolves the root cause permanently and unblocks the exact approved `permission_handler ^13.0.2` pin.
2. **Downgrade `permission_handler`** to a major version whose Android implementation predates the AGP-9-only Gradle script (e.g. the `12.x` line) — smallest, most contained change, stays on the same package (no substitution), but deviates from the exact version the user just approved ("sí, apruébalos" was for `^13.0.2` specifically) and would need a fresh, smaller re-approval.
3. **Defer** — ship this plan with the other three packages verified end-to-end, and explicitly carry the `permission_handler`/APK-build gap as a blocker into Plan 05 (which is where the camera-permission pre-flight check is actually consumed), deferring the AGP decision until that plan's discuss-phase.

**Recommendation:** Option 2 (downgrade to `permission_handler ^12.x`) is the narrowest, lowest-risk path that still satisfies this plan's must-have ("app resolves and builds with ... permission_handler ... pinned") without a project-wide Gradle/AGP migration that's out of scope for a dependency-installation plan — but this is the user's call given it reverses part of the just-given approval.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Build config] `flutter pub add` dropped the caret from all four version pins**
- **Found during:** Task 2, step 1
- **Issue:** `flutter pub add <pkg>:^X.Y.Z` wrote exact-version pins (`image_picker: 1.2.3`) instead of caret ranges into `pubspec.yaml`.
- **Fix:** Manually restored `^` prefixes for all four packages, re-ran `flutter pub get` — resolved identically (locked versions unchanged).
- **Files modified:** `pubspec.yaml`
- **Commit:** `5859d61`

**2. [Rule 3 - attempted, reverted] AGP/Kotlin/Gradle toolchain bump**
- **Found during:** Task 2, step 4 (debug APK build)
- **Issue:** See Blocking Issue above.
- **Fix attempted:** Bumped `android/settings.gradle.kts` (AGP `8.11.1`→`9.0.1`, Kotlin `2.2.20`→`2.3.20`) and `android/gradle/wrapper/gradle-wrapper.properties` (Gradle `8.14`→`9.1.0`) to test whether it resolved the issue. It got past the original error but surfaced a second, larger migration requirement (Flutter's official AGP-9 migration guide). **Reverted both files to their original values** — this is now Rule 4 (architectural decision), not auto-fixable. No toolchain files are modified in the final commit.
- **Files modified (reverted, no net change):** `android/settings.gradle.kts`, `android/gradle/wrapper/gradle-wrapper.properties`
- **Commit:** none (reverted before committing)

## Known Stubs

None — this plan touches only dependency/permission declarations, no UI or data code.

## Threat Flags

None beyond what the plan's own threat model already covers (T-02-SC package legitimacy — mitigated via the Task 1 checkpoint; T-02-12 Android permission scope — mitigated, only CAMERA+INTERNET declared; T-02-13 dependency resolution break — mitigated, cached_network_image confirmed resolved to 3.4.1).

## Self-Check

- `pubspec.yaml` contains all four caret-pinned packages: **FOUND** (verified via grep, see above)
- `pubspec.lock` resolves `cached_network_image` to `3.4.1`: **FOUND** (verified via `grep -A8`)
- `android/app/src/main/AndroidManifest.xml` contains `android.permission.CAMERA`: **FOUND**
- `ios/Runner/Info.plist` contains `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription`: **FOUND**
- `flutter analyze`: **No issues found** — confirmed
- `flutter test`: **26/26 passed** — confirmed
- `flutter build apk --debug`: **FAILS** — confirmed, documented as the open Blocking Issue above (not a false claim; this plan is NOT fully done pending the user's decision)
- Commit `5859d61` exists on `worktree-agent-a904bfd9ecaac2124`: **FOUND** (`git log --oneline -1` confirms)

## Self-Check: PASSED (with one open item)

All claims above are verified against actual command output. The plan is **not complete** — Task 2's `flutter build apk --debug` acceptance criterion is unmet, and requires an explicit user decision among the three options above before Plan 05/08 can safely build on these dependencies. This is being returned as a Rule 4 architectural checkpoint, not a completed plan.
