---
phase: 01-fundaci-n
plan: 01
subsystem: database
tags: [supabase, postgres, rls, sql, multi-tenant]

# Dependency graph
requires: []
provides:
  - "supabase/schema.sql: clientes table (decoupled from perfiles), mascotas re-pointed to clientes with composite FK, hardened perfiles_update (no self-escalation), vet-only RLS"
  - "supabase/tests/rls_smoke_test.sql: single-paste 27-check RLS smoke test"
  - "supabase/tests/verify_live_schema.sh: anon REST probe for the 4 tenant tables + anon-write-rejection check"
affects: ["01-02", "01-03", "any future phase touching clientes/mascotas/perfiles RLS"]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "RLS testing via SET_CONFIG('role', 'authenticated', true) + request.jwt.claims impersonation inside a single do $$ block that always RAISE EXCEPTIONs at the end (guaranteed rollback, zero residue)"
    - "Privilege-escalation-proof UPDATE policy: WITH CHECK pins sensitive columns to their pre-update value via a correlated subquery against the same table"
    - "Composite FK (dueno_id, clinica_id) references clientes(id, clinica_id) to make cross-tenant linkage a hard DB-level integrity error (foreign_key_violation), not just an RLS-filtered no-op"

key-files:
  created:
    - supabase/tests/rls_smoke_test.sql
    - supabase/tests/verify_live_schema.sh
  modified:
    - supabase/schema.sql

key-decisions:
  - "clientes table columns: id, clinica_id (not null, FK cascade), nombre, telefono, email (nullable), direccion, notas, created_at, updated_at + unique(id, clinica_id) as the FK target for mascotas"
  - "mascotas.clinica_id tightened to NOT NULL (every mascota now always belongs to the creating vet's clinic; no more client-owned/unassigned case since clients don't authenticate)"
  - "perfiles_update WITH CHECK fix uses the correlated-subquery pattern (D-03) rather than a BEFORE UPDATE trigger, matching the plan's explicit decision"
  - "RLS smoke test is a manual, single-paste script (not pgTAP/CI) per D-03/D-04 -- prioritizes speed over automated coverage for this phase"

patterns-established:
  - "Every future tenant-scoped table should follow the clientes/mascotas RLS shape: to authenticated using/with check (public.es_veterinario() and clinica_id = public.mi_clinica_id())"

requirements-completed: []  # Pending: Task 3 (BLOCKING checkpoint) not yet resolved -- see below.

# Metrics
duration: 35min
completed: 2026-09-24
---

# Phase 1 Plan 1: Supabase Schema Hardening (RLS) Summary

**Hardened schema.sql (new `clientes` table, `mascotas` re-pointed with vet-only RLS, `perfiles_update` self-escalation fix) plus a single-paste 27-check RLS smoke test and an anon REST probe -- code and tests are ready and committed, but the plan is PAUSED at a BLOCKING human checkpoint: the cloud project has not yet had this schema applied.**

## Performance

- **Duration:** ~35 min (Tasks 1-2)
- **Tasks:** 2 of 3 complete (Task 3 is a `checkpoint:human-action` and cannot be automated -- see below)
- **Files modified:** 3 (1 modified, 2 created)

## Status: PAUSED AT BLOCKING CHECKPOINT

This plan is `autonomous: false` by design. Tasks 1 and 2 (writing the SQL and the tests) are complete and committed. **Task 3 requires the human user to paste SQL into the Supabase cloud SQL Editor** -- Claude has no DB password / CLI link, only the anon key, and cannot reach `https://supabase.com/dashboard/project/apjonrmhkpyzbofupokb`. Full instructions are in the checkpoint message returned alongside this summary. FOUND-01/FOUND-04/FOUND-05 are **not yet closed** -- `requirements-completed` is intentionally empty. A continuation agent must resume Task 3 after the user reports the `RLS SMOKE:` result.

## Accomplishments

