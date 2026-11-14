---
phase: 07-facturaci-n
plan: 07
subsystem: billing-ui
tags: [billing, cobros, flutter, riverpod, go_router, tdd, idempotency]
requires: ["07-02", "07-03", "07-05"]
provides:
  - "ModoFormCobro, PrefillCobro, LineaBorrador, BorradorCobro, BorradorCobroNotifier, borradorCobroProvider (autoDispose family), claveIdempotenciaProvider"
  - "CobroFormScreen (new CC / new quote): tipo toggle, client picker, pet chips, services A-Z + Otro, editable lines, pinned total, emit flow"
  - "ServicioChip, LineaCobroTile (notaStock/errorStock params ready for 07-11), TotalCobroBar, ElegirClienteSheet"
  - "GoRoute '/cobros/nuevo' declared before '/cobros/:id' (parses tipo, clienteId, mascotaId, citaId, consultaId, desdeCobroId -> ModoFormCobro.copiar)"
affects: [lib/features/billing/presentation/cobros_routes.dart]
tech-stack:
  added: []
  patterns:
    - "Riverpod 3 NotifierProvider.autoDispose.family with a constructor arg (PrefillCobro record)"
    - "Idempotency key created once in Notifier.build() from an injectable generator; never regenerated on failure"
    - "submit -> on CobroFailure -> manejarLimitePlan first -> banner by ErrorCobro; finally clears loading"
    - "Messenger and GoRouter captured before await; pushReplacement(rutaCobro(id)) + snackbar"
    - "PopScope(canPop: descartado || !sucio) + discard dialog"
key-files:
  created:
    - lib/features/billing/presentation/providers/borrador_cobro_provider.dart
    - lib/features/billing/presentation/screens/cobro_form_screen.dart
    - lib/features/billing/presentation/widgets/servicio_chip.dart
    - lib/features/billing/presentation/widgets/linea_cobro_tile.dart
    - lib/features/billing/presentation/widgets/total_cobro_bar.dart
    - lib/features/billing/presentation/widgets/elegir_cliente_sheet.dart
    - test/borrador_cobro_test.dart
    - test/cobro_form_screen_test.dart
  modified:
    - lib/features/billing/presentation/cobros_routes.dart
    - test/router_cobros_cross_shell_test.dart
decisions:
  - "BorradorCobro carries an extra clienteInicialId (the prefilled client) so `sucio` can tell 'a client was chosen/changed' apart from a prefilled one; the contract fields are unchanged"
  - "In ModoFormCobro.convertir the notifier copies prefill.origenId into cotizacionId (07-15 fills the lines); nuevo/copiar leave it null"
  - "The CC confirmation uses a separate _confirmando guard (not _loading) so the CTA does not show a spinner behind the dialog, yet a second tap while the dialog is open is ignored"
  - "The disabled CTA is a custom surfaceMuted container (no opacity) wrapped in a GestureDetector that reports the first missing validation"
  - "Client search in ElegirClienteSheet is local and accent-insensitive ('gom' finds 'Gómez'), same folding as biologico_picker_sheet"
metrics:
  tasks: 3
  commits: 7
  tests_added: 41
  full_suite: 1270
  completed: 2026-11-13
---

# Phase 7 Plan 07: Issue a cuenta de cobro or quote (core slice) Summary

The vet can now open "Nueva cuenta de cobro" / "Nueva cotización" from Cobros, choose the client (and optionally a pet), add saved services or free "Otro" lines, edit quantity and price per line, watch the total live and emit it. A CC asks for one confirmation, then opens its detail with "Cuenta de cobro CC-0001 emitida."; a quote is saved directly. The draft holds one idempotency key for its whole life, so a retry after "Sin conexión" sends the same `p_clave` and never duplicates.

## Tasks

| # | Task | RED commit | GREEN commit | Result |
|---|------|-----------|--------------|--------|
| 1 | Draft model + BorradorCobroNotifier with stable key | `8014707` | `040e121` | ✅ BORRADOR_OK |
| 2 | CobroFormScreen layout + 4 widgets | `b3442f6` | `e1e55ca` | ✅ FORM_LAYOUT_OK |
| 3 | Emit flow, failures with same key, discard, `/cobros/nuevo` | `f712eb6` | `f2a96f0` (+ `913ba60` test tidy) | ✅ SLICE_EMITIR_OK |

