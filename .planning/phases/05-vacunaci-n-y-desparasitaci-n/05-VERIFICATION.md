---
phase: 05-vacunaci-n-y-desparasitaci-n
verified: 2026-10-03T00:00:00Z
status: human_needed
score: 5/5 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Tocar la notificacion de dosis proxima/vencida con la app abierta en /vacunas y cerrada"
    expected: "Abre /vacunas (Vacunas pendientes) sin pantalla roja"
    why_human: "QA r3 BLOCKED: el reloj del emulador impide programar un recordatorio cercano; no hay Android fisico (diferido a build iOS)"
  - test: "Envio real por WhatsApp del carne al dueno"
    expected: "Se abre WhatsApp con el mensaje y el enlace publico"
    why_human: "Integracion externa; diferido al build iOS"
  - test: "Sesion de veterinario NO admin abre Protocolos y Datos de la clinica"
    expected: "Vista solo lectura, sin acciones de edicion"
    why_human: "QA r1/r2 BLOCKED: no hay veterinario no admin activo en la clinica QA (la RLS ya esta cubierta por el smoke live 193 checks)"
---

# Phase 5: Vacunacion y Desparasitacion - Verification Report

**Goal:** El veterinario lleva el carne de vacunacion/desparasitacion con alertas automaticas y lo comparte sin exponer la historia clinica.
**Status:** human_needed (todo automatizable verificado; quedan 3 items no ejecutables en el entorno)

## Observable Truths

| # | Truth (ROADMAP SC) | Status | Evidence |
|---|---|---|---|
| 1 | Registrar vacuna/desparasitacion (biologico, fecha) | VERIFIED | RPC `registrar_dosis` (schema.sql:2440, inserta en `dosis_aplicadas`); `registrar_dosis_screen.dart`, repo `rpc(...)`; ruta en `vacunacion_routes.dart` montada en `app_router.dart`; QA r1-r3 registro real en emulador |
| 2 | Proxima dosis calculada automaticamente por protocolo, no editable | VERIFIED | Calculo en BD (`registrar_dosis` + `_carne_filas` fuente unica, protocolos con semillas); UI solo muestra `proxima_preview.dart`; QA G1 preview "Proxima 24/10/2026 Dosis 3 de 3"; nota menor r3: preview retroactivo (15/09) 06/10 vs guardado 23/10 (cosmetico, no bloqueante) |
| 3 | Alerta de dosis proxima o vencida | VERIFIED (parcial humano) | `vacunas_pendientes`, `vacunas_resumen`, `gestionar_alerta_vacuna`; `vacunas_pendientes_card.dart` en Inicio; QA: alerta Giardia vencida, Agendar PASS, G7 PASS. Toque de notificacion BLOCKED (humano) |
| 4 | Link publico solo lectura sin historia clinica | VERIFIED | `obtener_o_crear_enlace_carne` / `regenerar_enlace_carne` (schema.sql:2952/2995); Edge Function `carne` solo llama `rpc/carne_publico`, sin referencias a consultas/historia/diagnostico; `compartir_carne_sheet.dart`; REAL_TOKEN_OK |
| 5 | Dueno ve carne sin cuenta | VERIFIED | `public_carne/c/` (index.html, carne.js, carne_logica.js); aprobada por el usuario en iPhone Safari; QA F13 pagina publica con/sin logo |

**Score:** 5/5

## Verificaciones ejecutadas por el verificador
| Check | Resultado |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | 654 passed, all passed |
| `node --test test/web/carne_logica.test.mjs` | 9 pass / 0 fail |
| Marcadores TBD/FIXME/XXX en vaccination, functions/carne, public_carne | ninguno |

## Evidencia previa citada (no re-ejecutada)
RLS smoke live PASS (193 checks); `verify_live_schema.sh` LIVE_SCHEMA_OK con REQUIRE_CARNE_FN=1; REAL_TOKEN_OK con y sin logo; QA r3: G7, G8, Agendar PASS.

## Requirements Coverage
VAC-01 a VAC-05: SATISFIED (ver truths 1-5). Sin requisitos huerfanos. (REQUIREMENTS.md aun marca Pending; actualizar al cerrar fase.)

## Anti-Patterns
Ninguno bloqueante. Observacion menor: incoherencia de preview con fechas retroactivas cuando existen dosis posteriores.

## Human Verification Required
1. Toque de notificacion (abre /vacunas) - diurno o dispositivo real.
2. WhatsApp real al dueno - build iOS.
3. Vista solo lectura para veterinario no admin - requiere cuenta no admin.

## Gaps Summary
Sin gaps bloqueantes. Phase goal logrado en el codigo; 3 items de verificacion humana diferidos.

_Verifier: Claude (gsd-verifier)_
