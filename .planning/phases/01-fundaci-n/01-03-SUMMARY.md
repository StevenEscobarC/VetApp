---
phase: 01-fundaci-n
plan: 03
subsystem: ui
tags: [flutter, theme, design-tokens, google_fonts, caprasimo, figtree, material3]

# Dependency graph
requires: []
provides:
  - Terracota/crema `AppColors` palette replacing the old forest-green tokens, with all legacy field names preserved
  - `AppTheme.light`/`AppTheme.dark` `ColorScheme` + component themes mapped onto the new palette
  - Terracota-highlighted active bottom-nav icon/label via `navigationBarTheme`
  - Caprasimo (display/headline/titleLarge) + Figtree (body/label) `AppTypography` text theme, Noto Sans fully removed
  - `test/app_theme_test.dart` regression suite (12 tests) locking in the token values and typography roles
affects: ["01-fundaci-n plan 02 (Login/Inicio screens)", "01-fundaci-n plan 05", "Phase 8 (dark-mode design confirmation)"]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "google_fonts text-theme tests use `testWidgets` (not plain `test`) so the fake-async test zone absorbs the package's fire-and-forget network font-fetch future instead of it leaking into an unrelated test"
    - "NavigationBar active-state styling via `WidgetStateProperty.resolveWith` on both `iconTheme` and `labelTextStyle`, checking `WidgetState.selected`"

key-files:
  created:
    - test/app_theme_test.dart
  modified:
    - lib/core/theme/app_colors.dart
    - lib/core/theme/app_theme.dart
    - lib/core/theme/app_typography.dart

key-decisions:
  - "Kept every legacy AppColors field name (secondary, onSecondary, accent, muted, ring, *Dark, etc.), re-valuing them onto the new palette instead of renaming, so no other widget file needed touching this plan"
  - "Dark ColorScheme.primary now maps to AppColors.primary (terracota) instead of the old AppColors.secondary swap, per 01-UI-SPEC.md (terracota reads fine on dark, unchanged from light)"
  - "Dark-mode token values are explicitly marked provisional in-code (`// Dark mode: valores derivados...`) since they are derived, not from the approved mockup — to be reconfirmed in Phase 8"

requirements-completed: [FOUND-02]

duration: 20min
completed: 2026-09-24
---

# Phase 1 Plan 03: Terracota/Crema Theme Tokens Summary

**Replaced the forest-green Material palette and Figtree+Noto Sans typography with the approved terracota/crema tokens and Caprasimo+Figtree typography, with terracota highlighting the active bottom-nav item and a 12-test regression suite locking in the values.**

## Performance

- **Duration:** ~20 min
- **Tasks:** 2 completed
- **Files modified:** 3 (app_colors.dart, app_theme.dart, app_typography.dart) + 1 created (app_theme_test.dart)

## Accomplishments
- `AppColors` now ships the exact terracota/crema hex values from `01-UI-SPEC.md` (`0xFFC67139` primary, `0xFFF5EAD8` background, etc.) plus the new semantic tokens (primaryHover, primaryStrong, surfaceMuted, textSecondary, textMuted, placeholder, successBg, warningBg) while every legacy field name (`secondary`, `accent`, `muted`, `ring`, `*Dark`) still compiles for existing widgets.
- `AppTheme.light`/`.dark` `ColorScheme`s and `_base` component themes (inputs, cards, buttons) now read from the new tokens; dark mode keeps terracota as `primary` instead of swapping to the old sage-green `secondary`.
- The active bottom-nav icon and label now render in terracota via `resolveWith` on `navigationBarTheme.iconTheme`/`labelTextStyle`, with the indicator pill using a 16%-alpha terracota tint.
- `AppTypography` now composes `GoogleFonts.caprasimoTextTheme()` for display/headline/titleLarge roles and `GoogleFonts.figtreeTextTheme()` for everything else (Noto Sans fully removed), with UI-SPEC-exact sizes/line-heights and the invalid w700/w800 overrides on the single-weight Caprasimo font removed.
- `test/app_theme_test.dart` (12 tests, `testWidgets`-based) regression-tests both the color/component behaviors and the typography roles; full existing suite (`flutter test`) stays green (13/13).

## Task Commits

Each task was committed atomically (TDD RED → GREEN per task, sharing one test file):

1. **RED (both tasks): failing AppTheme token + typography tests** - `36cda31` (test)
2. **Task 1: Terracota/crema palette + ColorScheme/nav mapping** - `81ef9ba` (feat)
3. **Task 2: Caprasimo + Figtree typography scale** - `9683233` (feat)

_Note: both tasks share a single test file (`test/app_theme_test.dart`) written up front per the plan's action steps, so there is one shared RED commit followed by two GREEN commits._

