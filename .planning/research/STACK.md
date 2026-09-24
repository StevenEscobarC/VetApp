# Technology Stack

**Domain:** Flutter + Supabase mobile app — veterinary practice management (Colombia)
**Researched:** 2026-09-23
**Confidence:** HIGH (versions verified live against pub.dev API and package changelogs on 2026-09-23; wiring patterns verified against Riverpod official docs and multiple independent sources)

## Scope note

Flutter and Supabase are already decided (see `.planning/codebase/STACK.md`). This document only covers: (1) how to actually wire the already-declared `flutter_riverpod`/`go_router` dependencies, and (2) the new libraries needed for PDF export, pet photo storage, and Colombia-specific locale/notification behavior that the mocked features will need once they become real.

## Recommended Stack

### Core Technologies (wiring, not new deps)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| `flutter_riverpod` | `^3.3.2` (already pinned; resolves up to `3.4.3` as of 2026-09-23) | App-wide state/DI | Already a direct dependency but completely unused (`ProviderScope` wraps the app, zero `Provider`s exist). Riverpod 3.x's `Notifier`/`AsyncNotifier` classes are the current official replacement for `StatefulWidget`+`setState`, which is what every mocked feature screen uses today. No reason to introduce a second state library. |
| `go_router` | `^17.3.0` (already pinned; **do not bump to 18.x**, see below) | Declarative navigation, deep links, auth-gated redirects | Already a direct dependency but unused — `AuthGate` + manual `Navigator.push(MaterialPageRoute(...))` do the router's job by hand today. `go_router` is the Flutter-team-maintained standard for this; replacing `AuthGate`'s manual role/session branching with a `redirect:` callback removes the biggest structural anti-pattern flagged in `.planning/codebase/ARCHITECTURE.md`. |

**Wiring pattern (HIGH confidence, cross-verified against Riverpod docs + Supabase community examples):**

1. Build the `GoRouter` instance **inside a Riverpod `Provider`**, not as a top-level `final` or inside `main()`. This is the documented pattern for letting `redirect:` read other providers via `ref`.
2. Auth-gate with `redirect:`, not a widget (`AuthGate` today is a widget doing this job — replace it):
   ```dart
   final routerProvider = Provider<GoRouter>((ref) {
     final authState = ref.watch(authStateProvider); // AsyncValue<AuthProfile?>
     return GoRouter(
       refreshListenable: GoRouterRefreshStream(
         Supabase.instance.client.auth.onAuthStateChange,
       ),
       redirect: (context, state) {
         final loggedIn = authState.valueOrNull != null;
         final onLogin = state.matchedLocation == '/login';
         if (!loggedIn) return onLogin ? null : '/login';
         if (onLogin) return '/home';
         return null;
       },
       routes: [...],
     );
   });
   ```
   `GoRouterRefreshStream` (a tiny `ChangeNotifier` wrapping any `Stream`) bound to `supabase.auth.onAuthStateChange` is the standard way to make `go_router` re-run `redirect` the instant a Supabase session changes (sign-in, sign-out, token refresh) — without it, `redirect` only re-runs on navigation, which is exactly the class of bug ("user signs out but UI doesn't move") this app is at risk of if `AuthGate` is replaced naively.
3. Stop using `Navigator.push(MaterialPageRoute(...))` anywhere once this is wired — mixing imperative `Navigator` calls with `go_router` produces inconsistent back-stack behavior. `HomeScreen`'s internal `IndexedStack`/`NavigationBar` tab-switching is fine to keep as local widget state (it's not really "navigation", it's a tab index) but every screen-to-screen transition should become `context.go()`/`context.push()`.
4. Role-based home (`VETERINARIO` vs `CLIENTE`) becomes a `redirect:` branch reading a `profileProvider`, replacing the `_VeterinarianHome`/`ClientHomeScreen` branching currently inlined in `AuthGate`.

**Do NOT upgrade `go_router` to 18.x right now.** Verified via changelog: `go_router 18.0.0` migrates to the new `material_ui`/`cupertino_ui` packages and **raises the minimum Flutter SDK to 3.44 / Dart 3.12**. The project's `pubspec.yaml` currently constrains `sdk: ^3.11.1`. Bumping `go_router` to 18 without first upgrading the Flutter/Dart SDK will fail dependency resolution. This is a separate, deliberate decision for later — not something to do incidentally while wiring routing.

