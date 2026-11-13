---
phase: 07-facturaci-n
plan: 01
subsystem: database
tags: [supabase, postgres, rls, plpgsql, billing, smoke-test, tdd]
requires:
  - phase: 06-inventario
    provides: productos, movimientos_inventario (origen 'factura', motivo 'venta'/'deshacer', movimientos_deshace_uq), mover_stock, guard_solo_lectura, es_autor_en_mi_clinica (4 arms)
provides:
  - "Fase 7 block part A in supabase/schema.sql: clinica_servicios, cobros, cobro_items, cobro_contadores, clientes.cedula, clinicas.nit"
  - "Private helpers _numero_cobro, _aplicar_movimiento_stock, _total_items_cobro, _insertar_items_cobro (no grant to anyone)"
  - "RPCs crear_cuenta_cobro, crear_cotizacion, marcar_cobro_pagado, anular_cobro (security definer, authenticated only)"
  - "Smoke block T1..T23, R44 at 13 guarded tables, header 'Total esperado: 284.'"
affects: [07-02, 07-04, 07-08]
tech-stack:
  added: []
  patterns:
    - "Gapless per-clinic numbering with a counter table upserted inside the same sub-block as header/items/stock"
    - "Idempotency key: early lookup + unique_violation fallback that reads constraint_name via get stacked diagnostics"
    - "Private definer stock helper (origen 'factura') instead of widening mover_stock"
    - "Void reverses the movement ledger (not the items) with deshace_id"
key-files:
  created:
    - .planning/phases/07-facturaci-n/07-01-SUMMARY.md
  modified:
    - supabase/schema.sql
    - supabase/tests/rls_smoke_test.sql
key-decisions:
  - "mover_stock stays byte-for-byte unchanged (verified against 7cbaa03); billing uses _aplicar_movimiento_stock"
  - "An idempotency key that already belongs to the other document type raises check_violation instead of returning the wrong document"
  - "A non-null producto_id on a non-producto line (or servicio_id on a non-servicio line) is check_violation, matching the cobro_items check"
  - "Smoke setup generates one invitation code per colleague, because codes are single use"
  - "T15 asserts the first quote is COT numero 1 (own counter while CCs are at 2); T19's quote is therefore numero 2"
patterns-established:
  - "Billing error codes: IN001/IN002 with json detail, BC001 (not found / invalid state), BC002 (quote not open), BC003 (visit already charged, detail {numero})"
requirements-completed: []
duration: 25min
completed: 2026-11-13
---

# Phase 7 Plan 01: Billing server contract, part A — Summary

**Server-side billing contract in Postgres: gapless per-clinic CC/COT numbering through a counter table, idempotent issue via clave_idempotencia, atomic stock deduction and ledger reversal through a private definer helper (mover_stock untouched), pay and void RPCs. Proven by smoke block T1..T23 (284 checks total).**

## Performance

- **Started:** 2026-11-13T21:10Z (approx., after reset to 7cbaa03)
- **Completed:** 2026-11-13T21:33Z
- **Tasks:** 3/3 (plus 1 fix commit to the smoke)
- **Files modified:** 2 (`supabase/schema.sql` 4547 -> 5329 lines, `supabase/tests/rls_smoke_test.sql` 5093 -> 6120 lines)

## Evidence per task

