---
phase: 07-facturaci-n
plan: 13
subsystem: appointments / billing entry points
tags: [billing, appointments, tdd, read-only, D-05, D-19, D-20]
requires: ["07-05 CobrarBoton + CobroVinculadoFila", "07-02 rutaNuevoCobro + FakeCobrosRepository", "07-07 /cobros/nuevo route"]
provides: ["'Finalizar y cobrar' on CompletarCitaScreen", "'Cobrar' / 'Cobrada: CC-0012' on the completed cita detail"]
affects: [completar_cita_screen.dart, cita_detail_screen.dart]
tech-stack:
  added: []
  patterns: ["CobroVinculadoFila(siNoHay: ...) wraps every charge entry point", "ControlEscritura + asegurarEscritura lock only the charge"]
key-files:
  created: []
  modified:
    - lib/features/appointments/presentation/screens/completar_cita_screen.dart
    - lib/features/appointments/presentation/screens/cita_detail_screen.dart
    - test/completar_cita_screen_test.dart
    - test/cita_detail_screen_test.dart
    - test/cita_solo_lectura_test.dart
    - test/whatsapp_acciones_test.dart
decisions:
  - "The cita's pet is prefilled only when the cita has exactly one pet (plan's recorded choice over UI-SPEC §1 'first pet')"
  - "'Finalizar y cobrar' checks asegurarEscritura BEFORE completing: in read-only it neither completes nor navigates; 'Finalizar cita' is untouched"
  - "On an already-completed cita without a CC, 'Finalizar y cobrar' pushes the CC form directly (no second completion)"
requirements: [BILL-01, BILL-02]
metrics:
  completed: 2026-11-14
  tasks: 2
  files: 6
---

# Phase 7 Plan 13: Charge from the appointment Summary

The vet can charge a visit where it ends. "Finalizar y cobrar" completes the cita through the same path as before ("Cita completada" + Deshacer) and then pushes `rutaNuevoCobro(clienteId, citaId, mascotaId if single pet)`. A completed cita's detail shows "Cobrar", or "Cobrada: CC-0012" + state chip once a non-voided CC is linked.

## What was built

- **CompletarCitaScreen:**
  - `_Boton.cobrar` and `_finalizar(..., {bool cobrar})`: on success it calls `context.push(rutaNuevoCobro(...))` instead of `context.go(agenda)`. If completion fails, it does not navigate. If the cita is already completed, it pushes the form directly.
  - Outline "Finalizar y cobrar" (`Icons.receipt_long_outlined`) sits 8px below "Finalizar cita" and is disabled under the same rule (`hayPendientes || _finalizando != null`).
  - The button is wrapped in `ControlEscritura` + `asegurarEscritura`, so the padlock and LimitePlanSheet apply only to the charge. It is also wrapped in `CobroVinculadoFila(citaId: cita.id)`.
- **CitaDetailScreen** (`EstadoCita.completada`): `CobroVinculadoFila(citaId: cita.id, siNoHay: CobrarBoton(ruta: rutaNuevoCobro(...)))` + `gap`, placed before "Ver historia clínica". Other states are unchanged.

## Per-task evidence

| Task | RED commit | GREEN commit | Gate | Result |
|------|-----------|--------------|------|--------|
| 1 Finalizar y cobrar | 73d1fee (8 new tests failing, 12 existing passing) | 8fdd921 | `FINALIZAR_COBRAR_OK` | ✅ |
| 2 Cobrar / Cobrada on detail | c4344b4 (7 new tests failing, existing passing) | 03ef38e | `SLICE_CITA_COBRAR_OK` | ✅ |

Task 1 `<automated>` (run from worktree root):
```
No issues found! (ran in 10.6s)
00:02 +20: All tests passed!
FINALIZAR_COBRAR_OK
```

Task 2 `<automated>` (run from worktree root, includes full suite):
```
No issues found! (ran in 18.1s)
00:06 +74: All tests passed!
00:44 +1349: All tests passed!
SLICE_CITA_COBRAR_OK
```

- `! grep -rni "factur" lib/features/appointments` passed (no "factura" wording).
- Acceptance: `git diff` of all 4 test files against the base shows **only additions**, with 0 removed lines. These additions are the cobros override, the `/cobros/nuevo` and `/cobros/:id` stub routes, plan/auth overrides in the completar harness, the new `_abrirCon` / `_abrirConCobros` helpers and the new cases.

New cases:
- **completar_cita_screen_test:**
  - placement and variant and icon, 8px gap, and the same disable rule;
  - completes with snackbar + Deshacer, then the CC route with the single pet;
  - several pets give no `mascotaId`;
  - a failed completion does not navigate;
  - an already-completed cita pushes without re-completing;
  - a linked CC shows "Cobrada: CC-0012" + "Pagada" and its tap opens the detail;
  - a billing error falls back to the button;
  - read-only: padlock + semantics, LimitePlanSheet, no completion or navigation, and "Finalizar cita" stays unlocked.
- **cita_detail_screen_test:**
  - "Cobrar" outline before "Ver historia clínica", with the route;
  - several pets give no `mascotaId`;
  - "Cobrada: CC-0012" + "Pagada" opens `/cobros/cc-12`;
  - a voided CC brings "Cobrar" back;
  - a billing error shows "Cobrar" with no error text;
  - pendiente/confirmada/cancelada/no_asistio show no "Cobrar".
- **cita_solo_lectura_test:** completed "Cobrar" has the padlock + semantics and opens the sheet without navigating; with plan Beta it has no padlock and navigates.

## Deviations from Plan

- **Test harness only:** `dart format` reflowed 2 pre-existing lines, one in cita_detail_screen_test and one in whatsapp_acciones_test. I restored them by hand to satisfy the "only additions" criterion.
- **Housekeeping:** `flutter pub get` regenerated the linux/macos/windows plugin registrants. I discarded those changes per file (not part of this plan).
- **Not run:** I did not run STATE.md / ROADMAP.md / REQUIREMENTS.md updates. Plans 07-11, 07-12 and 07-14 run in parallel, and the orchestrator consolidates per wave. 07-VALIDATION.md is untouched.

## Threat model

- T-07-55: no client-side change to server checks. The "Cobrada" row replaces the button once a CC is linked.
- T-07-56: the CobrarBoton / ControlEscritura padlock is covered by tests; the server LP004 guard remains authoritative.

## Known Stubs

None.

## TDD Gate Compliance

The RED (`test(07-13)`) commit precedes the GREEN (`feat(07-13)`) commit for both tasks.

## Self-Check: PASSED

- Files exist: both screens and the 4 test files.
- Commits exist: 73d1fee, 8fdd921, c4344b4, 03ef38e.
