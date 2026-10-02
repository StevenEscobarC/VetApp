---
phase: 05-vacunaci-n-y-desparasitaci-n
plan: 01
subsystem: database
tags: [supabase, postgres, rls, plpgsql, vacunacion]
requires: []
provides:
  - Tablas protocolos_vacunacion, dosis_aplicadas, vacuna_alertas, carne_enlaces con RLS solo-lectura
  - _dosis_posiciones/_carne_filas como única derivación de próxima dosis
  - RPCs del contrato Fase 5 (catálogo, dosis, carné, alertas, enlaces) y carne_publico solo service_role
affects: [05-02, 05-04, 05-05, 05-12]
tech-stack:
  added: []
  patterns: [delta idempotente al final de schema.sql, escritura solo por RPC definer, derivación sin columnas almacenadas]
key-files:
  created: []
  modified: [supabase/schema.sql]
key-decisions:
  - "Dosis hipotética de previsualizar_dosis se ubica por fecha (igual que el insert real) para que posicion coincida con _carne_filas"
  - "Protocolo custom guardado desde 'otro:' queda con opciones_duracion_dias vacío (según contrato)"
requirements-completed: [VAC-01, VAC-02, VAC-03, VAC-04, VAC-05]
duration: 25min
completed: 2026-10-02
---

# Phase 5 Plan 01: Backend de vacunación y desparasitación Summary

Delta idempotente "Fase 5" al final de `supabase/schema.sql`: catálogo con 9 semillas colombianas, dosis solo-append, derivación única `_carne_filas`, 14 RPCs autenticadas y `carne_publico` ejecutable solo por service_role.

## Tasks

1. Tablas, RLS, semillas, `es_autor_en_mi_clinica` con dosis (D-09), `_dosis_posiciones` y `_carne_filas` - commit 9dbd9d2
2. RPCs (catálogo, registrar/anular/previsualizar dosis, carne_de_mascota, vacunas_pendientes/resumen/resumen_mascotas, gestionar_alerta_vacuna, enlaces, carne_publico) y grants - commit 4f4b504

## Deviations from Plan

None - plan ejecutado como estaba escrito. Se añadió además `revoke insert/update/delete/truncate ... from authenticated` sobre las cuatro tablas (defensa en profundidad; sin políticas de escritura ya quedaban bloqueadas por RLS).

## Verification

Los gates grep de ambas tareas pasan (CONTRATO_OK, 4 tablas, archivo termina en `notify pgrst`). No hay Postgres local: el SQL NO se ha ejecutado; la validación en vivo y el smoke test son el checkpoint del plan 05-04. Riesgo a vigilar en 05-04: sintaxis plpgsql de `previsualizar_dosis` y `guardar_protocolo` (ON CONFLICT con índice de expresión).

## Known Stubs

None.

## Threat Flags

None - superficie cubierta por el threat_model del plan (T-05-01..08).

## Self-Check: PASSED