**Riverpod: codegen or manual — use manual (`Notifier`/`AsyncNotifier`) for this milestone.** Riverpod's own docs describe `riverpod_generator` (`@riverpod` annotation + `build_runner`) as the "recommended" way to reduce boilerplate, and it is genuinely nicer for parameterized/family providers. But: this project has **no codegen tooling installed at all today** (no `build_runner`, no `freezed`, no `json_serializable`), every feature is starting from zero, and the existing `presentation/providers/` scaffolding folders imply plain Riverpod. Introducing `build_runner` + `riverpod_generator` + `riverpod_lint` + `custom_lint` as a first step adds a watch-mode build step and a new failure class (stale generated code, `.g.dart` merge conflicts) on top of everything else being rebuilt simultaneously. Recommendation: write `Notifier`/`AsyncNotifier` classes by hand for v1 (identical runtime behavior, just more explicit generic types); revisit codegen once the provider count is large enough that the boilerplate is measurably painful (a Phase 2/3 concern, not now).

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `pdf` | `^3.13.1` | Low-level PDF document construction (pages, text, tables, images) | Clinical history export, vaccination card export, invoice/quote PDF — all three "exportable to PDF" requirements in `PROJECT.md` |
| `printing` | `^5.15.1` | Preview, share, print, and save-to-file for a `pdf`-generated document; also ships `PdfGoogleFonts` | Wraps every PDF the app generates so the vet can preview it and share it via WhatsApp/email/print directly from the share sheet — this is the standard companion to `pdf`, maintained by the same author (DavBfr) |
| `image_picker` | `^1.2.3` | Camera capture / gallery picker for pet photos | Patient (mascota) photo field in the ficha — supports `maxWidth`/`maxHeight`/`imageQuality` params to downscale at picking time |
| `flutter_image_compress` | `^2.5.1` | Client-side JPEG/WebP re-compression before upload | Run after `image_picker` when the picked photo is still large (some Android cameras return >5MB originals despite `imageQuality`); keeps Supabase Storage usage and mobile data usage down — important for the "sin computador, todo desde el celular" use case where uploads happen over mobile data |
| `cached_network_image` | `^4.0.2` | Disk+memory caching for pet/patient photos rendered from Supabase Storage URLs | Every screen that lists patients/clients with a photo (patient list, ficha, dashboard) — avoids re-downloading the same photo on every rebuild/scroll |
| `intl` | `^0.20.3` (already pinned) | Locale-aware date and currency formatting | Already a dependency, already imported for date/number primitives, but not yet used for `es_CO`-specific formatting — see Locale section below |
| `flutter_local_notifications` | `^22.3.1` | Local (on-device) scheduled reminders | Appointment reminders and "próxima dosis" vaccination alerts are both in the Active scope; these are **local**, not remote push — the app already knows the due dates from Postgres, no server-triggered push is needed for v1 (WhatsApp reminders are explicitly Out of Scope / phase 2) |
| `timezone` | `^0.11.1` | IANA timezone database for scheduling notifications at a correct wall-clock time | Required companion to `flutter_local_notifications` for any `zonedSchedule(...)` call — without it, scheduled times drift with DST/timezone changes |
| `flutter_timezone` | `^5.1.0` | Reads the device's current IANA timezone name (`America/Bogota`) | `timezone` package itself cannot detect the device's zone; this plugin is the standard way to get it, needed once at app start to initialize the `timezone` package correctly |
| `permission_handler` | `^13.0.2` | Runtime permission requests (camera, photo gallery, notifications, exact alarms) | Needed for `image_picker` camera access and for Android 13+ notification permission / Android 14 exact-alarm permission required by `flutter_local_notifications` |
| `table_calendar` | `^3.2.1` | Month/week calendar UI widget with event markers | Agenda/citas screen — building a correct calendar grid with appointment dots by hand is a well-known time sink; this is the de-facto standard Flutter calendar widget |
| `url_launcher` | `^6.3.2` | Open `tel:`, `mailto:`, `https://wa.me/` links | Calling/WhatsApp-ing a client from their profile — low-risk, standard, Flutter-team-maintained |
| `share_plus` | `^13.3.0` | OS share sheet | Sharing a generated PDF (invoice/vaccination card) outside the app; `printing`'s `Printing.sharePdf(...)` already covers the PDF-specific case, but `share_plus` is useful for sharing non-PDF content (e.g. a text summary) |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `flutter_lints` | Already present (`^6.0.0`) | No change needed |
| `riverpod_lint` + `custom_lint` | Static analysis for Riverpod-specific mistakes (missing `ref.watch` disposal, provider misuse) | **Optional for this milestone.** Genuinely useful once real providers exist, but only pull it in if the manual (non-codegen) Notifier approach above is adopted — it still catches real bugs without requiring `build_runner`/codegen. If it adds friction, skip it; it is not load-bearing. |

## Installation