- `supabase/schema.sql` now defines `public.clientes` (decoupled from `perfiles`, owned by `clinica_id`), re-points `mascotas.dueno_id` at `clientes(id, clinica_id)` via a composite FK, tightens `mascotas.clinica_id` to `NOT NULL`, rewrites all 4 `mascotas` RLS policies to vet-only (removing the now-dead `dueno_id = auth.uid()` branches per Pitfall 2), adds 4 `clientes` RLS policies, and fixes the `perfiles_update` privilege-escalation bug (Pitfall 1 / D-03) so a `CLIENTE` can never change their own `rol` or `clinica_id`.
- `supabase/tests/rls_smoke_test.sql`: a single `do $$ ... end $$;` block runnable in one paste. Creates 2 throwaway VETERINARIO accounts (different clinics) + 1 CLIENTE account via direct `auth.users` insert (exercising the signup trigger), seeds one `cliente`/`mascota` per clinic as `postgres`, then impersonates each of the 3 accounts via `set_config('request.jwt.claims', ...)` + `set_config('role', 'authenticated', true)` to run 27 positive/negative checks (A1-A17 as vet A, B1-B2 as vet B, C1-C8 as the client, including the exact self-escalation attack C5/C6 and the FK-violation attack A15). Always ends by `RAISE EXCEPTION 'RLS SMOKE: PASS/FAIL ...'`, which rolls back every row it created -- verified idempotent/residue-free by construction (Postgres aborts the whole implicit transaction on an uncaught exception from a top-level `do` block).
- `supabase/tests/verify_live_schema.sh`: bash probe reading `SUPABASE_URL`/`SUPABASE_ANON_KEY` from env or `dart_define.json` (via `node -e`, cwd-relative require to dodge git-bash/Windows path issues -- never prints the key), hits `GET rest/v1/<table>?select=id&limit=1` for `clinicas`/`perfiles`/`clientes`/`mascotas` (expect 200) and `POST rest/v1/clientes` as anon (expect 401/403). Ran it locally against the real cloud project (pre-apply): correctly reports `FAIL <table> 404` for all 4 tables and exits 1 -- confirms the project is still empty, exactly as RESEARCH.md documented, and confirms the script's own logic works end-to-end.

## Task Commits

1. **Task 1: Harden supabase/schema.sql** - `ed63628` (feat)
2. **Task 2: Write RLS smoke test + anon REST probe** - `e58ef7e` (test)

