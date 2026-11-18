# Phase 8 — Brand re-audit (DASH-04, D-15, D-16)

**Auditor:** 08-13 executor, following the `vetapp-brand-ui` procedure (`.claude/agents/vetapp-brand-ui.md`) and UI-SPEC Sweep Rules SW-01..SW-10. The executor had no subagent tool in its session, so the `vetapp-brand-ui` subagent could not be spawned; the same read-only greps and file inspections were run directly. Date 2026-11-17, base `fef670f` + `9cfc6bd` (SW-04 gate fix).
**Scope:** `lib/features/{auth,home,patients,clients,clinical_history,appointments,vaccination,inventory,billing,plan,team,clinic}/**` and `lib/core/widgets/**`.
**Verdict:** PASS with observations. 0 BLOCKER. 1 WARN found and fixed inside home (Más, SW-07). All 30 tracked WARNs (W-01..W-30) are closed. INFO items are listed below for Linear.

## Whole-tree gates

| Gate | Result |
|------|--------|
| `bash tool/dash04_gates.sh --selftest` | `DASH04_SELFTEST_OK` (now also covers `EdgeInsets.all(12)` and `EdgeInsets.only(left: 6)`) |
| `bash tool/dash04_gates.sh lib` | `EXENTOS: 44` (9 SW-01 themed FAB/Switch/SwitchListTile/Checkbox, 1 SW-02 canvas fill in `recorte_cuadrado.dart`, 33 SW-03 pdf-package styles, 1 SW-09 `kOrigenCobro`) · `DASH04_GATES: PASS` |
| Fixed SW-04 pattern `\(([^)]*[^a-zA-Z_.0-9])?[0-9]+\b` over `lib` | 0 hits outside `core/theme` and `*_pdf_service.dart` |
| Multi-line `EdgeInsets.*(` arguments (awk scan) | only `carne_pdf_service.dart:250-251` (pdf builder, exempt) |
| Raw `ElevatedButton/FilledButton/OutlinedButton/TextButton/TextField/TextFormField/Chip/Card/AppBar` outside `lib/core/widgets` | 0 |
| `IconButton` without `tooltip` | 1 (`linea_cobro_tile.dart:217`, has `Semantics(label: 'Quitar …')`; INFO I-13) |
| `DateFormat(` / `toIso8601String()` / `'$' +` in presentation | 0 (SW-08 gate) |
| `toStringAsFixed` / `NumberFormat` in presentation | 0 (only `clinical_history/domain/formato_consulta.dart:9` temperature with comma decimal, correct for Colombia) |
| English copy / "Próximamente" / "Factura" | 0 |

## Per feature

### auth
| Rule | file:line | Severity | Finding | Fix |
|------|-----------|----------|---------|-----|
| — | — | — | No hits. W-01..W-04 closed by 08-11 (no `onPressed: () {}` left in `lib`, spacing via `AppSpacing`, `AppButton` text). I-01 fixed in 08-11. | — |

