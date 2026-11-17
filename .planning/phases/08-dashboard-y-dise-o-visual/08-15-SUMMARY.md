---
phase: 08-dashboard-y-dise-o-visual
plan: 15
subsystem: presentation (vaccination, plan)
tags: [inicio, dashboard, riverpod, widget]
requires: []
provides:
  - "VacunasPendientesCard(mostrarSiVacia:)"
  - "avisoPlanVisibleProvider"
affects: [08-12 (Inicio + PlanBanner switch)]
tech-stack:
  added: []
  patterns: ["Provider.autoDispose derived read-only provider", "ConsumerWidget flag with backwards-compatible default"]
key-files:
  created:
    - lib/features/plan/presentation/providers/aviso_plan_visible_provider.dart
    - test/vacunas_pendientes_card_test.dart
    - test/aviso_plan_visible_provider_test.dart
  modified:
    - lib/features/vaccination/presentation/widgets/vacunas_pendientes_card.dart
decisions:
  - "mostrarSiVacia hides the whole card (SizedBox.shrink before building AppCard), not just the data row, so Inicio gets zero height at 0/0"
  - "The hide check uses `async.hasError ? null : async.value`, matching when()'s skipLoadingOnRefresh: a refresh of a 0/0 result stays hidden, an error is always shown"
requirements: [DASH-01]
metrics:
  completed: 2026-11-17
  tasks: 2
  files: 4
---

# Phase 8 Plan 15: mostrarSiVacia + avisoPlanVisibleProvider Summary

Inicio can now hide an empty vaccine card (`VacunasPendientesCard(mostrarSiVacia: false)`, default `true`), and it can ask `avisoPlanVisibleProvider` whether a plan notice is showing. That provider is PlanBanner's visibility rule copied into one place, using the same 4 inputs and the same condition. `plan_banner.dart` was not touched; 08-12 switches it over.

## Tasks

| # | Task | Result | Evidence | Commits |
|---|------|--------|----------|---------|
| 1 | VacunasPendientesCard(mostrarSiVacia) | ✅ | `MOSTRAR_SI_VACIA_OK` printed; `flutter test test/vacunas_pendientes_card_test.dart test/vacunas_pendientes_screen_test.dart` -> +20 All tests passed (6 new + 14 existing); analyze: No issues found | RED 6d6ea67 (compile failure: no `mostrarSiVacia` param), GREEN 1154818 |
| 2 | avisoPlanVisibleProvider | ✅ | `AVISO_VISIBLE_OK` printed; `flutter test test/aviso_plan_visible_provider_test.dart test/plan_banner_test.dart` -> +27 All tests passed (7 new + 20 existing, plan_banner_test unchanged); analyze: No issues found | RED 1a7c829 (missing file/provider), GREEN 048e9fb |

`flutter analyze` on the whole project: No issues found. The full `flutter test` suite was not run; the orchestrator runs it after the wave merge, as the plan says.

## Truth table covered (Task 2)
- null while `miPlanProvider` is still loading (the repo never completes) and null when it fails with PlanFailure
- null with no notice (Beta, Pro fundador)
- returns the same `tipo` PlanBanner shows for: soloLectura, gracia, pacientesTope, pacientes80, ultimosDias
- a dismissible notice that was dismissed (pacientes80) -> null; a non-dismissible notice (pacientesTope) is still returned after `descartar`
- the admin and colleague profiles get the same `mensaje` as `avisoPlanPara(esAdmin: true/false)`, on gracia and pacientesTope

## Deviations from Plan

**1. [Rule 1 - Bug] Hide the whole card, not just the data row**
- The plan said to "return SizedBox.shrink in the data branch". That branch only builds the inner content, so the title and the AppCard would still show. The flag is now checked before the card is built, which gives the zero height the plan's behavior asks for. Commit 1154818.

**2. [Rule 3 - Blocking] Riverpod retry disabled in the new card test scope**
- Riverpod 3 retries a failed provider automatically, so the error branch never settled in the test. Added `retry: (retryCount, error) => null` to the test's ProviderScope. `router_harness` and `fake_auth` already do the same. This was folded into GREEN commit 1154818.

The plan's verify commands `cd` into the main repo, so they were run from this worktree instead.

## Known Stubs
None.

## Threat Flags
None. T-08-49 is mitigated by the truth-table test against PlanBanner's cases. T-08-50 is mitigated by the `true` default, and vacunas_pendientes_screen_test stays green.

## Self-Check: PASSED
- Files exist: aviso_plan_visible_provider.dart, vacunas_pendientes_card_test.dart, aviso_plan_visible_provider_test.dart, and the modified vacunas_pendientes_card.dart
- Commits found in git log: 6d6ea67, 1154818, 1a7c829, 048e9fb
