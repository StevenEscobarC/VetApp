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
  - "clientes.perfiles_id / codigo_vinculacion / codigo_expira_en columns (CLI-05 link-code backend, vet side only)"
  - "mascotas.foto_path column (object path, never a signed URL)"
  - "mascota_pesos append-only weight-history table + vet-only RLS (PAT-05)"
  - "registrar_cliente_con_mascota / registrar_mascota / generar_codigo_vinculacion security-invoker RPCs, anon-blocked"
  - "mascota-fotos private Storage bucket + 4 clinic-scoped storage.objects RLS policies (PAT-03)"
  - "RLS smoke test extended to 53 checks (27 Phase 1 + 26 Phase 2); anon REST probe extended to mascota_pesos + the 3 RPCs"
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

requirements-completed: []  # CLI-01, CLI-05, PAT-01, PAT-03, PAT-05 backend is written and locally verified, but NOT yet applied to the live cloud project -- Task 3 (blocking checkpoint) is pending user action. Do not mark complete until the live RLS SMOKE: PASS message is confirmed.

# Metrics
duration: ~35min (Tasks 1-2; Task 3 paused awaiting user)
completed: PENDING - blocked at Task 3 checkpoint
---

# Phase 2 Plan 01: Backend delta for Clientes y Pacientes Summary

**Idempotent schema delta (link-code columns, foto_path, append-only mascota_pesos, 3 atomic RPCs, private mascota-fotos bucket + storage RLS) written and locally verified; 53-check RLS smoke test extended; live application to the cloud project is a BLOCKING checkpoint awaiting the user.**

## Performance

- **Started:** 2026-09-25T02:20:00Z (approx.)
- **Completed:** PENDING (paused at Task 3 checkpoint)
- **Tasks:** 2 of 3 completed (Task 3 is `checkpoint:human-action`, gate="blocking")
- **Files modified:** 3 (`supabase/schema.sql`, `supabase/tests/rls_smoke_test.sql`, `supabase/tests/verify_live_schema.sh`)

## Accomplishments

