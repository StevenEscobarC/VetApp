---
phase: 05-vacunaci-n-y-desparasitaci-n
plan: 13
subsystem: vaccination
tags: [qa, gate, validation, brand-ui, carne-publico]
requires:
  - phase: 05-01..05-17
    provides: schema, repositorio, pantallas, carné público, logo de la clínica
provides:
  - Gate de fase 5 verde (analyze, test, node, sonda en vivo)
  - QA en emulador r1/r2/r3 con gaps G4-G8 corregidos
  - 05-VALIDATION.md aprobado (nyquist_compliant)
key-files:
  created:
    - .planning/phases/05-vacunaci-n-y-desparasitaci-n/05-QA-REPORT.md
  modified:
    - .planning/phases/05-vacunaci-n-y-desparasitaci-n/05-VALIDATION.md
decisions:
  - "Sexo omitido en la página pública y el PDF del carné por decisión; documentado en UI-SPEC"
  - "Task 3 adaptada: el usuario solo tiene iPhone; verificación del carné público en Safari/iPhone"
requirements-completed: [VAC-01, VAC-02, VAC-03, VAC-04, VAC-05]
completed: 2026-10-03
---

# Phase 5 Plan 13: Gate, QA y cierre de validación Summary

La Fase 5 queda validada de punta a punta: gate verde, auditoría de marca aplicada, QA en emulador en tres rondas con todos los gaps encontrados corregidos, carné público verificado en iPhone y mapa de validación aprobado.

## Task 1: Gate, sonda en vivo, APK y auditoría brand-ui

- `flutter analyze` limpio; `flutter test` 654 OK; `node --test test/web/carne_logica.test.mjs` 9/9.
- En vivo: `RLS SMOKE: PASS (193 checks)` (pegado por el usuario); `REQUIRE_CARNE_FN=1 verify_live_schema.sh` -> `LIVE_SCHEMA_OK`.
- Token real: `REAL_TOKEN_OK` con y sin logo de la clínica (token ...bb47; logo con URL firmada accesible como image/jpeg; sin `logo_path`/`foto_path`; dueño "Cliente Q.").
- APK de debug generado para el QA.
- Auditoría vetapp-brand-ui: 1 grupo BLOQUEA y ~20 ADVIERTE corregidos (commits 315dc84, b2b5a74, 5b6fbc8, 99384b0, 947b262).
- Decisión: el sexo de la mascota se omite en la página pública y en el PDF; documentado en UI-SPEC.

## Task 2: QA en emulador

- r1: 10/13 PASS; fallaron G4, G5, G6. Correcciones: a8e726d, 5a31b24, 00e399f, 9bbd084, 3f50907, 596a2a8, e2dbc9f.
- r2: G4/G5/G6 PASS; aparecieron G7 y G8.
  - G7: "Compartir carné" del snackbar usaba un router tras el `await`; ahora usa el router capturado antes (82cc5c1).
  - G8: los carnés cargados no se refrescaban al guardar datos/logo de la clínica; ahora se invalidan (002c1e2).
- r3: G7, G8 y Agendar->guardar PASS (commit 93755ff con capturas y reporte).
- BLOCKED (no bloqueante): lectura de solo lectura para no-admin (no hay vet no-admin activo en la clínica QA); toque de notificación (reloj del emulador).
- PR #1 fusionado como 6d7b097; GitHub Pages republicado y verificado el CSS nuevo en vivo.

## Task 3: Verificación en dispositivo (adaptada)

El usuario solo tiene iPhone (sin Android). El carné público fue verificado por el usuario en Safari/iPhone ("se ve bien", 2026-10-03). Los chequeos de la app Android se reemplazan por evidencia de emulador. El comportamiento real de WhatsApp y notificaciones queda diferido al build iOS/TestFlight (fase final).

## Deviations from Plan

Task 3 adaptada por falta de dispositivo Android (arriba). Wave 0: `test/enlace_carne_sheet_test.dart` quedó cubierto por `test/compartir_carne_sheet_test.dart`.

## Known Follow-ups (menores)

- La previsualización de la próxima fecha ignora dosis posteriores ya existentes (QA r3: preview 06/10 vs carné 23/10).
- Pendientes de dispositivo/cuenta: toque de notificación y lectura no-admin.
- Intervalos en días fijos (3 años = 1095 días).

## Self-Check: PASSED
