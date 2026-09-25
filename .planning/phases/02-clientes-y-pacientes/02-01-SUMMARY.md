---
phase: 02-clientes-y-pacientes
plan: 01
subsystem: database
tags: [postgres, supabase, rls, storage, plpgsql, postgrest]

# Dependency graph
requires:
  - phase: 01-fundacion
    provides: clinicas/perfiles/clientes/mascotas tables, es_veterinario()/mi_clinica_id() helpers, vet-only RLS, RLS smoke test harness and live-schema probe script
provides:
  - "clientes.perfiles_id / codigo_vinculacion / codigo_expira_en columns (CLI-05 link-code backend, vet side only) -- LIVE in apjonrmhkpyzbofupokb"
  - "mascotas.foto_path column (object path, never a signed URL) -- LIVE"
  - "mascota_pesos append-only weight-history table + vet-only RLS (PAT-05) -- LIVE"
  - "registrar_cliente_con_mascota / registrar_mascota / generar_codigo_vinculacion security-invoker RPCs, anon-blocked -- LIVE"
  - "mascota-fotos private Storage bucket + 4 clinic-scoped storage.objects RLS policies (PAT-03) -- LIVE, confirmed private"
  - "RLS smoke test extended to 53 checks (27 Phase 1 + 26 Phase 2), run in the cloud project: RLS SMOKE PASS (53 checks)"
affects: [02-04, 02-05, 02-06, 02-07, 02-08, 02-09, 02-10, 09-directorio-de-veterinarias]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "security invoker RPC for atomic multi-table writes (registrar_cliente_con_mascota, registrar_mascota) -- caller's RLS still applies inside the function, defense-in-depth not bypass"
    - "gen_random_uuid() (pg_catalog core function since PG13) used for random-code generation instead of pgcrypto, because Supabase keeps pgcrypto in the extensions schema which set search_path = public cannot see"
    - "append-only history table (mascota_pesos): select/insert RLS policies only, no update/delete policy at all"
    - "storage.objects RLS keyed on (storage.foldername(name))[1] = mi_clinica_id()::text, reusing Phase 1's tenant-scoping helpers instead of re-deriving them"

key-files:
  created: []
  modified:
    - supabase/schema.sql
    - supabase/tests/rls_smoke_test.sql
    - supabase/tests/verify_live_schema.sh

key-decisions:
  - "6-digit numeric link code (not UUID/deep-link) per D-07, globally unique via partial unique index so Phase 9's claim RPC can look codes up across clinics"
  - "registrar_mascota relies on the existing composite FK (dueno_id, clinica_id) -> clientes(id, clinica_id) to reject a dueño from another clinic, rather than an explicit application-level check"
  - "reclamar_codigo_cliente (CLIENTE-side claim, security definer) intentionally NOT created this phase -- deferred to Phase 9 (DIR-06) per plan; grep gate in Task 1 verification asserts its absence"
  - "Task 3's automated anon-probe verification (bash supabase/tests/verify_live_schema.sh) could not be executed from this sandboxed worktree agent (no SUPABASE_URL/SUPABASE_ANON_KEY env vars, no dart_define.json in the worktree). The checkpoint was closed on the user's manual SQL Editor + Storage dashboard confirmation instead, per the project's D-03 manual-verification convention -- the same convention that made this a checkpoint:human-action task in the first place."

requirements-completed: [CLI-01, CLI-05, PAT-01, PAT-03, PAT-05]

# Metrics
duration: ~45min
completed: 2026-09-25
---

# Phase 2 Plan 01: Backend delta for Clientes y Pacientes Summary

**Idempotent schema delta (link-code columns, foto_path, append-only mascota_pesos, 3 atomic RPCs, private mascota-fotos bucket + storage RLS) applied live to the cloud project; extended 53-check RLS smoke test ran clean (`RLS SMOKE: PASS (53 checks)`); bucket confirmed private with all 4 policies in place.**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-09-25T02:20:00Z (approx.)
- **Completed:** 2026-09-25T03:20:00Z (approx., checkpoint resumed and closed same session)
- **Tasks:** 3 of 3 completed
- **Files modified:** 3 (`supabase/schema.sql`, `supabase/tests/rls_smoke_test.sql`, `supabase/tests/verify_live_schema.sh`)

## Accomplishments