## Per-task evidence

All `<automated>` commands ran from the worktree root (`cd /c/Trabajo/VetApp` replaced by the worktree path), at final HEAD.

### Task 1: ✅
- RED: `flutter test test/borrador_cobro_test.dart` failed to compile (`Method not found: 'borradorCobroProvider'`), `00:00 +0 -1: Some tests failed.`
- GREEN:
  - `No issues found! (ran in 3.7s)`
  - `00:00 +17: All tests passed!`
  - `BORRADOR_OK`
- The behavior bullets map to tests one by one:
  - **clave:** generated once (counter == 1 after edits); a new clave after dispose.
  - **services:** same service twice gives cantidad 2 / subtotal 100000; a second service adds a second line.
  - **Otro:** empty, with a null price.
  - **cambiarPrecio:** keeps precioBaseCop and the Servicio stays untouched.
  - **cantidad:** clamps 0 to 1; quitar removes the line.
  - **totalCop:** a null price counts 0.
  - **vinculado:** keeps the mascota.
  - **unlinked:** elegirCliente clears it.
  - **lineasNuevas:** keeps the servicioId and sends a null price as 0.
  - **sucio:** covers both cases.

### Task 2: ✅
- RED: `flutter test test/cobro_form_screen_test.dart` failed to compile (missing screen and widgets), `Some tests failed.`
- GREEN:
  - `No issues found! (ran in 8.3s)`
  - `00:06 +35: All tests passed!` (the file also contains the Task 3 cases at final HEAD; 19 layout tests at the Task 2 commit: `00:02 +19: All tests passed!`)
  - `FORM_LAYOUT_OK`
- Covered:
  - **Titles and CTA:** they follow the toggle and the lines are kept.
  - **Empty client row:** at least 48dp; the sheet opens.
  - **Client search:**
    - 'gom' finds only Laura Gómez;
    - 'xyz' shows «xyz» empty text;
    - picking a client shows the read-only row + Cambiar.
  - **Prefilled client:** shows Cambiar; linked (citaId) has no Cambiar and a read-only pet.
  - **Pet chips:** select and deselect; a client without pets hides the section, and so does having no client.
  - **Service chips:** A–Z then Otro; semantics 'Agregar Consulta, $ 50.000'; tap adds a line and a second tap makes qty 2.
  - **No services:** shows the text. An admin also sees 'Agregar servicios', which pushes /servicios; a non-admin does not.
  - **Otro:** autofocused 'Ej. Baño medicado'.
  - **Steppers:**
    - '−' does nothing at 1 and has no Opacity;
    - '+' increments, with a cap at 999;
    - semantics read 'Disminuir/Aumentar cantidad de Consulta' and 'Quitar Consulta'.
  - **Price 40000:** shows 'Precio base $ 50.000' and 'Subtotal $ 80.000'.
  - **Disabled bar taps:** show 'Elige el cliente.' or 'Agrega al menos un servicio o producto.'.
  - **Line errors:** 'Escribe la descripción.' and 'Escribe el precio (puede ser 0).'.
  - **Total errors:** 'El total debe ser mayor que $ 0.' and 'El total es demasiado alto.'.
  - **Forbidden content:** no text matching 'actura|escuento'.

### Task 3: ✅
- RED: 16 new cases failed (`00:08 +25 -16: Some tests failed.`).
- GREEN (full `<automated>` block, including the full suite):
  - `No issues found! (ran in 9.2s)`
  - `00:06 +41: All tests passed!` (cobro_form_screen_test + router_cobros_cross_shell_test)
  - `00:42 +1270: All tests passed!` (full `flutter test`)
  - `SLICE_EMITIR_OK`
