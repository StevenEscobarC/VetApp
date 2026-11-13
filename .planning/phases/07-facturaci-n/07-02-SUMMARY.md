---
phase: 07-facturaci-n
plan: 02
subsystem: billing (Dart contract)
tags: [billing, cobros, riverpod, tdd, supabase-rpc]
requires:
  - inventory esErrorDeRed / invalidarInventario / Unidad.etiqueta
  - core limitePlanDe / ConLimitePlan
  - vaccination fechaDeBd / fechaABd
provides:
  - Billing domain (Cobro, CobroItem, LineaCobroNueva, TipoCobro, EstadoCobro, MetodoPago, TipoLinea, ResumenCobros, CobroVinculado, ClinicaCobroPdf, ResultadoCobro, Servicio)
  - CobroFailure + ErrorCobro
  - SupabaseCobrosRepository + cobroDesdeFila + servicioDesdeFila + cobroFailureDe + mensajeErrorCobro + lineaAJson + kSelectCobro
  - cobros_providers (repository, reads, permission flags, invalidarCobros, CobrosActions)
  - cobros_rutas (path builders)
  - test/helpers/fake_cobros.dart (FakeCobrosRepository, cobroDePrueba, servicioDePrueba, clinicaPdfDePrueba)
affects:
  - lib/features/inventory/data/repositories/supabase_inventario_repository.dart (esErrorDeRed no longer @visibleForTesting)
tech-stack:
  added: []
  patterns:
    - "invalidate-in-finally on every mutation outcome (WR-03)"
    - "single translation point for PostgrestException -> CobroFailure, payload parsed from detail json"
key-files:
  created:
    - lib/features/billing/domain/entities/cobro.dart
    - lib/features/billing/domain/entities/cobro_item.dart
    - lib/features/billing/domain/entities/servicio.dart
    - lib/features/billing/domain/numeracion.dart
    - lib/features/billing/domain/cobro_failure.dart
    - lib/features/billing/data/repositories/supabase_cobros_repository.dart
    - lib/features/billing/presentation/providers/cobros_providers.dart
    - lib/features/billing/presentation/cobros_rutas.dart
    - test/helpers/fake_cobros.dart
    - test/cobro_test.dart
    - test/supabase_cobros_repository_test.dart
    - test/cobros_invalidacion_test.dart
  modified:
    - lib/features/inventory/data/repositories/supabase_inventario_repository.dart
  deleted:
    - lib/features/billing/domain/entities/factura.dart
decisions:
  - "esErrorDeRed lost @visibleForTesting so billing reuses it (import show esErrorDeRed) instead of duplicating it"
  - "cobroDesdeFila accepts both PostgREST embeds (autor/anulador/convertida/origen) and the flat cobro_para_pdf keys (autor_nombre, anulada_por_nombre, convertida_en_numero, cotizacion_origen_numero)"
  - "CobrosActions.anular also refreshes the origin quote detail (otroCobroId = cotizacionOrigenId)"
  - "guardarServicio/archivarServicio invalidate serviciosProvider plus invalidarCobros(ref)"
metrics:
  duration: "~35 min"
  completed: 2026-11-13
  tasks: 3
  files: 14
---

# Phase 7 Plan 02: Billing Dart contract summary

The Dart billing contract was built test-first:
- **Domain:** integer-COP domain whose line descriptions and prices are copies, with 'CC-0012' / 'COT-0004' numbering that mirrors `_numero_cobro`.
- **Repository:** an RPC-only Supabase repository. Every server or network error becomes a typed Spanish `CobroFailure`.
- **Providers:** hand-written Riverpod providers with `CobrosActions`. Each action refreshes billing and inventory in a `finally` block, whether the call succeeds or fails.
- **Routes and fake:** route path builders and a stateful `FakeCobrosRepository`.

## Evidence per task

The `<automated>` commands were run from the worktree root instead of `/c/Trabajo/VetApp`. The plan's `cd` points at the main checkout, and this plan ran in an isolated worktree. Everything else in the commands ran exactly as written.

