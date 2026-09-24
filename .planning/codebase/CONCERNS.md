# Codebase Concerns

**Analysis Date:** 2026-09-24

## Tech Debt

**Duplicate/dead `HomeScreen` mockup layer coexists with real auth flow:**
- Issue: `lib/features/home/home_screen.dart` (1400 lines) is a static, hand-built UI mockup containing its own `LoginScreen`, `HomeScreen`, `DashboardScreen`, `PatientsScreen`, `AgendaScreen`, `HistoryScreen`, `VaccinationScreen`, `InventoryScreen`, `BillingScreen`. It is wired into the real app only through `_VeterinarianHome` (`lib/features/auth/presentation/auth_screens.dart:391-396`), which simply returns `const HomeScreen()`. Every screen inside it uses hardcoded literals (e.g. `value: '08'`, `'04'`) and no-op button handlers (`onPressed: () {}` — see lines 81, 390, 473, 543, 693, 983, 1156).
- Files: `lib/features/home/home_screen.dart`, `lib/features/auth/presentation/auth_screens.dart`
- Impact: A veterinarian who logs in successfully sees a dashboard that shows fake data and buttons that do nothing (no real navigation to patients/agenda/billing data, no Supabase queries). This is easy to mistake for working functionality during manual QA or demos.
- Fix approach: Replace `DashboardScreen`/`PatientsScreen`/etc. with real screens backed by the (currently empty) `presentation/screens` + `presentation/providers` folders in each feature module, or explicitly label `home_screen.dart` as a throwaway prototype until those modules ship.

**Duplicate `LoginScreen` class defined twice, one is fully dead code:**
- Issue: `lib/features/home/home_screen.dart:10` defines a `StatelessWidget LoginScreen` with no controllers, a no-op forgot-password button, and a "Continuar con Google" button that just calls the same `onLogin` callback as the primary submit button. The real, functional `LoginScreen` (with `TextEditingController`s and Supabase wiring) lives in `lib/features/auth/presentation/auth_screens.dart:67`. Because both are `StatelessWidget`/`StatefulWidget` classes with the identical name `LoginScreen` in different files, only explicit imports prevent a collision, and the one in `home_screen.dart` is never imported/used anywhere.
- Files: `lib/features/home/home_screen.dart:10-113`
- Impact: Confusing for anyone editing "the login screen" — changes to the dead copy have zero effect, and a future refactor could accidentally re-introduce it or collide on the class name if both files are ever imported into the same scope.
- Fix approach: Delete the dead `LoginScreen` (and the unused `HomeScreen`/`_HomeScreenState` bottom-nav shell, if it is not the intended long-term shell) from `home_screen.dart`, or rename it clearly (e.g. `_MockLoginScreen`) if it's kept as a design reference.

**Firebase-era domain layer never migrated to Supabase, now entirely dead code:**
- Issue: `lib/features/auth/domain/` contains an `AuthRepository` interface (`repositories/auth_repository.dart`), a `Veterinario` entity (`entities/veterinario.dart`), an `AuthFailure` type (`auth_failure.dart`), and five use cases (`sign_in_with_email.dart`, `sign_in_with_google.dart`, `sign_up_with_email.dart`, `sign_out.dart`, `watch_current_veterinario.dart`) whose doc comments explicitly describe a **Firestore** data model (`"todos los demás datos... cuelgan de veterinarios/{id} en Firestore"`, `"la capa de datos traduce los códigos de Firebase..."`). The project has since moved to Supabase: the actually-used implementation is `SupabaseAuthRepository` + `AuthProfile` in `lib/features/auth/data/repositories/supabase_auth_repository.dart`, which does **not** implement the `AuthRepository` interface and is called directly from `auth_screens.dart`, bypassing the use-case layer entirely.
- Files: `lib/features/auth/domain/*` (all files), `firebase.json` (still configured for Firebase project `vetapp-colombia`), contrasted with `lib/features/auth/data/repositories/supabase_auth_repository.dart`
- Impact: The domain layer gives a false impression that clean-architecture use cases are wired up and that Google sign-in is implemented (`SignInWithGoogle` use case exists) when in reality there is no Google sign-in UI anywhere in `auth_screens.dart` and no repository actually implements `signInWithGoogle()`. `firebase.json` and its Android/iOS/web app IDs are orphaned config with no `firebase_core`/`firebase_auth` packages in `pubspec.yaml` or `pubspec.lock`.
- Fix approach: Delete `lib/features/auth/domain/` (repository interface, use cases, `Veterinario` entity, Firestore-era comments) and `firebase.json`, or rewrite the interface/use cases to match the Supabase `AuthProfile` shape and actually route `auth_screens.dart` through them.

