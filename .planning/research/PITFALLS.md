# Pitfalls Research

**Domain:** Veterinary practice management software (mobile-first, Colombia) + Flutter/Supabase brownfield rebuild (mocked UI → real, RLS-secured data)
**Researched:** 2026-09-23
**Confidence:** MEDIUM-HIGH (Supabase RLS, Riverpod, and go_router pitfalls are verified against official docs/GitHub issues and multiple independent sources; veterinary-domain-specific pitfalls are MEDIUM confidence, synthesized from practice-management vendor content and general EMR/timeline-design literature — no vet-specific post-mortem literature exists publicly, so these are inferred from adjacent domains plus the concrete mismatches already found in this codebase)

## Critical Pitfalls

### Pitfall 1: RLS "looks secure" because it works in your own testing, but the anon key path was never actually exercised

**What goes wrong:**
Developers write and test RLS policies using the Supabase SQL editor or a service-role connection (which bypasses RLS entirely), see queries return the expected rows, and conclude the policy works. In production the Flutter app only ever holds the anon/publishable key, and policy bugs (missing `USING`, missing `WITH CHECK` on inserts, wrong join direction on `clinica_id`) surface only when a real client-role user hits the API — often as an empty result set or, worse, as another clinic's data being returned.

**Why it happens:**
The Supabase dashboard SQL editor and CLI `psql` connections typically run as `postgres`/service-role, which ignores RLS. It's easy to "confirm the policy is right" without ever running the query as the actual `anon`/`authenticated` role the app uses.