**Plan metadata:** (this summary's own commit, see below)

_Task 3 (checkpoint:human-action, gate="blocking") has not been executed -- no commit yet._

## Files Created/Modified

- `supabase/schema.sql` - clientes table, mascotas FK re-point + vet-only RLS, perfiles_update fix
- `supabase/tests/rls_smoke_test.sql` - single-paste 27-check manual RLS smoke test
- `supabase/tests/verify_live_schema.sh` - anon REST probe (4 tables + anon-write-rejection)

## Decisions Made

- Followed the plan's exact column/policy specification for `clientes` and the FK-repoint for `mascotas` (RESEARCH.md "Exact `clientes` table + RLS" / "Exact `mascotas` FK repoint").
- Used the correlated-subquery `WITH CHECK` fix for `perfiles_update` (D-03), not the alternative `BEFORE UPDATE` trigger RESEARCH.md flagged as an optional stronger alternative.
- `verify_live_schema.sh` reads `dart_define.json` by `cd`-ing to the repo root first and requiring a relative path, instead of passing an absolute path string to `node -e` -- the plan's literal spec ("fall back to `dart_define.json` via `node -e`") didn't anticipate that git-bash's POSIX-style `pwd` output (`/c/...`) is unparseable by Windows-native `node.exe` when embedded inside a `-e` string. This is a Rule 1 (bug) fix discovered while actually running the script, not a deviation from the plan's intent.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed `dart_define.json` path resolution in `verify_live_schema.sh`**
- **Found during:** Task 2 (running the script to verify Task 2's own acceptance gate)
- **Issue:** Computing `REPO_ROOT` via `cd ... && pwd` inside git-bash yields a POSIX-style path (e.g. `/c/Trabajo/VetApp/...`). Passing that string into `node -e "require('$REPO_ROOT/dart_define.json')"` fails with `MODULE_NOT_FOUND` because Windows-native `node.exe` cannot resolve that path format when it's embedded inside a JS string (git-bash's automatic POSIX->Windows path translation only rewrites bare CLI arguments, not substrings inside a larger `-e` payload).
- **Fix:** `cd "$REPO_ROOT" && node -e "require('./dart_define.json')..."` -- requiring a cwd-relative path lets Node's own resolver do the work natively, regardless of shell path-format quirks.
- **Files modified:** `supabase/tests/verify_live_schema.sh`
- **Verification:** Ran the script against the real (pre-apply) cloud project; it now correctly reports `FAIL <table> 404` for all 4 tables and `LIVE_SCHEMA_OK` is *not* printed (exit 1) -- matching Task 2's acceptance criteria exactly. Confirmed 0 occurrences of the anon-key prefix (`eyJ`) in the script's output.
- **Committed in:** `e58ef7e` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Necessary for the script to actually be runnable on this Windows/git-bash toolchain; no scope creep, no behavior change to the documented CLI contract (env vars still take priority, `dart_define.json` still the fallback, key still never printed).

## Issues Encountered

- `dart_define.json` is gitignored and therefore not present in this git worktree by default (worktrees only check out tracked files). It was manually copied from the main repo checkout (`C:\Trabajo\VetApp\dart_define.json`) into this worktree purely to exercise `verify_live_schema.sh` end-to-end during Task 2's verification -- it remains gitignored and untracked here, and was not committed. A continuation agent resuming Task 3 in a fresh worktree/session may need to repeat this copy (or have the orchestrator do so) to run the post-checkpoint `LIVE_SCHEMA_OK` verification.
- The plan's own automated verify commands hardcode `cd /c/Trabajo/VetApp` (the main repo path). Since this execution runs in an isolated worktree at a different path, all verification commands were run from the worktree root instead (same relative file layout, same logic) -- per worktree-isolation rules, never `cd` out of the assigned worktree.

## User Setup Required

**External service requires manual configuration -- see the checkpoint message returned alongside this summary.** Task 3 needs the user to, in the Supabase Dashboard SQL Editor for `https://apjonrmhkpyzbofupokb.supabase.co`:
1. Paste and run the full `supabase/schema.sql` (expect "Success. No rows returned").
2. Paste and run the full `supabase/tests/rls_smoke_test.sql` in a new query tab (expect an ERROR starting with `RLS SMOKE: PASS (27 checks)`).
3. (Recommended) Turn off "Confirm email" under Authentication -> Sign In / Providers -> Email.
4. Report back the verbatim `RLS SMOKE:` message and the Confirm-email choice.

## Next Phase Readiness

- Blocked: FOUND-01/FOUND-04/FOUND-05 cannot be marked complete until Task 3's checkpoint resolves with `RLS SMOKE: PASS (27 checks)` and `bash supabase/tests/verify_live_schema.sh` prints `LIVE_SCHEMA_OK`.
- Once resolved, plans 01-02 onward (Riverpod/go_router wiring, walking skeleton) can safely assume `es_veterinario()`/`mi_clinica_id()` are a trustworthy tenant boundary and that `clientes`/`mascotas` exist live in the cloud project.
- No other phase-1 plan's work is blocked by this pause per se (waves may still parallelize on other independent tracks), but nothing that reads/writes `clientes` or `mascotas` against the real backend can be verified end-to-end until the checkpoint clears.

---
*Phase: 01-fundaci-n*
*Status: PAUSED at Task 3 (blocking checkpoint) -- 2026-09-24*
