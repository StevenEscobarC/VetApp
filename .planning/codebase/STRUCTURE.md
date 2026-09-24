# Codebase Structure

**Analysis Date:** 2026-09-24

## Directory Layout

```
VetApp/
├── lib/                          # All Dart/Flutter application source
│   ├── main.dart                 # App entry point, Supabase init, theme, AuthGate
│   ├── core/                     # Cross-feature shared code (design system only, today)
│   │   ├── theme/                # Design tokens + ThemeData (implemented)
│   │   ├── widgets/               # Shared UI atoms: app_bar, buttons, cards, inputs, status (implemented)
│   │   ├── router/               # Empty — no router implementation yet
│   │   ├── data/                 # Empty — no shared data utilities yet
│   │   ├── errors/                # Empty — no shared error types yet
│   │   ├── utils/                # Empty — no shared utils yet
│   │   └── constants/             # Empty — no shared constants yet
│   └── features/                 # One directory per feature, Clean-Architecture shaped
│       ├── auth/                 # Fully implemented (data + domain + presentation)
│       ├── home/                 # Single flat file, no data/domain/presentation split
│       ├── dashboard/            # Empty — no files at all
│       └── {appointments,billing,clients,clinical_history,inventory,patients,vaccination}/
│                                  # Scaffolded directory tree, only domain/entities/*.dart present
├── supabase/                     # Backend schema and Supabase CLI config
│   ├── schema.sql                # Tables, trigger, RLS policies (source of truth for backend)
│   └── config.toml                # Supabase CLI project config
├── test/                         # Flutter tests
│   └── widget_test.dart          # Single smoke test for AuthGate/LoginScreen
├── android/, ios/, linux/, macos/, web/, windows/   # Flutter platform embedding (generated scaffolding, standard Flutter project)
├── build/                        # Build output (generated, not committed logic)
├── .planning/                    # GSD planning artifacts (this map lives here)
├── pubspec.yaml                  # Dependency manifest
├── pubspec.lock                  # Locked dependency versions
├── analysis_options.yaml         # Dart/Flutter lint configuration
├── firebase.json                 # Legacy Firebase project config (see note below)
├── prompt-app-veterinaria-colombia.md  # Original product/design prompt used to scaffold the app
└── README.md                     # Setup instructions (Supabase-focused)
```

## Directory Purposes

**`lib/core/theme/`:**
- Purpose: single source of truth for visual styling.
- Contains: `app_colors.dart` (palette), `app_spacing.dart` (spacing/radius scale), `app_typography.dart` (text styles), `app_theme.dart` (composes the above into `ThemeData.light`/`ThemeData.dark`).
- Key files: `lib/core/theme/app_theme.dart` — only file `main.dart` should ever reference directly for theming.

**`lib/core/widgets/`:**
- Purpose: reusable, feature-agnostic UI components.
- Contains: `app_bar/app_top_bar.dart`, `buttons/app_button.dart`, `cards/app_card.dart`, `inputs/app_text_field.dart`, `status/app_status_chip.dart`.
- Key files: `lib/core/widgets/buttons/app_button.dart` (used by both `auth` and `home`).

