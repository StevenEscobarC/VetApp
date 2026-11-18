---
phase: 08
plan: 04
status: complete
completed: 2026-11-17
---

# 08-04 — Live apply of `inicio_resumen()` (BLOCKING)

| Task | Result | Evidence |
|------|--------|----------|
| 1. Pre-apply static review | ✅ | `PREAPPLY_F8_OK`; delta = Fase 8 block of `supabase/schema.sql` (43 lines, from `-- ===== Fase 8: Inicio (delta idempotente) =====` to `notify pgrst`); sin cambios |
| 2. Live apply + smoke | ✅ | MCP `apply_migration fase_08_inicio` denied by the auto-mode classifier → fallback: user pasted the delta in the SQL Editor ("Success. No rows returned"). Read-only checks via MCP `execute_sql`: result type `TABLE(consultas_mes integer, ingresos_mes bigint, pacientes_nuevos_mes integer)`, anon execute `false`, authenticated `true`. Smoke pasted by the user: `RLS SMOKE: PASS (301 checks) - cambios revertidos` |
| 3. Live anon probe | ✅ | `OK rpc inicio_resumen protegido 401`, `OK rpc cobros_resumen protegido 401`, `LIVE_SCHEMA_OK` |

Notes: the first two smoke pastes ran before the delta was applied (10/301 failing, all T33..T40 with "function does not exist"); blocks A..T32 passed in both. No check was weakened.
