---
phase: 04-agenda-y-citas
plan: 01
status: partial-awaiting-checkpoint
subsystem: supabase-backend
tags: [supabase, rls, schema, citas]
requires: []
provides:
  - citas, cita_mascotas tables with RLS
  - crear_cita, actualizar_cita RPCs
  - registrar_consulta 11-arg (p_cita_id)
key-files:
  modified:
    - supabase/schema.sql
    - supabase/tests/rls_smoke_test.sql
    - supabase/tests/verify_live_schema.sh
    - README.md
requirements: [AGND-01, AGND-02, AGND-03, AGND-06]
---

# Phase 4 Plan 01: Agenda schema delta Summary (PARTIAL)

Fase 4 schema delta (citas + cita_mascotas bridge, atomic crear_cita/actualizar_cita, consultas.cita_id with one consulta per (cita, mascota)) written with a 95-check RLS smoke test; **awaiting the human apply step (Task 3), not yet verified live**.

## Status

- Task 1 (schema.sql delta): done, commit fc69a7c
- Task 2 (smoke test 95 checks + verify_live_schema.sh incl. embed probe): done, commit 54a1d38
- Task 3 (human applies schema.sql and runs smoke test in SQL Editor): **PENDING CHECKPOINT**

Static checks passed: SCHEMA4_OK greps, 95 `checks := checks + 1`, `bash -n` on the probe. Nothing has been run against the cloud DB. Do not treat RLS as passing until the user reports `RLS SMOKE: PASS (95 checks)`.

## Access matrix

| Role | citas / cita_mascotas select | insert | update | delete | crear/actualizar_cita |
|------|------|------|------|------|------|
| Vet, same clinic | yes | yes (veterinario_id = auth.uid()) | citas only | cita_mascotas only | yes |
| Vet, other clinic | no | no | no | no | rejected (FK violation) |
| CLIENTE | no | no | no | no | insufficient_privilege |
| anon | no | no | no | no | revoked |

## Deviations from Plan

- README.md got a short "Fase 4" section (expected check count) per vetapp-supabase guidance step 5; not in the plan's files_modified.
- `consultas` variable `v_consulta` already existed in the smoke test declare block; only the 5 other variables were added.

## Dart contract (errors to map)

42501 insufficient_privilege; 23503 'El cliente o la mascota no existe en tu clínica.' / 'La cita no existe en tu clínica.' / 'La mascota no pertenece a esta cita.'; 23514 'Elige al menos una mascota.' / 'Solo se pueden editar citas pendientes o confirmadas.' / 'No puedes quitar una mascota que ya tiene consulta registrada en esta cita.' / constraints citas_domicilio_requiere_direccion, citas_estado_check, citas_duracion_check; 23505 consultas_cita_mascota_key.

## Pending checkpoint

User must paste schema.sql, then rls_smoke_test.sql, in the SQL Editor of project apjonrmhkpyzbofupokb; then `bash supabase/tests/verify_live_schema.sh` must print `OK citas embed` and `LIVE_SCHEMA_OK`. Record the verbatim `RLS SMOKE:` message here once reported.

Smoke result: _pending_