**How to avoid:**
- Test every policy with `SET ROLE authenticated; SET request.jwt.claims = '...';` (or Supabase's `supabase test db` / pgTAP) impersonating a real user, not just as postgres.
- For every table, write both a positive test ("clinic A vet can read clinic A pet") and a negative test ("clinic B vet cannot read clinic A pet"; "CLIENTE cannot set `clinica_id`/`rol` on insert").
- Add `WITH CHECK` clauses to every `insert`/`update` policy, not just `USING` — `USING` alone only filters what's visible, not what can be written.
- This project already has zero RLS tests (flagged in CONCERNS.md) — this is not hypothetical, it's the current state.

**Warning signs:**
- Any RLS policy that only has `USING (...)` and no `WITH CHECK (...)` on an insert/update policy.
- Manual QA that only ever uses one veterinarian account with a service-role-connected admin tool for verification.
- No automated test file references `supabase/schema.sql` policies (currently true).

**Phase to address:**
Foundation/Supabase-setup phase (when the schema is first applied to a real project) and again every time a new table/feature adds policies (patients, clients, clinical history, agenda, inventory, billing).

---

### Pitfall 2: Role/tenant privilege escalation via a user-writable `perfiles` row

**What goes wrong:**
If a `CLIENTE` (or any authenticated user) can `UPDATE` their own row in `perfiles` and that row contains `rol` and/or `clinica_id`, they can promote themselves to `VETERINARIO` or attach themselves to a different clinic's tenant, defeating the entire RLS boundary — because most other tables' policies key off `es_veterinario()`/`mi_clinica_id()`, which read straight from this same table.

**Why it happens:**
It's natural to expose a "my profile" update policy (`perfiles_update`) so users can edit their name/phone. If that policy's `WITH CHECK` doesn't explicitly forbid changing `rol`/`clinica_id`, the update succeeds silently.

**How to avoid:**
- Split `perfiles` into "safe self-editable columns" (name, phone, avatar) vs. "privileged columns" (`rol`, `clinica_id`) using either a restrictive `WITH CHECK` that compares old vs. new values (`rol = (select rol from perfiles where id = auth.uid())`), a separate admin-only table, or a Postgres trigger that rejects role/tenant changes from non-admin callers.
- Never let the signup metadata (`rol` in `auth.users.raw_user_meta_data`) be trusted as-is for anything beyond the initial trigger-based row creation — the current `crear_perfil_nuevo_usuario` already does this at signup (self-service `VETERINARIO` with no verification, flagged in CONCERNS.md) and that same trust boundary must not also apply to later updates.
- This is separate from the already-flagged "anyone can self-register as VETERINARIO" issue — that one is about account creation; this one is about privilege escalation post-creation.

**Warning signs:**
- Any `perfiles_update` policy with `USING (id = auth.uid())` and no column-level restriction.
- `rol` or `clinica_id` present in the same update payload path as user-editable profile fields in the Flutter form.

**Phase to address:**
Foundation/Supabase-setup phase — must be fixed before any other feature relies on `es_veterinario()`/`mi_clinica_id()` for tenant isolation. Verify with an explicit RLS test: "authenticated CLIENTE attempts `UPDATE perfiles SET rol = 'VETERINARIO'` on own row → must fail."

---

### Pitfall 3: The signup trigger silently corrupts or blocks account creation, with no visibility

**What goes wrong:**
`crear_perfil_nuevo_usuario` is a single `plpgsql` trigger on `auth.users` with no tests and no migration history. A schema change elsewhere (e.g., adding a `NOT NULL` column to `perfiles` or `mascotas`, renaming a field the trigger references) breaks the trigger, which then makes every new signup fail with a generic Postgres 500 ("Database error saving new user") — already a known Supabase footgun independent of this project. Because `SupabaseAuthRepository._profileFor` also swallows the underlying exception behind a generic "No encontramos tu perfil" message (per CONCERNS.md), developers get zero diagnostic signal from either side.

**Why it happens:**
Trigger functions run inside the `auth.users` insert transaction; any exception rolls back the whole signup. Security-definer trigger functions plus a hand-maintained single `schema.sql` (not versioned migrations) make it easy to introduce a breaking change without noticing until real users hit it.

**How to avoid:**
- Move to Supabase CLI migrations (`supabase/migrations/`) instead of one mutable `schema.sql`, so every schema change is reviewed as a diff and can be tested against the trigger before merge.
- Add at least a manual (ideally pgTAP) test: "signup with `rol=VETERINARIO` + clinic fields creates exactly one `clinicas` row and one `perfiles` row"; "signup with `rol=CLIENTE` creates exactly one `perfiles` row and zero `clinicas` rows."
- Stop swallowing the original error in `_profileFor` — log the real exception (even just to console in dev) before mapping to the user-facing Spanish string, otherwise every future schema drift becomes a silent, undebuggable production incident (already true today for any RLS denial or malformed row).
- Check Supabase Auth logs (dashboard → Logs → Auth) as the first debugging step for any "couldn't find profile" report — the trigger error will appear there even though the Flutter app hides it.

**Warning signs:**
- Any schema migration that touches `perfiles`, `clinicas`, or `mascotas` columns referenced by the trigger, without immediately testing a fresh signup end-to-end.
- Support/QA reports of "can't sign up" or "signed up but app says profile not found" with no corresponding client-side stack trace.

**Phase to address:**
Foundation/Supabase-setup phase (introduce migrations + trigger tests before building on top of auth), revisited whenever `perfiles`/`clinicas`/`mascotas` schema changes in later feature phases.

---

### Pitfall 4: Riverpod/go_router adoption is deferred "for later" and the app entrenches raw `Navigator`/`StatefulWidget` patterns instead

**What goes wrong:**
`flutter_riverpod` and `go_router` are already declared dependencies with effectively zero real usage (confirmed in CONCERNS.md — only `ProviderScope` wraps the app; all navigation is raw `Navigator.push(MaterialPageRoute(...))`). If the team starts building patients/clients/agenda screens "the way the code already does it" (copy-pasting the existing `StatefulWidget` + `Navigator` pattern from `auth_screens.dart`/`home_screen.dart`), every new feature adds more code that must be migrated later, and the migration cost compounds with each screen added before the decision is made.

**Why it happens:**
It's the path of least resistance to extend existing patterns rather than introduce new ones, especially early in a rebuild when "just get it working" pressure is high. Nobody wants to be the first screen using a different pattern than everything around it.

**How to avoid:**
- Decide explicitly, before writing the first real CRUD screen (patients), whether to commit to Riverpod + go_router or drop them. Given they're already in `pubspec.yaml` and the roadmap explicitly calls for "wiring real Riverpod + go_router," commit — don't defer.
- Build one small vertical slice first (e.g., a single real provider + a single `GoRoute` for the patients list) as the reference pattern before parallelizing work across features, so every subsequent screen copies a real pattern, not the mock's `Navigator` pattern.
- Delete or clearly quarantine `home_screen.dart`'s Navigator-based screens before other engineers use them as a template.

**Warning signs:**
- A new feature branch adds `Navigator.push(MaterialPageRoute(...))` instead of `context.go()`/`context.push()`.
- A new screen reads data via a directly-constructed repository inside `initState` instead of via a Riverpod provider.

**Phase to address:**
Foundation phase (explicitly named in PROJECT.md as "Wiring real de gestión de estado (Riverpod) y navegación (go_router)") — must land before or alongside the first CRUD feature (patients), not after.

---

### Pitfall 5: Over-fragmented or overly-global Riverpod providers cause rebuild storms and untestable coupling

**What goes wrong:**
Two opposite failure modes both show up commonly in Riverpod codebases built by teams new to it: (a) every derived value gets its own provider even when it's a trivial map of another provider, leading to provider sprawl that's hard to navigate; or (b) screen-local/ephemeral UI state (selected tab, form validity, whether a dropdown is open) gets hoisted into global providers, which bloats rebuilds and couples unrelated screens. A third common issue: providers that chain (`providerB` reads `providerA` reads `providerC`) make it impossible to test one provider in isolation — you end up testing the whole graph.

**Why it happens:**
Riverpod's ergonomics make it very easy to add "just one more provider," and without an early convention (when is a provider justified vs. a plain getter/local `setState`?), the pattern proliferates inconsistently across features built by different people/sessions.

**How to avoid:**
- Establish a simple rule early: global/shared providers for anything that represents server-backed or cross-screen state (auth session, current clinic, patients list); local `StatefulWidget`/`useState`-equivalent for purely ephemeral UI state (form field focus, expanded/collapsed sections).
- Keep repository calls (the actual Supabase query) inside the provider/notifier layer, not inside widgets — but keep the notifier itself thin (call repository, expose `AsyncValue`), not a place where business logic and HTTP-adjacent logic mix.
- Avoid assigning a notifier instance to a local variable and reusing it across async gaps (`ref.read(provider.notifier)` right before use, not cached) — this is the single most-cited source of "stale notifier reference" bugs in Riverpod codebases.

**Warning signs:**
- A provider whose body is just `ref.watch(otherProvider).someField` with no other logic.
- `ref.watch` used for values only read once inside a callback (should be `ref.read`).
- A widget test that requires overriding five providers to test one screen.

**Phase to address:**
Foundation phase (establish convention in the reference vertical slice) — re-audited at each subsequent feature phase (patients, clients, agenda, vaccination, inventory, billing) as new providers are added.

---

### Pitfall 6: Domain entities were designed against an imagined schema, not the real one — and this repeats every time a new feature is scaffolded before checking `schema.sql`

**What goes wrong:**
CONCERNS.md already documents that `Cliente`, `Cita`, and `Mascota` entities assume fields/tables (`clientes` table, `sexo`, `pesoKg`, `color`, `fotoUrl`, `esterilizado`) that don't exist in `supabase/schema.sql` (which only has `clinicas`, `perfiles`, `mascotas` with a much smaller column set). If each remaining feature (agenda, clinical history, vaccination, inventory, billing) is implemented by first writing a Dart entity "the way it should look" and only later reconciling it with the actual Postgres schema, every feature repeats this same rework cycle — write repository, discover schema mismatch, alter schema or trim entity, rewrite repository.

**Why it happens:**
Clean-architecture scaffolding encourages defining the domain entity first, independent of the data layer — which is good for decoupling but bad when the "real" schema already exists and just hasn't been consulted yet. It's faster to imagine a shape than to open `schema.sql`.

**How to avoid:**
- Before writing any entity/repository for a new feature, read the actual current `supabase/schema.sql` (or, once migrations exist, the latest applied migration) for the relevant table(s) first. Treat the schema as the source of truth to reconcile against, not a suggestion.
- Any new required field discovered during entity design (e.g., `mascotas.sexo`) becomes an explicit, reviewed migration — not a silent assumption baked into the Dart model.
- For vaccination and clinical history specifically (not yet in `schema.sql` at all), design the table schema first (with the vet-domain modeling concerns in Pitfalls 7-9 below in mind) and generate the entity from it, not the reverse.

**Warning signs:**
- A Dart entity field with no corresponding column in `schema.sql`.
- A repository method that would require a join/table that doesn't exist yet.

**Phase to address:**
Every feature phase (patients, clients, clinical history, agenda, vaccination, inventory, billing) — add "reconcile entity with schema.sql" as an explicit step before repository implementation in each phase's task list.

---

### Pitfall 7: Vaccination scheduling modeled as "one date field" instead of a dose/series state machine

**What goes wrong:**
A naive vaccination model stores a single `fecha_proxima_dosis` (next-dose date) per vaccine type per pet. This breaks down immediately for real veterinary workflows: puppies/kittens need a multi-dose primary series (e.g., 3 doses of the polyvalent/óctuple vaccine at intervals before a single annual booster applies), different biologics have different revaccination intervals (rabies is often annual or triennial depending on product; polyvalent is annual), and a missed/delayed dose should shift the *entire remaining schedule*, not just silently show "overdue" forever. Without a proper series/dose model, the "próxima dosis" alert either fires incorrectly for puppies still in their primary series or fails to distinguish "first dose ever" from "annual booster."
This directly maps to the PROJECT.md requirement: "Carné de vacunación... con alertas automáticas de próxima dosis."

**Why it happens:**
It's the simplest thing that could work for a demo (one date, one alert), and the complexity of dose series/intervals per biologic only becomes visible once real veterinarians use it with real puppies/kittens.

**How to avoid:**
- Model vaccination as records of *administered doses* (`vacuna_id`, `mascota_id`, `fecha_aplicacion`, `lote`, `veterinario_id`) plus a small reference table of vaccine-type protocols (biologic name, species applicability, doses-in-primary-series, interval-between-doses, revaccination-interval-after-series). Compute "next dose due" from the protocol + dose history, don't store it as a mutable field that can drift out of sync with the history.
- Support species-specific and age-specific protocols from day one for the two named biologics in scope (antirrábica, óctuple/polivalente) — don't hardcode a single global interval.
- Decouple "vaccine administered" from "invoice line item" even though they're often the same clinical event — vaccination history must survive even if billing for that visit is later voided/edited.

**Warning signs:**
- A single `proxima_dosis` date column directly on the pet or vaccine-application record with no link back to a dose-count/series concept.
- No distinction in the data model between "puppy primary series dose 1/2/3" and "adult annual booster."

**Phase to address:**
Vaccination feature phase — should be scoped with explicit schema design review before implementation, given it's a named differentiator ("alertas automáticas de próxima dosis") and the most domain-logic-heavy feature in scope.

---

### Pitfall 8: Clinical history modeled as free-text blobs instead of structured, timestamped, append-only events

**What goes wrong:**
Veterinary practice-management literature repeatedly notes that many PIMS store clinical records as free text captured after the visit ("documentation defaults to memory, completed between appointments or at the end of the day") rather than structured data captured at the point of care. For this project's stated requirement — "línea de tiempo por paciente, exportable a PDF" — a free-text-only model makes the timeline feature nearly impossible to render meaningfully (no way to distinguish diagnosis from treatment from follow-up note) and makes PDF export just "one big text dump" rather than a real clinical record. A second, related trap: allowing clinical history rows to be edited/deleted in place rather than appended-to, which both loses the true history and creates legal/liability exposure (a clinical record should be an audit trail).
Note this also intersects with multi-pet-per-owner: a timeline must be scoped per-pet, but the client/owner view (once built, currently `ClientHomeScreen` is an empty stub) should also be able to see history across all their pets.

**Why it happens:**
Free text is the fastest thing to build (one `TextField`, one `text` column) and matches how the current mock's `HistoryScreen`/`_TimelineItem` widgets likely just render static strings. Structuring anamnesis/exam/diagnosis/treatment/evolution into distinct fields is more schema work up front.

**How to avoid:**
- Give `consulta`/clinical-history records distinct structured fields for at least: anamnesis, physical exam findings, diagnosis, treatment plan, evolution/follow-up notes, plus vitals (weight, temperature) — matching what the PROJECT.md requirement already names explicitly ("anamnesis, examen físico, diagnóstico, tratamiento, evolución").
- Treat clinical history rows as append-only/immutable once saved (allow a superseding correction record, not in-place mutation) — this matters both for timeline correctness and for defensibility if a treatment is ever disputed.
- Store weight at each visit as its own timestamped datapoint (not just "current weight" on the pet) — it's needed both for the timeline/growth tracking and for weight-based dosing.

**Warning signs:**
- A `consulta` table/entity with a single `notas` or `descripcion` free-text column and no structured fields.
- Clinical history records with `updated_at`/edit capability but no versioning/audit trail.

**Phase to address:**
Clinical history feature phase — schema design should be reviewed before implementation since PROJECT.md explicitly requires both a structured multi-field record and a PDF-exportable timeline.

---

### Pitfall 9: Multi-pet-per-owner and solo-vet-vs-clinic tenancy assumptions baked in wrong at the schema level

**What goes wrong:**
Two related domain-modeling traps specific to this market: (1) treating "owner" and "pet" as effectively 1:1 in early screens (e.g., an appointment or invoice model that only references one pet, with no clean way to book/bill multiple pets from the same family visit) causes rework once real users — who very commonly bring 2+ pets in one visit — hit the limitation; (2) the schema's `clinica_id`-per-vet tenancy model (one clinic per signup) doesn't cleanly express the stated target user of "veterinario independiente" who may not have a fixed "clinic" at all, or who is the sole professional but the product still forces a `clinicas` row to exist per PROJECT.md's own market framing (mobile-first for the vet who has no receptionist/desktop, possibly no fixed premises for home visits). If `clinica_id` isn't clearly documented as "the vet's own tenant boundary, not necessarily a physical clinic," future features (e.g., inventory, billing) may wrongly assume a physical-location concept that doesn't fit the "atiende a domicilio" (house-call) use case explicitly named in PROJECT.md.

**Why it happens:**
Schemas are usually first designed around the simplest case (one pet, one owner, one clinic) and multi-pet/no-fixed-location realities surface later as "edge cases" that are actually the common case for this specific market (independent vets, house calls).

**How to avoid:**
- Model appointments and invoices as capable of referencing multiple pets belonging to the same owner in one visit/transaction from the start (even if the UI only supports one at MVP) — retrofitting a many-to-many after billing/agenda ship is expensive.
- Explicitly document (in schema comments or ARCHITECTURE.md) that `clinica_id` represents "professional tenant," not "physical location," so `direccion`/location fields on `clinicas` are understood as optional/nullable metadata, not a hard requirement — this avoids someone later adding a `NOT NULL` address constraint that breaks the house-call use case.
- Keep the `perfiles`-as-unified-table design (already in place) for CLIENTE/VETERINARIO, but make sure client-side "mis mascotas" queries are written as `WHERE dueno_id = mi_perfil()` returning *all* pets, not implicitly assuming exactly one.

**Warning signs:**
- Any UI flow (appointment booking, invoice creation) hardcoded to a single `mascota_id` field with no path to add a second pet to the same visit.
- A `clinicas` table column that's `NOT NULL` but conceptually inapplicable to a home-visit-only vet (e.g., a required physical address).

**Phase to address:**
Clients/Patients phase (data model review) and Agenda/Billing phases (verify multi-pet flows before locking UI).

---

### Pitfall 10: Mocked screens are replaced with "loading spinner forever" or "false success" instead of proper async state handling

**What goes wrong:**
The current mock screens (`DashboardScreen`, `PatientsScreen`, etc.) show hardcoded literals and no-op `onPressed: () {}` handlers with no concept of loading/error/empty state, because there's no real async call to represent. When these are replaced with real Supabase-backed screens, a common mistake is wiring the happy path only: the UI renders correctly when data loads fast and successfully, but silently breaks when the query is slow (infinite spinner, no timeout/retry), fails (RLS denial, network error — swallowed or shown as a raw exception string), or returns zero rows (looks identical to "still loading" if empty state isn't handled distinctly). A second, closely related trap already seen in this exact codebase's auth layer: catching an error and showing a generic success-adjacent or vague message that hides real failures (`_profileFor`'s bare `catch (_)`, per CONCERNS.md) — the same pattern is easy to repeat in every new CRUD screen's save/submit handlers.

