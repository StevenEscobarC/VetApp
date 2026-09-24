<!-- GSD:project-start source:PROJECT.md -->
## Project

**VetApp**

App móvil en Flutter para veterinarios independientes y clínicas pequeñas en Colombia que atienden sin recepcionista ni computador fijo (consultorio propio o a domicilio). Permite gestionar pacientes (mascotas), clientes (dueños), historia clínica, agenda, vacunación, inventario y facturación básica desde el celular, con Supabase como backend real y una identidad visual propia (no Material genérico).

**Core Value:** El veterinario puede llevar toda su consulta — pacientes, historia clínica, agenda — desde el celular, sin depender de un computador ni de una recepcionista.

### Constraints

- **Tech stack**: Flutter + Supabase (Postgres/RLS) — decisión ya tomada, no se reevalúa en v1.
- **Diseño**: debe seguir el mockup ya aprobado por el usuario (paleta terracota/crema, Caprasimo + Figtree) — no usar Material 3 genérico ni paleta "sobria" del prompt original.
- **Backend real, no mocks**: cada módulo de la Fase 1 debe conectar a Supabase real; no se sigue construyendo sobre datos falsos.
- **Mercado objetivo**: Colombia — moneda COP, formato de fecha dd/mm/aaaa.
- **Cuenta Supabase pendiente**: el usuario aún no tiene cuenta creada en supabase.com; es un bloqueante para conectar el backend real y debe resolverse al inicio de la Fase 1.
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- Dart `^3.11.1` (SDK constraint in `pubspec.yaml`) - entire application (`lib/`)
- SQL (PostgreSQL/PL-pgSQL) - Supabase schema, triggers, RLS policies in `supabase/schema.sql`
- Kotlin/Gradle (Android platform shell) - `android/app/build.gradle.kts`, `android/`
- Swift/Objective-C (iOS/macOS platform shell) - `ios/Runner/`, `macos/Runner/`
- C++/CMake (Windows/Linux desktop shells) - `windows/`, `linux/`
- YAML - `pubspec.yaml`, `supabase/config.toml`, `analysis_options.yaml`
## Runtime
- Flutter SDK, channel `stable`, revision `ff37bef603469fb030f2b72995ab929ccfc227f0` (`.metadata`)
- Multi-platform Flutter app: Android, iOS, Web, Windows, macOS, Linux all scaffolded (`android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`)
- Android: `applicationId = "com.vetapp.vetapp"` (`android/app/build.gradle.kts`), compileSdk/minSdk/targetSdk driven by Flutter tooling defaults
- iOS/macOS bundle id: `com.vetapp.vetapp` (`ios/Runner.xcodeproj/project.pbxproj`)
- `pub` (Dart/Flutter's native package manager)
- Manifest: `pubspec.yaml`
- Lockfile: present - `pubspec.lock` (committed, pins exact resolved versions)
## Frameworks
- Flutter (Material) - UI toolkit, `sdk: flutter` in `pubspec.yaml`
- `flutter_riverpod` `^3.3.2` (locked `3.3.2`, transitively pulls `riverpod` core `3.3.2`) - state management. `ProviderScope` wraps the app root in `lib/main.dart`; no feature-level providers are defined yet elsewhere in `lib/`
- `go_router` `^17.3.0` (locked `17.3.0`) - declarative routing package is a direct dependency, but `lib/core/router/` is currently an empty directory - routing is not yet wired up; `lib/main.dart` uses a plain `MaterialApp` with a static `home:` widget (`AuthGate`)
- `supabase_flutter` `^2.9.1` (locked `2.17.2`) - backend client (auth, Postgres, realtime, storage)
- `flutter_test` (SDK dev dependency) - only scaffold test present: `test/widget_test.dart` (default counter-app template, not adapted to this app)
- `flutter_lints` `^6.0.0` (locked `6.0.0`) - lint rule set, configured via `analysis_options.yaml` (`include: package:flutter_lints/flutter.yaml`, no custom rule overrides)
## Key Dependencies
- `supabase_flutter` `2.17.2` - sole backend integration: authentication, Postgres data access (`SupabaseClient.from(...)`), session persistence/restoration. Used directly in `lib/main.dart` and `lib/features/auth/data/repositories/supabase_auth_repository.dart`
- `flutter_riverpod` `3.3.2` - DI/state container, currently only bootstrapped (`ProviderScope`) with no providers defined in feature code
- `go_router` `17.3.0` - declared but unused; no `GoRouter` instance exists in the codebase yet (`lib/core/router/` is empty)
- `google_fonts` `^8.2.0` (locked `8.2.0`) - typography, referenced from `lib/core/theme/app_typography.dart`
- `intl` `^0.20.3` (locked `0.20.3`) - date/number formatting/localization primitives (Spanish-language app)
- `cupertino_icons` `^1.0.8` - iOS-style icon set
## Configuration
- No `.env` file present in the repository. Supabase credentials are injected at build/run time via Dart compile-time environment variables:
- `firebase.json` exists at repo root (project `vetapp-colombia`, referencing `lib/firebase_options.dart` and `android/app/google-services.json`) but **no Firebase Dart packages are declared** in `pubspec.yaml`/`pubspec.lock` (no `firebase_core`, `firebase_auth`, etc.) and `lib/firebase_options.dart` does not exist. This appears to be leftover FlutterFire scaffolding from an earlier setup step and is not part of the active stack - see `CONCERNS.md` if generated.
- `pubspec.yaml` - single source of truth for dependencies, Dart SDK constraint, and Flutter asset/font config (no custom fonts or assets currently declared)
- `analysis_options.yaml` - static analysis config, extends `flutter_lints/flutter.yaml` with no local overrides
- `supabase/config.toml` - local Supabase CLI stack configuration (API port `54321`, DB, Auth, Storage, Realtime, Edge Runtime all enabled for local dev via `supabase start`); no custom Edge Functions present (no `supabase/functions/` directory)
- `supabase/schema.sql` - hand-maintained SQL migration (tables, enum, trigger, RLS policies) intended to be pasted into the Supabase SQL Editor per `README.md` (no formal `supabase/migrations/` folder is used)
## Platform Requirements
- Flutter SDK (stable channel) matching Dart constraint `^3.11.1`
- Platform toolchains as needed per target: Android SDK/Gradle, Xcode (iOS/macOS), Visual Studio (Windows), standard Linux build toolchain
- Supabase account/project (cloud) or Supabase CLI + Docker for local stack (`supabase/config.toml`)
- Deployment target(s): not yet defined in-repo (no CI/CD config, no store listing files, no environment-specific build scripts beyond the standard Flutter platform folders)
- Backend: Supabase-hosted Postgres + Auth (cloud project, URL/key supplied at build time - no project ref committed)
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Naming Patterns
- `snake_case.dart` throughout, matching the primary class name in singular/verb form. Examples: `sign_in_with_email.dart`, `supabase_auth_repository.dart`, `app_status_chip.dart`, `app_text_field.dart`.
- Domain entity files are named after the noun they model (`mascota.dart`, `cliente.dart`, `veterinario.dart`, `cita.dart`, `consulta.dart`, `factura.dart`, `vacuna.dart`, `producto.dart`).
- Usecase files are named as `verb_noun_with_noun.dart` mirroring the class name (`watch_current_veterinario.dart` → `WatchCurrentVeterinario`).
- `PascalCase`. Domain terms are kept in **Spanish** even though the codebase (comments, identifiers, structure) mixes English and Spanish: `Veterinario`, `Mascota`, `Cliente`, `Cita`, `Consulta`, `Factura`, `Vacuna`, `Producto`, `AuthFailure`.
- Private widgets/helpers are prefixed with `_` and still `PascalCase`: `_AuthGateState`, `_AuthScaffold`, `_VeterinarianHome`, `_SummaryCard`, `_PatientRow` (`lib/features/home/home_screen.dart`).
- Repository implementations follow `<Provider><Domain>Repository`, e.g. `SupabaseAuthRepository` (`lib/features/auth/data/repositories/supabase_auth_repository.dart`) implementing the abstract `AuthRepository` (`lib/features/auth/domain/repositories/auth_repository.dart`).
- Usecase classes are single-purpose, named as an imperative verb phrase with **no `UseCase` suffix**: `SignInWithEmail`, `SignUpWithEmail`, `SignOut`, `SignInWithGoogle`, `WatchCurrentVeterinario` (all in `lib/features/auth/domain/usecases/`).
- `camelCase`. Private helpers prefixed with `_`: `_messageFor`, `_profileFor`, `_loadSession`, `_submit` (`lib/features/auth/presentation/auth_screens.dart`, `lib/features/auth/data/repositories/supabase_auth_repository.dart`).
- Usecase classes expose a single `call(...)` method so instances are invoked like functions: `SignInWithEmail(repo).call(email: ..., password: ...)` (`lib/features/auth/domain/usecases/sign_in_with_email.dart`).
- Boolean getters read as predicates: `esVeterinario` (`lib/features/auth/data/repositories/supabase_auth_repository.dart:24`), computed getters like `edadEnAnios` (`lib/features/patients/domain/entities/mascota.dart:36`).
- `camelCase`, in **Spanish for domain data** (`nombre`, `telefono`, `clienteId`, `veterinarioId`, `fechaNacimiento`) and **English for framework/UI plumbing** (`onPressed`, `isLoading`, `controller`, `errorText`).
- Private field state in `StatefulWidget`s uses a leading underscore and no `is`/`has` prefix convention beyond booleans: `_loading`, `_error`, `_profile` (`lib/features/auth/presentation/auth_screens.dart`).
- Enums are `PascalCase` names with lowercase `camelCase` values: `enum Especie { perro, gato, otro }`, `enum Sexo { macho, hembra }` (`lib/features/patients/domain/entities/mascota.dart`), `enum AppButtonVariant { primary, outline, text }` (`lib/core/widgets/buttons/app_button.dart`), `enum AppStatus { confirmed, pending, cancelled, completed }` (`lib/core/widgets/status/app_status_chip.dart`).
- Dart records (`({Color color, IconData icon, String label})`) are used for small internal lookup tables rather than defining a class, e.g. the private `_spec` getter in `lib/core/widgets/status/app_status_chip.dart:19`.
## Code Style
- Standard `dart format` output (trailing commas on multi-line constructors, no semicolon omission). No custom `.prettierrc`-equivalent; formatting is whatever `flutter_lints` + `dart format` enforce.
- Widget `build()` methods are frequently written as expression-bodied arrow functions when the whole widget is a single return, e.g. `Widget build(BuildContext context) => Scaffold(...)` (`lib/features/auth/presentation/auth_screens.dart:108`, `:221`, `:317`, `:351`, `:402`).
- `const` is used aggressively wherever the constructor allows it (`const SizedBox(...)`, `const Icon(...)`, `const AuthGate()`).
- `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml` with no rule overrides (`analysis_options.yaml`). Treat the default Flutter lint set as authoritative; do not disable rules without discussion.
- `pubspec.yaml` pins `flutter_lints: ^6.0.0` as the only dev-tooling dependency besides `flutter_test`.
## Import Organization
- No blank-line grouping convention beyond package-imports-before-relative-imports; there are no barrel files (`index.dart`-equivalents) anywhere in `lib/`.
- No path aliases configured in `pubspec.yaml`; imports always use relative paths within `lib/`, and only the test target imports via `package:vetapp/...` (`test/widget_test.dart:3`).
## Error Handling
- Domain-facing errors are a single custom `Exception` type per feature: `AuthFailure implements Exception` with just a `message` field (`lib/features/auth/domain/auth_failure.dart`). The doc comment explicitly states the intent: the data layer translates provider-specific errors (Supabase `AuthException`) into this type so **domain/presentation code never depends on the data provider's SDK directly**.
- Data-layer repository methods (`lib/features/auth/data/repositories/supabase_auth_repository.dart`) wrap every external SDK call in `try { ... } on AuthException catch (error) { throw AuthFailure(_messageFor(error)); } catch (_) { throw const AuthFailure('<generic Spanish message>'); }`. Always provide **both** a specific `on <SdkException>` branch and a generic catch-all fallback with a user-facing Spanish message.
- `_messageFor(AuthException error)` (`lib/features/auth/data/repositories/supabase_auth_repository.dart:134`) centralizes translation of raw provider error strings (lowercased substring checks) into Spanish, user-safe messages. Add new provider error mappings here rather than inline at call sites.
- Presentation widgets catch the domain failure type only (`on AuthFailure catch (error)`) and surface `error.message` directly in `setState` (`lib/features/auth/presentation/auth_screens.dart:100`, `:213`, `:307`). They do not catch generic `Exception`/`Object` — any unmapped error is expected to already have been normalized to `AuthFailure` by the data layer.
- No app-wide error boundary, logger, or crash-reporting integration exists yet — errors that aren't `AuthFailure` will propagate as unhandled Flutter framework errors.
## Comments
- File/class-level doc comments (`///`) explain **why**, not what — architectural intent, cross-feature relationships, or a non-obvious workaround. Examples:
- Inline `//` comments are rare and only used for non-obvious constants, e.g. `// Dark mode (full support, per style spec).` (`lib/core/theme/app_colors.dart:29`).
- Public classes that are part of the domain layer or shared widget library get a `///` doc comment; private/internal state classes and screen-glue widgets do not. Follow this asymmetry: document domain entities, repositories interfaces, and reusable `core/widgets/*` components; skip docs on private `_FooState` and one-off screen sections.
- Cross-references use Dart's `[Identifier]` doc-link syntax (`mascota.dart:5`) — use this when referencing other entities/classes in comments.
## Function Design
## Module Design
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## System Overview
```text
```
## Component Responsibilities
| Component | Responsibility | File |
|-----------|----------------|------|
| App bootstrap | Initializes Supabase (if env vars present), wraps app in `ProviderScope`, sets theme, renders `AuthGate` | `lib/main.dart` |
| AuthGate | De-facto root router: checks Supabase config, restores session, loads profile, decides Login vs role-based home | `lib/features/auth/presentation/auth_screens.dart` |
| SupabaseAuthRepository | Concrete auth/profile data access: sign in/up/out, password reset, profile fetch, Supabase error → Spanish message translation | `lib/features/auth/data/repositories/supabase_auth_repository.dart` |
| AuthProfile | Data-layer view model actually consumed by the UI (id, nombre, email, rol, telefono, clinicaId, clinicaNombre) | `lib/features/auth/data/repositories/supabase_auth_repository.dart` |
| AuthRepository (interface) / Veterinario / usecases | Domain-layer abstraction for auth — **defined but never referenced by any other file** | `lib/features/auth/domain/repositories/auth_repository.dart`, `lib/features/auth/domain/entities/veterinario.dart`, `lib/features/auth/domain/usecases/*.dart` |
| HomeScreen shell | Post-login veterinarian UI: `NavigationRail`/`NavigationBar` switching between 5 static sub-screens via `IndexedStack` | `lib/features/home/home_screen.dart` |
| Design tokens | Central color/spacing/typography/theme definitions consumed via `AppTheme.light` / `AppTheme.dark` | `lib/core/theme/app_theme.dart`, `app_colors.dart`, `app_spacing.dart`, `app_typography.dart` |
| Shared widgets | Reusable UI atoms (button, card, text field, status chip, top bar) used across features | `lib/core/widgets/**` |
| Domain entities (stub features) | Data shape for future features; no repository/usecase/datasource/screen exists yet | `lib/features/{appointments,billing,clients,clinical_history,inventory,patients,vaccination}/domain/entities/*.dart` |
| DB schema + RLS | Multi-tenant schema (clinicas → perfiles → mascotas), signup trigger, row-level security policies | `supabase/schema.sql` |
## Pattern Overview
- Directory layout signals intended Clean Architecture (`data/datasources`, `data/models`, `data/repositories`, `domain/entities`, `domain/repositories`, `domain/usecases`, `presentation/providers`, `presentation/screens`, `presentation/widgets`) per feature.
- In practice, the `auth` feature's presentation code (`auth_screens.dart`) instantiates the concrete `SupabaseAuthRepository` class directly (`SupabaseAuthRepository(Supabase.instance.client)`) inline inside widget callbacks — it never depends on the `AuthRepository` interface, never uses the `Veterinario` entity, and never calls any of the `domain/usecases/*.dart` classes. Those domain files are unused dead code.
- State management is plain `StatefulWidget` + `setState()` everywhere. `flutter_riverpod`'s `ProviderScope` wraps the app in `lib/main.dart` but no `Provider`, `StateNotifier`, `ConsumerWidget`, or `ref.watch` exists anywhere in `lib/`.
- Routing is manual `Navigator.push(MaterialPageRoute(...))` plus in-widget `IndexedStack`/`NavigationRail` index state. `go_router` is declared in `pubspec.yaml` but never imported anywhere in `lib/`.
- Multi-tenancy is enforced at the database layer via Postgres RLS (`supabase/schema.sql`), not in the Flutter client.
- Domain-layer comments reference **Firestore/Firebase** ("cuelgan de `veterinarios/{id}` en Firestore", "la capa de datos traduce los códigos de Firebase a este tipo") — e.g. `lib/features/auth/domain/entities/veterinario.dart:1-3` and `lib/features/auth/domain/auth_failure.dart:2-3` — even though the actual, wired implementation uses **Supabase** exclusively. This indicates the domain scaffolding predates (or was copy-pasted from) an earlier Firebase-based design and was never updated to match the Supabase implementation.
## Layers
- Purpose: Screens and widgets; owns all business logic for the one implemented feature (auth) inline in widget State classes.
- Location: `lib/features/auth/presentation/auth_screens.dart`, `lib/features/home/home_screen.dart`
- Contains: `StatefulWidget`/`StatelessWidget` classes, form controllers, direct Supabase client calls, hardcoded UI copy in Spanish.
- Depends on: `lib/features/auth/data/repositories/supabase_auth_repository.dart` directly (not through an interface); `lib/core/widgets/**`; `lib/core/theme/**`.
- Used by: `lib/main.dart` (renders `AuthGate`).
- Purpose: Concrete Supabase access + error translation.
- Location: `lib/features/auth/data/repositories/supabase_auth_repository.dart` (only implemented instance; `data/datasources`, `data/models` folders exist under other features but are empty).
- Contains: `SupabaseAuthRepository` (raw Supabase calls), `AuthProfile` (plain data class returned to the UI).
- Depends on: `package:supabase_flutter`, `lib/features/auth/domain/auth_failure.dart` (only domain file actually used, purely as an exception type).
- Used by: `presentation/auth_screens.dart`.
- Purpose: Intended business-rule layer (entities, repository interfaces, usecases).
- Location: `lib/features/*/domain/**`
- Contains: Entities (`Veterinario`, `Mascota`, `Cita`, `Factura`, `Cliente`, `Consulta`, `Producto`, `Vacuna`), one repository interface (`AuthRepository`), five auth usecases, `AuthFailure` exception.
- Depends on: Nothing (pure Dart, no Flutter/Supabase imports) — correctly isolated in principle.
- Used by: **Nothing**, except `AuthFailure`, which is used purely as an exception type by the data layer. All entities and the `AuthRepository` interface/usecases are unreferenced dead code as of this analysis.
- Purpose: Cross-feature design system and shared UI primitives.
- Location: `lib/core/theme/**` (tokens + `AppTheme`), `lib/core/widgets/**` (`AppButton`, `AppCard`, `AppTextField`, `AppStatusChip`, `AppTopBar`).
- Contains: Stateless style/config classes and small reusable widgets.
- Depends on: Flutter SDK only.
- Used by: `lib/main.dart`, `lib/features/auth/presentation/auth_screens.dart`, `lib/features/home/home_screen.dart`.
- Empty (scaffold-only, zero files): `lib/core/router/`, `lib/core/data/`, `lib/core/errors/`, `lib/core/utils/`, `lib/core/constants/`.
## Data Flow
### App Boot / Session Restore
### Sign-In
### Sign-Up
- Purely local widget state (`setState`) per screen; no shared/global app state container is actually wired despite `flutter_riverpod` being present.
- Session/profile state lives only in `_AuthGateState` (`_profile`, `_loading`) and is lost/rebuilt on full widget tree rebuild; no persistence layer beyond what `supabase_flutter` itself persists (its own session token storage).
## Key Abstractions
- Purpose: intended to abstract the auth backend behind an interface.
- Examples: `lib/features/auth/domain/repositories/auth_repository.dart` (interface, unused), `lib/features/auth/data/repositories/supabase_auth_repository.dart` (concrete class, used directly — does not `implements AuthRepository`).
- Pattern: broken — the concrete class is used as its own type everywhere; the abstraction it was meant to sit behind is never referenced.
- Purpose: single source of truth for color/spacing/typography so theming changes propagate app-wide.
- Examples: `lib/core/theme/app_colors.dart`, `app_spacing.dart`, `app_typography.dart`, composed by `app_theme.dart`.
- Pattern: static classes with private constructors (`AppSpacing._()`) exposing only `static const` fields — never instantiated.
- Purpose: domain data shapes with `copyWith`, used (in principle) independently of any persistence framework.
- Examples: `lib/features/patients/domain/entities/mascota.dart`, `lib/features/appointments/domain/entities/cita.dart`, `lib/features/billing/domain/entities/factura.dart`, etc.
- Pattern: `const` constructor + `copyWith()` method; no JSON (de)serialization, no Supabase mapping — these exist purely as future domain shapes, not yet connected to any `data/models` or Supabase table mapping code.
## Entry Points
- Location: `lib/main.dart`
- Triggers: Flutter engine on process start (mobile/desktop/web target set under `android/`, `ios/`, `web/`, `windows/`, `linux/`, `macos/`).
- Responsibilities: Supabase init (conditional), theme setup, render `AuthGate`.
- Location: `lib/features/auth/presentation/auth_screens.dart`
- Triggers: rendered unconditionally by `main.dart`; re-renders on internal `setState` after login/logout.
- Responsibilities: session bootstrap, role-based screen selection (veterinarian vs client), Supabase-not-configured fallback.
- Location: `test/widget_test.dart`
- Triggers: `flutter test`
- Responsibilities: single smoke test pumping `VetApp` and asserting login-screen copy is present (see also TESTING.md-equivalent coverage note below — no other tests exist in the repo).
## Architectural Constraints
- **Threading:** Standard single-threaded Flutter UI/event-loop model; no isolates, workers, or background tasks used anywhere.
- **Global state:** `supabaseConfigured` is a module-level `final` computed from `String.fromEnvironment` in `lib/features/auth/presentation/auth_screens.dart:10-13` — the only global/module-level state in the app. No singletons elsewhere.
- **Circular imports:** None detected — the feature/core layering is acyclic; the main issue is unused domain code, not circular coupling.
- **Environment configuration:** Supabase URL/anon key must be passed via `--dart-define` at build/run time (`lib/main.dart:10-11`); there is no `.env` file loading and no fallback config file. If unset, the app runs in a "not configured" degraded mode (`supabaseConfigured == false`) that still renders `LoginScreen` but blocks all auth actions.
- **Multi-tenancy enforcement:** Tenant isolation (`clinica_id`) is enforced exclusively via Postgres RLS policies in `supabase/schema.sql` — the Flutter client performs no additional tenant-scoping logic itself; any future feature querying `mascotas` or other tenant-scoped tables relies entirely on RLS being correct.
## Anti-Patterns
### Domain layer defined but bypassed
### Declared-but-unused core dependencies (Riverpod, go_router)
### Feature-directory scaffolding without implementation
### Hardcoded/mock UI presented as the main app screen
## Error Handling
- `AuthFailure implements Exception` carries a pre-translated, user-facing message (`lib/features/auth/domain/auth_failure.dart`).
- `SupabaseAuthRepository._messageFor(AuthException)` pattern-matches on lowercased substrings of the raw Supabase error message (`invalid login credentials`, `already registered`, `email not confirmed`, `password`, `email`) and returns a fixed Spanish string, with a generic catch-all otherwise (`lib/features/auth/data/repositories/supabase_auth_repository.dart:134-151`).
- Every repository method wraps its Supabase call in `try { ... } on AuthException catch (error) { throw AuthFailure(_messageFor(error)); } catch (_) { throw const AuthFailure('...'); }` — a consistent two-tier catch (`lib/features/auth/data/repositories/supabase_auth_repository.dart:40-53, 66-88, 91-100, 111-129`).
- Presentation widgets catch `AuthFailure` specifically and set it into `_error`/`_message` state for display (`lib/features/auth/presentation/auth_screens.dart:100-104, 213-216, 307-313`).
- No error handling exists outside the auth feature (no other feature has any backend calls yet).
## Cross-Cutting Concerns
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

| Skill | Description | Path |
|-------|-------------|------|
| banner-design | "Design banners for social media, ads, website heroes, creative assets, and print. Multiple art direction options with AI-generated visuals. Actions: design, create, generate banner. Platforms: Facebook, Twitter/X, LinkedIn, YouTube, Instagram, Google Display, website hero, print. Styles: minimalist, gradient, bold typography, photo-based, illustrated, geometric, retro, glassmorphism, 3D, neon, duotone, editorial, collage. Uses ui-ux-pro-max, frontend-design, ai-artist, ai-multimodal skills." | `.claude/skills/banner-design/SKILL.md` |
| brand | Brand voice, visual identity, messaging frameworks, asset management, brand consistency. Activate for branded content, tone of voice, marketing assets, brand compliance, style guides. | `.claude/skills/brand/SKILL.md` |
| design | "Comprehensive design skill: brand identity, design tokens, UI styling, logo generation (55 styles, Gemini AI), corporate identity program (50 deliverables, CIP mockups), HTML presentations (Chart.js), banner design (22 styles, social/ads/web/print), icon design (15 styles, SVG, Gemini 3.1 Pro), social photos (HTML→screenshot, multi-platform). Actions: design logo, create CIP, generate mockups, build slides, design banner, generate icon, create social photos, social media images, brand identity, design system. Platforms: Facebook, Twitter, LinkedIn, YouTube, Instagram, Pinterest, TikTok, Threads, Google Ads." | `.claude/skills/design/SKILL.md` |
| design-system | Token architecture, component specifications, and slide generation. Three-layer tokens (primitive→semantic→component), CSS variables, spacing/typography scales, component specs, strategic slide creation. Use for design tokens, systematic design, brand-compliant presentations. | `.claude/skills/design-system/SKILL.md` |
| slides | Create strategic HTML presentations with Chart.js, design tokens, responsive layouts, copywriting formulas, and contextual slide strategies. | `.claude/skills/slides/SKILL.md` |
| ui-styling | Create beautiful, accessible user interfaces with shadcn/ui components (built on Radix UI + Tailwind), Tailwind CSS utility-first styling, and canvas-based visual designs. Use when building user interfaces, implementing design systems, creating responsive layouts, adding accessible components (dialogs, dropdowns, forms, tables), customizing themes and colors, implementing dark mode, generating visual designs and posters, or establishing consistent styling patterns across applications. | `.claude/skills/ui-styling/SKILL.md` |
| ui-ux-pro-max | "UI/UX design intelligence. Searchable local database with 67 styles, 161 palettes, 57 font pairings, 25 charts, and 21 stacks (React, Next.js, Vue, Svelte, Astro, SwiftUI, React Native, Flutter, WPF, WinUI 3, UWP, Avalonia, Uno Platform, Nuxt, Nuxt UI, Tailwind, shadcn/ui, Jetpack Compose, Three.js, Angular, Laravel). Use when designing, building, or reviewing UI: pages, components, color schemes, typography, layout, accessibility, animation, or data visualization." | `.claude/skills/ui-ux-pro-max/SKILL.md` |
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