**All non-auth features are scaffolding with only a domain entity — no implementation:**
- Issue: `appointments`, `billing`, `clients`, `clinical_history`, `dashboard`, `inventory`, `patients`, `vaccination` each have the full clean-architecture directory tree (`data/{datasources,models,repositories}`, `domain/{entities,repositories,usecases}`, `presentation/{providers,screens,widgets}`) but every directory except `domain/entities` is empty. Only one entity file per feature exists: `cita.dart`, `factura.dart`, `cliente.dart`, `consulta.dart`, `producto.dart`, `mascota.dart`, `vacuna.dart`. `lib/features/dashboard/domain/entities/` itself is empty (no entity at all).
- Files: `lib/features/{appointments,billing,clients,clinical_history,dashboard,inventory,patients,vaccination}/**`
- Impact: ~70 empty directories exist in the tree, which can mislead both humans and AI planning tools into thinking these features have partial implementations. `dashboard` has no entity, repository, or screen at all despite the directory scaffold existing.
- Fix approach: Either implement each layer as the corresponding feature is built, or remove empty directories until they're needed to avoid a misleading structure.

**Domain entities model a data shape that does not match the live Supabase schema:**
- Issue: Entities like `Cliente` (`veterinarioId`, `mascotaIds`), `Cita` (`veterinarioId`, `clienteId`), and `Mascota` (`clienteId`, `veterinarioId`, `sexo`, `pesoKg`, `color`, `fotoUrl`, `esterilizado`) assume a `Veterinario` → `Cliente` → `Mascota` hierarchy with a dedicated `clientes` table. The actual schema (`supabase/schema.sql`) only defines `clinicas`, `perfiles` (unified table for both `VETERINARIO` and `CLIENTE` roles via a `rol_perfil` enum), and `mascotas` (`dueno_id` referencing `perfiles`, `clinica_id` referencing `clinicas`, and only `nombre`/`especie`/`raza`/`fecha_nacimiento` columns — no `sexo`, `pesoKg`, `color`, `fotoUrl`, `esterilizado`).
- Files: `lib/features/clients/domain/entities/cliente.dart`, `lib/features/appointments/domain/entities/cita.dart`, `lib/features/patients/domain/entities/mascota.dart`, `supabase/schema.sql`
- Impact: When these features are implemented, the entities and repositories will need a redesign (or the schema will need new columns/tables) — this is aspirational domain modeling, not a contract already agreed with the backend.
- Fix approach: Reconcile entity fields with `supabase/schema.sql` before writing repositories/datasources for these features; extend the schema (e.g. add `sexo`, `peso_kg`, `color`, `foto_url`, `esterilizado` to `mascotas`) or trim the entities to match what exists today.

**`flutter_riverpod` and `go_router` are declared dependencies with effectively no real usage:**
- Issue: `flutter_riverpod: ^3.3.2` is only referenced once, to wrap the app in `ProviderScope` in `lib/main.dart:20` — no `Provider`, `Consumer`, `StateNotifier`, or `ref.watch` exists anywhere in `lib/`. `go_router: ^17.3.0` is declared in `pubspec.yaml` but never imported; all navigation uses raw `Navigator.of(context).push(MaterialPageRoute(...))` (`lib/features/auth/presentation/auth_screens.dart:131,146`; `lib/features/home/home_screen.dart:502-504,1243-1245`).
- Files: `pubspec.yaml`, `lib/main.dart`, `lib/features/auth/presentation/auth_screens.dart`, `lib/features/home/home_screen.dart`
- Impact: The intended state-management and routing architecture is not actually followed by any current screen, so any future code written "the way the app already does it" will further entrench raw `Navigator`/`StatefulWidget` patterns instead of the declared architecture, causing rework later.
- Fix approach: Decide early whether to commit to Riverpod + go_router (and migrate `auth_screens.dart`/`home_screen.dart` accordingly) or drop the unused dependencies to keep `pubspec.yaml` honest.

