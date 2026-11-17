---
phase: 08-dashboard-y-dise-o-visual
plan: 01
subsystem: supabase
tags: [rpc, rls, smoke, inicio, dashboard]
requires: [cobros_resumen, _hoy_bogota, es_veterinario, mi_clinica_id]
provides: [inicio_resumen() server contract, smoke T33..T40, anon probe]
affects: [08-03 (Dart repo on fakes), 08-04 (live apply), 08-06]
tech-stack:
  added: []
  patterns: [security definer stable RPC with clinic guard, Bogotá-month timestamptz bounds, copied cobros_resumen predicate with smoke parity]
key-files:
  created: []
  modified:
    - supabase/tests/rls_smoke_test.sql
    - supabase/schema.sql
    - supabase/tests/verify_live_schema.sh
decisions:
  - "inicio_resumen returns table (consultas_mes int, ingresos_mes bigint, pacientes_nuevos_mes int), names from UI-SPEC"
  - "Próximas citas stay out of the RPC (D-09); ingresos predicate copied, cobros_resumen untouched"
  - "T40 restores t_c to beta after the read-only state (same hygiene as T30)"
metrics:
  duration: ~20m
  completed: 2026-11-17
  tasks: 3
  files: 3
---

# Phase 8 Plan 01: inicio_resumen server contract Summary

One security-definer RPC, `public.inicio_resumen()`, returns the clinic's 3 month numbers for Inicio (consultas, ingresos cobrados, pacientes nuevos) using the Bogotá calendar month. Consultas are scoped through `mascotas.clinica_id`, and ingresos reuse the `cobros_resumen` predicate character for character. The contract is encoded as 8 smoke checks, T33..T40, and the smoke header total is now 301. The live anon probe also knows the new RPC.

## Tasks

| # | Task | Commit | Gate | Result |
|---|------|--------|------|--------|
| 1 | Smoke block T33..T40 + header total 301 (RED) | af684a6 | `SMOKE_F8_OK` | ✅ |
| 2 | Fase 8 delta in schema.sql: inicio_resumen() + grants (GREEN) | f568cf8 | `SCHEMA_F8_OK` | ✅ |
| 3 | verify_live_schema.sh probes inicio_resumen | 3646588 | `PROBE_F8_OK` | ✅ |

Evidence: the plan's three automated verifies were run from the worktree root, not `/c/Trabajo/VetApp`, because the plan is executed in an isolated worktree. They were run once after each task and again together at the end, and printed `SMOKE_F8_OK`, `SCHEMA_F8_OK` and `PROBE_F8_OK`. The schema gate includes `git diff --numstat e060feb -- supabase/schema.sql` = 0 deleted lines, so the change only adds lines. `bash -n` passes on the probe script.

Counts: `checks := checks + 1` = 301, one `Total esperado:` line (301). schema.sql 5649 -> 5691 lines, and `notify pgrst, 'reload schema';` is still the last line.

## TDD Gate Compliance

- RED: `test(08-01)` af684a6 comes before GREEN: `feat(08-01)` f568cf8.
- The RED phase is notional. There is no local psql or Docker stack, so the smoke cannot run before 08-04 applies the delta live. The evidence for Task 1 is the static gate. Before Task 2 the block would fail on every check, because `inicio_resumen()` did not exist: T33 reports "falta la RPC" and T34..T40 raise "function does not exist", which is caught as `Tn error inesperado`.
- The live proof (`RLS SMOKE: PASS (301 checks) - cambios revertidos`, `LIVE_SCHEMA_OK`) is deferred to 08-04, as the plan requires.

## Smoke block notes

- The fixtures are `i_*`: two new clinics, one of them empty. The block never touches vet_a/vet_b or `s_*`, and every return to postgres clears `request.jwt.claims`.
- `clientes.telefono` defaults to `''`, so the I client is inserted with `(clinica_id, nombre)` only and no phone is written. mascotas `created_at` is set on insert and re-set with an `update` as postgres, in case a trigger overrides it.
- T38 reads t_c with t_vet_admin and t_c_otro with t_vet_otro against counts that postgres computes. It also has a positive control (`i_n >= 1` from t_cons).
- T39 expects `sqlstate '42501'` for a CLIENTE (cliente_c_id), for t_vet_q (deactivated in T23) and for a JWT with no profile.
- T40 copies the T30 R30 update, then checks as t_vet_col that `puede_escribir()` is false, that the read succeeds and that `ingresos_mes = cobros_resumen().cobrado_mes`. Afterwards it restores `asignar_plan(t_c, 'beta')`.

## Deviations from Plan

None. The plan was executed as written. Two small additions stay inside the plan's intent:
- The T40 failure message adds `sqlstate: sqlerrm` after the prescribed text "T40 el colega en solo lectura no pudo leer el resumen".
- T40 restores the beta plan at the end, as T30 does. It is the last check, so this only keeps things tidy.

No live database was touched. No secrets, URLs, project refs or phone numbers were written.

## Known Stubs

None.

## Self-Check: PASSED

- supabase/schema.sql, supabase/tests/rls_smoke_test.sql, supabase/tests/verify_live_schema.sh modified: FOUND
- Commits af684a6, f568cf8, 3646588: FOUND
