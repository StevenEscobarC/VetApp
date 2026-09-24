# Walking Skeleton — VetApp

**Phase:** 1
**Generated:** 2026-09-24

## Capability Proven End-to-End

A veterinarian registers or signs in against the real cloud Supabase project and lands (via go_router, driven by a Riverpod `AsyncNotifier`) on a terracota/crema **Inicio** screen that shows their real `nombre` and clinic name read from Postgres through RLS.

User story: **As a** veterinario independiente, **I want to** iniciar sesión y ver mi nombre y el de mi clínica reales en la pantalla de Inicio, **so that** tenga la certeza de que la app ya trabaja sobre mi backend real y seguro (no sobre datos de prueba).

## Architectural Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Framework | Flutter (Dart `^3.11.1`, local toolchain Flutter 3.41.4), Material 3 widgets styled by custom `AppTheme` | Locked in CLAUDE.md; mobile-first for vets without a desk computer |
| Data layer | Supabase cloud Postgres (project `apjonrmhkpyzbofupokb`), single hand-maintained `supabase/schema.sql` pasted in the SQL Editor; no `supabase/migrations/` yet | Existing project convention (README); project was empty so a one-pass apply needs no migration tooling |
| Multi-tenancy | Every tenant-owned table carries `clinica_id`; RLS `public.es_veterinario() and clinica_id = public.mi_clinica_id()` is the ONLY isolation boundary (client does no tenant filtering) | Anon key is the only credential the app holds; RLS is the only enforceable boundary |
| Client (dueño) model | `public.clientes` table owned by `clinica_id`, no `auth.users` row; `mascotas (dueno_id, clinica_id)` composite FK to `clientes (id, clinica_id)` | FOUND-04 / D-06: vets register owners who never authenticate; composite FK stops cross-clinic owner linking |
| Privilege boundary | `perfiles_update` `WITH CHECK` pins `rol` and `clinica_id` to their pre-update values | Fixes the CLIENTE→VETERINARIO / clinic-hopping self-escalation (FOUND-05, D-03) |
| RLS verification | Single-paste `supabase/tests/rls_smoke_test.sql` (impersonates `authenticated` via `set_config('role')` + `request.jwt.claims`, always ends in a rollback-forcing exception carrying PASS/FAIL) plus `supabase/tests/verify_live_schema.sh` (anon REST probe) | D-03: manual smoke test, no pgTAP/CI suite this phase |
| Auth | Supabase email/password via `supabase_flutter`; profile = `perfiles` ⋈ `clinicas`; open VETERINARIO self-signup kept (D-05) | Already working in the repo; only its wiring changes |
| State management | `flutter_riverpod` 3.3.2, hand-written providers (no codegen). `supabaseClientProvider` → `authRepositoryProvider` → `authStateChangesProvider` (StreamProvider) → `authProfileProvider` (`AsyncNotifier<AuthProfile?>`) | Single injection point; every later feature repository derives from `supabaseClientProvider` |
| Navigation | `go_router` 17.x (do not bump to 18.x — needs Dart 3.12). `routerProvider` (`Provider<GoRouter>`), `refreshListenable` bridge on `authProfileProvider`, `StatefulShellRoute.indexedStack` with 5 branches `/inicio /pacientes /agenda /clientes /mas`, public `/splash /login /register /reset-password`, CLIENTE-only `/cliente` | FOUND-02; redirect is the single auth gate (replaces `AuthGate`) |
| Design system | `AppColors` terracota `#C67139` / crema `#F5EAD8`, `AppTypography` Caprasimo (display/headline/titleLarge) + Figtree (body/label) via `google_fonts` 8.2.0 (`GoogleFonts.caprasimoTextTheme()` verified present) | Approved mockup (DESIGN-REFERENCE.md, 01-UI-SPEC.md) |
| Secrets / config | `dart_define.json` (gitignored) holds `SUPABASE_URL` + anon `SUPABASE_ANON_KEY`; app run with `--dart-define-from-file=dart_define.json`; missing config shows a static error app instead of a degraded login | No keys in source; service_role never shipped |
| Deployment target | Local dev run on an Android emulator/device (or Windows desktop) against the cloud project: `flutter run --dart-define-from-file=dart_define.json` | No store/CI pipeline yet; documented local full-stack run satisfies the skeleton |
| Directory layout | Feature folders `lib/features/<feature>/{data,domain,presentation/{providers,screens}}`; cross-cutting `lib/core/{data,router,theme,widgets}`; tests in `test/` with shared fakes in `test/helpers/` | Matches existing scaffold; Phase 2+ add `data/repositories/*` + `presentation/providers/*` per feature |

## Stack Touched in Phase 1

- [ ] Project scaffold (framework, build, lint, test runner) — `flutter analyze` + `flutter test` green; Firebase leftovers removed (Plan 04)
- [ ] Routing — real go_router routes with auth redirect and 5-branch shell (Plan 02, Plan 05)
- [ ] Database — real read (`perfiles` ⋈ `clinicas` for Inicio) AND real write (registration → `auth.users` → trigger → `clinicas` + `perfiles`; smoke test writes `clientes`/`mascotas` inside a rolled-back transaction) (Plan 01, Plan 06)
- [ ] UI — Login/Register forms wired to Supabase Auth; Inicio renders the live profile; Más/Mis mascotas sign-out (Plan 02, Plan 05)
- [ ] Deployment — documented local full-stack run command, exercised by the human checkpoint in Plan 06

## Out of Scope (Deferred to Later Slices)

- Business dashboard metrics, próximas citas, accesos rápidos (Phase 8, D-02)
- Any CRUD UI for clientes/mascotas — the `clientes` table exists but has no screen until Phase 2
- Automated RLS suite (pgTAP/CI) — manual smoke test only (D-03)
- Approval flow for VETERINARIO self-signup (D-05)
- Desktop `NavigationRail` layout (old mock shell had one; mobile-first skeleton uses `NavigationBar` only)
- Confirmed dark-mode palette (dark values are derived/provisional per 01-UI-SPEC.md; re-confirm in Phase 8)
- Card corner radius / shadow retune to the mockup's 20-24px (Phase 8 design pass)
- Supabase CLI link + `supabase/migrations/` workflow (schema stays a single pasted file for now)
- Re-enabling mandatory email confirmation if it is switched off for development during Plan 01 (must be revisited before real users)
- Offline mode, WhatsApp, DIAN, AI features (v2 / out of scope)

## Subsequent Slice Plan

Each later phase adds one vertical slice on top of this skeleton without altering its architectural decisions:

- Phase 2: vet creates/edits/searches clientes and mascotas (first feature repositories derived from `supabaseClientProvider`, real screens replace `/clientes` and `/pacientes` placeholders)
- Phase 3: vet records append-only clinical history per mascota and exports it to PDF
- Phase 4: vet manages the day/week agenda (`/agenda`) with local and WhatsApp reminders
- Phase 5: vaccination/deworming card with auto next-dose and public read-only share link
- Phase 6: inventory with minimum-stock alerts
- Phase 7: quotes/invoices in PDF with automatic stock discount
- Phase 8: real business dashboard on `/inicio` and the full design pass across every screen