**`SupabaseAuthRepository` is re-instantiated per action instead of being a shared/injected instance:**
- Issue: `AuthGate` builds one instance in `initState` (`lib/features/auth/presentation/auth_screens.dart:31`), but `_LoginScreenState._submit()`, `_RegisterScreenState._submit()`, and `_ResetPasswordScreenState._submit()` each construct a brand-new `SupabaseAuthRepository(Supabase.instance.client)` inline instead of reusing a shared instance or passing it down.
- Files: `lib/features/auth/presentation/auth_screens.dart:96-98,193-194,299-301`
- Impact: Harmless today (the class is stateless besides the client reference), but it signals no dependency-injection pattern is in place; as more repositories are added this will multiply boilerplate and make testing/mocking the auth repository in widget tests difficult.
- Fix approach: Provide `SupabaseAuthRepository` via a Riverpod provider (once Riverpod is actually adopted) or via constructor injection from `AuthGate`.

## Known Bugs

**`TextEditingController`s are never disposed in auth screens:**
- Symptoms: Each of `_LoginScreenState`, `_RegisterScreenState` (8 controllers: `_name`, `_email`, `_phone`, `_password`, `_clinic`, `_city`, `_address`, `_clinicPhone`), and `_ResetPasswordScreenState` creates `TextEditingController()` fields but none of the three classes overrides `dispose()` to call `.dispose()` on them.
- Files: `lib/features/auth/presentation/auth_screens.dart` (classes `_LoginScreenState` ~line 76, `_RegisterScreenState` ~line 162, `_ResetPasswordScreenState` ~line 291)
- Trigger: Navigating to/from `RegisterScreen` or `ResetPasswordScreen` repeatedly (e.g. opening "Crear cuenta" and going back several times) leaks a `TextEditingController` (and its underlying `ChangeNotifier`/listeners) each time.
- Workaround: None currently; low practical impact for a login flow visited a handful of times per session, but is a real leak flagged by `flutter analyze`/`leak_tracker` and by the `flutter_lints` recommended set once `avoid_...`-style disposal lints are enforced.

**`SupabaseAuthRepository._profileFor` swallows the real error behind a generic message:**
- Symptoms: Any failure while fetching `perfiles` (e.g. RLS denial, network error, malformed row, missing profile row for a confirmed user) is caught by a bare `catch (_)` and rethrown as `AuthFailure('No encontramos tu perfil. Intenta de nuevo.')`, discarding the original exception/stack trace.
- Files: `lib/features/auth/data/repositories/supabase_auth_repository.dart:110-130`
- Trigger: A user confirms their email but the `on_auth_user_created` trigger failed to insert a `perfiles` row (e.g. metadata missing `rol`), or an RLS policy blocks the read — the app just says "we couldn't find your profile," with no way for developers to see why.
- Workaround: None; would require temporarily adding logging to diagnose.

**Google sign-in is advertised in the domain layer but has no UI entry point and no real implementation:**
- Symptoms: `SignInWithGoogle` use case and `AuthRepository.signInWithGoogle()` exist, but no repository implements them (`SupabaseAuthRepository` has no `signInWithGoogle` method), and no button in `auth_screens.dart` calls into this path. The only "Continuar con Google" button that exists is in the dead mockup `home_screen.dart:90-95`, which just calls the generic `onLogin` callback without any OAuth call.
- Files: `lib/features/auth/domain/usecases/sign_in_with_google.dart`, `lib/features/auth/domain/repositories/auth_repository.dart`, `lib/features/home/home_screen.dart:88-95`
- Trigger: Any attempt to wire up Google sign-in today would find no working implementation despite the interface suggesting one is planned/ready.
- Workaround: N/A — feature is not implemented.

## Security Considerations

**No password-strength enforcement beyond client-side length check; Supabase default policy relied on implicitly:**
- Risk: `_RegisterScreenState._submit()` only checks `_password.text.length < 8` client-side (`lib/features/auth/presentation/auth_screens.dart:178`). There is no complexity requirement, and the actual enforcement depends entirely on Supabase Auth server-side settings, which are not documented in `supabase/schema.sql` or `README.md`.
- Files: `lib/features/auth/presentation/auth_screens.dart:175-188`
- Current mitigation: Server-side Supabase Auth almost certainly rejects too-short passwords independently, and `SupabaseAuthRepository._messageFor` maps a `password`-related `AuthException` to a friendly message (`lib/features/auth/data/repositories/supabase_auth_repository.dart:146-148`).
- Recommendations: Document the expected Supabase Auth password policy in `README.md`/`supabase/config.toml` so client and server checks stay in sync, and add a repeat-password confirmation field to reduce sign-up typos.

