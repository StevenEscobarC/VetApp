---
phase: 06-inventario
plan: 04
subsystem: database
tags: [supabase, live-apply, smoke-test, inventario]
requires:
  - phase: 06-inventario
    provides: "06-01 Fase 6 block in schema.sql + smoke block S (258 checks)"
provides:
  - "Fase 6 inventory schema live (productos, movimientos_inventario, 5 RPCs, RLS, guard on 9 tables)"
requirements-completed: []
completed: 2026-11-12
---

# Plan 06-04: Apply the Fase 6 delta live and run the 258-check smoke

**Complete: delta applied live, anon probe `LIVE_F6_OK`, and the user pasted the 258-check smoke: `RLS SMOKE: PASS (258 checks) - cambios revertidos`.**

## Task 1: pre-apply static review (2026-11-12)

- `PREAPPLY_F6_OK`.
- Delta range in `supabase/schema.sql`: lines 4176-4538 (`-- ===== Fase 6: Inventario (delta idempotente) =====` through `notify pgrst, 'reload schema';`).
- Every `create trigger` / `create policy` is preceded by `drop ... if exists`; tables, indexes and FKs use `if not exists` / `duplicate_object` guards; functions use `drop function if exists` + `create or replace`.
- `movimientos_inventario` is created before `es_autor_en_mi_clinica` is redefined.
- All 5 RPCs are `security definer set search_path = public` and start with the `es_veterinario()` / `mi_clinica_id()` check; `mover_stock` has `#variable_conflict use_column`, OUT names `movimiento_id` / `cantidad_nueva` and `for update`.
- Grants: execute revoked from `public, anon` and granted to `authenticated` with the exact signatures; table writes revoked from `authenticated`, everything revoked from `anon`; no write policy.
- Fixes: sin cambios.

## Task 2: live apply (2026-11-12)

- User authorization in chat: "Autorizo".
- First attempt: Supabase MCP `apply_migration fase_06_inventario` failed before running anything: `Failed to initialise history table: Connection terminated due to connection timeout`. A read-only `execute_sql` also timed out twice; the project reported `ACTIVE_HEALTHY` (Postgres 17.11) and the REST API answered (inventory RPCs still 404, so nothing was applied).
- Retry (user: "Reintenta el MCP"): a read-only check showed `productos` and `mover_stock` absent, then `apply_migration fase_06_inventario` returned `{"success":true}` with the Fase 6 block only.
- Read-only queries after the apply:
  - `select count(*) from public.productos` → 0
  - `select count(*) from public.movimientos_inventario` → 0
  - `guard_solo_lectura` triggers → 9 tables: cita_mascotas, citas, clientes, consultas, dosis_aplicadas, mascota_pesos, mascotas, movimientos_inventario, productos
- Smoke test pasted by the user (ENTIRE `supabase/tests/rls_smoke_test.sql`, first run, no fixes needed), literal line reported in chat on 2026-11-12:

```
RLS SMOKE: PASS (258 checks) - cambios revertidos
```

## Task 3: live anon probe (2026-11-12, after the apply)

`bash supabase/tests/verify_live_schema.sh` → last line `LIVE_SCHEMA_OK`, marker `LIVE_F6_OK`. Inventory lines:

```
OK productos protegida 401
OK movimientos_inventario protegida 401
OK rpc mover_stock protegido 401
OK rpc crear_producto protegido 401
OK rpc actualizar_producto protegido 401
OK rpc archivar_producto protegido 401
OK rpc inventario_resumen protegido 401
OK movimientos autor embed (anon sin privilegio 401; el hint de la FK resolvió, no hubo 400)
```

No key material recorded.
