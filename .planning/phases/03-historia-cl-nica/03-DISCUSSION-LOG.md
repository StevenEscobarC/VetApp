# Phase 3: Historia Clínica - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-26
**Phase:** 3-Historia Clínica
**Areas discussed:** Corrección de entradas, Peso (consulta ↔ historial Fase 2), Campos obligatorios, PDF (alcance y destinatario), Alcance extra (adjuntos / próxima cita)

---

## Corrección de entradas (HIST-04)

| Option | Description | Selected |
|--------|-------------|----------|
| Sin vínculo formal | La nueva entrada simplemente se agrega a la línea de tiempo, más reciente arriba. Sin campo `corrige_a` ni UI extra. | ✓ |
| Referencia explícita a la consulta original | Campo `corrige_a` + UI para marcar qué consulta se corrige. | |

**User's choice:** Sin vínculo formal (recomendado).
**Notes:** Ninguna adicional — decisión rápida, primera opción confirmada.

---

## Peso: ¿consulta alimenta el historial de la Fase 2?

| Option | Description | Selected |
|--------|-------------|----------|
| Sí, alimenta el mismo historial | El peso de la consulta inserta en `mascota_pesos` (misma tabla append-only de Fase 2). | ✓ |
| Registros separados | El peso de la consulta queda solo dentro de `examenFisico.pesoKg`, sin tocar `mascota_pesos`. | |

**User's choice:** Sí, alimenta el mismo historial (recomendado).
**Notes:** El usuario fue explícito en que no quiere que el vet registre el mismo dato dos veces.

---

## Campos obligatorios al registrar (fricción cero)

| Option | Description | Selected |
|--------|-------------|----------|
| Solo diagnóstico + tratamiento | Mínimo absoluto; resto opcional al crear (no editable después por HIST-04). | ✓ |
| Todos obligatorios excepto evolución | Anamnesis, examen físico, diagnóstico y tratamiento obligatorios. | |

**User's choice:** Solo diagnóstico + tratamiento (recomendado).
**Notes:** Coherente con el principio de fricción cero ya registrado en PROJECT.md.

---

## PDF: alcance (HIST-03)

| Option | Description | Selected |
|--------|-------------|----------|
| Toda la historia del paciente | Un solo documento con todas las consultas en orden cronológico. | ✓ |
| Ambas: consulta individual y completa | Exportación por consulta además de la completa. | |

**User's choice:** Toda la historia del paciente (recomendado).

## PDF: destinatario

| Option | Description | Selected |
|--------|-------------|----------|
| Solo para el veterinario | Compartir/guardar vía mecanismo nativo del dispositivo, sin link público. | ✓ |
| Pensado también para el dueño | Lenguaje adaptado + posible link compartible. | |

**User's choice:** Solo para el veterinario (recomendado).
**Notes:** El dueño no tiene experiencia propia en la app hasta la Fase 9.

---

## Alcance extra: adjuntos / próxima cita

| Option | Description | Selected |
|--------|-------------|----------|
| Dejar ambos fuera | `adjuntoUrls` y `proximaCita` (ya en el entity scaffolding) quedan diferidos. | ✓ |
| Incluir adjuntoUrls ahora | Subir fotos/documentos por consulta esta fase. | |
| Incluir proximaCita ahora | Guardar fecha sugerida de próximo control esta fase. | |

**User's choice:** Dejar ambos fuera (recomendado).
**Notes:** `proximaCita` se descartaría/duplicaría cuando exista Agenda (Fase 4); `adjuntoUrls` es candidato a mejora futura, no bloqueante para HIST-01..04.

---

## Claude's Discretion

- Mecanismo exacto de la RPC atómica consulta+peso.
- Librería/enfoque de generación de PDF en Flutter.
- Diseño exacto de la UI de línea de tiempo.
- Estructura exacta de la tabla `consultas`/`examen_fisico` (columnas vs. JSONB).

## Deferred Ideas

- Adjuntos por consulta (fotos/documentos).
- "Próxima cita" con efecto real de agendamiento (Fase 4).
- PDF pensado para el dueño / compartible por link (candidato Fase 9+).
- Vínculo formal entre consulta correctiva y original.
