---
phase: 3
slug: historia-cl-nica
status: verified
threats_open: 0
asvs_level: 1
created: 2026-09-30
---

# Phase 3 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|----------------|
| mobile app (authenticated JWT) -> PostgREST RPC `registrar_consulta` | Vet controls every argument (mascota id, free text, vitals, peso) | Clinical record fields |
| mobile app -> PostgREST table `consultas` | A modified client could try direct insert/update/delete bypassing the RPC | Clinical record fields |
| anon key holder -> PostgREST | Public key; must not reach `consultas` or the RPC | N/A (must be blocked) |
| SQL Editor (postgres) -> smoke test | Privileged session; must leave no residue | Synthetic test rows |
| pub.dev -> project dependency graph | Third-party code (`pdf`, `printing`) executes inside the app and receives clinical data to render | PDF rendering engine |
| form -> `registrar_consulta` RPC | Vet-typed free text and numeric vitals cross into Postgres | Clinical free text + vitals |
| RPC errors -> UI | Raw `PostgrestException` text must not leak to the screen | Error strings |
| `consultas` select (RLS-filtered) -> timeline widget | Clinical text rendered on screen | Clinical record fields |
| app -> OS share sheet | Clinical PDF bytes leave the app to a vet-chosen target | Full clinical history PDF |
| app -> fonts.gstatic.com (`PdfGoogleFonts`) | Font download over the network on first export | Font binary (no clinical data) |
| developer machine -> README / logs | Risk of leaking the anon key into docs | Supabase anon key |
| device -> live project | Real clinical test data created during UAT | Synthetic UAT rows |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-03-RLS | Information Disclosure | `consultas` select | mitigate | `consultas_select` policy requires `es_veterinario()` + `mascotas.clinica_id = mi_clinica_id()` (`supabase/schema.sql:501-508`); smoke G9/H1/I1 assert 0 cross-clinic/client rows (`supabase/tests/rls_smoke_test.sql:713-716,738-741,772-775`) | closed |
| T-03-RPC | Elevation of Privilege | `registrar_consulta` | mitigate | `security invoker` (`schema.sql:544`), explicit vet/clinic guard (`:551-554`), mascota-ownership guard raising `foreign_key_violation` (`:556-560`), `revoke all ... from public, anon` + `grant ... to authenticated` (`:579-584`); smoke G4/H2/I2 (`rls_smoke_test.sql:661-699,743-784`) | closed |
| T-03-APPEND | Tampering / Repudiation | `consultas` update/delete, client UI, timeline | mitigate | No update/delete policy exists (`schema.sql:521-522`); smoke G10/G11/H3/H4 assert 0 rows affected even for the owning vet (`rls_smoke_test.sql:718-728,753-763`); `Consulta` entity has no `copyWith` (`domain/entities/consulta.dart`); `SupabaseConsultaRepository` exposes only `porMascota`/`registrarConsulta` (`data/repositories/supabase_consulta_repository.dart`); no `.update(`/`.delete(` call anywhere under `lib/features/clinical_history/`; `ConsultaFormScreen` is create-only; `HistoriaClinicaTimeline`/`_ConsultaCard` have no edit/delete icon, long-press, or swipe handler (`presentation/widgets/historia_clinica_timeline.dart:74-75`) | closed |
| T-03-SPOOF | Spoofing | `consultas.veterinario_id` on direct insert | mitigate | `consultas_insert` policy requires `veterinario_id = auth.uid()` (`schema.sql:512-519`); RPC sets it from `auth.uid()` server-side (`:566`), never a client-supplied param; smoke G7 (`rls_smoke_test.sql:691-699`) | closed |
| T-03-PESO | Tampering | consulta weight vs `mascota_pesos` (D-02) | mitigate | Single `registrar_consulta` plpgsql function performs both inserts in one transaction (`schema.sql:562-573`); `peso_kg > 0` check on both tables (`:482,232`); client repository/provider make exactly one call, no separate `registrarPeso` path (`supabase_consulta_repository.dart:49-82`, `consultas_providers.dart:45-74`); smoke G1/G2 (`rls_smoke_test.sql:605-642`) | closed |
| T-03-INPUT | Tampering | blank/invalid clinical fields, numeric input | mitigate | Server check constraints on `diagnostico`/`tratamiento`/vitals (`schema.sql:482-489`); `nullif(trim())` for optional text (`:566-568`); client `parsearPeso`/`parsearNumeroPositivo` before any call, with temperature capped to `maximo: 999.9` matching the `numeric(4,1)` column (`consulta_form_screen.dart:81-93`, fixing WR-03); smoke G3/G5/G6 (`rls_smoke_test.sql:645-688`) | closed |
| T-03-SMOKE | Tampering | smoke test residue in real DB | mitigate | Script's only two exit paths both call `raise exception` (pass or fail), rolling back every insert (`rls_smoke_test.sql:794-797`) | closed |
| T-03-FKDEL | Repudiation | `veterinario_id` on delete cascade | accept | `consultas.veterinario_id references auth.users(id) on delete cascade` (`schema.sql:476`) would silently delete clinical records if a vet account is ever deleted. No account-deletion feature exists yet. Risk documented in a schema comment (`schema.sql:471-475`), in code review `03-REVIEW.md` WR-04, and logged below in Accepted Risks Log per `STATE.md` Blockers/Concerns — must be revisited (`on delete restrict` or placeholder-user pattern) before any account-deletion feature ships | closed (accepted) |
| T-03-SC | Tampering | pubspec install of `pdf`/`printing` | mitigate | Exact pins, no caret: `pdf: 3.12.0`, `printing: 5.14.3` (`pubspec.yaml:48-49`), matching resolved lockfile entries (`pubspec.lock:747-750,867-870`); legitimacy checkpoint against verified pub.dev publisher documented in `03-02-PLAN.md`/README | closed |
| T-03-DOS | Denial of Service | Dependency resolution break | mitigate | Exact pins (no caret) on `pdf`/`printing` verified in `pubspec.yaml`/`pubspec.lock` as above; resolved versions match the pinned versions exactly | closed |
| T-03-ERR | Information Disclosure | error messages (consulta + PDF) | mitigate | Two-tier handling in `SupabaseConsultaRepository._messageFor` (`supabase_consulta_repository.dart:104-117`, mapping `42501`/`23503`/`23514`/`23502`/`22003`) with catch-all fallback (`:36-40,77-81`); PDF service/share wrapper catch-all to fixed `ConsultaFailure` (`historia_clinica_pdf_service.dart:145-149`, `historia_clinica_pdf_providers.dart:32-36`); UI shows only `ConsultaFailure.message` (`consulta_form_screen.dart:142-143`) | closed |
| T-03-XCLIN | Elevation of Privilege | `mascotaId` taken from the route | accept | `mascotaId` comes from a ficha the vet could already see via RLS; RPC re-checks clinic ownership server-side and raises `foreign_key_violation`/23503 on mismatch (`schema.sql:556-560`); verified by smoke G4/H2 (`rls_smoke_test.sql:661-668,743-750`) | closed (accepted) |
| T-03-ORDER | Repudiation | misleading chronology in the timeline | mitigate | Defensive client-side sort by `fecha desc` regardless of source order (`historia_clinica_timeline.dart:51-52`); PDF sorts ascending separately for chronological reading (`historia_clinica_pdf_service.dart:45-46`) | closed |
| T-03-PDF | Information Disclosure | exported PDF shared to the wrong recipient | accept | D-05: vet-only, native share by explicit tap only — `Printing.sharePdf` (`historia_clinica_pdf_providers.dart:28-37`); no public link, no upload, no owner-facing channel anywhere in the PDF/share code path | closed (accepted) |
| T-03-PDFDATA | Information Disclosure | PDF content scope | mitigate | `_exportarPdf` builds the PDF only from `mascotaProvider(widget.mascotaId).future` and `consultasProvider(widget.mascotaId).future` (`mascota_detail_screen.dart:62-78`), both RLS-scoped to the vet's own clinic; no veterinarian identity or other patients included in `generar()` output | closed |
| T-03-FONT | Tampering / Denial of Service | network font fetch (`PdfGoogleFonts`) | mitigate | HTTPS via `printing` package's `PdfGoogleFonts`, same trust model as `google_fonts` already in the app (`historia_clinica_pdf_service.dart:19-23`); wrapped in try/catch converting any failure to a fixed Spanish `ConsultaFailure`, never a crash (`:84-149`) | closed |
| T-03-KEY | Information Disclosure | README / SUMMARY leaking the anon key | mitigate | No `eyJ` token found in `README.md` or any `03-*-SUMMARY.md`; key lives only in `dart_define.json`, which is listed in `.gitignore:48` and confirmed untracked via `git ls-files`/`git check-ignore` | closed |
| T-03-UATDATA | Tampering | UAT `consultas` created in the live project | accept | Dev-only project with no real users (same acceptance as Phases 1-2); append-only means test rows stay — documented in `03-06-SUMMARY.md` (10-step device UAT, user approved "aprobado") | closed (accepted) |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|--------------|------|
| AR-03-01 | T-03-FKDEL | `consultas.veterinario_id` cascades on delete of `auth.users`; no account-deletion feature exists yet, so risk is theoretical. Must be revisited (`on delete restrict` or placeholder-user pattern) before any account-deletion feature ships. Tracked in `03-REVIEW.md` WR-04 and `STATE.md` Blockers/Concerns ([Phase 3] entry) | User (via STATE.md Blockers/Concerns, deferred per `03-REVIEW.md`) | 2026-09-29 |
| AR-03-02 | T-03-XCLIN | `mascotaId` is taken from the route rather than re-validated against an explicit allow-list client-side; acceptable because the vet could already see the ficha via RLS, and the server-side RPC independently re-checks clinic ownership (23503) before any write | Plan author (`03-03-PLAN.md` threat model) | 2026-09-25 |
| AR-03-03 | T-03-PDF | Exported PDF is shared via the native OS share sheet at the vet's explicit discretion; recipient choice is a social/human risk outside code control (D-05: no public link, no upload, no owner-facing channel) | Plan author (`03-05-PLAN.md`, `03-06-PLAN.md` threat models) | 2026-09-25 |
| AR-03-04 | T-03-UATDATA | UAT was run against a dev-only Supabase project with no real users; `consultas` is append-only by design so synthetic UAT rows remain, consistent with the same acceptance already made in Phases 1-2 | User (device UAT "aprobado", `03-06-SUMMARY.md`) | 2026-09-30 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|----------------|--------|------|--------|
| 2026-09-30 | 18 | 18 | 0 | gsd-security-auditor |

### Unregistered Flags

None. No `## Threat Flags` section was found in any of `03-01-SUMMARY.md` through `03-06-SUMMARY.md`. `03-REVIEW.md` WR-01/WR-02/WR-03 (re-entrancy guard, PDF-export gate on `mascotaAsync.hasValue`, temperature cap) were code-review findings outside the threat register but were independently confirmed fixed in code during this audit (`consulta_form_screen.dart:80`, `mascota_detail_screen.dart:177`, `consulta_form_screen.dart:84`) — they reinforce, rather than conflict with, T-03-INPUT and general re-entrancy hygiene; no new unmapped attack surface was found. WR-04 is T-03-FKDEL, already in the register.

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-09-30