- Appended a fully idempotent Phase 2 section to `supabase/schema.sql`: 3 new nullable columns + 1 format constraint + 2 indexes on `clientes`; `mascotas.foto_path`; the new `mascota_pesos` append-only table with 2 RLS policies (select/insert only); 3 `security invoker` RPCs (`registrar_cliente_con_mascota`, `registrar_mascota`, `generar_codigo_vinculacion`) each revoked from `public`/`anon` and granted to `authenticated`; the private `mascota-fotos` bucket + 4 clinic-scoped `storage.objects` policies. Verified with the plan's automated `SCHEMA2_OK` grep gate and confirmed via `git diff` that zero Phase 1 lines were touched.
- Extended `supabase/tests/rls_smoke_test.sql` from 27 to 53 checks: D1-D18 (as vet A: weight append-only behavior, both RPCs, link-code generation/repeat-before-expiry/forced-expiry-regeneration, cross-clinic rejections, storage isolation), E1-E4 (as vet B, cross-checking against vet A's data), F1-F4 (as the CLIENTE-role account, confirming zero access to any of the new surface). Every new check follows the existing ID-prefixed failure-message convention and the nested `begin/exception` pattern; storage checks (D16-D18, E3, F3, F4) are all wrapped so an unexpected ownership/permission error on `storage.objects` itself is captured as a failure message rather than aborting the script.
- Extended `supabase/tests/verify_live_schema.sh`: added `mascota_pesos` to the anon table-read probe loop, and a new RPC probe loop that POSTs dummy payloads to the 3 new RPCs as `anon` and expects `401`/`403`.
- **User applied both SQL files in the live cloud project (`apjonrmhkpyzbofupokb`) and confirmed:**
  1. `supabase/schema.sql` ran successfully with no errors.
  2. `supabase/tests/rls_smoke_test.sql` produced, verbatim: `ERROR: P0001: RLS SMOKE: PASS (53 checks) - cambios revertidos` — all 53 checks (27 Phase 1 + 26 Phase 2) passed on the live project as the `authenticated` role; the script's own rollback-by-design exception fired as expected, leaving zero residue.
  3. Storage → Buckets confirms `mascota-fotos` exists with exactly the 4 expected policies (`mascota_fotos_select`/`insert`/`update`/`delete`, all scoped to role `authenticated`) — screenshot-verified by the user. The bucket does **not** show a "Public" label in the dashboard, confirming it is private.

## Task Commits

1. **Task 1: Append the Phase 2 schema delta to supabase/schema.sql** - `abb037e` (feat)
2. **Task 2: Extend the RLS smoke test (26 new checks) and the anon REST probe** - `f4e992c` (test)
3. **Task 3: BLOCKING — apply schema.sql and run the extended RLS smoke test in the cloud project** - `db97942` (docs, checkpoint state) + this commit (docs, closed) — user-executed in the Supabase SQL Editor / Storage dashboard (no Claude-authored code commit for this task; it is a manual verification step by design)

**Plan metadata:** pending (final `docs(02-01): complete plan` metadata commit is applied by the orchestrator after this SUMMARY, per worktree-mode convention — this agent does not touch STATE.md/ROADMAP.md)

## Files Created/Modified

- `supabase/schema.sql` - Appended the "Fase 2: Clientes y Pacientes" section (263 lines added, 0 removed/modified from Phase 1) — now live in the cloud project
- `supabase/tests/rls_smoke_test.sql` - Extended header, added 7 new declared variables, added `mascota_pesos`/`storage.objects` seed rows, added D1-D18/E1-E4/F1-F4 check blocks (292 lines added, 0 removed) — ran clean in the cloud project
- `supabase/tests/verify_live_schema.sh` - Added `mascota_pesos` to the table-read probe loop; added the RPC anon-protection probe loop (could not be executed from this sandboxed worktree — see Issues Encountered)

## Decisions Made

- Followed the plan's exact RPC contract (names/parameters/return shapes) verbatim — no renaming, no signature changes — since Plans 04/07/09 (built in parallel) call these RPCs by that exact contract.
- Used `gen_random_uuid()` (Postgres core since v13, resolves via `pg_catalog` regardless of `search_path`) for the 6-digit code's randomness source instead of any `pgcrypto` function, per the plan's explicit guidance that `search_path = public` inside a `security invoker` function cannot see Supabase's `extensions` schema where `pgcrypto` actually lives.
- Wrapped every storage-related smoke-test check (D16-D18, E3, F3, F4) in its own `begin/exception` block — even the plain `select count(*)` ones — so that if the live project raised an unexpected `storage.objects`-ownership error (the documented fallback scenario in Task 3's `<action>`), the failure would be captured as a message rather than aborting the whole `do $$` block before it could raise its mandatory `RLS SMOKE: PASS/FAIL` closing message. In the event, no fallback was needed — the live run reported a clean PASS on all 53 checks including storage.
- Closed the Task 3 checkpoint on the user's manual dashboard confirmation (verbatim PASS message + screenshot of bucket/policies) rather than this agent's own automated probe run, because the automated probe requires live cloud credentials this sandboxed worktree does not have. This matches the project's own D-03 convention (manual SQL Editor verification, no CI/automated migration pipeline) — the checkpoint's `<how-to-verify>` steps are explicitly designed for the user to execute in the dashboard, and its `<resume-signal>` is "paste the RLS SMOKE message", which the user did.

## Deviations from Plan

None - plan executed exactly as written for Tasks 1 and 2. No Rule 1-4 auto-fixes were needed; no bugs, missing critical functionality, blocking issues, or architectural changes were encountered while writing the SQL delta or the smoke-test extension. Task 3 required no fix of any kind — schema.sql applied cleanly on the first attempt and the smoke test passed all 53 checks with no fallback needed.

## Issues Encountered

**Automated live-schema probe not executable from this sandboxed worktree agent.** `bash supabase/tests/verify_live_schema.sh` requires `SUPABASE_URL`/`SUPABASE_ANON_KEY` (env vars or a gitignored `dart_define.json` at the repo root); neither is present in this worktree's sandbox, so running the script here produces `FAIL config: falta SUPABASE_URL / SUPABASE_ANON_KEY` — a credentials-availability limitation of the sandbox, not a regression in the script or the live schema. The plan's Task 3 `<verify><automated>` step (`bash supabase/tests/verify_live_schema.sh | tail -1 | grep -q LIVE_SCHEMA_OK`) is therefore **not independently re-verified by this agent** for this run. The checkpoint is closed on the strength of the user's direct, verbatim confirmation of the SQL Editor output and the Storage dashboard screenshot instead, which covers the same ground (tables/RPCs/bucket policies live and correctly scoped) that the script would have probed as `anon`. A future agent or the user, running from a machine with the project's `dart_define.json` present, can re-run the script at any time to get the `LIVE_SCHEMA_OK` confirmation with zero risk (it is read-only against tables and only POSTs to already-tested RPCs expecting a 401/403 rejection).

## User Setup Required

None further — the one external-service setup this plan required (applying `supabase/schema.sql` and `supabase/tests/rls_smoke_test.sql` to the live Supabase project `apjonrmhkpyzbofupokb`, and confirming the `mascota-fotos` bucket is private) is complete, confirmed by the user directly in the Supabase dashboard.

## Next Phase Readiness

- The RPC contract (`registrar_cliente_con_mascota`, `registrar_mascota`, `generar_codigo_vinculacion`) and the schema surface (`foto_path`, `mascota_pesos`, link-code columns, `mascota-fotos` bucket) that Plans 03-09 build against is now live in the cloud project and RLS-verified (53/53 checks passed as `authenticated`). Dart-side plans calling these RPCs against a real device/emulator can now proceed.
- Recommended follow-up (not blocking): when convenient, run `bash supabase/tests/verify_live_schema.sh` from an environment with `dart_define.json` present (or `SUPABASE_URL`/`SUPABASE_ANON_KEY` exported) to get the automated `LIVE_SCHEMA_OK` confirmation as a second, independent check of the anon-protection boundary on the 3 new RPCs and the `mascota_pesos` table. This is a nice-to-have double-check, not a gate — the manual dashboard confirmation already covers the same trust boundary.
- No blockers for the Dart-side plans that build against fakes/mocks in parallel (per the plan's `<objective>` note that Plans 03-09 are unit-tested against fakes independent of this plan's live-schema step).

## Self-Check

- `supabase/schema.sql` contains the Phase 2 section: FOUND (verified via `SCHEMA2_OK` grep gate, re-confirmed present in worktree)
- `supabase/tests/rls_smoke_test.sql` contains D1-D18/E1-E4/F1-F4: FOUND (verified via Grep, all 26 IDs present)
- `supabase/tests/verify_live_schema.sh` contains `mascota_pesos` + 3 RPC probes: FOUND (verified via Grep and `bash -n`)
- Commit `abb037e` (Task 1): FOUND in `git log --oneline`
- Commit `f4e992c` (Task 2): FOUND in `git log --oneline`
- Commit `db97942` (checkpoint-state SUMMARY): FOUND in `git log --oneline`
- Working tree clean before this update (no stray untracked files): CONFIRMED via `git status --short`

## Self-Check: PASSED

---
*Phase: 02-clientes-y-pacientes*
*Completed: 2026-09-25*
