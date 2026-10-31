---
phase: quick-261030-p7m
plan: 01
subsystem: project-skills
tags: [skill, linear, project-management, pm-vetapp]
requirements: []
key-files:
  created:
    - .claude/skills/pm-vetapp/SKILL.md
metrics:
  completed: 2026-10-30
  tasks: 2
  files: 1
---

# Quick 261030-p7m: Skill pm-vetapp (Project Manager con Linear) Summary

Skill de proyecto `pm-vetapp`: lee el estado GSD, lo refleja en Linear (team VetApp) con un issue por plan y un sub-issue `UAT` por cada paso humano, prioriza, delega lo técnico a `arquitecto-vetapp` / agentes `vetapp-*` dentro de comandos GSD y no deja cerrar un issue sin marcadores `<automated>`, `flutter analyze` + `flutter test` en verde y evidencia en `{NN}-VALIDATION.md`. Escribe en Linear solo con OK del usuario; por defecto trabaja en seco.

## Decisiones del usuario (2026-10-30)

- Issue por plan; los pasos humanos (checkpoint, pegar smoke, `user_setup`, aprobación) son sub-issues con label `UAT`.
- Las fases insertadas (04.1, 05.1) tienen proyecto propio en Linear (`Fase 5.1 · Planes y límites`).
- Sin labels de módulo: el proyecto es el módulo.

## Linear confirmado por MCP (2026-10-30)

- Team `VetApp` (key `VET`). Estados: Backlog, Todo, In Progress, In Review, Done, Canceled, Duplicate.
- Labels: Feature, Bug, UAT, Seguridad, Deuda técnica, Mejora, Idea diferida (+ `Improvement`, duplicado de Mejora, que la skill no usa).
- Proyectos: `Fase 1..9 · Nombre` y `Plataforma y Calidad`. No existen proyectos para 4.1 ni 5.1, ni issues `[05.1-xx]` (búsqueda con archivados incluidos).

## Verificación

- Tarea 1: `PM_SKILL_OK` (frontmatter, referencias a arquitecto/VALIDATION/estados, sin refs ni claves de Supabase).
- Compuertas estáticas del plan 05.1-06 re-ejecutadas en `1b4d04f` (solo lectura): `SMOKE_R_OK`, `PROBE_SYNTAX_OK`.

## Recorrido en seco sobre la fase 05.1 (nada escrito en Linear)

```
Fase activa: 05.1 · Planes y límites — 9/11 planes terminados (según GSD)
```

### Desfases GSD↔git↔Linear

1. `.planning/ROADMAP.md`: 05.1-03 sigue en `- [ ]` y "Plans: 8/11", aunque su SUMMARY y `05.1-VALIDATION.md` lo dan por verde (smoke 193 PASS pegado por el usuario, `LIVE_SCHEMA_OK`). Deberían ser `[x]` y 9/11.
2. `.planning/STATE.md`: "Plan: 1 of 11", `last_activity: 2026-10-09`, `stopped_at` de la fase 5: desactualizado.
3. `05.1-VALIDATION.md`: las filas 05.1-06-T1 y T2 siguen en ⬜, pero sus marcadores pasan (`SMOKE_R_OK`, `PROBE_SYNTAX_OK` en `1b4d04f`). Falta escribir la evidencia.
4. Linear `Fase 5 · Vacunación y Desparasitación` está "In Progress", pero la Fase 5 está `[x]` en ROADMAP (completada 2026-10-03).
5. Fuera del alcance de este recorrido: la Fase 4.1 (completada) tampoco tiene proyecto en Linear.

### Operaciones que haría en Linear