- Covered:
  - **CC confirmation:** shows the dialog title and the exact body. 'Revisar' makes no call; 'Emitir' makes exactly one `crearCuentaCobro` with `clave-1`, `cli1` and servicioId `s1`. Then 'Detalle cobro-1' opens with the snackbar 'Cuenta de cobro CC-0001 emitida.' (also when yaExistia).
  - **Quote:** saved without a dialog, 'Cotización COT-0001 guardada.'.
  - **sinConexion:**
    - warningBg banner with wifi_off and both texts;
    - 2 lines kept and the CTA label unchanged;
    - **the retry sends the identical `clave` (asserted from `llamadas[0..1].args['clave']`)**.
  - **Other failures:**
    - generic CC and quote banners, without the raw message;
    - visitaYaCobrada shows the failure message;
    - stockInsuficiente shows 'Revisa las cantidades marcadas.';
    - LP004 opens 'Tu cuenta está en solo lectura' with no snackbar, keeping the form and its line.
  - **In flight (bloqueoCrear):**
    - the bar shows a spinner and LineaCobroTile.habilitado is false;
    - a second CTA tap and a chip tap give **exactly 1 call**;
    - the CC double tap after 'Emitir' also gives 1 call.
  - **Leaving:**
    - dirty: '¿Descartar este cobro?' / 'Se perderán las líneas que agregaste.'; 'Seguir editando' stays, 'Descartar' pops;
    - clean: pops without a dialog.
  - **Route:**
    - `/cobros/nuevo?tipo=cot&clienteId=cli1` opens the quote prefilled with cli1;
    - `/cobros/nuevo` opens the form and never CobroDetailScreen;
    - all query params are parsed, and desdeCobroId gives ModoFormCobro.copiar.
  - **Real router:** Más → Cobros → FAB lands on `/cobros/nuevo` with CobroFormScreen and a single AppShell (G5); pop returns to `/cobros`.
- Route order check: `/cobros/nuevo` (line 29) is declared before `'/cobros/:id'` (line 47) in `cobros_routes.dart`.

## Deviations from Plan

### Auto-fixed / adjusted

1. **[Rule 2 - Correctness] `clienteInicialId` on BorradorCobro.** Without the prefilled client the draft could not know whether a client was "chosen when not prefilled", which `sucio` needs. The extra field was added; the contract fields and getters are unchanged. Commit `040e121`.
2. **[Layout] The total bar sits in a `Column`, not an overlay.** The bar is the last child of the body `Column`, under an `Expanded` scroll, so it can never cover the last line. It rises with the keyboard through `resizeToAvoidBottomInset`. The "scroll bottom padding = bar height + 16" rule only matters for an overlaid bar, so the scroll keeps the plain 16px padding. Commit `e1e55ca`.
3. **[Accessibility] Visible labels on the quantity and price fields.** The stepper got a visible Label "Cantidad" and the price field keeps its visible label "Precio unitario". This follows the design system rule that labels are never placeholder-only. Commit `e1e55ca`.
4. **[Rule 1] Comment wording.** A doc comment in `total_cobro_bar.dart` contained "descuento" and tripped the forbidden-word grep, so it was reworded. Commit `e1e55ca`.
5. **[Tooling] Generated plugin registrants.** `flutter analyze`/`test` runs `pub get`, which rewrote the generated plugin registrants under `linux/`, `macos/` and `windows/`. They are not plan files, so each time they were restored with a file-specific `git checkout --` and never committed.
6. **[Test] Missed-tap warning.** The in-flight test taps a chip while the inputs are blocked, which is intentional. It now passes `warnIfMissed: false` with a comment. Commit `913ba60`.

STATE.md, ROADMAP.md and 07-VALIDATION.md were not touched (parallel wave; the orchestrator consolidates).

## Known Stubs

- `LineaCobroTile.notaStock` / `errorStock`: the screen does not fill them yet. Product lines and stock arrive in 07-11, which only passes values.
- There is no "Agregar producto" button yet (07-11).
- Edit, convert and copy modes are parsed or typed only. The `ModoFormCobro.copiar` route parsing exists, and 07-15 fills the content.

None of these blocks this plan's goal: services and Otro lines are fully wired to the real `cobrosActionsProvider`.

## Threat Flags

None. No new endpoints. The form calls only the existing 07-02 actions:
- **T-07-32:** one clave and the in-flight guard, both tested.
- **T-07-33:** the total is a preview only and the detail shows the server's total.
- **T-07-35:** only `CobroFailure.message` or fixed Spanish copy is shown.

## Self-Check: PASSED

- All 8 created files and 2 modified files exist (verified in the worktree).
- Commits `8014707`, `040e121`, `b3442f6`, `e1e55ca`, `f712eb6`, `f2a96f0` and `913ba60` are present in `git log 0825d2e..HEAD`.
