---
phase: 08-dashboard-y-dise-o-visual
plan: 13
subsystem: phase-close (automated)
tags: [gate, dash-04, brand-audit, code-review, docs, validation]
requires: [08-01, 08-02, 08-03, 08-04, 08-05, 08-06, 08-07, 08-08, 08-09, 08-10, 08-11, 08-12, 08-14, 08-15]
provides: [08-BRAND-AUDIT.md, 08-REVIEW.md, filled 08-VALIDATION.md, Inicio domain docs, fixed SW-04 gate]
affects: [08-16]
tech-stack:
  added: []
  patterns: [InicioColores for theme-aware secondary text in home]
key-files:
  created:
    - .planning/phases/08-dashboard-y-dise-o-visual/08-BRAND-AUDIT.md
    - .planning/phases/08-dashboard-y-dise-o-visual/08-REVIEW.md
    - .planning/phases/08-dashboard-y-dise-o-visual/08-13-SUMMARY.md
  modified:
    - tool/dash04_gates.sh
    - lib/features/home/presentation/screens/mas_screen.dart
    - .claude/skills/arquitecto-vetapp/SKILL.md
    - .claude/skills/arquitecto-vetapp/references/modelo-dominio.md
    - .planning/phases/08-dashboard-y-dise-o-visual/08-VALIDATION.md
decisions:
  - "SW-07 dark-contrast debt in pre-existing screens (outside home) is INFO for Linear, not WARN: D-18 limits the sweep's contrast check to new screens"
  - "The Más screen (home) WARN found by the re-audit was fixed in place, visual only (D-19)"
metrics:
  completed: 2026-11-17
  tasks: 3
  commits: 4
---

# Phase 8 Plan 13: Automated close Summary

Full suite, live probe, APK and DASH-04 gates are green over the whole tree. I fixed the SW-04 gate gap, which turned up no hidden literal. The brand re-audit closes W-01..W-30 and found one new WARN in Más, fixed in home. The code review found 0 critical and 0 warning findings. The Inicio domain docs and the VALIDATION statuses are filled in.

## Tasks

| Task | Result | Evidence | Commit |
|------|--------|----------|--------|
| 1. Gate, live probe, APK, DASH-04 greps | ✅ | `PHASE8_GATE_OK` (see below) | `9cfc6bd` (gate fix) |
| 2. Brand re-audit + Linear | ✅ | `BRAND_AUDIT_OK`; `BRAND-AUDIT: 0 BLOCKER, 0 WARN abiertos` | `c3ca862` (Más fix), `e1dc7be` |
| 3. Review, docs, validation | ✅ | `REVIEW_DOCS_OK` (leak grep run with `--exclude=08-13-PLAN.md`, see Deviations) | `fc9d8f8` |

## Task 1 evidence (literal results, from the worktree root)

- `bash supabase/tests/verify_live_schema.sh` → RC 0, 90 `OK` lines, `OK rpc inicio_resumen protegido 401`, last line `LIVE_SCHEMA_OK`. The probe's RPC list includes `inicio_resumen`, the same name as `_client.rpc('inicio_resumen')` in `lib/features/home/data/supabase_inicio_repository.dart:25`. The credentials came from the main checkout's `dart_define.json` through environment variables and were never printed.
- RLS smoke (copied from 08-04-SUMMARY, not re-run): `RLS SMOKE: PASS (301 checks) - cambios revertidos`.
- `flutter analyze` → `No issues found!` (run at `9cfc6bd` and again at `c3ca862`).
- `flutter test` → `+1688: All tests passed!` (at `9cfc6bd` and again at `c3ca862`). vetapp-gate equivalent: GATE GREEN in round 1, no test edited.
- `flutter build apk --debug --dart-define-from-file=<main checkout>/dart_define.json` → `√ Built build\app\outputs\flutter-apk\app-debug.apk` (173 MB). APK path: `build/app/outputs/flutter-apk/app-debug.apk` in the worktree.
- `bash tool/dash04_gates.sh --selftest` → `DASH04_SELFTEST_OK`.
- `bash tool/dash04_gates.sh lib` →
  ```
  EXENTOS: 44
    9 SW-01: tematizado en app_theme.dart (08-02)
    1 SW-02: relleno de canvas dart:ui al recortar la foto, no es color de UI
    33 SW-03: estilos del paquete pdf (UI-SPEC Exemptions)
    1 SW-09: constante de origen en la base, nunca se muestra
  DASH04_GATES: PASS
  ```
