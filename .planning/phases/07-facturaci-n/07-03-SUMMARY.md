---
phase: 07-facturaci-n
plan: 03
subsystem: billing-domain-helpers
tags: [billing, tdd, pure-dart, whatsapp, formato]
requires: []
provides:
  - "generarClaveIdempotencia([Random? rng]) — UUID v4 via Random.secure()"
  - "pesosEnLetras(int) — amount in words, 0..999.999.999"
  - "mensajeCobroWhatsApp({...}) — formal CC/quote WhatsApp text"
  - "normalizarCedula / formatearCedula / normalizarNit / formatearNit in formato.dart"
affects: [07-04+, billing slices (draft key, CC PDF, share flow, cliente/clinica forms)]
tech-stack:
  added: []
  patterns: ["pure domain helpers with record returns ({valor, error})", "injectable Random seam for deterministic tests"]
key-files:
  created:
    - lib/features/billing/domain/clave_idempotencia.dart
    - lib/features/billing/domain/pesos_en_letras.dart
    - lib/features/billing/domain/whatsapp_cobro.dart
    - test/clave_idempotencia_test.dart
    - test/pesos_en_letras_test.dart
    - test/whatsapp_cobro_test.dart
  modified:
    - lib/core/utils/formato.dart
    - test/formato_test.dart
decisions:
  - "The 'Es válida hasta el …' sentence is omitted when a quote has no validaHasta, so the text never shows a broken date."
  - "The firma is the clinic alone for a blank vet name, the vet alone for a blank clinic, and empty when both are blank."
  - "formatearCedula/formatearNit return non-digit input unchanged (legacy, non-normalized data)."
metrics:
  duration: "~15 min"
  completed: 2026-11-13
  tasks: 2
  files: 8
---

# Phase 7 Plan 03: Billing pure helpers Summary

These are dependency-free, test-first helpers for the billing slices:
- an RFC 4122 v4 idempotency key from `Random.secure()`;
- the Colombian Spanish amount in words for the CC "La suma de" line;
- the formal WhatsApp text for a CC (pending or paid) and for a quote, which never says "factura";
- cédula/NIT normalizers and formatters that mirror the server CHECKs.

## Tasks and evidence

| Task | Result | RED commit | GREEN commit | Marker | Tests |
|------|--------|------------|--------------|--------|-------|
| 1. generarClaveIdempotencia + pesosEnLetras | ✅ | 66c4f30 (failed to compile: `Method not found: 'pesosEnLetras'`, `+0 -2`) | 2c235d8 | `HELPERS_CLAVE_LETRAS_OK` | `00:00 +32: All tests passed!` (analyze: `No issues found!`); `PUBSPEC_UNCHANGED` |
| 2. mensajeCobroWhatsApp + cédula/NIT | ✅ | 14c5c16 (`+0 -2: Some tests failed.`) | ece3867 | `HELPERS_WA_DOC_OK` | `00:00 +50: All tests passed!` (analyze: `No issues found!`); `git diff --numstat test/formato_test.dart` → `62 0` (only additions) |

Full-plan gates, run from the worktree at the plan's final code commit:
- `flutter analyze` gave `No issues found! (ran in 12.1s)`.
- `flutter test` gave `00:36 +1092: All tests passed!`.
- `git diff --quiet 7cbaa03 -- pubspec.yaml pubspec.lock` gave `PUBSPEC_UNCHANGED`.

## TDD Gate Compliance

Each task has a `test(07-03)` RED commit followed by a `feat(07-03)` GREEN commit. No refactor commits were needed.

## Deviations from Plan

**1. [Rule 3 - Blocking] I ran the verify commands in the worktree, not at `/c/Trabajo/VetApp`.**
- **Issue:** The plan's `<automated>` blocks begin with `cd /c/Trabajo/VetApp`, which is the main checkout. Running them there would have tested master without this plan's code.
- **Fix:** I ran the same command chains unchanged, but from `C:\Trabajo\VetApp\.claude\worktrees\agent-a446b693d38a12ef5`.

Otherwise the plan was executed as written.

## Threat model

- **T-07-16:** The key uses `Random.secure()`, which gives 122 random bits. A test checks that 1000 keys are distinct.
- **T-07-17:** The message contains only the name, number, amount, pet, date and firma. The tests check the exact strings.
- **T-07-18:** The regexes match the `clientes_cedula_formato` / `clinicas_nit_formato` shapes in the plan contract, and the tests cover them.

## Known Stubs

None.

## Self-Check: PASSED

- All 8 files in key-files exist in the worktree.
- Commits 66c4f30, 2c235d8, 14c5c16 and ece3867 are present in `git log`.