| Task | Gate | Result | Tests |
|------|------|--------|-------|
| 1 Domain | `DOMINIO_COBRO_OK` | ✅ printed | cobro_test `+14: All tests passed!` |
| 2 Repository | `REPO_COBROS_OK` | ✅ printed | supabase_cobros_repository_test `+29: All tests passed!` |
| 3 Providers/rutas/fake | `CONTRATO_COBROS_OK` | ✅ printed | cobros_invalidacion_test `+19: All tests passed!`; full suite `+1107: All tests passed!` |

Extra Task 1 acceptance check: `grep -rn "supabase_flutter\|package:flutter/" lib/features/billing/domain` returned nothing.

Literal gate lines from the final Task 3 run:
```
No issues found! (ran in 8.8s)
+19: All tests passed!
+1107: All tests passed!
CONTRATO_COBROS_OK
```

Test count: the pre-plan baseline at 7cbaa03 was `+1045: All tests passed!`. Afterwards it is 1107, which is 1045 + 14 + 29 + 19.

TDD gates: each task has a RED `test(07-02)` commit followed by a GREEN `feat(07-02)` commit. Each RED run failed at compile time on the missing symbols. No refactor commits were needed.

## Commits

| Hash | Message |
|------|---------|
| 4c9e785 | test(07-02): add failing test for billing domain (Cobro, numeración, CobroFailure) |
| d34c5fc | feat(07-02): billing domain Cobro, CobroItem, enums, numeración, Servicio, CobroFailure |
| f55f65c | test(07-02): add failing test for SupabaseCobrosRepository |
| 6945198 | feat(07-02): SupabaseCobrosRepository with RPC params, row mapping and error translation |
| c2d4900 | test(07-02): add failing invalidation/route test and FakeCobrosRepository |
| bf29baf | feat(07-02): billing providers, CobrosActions with always-invalidate, route builders |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `esErrorDeRed` was `@visibleForTesting`**
- **Found during:** Task 2
- **Issue:** The plan says to import `esErrorDeRed` with `show esErrorDeRed` and not duplicate it. But the function is annotated `@visibleForTesting`, so `flutter analyze` reported `invalid_use_of_visible_for_testing_member` twice.
- **Fix:** Removed the annotation and noted in the doc comment that the inventory and billing repositories share the helper. Behavior is unchanged; `supabase_inventario_repository_test` still passes (+22).
- **Files modified:** lib/features/inventory/data/repositories/supabase_inventario_repository.dart
- **Commit:** 6945198

**2. [Rule 3 - Blocking] Gate grep vs `dart format`**
- **Found during:** Task 2
- **Issue:** `dart format` split `rpc(` and `'crear_cuenta_cobro'` onto separate lines, so `grep -q "rpc('crear_cuenta_cobro'"` failed.
- **Fix:** Build the params into a local variable first, so the call `_client.rpc('crear_cuenta_cobro', params: p)` fits on one line.
- **Commit:** 6945198

### Contract additions (non-breaking)
- `CobroFailure` for BC003 without a `numero` in its detail falls back to 'Esta visita ya tiene una cuenta de cobro.'
- `FakeCobrosRepository.guardados` is a read-only view for tests. It is extra and not part of the repository interface.
- `cobroDePrueba` takes more optional parameters than the plan lists. The plan's list ended in `...`, and the defaults match the plan.

## Not done here (by instruction)
- `07-VALIDATION.md` not edited; the orchestrator copies the evidence above.
- `supabase/` and `lib/core/utils/formato.dart` not touched.
- STATE.md, ROADMAP.md and REQUIREMENTS.md not updated from this worktree. Plans 07-01 and 07-03 run in parallel, so the orchestrator updates them once per wave.

## Known Stubs
None.

## Threat Flags
None. No new surface beyond the plan's threat model. T-07-11, T-07-12 and T-07-13 are covered by the tests above, and the repository never logs anything (T-07-15).

## Self-Check: PASSED
- All 12 created files exist, and factura.dart is gone.
- All 6 commits are present in `git log 7cbaa03..HEAD`.