**Self-registration allows anyone to create a `VETERINARIO` account and clinic with no verification:**
- Risk: `crear_perfil_nuevo_usuario()` in `supabase/schema.sql:46-75` automatically creates a new `clinicas` row and a `VETERINARIO` profile for any signup where the client sends `rol = 'VETERINARIO'` in user metadata — there is no admin approval, invite code, or domain-verification step. Any anonymous signer-upper can claim to run a clinic.
- Files: `supabase/schema.sql:46-80`, `lib/features/auth/presentation/auth_screens.dart:226-241` (role selector exposed directly to the end user during signup)
- Current mitigation: Email confirmation is required before the profile becomes usable (per `README.md`), and RLS scopes data access by `clinica_id`/`dueno_id` once a role is set.
- Recommendations: Before launch, add a verification/invite-code step for the `VETERINARIO` role, since clinic-admin capability (an isolated RLS tenant boundary) is currently granted purely on user-supplied signup metadata.

**`.env`-style secrets are not present, but no `.gitignore` protection layer exists specifically for local Supabase keys:**
- Risk: `README.md` correctly instructs passing `SUPABASE_URL`/`SUPABASE_ANON_KEY` via `--dart-define` rather than committing them, and `main.dart:10-11` reads them via `String.fromEnvironment`. However, there is no `.env.example`, no `.gitignore` entry blocking a stray `.env`/`secrets.json`, and no CI config exists to confirm keys are injected safely rather than hardcoded ad hoc by future contributors.
- Files: `.gitignore`, `lib/main.dart:10-17`, `README.md:14-23`
- Current mitigation: Anon/publishable key usage is explicitly called out as safe in `README.md:23`; no service-role key appears anywhere in the repo.
- Recommendations: Add a `.env.example` or a short "secrets" section in `.gitignore` proactively, and consider a `flutter_dotenv`/`--dart-define-from-file` convention now, before more contributors touch the auth flow.

## Performance Bottlenecks

**No performance bottlenecks detected in current code** — the codebase is pre-feature (only auth + a static mockup home screen exist), so there is no data-fetching, pagination, or list-rendering code yet to assess for performance. This should be re-evaluated once `patients`, `appointments`, and `clinical_history` data-fetching is implemented (watch especially the `_profileFor` join query in `supabase_auth_repository.dart:112-116`, which does a `clinicas(nombre)` embedded select on every login/profile read).

## Fragile Areas

**`lib/features/home/home_screen.dart` (1400 lines, single file, 20 classes):**
- Files: `lib/features/home/home_screen.dart`
- Why fragile: A single file mixes seven distinct "screens" (`DashboardScreen`, `PatientsScreen`, `AgendaScreen`, `HistoryScreen`, `VaccinationScreen`, `InventoryScreen`, `BillingScreen`) plus shared private widgets (`_SummaryCard`, `_ActionTile`, `_AppointmentCard`, `_PatientRow`, `_PatientCard`, `_AgendaItem`, `_TimelineItem`, `_InventoryItem`, `_InvoiceItem`, `_VaccinePill`) and a dead `LoginScreen`/`HomeScreen` pair. Any edit risks touching unrelated screens, and merge conflicts across features would collide in this one file since every feature currently renders through it.
- Safe modification: Split into one file per screen under each feature's own `presentation/screens/` directory (which already exists empty) before adding real logic, rather than continuing to grow this file.
- Test coverage: Zero — `test/widget_test.dart` only pumps `VetApp` and checks for auth-gate text; none of the seven mock screens are covered by any test.

**Trigger-based profile/clinic creation (`crear_perfil_nuevo_usuario`) is the single point of truth for account setup:**
- Files: `supabase/schema.sql:46-80`
- Why fragile: All account bootstrapping logic (role assignment, clinic creation, defaulting fields) lives in a single `plpgsql` trigger function with no automated tests and no version-controlled migration history (only one `schema.sql` file, not a timestamped migrations folder). A typo or bad `coalesce` default here silently corrupts every new signup's profile with no client-visible error until later reads fail.
- Safe modification: Introduce Supabase CLI migrations (`supabase/migrations/`) instead of a single mutable `schema.sql`, and add SQL-level tests (e.g. `pgTAP`) or at least a manual test checklist before altering the trigger.
- Test coverage: None — no tests reference or exercise `supabase/schema.sql` at all.

## Scaling Limits

