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

duration: ~10min (Tasks 1-2, plus checkpoint closed same session on user's live confirmation)
completed: 2026-09-28
---

# Phase 3 Plan 01: Historia Clínica — Schema Delta Summary

**Append-only `consultas` table + atomic `registrar_consulta` RPC (feeds `mascota_pesos` when a weight is given) applied live to the cloud project; extended 70-check RLS smoke test ran clean (`RLS SMOKE: PASS (70 checks) - cambios revertidos`).**

## Performance

- **Duration:** ~10 min (Tasks 1-2 authored/committed; Task 3 checkpoint closed on the user's verbatim confirmation)
- **Started:** 2026-09-25T21:57:09-05:00 (base commit `7254250`)
- **Completed:** Tasks 1-2 done 2026-09-25T22:01:42-05:00; Task 3 closed 2026-09-28 on user confirmation
- **Tasks:** 3 of 3 completed
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

**Task 3 (BLOCKING checkpoint):** closed via this commit (docs) — user ran both files in the Supabase Dashboard SQL Editor and confirmed the result below; no separate code commit needed for this task by design (manual verification step).

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

None further — the one external-service setup this plan required is complete.

**User applied both SQL files in the live cloud project (`apjonrmhkpyzbofupokb`) and confirmed, verbatim:**

```
RLS SMOKE: PASS (70 checks) - cambios revertidos
```

All 70 checks (53 from Phases 1-2 + 17 new: G1-G11 as vet A, H1-H4 as vet B, I1-I2 as the cliente-role account) passed on the live project as the `authenticated` role. The script's own rollback-by-design exception fired as expected, leaving zero residue in real data.

**Automated anon-probe verification (`bash supabase/tests/verify_live_schema.sh`) could not be executed from this sandboxed worktree agent** — no `SUPABASE_URL`/`SUPABASE_ANON_KEY` env vars or `dart_define.json` present, same limitation documented in Plan 02-01's SUMMARY. The checkpoint is closed on the user's manual SQL Editor confirmation instead, per the project's D-03 manual-verification convention. A future session with the project's `dart_define.json` present can run the script at any time for the `LIVE_SCHEMA_OK` double-check; it is a nice-to-have, not a gate.

## Next Phase Readiness
- Schema is live: `consultas` table + `registrar_consulta` RPC now exist in the cloud project, RLS-verified (70/70 checks as `authenticated`).
- Plan 03-03's `SupabaseConsultaRepository` (built against fakes) can now be exercised against a real device/emulator.
- No blockers remaining for Phase 3 Wave 1.

## Self-Check

- `supabase/schema.sql` contains the Phase 3 `consultas` section: FOUND
- `supabase/tests/rls_smoke_test.sql` contains G1-G11/H1-H4/I1-I2: FOUND
- Commit `8f6c62f` (Task 1): FOUND in `git log --oneline`
- Commit `665d6fc` (Task 2): FOUND in `git log --oneline`
- User's verbatim `RLS SMOKE: PASS (70 checks)` confirmation: RECORDED above

## Self-Check: PASSED

---
*Phase: 03-historia-cl-nica*
*Completed: 2026-09-28*
