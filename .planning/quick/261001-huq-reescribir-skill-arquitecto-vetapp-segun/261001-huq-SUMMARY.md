---
phase: quick-261001-huq
plan: 01
subsystem: project-skills
tags: [skill, docs, arquitecto-vetapp, VET-24]
requirements: [VET-24]
key-files:
  modified:
    - .claude/skills/arquitecto-vetapp/SKILL.md
    - .claude/skills/arquitecto-vetapp/references/modelo-dominio.md
    - .claude/skills/arquitecto-vetapp/references/colombia.md
metrics:
  completed: 2026-10-01
  tasks: 3
  files: 3
---

# Quick 261001-huq: Reescribir skill arquitecto-vetapp Summary

Skill `arquitecto-vetapp` reescrita en español para describir el repo real (Riverpod a mano, go_router, excepciones `*Failure`, `schema.sql` + smoke test, fakes a mano), con Result/freezed/riverpod_generator/mocktail/migrations/use cases relegados a "Refactors candidatos".

## Commits

- `25be488` SKILL.md (stack, estructura, providers, routing, errores, backend, diseño, tests, flujo GSD, refactors candidatos)
- `d54dd37` references/modelo-dominio.md (8 tablas de schema.sql, invariantes [DB]/[App], sección Planeado)
- `5c9e643` references/colombia.md (helpers reales de lib/core/utils)

## Deviations from Plan

None en el alcance. Ajustes por verificación contra el código (el código manda):

- **COP**: el plan decía alinear con `formato.dart`, pero no existe ningún helper de moneda en `lib/` (no hay `NumberFormat`). colombia.md lo documenta como convención pendiente (Fase 7), no como helper existente.
- **Locale/intl**: la skill anterior mandaba `Intl.defaultLocale` + `initializeDateFormatting('es_CO')`; el código nunca lo llama (formatos escritos a mano). colombia.md lo refleja y advierte contra `DateFormat` localizado.
- **Teléfono**: la skill anterior decía E.164 `+573001234567`; el código guarda `573001234567` (sin `+`) para números colombianos y `+<dígitos>` solo para extranjeros.
- **Documento de identidad / tarjeta profesional**: no hay columnas en `clientes`/`clinicas`/`perfiles`; se marcaron opcional/futuro.
- **consultas.veterinario_id** es `on delete cascade` (no restrict, como `citas`); documentado tal cual.
- **mascotas.especie** es texto libre en BD (el enum `Especie` es solo App); documentado como [App].
- Frontmatter `name:` sin comillas para cumplir la verificación del plan.
- `.planning/codebase/*.md` y CLAUDE.md "Architecture" siguen desactualizados (dicen que Riverpod/go_router no se usan); no se tocaron (fuera de alcance), pero SKILL.md lo avisa.

## Known Stubs

None.

## Self-Check: PASSED

Los tres archivos existen y los commits `25be488`, `d54dd37`, `5c9e643` están en el historial. Las verificaciones automáticas del plan pasan (rutas citadas existen, descripción sin Bluetooth/IDEXX/Dog API, ideales solo en "Refactors candidatos"). No se llamó a Linear ni se commitearon artefactos de otros agentes.