**Not applicable yet** — the app has no implemented data-fetching feature (patients, appointments, billing, inventory, clinical history are all unimplemented), so there is no current query pattern to evaluate for N+1 issues or row-count limits. The one real query in production (`SupabaseAuthRepository._profileFor`, `lib/features/auth/data/repositories/supabase_auth_repository.dart:112-116`) is a single-row `.eq('id', userId).single()` lookup and has no scaling concern at current usage levels.

## Dependencies at Risk

**`go_router` and `flutter_riverpod` declared but unused (see Tech Debt above) — risk is architectural drift, not upstream package health.**
- Risk: Both packages are current, actively maintained majors (`go_router ^17.3.0`, `flutter_riverpod ^3.3.2`); the risk is entirely internal (unused dependency drift), not a supply-chain or maintenance concern.
- Impact: None today; future risk is that features get built with ad hoc `Navigator`/`StatefulWidget` patterns that must be migrated later once routing/state conventions are finally enforced.
- Migration plan: Adopt or remove — see Tech Debt section above.

**`firebase.json` references a live Firebase project (`vetapp-colombia`) with no corresponding Flutter packages:**
- Risk: The file still points at real Firebase App IDs for Android/iOS/Web (`firebase.json`), implying a Firebase project may still exist/be billed in a cloud console even though the codebase fully migrated to Supabase.
- Impact: Confusing for onboarding (a new contributor running `flutterfire configure` or similar could clobber this file) and a potential unnoticed cost/security surface if the Firebase project is still live with default rules.
- Migration plan: Delete `firebase.json` (and confirm/decommission the `vetapp-colombia` Firebase project in the Firebase console) now that Supabase is the sole backend.

## Missing Critical Features

**No routing/navigation layer for post-login flows beyond the static mockup:**
- Problem: There is no `GoRouter` configuration despite the dependency being present, and `_VeterinarianHome`/`ClientHomeScreen` are the only two post-login destinations, both effectively static. `ClientHomeScreen` (`lib/features/auth/presentation/auth_screens.dart:398-424`) only shows an empty state with two no-op buttons ("Agregar mascota", "Agendar cita").
- Blocks: Any real client-facing pet/appointment management flow; currently a client who signs up sees a permanently empty, non-interactive screen.

**No CI/lint-check automation found:**
- Problem: No `.github/workflows/`, no CI config of any kind was found in the repo tree; only `flutter_lints` is configured via `analysis_options.yaml` for local/IDE-time linting.
- Blocks: Catching the dead-code, missing-`dispose()`, and unused-dependency issues above automatically before merge; currently nothing enforces `flutter analyze`/`flutter test` on any change.

## Test Coverage Gaps

**Only one test exists in the entire repository:**
- What's not tested: `test/widget_test.dart` is the sole test file, and only asserts that `VetApp` boots to the login screen and shows a few expected strings (`Bienvenido a VetApp`, `Crear cuenta`, `Olvidé mi contraseña`). No tests exist for `SupabaseAuthRepository` (sign in/up/reset/profile-fetch logic, error-message mapping), `RegisterScreen`/`ResetPasswordScreen` validation logic, or any of the seven mock screens in `home_screen.dart`.
- Files: `test/widget_test.dart` (only file), everything under `lib/features/*` besides the boot path
- Risk: Any regression in sign-up validation (e.g. the `_role == 'VETERINARIO'` clinic-name-required check at `lib/features/auth/presentation/auth_screens.dart:185-188`) or in `_messageFor` error-string mapping (`lib/features/auth/data/repositories/supabase_auth_repository.dart:134-151`) would go unnoticed until manual QA or a user report.
- Priority: High — this is the only functional feature in the app today, and it has effectively no automated coverage of its business logic (only a smoke test of the initial widget tree).

**No integration/RLS tests against `supabase/schema.sql`:**
- What's not tested: The row-level-security policies (`clinicas_select`, `perfiles_select/update/insert`, `mascotas_select/insert/update/delete` in `supabase/schema.sql:105-143`) and the signup trigger (`crear_perfil_nuevo_usuario`) have no automated verification that a `CLIENTE` truly cannot read another clinic's data, or that a client cannot self-assign `VETERINARIO`/`clinica_id` via the `perfiles_insert` policy.
- Files: `supabase/schema.sql`
- Risk: A future edit to any policy (e.g. loosening `mascotas_select`) could silently break tenant isolation with no automated signal.
- Priority: High — RLS is the entire security boundary for multi-tenant data isolation in this app.

---

*Concerns audit: 2026-09-24*