```bash
# PDF generation (clinical history, vaccination card, invoices)
flutter pub add pdf printing

# Pet photo capture + compression + caching
flutter pub add image_picker flutter_image_compress cached_network_image permission_handler

# Local reminders (appointments, vaccination due dates)
flutter pub add flutter_local_notifications timezone flutter_timezone

# Agenda UI
flutter pub add table_calendar

# Contact actions / sharing
flutter pub add url_launcher share_plus
```

`flutter_riverpod`, `go_router`, `intl`, and `supabase_flutter` are already in `pubspec.yaml` — no install step needed, only wiring code.

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|--------------------------|
| `pdf` + `printing` | `syncfusion_flutter_pdf` (`^34.2.9`) | Only if the app later needs advanced PDF *editing* (form fields, digital signatures, merging existing PDFs) or DIAN-integration-grade fixed layouts. Syncfusion requires a commercial license for teams (free "Community License" tier has revenue/employee-count caps) — unnecessary cost/complexity for generating simple structured documents from scratch, which `pdf`+`printing` (fully open-source, MIT-style) does perfectly well. |
| Manual `Notifier`/`AsyncNotifier` (Riverpod, no codegen) | `riverpod_generator` + `build_runner` | Switch once the app has enough parameterized/family providers (e.g. `patientByIdProvider(id)` repeated across many features) that hand-writing generic signatures becomes the dominant source of boilerplate/bugs. Revisit at the start of a future milestone, not mid-rebuild. |
| `flutter_local_notifications` (local reminders) | OneSignal / Firebase Cloud Messaging (remote push) | Needed only if reminders must reach the vet's device even when the app is fully closed for extended periods and the reminder is triggered server-side (e.g. a cron job on Supabase), or if the roadmap adds the "app complementaria para el dueño" (owner-facing app) from Out of Scope — that would need real push, not local notifications. |
| `image_picker` + `flutter_image_compress` | `image_cropper` | Add later only if the design calls for in-app photo cropping (e.g. forcing a square avatar crop) — not currently in the approved mockup per `PROJECT.md`; don't add speculatively. |
| Private Supabase Storage bucket + signed URLs | Public bucket with unguessable path | Public-bucket-by-obscurity is simpler to implement (no signed-URL refresh logic) but leaks any pet photo URL permanently to whoever it's shared with and doesn't respect the multi-tenant RLS model already established for every other table in `supabase/schema.sql`. Only acceptable if the team explicitly decides pet photos are low-sensitivity and wants to trade privacy for simplicity. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|--------------|
| `go_router ^18.0.0` | Requires Flutter 3.44/Dart 3.12 minimum SDK (verified in changelog) — incompatible with the current `sdk: ^3.11.1` constraint in `pubspec.yaml`; also migrates the whole widget-styling layer to new `material_ui`/`cupertino_ui` packages, an unrelated and larger change than "wire up navigation" | Stay on `go_router ^17.3.0` (already locked) until a deliberate, separate Flutter/Dart SDK upgrade is planned |
| `Navigator.push(MaterialPageRoute(...))` alongside `go_router` | Two competing navigation stacks produce unpredictable back-button/back-stack behavior; this is the exact anti-pattern already flagged in `.planning/codebase/ARCHITECTURE.md` | `context.go()` / `context.push()` / `context.pop()` exclusively, once `go_router` is wired |
| `StatefulWidget` + `setState()` for anything beyond pure local UI state (text field focus, animation state) | This is the current pattern for every mocked screen and is exactly what `flutter_riverpod` (already a dependency) is meant to replace; continuing it means the Riverpod dependency stays permanently dead weight | `Notifier` / `AsyncNotifier` + `ConsumerWidget`/`ConsumerStatefulWidget` |
| Instantiating `SupabaseAuthRepository(Supabase.instance.client)` (or any repository) inline inside widget build/callback methods | This is the current anti-pattern for auth (repo constructed ad hoc in `auth_screens.dart`); extending it to patients/clients/appointments/etc. means no single place to swap data sources, mock for tests, or add caching | Expose repositories via Riverpod `Provider`s (e.g. `final patientRepositoryProvider = Provider((ref) => SupabasePatientRepository(Supabase.instance.client));`) and inject via `ref.watch`/`ref.read` |
| `syncfusion_flutter_pdf` for basic document generation | Commercial license required beyond the free-tier revenue/team-size cap; massive API surface for a need (structured text+table PDFs) that `pdf`+`printing` already covers for free | `pdf` + `printing` |
| Public Supabase Storage bucket for pet photos with no RLS | Breaks the multi-tenant isolation model already enforced via Postgres RLS on every other table (`clinicas`/`perfiles`/`mascotas`) — a photo URL leak would cross clinic tenant boundaries | Private bucket + `storage.objects` RLS policy keyed on a `{clinica_id}/...` path prefix (mirrors the Postgres RLS pattern already used) + `createSignedUrl()` fetched by the authenticated client |