### home (shell, Inicio, Más)
| Rule | file:line | Severity | Finding | Fix |
|------|-----------|----------|---------|-----|
| SW-07 | `home/presentation/screens/mas_screen.dart:110,137,278` | WARN (fixed) | "Mat. …", "n miembros" and the reminder label used light-only `AppColors.textSecondary` (#474238) on the dark card surface, about 1.8:1. | Swapped to `InicioColores.secundario(context)` (light unchanged, dark `textSecondaryDark`). Commit `c3ca862`. |
| SW-07 | `home/presentation/widgets/*` | — | Inicio reads every text color through `InicioColores` / `colorScheme`; the only `AppColors.*` are the 4 quick-action fills (UI-SPEC accepts the dark `Cobro` fill), `onPrimary` icons and the light-mode branch of the paw icon. | — |
| SW-01..SW-09 | `lib/features/home` | — | `bash tool/dash04_gates.sh lib/features/home` → `DASH04_GATES: PASS`. | — |

### patients
| Rule | file:line | Severity | Finding | Fix |
|------|-----------|----------|---------|-----|
| SW-04 | `patients/presentation/screens/mascota_detail_screen.dart:192` | INFO (I-04) | 24×24 spinner box: allowed literal (icon/avatar size, SW-04). Recorded, no change. | — |
| SW-07 | 7 uses of light-only `AppColors` text constants | INFO (I-12) | Dark-mode contrast of pre-existing screens (D-18: verify only). | See I-12. |

### clients
| Rule | file:line | Severity | Finding | Fix |
|------|-----------|----------|---------|-----|
| SW-01 | `clients/presentation/screens/clientes_list_screen.dart:86` | exempt | `FloatingActionButton.extended` themed by `floatingActionButtonTheme` (08-02). W-05 closed. | — |
| SW-07 | 4 uses | INFO (I-12) | as above | I-12 |

### clinical_history
| Rule | file:line | Severity | Finding | Fix |
|------|-----------|----------|---------|-----|
| SW-03/SW-07 | `clinical_history/presentation/widgets/historia_clinica_timeline.dart:182` | INFO (I-06) | `TextStyle(color: AppColors.textMuted)` inside a `TextSpan` (" (retirado)"); light-only color in dark mode. | Inherit the span style and use `colorScheme.onSurfaceVariant` (same fix as `dosis_card.dart:303`). |
| SW-07 | 9 uses | INFO (I-12) | as above | I-12 |

### appointments
| Rule | file:line | Severity | Finding | Fix |
|------|-----------|----------|---------|-----|
| — | — | — | W-06..W-14 closed (08-07 and 08-02 themes): no raw buttons, `day_strip.dart:101` `minWidth: AppSpacing.touchTarget`, spacing tokens, Switch/Checkbox themed. | — |
| maintainability | `agenda_screen.dart:392-394`, `cita_form_screen.dart:434-436`, `completar_cita_screen.dart:83-85` | INFO (I-07) | Same `yyyy-MM-dd` route-param helper repeated 3 times. | One helper in `core/utils/zona_bogota.dart` or `formato.dart`, with a test. |
| SW-07 | 39 uses (incl. `day_strip.dart:79,138` unselected day text `AppColors.foreground`) | INFO (I-12) | as above | I-12 |

### vaccination
| Rule | file:line | Severity | Finding | Fix |
|------|-----------|----------|---------|-----|
| — | — | — | W-15, W-16 closed (switch theme; tokens in `dosis_card` / `carne_resumen_section`). I-10 fixed (`dosis_card.dart:303` uses `onSurfaceVariant`). | — |
| SW-07 | 55 uses | INFO (I-12) | as above | I-12 |

### inventory
| Rule | file:line | Severity | Finding | Fix |
|------|-----------|----------|---------|-----|
| — | — | — | W-20..W-22, W-28 (`insignia_stock.dart:89` `labelLarge`), W-29 (header while loading, 08-09 `INVENTARIO_BARRIDO_OK`) closed. I-11 comment verified by 08-09. | — |
| SW-07 | 23 uses | INFO (I-12) | as above | I-12 |

### billing
| Rule | file:line | Severity | Finding | Fix |
|------|-----------|----------|---------|-----|
| — | — | — | W-23..W-25, W-30 closed (FAB theme, `AppButton` in every sheet, `linea_cobro_tile` spacing token). | — |
| SW-06/SW-07 | `billing/presentation/widgets/linea_cobro_tile.dart:217-221` | INFO (I-13) | "Quitar" `IconButton` has a `Semantics` label but no `tooltip`, and its icon is `AppColors.foreground` (#201E1D), about 1.1:1 on the dark surface. | Add `tooltip: 'Quitar'` and use `colorScheme.onSurface`. |
| SW-07 | 63 uses (incl. `cobro_fila.dart:119`, `enviar_cobro_sheet.dart:248`, `servicio_chip.dart:52`, `tipo_cobro_toggle.dart:61` with `AppColors.foreground`) | INFO (I-12) | as above | I-12 |

### plan
| Rule | file:line | Severity | Finding | Fix |
|------|-----------|----------|---------|-----|
| — | — | — | W-18, W-19 closed (08-09). `plan_banner.dart:67` `AppColors.foreground` sits on the fixed light `warningBg` fill in both modes, so it is readable. | — |
| SW-07 | 26 uses (incl. `mi_plan_screen.dart:148` `AppColors.foreground`) | INFO (I-12) | as above | I-12 |

### team
| Rule | file:line | Severity | Finding | Fix |
|------|-----------|----------|---------|-----|
| — | — | — | W-17 closed (08-10). | — |
| SW-07 | 17 uses | INFO (I-12) | as above | I-12 |

### clinic
| Rule | file:line | Severity | Finding | Fix |
|------|-----------|----------|---------|-----|
| SW-07 | 6 uses | INFO (I-12) | as above | I-12 |

### lib/core/widgets
| Rule | file:line | Severity | Finding | Fix |
|------|-----------|----------|---------|-----|
| — | — | — | W-26 closed (no literal 6/8 left in `app_status_chip`, `app_text_field`, `app_button`); W-27 closed (`app_theme.dart:175-239` switch, checkbox, FAB, dialog, snackBar, datePicker and bottomSheet themes). Raw Material widgets only inside the core wrappers (allowed by UI-SPEC Exemptions). | — |

## W-01..W-30 closure

| ID | Closed by | Evidence | Status |
|----|-----------|----------|--------|
| W-01 | 08-11 | `AUTH_BARRIDO_OK`; SW-04 gate 0 hits in `client_home_screen.dart` | closed |
| W-02 | 08-11 | `grep -rn "onPressed: () {}" lib` empty | closed |
| W-03 | 08-11 | `AUTH_LOGIN_OK`; no raw `TextButton` | closed |
| W-04 | 08-11 | `AUTH_LOGIN_OK`; SW-04 gate clean | closed |
| W-05 | 08-02 | FAB themed (`THEME_OK`), exempted in the gate | closed |
| W-06 | 08-07 | `AGENDA_BOTONES_OK` | closed |
| W-07 | 08-07 | `AGENDA_BOTONES_OK` | closed |
| W-08 | 08-07 | `AGENDA_BOTONES_OK` | closed |
| W-09 | 08-07 | `AGENDA_BOTONES_OK` (destructive variant) | closed |
| W-10 | 08-07 | no `minimumSize`/`Size(48` in features | closed |
| W-11 | 08-07 | `AppButton` square mode; no `OutlinedButton` in features | closed |
| W-12 | 08-07 | `AGENDA_BARRIDO_OK`; SW-04 gate clean | closed |
| W-13 | 08-07 | `day_strip.dart:101` `minWidth: AppSpacing.touchTarget` | closed |
| W-14 | 08-02 | switch/checkbox themes (`THEME_OK`), exempted in the gate | closed |
| W-15 | 08-02 | switch theme (`THEME_OK`), exempted in the gate | closed |
| W-16 | 08-10 | `VACUNAS_BARRIDO_OK` | closed |
| W-17 | 08-10 | `EQUIPO_BARRIDO_OK` | closed |
| W-18 | 08-09 | `PLAN_BARRIDO_OK` | closed |
| W-19 | 08-09 | `uso_contador_tile.dart:54` `radiusSm` | closed |
| W-20 | 08-02 | FAB theme, exempted in the gate | closed |
| W-21 | 08-09 | `INVENTARIO_BARRIDO_OK` | closed |
| W-22 | 08-09 | `AppButton` square mode (`INVENTARIO_BARRIDO_OK`) | closed |
| W-23 | 08-02 | FAB theme, exempted in the gate | closed |
| W-24 | 08-08 | `COBRO_FORM_BARRIDO_OK`, `COBROS_BARRIDO_OK` | closed |
| W-25 | 08-08 | `COBRO_FORM_BARRIDO_OK`; SW-04 gate clean | closed |
| W-26 | 08-02 | `CORE_TOKENS_OK` | closed |
| W-27 | 08-02 | `THEME_OK`; 7 component themes in `app_theme.dart` | closed |
| W-28 | 08-09 | `insignia_stock.dart:89` `labelLarge` | closed |
| W-29 | 08-09 | `INVENTARIO_BARRIDO_OK` (VET-57) | closed |
| W-30 | 08-08 | same fix as W-24 (VET-78) | closed |

New WARN found by this re-audit: W-31 (SW-07, `mas_screen.dart:110,137,278`), fixed in home by `c3ca862`.

## INFO for Linear (team VetApp)

The executor session had no Linear tool, so no issue was created. Every item is **pendiente de Linear**.

| ID | Module label | Proposed title (es) | file:line | Suggested fix | Linear |
|----|--------------|---------------------|-----------|---------------|--------|
| I-04 | Pacientes | — (record only, allowed size) | `mascota_detail_screen.dart:192` | none | not needed |
| I-06 | Historia clínica | "(retirado)" en la historia clínica usa un color solo-claro | `historia_clinica_timeline.dart:182` | heredar el estilo y usar `colorScheme.onSurfaceVariant` | pendiente de Linear |
| I-07 | Agenda | Unificar el helper de fecha `yyyy-MM-dd` para rutas de agenda | `agenda_screen.dart:392`, `cita_form_screen.dart:434`, `completar_cita_screen.dart:83` | un helper en `core/utils` con prueba | pendiente de Linear |
| I-12 | Plataforma y Calidad (todos los módulos) | Contraste en modo oscuro: constantes de texto solo-claro en pantallas existentes | `lib/features/**`: `textMuted` 111, `textSecondary` 98, `primaryText` 32, `success` 23, `foreground` 11 usos fuera de home | cambiar a `colorScheme.onSurfaceVariant` / `textSecondaryDark` / `primaryHover`, pantalla por pantalla, confirmando con las capturas oscuras de 08-16 F9 (D-18 limitó el barrido a las pantallas nuevas) | pendiente de Linear |
| I-13 | Cobros | Botón "Quitar" de la línea de cobro sin tooltip y con icono solo-claro | `linea_cobro_tile.dart:217-221` | `tooltip: 'Quitar'` y `colorScheme.onSurface` | pendiente de Linear |
| I-14 | Plataforma y Calidad | Mover `esErrorDeRed` a `core/` | `inventory/data/repositories/supabase_inventario_repository.dart:330`, importado por appointments, billing y home | `core/data/errores_red.dart` y reexportar | pendiente de Linear |

The baseline mentioned "billing x2, core x2" INFO without itemizing them; the re-audit found no other billing or core INFO beyond I-13 and the core items already closed in W-26/W-27.

BRAND-AUDIT: 0 BLOCKER, 0 WARN abiertos
