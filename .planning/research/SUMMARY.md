# Project Research Summary

**Project:** VetApp
**Domain:** Flutter + Supabase mobile practice-management app for independent/solo veterinarians and small clinics in Colombia (brownfield rebuild: mocked UI → real, RLS-secured backend)
**Researched:** 2026-09-23
**Confidence:** HIGH

## Executive Summary

VetApp is a mobile-first veterinary practice-management system (a "PIMS") for solo vets and small clinics in Colombia who work without a receptionist or fixed desktop — including house calls. Every competitor analyzed (Vetlogy, GVET, Panacea, Digitail, IDEXX Neo, Provet Cloud) is a web/cloud platform designed for a receptionist at a desk; none is a true native mobile app. That gap is VetApp's core structural advantage, and the research confirms the already-planned feature set (patients, clients, clinical history, agenda, vaccination, inventory, billing, dashboard) matches table stakes across the category — nothing essential is missing and nothing planned is over-scoped, apart from a few sequencing and data-modeling decisions that must be made correctly the first time.

The recommended approach is a straightforward clean-architecture wiring of dependencies already declared but unused: `flutter_riverpod` (hand-written `Notifier`/`AsyncNotifier`, no codegen for now) for state, `go_router` (stay on `^17.3.0`, do not bump to 18.x) with a `StatefulShellRoute` + `redirect:`-based auth gate for navigation, and a strict repository-behind-interface pattern so every feature's Supabase access goes through one seam. New libraries are only needed for PDF export (`pdf`+`printing`), photo capture/compression (`image_picker`+`flutter_image_compress`+`cached_network_image`), and local reminders (`flutter_local_notifications`+`timezone`+`flutter_timezone`) — no exotic stack additions. Colombia-specific differentiators (WhatsApp deep-link reminders, a shareable read-only vaccination-card link) are cheap to add once core CRUD is real and should follow immediately after, ahead of harder items like DIAN e-invoicing and AI features, which are correctly deferred.

The main risks are not technological, they are sequencing and data-modeling risks compounded by the fact that the codebase already has zero RLS tests, an unresolved clients-vs-authenticated-users schema conflict, and a documented history of building UI before the backing repository exists (the single biggest failure mode already present in the codebase). The four research files agree on the same root cause and the same fix: settle schema/RLS/tenancy decisions (clients-as-vet-managed-contacts, vaccination as dose-series not a single date, clinical history as structured/append-only records) *before* writing feature UI, verify every RLS policy against the `authenticated` role (not just service-role/postgres), and commit to Riverpod+go_router in one reference vertical slice before parallelizing across the remaining seven features.

## Key Findings

### Recommended Stack

Flutter and Supabase are already fixed decisions; this research covers only how to wire the two already-declared-but-unused dependencies (`flutter_riverpod`, `go_router`) and which new libraries the mocked features will need once real. All version numbers were verified live against pub.dev on 2026-09-23.

