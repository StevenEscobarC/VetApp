# Phase 1: Fundación - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-24
**Phase:** 1-Fundación
**Areas discussed:** Alcance del Walking Skeleton, Rigor de pruebas RLS, Registro de veterinarios

---

## Alcance del Walking Skeleton

| Option | Description | Selected |
|--------|-------------|----------|
| Dashboard real mínimo | El Inicio muestra datos reales de Supabase (nombre del veterinario, clínica) con el diseño ya aprobado | ✓ |
| Lista de pacientes vacía real | La pantalla de Pacientes conecta a Supabase de verdad, probando lectura end-to-end | |
| Solo el pipe técnico | Pantalla simple que prueba conexión+auth+ruta, sin aplicar el diseño visual todavía | |

**User's choice:** Dashboard real mínimo
**Notes:** El usuario quiere que se sienta como progreso real y visible — nombre/clínica reales sobre el diseño terracota/crema aprobado, no una pantalla de prueba técnica.

---

## Rigor de pruebas RLS

| Option | Description | Selected |
|--------|-------------|----------|
| Fix + smoke test manual | Corregir el bug y probar manualmente contra el rol authenticated | ✓ |
| Suite de pruebas automatizada | Pruebas SQL formales (positivas/negativas), más lento ahora, más confiable después | |

**User's choice:** Fix + smoke test manual
**Notes:** Prioridad explícita de avanzar rápido sobre cobertura exhaustiva en esta etapa temprana.

---

## Registro de veterinarios

| Option | Description | Selected |
|--------|-------------|----------|
| Dejarlo abierto por ahora | Uso personal/beta por ahora; se resuelve más adelante si el producto crece | ✓ |
| Agregar aprobación manual | Las cuentas VETERINARIO nuevas quedan pendientes hasta aprobación manual | |

**User's choice:** Dejarlo abierto por ahora
**Notes:** Ninguna adicional.

---

## Claude's Discretion

- Diseño exacto de columnas de la tabla `clientes` nueva (más allá de que exista y esté desacoplada de `perfiles` — eso ya estaba decidido en REQUIREMENTS.md/ROADMAP.md como FOUND-04).
- Estructura exacta de providers Riverpod y rutas go_router (seguir patrón de `.planning/research/ARCHITECTURE.md`).
- Orden exacto de tareas dentro de la fase.
- Mecánica exacta de limpieza del código muerto Firebase.

## Deferred Ideas

None — la discusión se mantuvo dentro del alcance de la fase.
