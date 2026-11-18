---
phase: 08-dashboard-y-dise-o-visual
reviewed: 2026-11-17
depth: standard
base: f4ef96d^ (first Phase 8 commit) .. fef670f, plus 08-13 commits 9cfc6bd and c3ca862
files_reviewed: 65 (lib, supabase, tool; 2531 insertions, 481 deletions)
findings:
  critical: 0
  warning: 0
  info: 5
status: clean_with_info
---

# Phase 8 — Code review

**Reviewer:** the 08-13 executor, following the `gsd-code-reviewer` standard-depth checklist. The executor session had no subagent tool, so the `gsd-code-reviewer` subagent could not be spawned; the review was done directly on the phase diff (focus: `lib/features/home/**`, `lib/core/data/inicio_revision.dart`, `SupabaseCitaRepository.proximas`, every `inicioRevisionProvider` bump site, the Fase 8 block of `supabase/schema.sql`, `tool/dash04_gates.sh`).

## Lessons checked explicitly (06-REVIEW / 07-REVIEW)

| Lesson | Where | Result |
|--------|-------|--------|
| **WR-01** network detection by type | `SupabaseCitaRepository.proximas()` (`supabase_cita_repository.dart:51-74`) catches `PostgrestException` → `CitaFailure`, and in the generic branch `if (esErrorDeRed(e)) rethrow;`. `esErrorDeRed` (`supabase_inventario_repository.dart:330`) checks `TimeoutException` / `http.ClientException` by type, plus `SocketException` by runtime type name (dart:io is not imported on web). `proximasCitasProvider` and `SupabaseInicioRepository._run` map network errors to `InicioFailure(kMensajeSinConexionLectura, sinConexion: true)`. Covered by `INICIO_DATA_OK` / `INICIO_REPO_OK`. | PASS |
| **WR-03** invalidation on every outcome | `CitaActions.crear/actualizar/reasignar/cambiarEstado` (`citas_providers.dart:99,131,141,151`) and `RegistrarConsulta` (`consultas_providers.dart:82`) bump `inicioRevisionProvider` in `finally`; every cobros action calls `invalidarCobros` (which bumps the counter) in `finally` (`cobros_providers.dart:152-250`). Alta de mascota / cliente+mascota bump after success only (`mascota_form_screen.dart:189`, `nuevo_cliente_mascota_screen.dart:171`), which is correct (a failed insert changes no number), and the shell bumps again when the user returns to the Inicio tab (`app_shell.dart:41`). | PASS |
| **CR-01** stale client values sent as truth | Inicio never aggregates: `SupabaseInicioRepository.resumen()` maps the RPC row verbatim (empty → zeros); no `fold`/`reduce`/`length` arithmetic in `lib/features/home`. Inicio writes nothing. | PASS |
| **Definer RPC tenant scoping** | `inicio_resumen()` is `security definer set search_path = public`, guards `es_veterinario()` and `mi_clinica_id()` (raises `insufficient_privilege`), counts `consultas` through `join mascotas m ... where m.clinica_id = v_clinica`, filters `cobros` and `mascotas` by `clinica_id`; `execute` revoked from `public, anon`, granted to `authenticated`. Live: `OK rpc inicio_resumen protegido 401`. Smoke T33..T40 isolation checks: `RLS SMOKE: PASS (301 checks) - cambios revertidos` (08-04). | PASS |

## Other checks

- Import graph: no feature imports `home/` (gate empty); `home/domain` and `home/presentation` do not import `supabase_flutter`; no `DateTime.now()` in `lib/features/home` (clock via `clockProvider`).
- Month bounds: Bogotá `timestamptz` bounds, sargable; `ingresos_mes` copies the `cobros_resumen` predicate (parity tested by T37).
- `proximas()`: explicit ascending order (the comment explains postgrest-dart's default), `limit 5`, estado `in (pendiente, confirmada)`, RLS-scoped.
- Providers: `AppLifecycleListener` created in each `FutureProvider.autoDispose` build and disposed in `onDispose`; no timers or polling.
- Gate script: the SW-04 `EdgeInsets` pattern missed a literal directly after `(`; fixed in `9cfc6bd` with two new selftest fixtures. A full run over `lib` found no new hit.
- Secrets: no URL, project ref, key or phone number in the diff or in the reports.

## Findings

| ID | Severity | file:line | Finding | Disposition |
|----|----------|-----------|---------|-------------|
| IN-01 | INFO | `lib/features/inventory/data/repositories/supabase_inventario_repository.dart:330` | `esErrorDeRed` lives in the inventory data layer and is imported by appointments, billing and home (`show esErrorDeRed`). It works, but it couples features through a data file. | Linear (Plataforma y Calidad): move to `core/data/` (brand-audit I-14). |
| IN-02 | INFO | `lib/features/home/presentation/providers/inicio_providers.dart:43` | `ahora` is read once per provider build, so a cita whose time passes while Inicio stays open keeps showing until the next refresh (resume, pull-to-refresh, tab return or any write). This matches D-13 (no timers). | Accepted, no change. |
| IN-03 | INFO | `supabase/schema.sql` Fase 8 block | `pacientes_nuevos_mes` counts every mascota created in the month, archived ones included. Consistent with "Pacientes nuevos" = altas del mes; confirm the wording in 08-16 QA. | Record only. |
| IN-04 | INFO | `lib/features/home/presentation/providers/inicio_providers.dart:49-53` | Any non-network error from `proximas()` (including a `CitaFailure` with a specific message) becomes the generic "No pudimos cargar las próximas citas." | Accepted (UI-SPEC §7: one failure type per block). |
| IN-05 | INFO | `lib/features/home/presentation/screens/mas_screen.dart:110,137,278` | Light-only `AppColors.textSecondary` on the dark card (brand re-audit W-31). | Fixed in `c3ca862` (visual only). |

No critical or warning findings, so there are no gaps for `/gsd-plan-phase 8 --gaps` from the review.