**`lib/core/router/`, `lib/core/data/`, `lib/core/errors/`, `lib/core/utils/`, `lib/core/constants/`:**
- Purpose (intended): shared routing config, shared data helpers, shared exception/error types, generic utilities, app-wide constants.
- Contains: nothing — these are empty scaffold directories with zero files. Do not assume any shared error type, router, or util exists; each feature currently reimplements what it needs locally (e.g., `AuthFailure` lives inside the `auth` feature's own `domain/`, not in `core/errors/`).

**`lib/features/auth/`:**
- Purpose: the only fully implemented feature — login, registration, password reset, session restore, role-based routing to home.
- Contains: `data/repositories/supabase_auth_repository.dart` (concrete Supabase access + `AuthProfile` model), `domain/{auth_failure.dart, entities/veterinario.dart, repositories/auth_repository.dart, usecases/*.dart}` (unused abstraction layer — see ARCHITECTURE.md), `presentation/auth_screens.dart` (all screens + `AuthGate` in one file).
- Key files: `lib/features/auth/presentation/auth_screens.dart` (entry point for all auth UI and the app's effective root router), `lib/features/auth/data/repositories/supabase_auth_repository.dart` (all real backend logic).

**`lib/features/home/`:**
- Purpose: post-login veterinarian dashboard shell.
- Contains: a single file, `home_screen.dart` (1400 lines), holding a dead `LoginScreen` (superseded by `auth`'s version), `HomeScreen` (nav shell), and five static sub-screens (`DashboardScreen`, `PatientsScreen`, `AgendaScreen`, `HistoryScreen`, `BillingScreen`) — all hardcoded mock data, no `data/`/`domain/` split.
- Key files: `lib/features/home/home_screen.dart`.

**`lib/features/dashboard/`:**
- Purpose (intended): presumably meant to hold the real dashboard feature eventually, separate from the mock content currently living in `features/home/home_screen.dart`.
- Contains: nothing — completely empty, not even a `data`/`domain`/`presentation` subdirectory exists.

**`lib/features/{appointments,billing,clients,clinical_history,inventory,patients,vaccination}/`:**
- Purpose (intended): each represents a planned domain area (appointments/citas, billing/facturas, clients/clientes, clinical history/consultas, inventory/productos, patients/mascotas, vaccination/vacunas).
- Contains: only `domain/entities/<name>.dart` (e.g. `cita.dart`, `factura.dart`, `cliente.dart`, `consulta.dart`, `producto.dart`, `mascota.dart`, `vacuna.dart`). All other subdirectories (`data/datasources`, `data/models`, `data/repositories`, `domain/repositories`, `domain/usecases`, `presentation/providers`, `presentation/screens`, `presentation/widgets`) exist but are empty.
- Key files: e.g. `lib/features/patients/domain/entities/mascota.dart` (defines `Mascota`, `Especie`, `Sexo` — the most fleshed-out entity, matching the `mascotas` table in `supabase/schema.sql`).

**`supabase/`:**
- Purpose: backend schema and local Supabase CLI project config.
- Contains: `schema.sql` (tables `clinicas`/`perfiles`/`mascotas`, enum `rol_perfil`, signup trigger, RLS policies — must be pasted into Supabase SQL Editor per `README.md`), `config.toml` (CLI config), `.temp/` (CLI-generated, not meaningful source).
- Key files: `supabase/schema.sql` — the actual source of truth for what data model currently exists server-side; `lib/features/*/domain/entities/*.dart` for non-auth/patients features have **no corresponding tables yet** (only `clinicas`, `perfiles`, `mascotas` exist in the schema).

**`test/`:**
- Purpose: automated tests.
- Contains: `widget_test.dart` only — a single smoke test asserting `AuthGate` renders `LoginScreen` copy correctly. No unit tests for repositories, usecases, or entities exist anywhere.

**`android/`, `ios/`, `linux/`, `macos/`, `web/`, `windows/`:**
- Purpose: standard Flutter multi-platform embedding directories (generated by `flutter create`, customized minimally if at all).
- Contains: platform-specific manifest/build files; not application logic.

## Key File Locations

**Entry Points:**
- `lib/main.dart`: process entry point, Supabase bootstrap, theme, renders `AuthGate`.
- `lib/features/auth/presentation/auth_screens.dart`: effective root router (`AuthGate`) and all auth-related screens.

**Configuration:**
- `pubspec.yaml`: dependency manifest (Flutter SDK `^3.11.1`, `flutter_riverpod`, `go_router`, `supabase_flutter`, `google_fonts`, `intl`).
- `supabase/config.toml`: Supabase CLI local project settings.
- `analysis_options.yaml`: lint rules (`flutter_lints`).
- Runtime secrets: `SUPABASE_URL` / `SUPABASE_ANON_KEY` passed via `--dart-define` at `flutter run`/`flutter build` time — never stored in a committed file (see `README.md`).

**Core Logic:**
- `lib/features/auth/data/repositories/supabase_auth_repository.dart`: all real backend logic (auth + profile fetch) that currently exists in the app.
- `supabase/schema.sql`: all real backend data-model/authorization logic.

**Testing:**
- `test/widget_test.dart`: only test file in the repository.

## Naming Conventions

**Files:**
- `snake_case.dart` throughout (e.g. `supabase_auth_repository.dart`, `app_text_field.dart`, `sign_in_with_email.dart`).
- Entity files are named after the Spanish domain noun they represent (e.g. `mascota.dart`, `cita.dart`, `factura.dart`, `cliente.dart`, `consulta.dart`, `producto.dart`, `vacuna.dart`, `veterinario.dart`) — domain language is Spanish even though structural/technical naming (folders, class suffixes) is English.
- One class per usecase file, file name matches the class in `snake_case` (e.g. `sign_in_with_email.dart` → `SignInWithEmail`).

**Directories:**
- Per-feature Clean Architecture layout: `features/<feature_name>/{data,domain,presentation}/...` where `<feature_name>` is `snake_case` English (e.g. `clinical_history`, not `historial_clinico`), while the entities/classes inside are Spanish domain terms.
- `data/` subdivided into `datasources/`, `models/`, `repositories/`.
- `domain/` subdivided into `entities/`, `repositories/`, `usecases/`.
- `presentation/` subdivided into `providers/`, `screens/`, `widgets/`.
- `core/` subdivided by concern (`theme/`, `widgets/`, and the currently-empty `router/`, `data/`, `errors/`, `utils/`, `constants/`).

**Classes:**
- `PascalCase` for all types (entities, repositories, screens, usecases): `Veterinario`, `AuthRepository`, `SupabaseAuthRepository`, `SignInWithEmail`, `AuthFailure`, `Mascota`.
- Widget classes end with `Screen` for full-page widgets (`LoginScreen`, `RegisterScreen`, `ResetPasswordScreen`, `HomeScreen`, `DashboardScreen`) and no consistent suffix for smaller components (`AppButton`, `AppCard`, `AppTextField`).
- Domain entity fields and method names are in Spanish (`nombre`, `telefono`, `fechaRegistro`, `esVeterinario`, `edadEnAnios`), matching the Supabase column names (`nombre`, `telefono`, `clinica_id`) — keep this Spanish-domain-naming convention when adding new entities/fields to stay consistent with the schema and existing code.

## Where to Add New Code

**Completing a stub feature (e.g. patients, appointments):**
- Follow the exact shape already scaffolded: add a datasource in `lib/features/<feature>/data/datasources/`, a Supabase-backed repository in `lib/features/<feature>/data/repositories/` (name it `Supabase<Feature>Repository`, mirroring `SupabaseAuthRepository`), and wire the corresponding screen in `lib/features/<feature>/presentation/screens/` directly to that repository.
- Do not feel obligated to also implement the parallel `domain/repositories/` interface + `domain/usecases/` unless you intend to actually wire presentation through them — the existing `auth` feature shows this half of the architecture is currently unused dead weight; wiring presentation directly to the concrete data-layer repository is the pattern actually in production use today. If a future decision is made to enforce the domain abstraction, `auth` must be retrofitted at the same time for consistency.
- Any new Supabase table needed must be added to `supabase/schema.sql` with matching RLS policies (follow the `mascotas` table pattern: tenant/owner columns + `select`/`insert`/`update`/`delete` policies keyed on `auth.uid()` and `clinica_id`).

**New shared UI component:**
- Add to `lib/core/widgets/<category>/` (create a new category subdirectory if it doesn't fit `app_bar`, `buttons`, `cards`, `inputs`, `status`), name it `App<Thing>` to match existing convention (`AppButton`, `AppCard`, `AppTextField`, `AppStatusChip`).

**New design token:**
- Add to the relevant file in `lib/core/theme/` (`app_colors.dart`, `app_spacing.dart`, `app_typography.dart`) and reference it from `app_theme.dart`; never hardcode raw colors/spacing values in feature widgets.

**Replacing home_screen.dart mock content:**
- When implementing real data for `DashboardScreen`, `PatientsScreen`, `AgendaScreen`, `HistoryScreen`, or `BillingScreen`, move each out of `lib/features/home/home_screen.dart` into its proper feature directory (`lib/features/dashboard/presentation/screens/`, `lib/features/patients/presentation/screens/`, `lib/features/appointments/presentation/screens/`, `lib/features/clinical_history/presentation/screens/`, `lib/features/billing/presentation/screens/` respectively) rather than editing the monolithic file in place.

**New test:**
- Add to `test/`, following the existing `flutter_test` + `pumpWidget` smoke-test style in `test/widget_test.dart`. No test helper/fixture directory exists yet — create one under `test/` if fixtures are needed.

## Special Directories

**`build/`:**
- Purpose: Flutter/Dart build output.
- Generated: Yes.
- Committed: No (`.gitignore` excludes `/build/`).

**`.dart_tool/`:**
- Purpose: Dart tooling cache.
- Generated: Yes.
- Committed: No (`.gitignore` excludes `.dart_tool/`).

**`supabase/.temp/`:**
- Purpose: Supabase CLI temp state (e.g. `cli-latest` version marker).
- Generated: Yes.
- Committed: Not meaningful to review; effectively CLI cache.

**`android/`, `ios/`, `linux/`, `macos/`, `web/`, `windows/`:**
- Purpose: platform embedding shells created by `flutter create`.
- Generated: Yes (scaffolded), then customized minimally (e.g. app icons/signing) — not part of application logic covered by this map.
- Committed: Yes (platform config typically is committed in Flutter projects, unlike build output).

**`firebase.json`:**
- Purpose: leftover Firebase project configuration file at repo root.
- Generated: Originally scaffolded, likely from an earlier Firebase-based iteration of this project (consistent with the Firebase-referencing comments found in `lib/features/auth/domain/` — see ARCHITECTURE.md Anti-Patterns). The app's actual backend today is Supabase, not Firebase.
- Committed: Yes — verify whether this file is still needed before relying on it; it does not correspond to any Firebase SDK usage in `lib/`.

---

*Structure analysis: 2026-09-24*
