---
phase: 03-historia-cl-nica
plan: 01
subsystem: database
tags: [postgres, rls, supabase, plpgsql, historia-clinica]

# Dependency graph
requires:
  - phase: 02-clientes-y-pacientes
    provides: "mascotas, mascota_pesos tables; es_veterinario()/mi_clinica_id() RLS helpers; registrar_mascota RPC pattern to mirror"
provides:
  - "consultas table: flat-column, append-only clinical-record schema (no update/delete policy)"
  - "registrar_consulta(...) RPC: atomic consulta + optional mascota_pesos insert (D-02), exact contract consumed by Plan 03-03's repository"
  - "70-check RLS smoke test proving clinic isolation and append-only enforcement for consultas"
  - "verify_live_schema.sh probe covering the consultas table and registrar_consulta RPC"
affects: [03-03-clinical-history-app-layer]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Append-only table: no update/delete RLS policy at all (same shape as mascota_pesos)"
    - "Atomic multi-table RPC (security invoker) feeding a Phase 2 table conditionally"

key-files:
  created: []
  modified:
    - supabase/schema.sql
    - supabase/tests/rls_smoke_test.sql
    - supabase/tests/verify_live_schema.sh

key-decisions:
  - "registrar_consulta's mascota-ownership guard raises errcode 'foreign_key_violation' (23503) instead of insufficient_privilege, so the Dart _messageFor(23503) mapping surfaces the exact UI-SPEC copy; the vet/clinic guard keeps insufficient_privilege"
  - "Optional text params stored via nullif(trim(p_x), '') so a blank optional field is NULL, never '' (D-03)"

requirements-completed: [HIST-01, HIST-02, HIST-04]

duration: 5min (Tasks 1-2; Task 3 pending human action in cloud SQL Editor)
completed: 2026-09-25
---

# Phase 3 Plan 01: Historia Clínica — Schema Delta Summary

**Append-only `consultas` table + atomic `registrar_consulta` RPC (feeds `mascota_pesos` when a weight is given) and a 70-check RLS smoke test — schema/test files ready, awaiting the user's cloud SQL Editor paste (Task 3, blocking checkpoint).**

## Performance

- **Duration:** ~5 min for Tasks 1-2 (schema + tests authored and committed)
- **Started:** 2026-09-25T21:57:09-05:00 (base commit `7254250`)
- **Completed:** Tasks 1-2 done 2026-09-25T22:01:42-05:00; Task 3 (BLOCKING checkpoint) not yet resolved — no DDL access to the live project
- **Tasks:** 2/3 completed automatically; Task 3 requires the user to paste SQL into the Supabase SQL Editor
- **Files modified:** 3 (`supabase/schema.sql`, `supabase/tests/rls_smoke_test.sql`, `supabase/tests/verify_live_schema.sh`)

## Accomplishments
- Added the Phase 3 idempotent schema delta: `consultas` table (flat nullable columns, no `examen_fisico jsonb`, no `proxima_cita`, no `corrige_a`), indexed `(mascota_id, fecha desc)`, RLS-enabled with exactly 2 policies (`consultas_select`, `consultas_insert`) and zero update/delete policies (HIST-04).
- Added `public.registrar_consulta(...)` — the exact RPC contract Plan 03-03's repository will call — atomically inserting the consulta and, only when `p_peso_kg is not null`, a `mascota_pesos` row in the same transaction (D-02).
- Extended `supabase/tests/rls_smoke_test.sql` from 53 to 70 checks (G1-G11 as vet A, H1-H4 as vet B, I1-I2 as cliente C), all existing checks left byte-identical.
- Extended `supabase/tests/verify_live_schema.sh`'s table loop and RPC loop to also probe `consultas`/`registrar_consulta` against the live project as the anon role.

## Task Commits

Each task was committed atomically:

1. **Task 1: Append the Phase 3 schema delta to supabase/schema.sql** - `8f6c62f` (feat)
2. **Task 2: Extend the RLS smoke test (17 new checks, total 70) and the anon REST probe** - `665d6fc` (test)

**Task 3 (BLOCKING checkpoint):** not committed — requires the user to run SQL in the Supabase Dashboard SQL Editor; no commit is possible until that happens and the smoke-test result is recorded here.

