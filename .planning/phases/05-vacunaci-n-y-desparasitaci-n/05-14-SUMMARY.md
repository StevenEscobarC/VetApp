---
phase: 05-vacunaci-n-y-desparasitaci-n
plan: 14
subsystem: clinic-logo
tags: [supabase, storage, rls, flutter, riverpod]
requires: [05-01]
provides:
  - "schema.sql section 16: clinicas.logo_path, private bucket clinica-logos, admin-only actualizar_clinica RPC"
  - "lib/features/clinic contract (Clinica, SupabaseClinicaRepository, ClinicaLogoDatasource, providers, ClinicaLogo)"
affects: [05-04, 05-15, 05-16]
key-files:
  created:
    - lib/features/clinic/domain/clinica.dart
    - lib/features/clinic/domain/clinica_failure.dart
    - lib/features/clinic/data/repositories/supabase_clinica_repository.dart
    - lib/features/clinic/data/datasources/clinica_logo_datasource.dart
    - lib/features/clinic/presentation/providers/clinica_providers.dart
    - lib/features/clinic/presentation/widgets/clinica_logo.dart
    - test/helpers/fake_clinica.dart
    - test/clinica_contrato_test.dart
    - test/clinica_logo_test.dart
  modified:
    - supabase/schema.sql
decisions:
  - "Clinic data written only via actualizar_clinica (no UPDATE policy on clinicas)"
  - "Logo path shape {clinica_id}/logo-<epoch>.jpg enforced identically in table check, storage policies, RPC and Dart rutaLogo"
metrics:
  tasks: 3
  completed: 2026-10-02
---

# Phase 5 Plan 14: Clinic logo schema + Dart contract Summary

Fase 5 schema delta now carries the clinic logo (logo_path, private 1 MB JPEG bucket, admin-only `actualizar_clinica`, `logo_path` in both carne functions) plus a tested Dart contract for plans 05-15 and 05-16. Nothing applied live (05-04 does that).

## Commits
- 8b6e061: schema section 16 + logo_path in carne_de_mascota / carne_publico
- 592a920: Clinica, ClinicaFailure, SupabaseClinicaRepository, ClinicaLogoDatasource + contract tests
- e8e79c9: providers, ClinicaLogo widget, fakes, widget tests

## Verification
- LOGO_SQL_OK grep gate passes; exactly 2 `'logo_path', cl.logo_path`; no clinicas UPDATE policy; file ends with `notify pgrst`.
- `flutter test test/clinica_logo_test.dart test/clinica_contrato_test.dart`: 10 tests pass. `flutter analyze` clean on new files.

## Deviations from Plan
None. Minor: the widget test imports `flutter_riverpod/misc.dart` for the `Override` type (Riverpod 3), as other tests do. Regenerated linux/macos/windows plugin registrants from `flutter pub get` were deliberately not committed.

## Known Stubs
None.

## Threat Flags
None beyond the plan's threat model (T-05-40..45 mitigated in section 16).

## Self-Check: PASSED
