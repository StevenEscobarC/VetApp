---
phase: 07-facturaci-n
plan: 06
subsystem: clients, clinic
tags: [billing, cedula, nit, forms, tdd]
requires: ["07-03 (normalizarCedula/formatearCedula/normalizarNit/formatearNit)"]
provides:
  - "Cliente.cedula (digits only, nullable) written via PostgREST update"
  - "Clinica.nit (nullable) read in miClinica, written via actualizar_clinica p_nit"
affects: ["07-04 (actualizar_clinica 6-arg signature)", "07-08 (live apply)", "PDF snapshot of cuenta de cobro"]
tech-stack:
  added: []
  patterns: ["digits-only while focused, formatted when unfocused", "full-replacement param like logoPath"]
key-files:
  created: []
  modified:
    - lib/features/clients/domain/entities/cliente.dart
    - lib/features/clients/data/repositories/supabase_cliente_repository.dart
    - lib/features/clients/presentation/screens/cliente_detail_screen.dart
    - lib/features/clinic/domain/clinica.dart
    - lib/features/clinic/data/repositories/supabase_clinica_repository.dart
    - lib/features/clinic/presentation/providers/datos_clinica_providers.dart
    - lib/features/clinic/presentation/screens/datos_clinica_screen.dart
    - test/helpers/fake_clinica.dart
    - test/clinica_contrato_test.dart
    - test/guardar_datos_clinica_test.dart
    - test/datos_clinica_screen_test.dart
    - test/cliente_detail_screen_test.dart
decisions:
  - "The cédula field always applies digitsOnly (not only while focused): enterText/paste can land before focus rebuilds, and maxLength 12 would truncate a dotted value"
  - "p_nit is always sent and is full replacement (null clears, matching 07-04 T28); GuardarDatosClinica passes nit through and the form always sends the current value"
  - "SupabaseClienteRepository.desdeFila (static) exposes the row mapping for tests; _fromRow delegates to it"
  - "SupabaseClinicaRepository.columnasClinica (static const) holds the miClinica select so the test can assert 'nit'"
metrics:
  completed: 2026-11-13
  tasks: 2
  commits: 4
---

# Phase 7 Plan 06: Client cédula and clinic NIT Summary

Clients get an optional "Cédula (opcional)" field on the detail form, stored as digits and shown with dots. The clinic gets an optional "NIT o cédula (opcional)" field in Datos de la clínica, sent as a normalized `p_nit` to the 6-argument `actualizar_clinica`. Both are covered by TDD, and the full suite stays green.

## Tasks

| # | Task | RED commit | GREEN commit | Gate |
|---|------|-----------|--------------|------|
| 1 | Optional cédula on the client (entity, repo, detail form) | 6761003 | 64d74cd | ✅ CEDULA_CLIENTE_OK |
| 2 | Optional NIT o cédula of the clinic (entity, repo, provider, form) | e8b6ba2 | aa70669 | ✅ NIT_CLINICA_OK |

## Evidence per task (for 07-VALIDATION.md, copied by the orchestrator)

**Task 1.** The `<automated>` command was run from the worktree root, with `cd /c/Trabajo/VetApp` replaced by the worktree.
- RED: `00:00 +0 -1: Some tests failed.` The getter `cedula` was not defined yet.
- `flutter analyze lib/features/clients test/cliente_detail_screen_test.dart` → `No issues found! (ran in 11.5s)`
- `flutter test test/cliente_detail_screen_test.dart test/clientes_providers_test.dart test/nuevo_cliente_mascota_screen_test.dart` → `00:04 +53: All tests passed!`
- grep `'cedula'` in the repository → OK. `nuevo_cliente_mascota_screen.dart` is not in the diff.
- Marker: `CEDULA_CLIENTE_OK`
- `git diff 8b17acc --numstat -- test/cliente_detail_screen_test.dart` → `161	0` (additions only).

**Task 2.**
- RED: `00:00 +0 -1: Some tests failed.` `nit`, `columnasClinica` and `p_nit` did not exist yet.
- `flutter analyze` → `No issues found! (ran in 12.8s)`
- `flutter test test/clinica_contrato_test.dart test/guardar_datos_clinica_test.dart test/datos_clinica_screen_test.dart test/clinica_logo_test.dart` → `00:10 +44: All tests passed!`
- grep `'p_nit'` → OK.
- `flutter test` (full suite) → `01:06 +1170: All tests passed!`
- Marker: `NIT_CLINICA_OK`
- Test diffs:
  - `clinica_contrato_test.dart` has 35 additions and 0 deletions. The only change in the key set is the added `'p_nit'` line.
  - `datos_clinica_screen_test.dart` has 83 additions and 0 deletions.
  - `guardar_datos_clinica_test.dart` has 16 additions and 0 deletions.
  - `fake_clinica.dart` has 3 additions.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] digitsOnly applied always on the cédula field**
- **Found during:** Task 1 GREEN.
- **Issue:** The formatter was applied only while the field was focused. Text that entered before the focus rebuild skipped it, so `maxLength: 12` cut '1.020.304.050' down to '102030405'.
- **Fix:** `FilteringTextInputFormatter.digitsOnly` now always applies. Dots are only ever set by code when the field loses focus.
- **Commit:** 64d74cd

**2. [Rule 3 - Blocking] Redundant import removed**
- **Found during:** Task 2.
- **Issue:** Adding `package:flutter/services.dart` made `dart:typed_data` redundant in `datos_clinica_screen.dart`, and `flutter analyze` flagged it with `unnecessary_import`.
- **Fix:** Removed the redundant import.
- **Commit:** aa70669

**3. Small test seams**
- `SupabaseClienteRepository.desdeFila` (static) is now the public form of `_fromRow`, so the mapping behavior can be tested.
- `SupabaseClinicaRepository.columnasClinica` is a const holding the select string.
- Both are inside the listed files.

## Notes

- **Generated files left out.** `flutter` tooling changed the generated plugin registrants under `linux/`, `macos/` and `windows/`. They were not committed because they are outside this plan's scope. `.claude/settings.local.json` was already modified before this plan and was also not committed.
- **Files from other plans.** Nothing under `supabase/` (07-04) or `lib/features/billing/**` (07-05) was touched, and `07-VALIDATION.md` was not edited.
- **When live writes work.** Live writes of `cedula` and `p_nit` start working once 07-08 applies the schema. Until then, everything runs on fakes.
- **Read-only clinic view.** It does not show the NIT, because the UI-SPEC does not ask for it.

## Threat Flags

None. T-07-29 is mitigated on the client by `normalizarCedula`/`normalizarNit` before any write; the server CHECKs belong to 07-01/07-04. T-07-30 is unchanged: the field sits only in the admin-only `_Formulario`. T-07-31: the cédula appears only on the client detail form, never on the fast form or in logs.

## Self-Check: PASSED

- All 12 listed files exist and were modified.
- Commits 6761003, 64d74cd, e8b6ba2 and aa70669 are present on the branch `worktree-agent-a331b256bc559c720`.
