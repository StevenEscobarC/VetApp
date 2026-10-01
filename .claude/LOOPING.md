# Looping y agentes en VetApp

Guía práctica para combinar los agentes de `.claude/agents/` con `/loop` y GSD.

## Agentes del proyecto

| Agente | Rol | Edita | Cuándo |
|---|---|---|---|
| `vetapp-gate` | analyze + test + fix mínimo | Sí (Dart/tests) | Al cerrar cada plan, antes de commit, dentro de `/loop` |
| `vetapp-supabase` | schema.sql, RLS, RPCs, smoke test | Sí (SQL + README) | Fases con tablas nuevas (4 Agenda, 5 Vacunación, 6 Inventario, 7 Facturación, 9 Directorio) |
| `vetapp-brand-ui` | auditoría visual + formato Colombia | No | Después de pantallas nuevas; antes de `/gsd-verify-work` |
| `vetapp-qa` | UAT/pruebas manuales en emulador Android vía adb, reporte con evidencia | Solo el reporte QA + capturas | Después de `vetapp-gate` GREEN (y brand-ui), antes de `/gsd-verify-work` |
| `vetapp-opportunity-research` | ideas de mejora, innovación, usabilidad | No | Antes de `/gsd-discuss-phase`, o periódicamente para el backlog |
| `vetapp-negocio` | ventas, precios, monetización, go-to-market; mantiene `.planning/business/` sincronizado con lo nuevo | Solo `.planning/business/` | **Modo sync al cerrar cada fase** (después de `/gsd-verify-work`), y cuando se pregunte por negocio/precios |

Invocación directa en el chat: *"usa el agente vetapp-gate"* o `@vetapp-gate`.
Los agentes GSD (`gsd-planner`, `gsd-executor`, …) siguen siendo el motor de las fases; estos agentes
aportan el conocimiento específico de VetApp.

## Anatomía de un buen loop

1. **Una condición de parada verificable** (no "hasta que esté bien"): `GATE: GREEN`, `RLS SMOKE: PASS`, `QA: PASS`, "fase marcada [x]".
2. **Progreso medible por iteración**: si una vuelta no reduce fallos, el loop debe detenerse y escalar.
3. **Un tope**: número máximo de rondas o de tiempo.
4. **Estado fuera de la conversación**: `.planning/STATE.md`, SUMMARY.md, git, no la memoria del chat.
5. **El paso humano queda humano**: aplicar SQL en la nube y compras/despliegues no se automatizan. La UAT en emulador la cubre `vetapp-qa`; lo que necesita dispositivo físico (WhatsApp real, Doze) sigue siendo humano.

## Recetas

### 1. Gate hasta verde (ritmo libre)
```
/loop Usa el agente vetapp-gate. Si la última línea es GATE: GREEN, detén el loop. Si es BLOCKED, detén el loop y muéstrame la pregunta. Si es RED dos veces seguidas con el mismo número de fallos, detente y resume.
```
Sin intervalo, el modelo decide el ritmo y se detiene solo con `ScheduleWakeup stop`.

### 2. Fase completa con autonomía GSD
```
/gsd-autonomous
```
Recorre discuss → plan → execute por fase. Combínalo con: `vetapp-opportunity-research` antes de discuss
(insumo para decisiones), `vetapp-supabase` en los planes de esquema, `vetapp-gate` + `vetapp-brand-ui` + `vetapp-qa` antes de verify.
Se detiene en los checkpoints humanos (aplicar schema, UAT).

### 3. Vigilancia periódica (cosas externas que no avisan)
```
/loop 15m Revisa el estado del build/PR <x>; avísame solo si cambió.
```
Úsalo para CI, despliegues o un build largo. No para trabajo que el propio harness notifica.

### 4. Fan-out en paralelo (worktrees)
Para una fase con backend + UI independientes:
- `vetapp-supabase` (worktree A) → sección de schema + checks del smoke test.
- `gsd-executor` (worktree B) → slice de UI sobre fakes de `test/helpers/`.
- Al unir: `vetapp-gate` y luego `vetapp-brand-ui`.
Regla: dos agentes nunca editan el mismo archivo en paralelo (en especial `schema.sql`, `app_router.dart`, `STATE.md`).

### 5. Ideación periódica
```
/loop 1d Usa vetapp-opportunity-research sobre lo que cambió desde ayer (git log --since=1.day). Si hay ideas de impacto Alto, regístralas con /gsd-capture.
```
Para que corra con la app cerrada usa `/schedule` (agente en la nube) en vez de `/loop`.

### 6. QA loop (UAT en emulador)
```
/loop Usa vetapp-qa sobre la fase N. Si la última línea es QA: PASS, detén el loop. Si es BLOCKED, detén el loop y muéstrame qué necesita (login, dispositivo). Si es FAIL, lanza /gsd-debug con el caso fallido y su causa probable, luego vetapp-gate, y vuelve a correr vetapp-qa; máximo 3 vueltas.
```
Cierre de fase: `vetapp-gate` GREEN → `vetapp-brand-ui` → `vetapp-qa` PASS → `/gsd-verify-work`.
Los casos REQUIERE-DISPOSITIVO quedan en el HUMAN-UAT para el humano.

## Antipatrones

- Un loop que "arregla" tests debilitándolos → `vetapp-gate` lo tiene prohibido; revisa sus diffs igual.
- Loops sin tope que se comen el contexto: mejor iteraciones cortas con estado en archivos.
- Polling cada 60 s de trabajo que el harness ya notifica.
- Pedir a un agente de solo lectura (`brand-ui`, `opportunity-research`) que edite: encadena con el ejecutor.
- Pedir a `vetapp-qa` que arregle lo que encuentra: reporta; el arreglo va por `/gsd-debug` o `--gaps`.
