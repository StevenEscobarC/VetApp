---
phase: 07-facturaci-n
plan: 09
subsystem: billing
tags: [pdf, whatsapp, share, payment, read-only, tdd]
requires: ["07-02", "07-03", "07-05"]
provides:
  - CobroPdfService (generar, nombreArchivo, filasPdf, textosPdf)
  - cobroPdfServiceProvider, compartirCobroProvider (CompartirPdfConTexto)
  - showEnviarCobroSheet(context, cobro)
  - showMarcarPagadaSheet(context, cobro)
  - CobroDetailScreen._acciones switch for CC pendiente / CC pagada
affects: [07-12, 07-15]
tech-stack:
  added: []
  patterns:
    - "Typed text record (_Textos) feeds both the PDF widgets and textosPdf, so tests check printed content without parsing the PDF"
    - "_acciones is a switch over (c.tipo, c.estado); later plans add cases"
key-files:
  created:
    - lib/features/billing/data/services/cobro_pdf_service.dart
    - lib/features/billing/presentation/providers/cobro_pdf_providers.dart
    - lib/features/billing/presentation/widgets/enviar_cobro_sheet.dart
    - lib/features/billing/presentation/widgets/marcar_pagada_sheet.dart
    - test/helpers/fake_compartir_cobro.dart
    - test/cobro_pdf_service_test.dart
    - test/compartir_cobro_test.dart
    - test/marcar_pagada_sheet_test.dart
  modified:
    - lib/features/billing/presentation/screens/cobro_detail_screen.dart
    - test/cobro_detail_screen_test.dart
decisions:
  - "The PDF prints no legal disclaimer (D-01 wins over RESEARCH); the title alone says what the document is"
  - "Quote parties block reads 'Cliente: {nombre}'; CC uses the 'Cliente' label + bold name (UI-SPEC PDF §2)"
  - "MarcarPagadaSheet maps failures by ErrorCobro tipo to the UI-SPEC §4.1 copy; estadoInvalido also disables the CTA"
  - "EnviarCobroSheet uses one busy flag for all three rows, so taps on any row are ignored while another action runs"
metrics:
  duration: "~45 min"
  completed: 2026-11-14
  tasks: 3
  files: 10
---

# Phase 7 Plan 09: Cobro PDF, Enviar al cliente and Marcar como pagada Summary

The PDF for a quote or cuenta de cobro uses the carnet layout family: clinic header with 'NIT o cédula', parties, 'Debe a' and 'La suma de: … pesos', the Cant. × Valor unitario table, the state block and the 'Hecho con VetApp' footer. It never prints the client's phone or any forbidden word. The vet sends it from an "Enviar al cliente" sheet: PDF + formal caption to WhatsApp, a wa.me chat to the client's +57 number (opened in the app only), or a plain share. A pending CC is marked paid from a method + date sheet. The detail action block now covers CC pendiente (pay is the primary, with a padlock in read-only) and CC pagada (send is the primary).

## Tasks

| # | Task | RED commit | GREEN commit | Evidence |
|---|------|-----------|--------------|----------|
| 1 | CobroPdfService + PDF/share providers | `4dc4aae` | `383731d` | ✅ `PDF_COBRO_OK`, `test/cobro_pdf_service_test.dart` 16/16 |
| 2 | EnviarCobroSheet + test seam | `b363b69` | `529310c` | ✅ `ENVIAR_COBRO_OK`, `test/compartir_cobro_test.dart` 13/13 |
| 3 | MarcarPagadaSheet + detail actions | `4087007` | `3b1cafa` | ✅ `SLICE_PAGO_PDF_OK`, 4 slice files 55/55, full suite 1260/1260 |

TDD gates: every task has a `test(07-09)` RED commit followed by a `feat(07-09)` GREEN commit. RED was confirmed by a failing run each time: compile errors for the missing service, sheet and file, plus the 5 failing detail-action cases. No refactor commits were needed.

### Task 1 evidence (run from the worktree root)

```
flutter analyze lib/features/billing test/cobro_pdf_service_test.dart  -> No issues found! (ran in 4.8s)
flutter test test/cobro_pdf_service_test.dart                         -> 00:00 +16: All tests passed!
grep checks (no factur/IVA/DIAN, 'Hecho con VetApp', pesosEnLetras, no copied typedefs) -> PDF_COBRO_OK
```

Each behavior bullet maps to a test:
- textosPdf order for a pending CC;
- paid, voided, quote and converted-quote variants;
- no NIT and no cédula;
- filasPdf;
- forbidden regex plus the client phone check over textosPdf, filasPdf and nombreArchivo, for 5 document states;
- generation that returns %PDF bytes;
- the logo loader is not called without a logoPath;
- the loader throws or the image is corrupt (real `dart:ui` validator), and generation still succeeds;
- failing fonts give the CobroFailure message;
- nombreArchivo.