| # | Operación | Objeto | Detalle |
|---|-----------|--------|---------|
| 1 | crear proyecto | Fase 5.1 · Planes y límites | In Progress · Objetivo del ROADMAP (sin la referencia a `.planning/business/`) · Requisitos PLAN-01..06 · Fuente/Artefactos |
| 2 | crear issue | [05.1-01] Delta SQL: clinica_planes, _plan_efectivo, triggers LP001..LP004 | Done · Feature, Seguridad · comentario con `T1_OK`/`T2_OK`/`T3_OK` |
| 3 | crear issue | [05.1-02] Mi plan: contrato Dart, pantalla /mas/plan y fila en Más | Done · Feature · 110 pruebas ✅ |
| 4 | crear issue | [05.1-03] Aplicar el delta en vivo y correr los 193 checks | Done · Feature, Seguridad · `RLS SMOKE: PASS (193 checks)` + `LIVE_SCHEMA_OK` |
| 5 | crear issue | [05.1-04] Límite de 50 pacientes, hoja explicativa y candado | Done · Feature · 101 ✅ |
| 6 | crear issue | [05.1-05] WhatsApp de soporte y banner de Inicio | Done · Feature · 61 ✅ |
| 7 | crear issue | [05.1-07] Prueba Clínica 30 días y cupos en Equipo | Done · Feature · 69 ✅ |
| 8 | crear issue | [05.1-08] Logo y protocolos propios en Gratis | Done · Feature · 83 ✅ |
| 9 | crear issue | [05.1-09] Solo lectura de colegas: ficha, historia, carné, Inicio | Done · Feature · 134 ✅ |
| 10 | crear issue | [05.1-10] Solo lectura en agenda y tope desde el formulario de cita | Done · Feature · 150 ✅ |
| 11 | crear issue | [05.1-06] Smoke R1..R45 (238 checks) y sondas anon | In Review · Feature, Seguridad · High · blockedBy [05.1-03] · tareas T1 ✅ T2 ✅ T3 ⬜ |
| 12 | crear sub-issue | [05.1-06·T3] Pegar `supabase/tests/rls_smoke_test.sql` completo en el SQL Editor y correr `verify_live_schema.sh` | Todo · UAT · me · High · reportar la línea `RLS SMOKE: …` literal y `LIVE_SCHEMA_OK` |
| 13 | crear issue | [05.1-11] Cierre: gate, sonda, auditoría de marca/copy, UAT en emulador y aprobación | Todo · Feature · High · blockedBy [05.1-06], [05.1-06·T3] |
| 14 | crear sub-issue | [05.1-11·setup] Autorizar cambios de plan de las clínicas QA vía MCP y dar el número `SOPORTE_WHATSAPP` del build QA | Todo · UAT · me · High · bloquea la T2 de 05.1-11 |
| 15 | crear sub-issue | [05.1-11·T3] Visto bueno: copy sin dinero, número de soporte, clínica propia en Beta | Todo · UAT · me · Medium |
| 16 | comentar | [05.1-06] | Avance 2026-10-30 · `1b4d04f`: T1 ✅ `SMOKE_R_OK`, T2 ✅ `PROBE_SYNTAX_OK`; pendiente T3 (usuario) |
| 17 | proponer | proyecto Fase 5 · Vacunación y Desparasitación | In Progress → Completed (ROADMAP `[x]` 2026-10-03) |

Las operaciones 2–10 dan historial de planes ya terminados; se pueden omitir si solo se quiere seguir lo pendiente.

### Delegaciones que propondría

- **Evidencia de 05.1-06 T1/T2** → `/gsd-fast` (solo `.planning/`): marcar ✅ en el mapa por tarea y completar la fila de evidencia con los marcadores y el commit. De paso corrige los desfases 1 y 2 (ROADMAP 05.1-03 `[x]`, 9/11; STATE).
- **05.1-11 T1** (gate, sonda en vivo, escaneo de palabras de dinero, `vetapp-brand-ui`) → `/gsd-execute-phase 05.1` con `gsd-executor` siguiendo `arquitecto-vetapp`. Brief: archivos solo de `lib/features/plan/presentation/**` listados en el plan; criterios: sin palabras de dinero en `lib/features/plan` y `whatsapp_soporte.dart`, hallazgos bloqueantes de marca corregidos dentro de esos archivos, lo demás como gap; verificación: el `<automated>` literal hasta `PHASE51_GATE_OK` + `vetapp-gate` → `GATE: GREEN`; evidencia en `05.1-VALIDATION.md`. Requiere 06·T3 hecho (la sonda llama a la nube).
- **05.1-11 T2** → `vetapp-qa` (flujos F1..F10 en el emulador, A1 de punta a punta en F5) cuando T1 esté verde y el sub-issue de setup esté hecho; `QA_REPORT_OK`; un FAIL va a `/gsd-debug` o `/gsd-plan-phase 05.1 --gaps`.
- **Al cerrar la fase** → `/gsd-verify-work`, `vetapp-negocio` en modo sync y proyecto 5.1 → Completed.

### Pendiente del usuario (en orden)

1. Pegar el smoke de 238 checks en el SQL Editor y correr `bash supabase/tests/verify_live_schema.sh`; reportar ambas líneas literales.
2. Autorizar los cambios de plan de las clínicas QA vía MCP y dar el número de soporte para el build QA.
3. Visto bueno final de 05.1-11 T3 tras el reporte de QA.

## Deviations from Plan

Ninguna. La skill no modifica `LOOPING.md` ni la sección 12 de `arquitecto-vetapp`; mencionar ahí a `pm-vetapp` queda como posible seguimiento.