**Why it happens:**
Converting a static mock into a real screen is naturally done by "swap the hardcoded value for a `FutureBuilder`/provider call" without also explicitly designing the loading/error/empty/success state machine, because the mock never had a reason to think about those states.

**How to avoid:**
- For every screen migrated off the mock, explicitly enumerate and design for: loading, error (with the *real* underlying message surfaced at least in logs, ideally to the user in dev builds), empty (zero results, distinct from loading), and success — in that render-priority order.
- Never let a `catch` block produce a generic "algo salió mal" without logging/surfacing the real exception somewhere reachable during development (fix this in the existing `_profileFor` pattern before propagating it to new features).
- Add a lightweight logging package (even just `debugPrint` wrapped consistently, or `logger`) now, before a dozen more screens each invent their own ad hoc error handling — there is currently zero logging infrastructure in the app (per INTEGRATIONS.md).

**Warning signs:**
- A widget that only has a `success` branch and assumes the Supabase call always returns data.
- A `catch (_)` or `catch (e)` block that doesn't log/print `e` before showing a user-facing message.
- No visual distinction in a list screen between "still loading" and "zero results, none exist yet."

**Phase to address:**
Every feature phase that replaces a mock screen (patients, clients, agenda, clinical history, vaccination, inventory, billing, dashboard) — establish the loading/error/empty/success pattern once in the first real CRUD screen (patients) as the template for the rest.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Single mutable `schema.sql` instead of versioned Supabase migrations | Faster to edit, no CLI ceremony | No diff review of schema changes, no rollback path, silent trigger breakage (Pitfall 3) | Never past the foundation phase — switch to `supabase/migrations/` before the second feature's schema lands |
| Testing RLS only via service-role/dashboard queries | Fast iteration while designing policies | False confidence; real anon-key bugs surface only in production (Pitfall 1) | Only during initial policy drafting, never as the final verification step |
| Leaving `home_screen.dart` mock screens in place "for reference" while building real screens elsewhere | Visual reference for the approved design without redoing layout work | Risk of accidentally wiring a real navigation path back into a mock screen; dead code confuses future contributors (already flagged in CONCERNS.md) | Acceptable only if explicitly renamed/quarantined (e.g., moved to a `_design_reference/` folder, classes prefixed `_Mock`) with no imports from real code |
| Storing "next vaccine due" as a single mutable date field instead of derived from dose history | Simple to build, fast to query | Cannot correctly express multi-dose puppy/kitten series or handle missed-dose recalculation (Pitfall 7) | Never for a product whose stated differentiator is automatic vaccination alerts |
| Free-text-only clinical history field | Fastest UI to ship (one text box) | Timeline/PDF export features become unbuildable or low-quality later (Pitfall 8) | Only as a temporary placeholder before the clinical-history phase begins — not once that phase starts |
| Deferring Riverpod/go_router adoption while building new CRUD screens with `Navigator`/`StatefulWidget` | Ships a screen faster using familiar patterns | Every screen built this way must be migrated later; cost compounds per screen (Pitfall 4) | Never — the roadmap already names this as Phase 1 foundation work |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Supabase RLS | Testing policies with service-role/postgres connection, assuming anon-key behavior matches | Explicitly test as `authenticated` role with a real JWT/claims set (pgTAP or manual `SET ROLE`), for both allow and deny cases |
| Supabase Auth trigger (`on_auth_user_created`) | Editing `perfiles`/`clinicas` schema without re-testing the trigger; letting trigger exceptions surface as opaque 500s | Move to versioned migrations; add a signup smoke test after every schema change touching tables the trigger writes to |
| Supabase deep links (password reset / email confirmation) + `go_router` | Supabase's redirect URL scheme (`#/path?...` hash fragments, `code=` query param injection) conflicts with `go_router`'s own path/hash handling, and underscores in redirect URLs can silently fall back to the Site URL | Test the full email-confirmation and password-reset flow on real devices (not just simulator) after introducing `go_router`; keep redirect URLs simple (no underscores) and verify the allow-listed URL in the Supabase dashboard matches exactly |
| `supabase_flutter` session client | Constructing a new repository instance per call (`SupabaseAuthRepository(Supabase.instance.client)` inline, already happening in 3 places per CONCERNS.md) instead of a shared/injected instance | Provide repositories via Riverpod providers once adopted, so there's one shared instance and tests can override it |
| Supabase Storage (for pet photos, per PROJECT.md's "foto" field) | Enabling Storage in `config.toml` but forgetting bucket-level RLS policies (`storage.objects`), leaving uploaded files either fully public or fully inaccessible | Define explicit bucket policies scoped by `clinica_id`/`dueno_id` the same way table RLS is scoped, before the first photo-upload feature ships |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Embedded join on every profile read (`perfiles` joined to `clinicas` on every login, already the one live query per INTEGRATIONS.md) | Slightly slower login/session-restore as clinic data grows | Fine at current scale; revisit only if `clinicas` gains heavy columns or the join is called on every screen instead of once per session | Not a near-term concern for a single-vet/small-clinic app; would matter only if this join gets called per-list-item somewhere |
| Missing indexes on RLS-filtered columns (`clinica_id`, `dueno_id`) as `mascotas`/`consultas`/`citas` tables grow | Query latency increases noticeably as row counts grow past a few thousand, because Postgres evaluates the policy predicate per candidate row | Add indexes on every column referenced in a `USING`/`WITH CHECK` clause as each new table is created, not retroactively | Becomes noticeable once any single clinic accumulates thousands of pet/visit records — plausible within 1-2 years of real usage for an active practice |
| RLS policies that call a function per-row instead of once per statement (e.g., unwrapped `auth.uid()` in a policy) | Query plans show the policy function evaluated once per row rather than cached | Wrap volatile function calls as `(select auth.uid())` in policy definitions so Postgres evaluates once per statement | Compounds with row count; worth fixing at write-time for every new policy rather than as a later optimization pass |
| Fetching entire patient/clinical-history lists without pagination once real data accumulates | Dashboard/patient-list screens slow down or jank as a clinic's pet/visit count grows over months of real use | Design list queries with `.range()`/pagination and reasonable page sizes from the first real CRUD screen, not as a later retrofit | Becomes visible once a single vet accumulates a few hundred patients/consultations — realistic within the product's first year |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Self-service `VETERINARIO` signup with no verification, granting an isolated tenant (`clinica_id`) purely from client-supplied metadata (already flagged in CONCERNS.md) | Anyone can claim to run a clinic and start creating patient/client/billing records under a fake tenant; damages trust if discovered post-launch | Add an invite-code, manual approval, or domain/phone-verification step for `VETERINARIO` signups before general launch — track as a pre-launch blocker, not a "someday" item |
| `perfiles` self-update policy allowing `rol`/`clinica_id` mutation (Pitfall 2) | Privilege escalation across the entire multi-tenant boundary | Restrict updatable columns via `WITH CHECK` comparing old/new privileged fields, or move them to an admin-only-writable path |
| No password confirmation field on signup, relying only on an 8-character client-side length check plus Supabase server defaults (flagged in CONCERNS.md) | Typo'd passwords lock users out immediately after signup, generating support burden and possibly abandoned accounts | Add a repeat-password field; document the actual Supabase Auth password policy in README/config so client and server checks stay in sync |
| Storing clinical/medical data (a sensitive category even for pets — arguably less regulated than human health data, but still contains client PII: address, phone, payment info) with no encryption-at-rest consideration beyond Supabase's defaults, and no data-retention/export policy | Not an immediate blocker (Supabase encrypts at rest by default), but no documented policy means it's easy to later violate an implicit promise to users about data handling once billing/PDF export ship | Document what happens to clinical/billing PDFs on export (where they're generated, whether cached, whether the device stores them locally) as part of the billing/clinical-history phases |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Vaccination alerts that fire generically ("próxima dosis" with no context on whether it's a primary-series dose or annual booster) | Vet can't tell at a glance whether a reminder is urgent (overdue puppy series) vs. routine (annual booster in 2 months), reducing trust in the "automatic alerts" differentiator | Surface dose-series context in the alert itself (e.g., "Dosis 2/3 de óctuple — vencida hace 5 días" vs. "Refuerzo antirrábico — en 30 días") |
| Clinical history timeline that's just a reverse-chronological list of free-text blobs | Hard to scan a pet's history quickly during a live consultation (the exact moment the vet needs it most, per the domain literature on point-of-care documentation) | Structure the timeline entry preview around the fields PROJECT.md already names (diagnóstico, tratamiento) as scannable summary lines, with anamnesis/evolución as expandable detail |
| Appointment/invoice UI that assumes one pet per visit when a family brings multiple pets (common case, not edge case, per Pitfall 9) | Vet must create separate appointments/invoices per pet for what is one physical visit, adding friction exactly for the solo/no-receptionist use case this app targets | Support multi-pet selection within a single agenda slot/invoice from the data model up (Pitfall 9), even if MVP UI only exposes it minimally |
| Loading states copied from the mock's instant-render assumption (no skeleton/spinner because the mock never needed one) | Screens feel broken/frozen on slow rural connections (explicitly part of the target market — "atiende... a domicilio," often areas with weaker connectivity) while data loads | Design every real screen with an explicit loading skeleton and a distinct empty state from day one, informed by target-market connectivity realities |

## "Looks Done But Isn't" Checklist

- [ ] **RLS policies exist:** Often missing `WITH CHECK` on insert/update — verify by attempting a cross-tenant write as an `authenticated` test user, not just reading as postgres.
- [ ] **Signup flow works:** Often missing a test after any schema change to `perfiles`/`clinicas` — verify by running a real signup (both `VETERINARIO` and `CLIENTE` roles) after every migration.
- [ ] **Vaccination "next dose" alert:** Often missing correct behavior for multi-dose primary series and missed-dose recalculation — verify with a simulated puppy going through 3 doses with one deliberately-delayed dose.
- [ ] **Clinical history timeline:** Often missing structured fields (looks done as "a list of notes") — verify diagnosis/treatment/evolution are separately queryable, not concatenated into one text blob.
- [ ] **CRUD screen "done":** Often missing error/empty states (looks done because the happy path with seed data renders correctly) — verify by turning off WiFi mid-load, and by testing against a brand-new clinic with zero patients.
- [ ] **Multi-pet-per-owner support:** Often missing at the appointment/invoice level even when the pet/owner data model supports it — verify by creating an appointment/invoice for a client with 2+ pets in one visit.
- [ ] **Provider/notifier disposal:** Often missing `dispose()`/`ref.onDispose` for controllers and subscriptions created inside new screens (the existing auth screens already leak `TextEditingController`s per CONCERNS.md) — verify with Flutter's leak tracker or by navigating to/from a new screen 20+ times and watching memory.
- [ ] **Dead mock code removed:** Often "looks removed" because the real screen renders correctly, but the old mock class/file still exists and could be re-imported by accident — verify by deleting (not just unlinking) `home_screen.dart`'s mock screens once each real equivalent ships.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|-----------------|
| RLS privilege escalation via `perfiles` self-update (Pitfall 2) discovered post-launch | MEDIUM | Immediately tighten the `WITH CHECK` clause via a hotfix migration; audit `perfiles` rows for any `rol`/`clinica_id` values that don't match the original signup metadata (compare against `auth.users.raw_user_meta_data` history if retained, or against `clinicas.created_at`/ownership records) |
| Vaccination model needs restructuring from single-date to dose-series after real puppy/kitten data exists (Pitfall 7) | MEDIUM-HIGH | Write a backfill migration that infers dose number from existing administration-date history per pet/vaccine-type ordered chronologically; ship the new protocol-reference table alongside, don't block on perfect backfill for older records |
| Domain entities need reconciling with schema mid-feature (Pitfall 6) discovered during a feature phase already in progress | LOW-MEDIUM | Treat as expected, not a crisis — pause the repository/datasource layer, update the entity to match schema.sql (or add the missing migration if the schema was genuinely incomplete), resume; cheaper the earlier it's caught |
| Riverpod/go_router adoption deferred and several screens already built with raw Navigator (Pitfall 4) | HIGH | Migrate screen-by-screen starting with the most-navigated-to screen (likely patients list); budget one migration pass per screen rather than a big-bang rewrite, and freeze new Navigator-based screens immediately once decided |
| Free-text-only clinical history shipped, timeline/PDF export now needed (Pitfall 8) | MEDIUM-HIGH | Add structured columns going forward (don't force-migrate old free text); optionally run old free-text notes through a one-time manual/LLM-assisted split into anamnesis/diagnóstico/tratamiento for the most recent N records if genuinely needed, otherwise accept old records display as a single "legacy note" block in the timeline |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|---------------|
| RLS tested only via service-role, missing anon-key coverage (#1) | Foundation/Supabase-setup phase | Automated or manual test suite exercises every table's policies as `authenticated` role with both allow and deny assertions |
| `perfiles` privilege escalation via self-update (#2) | Foundation/Supabase-setup phase | Explicit test: authenticated CLIENTE cannot set own `rol`/`clinica_id` via update |
| Signup trigger fragility / opaque errors (#3) | Foundation/Supabase-setup phase | Migrations adopted; signup smoke test passes after each schema change touching `perfiles`/`clinicas` |
| Riverpod/go_router adoption deferred (#4) | Foundation phase (before first CRUD feature) | First real feature (patients) uses a `GoRoute` + Riverpod provider as the template; no new `Navigator.push`/raw `StatefulWidget` data-fetching in feature code after this phase |
| Provider sprawl / global-vs-local state confusion (#5) | Foundation phase, re-audited each feature phase | Code review checklist item: "is this provider global/shared state or should it be local widget state?" applied at each new feature |
| Entities designed before checking schema.sql (#6) | Every feature phase | Task list for each feature phase includes "reconcile entity with schema.sql" as an explicit, checked step before repository work begins |
| Vaccination modeled as single date, not dose series (#7) | Vaccination feature phase | Schema review confirms dose-history + protocol-reference tables exist before UI work starts; test with a simulated 3-dose puppy series including one delayed dose |
| Clinical history as free text, not structured (#8) | Clinical history feature phase | Schema review confirms distinct anamnesis/exam/diagnosis/treatment/evolution fields exist and are independently queryable before timeline/PDF export work starts |
| Multi-pet-per-owner and location-flexible tenancy not modeled (#9) | Clients/Patients phase (schema) + Agenda/Billing phases (UI) | Schema supports multiple pets per appointment/invoice; `clinicas` address-like fields are nullable; test with a client who has 2+ pets |
| Mock-to-real migration skips loading/error/empty states (#10) | Every feature phase replacing a mock screen | First real CRUD screen (patients) establishes the loading/error/empty/success pattern; subsequent screens reviewed against it |

## Sources

- [Supabase RLS Best Practices: Production Patterns for Secure Multi-Tenant Apps](https://makerkit.dev/blog/tutorials/supabase-rls-best-practices) — RLS policy structure, `WITH CHECK`, privilege escalation, indexing/performance guidance (MEDIUM confidence, cross-checked against official Supabase docs concepts)
- [Row Level Security | Supabase Docs](https://supabase.com/docs/guides/database/postgres/row-level-security) — official RLS behavior (HIGH confidence)
- [Fixing Row-Level Security (RLS) Misconfigurations in Supabase: Common Pitfalls](https://prosperasoft.com/blog/database/supabase/supabase-rls-issues/) — RLS misconfiguration patterns (MEDIUM confidence)
- [When adding trigger on_auth_user_created, can no longer signup user · supabase Discussion #6518](https://github.com/orgs/supabase/discussions/6518) — trigger-breaks-signup failure mode (HIGH confidence, official GitHub discussion)
- [Supabase Docs | Troubleshooting | Database error saving new user](https://supabase.com/docs/guides/troubleshooting/database-error-saving-new-user-RU_EwB) — official troubleshooting guide for trigger failures (HIGH confidence)
- [Supabase redirect links break Flutter apps using GoRouter · Issue #27554](https://github.com/supabase/supabase/issues/27554) — hash-fragment/redirect conflict between Supabase auth links and go_router (HIGH confidence, official GitHub issue)
- [How to make deep linking play nicely with go_router · supabase-flutter Issue #901](https://github.com/supabase/supabase-flutter/issues/901) — deep link + go_router integration issues (HIGH confidence)
- [Riverpod's Flaws: A Critical Perspective](https://lazebny.io/riverpod/) — provider sprawl, coupling, testability critique (MEDIUM confidence, single-author opinion piece but consistent with other sources)
- [Riverpod Best Practices You're Probably Missing — DCM](https://dcm.dev/blog/2026/03/25/inside-riverpod-source-code-guide-dcm-rules/) — stale notifier references, over-splitting providers, local-vs-global state (MEDIUM confidence)
- [Offline-First Mobile App Architecture: Syncing, Caching, and Conflict Resolution](https://dev.to/odunayo_dada/offline-first-mobile-app-architecture-syncing-caching-and-conflict-resolution-518n) — outbox-queue pattern, conflict resolution strategies, rural connectivity failure modes (MEDIUM confidence; relevant for the deferred offline-mode milestone, not v1 scope)
- General veterinary EMR/PIMS literature (co.vet buyer guides, VetPartners utilization guide) — clinical-record-as-free-text anti-pattern, point-of-care documentation gap (MEDIUM confidence — vendor/industry content, not peer-reviewed, but consistent across sources)
- Direct analysis of `.planning/codebase/CONCERNS.md` and `.planning/codebase/INTEGRATIONS.md` — grounding for entity/schema mismatch, trigger fragility, controller leaks, self-service signup risk, and current zero-test/zero-CI state (HIGH confidence — first-party codebase audit, not external research)

---
*Pitfalls research for: Veterinary practice management (Colombia) + Flutter/Supabase brownfield rebuild*
*Researched: 2026-09-23*