## Stack Patterns by Variant

**If offline mode is added later (flagged as deferred in `PROJECT.md`, important for rural vets):**
- Introduce `drift` (SQLite ORM) or Supabase's own local-first tooling for a local cache layer, plus `connectivity_plus` to detect connectivity changes.
- Do not attempt this now — it's explicitly deferred until the online CRUD is real, and retrofitting an offline cache onto Riverpod providers that don't exist yet would be premature.

**If a client/owner-facing app is added later (Out of Scope phase 3):**
- Revisit `flutter_local_notifications` → real push (FCM/OneSignal) since reminders would need to reach a device the vet doesn't control server-side triggers for.

**For the invoice/vaccination-card PDF branding:**
- Use `printing`'s `PdfGoogleFonts` (confirmed to ship inside the `printing` package, not a separate dependency) to load the same Figtree/Caprasimo families already used in the app's `google_fonts`-based theme (`lib/core/theme/app_typography.dart`), so exported PDFs visually match the in-app design system without manually bundling `.ttf` assets.

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|------------------|-------|
| `flutter_riverpod ^3.3.2` | `go_router ^17.3.0` | No direct dependency between them; wiring is done manually via `Provider<GoRouter>` + `GoRouterRefreshStream`, not a bridging package — no compatibility risk either way |
| `pdf ^3.13.1` | `printing ^5.15.1` | `printing 5.15.1` depends on `pdf: ^3.13.0` and `image: >=4.1.0 <=5.0.0` — the project's `image` (if added for compression) must stay `<=5.0.0` to avoid a version solve conflict with `printing` |
| `flutter_local_notifications ^22.3.1` | Dart SDK `^3.11.1` (project constraint) | `flutter_local_notifications` bumped its minimum SDK requirement to Flutter 3.38.1/Dart 3.10.0 as of v21.0.0 — compatible with the project's current `^3.11.1` constraint, no conflict |
| `go_router ^17.3.0` | Dart SDK `^3.11.1` (project constraint) | `go_router 17.3.0` itself requires Flutter 3.38/Dart 3.10 minimum — compatible; `18.x` requires Flutter 3.44/Dart 3.12 — **not** compatible without an SDK bump (see "What NOT to Use") |
| `supabase_flutter ^2.9.1` (locked `2.17.2`) | Storage signed-URL API used above | No version concern — Storage API (`createSignedUrl`, `upload`) has been stable across the 2.x line |

## Sources

- `/websites/pub_dev_flutter_riverpod_3_4_1` (Context7, via `ctx7` CLI) — AsyncNotifier/codegen migration guidance, confirmed manual vs. generated API parity
- pub.dev API (`https://pub.dev/api/packages/<name>`) — live version/publish-date lookup for every package listed above, queried 2026-09-23
- pub.dev changelogs (`https://pub.dev/packages/go_router/changelog`, `.../flutter_riverpod/changelog`, `.../flutter_local_notifications/changelog`) — verified breaking changes and minimum SDK requirements directly from source, not training data
- [Flutter: A Design Guide for Properly Handling redirect with go_router and Riverpod](https://zenn.dev/harx/articles/95c3bb3a991f59?locale=en) — MEDIUM confidence, cross-checked against multiple independent sources on the same `Provider<GoRouter>` + `refreshListenable` pattern
- [Q Agency — Handling Authentication State With go_router and Riverpod](https://q.agency/blog/handling-authentication-state-with-go_router-and-riverpod/) — MEDIUM confidence, corroborates `GoRouterRefreshStream` pattern
- [Supabase Storage Deep Dive — Bucket Design, Signed URLs, Image Transforms, and RLS](https://dev.to/kanta13jp1/supabase-storage-deep-dive-bucket-design-signed-urls-image-transforms-and-rls-3b9k) — MEDIUM confidence, standard private-bucket + RLS + signed-URL pattern for multi-tenant apps
- [Supabase Flutter — onAuthStateChange reference](https://supabase.com/docs/reference/dart/auth-onauthstatechange) — HIGH confidence, official docs, confirms the stream used for `GoRouterRefreshStream`
- [printing | Flutter package](https://pub.dev/packages/printing) — HIGH confidence, official package page, confirms `PdfGoogleFonts` and dependency bounds on `pdf`/`image`
- [pdf | Dart package](https://pub.dev/packages/pdf) — HIGH confidence, official package page

---
*Stack research for: Flutter + Supabase veterinary practice management app (Colombia)*
*Researched: 2026-09-23*