Plan gates were run from this worktree (the plan's `cd /c/Trabajo/VetApp` would point at the main checkout, so the identical marker scripts were run with the worktree as their working directory).

| Task | Result | Literal evidence |
|------|--------|------------------|
| 1 — smoke block T, R44, header (RED) | ✅ | `SMOKE_T_A_OK`; RED against the 7cbaa03 schema on a local throwaway container: `RLS SMOKE: FAIL (63 de 284 checks)` |
| 2 — tables, columns, RLS, private helpers | ✅ | `SCHEMA_F7A_TABLAS_OK`; schema applied twice in a row with no error (re-runnable) |
| 3 — RPCs, guards, authorship, grants | ✅ | `SCHEMA_F7A_OK`; GREEN on the local throwaway container: `RLS SMOKE: PASS (284 checks) - cambios revertidos` |
| mover_stock unchanged | ✅ | Body extracted from 7cbaa03 vs HEAD: `mover_stock identical: True definitions base/now: 1 1` |
| Flutter (no Dart touched) | ✅ | `No issues found! (ran in 11.8s)`; `00:41 +1045: All tests passed!` |

How the smoke was executed (local only, never live): a throwaway `public.ecr.aws/supabase/postgres:17.11.0.011` container (`vetapp-0701-scratch`, port 55432, removed afterwards). It needed two local-only shims: a stub `storage` schema (buckets/objects/foldername), because the storage-api container normally creates it, and the current `auth.uid()` definition that reads `request.jwt.claims`. With those shims the 7cbaa03 baseline reproduced `RLS SMOKE: PASS (261 checks)`, so the harness matches the live behavior the smoke was written for. A mutation run (wrong `_numero_cobro` for ≥10000 and no guard on `cobro_contadores`) gave `RLS SMOKE: FAIL (2 de 284 checks)` (T3 + R44), so the new checks catch regressions. The authoritative live run is still 07-08 (after part B, expected 291).

## Accomplishments

- `cobros` / `cobro_items` / `cobro_contadores` / `clinica_servicios` with the named constraints, partial unique indexes and composite FK from the contract; `clientes.cedula` and `clinicas.nit` with format checks
- Select-only RLS (`es_veterinario() and clinica_id = mi_clinica_id()`); no policy and no SELECT on `cobro_contadores`; writes revoked from authenticated and everything from anon
- `crear_cuenta_cobro`: idempotency lookup first, tenant re-check of cliente/consulta/mascota/cita, BC003 for a visit already charged, quote lock (BC001/BC002), server total in bigint, then counter + header + items + stock + conversion in one sub-block (IN001 leaves no number burned)
- `crear_cotizacion` (no stock, `valida_hasta = fecha + 15`, archived/foreign products still IN002), `marcar_cobro_pagado` (idempotent, date between issue and today), `anular_cobro` (admin or issuer, reverses the ledger with `deshacer` + `deshace_id`, works on archived products, keeps number and payment data)
- `guard_solo_lectura` on the 4 tables (13 total, LP004 under the definer RPCs); `es_autor_en_mi_clinica` keeps its 4 arms and adds cobros and clinica_servicios

## Task Commits

1. **Task 1: smoke block T1..T23, R44, header (RED)** — `98bb250` (test)
2. **Task 2: tables, columns, RLS, private helpers** — `ed6b4d6` (feat)
3. **Task 3: RPCs, guard triggers, authorship, grants** — `d22bfa4` (feat)
4. **Smoke fix found while going GREEN** — `48a2733` (fix)

## Decisions Made

See `key-decisions` in the frontmatter. All follow the plan's contract; the two schema-side ones (wrong-type clave, ids on the wrong line type) only tighten validation.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Invitation codes are single use**
- **Found during:** Task 1 (setup T)
- **Issue:** The plan asks for one `generar_invitacion_clinica()` code for three colleagues. Codes are single use and a new code revokes the previous unused one, so the 2nd and 3rd signups would fail.
- **Fix:** The setup generates a fresh code before each colleague signup.
- **Files modified:** supabase/tests/rls_smoke_test.sql
- **Commit:** 98bb250

**2. [Rule 1 - Bug] T19 quote number conflicted with T15**
- **Found during:** Task 1
- **Issue:** T15 must create a quote (to prove a quote cannot be paid) before T19, so T19's quote cannot be numero 1.
- **Fix:** T15 asserts its quote is COT numero 1 (own counter while CCs are at 2); T19 asserts numero 2. The "own counter" intent is kept.
- **Commit:** 98bb250

**3. [Rule 1 - Bug] Failure messages raised "malformed array literal"**
- **Found during:** going GREEN (local run after Task 2)
- **Issue:** `failures := failures || 'plain literal'` resolves the untyped literal as `text[]` and errors on the failure path, hiding the real failure.
- **Fix:** In block T, the 33 plain-literal messages are cast with `::text`.
- **Commit:** 48a2733

**4. [Rule 3 - Blocking] Extra smoke variables**
- `t_s_otro`, `t_cita2`, `t_cobro3`, `t_cot2`, `t_cot3`, `t_cc_cita`, `t_cc_cons`, `t_clave`, `t_clave2`, `t_n3`, `t_n4`, `t_t`, `t_p` were added to the `-- Fase 7 (bloque T)` declarations; the foreign service and the other-client cita are created in setup instead of inside T10.

**Total deviations:** 4 auto-fixed. **Impact:** none on the contract; the counts stay at 23 checks / 284 total.

## Deferred Issues

- The same `failures || 'plain literal'` pattern exists 249 times in the older blocks (A..S). It only matters if one of those checks fails, so it is out of scope here; logged for a later cleanup.

## Issues Encountered

None beyond the deviations above.

## Known Stubs

None.

## Threat Flags

None. All new surface (4 tables, 4 RPCs, 4 private helpers) is covered by T-07-01..T-07-10 in the plan.

## User Setup Required

None. Nothing was applied to the live database; 07-08 applies part A + part B after the user's OK.

## Next Phase Readiness

- 07-02 can code Dart against the exact RPC names, signatures, return shape `(id, numero, ya_existia)` and the error codes.
- 07-04 adds part B; its smoke additions must keep the total consistent (expected 291).
- STATE.md / ROADMAP.md / REQUIREMENTS.md were not touched from this parallel worktree; the orchestrator records the wave.

## Self-Check: PASSED

- FOUND: supabase/schema.sql (Fase 7 block present, last line `notify pgrst, 'reload schema';`)
- FOUND: supabase/tests/rls_smoke_test.sql (284 `checks := checks + 1`)
- FOUND commits: 98bb250, ed6b4d6, d22bfa4, 48a2733