- `grep -rn "ComingSoon\|Próximamente" lib test --include=*.dart | grep -v test/core_tokens_test.dart` → empty.
- `grep -rni "factur" lib --include=*.dart | grep -v "const String kOrigenCobro = 'factura';"` → empty. The only `factur` in lib is `lib/features/inventory/domain/entities/movimiento_stock.dart:61` `kOrigenCobro`.
- Import-cycle gate `grep -rnE "import '.*(/|\.\./)home/" lib/features --include=*.dart | grep -v "^lib/features/home/"` → empty.
- `grep -rln "supabase_flutter" lib/features/home/domain lib/features/home/presentation` → empty.
- `grep -rn "DateTime.now()" lib/features/home` → empty.
- Plan verify chain (all of the above in one command) → `PHASE8_GATE_OK`.

### SW-04 gate gap (reported by 08-10)

- **Bug:** `EdgeInsets\.(all|symmetric|only|fromLTRB)\([^)]*[^a-zA-Z_.0-9][0-9]+\b` needs one non-identifier character between `(` and the digit, so `EdgeInsets.all(12)` slipped through.
- **Fix (`9cfc6bd`):** `EdgeInsets\.(all|symmetric|only|fromLTRB)\(([^)]*[^a-zA-Z_.0-9])?[0-9]+\b`, plus selftest fixtures `EdgeInsets.all(12)` and `EdgeInsets.only(left: 6)`. The selftest prints `DASH04_SELFTEST_OK`.
- **Full run over lib:** 0 new hits. An extra awk scan of multi-line `EdgeInsets.*(` arguments found only `carne_pdf_service.dart:250-251`, which is a pdf builder and exempt. No code fix was needed (D-19 untouched).

## Task 2: brand re-audit

