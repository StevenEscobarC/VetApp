---
phase: 08-dashboard-y-dise-o-visual
plan: 03
subsystem: home (Inicio data layer)
tags: [dashboard, riverpod, supabase, tdd, formato]
requires: [08-01 contract (rpc inicio_resumen columns)]
provides:
  - formatearCopCorto (lib/core/utils/formato.dart)
  - inicioRevisionProvider (lib/core/data/inicio_revision.dart)
  - ResumenInicio, InicioFailure (lib/features/home/domain/)
  - SupabaseInicioRepository + kMensajeSinConexionLectura + kErrorResumenInicio
  - SupabaseCitaRepository.proximas + FakeCitaRepository.proximas
  - inicioRepositoryProvider, inicioResumenProvider, proximasCitasProvider (+ kErrorProximasCitas)
  - FakeInicioRepository + inicioOverrides (test/helpers/fake_inicio.dart)
affects: [08-05 (invalidation), 08-06 / 08-12 (Inicio UI)]
tech-stack:
  added: []
  patterns: [two-tier catch with esErrorDeRed, AppLifecycleListener on-resume refetch, core revision counter, MockClient request-shape tests]
key-files:
  created:
    - lib/core/data/inicio_revision.dart
    - lib/features/home/domain/resumen_inicio.dart
    - lib/features/home/domain/inicio_failure.dart
    - lib/features/home/data/supabase_inicio_repository.dart
    - lib/features/home/presentation/providers/inicio_providers.dart
    - test/helpers/fake_inicio.dart
    - test/supabase_inicio_repository_test.dart
    - test/inicio_providers_test.dart
  modified:
    - lib/core/utils/formato.dart
    - lib/features/appointments/data/repositories/supabase_cita_repository.dart
    - test/helpers/fake_citas.dart
    - test/formato_test.dart
    - test/supabase_cita_repository_test.dart
decisions:
  - "proximas() orders with ascending: true explicitly: postgrest-dart's .order() defaults to DESCENDING, so combined with .limit() it would return the last citas instead of the next ones"
  - "proximasCitasProvider wraps every error as InicioFailure (offline text when esErrorDeRed, else 'No pudimos cargar las próximas citas.'), so the UI block only handles one failure type"
  - "inicioOverrides overrides both inicioRepositoryProvider and citaRepositoryProvider with fakes by default, so a widget test never hits a real client"
metrics:
  duration: ~35 min
  completed: 2026-11-17
  tasks: 3
  commits: 6
---

# Phase 8 Plan 03: Inicio data slice Summary

This plan adds the tested data layer for Inicio, using fakes only:
- `formatearCopCorto`, which truncates to one decimal and never rounds up;
- `SupabaseInicioRepository.resumen()` over `rpc('inicio_resumen')`, with the D-14 offline mapping;
- `SupabaseCitaRepository.proximas()`, which filters estado in SQL, plus its fake in the same commit;
- two `autoDispose` providers that refetch on resume, on `inicioRevisionProvider` and (for próximas) on `citasRevisionProvider`;
- a counter in `core/` that keeps the import graph acyclic.

## Per-task evidence

| Task | Result | Marker | Tests | Commits (RED / GREEN) |
|------|--------|--------|-------|-----------------------|
| 1 formatearCopCorto | ✅ | `COP_CORTO_OK` | `test/formato_test.dart`: 48 passed (all 15 table cases plus the AssertionError case); `flutter analyze lib/core/utils test/formato_test.dart`: no issues | f4ef96d / 56e71b3 |
| 2 Inicio repository, entity, failure, counter, fake | ✅ | `INICIO_REPO_OK` | `test/supabase_inicio_repository_test.dart`: 10 passed. Covers the rpc POST path, all-zero results for empty and null answers, SocketException / ClientException / TimeoutException mapped to offline, a 400 Postgrest error and an unknown error mapped to the generic message, and the revision counter. The 1-import check and the domain-has-no-Flutter/Supabase check pass | 7b4b77d / c6eae31 |
| 3 proximas() + fake + providers | ✅ | `INICIO_DATA_OK` | cita repo + inicio providers + inicio repo: 36 passed. Covers the request shape (estado in, gte, asc order, limit=5); SocketException rethrown and 400 mapped to CitaFailure; the fake's filter, sort and limit; resumen and próximas refetching on both counters; clock used as `desde` with limit 5; network and other errors mapped to InicioFailure; the end-to-end case with a real repo that has no network. Greps pass: 2x `ref.watch(inicioRevisionProvider)`, 2x `AppLifecycleListener`, no feature imports `home/`. Full `flutter analyze`: no issues | 51ca958 / 149eced (proximas() and the fake override share this commit) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `proximas()` would have returned the latest citas, not the next ones**
- **Found during:** Task 3 GREEN. The request-shape test captured `order=fecha_hora.desc.nullslast`.
- **Issue:** postgrest-dart's `.order(col)` defaults to `ascending: false`. Copying `entre()` verbatim (`.order('fecha_hora')`) together with `.limit(5)` returns the 5 latest future citas.
- **Fix:** `.order('fecha_hora', ascending: true)`, with a comment explaining why. The test now asserts `fecha_hora.asc`.
- **Commit:** 149eced
- **Not fixed (out of scope):** `entre()` has the same descending order, but it is harmless because `agendaSemanaProvider` sorts in Dart and there is no limit.

**2. [Rule 1 - Test] The `in.` filter assertion accepts the quoted form**
- postgrest-dart serializes the filter as `in.("pendiente","confirmada")`. PostgREST treats this the same as the unquoted form, so the test accepts both. Commit 149eced.

**3. [Rule 3 - Blocking] Riverpod 3 auto-retry in provider error tests**
- Error-path tests hung, then hit "disposed during loading state". The fix gives the test container `retry: (retryCount, error) => null`, following the same pattern as `mascotas_providers_test.dart`.

**4. Format-only churn**
- `dart format` also reflowed 2 existing `expect` calls in `test/formato_test.dart` (no behavior change, commit c6eae31).
- Running `dart format lib/features` reformatted unrelated files, and flutter tooling regenerated the plugin registrants. Neither was committed: each of those files was restored individually.

## Known Stubs

None.

## Threat Flags

None. No new endpoints or trust boundaries: reads go through the existing citas RLS and the 08-01 RPC. T-08-12 is covered by the tests that check fixed Spanish messages. T-08-13 is covered by the request-shape test for the SQL `in` filter.

## Notes for downstream plans

- `kMensajeSinConexionLectura` now exists in two libraries: billing and `home/data/supabase_inicio_repository.dart`. They have the same text. Do not import both libraries unprefixed in one file.
- Provider tests on Inicio need `TestWidgetsFlutterBinding.ensureInitialized()` (for `AppLifecycleListener`) and `retry: (_, _) => null`.

## Self-Check: PASSED

- All 8 created files exist. The 6 commits f4ef96d, 56e71b3, 7b4b77d, c6eae31, 51ca958 and 149eced are in `git log`.