**Core technologies:**
- `flutter_riverpod ^3.3.2` (already pinned, unused) — app-wide state/DI via hand-written `Notifier`/`AsyncNotifier` classes; replaces every screen's `StatefulWidget`+`setState`. No codegen (`riverpod_generator`/`build_runner`) for v1 — revisit once provider count makes boilerplate genuinely painful.
- `go_router ^17.3.0` (already pinned, unused — **do not bump to 18.x**, which requires Flutter 3.44/Dart 3.12, incompatible with the project's `sdk: ^3.11.1`) — declarative navigation; build the `GoRouter` inside a Riverpod `Provider`, gate auth via `redirect:` + `GoRouterRefreshStream` bound to `supabase.auth.onAuthStateChange`, replacing the `AuthGate` widget and all `Navigator.push(MaterialPageRoute(...))` calls.
- `pdf ^3.13.1` + `printing ^5.15.1` — clinical history / vaccination card / invoice PDF export and preview/share/print; `printing` ships `PdfGoogleFonts` so exported PDFs can match the app's Figtree/Caprasimo theme without bundling fonts.
- `image_picker` + `flutter_image_compress` + `cached_network_image` + `permission_handler` — pet photo capture, client-side compression before upload (important on mobile data), and disk/memory caching for list/ficha screens.
- `flutter_local_notifications` + `timezone` + `flutter_timezone` — local (on-device) scheduled reminders for appointments and vaccination due-dates; no server-triggered push needed for v1 since WhatsApp/remote reminders are explicitly out of scope.
- `table_calendar`, `url_launcher`, `share_plus` — agenda calendar UI and contact/share actions (call, WhatsApp deep link, PDF sharing).

Private Supabase Storage buckets with signed URLs (not public buckets) for pet photos, mirroring the existing multi-tenant RLS pattern. See `.planning/research/STACK.md` for full installation commands, alternatives considered, and version-compatibility notes.

### Expected Features

Verified across Vetlogy, GVET, Panacea, Digitail, IDEXX Neo, Provet Cloud, and mobile-vet-specific competitors (AcuroVet). The already-scoped Active requirements in PROJECT.md match table stakes almost exactly — this is a strong validation signal, not a reason to expand scope.

**Must have (table stakes) — matches current PROJECT.md Active scope:**
- Patient (pet) records with photo, weight history, owner link
- Client (owner) records with contact info and visit history
- Structured digital clinical history (anamnesis/exam/diagnóstico/tratamiento/evolución) with per-patient timeline, PDF export
- Appointment scheduling with reminders
- Vaccination/deworming digital card with next-dose alerts
- Basic inventory with low-stock alerts
- Simple invoicing/quotes as PDF (no DIAN yet)
- Basic dashboard (consultations, revenue, new patients)
- Search/filter across patients/clients (easy to miss, painful once patient count grows)

**Should have (competitive differentiators, add right after core CRUD is stable):**
- WhatsApp deep-link reminders (`wa.me` prefilled text, tap-to-send) — nearly free once reminder data exists, beats push/email-only incumbents (Vetlogy already has WhatsApp automation, so this is now catch-up-plus, not a novel idea)
- Shareable read-only vaccination-card link/PDF — genuine gap even vs. Vetlogy; must be scoped strictly to vaccination data, never full clinical history

**Defer (v2+) — correctly out of scope already:**
- Full WhatsApp Business API automation, DIAN e-invoicing (via Siigo/Alegra/Factus — never build in-house), AI voice-to-note and AI dosage suggestions (never free-form LLM dosage math — deterministic tables only), offline-first sync, pet-owner companion app, multi-vet/multi-clinic accounts, telemedicine, full multi-provider scheduling, multi-warehouse/lot inventory tracking

### Architecture Approach

Standard clean-architecture layering (presentation → thin domain → data) wired around Riverpod and a single injected `SupabaseClient`. The recommended structure keeps `domain/usecases/` mostly empty per-feature (CRUD goes straight from Notifier to repository) and reserves usecases for the ~4 real cross-feature workflows: vaccination→next-dose reminder, billing→inventory decrement, appointment-completion→clinical-history entry, and signup→profile/clinic creation (already handled by a Postgres trigger).

**Major components:**
1. `core/data/supabase_client_provider.dart` — the single `Provider<SupabaseClient>` injection point; every repository derives from it (replaces today's pattern of constructing repositories inline inside widgets)
2. `core/router/app_router.dart` — one `GoRouter` built inside a `Provider`, `StatefulShellRoute.indexedStack` for the 5-tab bottom nav, `redirect:` driven by `authProfileProvider`
3. Per-feature `data/repositories/Supabase<Feature>Repository implements <Feature>Repository` — abstracts persistence, maps Supabase rows to domain entities, translates `PostgrestException` into typed `Failure`
4. Per-feature `presentation/providers/<Feature>Notifier extends AsyncNotifier<T>` — owns feature state, calls repository, exposes `AsyncValue`
5. `authProfileProvider` — single source of truth for logged-in user/role/clinic, watched by both router redirect and every feature's RLS-scoped queries

**Open architectural gap requiring a decision before the clients/patients phase starts:** the current schema (`perfiles`) requires every client to be an authenticated `auth.users` row, but the product's core value (vet creates a client+pet on the spot, no receptionist, client may never sign up) conflicts with that. Recommendation: add a `clientes` table owned by `clinica_id`, decoupled from `perfiles`, with `mascotas.dueno_id` pointing there — decide and patch the schema before building the clients/patients feature, not after.

### Critical Pitfalls

1. **RLS tested only via service-role/dashboard, never as the real `authenticated` role** — the app currently has zero RLS tests. Every policy needs both a positive ("clinic A can read clinic A data") and negative ("clinic B cannot read clinic A data") test using `SET ROLE authenticated`, and every insert/update policy needs `WITH CHECK`, not just `USING`.
2. **`perfiles` self-update allows privilege escalation** — if a client can update their own `rol`/`clinica_id`, they can promote themselves to `VETERINARIO` or jump tenants, defeating the entire RLS boundary that every other table's policies depend on. Must restrict updatable columns via `WITH CHECK` comparing old vs. new privileged fields before any other feature relies on `es_veterinario()`/`mi_clinica_id()`.
3. **Riverpod/go_router adoption deferred "for later," entrenching raw `Navigator`/`StatefulWidget`** — both are already declared dependencies with zero real usage. Build one real vertical slice (one provider + one route) as the reference pattern before parallelizing feature work, or migration cost compounds per screen added in the interim.
4. **Domain entities designed against an imagined schema instead of the real `schema.sql`** — already documented mismatch for `Cliente`/`Cita`/`Mascota`. Every remaining feature must read the actual current schema first and treat it as source of truth, generating migrations for genuinely missing fields rather than guessing shapes in Dart.
5. **Vaccination modeled as a single "next dose" date instead of a dose/series state machine** — breaks immediately for real puppy/kitten multi-dose primary series and missed-dose recalculation, which is the exact "alertas automáticas" differentiator named in PROJECT.md. Model administered-dose history + a vaccine-protocol reference table; compute next-due from that, never store it as a bare mutable field.
6. **Clinical history as free-text blobs instead of structured, append-only fields** — makes the required PDF-exportable timeline nearly unbuildable as anything more than a text dump. Needs distinct anamnesis/exam/diagnóstico/tratamiento/evolución fields plus timestamped weight, and records should be immutable/append-only once saved.

## Implications for Roadmap

Based on combined research, suggested phase structure:

### Phase 1: Foundation — Supabase project + Riverpod/go_router wiring + RLS hardening
**Rationale:** Every other feature depends on (a) a real cloud Supabase project existing, (b) the state/navigation wiring being decided and demonstrated once, and (c) the multi-tenant RLS boundary being trustworthy — building any feature on top of an untested RLS model or on continued `Navigator`/`setState` patterns multiplies rework later (Pitfalls #1, #2, #3, #4).
**Delivers:** Cloud Supabase project linked; `supabase/schema.sql` applied; `core/data/supabase_client_provider.dart`; one reference vertical slice (e.g., patients list) using a real `AsyncNotifier` + `GoRoute` + `redirect:`-based auth gate replacing `AuthGate`; RLS policies for existing tables (`clinicas`, `perfiles`, `mascotas`) verified with `authenticated`-role positive/negative tests, including the `perfiles` self-update privilege-escalation fix; signup trigger covered by at least a manual smoke test; decision made and schema-patched for clients-as-vet-managed-contacts (new `clientes` table, not `perfiles`-only).
**Addresses:** "Wiring real de gestión de estado (Riverpod) y navegación (go_router)" (Active scope); "Crear y enlazar un proyecto Supabase real" (Active scope)
**Avoids:** Pitfalls #1 (RLS false confidence), #2 (privilege escalation), #3 (signup trigger fragility), #4 (Riverpod/go_router deferred), #6 (entities before schema)

### Phase 2: Clients & Patients (core records)
**Rationale:** FEATURES.md confirms client+patient records are the foundation every other module depends on (clinical history, agenda, vaccination, invoicing all FK to a patient and/or client) — must be built and stable before anything else.
**Delivers:** Real CRUD for clients (using the new `clientes` table decided in Phase 1) and patients (mascotas — species, breed, age, weight, photo, owner link), with photo upload via private Storage bucket + signed URLs, search/filter, and the loading/error/empty/success state pattern established once here as the template for every later feature.
**Addresses:** "Gestión de pacientes," "Gestión de clientes" (Active scope)
**Avoids:** Pitfall #9 (model multi-pet-per-owner from the start, even if UI only exposes one at MVP); Pitfall #10 (loading/error/empty states, not just happy path)

### Phase 3: Clinical History
**Rationale:** The most domain-logic-heavy and legally consequential module (structured anamnesis/exam/diagnóstico/tratamiento/evolución, append-only, PDF-exportable timeline) — needs its own schema design pass before implementation, per PITFALLS.md and ARCHITECTURE.md agreement that structure must exist before UI.
**Delivers:** `consulta` table with distinct structured fields, timestamped weight-history datapoints, immutable/append-only records with superseding-correction support, per-patient timeline UI, PDF export via `pdf`+`printing`.
**Uses:** `pdf`, `printing` (STACK.md); PDF as a `presentation`-adjacent concern, not a repository method (ARCHITECTURE.md)
**Avoids:** Pitfall #8 (free-text-only clinical history)

### Phase 4: Agenda / Appointments
**Rationale:** Depends on client+patient records; enhances (and is enhanced by) the reminder mechanism that vaccination alerts will also use — build the generic "send a reminder" capability once here.
**Delivers:** Day/week calendar (`table_calendar`), appointment CRUD, local push reminders (`flutter_local_notifications`+`timezone`+`flutter_timezone`), multi-pet-per-visit support in the data model.
**Uses:** `table_calendar`, `flutter_local_notifications`, `timezone`, `flutter_timezone` (STACK.md)
**Implements:** appointment-completion → clinical-history-entry usecase (ARCHITECTURE.md cross-feature workflow #3)

### Phase 5: Vaccination / Deworming Card
**Rationale:** Explicitly the most domain-logic-heavy remaining feature (dose-series state machine, not a single date) and a named product differentiator — needs a dedicated schema-design review before UI, per PITFALLS.md #7.
**Delivers:** Dose-history table + vaccine-protocol reference table (antirrábica, óctuple/polivalente with species/age-specific intervals), correct next-due computation, dose-series-aware alert UI, and (per FEATURES.md v1.x add-on) the shareable read-only vaccination-card public link.
**Addresses:** "Carné de vacunación... con alertas automáticas de próxima dosis" (Active scope); shareable vaccination card (FEATURES.md differentiator, cheap add-on once this module is stable)
**Avoids:** Pitfall #7 (single-date vaccination model)

### Phase 6: Inventory
**Rationale:** Simple relative to the above; mainly needed as a prerequisite for billing's stock-decrement usecase.
**Delivers:** SKU + quantity + reorder-threshold + optional single expiry date; low-stock alerts (reusing the Phase 4 reminder mechanism).
**Addresses:** "Inventario básico... con alertas de stock mínimo" (Active scope)

### Phase 7: Billing (Facturación simple)
**Rationale:** Requires patient+client records and, if line items pull priced products, inventory — must come after both; DIAN e-invoicing (deferred) requires this phase's data model to exist first and be stable.
**Delivers:** Quote/receipt PDF generation, invoice→inventory-decrement usecase, and (per FEATURES.md) IVA charged by default on companion-animal services (verify with an accountant — do not assume tax-exempt).
**Uses:** `pdf`, `printing` (STACK.md)
**Implements:** billing↔inventory cross-feature usecase (ARCHITECTURE.md #2)

### Phase 8: Dashboard + Design polish + WhatsApp deep-link reminders
**Rationale:** Dashboard aggregates data from every prior module, so it must come last; WhatsApp deep-link reminders are cheap once appointment/vaccination reminder payloads already exist (FEATURES.md: "build the reminder-sending capability once, generically, then wire trigger sources into it").
**Delivers:** Real dashboard replacing the 1400-line mock, final terracota/crema + Caprasimo/Figtree visual design applied across all screens, `wa.me` deep-link reminders wired to appointment and vaccination triggers, removal of dead Firebase-migration code.
**Addresses:** Remaining Active-scope items (dashboard, design application, dead-code removal)

### Phase Ordering Rationale

- Dependency order matches FEATURES.md's explicit dependency graph: everything requires client+patient records; clinical history and agenda both require those; vaccination and billing both build on top; dashboard aggregates everything, so it comes last.
- RLS/schema/state-management decisions front-loaded into Phase 1 because PITFALLS.md identifies these as the highest-cost-to-fix-late category (privilege escalation, entity/schema mismatch, Navigator-vs-router migration cost) — every research file independently converges on "decide once, early" for these.
- Clinical history and vaccination are each given their own dedicated phase (not folded into patients/agenda) because both need schema design reviewed *before* implementation per PITFALLS.md #7/#8 — these are the two most domain-logic-heavy, hardest-to-retrofit modules.
- WhatsApp reminders and shareable vaccination card are placed as add-ons to their prerequisite phases (agenda/vaccination) rather than standalone phases, matching FEATURES.md's "add after validation, cheap once core CRUD is real" categorization.
- DIAN e-invoicing, AI features, offline-first, and multi-vet/telemedicine are excluded from this roadmap entirely (Out of Scope in PROJECT.md, confirmed as correctly deferred by FEATURES.md's competitor/complexity analysis).

### Research Flags

Needs deeper research during planning (`--research-phase`):
- **Phase 1 (Foundation/RLS):** RLS testing methodology (pgTAP vs. manual `SET ROLE`) and the `clientes`-vs-`perfiles` schema redesign are both non-trivial, first-of-their-kind decisions for this codebase with no existing precedent to copy.
- **Phase 5 (Vaccination):** Dose-series/protocol data model (species/age-specific intervals for antirrábica and óctuple) needs a veterinary-domain-accurate reference table — worth a focused pass to get the protocol data right, not just the schema shape.
- **Phase 7 (Billing):** IVA/tax treatment of companion-animal veterinary services in Colombia is MEDIUM confidence in FEATURES.md and explicitly flagged as needing accountant verification — do not build tax logic on the current secondary-source understanding alone.

Phases with standard, well-documented patterns (research-phase likely unnecessary):
- **Phase 2 (Clients & Patients):** Standard CRUD; the repository/Notifier/screen pattern is fully specified in ARCHITECTURE.md with working code examples.
- **Phase 3 (Clinical History):** Structure is explicit in PITFALLS.md/FEATURES.md (SOAP-like fields already named in PROJECT.md); PDF export pattern is standard `pdf`+`printing` usage.
- **Phase 4 (Agenda):** `table_calendar` + `flutter_local_notifications` are both well-documented, single-purpose libraries with standard wiring.
- **Phase 6 (Inventory):** Deliberately kept simple (SKU+qty+threshold) per FEATURES.md anti-feature guidance against over-engineering.
- **Phase 8 (Dashboard/design):** Aggregation queries over already-real data; visual design is already fully specified in `.planning/design/DESIGN-REFERENCE.md`.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Every version verified live against pub.dev API and changelogs on 2026-09-23; wiring patterns cross-checked against official Riverpod docs and multiple independent community sources |
| Features | MEDIUM-HIGH | Feature landscape verified across many competitor sources (Vetlogy, GVET, Panacea, Digitail, IDEXX Neo, Provet Cloud); Colombia-specific regulatory details (DIAN, IVA exemption scope) are MEDIUM confidence — secondary sources summarizing a DIAN concept, not verified with an accountant |
| Architecture | HIGH | Riverpod 3/go_router patterns verified against official docs via Context7; Supabase-specific layering corroborated by multiple community sources; VetApp-specific findings verified by direct codebase reading (`.planning/codebase/*`, `supabase/schema.sql`) |
| Pitfalls | MEDIUM-HIGH | Supabase RLS, Riverpod, and go_router pitfalls verified against official docs/GitHub issues; veterinary-domain-specific pitfalls (dose-series modeling, clinical-history structuring) are MEDIUM confidence — synthesized from practice-management vendor content and adjacent-domain EMR literature, no vet-specific post-mortem literature exists publicly, but corroborated by concrete mismatches already found in this codebase |

**Overall confidence:** HIGH

### Gaps to Address

- **Clients-as-authenticated-users vs. clients-as-vet-managed-contacts:** genuinely unresolved architectural decision (ARCHITECTURE.md's "Open Architectural Gap") — must be decided explicitly at the start of Phase 1/2, not discovered mid-build. Recommendation already given (new `clientes` table decoupled from `perfiles`) but requires user/stakeholder sign-off since it's a schema change, not just an implementation detail.
- **DIAN/IVA tax treatment for companion-animal veterinary services:** MEDIUM confidence, single secondary source (Cr Consultores summarizing DIAN Concepto 1431). Flag for accountant verification before any billing/tax logic is built, even though DIAN e-invoicing itself is deferred to v2 — the underlying "is this taxable" question still affects the v1 quote/receipt PDF's line-item math.
- **Spanish-language veterinary STT/scribe accuracy:** relevant only for the deferred AI voice-to-note feature; no current action needed, but flag for re-research if/when that feature is pulled forward.
- **Vaccination protocol specifics (dose intervals per biologic, by species/age):** PITFALLS.md correctly identifies the *shape* of the data model needed (dose history + protocol reference table) but the actual interval values for Colombian-market biologics should be sourced from a veterinary reference (or ICA guidance) during Phase 5 planning, not assumed.

## Sources

### Primary (HIGH confidence)
- pub.dev API and changelogs (`https://pub.dev/api/packages/<name>`, package changelogs) — live version verification, 2026-09-23
- Riverpod 3 official docs via Context7 (`/rrousselgit/riverpod`, `/websites/pub_dev_flutter_riverpod_3_4_1`) — AsyncNotifier/Notifier API, codegen vs. manual parity
- [Row Level Security | Supabase Docs](https://supabase.com/docs/guides/database/postgres/row-level-security) — official RLS behavior
- [Supabase Flutter — onAuthStateChange reference](https://supabase.com/docs/reference/dart/auth-onauthstatechange) — official docs
- [Supabase Docs | Troubleshooting | Database error saving new user](https://supabase.com/docs/guides/troubleshooting/database-error-saving-new-user-RU_EwB) — official trigger-failure guide
- [supabase/discussions#6518](https://github.com/orgs/supabase/discussions/6518), [supabase/supabase#27554](https://github.com/supabase/supabase/issues/27554), [supabase-flutter#901](https://github.com/supabase/supabase-flutter/issues/901) — official GitHub issues on trigger fragility and go_router deep-link conflicts
- [pdf](https://pub.dev/packages/pdf) / [printing](https://pub.dev/packages/printing) package pages — official, confirm dependency bounds and `PdfGoogleFonts`
- Direct codebase reads: `.planning/codebase/ARCHITECTURE.md`, `STRUCTURE.md`, `CONCERNS.md`, `INTEGRATIONS.md`, `supabase/schema.sql`, `pubspec.yaml`, `PROJECT.md` — first-party audit

### Secondary (MEDIUM confidence)
- [Flutter: A Design Guide for Properly Handling redirect with go_router and Riverpod](https://zenn.dev/harx/articles/95c3bb3a991f59?locale=en); [Q Agency](https://q.agency/blog/handling-authentication-state-with-go_router-and-riverpod/); [ApparenceKit](https://apparencekit.dev/blog/flutter-riverpod-gorouter-redirect/); [Dinko Marinac](https://dinkomarinac.dev/blog/guarding-routes-in-flutter-with-gorouter-and-riverpod/) — cross-corroborated `Provider<GoRouter>` + `refreshListenable` pattern
- [Supabase Storage Deep Dive](https://dev.to/kanta13jp1/supabase-storage-deep-dive-bucket-design-signed-urls-image-transforms-and-rls-3b9k); [Supabase RLS Best Practices — Makerkit](https://makerkit.dev/blog/tutorials/supabase-rls-best-practices); [Fixing RLS Misconfigurations — Prosperasoft](https://prosperasoft.com/blog/database/supabase/supabase-rls-issues/) — private bucket + RLS patterns, policy misconfiguration patterns
- [Flutter Clean Architecture with Riverpod and Supabase — Otakoyi](https://otakoyi.software/blog/flutter-clean-architecture-with-riverpod-and-supabase) — data/domain/presentation layering corroboration
- Vendor/competitor sources: Vetlogy, softwareveterinario.com, Digitail, GVET, IDEXX Neo, AcuroVet, AI scribe products (ScribbleVet, Scribenote, VetRec, VetGeni, VetDoze, PawfectNotes) — feature landscape and differentiator validation
- [Exclusión de IVA — DIAN Concepto 1431 (Cr Consultores)](https://crconsultorescolombia.com/exclusion-de-iva-en-servicios-veterinarios-y-bienestar-animal-dian-concepto-1431012149.php) — tax scope, needs accountant verification
- [Riverpod's Flaws: A Critical Perspective](https://lazebny.io/riverpod/); [Riverpod Best Practices — DCM](https://dcm.dev/blog/2026/03/25/inside-riverpod-source-code-guide-dcm-rules/) — provider sprawl/stale-reference pitfalls

### Tertiary (LOW confidence)
- General veterinary EMR/PIMS vendor buyer-guide content (co.vet, VetPartners) — clinical-record-as-free-text anti-pattern; consistent across sources but not peer-reviewed
- [Offline-First Mobile App Architecture — dev.to](https://dev.to/odunayo_dada/offline-first-mobile-app-architecture-syncing-caching-and-conflict-resolution-518n) — relevant only to the deferred offline-mode milestone, not v1

---
*Research completed: 2026-09-23*
*Ready for roadmap: yes*
