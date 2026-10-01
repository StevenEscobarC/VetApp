---
phase: 04-agenda-y-citas
plan: 04
subsystem: clients/patients
tags: [telefono, whatsapp, agenda, go_router, tdd]
requires: []
provides:
  - "lib/core/utils/telefono_co.dart: normalizarTelefono, ClaseTelefono, requiereAvisoTelefono, numeroWhatsApp, kAvisoTelefono"
  - "NuevoClienteMascotaScreen(devolverResultado) returns (clienteId, mascotaId)"
  - "'Agendar cita' entry points to /agenda/nueva?clienteId=..&mascotaId=.."
affects: [04-05, 04-08]
tech-stack:
  added: []
  patterns: ["pure-Dart record-returning normalizer", "Focus.onFocusChange for blur-time soft validation"]
key-files:
  created:
    - lib/core/utils/telefono_co.dart
    - test/telefono_co_test.dart
  modified:
    - lib/features/clients/presentation/screens/nuevo_cliente_mascota_screen.dart
    - lib/features/clients/presentation/screens/cliente_detail_screen.dart
    - lib/features/patients/presentation/screens/mascota_detail_screen.dart
    - test/nuevo_cliente_mascota_screen_test.dart
    - test/cliente_detail_screen_test.dart
    - test/mascota_detail_screen_test.dart
decisions:
  - "Phones saved as 57XXXXXXXXXX (Colombian) or +digits (foreign); never blocks saving (D-16)"
  - "Soft warning rendered as a warning-colored Text under the field, not errorText"
  - "Fichas use context.go (cross-branch to Agenda shell), query built via Uri()"
metrics:
  tasks: 3
  completed: 2026-09-30
---

# Phase 4 Plan 04: Phone normalization and Agendar cita entry points Summary

Pure-Dart idempotent Colombian phone normalizer (D-16) wired into the combined alta and cliente ficha with a non-blocking soft warning, plus "Agendar cita" outline buttons on mascota/cliente fichas and a return-result mode on the combined alta for the new-cita flow.

## Tasks

| Task | Name | Commit |
| ---- | ---- | ------ |
| 1 | Colombian phone normalizer (TDD) | 6cd7fcf |
| 2 | Normalize + soft-warn phone; devolverResultado mode | 8594db5 |
| 3 | 'Agendar cita' on mascota and cliente fichas | 2ab1462 |

## Verification

`flutter analyze`: no issues. `flutter test`: 170 passed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Warning copy as shared constant**
- Added `kAvisoTelefono` to `telefono_co.dart` so both screens and tests share one string.
- Commit: 8594db5

**2. [Rule 1 - Bug] Dirty state after saving normalized phone (cliente ficha)**
- After saving, the phone controller is set to the normalized value, otherwise the form stayed "dirty" (text differed from the saved original).
- Commit: 8594db5

**3. Existing test expectations updated**
- Pre-existing assertions of raw phone values (`3001234567`, `3005550000`) changed to normalized values (`573001234567`, `573005550000`), a direct consequence of D-16.

TDD note: Task 1 tests and implementation were written together and committed as a single `feat` commit (no separate RED commit).

## Known Stubs

None.

## Threat Flags

None. T-04-15 mitigated (only digits and a leading `+` survive; unit-tested).

## Self-Check: PASSED

All created files exist; commits 6cd7fcf, 8594db5, 2ab1462 present.
