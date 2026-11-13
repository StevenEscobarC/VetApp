---
phase: 06-inventario
plan: 01
subsystem: database
tags: [supabase, postgres, rls, inventory, rpc]
requires: []
provides:
  - "Fase 6 server contract: productos, movimientos_inventario, crear_producto, actualizar_producto, archivar_producto, mover_stock, inventario_resumen"
affects: [06-02, 06-04]
key-files:
  modified:
    - supabase/schema.sql
    - supabase/tests/rls_smoke_test.sql
    - supabase/tests/verify_live_schema.sh
decisions:
  - "All 5 inventory RPCs are security definer with search_path = public (not invoker) so stock only changes via mover_stock"
metrics:
  completed: 2026-11-12
---

# Phase 6 Plan 01: Inventory server contract Summary

Idempotent Fase 6 schema block (tables, atomic stock ledger RPCs, select-only RLS, read-only guard, author visibility), smoke block S (20 checks, total 258) and anon live probes. Nothing applied to the live database (06-04 does that, gated on the user).

## Commits
- 23c1cec test(06-01): smoke block S (RED), R44 to 9 tables, header total 258
- 66a8a37 feat(06-01): Fase 6 inventory schema block
- f9ac974 test(06-01): anon probes for inventory tables, RPCs and author embed

## Markers
SMOKE_S_OK (258 `checks := checks + 1`, one "Total esperado: 258."), SCHEMA_F6_OK, PROBE_F6_OK. Not run against any database: expected live results `RLS SMOKE: PASS (258 checks)` and `LIVE_SCHEMA_OK` are pending 06-04.

## Contract for Dart (06-02)
- RPCs: `crear_producto(p_nombre, p_unidad, p_cantidad, p_minimo, p_categoria, p_vencimiento, p_precio_venta_cop, p_costo_cop) -> uuid`; `actualizar_producto(p_id, p_nombre, p_categoria, p_vencimiento, p_minimo, p_precio_venta_cop, p_costo_cop)`; `archivar_producto(p_id)`; `mover_stock(p_producto_id, p_delta, p_motivo, p_origen, p_ref_id, p_nota, p_deshace_id) -> (movimiento_id, cantidad_nueva)`; `inventario_resumen() -> (bajos, por_vencer, vencidos)`.
- Errors: IN001 stock insuficiente, IN002 producto no disponible, IN003 ajuste ya deshecho, 42501 (no admin / no vet), 23514 (input), 23505 (nombre duplicado), LP004 (solo lectura).
- Motivos allowed via mover_stock in this phase: compra, uso, vencido_danado, conteo, deshacer; origen only 'ajuste'.

## Deviations from Plan
None in behavior. Notes: the smoke block was authored without a database to run it (no live apply allowed), so SQL is statically reviewed only; the first real run is in 06-04. In archivar_producto the admin check precedes the IN002 lookup (non-admins never learn existence).

## Self-Check: PASSED