- Appended a fully idempotent Phase 2 section to `supabase/schema.sql`: 3 new nullable columns + 1 format constraint + 2 indexes on `clientes`; `mascotas.foto_path`; the new `mascota_pesos` append-only table with 2 RLS policies (select/insert only); 3 `security invoker` RPCs (`registrar_cliente_con_mascota`, `registrar_mascota`, `generar_codigo_vinculacion`) each revoked from `public`/`anon` and granted to `authenticated`; the private `mascota-fotos` bucket + 4 clinic-scoped `storage.objects` policies. Verified with the plan's automated `SCHEMA2_OK` grep gate and confirmed via `git diff` that zero Phase 1 lines were touched.
- Extended `supabase/tests/rls_smoke_test.sql` from 27 to 53 checks: D1-D18 (as vet A: weight append-only behavior, both RPCs, link-code generation/repeat-before-expiry/forced-expiry-regeneration, cross-clinic rejections, storage isolation), E1-E4 (as vet B, cross-checking against vet A's data), F1-F4 (as the CLIENTE-role account, confirming zero access to any of the new surface). Every new check follows the existing ID-prefixed failure-message convention and the nested `begin/exception` pattern; storage checks (D16-D18, E3, F3, F4) are all wrapped so an unexpected ownership/permission error on `storage.objects` itself is captured as a failure message rather than aborting the script. Verified `git diff --stat` shows only insertions (292 lines added, 0 removed) confirming the Phase 1 A1-C8 blocks are untouched.
- Extended `supabase/tests/verify_live_schema.sh`: added `mascota_pesos` to the anon table-read probe loop, and a new RPC probe loop that POSTs dummy payloads to the 3 new RPCs as `anon` and expects `401`/`403` (function exists, correctly protected), flags `404` as "no aplicada", and flags any `2xx` as a failure. Confirmed with `bash -n` and confirmed the anon key is never echoed (existing script convention preserved).

## Task Commits

1. **Task 1: Append the Phase 2 schema delta to supabase/schema.sql** - `abb037e` (feat)
2. **Task 2: Extend the RLS smoke test (26 new checks) and the anon REST probe** - `f4e992c` (test)
3. **Task 3: BLOCKING — apply schema.sql and run the extended RLS smoke test in the cloud project** - NOT YET DONE (checkpoint:human-action, gate="blocking")

**Plan metadata:** pending (will be added once Task 3 completes and the plan is fully closed by the orchestrator/continuation agent)

## Files Created/Modified

- `supabase/schema.sql` - Appended the "Fase 2: Clientes y Pacientes" section (263 lines added, 0 removed/modified from Phase 1)
- `supabase/tests/rls_smoke_test.sql` - Extended header, added 7 new declared variables, added `mascota_pesos`/`storage.objects` seed rows, added D1-D18/E1-E4/F1-F4 check blocks (292 lines added, 0 removed)
- `supabase/tests/verify_live_schema.sh` - Added `mascota_pesos` to the table-read probe loop; added the RPC anon-protection probe loop (1 line changed, ~33 lines added)

## Decisions Made

- Followed the plan's exact RPC contract (names/parameters/return shapes) verbatim — no renaming, no signature changes — since Plans 04/07/09 (built in parallel) call these RPCs by that exact contract.
- Used `gen_random_uuid()` (Postgres core since v13, resolves via `pg_catalog` regardless of `search_path`) for the 6-digit code's randomness source instead of any `pgcrypto` function, per the plan's explicit guidance that `search_path = public` inside a `security invoker` function cannot see Supabase's `extensions` schema where `pgcrypto` actually lives.
- Wrapped every storage-related smoke-test check (D16-D18, E3, F3, F4) in its own `begin/exception` block — even the plain `select count(*)` ones — so that if the live project raises an unexpected `storage.objects`-ownership error (the documented fallback scenario in Task 3's `<action>`), the failure is captured as a message rather than aborting the whole `do $$` block before it can raise its mandatory `RLS SMOKE: PASS/FAIL` closing message.

## Deviations from Plan

None - plan executed exactly as written for Tasks 1 and 2. No Rule 1-4 auto-fixes were needed; no bugs, missing critical functionality, blocking issues, or architectural changes were encountered while writing the SQL delta or the smoke-test extension.

## Issues Encountered

None during Tasks 1-2. Task 3 is a genuine, expected blocker: Claude has no DDL access to the cloud Supabase project (`apjonrmhkpyzbofupokb`) — this is the plan's designed BLOCKING checkpoint (D-03 manual-SQL convention, same as Phase 1), not an unplanned issue.

## User Setup Required

**External service (Supabase) requires manual configuration before this plan — and Plans 02-04 through 02-10 which depend on this backend — can be considered done.**

1. Open https://supabase.com/dashboard/project/apjonrmhkpyzbofupokb/sql/new
2. Paste the **entire** contents of `supabase/schema.sql` (not just the new section — the whole file is idempotent and safe to re-run over the existing Phase 1 schema/data) and click Run. Expected: "Success. No rows returned".
3. Open a new query tab, paste the **entire** contents of `supabase/tests/rls_smoke_test.sql`, and click Run. Expected: an ERROR whose message starts with `RLS SMOKE: PASS (53 checks)` — this is intentional, it rolls back all test data automatically.
4. Open Storage in the dashboard and confirm a bucket named `mascota-fotos` exists and is **not** public.
5. Report back the full, verbatim `RLS SMOKE: ...` message (and the verbatim error from step 2, if any).

**Storage fallback (only if needed):** If step 3 fails *only* on storage-related checks (D16-D18, E3, F3, F4) with an ownership/permission error on `storage.objects` itself (e.g. "must be owner of table objects" or "permission denied for table objects") — rather than a normal RLS-denial exception — the next agent should ask the user to create the bucket and the 4 policies manually via Dashboard → Storage → Policies using the same USING/WITH CHECK expressions already in `supabase/schema.sql`, and record that fallback here; every non-storage check must still report PASS.

Once the user replies with the `RLS SMOKE: PASS` message, a continuation agent should:
- Run `bash supabase/tests/verify_live_schema.sh` and confirm it prints `LIVE_SCHEMA_OK` as its last line.
- Record the verbatim smoke-test message and probe output in this SUMMARY.md.
- Confirm the bucket privacy.
- Only then mark Task 3 done and consider requirements CLI-01, CLI-05, PAT-01, PAT-03, PAT-05 complete.

## Next Phase Readiness

- The RPC contract (`registrar_cliente_con_mascota`, `registrar_mascota`, `generar_codigo_vinculacion`) and the schema surface (`foto_path`, `mascota_pesos`, link-code columns, `mascota-fotos` bucket) that Plans 03-09 build against is now fully written, locally verified, and ready to paste — but **not yet live**. Any Dart-side plan that calls these RPCs against a real device/emulator will fail until Task 3 is completed by the user and confirmed by a continuation agent.
- No blockers for the Dart-side plans that only build against fakes/mocks in parallel (per the plan's `<objective>` note that Plans 03-09 are unit-tested against fakes independent of this plan's live-schema step).

---
*Phase: 02-clientes-y-pacientes*
*Completed: PENDING — paused at Task 3 blocking checkpoint, 2026-09-25*
