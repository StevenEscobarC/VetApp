# Phase 4: Agenda y Citas - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-30
**Phase:** 04-agenda-y-citas
**Areas discussed:** Crear una cita, Vista y estados, Recordatorios, Completar → consulta

Insumo previo: informe de `vetapp-opportunity-research` con recomendaciones D1–D10.

---

## Crear una cita

| Pregunta | Opciones | Elegida |
|---|---|---|
| Duración | Según el motivo / Elegir duración siempre / Solo hora de inicio | Según el motivo ✓ |
| Domicilio | Casilla + dirección / Solo marcar / No modelarlo | Casilla + dirección ✓ |
| Varias mascotas | Sí, varias / Una por cita | Sí, varias ✓ |
| Cliente no registrado | Alta rápida en el flujo / Cita sin registrar / Exigir registro previo | Alta rápida ✓ |
| Obligatorios | Cliente, mascota, fecha y hora / También el motivo | Cliente, mascota, fecha y hora ✓ |
| Hora | Sugerir primer hueco libre / Reloj estándar / Lista de horas | Sugerir hueco libre ✓ |
| Entradas (multi) | Botón en Agenda / Desde ficha / Al guardar consulta | Botón en Agenda + Desde ficha ✓ |

---

## Vista y estados

| Pregunta | Opciones | Elegida |
|---|---|---|
| Vista | Tira de días + lista / Calendario de rejilla / Lista continua | Tira de días + lista ✓ |
| Cruces | Avisar sin bloquear / Bloquear / Ignorar | Avisar sin bloquear ✓ |
| Estados extra (multi) | No asistió / Solicitada (reservada Fase 9) | Ambos ✓ |
| Cambiar estado | Botones en la tarjeta / Botones + deslizar / Solo en detalle | Botones en la tarjeta ✓ |

---

## Recordatorios

| Pregunta | Opciones | Elegida |
|---|---|---|
| Aviso local | 1 h antes configurable / Noche anterior + 1 h / Por cita | 1 h antes configurable ✓ |
| Tono WhatsApp | Formal "usted" / Cercano "tú" / Editable por el vet | Formal "usted" ✓ |
| Masivo | Sí, en serie / Solo indicador por cita / Solo botón | Sí, en serie ✓ |
| Permiso notificaciones | Al crear primera cita / Al abrir la app | Al crear primera cita ✓ |

---

## Completar → consulta

| Pregunta | Opciones | Elegida |
|---|---|---|
| Completar | Ofrecer consulta (opcional) / Siempre exige / Solo marcar | Ofrecer, opcional ✓ |
| Varias mascotas | Una consulta por mascota / Solo la primera | Una por mascota ✓ |
| Precarga | Motivo en anamnesis / Nada | Motivo en anamnesis ✓ |
| Teléfono +57 | Normalizar al usar y al guardar / Solo al armar enlace | Al usar y al guardar ✓ |

---

## Claude's Discretion

Esquema/RLS exacto, vínculo cita→consulta, paquete y modo de notificaciones, zona horaria, motivos y duraciones, diseño visual (UI-SPEC).

## Deferred Ideas

- "Agendar control" al guardar consulta
- Cola offline de cambios de estado
- Plantilla WhatsApp editable
- Google Calendar, citas recurrentes