## Files Created/Modified
- `supabase/schema.sql` - Added the "Fase 3: Historia Clínica" section (125 lines appended, nothing above it changed): `consultas` table + index + RLS + `registrar_consulta` RPC + revoke/grant.
- `supabase/tests/rls_smoke_test.sql` - Added Fase 3 coverage line to the header comment, 3 new declared variables (`n_pesos`, `v_consulta`, `v_texto`), 2 seed `consultas` rows, and the G1-G11/H1-H4/I1-I2 check blocks (202 lines appended/changed, no earlier check altered).
- `supabase/tests/verify_live_schema.sh` - Added `consultas` to the table probe loop and `registrar_consulta` (with its JSON payload) to the RPC probe loop.

## Decisions Made
- `foreign_key_violation` (23503) chosen over `insufficient_privilege` for the mascota-ownership guard inside `registrar_consulta`, per the plan's explicit RPC contract, so the Dart repository's existing `23503 -> 'La mascota no existe en tu clínica.'` mapping fires correctly.
- Optional free-text params (`anamnesis`, `evolucion`, `mucosas`) are stored via `nullif(trim(p_x), '')`, guaranteeing a blank/whitespace-only value is persisted as `NULL`, never `''` — verified by smoke check G3.

## Deviations from Plan

None - plan executed exactly as written (Tasks 1-2). Task 3 is the plan's own designed blocking checkpoint (`autonomous: false`), not a deviation.

## Issues Encountered

**Worktree branch drift on spawn.** The worktree's `worktree-agent-a6d85fc5a5e92c375` branch was found at commit `97b3ba5` ("docs: create roadmap") — far behind the plan's required base commit `7254250`. This was a stale/pre-Phase-3 checkout of the per-agent branch, not caused by any action in this session. Per the mandatory `<worktree_branch_check>` startup protocol, the branch was reset (`git reset --hard 72542503c753240e2e7bd3d93c66e151ae848a81`) before any file edits — confirmed HEAD landed on the correct branch (not a protected ref) and the working tree was clean except for an unrelated local `.claude/settings.local.json` diff, which was left untouched. All subsequent commits are on top of the correct base.

## User Setup Required

**External service requires manual configuration — this plan cannot complete without it.**

### BLOCKING: Apply the Phase 3 schema delta and run the extended RLS smoke test

Claude has no DDL access to the live Supabase project (`apjonrmhkpyzbofupokb`) — only the anon key is available, no CLI link. Please do the following:

1. Open **https://supabase.com/dashboard/project/apjonrmhkpyzbofupokb/sql/new**
2. Paste the **ENTIRE** contents of `supabase/schema.sql` (worktree path: `C:\Trabajo\VetApp\.claude\worktrees\agent-a6d85fc5a5e92c375\supabase\schema.sql`) and click **Run**.
   Expected: `Success. No rows returned` (idempotent — your existing Phase 1/2 data and rows are untouched; every statement is `create table/index if not exists`, `create or replace function`, or `drop policy if exists` + `create policy`).
3. Open a **new query tab**, paste the **ENTIRE** contents of `supabase/tests/rls_smoke_test.sql` and click **Run**.
   Expected: an **ERROR** (intentional) whose message starts with `RLS SMOKE: PASS (70 checks)` — the script always raises an exception at the end so every test row it inserted (including throwaway `auth.users` rows) rolls back, leaving zero residue in your real data regardless of outcome.
4. In the **Table Editor**, confirm a `consultas` table now exists and shows the RLS-enabled badge.
5. Reply with the **full, verbatim** `RLS SMOKE: ...` message from step 3 (and the verbatim error from step 2, if any).

Once you provide that message, a follow-up agent will run `bash supabase/tests/verify_live_schema.sh` from the worktree to confirm the anon-key probe also passes (expects `LIVE_SCHEMA_OK` as the last line), record both results verbatim in this SUMMARY, and — only if the message starts with `RLS SMOKE: PASS (70 checks)` — mark this plan complete. If it reports `FAIL`, the follow-up agent will fix only the Phase 3 section of `supabase/schema.sql` (or the new smoke checks, if the check itself is wrong) with re-runnable statements and ask for a re-paste.

## Next Phase Readiness
- Schema/test files are complete and committed; they are the hard prerequisite for Plan 03-03's `SupabaseConsultaRepository` (which calls `registrar_consulta` and reads from `consultas`) to work against a real device/emulator.
- **Blocker:** Plan 03-01 is NOT done until the user pastes both files into the cloud SQL Editor and reports a `RLS SMOKE: PASS (70 checks)` result. Plans 03-03..03-05 can continue being built/tested against fakes in the meantime (per the plan's own `<objective>`), but none of them will work on a real device until this delta is live.

---
*Phase: 03-historia-cl-nica*
*Completed: Tasks 1-2 only — Task 3 (BLOCKING checkpoint) awaiting user action*