## Files Created/Modified
- `test/app_theme_test.dart` - 12-test regression suite: 6 `AppTheme tokens` behaviors (palette/ColorScheme/nav) + 6 `AppTypography` behaviors (Caprasimo/Figtree roles, no-Noto guard)
- `lib/core/theme/app_colors.dart` - Terracota/crema palette per `01-UI-SPEC.md`, all legacy field names preserved and re-valued, dark tokens marked provisional inline
- `lib/core/theme/app_theme.dart` - `ColorScheme.light`/`.dark` remapped onto new tokens; dark `primary` fixed to stay terracota; `navigationBarTheme` iconTheme/labelTextStyle now resolve terracota on `WidgetState.selected`
- `lib/core/theme/app_typography.dart` - `caprasimoTextTheme()` + `figtreeTextTheme()` composition replacing `figtreeTextTheme()` + `notoSansTextTheme()`; UI-SPEC sizes/line-heights applied; w700/w800 overrides removed

## Decisions Made
- Kept every legacy `AppColors` field name (see key-decisions in frontmatter) instead of renaming, so this plan stays isolated to token files only, as scoped ("Token files only — no screen files are touched here").
- Dark-mode values are explicitly commented as provisional/unapproved, per `01-UI-SPEC.md`'s own caveat, to flag them for the Phase 8 design revisit.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Test file needed `testWidgets` instead of plain `test`, and a `TestWidgetsFlutterBinding.ensureInitialized()`/`allowRuntimeFetching` false attempt was tried and discarded first**
- **Found during:** Task 1 (writing `test/app_theme_test.dart`)
- **Issue:** Accessing `AppTheme.light`/`.dark` triggers `google_fonts` to kick off a fire-and-forget async network font fetch. Under plain `test()` (real async, no fake time), that future sometimes rejects (network fetch failure, or `allowRuntimeFetching = false` + missing local asset) *after* the current test had already completed, and the test runner attributed the resulting `TestFailure`/uncaught exception to an unrelated, already-finished or currently-running test — non-deterministic failures unrelated to the actual token/typography values under test.
- **Fix:** Rewrote every test case in `test/app_theme_test.dart` to use `testWidgets` (matching the project's only existing test, `test/widget_test.dart`, which already proved this pattern works cleanly with `google_fonts`). `testWidgets`' fake-async test zone means the network future never resolves within the test's synchronous fake-time window, so it's discarded harmlessly instead of surfacing as a spurious failure.
- **Files modified:** test/app_theme_test.dart
- **Verification:** `flutter test test/app_theme_test.dart` — 12/12 pass deterministically across repeated runs; `flutter test` (full suite) — 13/13 pass.
- **Committed in:** 36cda31 (RED commit, before implementation) — no separate fix commit needed since this was resolved before the first GREEN commit.

---

**Total deviations:** 1 auto-fixed (1 blocking/test-infrastructure)
**Impact on plan:** No scope creep — this only changed how the test file is structured (test → testWidgets) to make the RED/GREEN cycle deterministic; all 12 planned behaviors are still asserted exactly as specified in the plan's `<behavior>` blocks.

## Issues Encountered
- Initial `test()`-based test runs against `AppTheme.light`/`.dark` intermittently failed with `google_fonts` network-fetch or missing-asset exceptions unrelated to the palette/typography assertions being tested (see Deviations above) — resolved by switching to `testWidgets`.

## User Setup Required

None - no external service configuration required. (Fonts are fetched by `google_fonts` at runtime as already documented in the plan's threat model, T-01-17/T-01-18 — no new setup.)

## Next Phase Readiness
- Token files (`app_colors.dart`, `app_theme.dart`, `app_typography.dart`) are ready for Plan 02/05 to build the Login and Inicio screens against — no screen code was touched in this plan, so there is no merge risk with parallel wave-1 plans.
- Dark-mode values remain provisional/unapproved (flagged in-code and in `01-UI-SPEC.md`) — Phase 8's full design pass should re-confirm them with the user.

---
*Phase: 01-fundaci-n*
*Completed: 2026-09-24*

## Self-Check: PASSED

- FOUND: lib/core/theme/app_colors.dart
- FOUND: lib/core/theme/app_theme.dart
- FOUND: lib/core/theme/app_typography.dart
- FOUND: test/app_theme_test.dart
- FOUND commit: 36cda31 (test: add failing AppTheme token regression tests)
- FOUND commit: 81ef9ba (feat: terracota/crema palette + ColorScheme/nav mapping)
- FOUND commit: 9683233 (feat: Caprasimo + Figtree typography scale)
