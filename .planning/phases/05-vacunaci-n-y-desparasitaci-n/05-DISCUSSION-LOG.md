# Phase 5: Vacunación y Desparasitación - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-10-01
**Phase:** 05-vacunacion-y-desparasitacion
**Areas discussed:** Protocolos y cálculo, Registrar una dosis, Alertas de próxima dosis, Link público del carné (+ Equipo de la clínica → derivado a Fase 4.1)

Nota: en paralelo se ejecutaron dos agentes en segundo plano: `vetapp-opportunity-research` (protocolos Colombia → `05-PROTOCOLOS-RESEARCH.md`) y `general-purpose` (diseño multi-veterinario → `.planning/research/MULTI-VET.md`), a pedido del usuario ("todo lo que puedas hacer en paralelo, hazlo").

---

## Protocolos y cálculo

| Pregunta | Opciones | Elegida |
|---|---|---|
| ¿Quién define los protocolos? | Catálogo base editable / Catálogo fijo / El vet crea todo | Catálogo base editable ✓ |
| Series cachorro/gatito | Serie automática / Solo intervalo simple | Serie automática ✓ |
| Duración distinta por producto | Chips de duración / Solo el protocolo | Chips de duración ✓ |
| Biológico "Otro" | Elegir intervalo / Sin próxima dosis | Elegir intervalo ✓ |

## Registrar una dosis

| Pregunta | Opciones | Elegida |
|---|---|---|
| Puntos de entrada (multi) | Pestaña Carné / Al completar cita / Dentro de consulta / Botón rápido global | Carné, completar cita, botón rápido global ✓ (no dentro de consulta) |
| Campos obligatorios | Biológico + fecha / + lote | Biológico + fecha ✓ |
| Dosis históricas/externas | Sí, marcada externa / Sí, sin distinción / No | Sí, marcada externa ✓ |
| Corrección | Anular con motivo / Editar libremente | Anular con motivo ✓ |

## Alertas de próxima dosis

| Pregunta | Opciones | Elegida |
|---|---|---|
| Dónde (multi) | Tarjeta Inicio / Lista pendientes / Notificación del celular / Badge en ficha | Tarjeta Inicio, lista, badge ✓ (sin notificación) |
| Ventana "Próxima" | 7 días / 15 días / Configurable | 7 días → luego cambiado a **por tipo** (14/3/5 días) tras el research |
| Acciones rápidas (multi) | WhatsApp / Agendar / Registrar dosis / Descartar | Las cuatro ✓ |
| Vencidas antiguas | Sí, con límite 6 meses / Siempre | Con límite ✓ |

## Link público del carné

| Pregunta | Opciones | Elegida |
|---|---|---|
| Contenido | Tipo certificado / Mínimo | Tipo certificado ✓ |
| Vigencia | Permanente + revocable / Vence en 30 días | Permanente + revocable ✓ |
| Compartir (multi) | WhatsApp / Nativo / PDF / QR | WhatsApp, nativo, PDF ✓ (sin QR) |

## Equipo de la clínica (pedido del usuario a mitad del discuss)

| Pregunta | Opciones | Elegida |
|---|---|---|
| Ubicación | Fase 4.1 antes de la 5 / Después de la 5 / Al final | Fase 4.1 ✓ |
| Unirse | Código de invitación / Código + aprobación / Por correo | Código de invitación ✓ |
| Roles | Admin + Vet / + Auxiliar / Todos iguales | Admin + Vet ✓ |
| Agenda | "Mías" con filtro / "Todas" por defecto | "Mías" con filtro ✓ |
| Retiro | Desactivar, conservar autoría / + reasignar obligatorio | Desactivar, conservar autoría ✓ |
| Asignación de cita | A mí con selector / Siempre quien crea | A mí con selector ✓ |
| Matrícula | Sí, opcional / No | Sí, opcional ✓ |
| Multi-clínica | No en v1 / Sí | No en v1 ✓ |

→ Capturado en `.planning/phases/04.1-equipo-de-la-cl-nica/04.1-CONTEXT.md`.

## Claude's Discretion

Schema y cálculo de la próxima dosis, mecanismo de la página pública, valores del catálogo base, sugerencia de "reiniciar serie", plantillas de WhatsApp, diseño visual (UI-SPEC).

## Deferred Ideas

Notificación diaria de pendientes, vacunas dentro de consulta, QR, vista "¿Puede ir a guardería?", recordatorio automático (DIFF-01), descuento de inventario (Fase 6/7), rol auxiliar y multi-clínica (v2).