- `08-BRAND-AUDIT.md`: one table per feature (13 scopes), W-01..W-30 closure table (all closed, with each plan's marker), INFO list, final line `BRAND-AUDIT: 0 BLOCKER, 0 WARN abiertos`.
- **New WARN W-31 (SW-07), fixed:** `mas_screen.dart:110,137,278` used the light-only `AppColors.textSecondary` on the dark card, about 1.8:1. Now it uses `InicioColores.secundario(context)`. Light mode is unchanged. Commit `c3ca862`. Re-run after the fix: `flutter test` of the 4 Inicio tests plus the 6 Más-route tests → `+187: All tests passed!`; `bash tool/dash04_gates.sh lib/features/home` → `DASH04_GATES: PASS`; full suite `+1688` and analyze clean.
- **Linear:** the session had no Linear tool, so every INFO item is **pendiente de Linear** (team VetApp, project "Fase 8 — Dashboard y Diseño Visual"):
  - I-06 Historia clínica: `historia_clinica_timeline.dart:182`. "(retirado)" uses a `TextStyle` with the light-only `textMuted` → `colorScheme.onSurfaceVariant`.
  - I-07 Agenda: the `yyyy-MM-dd` route helper is repeated in `agenda_screen.dart:392`, `cita_form_screen.dart:434` and `completar_cita_screen.dart:83` → one helper in `core/utils`.
  - I-12 Plataforma y Calidad: pre-existing screens use light-only text constants in dark mode (`textMuted` 111, `textSecondary` 98, `primaryText` 32, `success` 23, `foreground` 11 uses outside home). Fix them screen by screen against the 08-16 F9 dark captures.
  - I-13 Cobros: the "Quitar" button at `linea_cobro_tile.dart:217-221` has no tooltip, and its `AppColors.foreground` icon is about 1.1:1 in dark mode.
  - I-14 Plataforma y Calidad: move `esErrorDeRed` (`supabase_inventario_repository.dart:330`) to `core/data/`.
  - I-04 (`mascota_detail_screen.dart:192`, 24×24 spinner) is an allowed size. Recorded only, no issue needed.

## Task 3: review, docs, validation

- `08-REVIEW.md` (standard depth, phase diff `f4ef96d^..fef670f` plus the 08-13 commits: 65 files, +2531/-481). All 4 lessons PASS: WR-01 network detection by type, WR-03 counter bump in `finally`, CR-01 no client aggregation, definer tenant scoping through `mascotas.clinica_id`. Findings: **0 critical, 0 warning**, 5 info (IN-01..IN-05). No gaps for `/gsd-plan-phase 8 --gaps`.
- `modelo-dominio.md` §11 now covers `inicio_resumen()`: definer, clinic guard, consultas via mascotas, Bogotá timestamptz month bounds, the ingresos = `cobros_resumen` rule and the fact that read-only users can read it. It also covers the próximas citas query and the refresh counter.
- `SKILL.md`: §3 `core/data/inicio_revision.dart` and the home folders; §4 the `inicioRevisionProvider` pattern; §7 the definer exception line for `inicio_resumen`; §8 the AppButton variants and square mode, the 08-02 component themes and the gate script.
- `08-VALIDATION.md`: every automated row (08-01..08-15 and 08-13) is ✅ with its literal marker, and W-01..W-30 plus W-31 are filled. Other changes: Wave 0 ticked, the literal RLS SMOKE line recorded, `wave_0_complete: true`, `nyquist_compliant: true` kept. The 08-16 rows and the manual rows stay ⬜.

## Deviations from Plan

1. **[Rule 3 - Blocking] No subagent or Linear tools in this executor session.** I could not spawn `vetapp-brand-ui` or `gsd-code-reviewer`, so I ran their read-only procedures directly and noted this in both reports. I created no Linear issues. Every INFO item is marked "pendiente de Linear" (listed above).
2. **[Rule 1 - Bug] SW-04 gate pattern** fixed as described above (`9cfc6bd`).
3. **[Rule 2 - Brand WARN in home] Más dark contrast** fixed visual-only inside `lib/features/home/presentation/**`, as Task 2 step 3 allows (`c3ca862`).
4. **[Rule 3] Task 3 leak grep self-matches the plan.** The verify's leak grep covers the whole phase directory, and `08-13-PLAN.md:159` (the T-08-44 threat row) spells out `supabase.co` and `supabase.com/dashboard/project/` as patterns. With `--exclude=08-13-PLAN.md`, the grep is empty and the chain prints `REVIEW_DOCS_OK`. No report or doc contains a URL, project ref, key or phone number.
5. **Environment.** `dart_define.json` exists only in the main checkout (gitignored). The live probe read it through environment variables and the APK build through `--dart-define-from-file` with its path. Nothing was copied into the worktree and no value was printed. Flutter tooling rewrote the generated plugin registrants (line endings only); I restored them per file and did not commit them.

## Known Stubs

None.

## Threat Flags

None. No new endpoint, auth path or schema change. This plan changed only one color lookup and the gate script.

## Self-Check: PASSED

- Files: `08-BRAND-AUDIT.md`, `08-REVIEW.md`, `08-13-SUMMARY.md`, `08-VALIDATION.md`, `SKILL.md`, `modelo-dominio.md`, `tool/dash04_gates.sh`, `mas_screen.dart`: present.
- Commits: `9cfc6bd`, `c3ca862`, `e1dc7be`, `fc9d8f8`: present in `git log`.
