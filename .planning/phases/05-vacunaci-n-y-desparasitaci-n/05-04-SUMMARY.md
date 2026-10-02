---
phase: 05-vacunaci-n-y-desparasitaci-n
plan: 04
subsystem: database
tags: [supabase, rls, smoke-test, live-apply]
requires:
  - phase: 05-01
    provides: Fase 5 schema block
  - phase: 05-14
    provides: clinic logo schema section 16
provides:
  - Fase 5 delta (vacunación + logo de clínica) LIVE in production
  - rls_smoke_test.sql block Q1..Q48 (193 checks total) — PASS live
  - verify_live_schema.sh Fase 5 probes — LIVE_SCHEMA_OK
affects: [05-11, 05-13, 05-15, 05-16, 05-17]
key-files:
  modified:
    - supabase/tests/rls_smoke_test.sql
    - supabase/tests/verify_live_schema.sh
key-decisions:
  - "Live apply via Supabase MCP apply_migration `fase_05_vacunacion` with explicit user authorization (2026-10-02); only lines 1873–3284 of schema.sql (whole-line comments stripped, statements verbatim)"
  - "Smoke test pasted by the user in SQL Editor (MCP send blocked in 4.1)"
requirements-completed: [VAC-01, VAC-02, VAC-03, VAC-04, VAC-05]
completed: 2026-10-02
---

# Phase 5 Plan 04: Smoke Q-block + live apply — Summary

## Tasks
| # | Task | Commit |
|---|------|--------|
| 1 | Smoke block Q1..Q48 (vacunación, derivación, logo) | `e46914f` |
| 2 | Sondas anónimas Fase 5 en verify_live_schema.sh | `3e4e64b` |
| 3 | [BLOCKING] Aplicación en vivo + smoke | (sin commit de código) |

## Verificación en vivo
- `apply_migration fase_05_vacunacion` → `{"success":true}`.
- Solo lectura: 4 tablas nuevas, 9 protocolos semilla, `clinicas.logo_path`, bucket `clinica-logos` privado, `carne_publico` sin EXECUTE para anon ni authenticated; una sola versión de `actualizar_clinica(p_nombre, p_ciudad, p_direccion, p_telefono, p_logo_path)`.
- Smoke (pegado por el usuario): `RLS SMOKE: PASS (193 checks) - cambios revertidos` (un primer intento usó una copia antigua de 27 checks; repetido con el archivo actual).
- `bash supabase/tests/verify_live_schema.sh` → RPCs y tablas Fase 5 `protegido 401`, `OK dosis veterinario embed`, `OK clinica-logos privado`, `PENDIENTE carne edge function (no desplegada aún)`, `LIVE_SCHEMA_OK`.

## Deviations
- Ninguna sobre el SQL. No hubo FAIL; no se tocó schema.sql.

## Self-Check: PASSED