### Task 2 evidence

```
flutter analyze lib/features/billing test/compartir_cobro_test.dart -> No issues found! (ran in 6.2s)
flutter test test/compartir_cobro_test.dart                        -> 00:01 +13: All tests passed!
grep abrirEnApp present, no 'enlace'/'factur' in the sheet          -> ENVIAR_COBRO_OK
```

The tests cover:
- the header and the subtitle with '(+57 300 123 4567)';
- 'Generando PDF…' while busy;
- the filename and a caption equal to `mensajeCobroWhatsApp(...)`;
- double tap generates once;
- wa.me via `abrirEnApp` equals `whatsappUri('573001234567', …)`;
- the `abrirEnApp=false` snackbar;
- a landline or no phone disables the row with the reason, without Opacity;
- a null clienteId hides the chat row;
- 'Compartir PDF' passes texto null;
- the PDF and share failure messages;
- the quote caption 'Es válida hasta el 28/11/2026' and the paid caption;
- no 'enlace'/'link' text and no padlock.

### Task 3 evidence

```
flutter analyze                                   -> No issues found! (ran in 12.0s)
flutter test <4 slice files>                      -> 00:02 +55: All tests passed!
! grep -rni "factur" lib/features/billing         -> (no matches)
flutter test                                      -> 00:46 +1260: All tests passed!
                                                  -> SLICE_PAGO_PDF_OK
```

The sheet tests cover:
- the header 'CC-0012 · $ 120.000';
- the 6 chips in order with none selected;
- the CTA disabled with no Opacity and the helper 'Elige cómo pagó.';
- 'Hoy, 13/11/2026';
- the picker bounded to [01/11/2026, 13/11/2026], and a picked past date shows as '05/11/2026' and is sent as `DateTime.utc(2026,11,5)`;
- Nequi + confirm calls `marcarPagado(nequi, fecha null)`, closes the sheet and shows 'CC-0012 marcada como pagada.' with no Deshacer;
- inline sinConexion, estadoInvalido (CTA disabled) and otro failures;
- LP004 opens the plan sheet.

The detail tests cover:
- pending: exactly one primary (`payments_outlined`) plus the outline 'Enviar al cliente' (`ios_share`);
- paid: exactly one primary 'Enviar al cliente';
- voided: neither action;
- read-only: `lock_outline` and the 'bloqueado, solo lectura' semantics, the tap opens LimitePlanSheet, and 'Enviar al cliente' still opens the sheet;
- after paying, the detail re-reads and shows 'Pagada el 13/11/2026 · Nequi'.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The message signature was empty on first tap**
- **Found during:** Task 2 GREEN
- **Issue:** `authProfileProvider` was only `read`, so it was still loading when tapped. The caption signed with the clinic only.
- **Fix:** the sheet `watch`es `authProfileProvider` in build.
- **Files modified:** `enviar_cobro_sheet.dart`
- **Commit:** `529310c`

**2. [Rule 3 - Blocking] The doc comment contained 'enlace'**
- **Issue:** the comment tripped the plan's `! grep -qi "enlace\|factur"` check.
- **Fix:** reworded to "No publica nada en la web".
- **Commit:** `529310c`

**3. [Test harness] Extended the existing detail test harness**
- `_abrir` in `test/cobro_detail_screen_test.dart` now takes an optional `MiPlan? plan` and overrides `clienteProvider`.
- This lets the action tests open the share sheet and cover read-only.
- The existing cases are unchanged.

### Notes
- `flutter pub get` rewrote the generated plugin registrants (linux/macos/windows). These are tool output outside this plan, so I restored them with per-file `git checkout --` and did not commit them.
- Scope: only the files listed in the plan were touched. In `cobro_detail_screen.dart`, only `_acciones` changed (it is now a `switch ((c.tipo, c.estado))` over the two new private action widgets), plus the imports it needs. I did not touch `cobros_routes.dart` (07-07) or any services (07-10).
- `07-VALIDATION.md` was not edited (W3 override). STATE.md and ROADMAP.md were not updated, because the orchestrator records parallel-wave evidence and state once per wave.

## Known Stubs

None. Quote and voided-CC actions return `SizedBox.shrink()` on purpose, until 07-12/07-15 (stated in the plan objective).

## Threat Flags

None. No new endpoints or links. The PDF and the caption leave the device only through the user-initiated share sheet or `abrirEnApp` (T-07-40..42). Pay is guarded by `ControlEscritura` + `asegurarEscritura` plus an in-flight lock (T-07-43). `logoPath` comes from the server payload (T-07-44).

## Self-Check: PASSED

- All 8 created files and 2 modified files exist in the worktree.
- Commits 4dc4aae, 383731d, b363b69, 529310c, 4087007, 3b1cafa are present on `worktree-agent-acafd48ae441a2dcf`.
