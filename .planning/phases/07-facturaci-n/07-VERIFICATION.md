---
phase: 07-facturaci-n
verified: 2026-11-16T23:30:00-05:00
status: passed
score: 4/4 must-haves verified
overrides_applied: 0
accepted_open_items:
  - item: "F11 (colega en solo lectura) no corrido en vivo"
    reason: "Sin sesión del colega. Cubierto por el smoke T22/T30 (293 PASS en vivo) y los tests de widget de solo lectura"
    accepted_by: "usuario (sign-off 'Aprobado')"
    accepted_at: "2026-11-16"
  - item: "Revisión del texto de la cuenta de cobro con un contador"
    reason: "Decisión legal, no de código. Queda abierta para el usuario antes de cobrar a clínicas por esta función"
    accepted_by: "usuario"
    accepted_at: "2026-11-16"
  - item: "INFO IN-01..IN-08 de 07-REVIEW.md e INFO de 07-BRAND-AUDIT.md"
    reason: "Deuda registrada, no bloquea el objetivo"
    accepted_by: "usuario"
    accepted_at: "2026-11-16"
---

# Phase 7: Facturación — Verification Report

**Phase Goal:** El veterinario puede cobrar sus consultas y productos con una cotización/factura simple, y el inventario se actualiza solo.
**Mode:** mvp. Outcome clause: "cobrar con una cotización/factura simple, y el inventario se actualiza solo".
**Verified:** 2026-11-16
**Status:** passed
**Re-verification:** No. This is the first verification (there was no earlier 07-VERIFICATION.md).

Vocabulary note (D-01): the app never says "Factura". It uses **Cuenta de cobro (CC-NNNN)** and **Cotización (COT-NNNN)**. The roadmap's "factura" maps to the cuenta de cobro.

## User Flow Coverage (MVP)

| Paso | Esperado | Evidencia en código | Estado |
|------|----------|---------------------|--------|
| Entrar a Cobros | Más > Cobros abre la lista | `lib/features/home/presentation/screens/mas_screen.dart:237-241` (`context.push(kRutaCobros)`); rutas en `lib/core/router/app_router.dart:97-98`; `lib/features/billing/presentation/cobros_routes.dart:21,29,47,61,75` | VERIFIED |
| Crear CC/cotización con varias líneas | Servicios, productos y "Otro", con el precio editable | `lib/features/billing/presentation/screens/cobro_form_screen.dart:245` (selector de producto), `:699` (chip "Otro"), `:394` (`_emitir`); borrador con `List<LineaBorrador>` en `lib/features/billing/presentation/providers/borrador_cobro_provider.dart:111,118` | VERIFIED |
| Emitir en el servidor | RPC atómica, numerada e idempotente | `lib/features/billing/data/repositories/supabase_cobros_repository.dart:205` (`crear_cuenta_cobro`), `:219` (`crear_cotizacion`); `supabase/schema.sql:4937` | VERIFIED |
| El stock se descuenta solo | Movimiento "venta" con origen factura en la misma transacción | `supabase/schema.sql:4918-4927` → `_aplicar_movimiento_stock` en `:4737-4785` (update de `productos` en `:4775`, movimiento en `:4777-4781`); se llama desde `crear_cuenta_cobro` en `:5074` con `p_descontar=true` | VERIFIED |
| Marcar como pagada | Método y fecha; el estado pasa de pendiente a pagada | `lib/features/billing/presentation/screens/cobro_detail_screen.dart:259-272` → `widgets/marcar_pagada_sheet.dart:80` → `providers/cobros_providers.dart:199-205` → `supabase_cobros_repository.dart:261` → `supabase/schema.sql:5190-5231` | VERIFIED |
| PDF al cliente | Se genera el PDF y sale por WhatsApp o por la hoja de compartir | `widgets/enviar_cobro_sheet.dart:95-112` → `data/services/cobro_pdf_service.dart:220,239` (pw.Document) → `providers/cobro_pdf_providers.dart:36` (`Printing.sharePdf`); los datos vienen de `cobro_para_pdf` (`supabase/schema.sql:5388`) | VERIFIED |

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | El veterinario puede generar una cotización o factura simple en PDF para un cliente | VERIFIED | `cobro_pdf_service.dart:53` (`CobroPdfService`), `:220` (`generar`). Contenido: cliente y cédula en `:116,171`; título según el tipo y la validez de la cotización en `:131-135`; valor en letras en `:180`; líneas en `:211-216`; total en `:390`; nombre de archivo en `:420-423`. Los datos salen de la RPC `cobro_para_pdf` (`supabase/schema.sql:5388`, grant en `:5641`), que lee el repositorio en `supabase_cobros_repository.dart:323`. Se comparte en `enviar_cobro_sheet.dart:100-112` y `cobro_pdf_providers.dart:36`. Desde el detalle se llega en `cobro_detail_screen.dart:161,204,282,306`. Tests: `test/cobro_pdf_service_test.dart:122,144,157,171`. QA F6 PASS (re-QA) |
| 2 | Una factura puede incluir uno o más ítems (servicios/productos) con precio | VERIFIED | Tabla `cobro_items` (`supabase/schema.sql:4629`), con tipo `servicio/producto/otro`, cantidad 1..100000, `precio_unitario_cop` y orden 1..50. `_insertar_items_cobro` (`:4883`) inserta todas las líneas del payload jsonb. Entidades: `cobro_item.dart:2,21,45`. Total del borrador en `borrador_cobro_provider.dart:118`. Formulario en `cobro_form_screen.dart:245,699,741`. Tests: `test/cobro_form_screen_test.dart:331,418`; smoke T4 y T11 (`supabase/tests/rls_smoke_test.sql:5354,5573`). QA F3 PASS (cantidad 2, "Otro", precio cambiado) |
| 3 | Al facturar un producto de inventario, el stock se descuenta automáticamente | VERIFIED | `supabase/schema.sql:4918-4927` agrupa las líneas de producto y llama a `_aplicar_movimiento_stock(..., -cantidad, 'venta', ...)`. El helper (`:4737-4785`) bloquea la fila, rechaza el stock negativo con IN001 (`:4769-4772`), actualiza `productos.cantidad` (`:4775`) y deja el movimiento con origen `'factura'` (`:4777-4781`). No tiene grant a authenticated (`:4787`). Lo llama `crear_cuenta_cobro` (`:5074`). La cotización nunca descuenta (`:5174`, `p_descontar=false`). Anular devuelve el stock (`:5275`). En el cliente se refresca el inventario en `cobros_providers.dart:99-103` (`invalidarInventario`) y IN001 se mapea en `supabase_cobros_repository.dart:538`. Smoke T5, T6, T8, T17 y T19 (`rls_smoke_test.sql:5407,5428,5488,5801,5875`). Tests: `cobro_form_screen_test.dart:888,1145,1188`. QA F4 PASS |
| 4 | El veterinario puede marcar una factura como pagada/pendiente | VERIFIED | Los estados `pendiente/pagada/anulada` se exigen por tipo en `supabase/schema.sql` (constraint `cobros_estado_por_tipo` y `cobros_pago_consistente`, en el bloque `:4579-4628`). La RPC `marcar_cobro_pagado` (`:5190-5231`) es idempotente, toma el método de una lista fija y una fecha entre la emisión y hoy. La cadena UI→RPC está completa (ver la tabla de flujo). Enum `EstadoCobro` en `cobro.dart:26`, `MetodoPago` en `:50`. Filtro Pendientes/Pagadas en el servidor en `cobros_screen.dart:46,117-120`. Según D-15 (`07-CONTEXT.md:68-70`), pagada vuelve a pendiente solo anulando la CC, y eso está implementado en `anular_cobro`. Tests: `test/cobro_detail_screen_test.dart:209,399`; smoke T15 (`rls_smoke_test.sql:5703`). QA F5 PASS |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `supabase/schema.sql` Phase 7 block (`:4547-5647`) | VERIFIED | 4 tablas, RLS solo SELECT (`:4700,4704,4708`), RPC definer con grants (`:5627-5647`) |
| `lib/features/billing/data/repositories/supabase_cobros_repository.dart` (623 lines) | VERIFIED + WIRED | Llama a las 9 RPC; traduce los errores a `CobroFailure` |
| `lib/features/billing/data/services/cobro_pdf_service.dart` (426 lines) | VERIFIED + WIRED | Lo usa `enviar_cobro_sheet.dart:102` |
| `lib/features/billing/presentation/screens/*` (form 1044, detail 759, list 411, servicios 346 lines) | VERIFIED + WIRED | Rutas registradas en `app_router.dart:97-98` |
| `lib/features/billing/presentation/providers/cobros_providers.dart` | VERIFIED + WIRED | `invalidarCobros` también refresca el inventario |
| `supabase/tests/rls_smoke_test.sql` | VERIFIED | 293 `checks := checks + 1`; el encabezado dice "Total esperado: 293" (`:38`) |

### Key Link Verification

| From | To | Via | Status |
|------|----|-----|--------|
| Form `_emitir` | `crear_cuenta_cobro` / `crear_cotizacion` | `cobrosActionsProvider` → repositorio `:205,:219` | WIRED |
| `crear_cuenta_cobro` | `productos.cantidad` | `_insertar_items_cobro` → `_aplicar_movimiento_stock` (`schema.sql:5074 → 4926 → 4775`) | WIRED |
| Emitir/anular (client) | Inventory screens | `invalidarInventario` (`cobros_providers.dart:99-103`) | WIRED |
| Detail "Marcar como pagada" | `marcar_cobro_pagado` | sheet `:80` → providers `:205` → repositorio `:261` | WIRED |
| Hoja Enviar | PDF + share | `datosPdfCobroProvider` → `CobroPdfService.generar` → `Printing.sharePdf` | WIRED |
| Más | `/cobros` | `mas_screen.dart:241` | WIRED |

### Data-Flow Trace (Level 4)

| Artifact | Data | Source | Real data | Status |
|----------|------|--------|-----------|--------|
| Cobros list / resumen | `cobrosProvider`, `resumenCobrosProvider` | `cobros` (select under RLS, server-side filter), RPC `cobros_resumen` (`schema.sql:5359`) | Yes | FLOWING |
| PDF | `datosPdfCobroProvider` | RPC `cobro_para_pdf` (`schema.sql:5388`) | Yes | FLOWING |
| Stock tras emitir | `productos.cantidad` | Escrito en la transacción (`schema.sql:4775`) | Yes | FLOWING |

### Behavioral Spot-Checks (run by the verifier)

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Análisis estático | `flutter analyze` | `No issues found! (ran in 52.8s)` | PASS |
| Suite completa | `flutter test` | `01:12 +1468: All tests passed!` | PASS |
| Vocabulario (D-01) | `grep -rni "factur" lib --include=*.dart` sin `kOrigenCobro` | vacío. Solo queda `inventory/domain/entities/movimiento_stock.dart:61` | PASS |
| Capas | `supabase_flutter` dentro de `billing/presentation` o `billing/domain` | ninguno | PASS |
| Conteo del smoke | `grep -c "checks := checks + 1"` | 293 | PASS |

### Probe Execution

| Probe | Command | Result | Status |
|-------|---------|--------|--------|
| `supabase/tests/verify_live_schema.sh` | `timeout 60s bash supabase/tests/verify_live_schema.sh` | exit 0, `LIVE_SCHEMA_OK` (incluye los embeds de cobros, autor, ítems y anulador) | PASS |
| `supabase/tests/rls_smoke_test.sql` (live) | Lo pega el usuario en el SQL Editor (este verificador no puede correrlo) | `RLS SMOKE: PASS (293 checks) - cambios revertidos`, según `07-VALIDATION.md:166` y el commit `2f260c3` | Accepted (user-run) |

### Requirements Coverage

| Requirement | Plans | Status | Evidence |
|-------------|-------|--------|----------|
| BILL-01 (PDF de cotización/factura) | 13 plans | SATISFIED | Truth 1 |
| BILL-02 (uno o más ítems con precio) | 11 plans | SATISFIED | Truth 2 |
| BILL-03 (descuento automático de stock) | 7 plans | SATISFIED | Truth 3 |
| BILL-04 (pagada/pendiente) | 8 plans | SATISFIED | Truth 4 |

No requirements are orphaned. REQUIREMENTS.md maps only BILL-01..04 to Phase 7 (`.planning/REQUIREMENTS.md:84-87,162`). Those checkboxes and the ROADMAP plan list are still `[ ]`; the orchestrator updates them when it closes the phase.

### Review / Brand Closure

- 07-REVIEW: 1 critical and 6 warnings. All are closed in 07-17. Spot-checks in the code:
  - CR-01: the draft locks after a network failure (`cobro_form_screen.dart:40-41,91,520`).
  - WR-01: a retry with the same key is looked up again (`schema.sql:5029,5048`).
  - WR-02: the filter runs on the server (`cobros_screen.dart:46`).
  - WR-03: the local stock limit is now a warning (test `cobro_form_screen_test.dart:1145`).
  - WR-04: `p_nit default '__sin_cambio__'` (`schema.sql:5514`).
- 07-BRAND-AUDIT: `BRAND: PASS`, with 0 BLOCKER. The WARN about the emit dialog was fixed in `b1114ca`.

### Anti-Patterns Found

| File | Pattern | Severity |
|------|---------|----------|
| `lib/features/billing/**` | TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER | None found |

### Human Verification Required

None pending. The emulator QA ran F1..F12: F1-F10 and F12 PASS, and F11 BLOCKED. The user signed off with "Aprobado" (`07-VALIDATION.md:182`, `07-16-SUMMARY.md:17,46`). Items accepted by the user (listed in the frontmatter, not counted as gaps):
- F11 was not run live; the smoke and the widget tests cover it.
- The accountant review of the cuenta de cobro text is still open with the user.
- The INFO items IN-01..IN-08 remain as debt.

### Gaps Summary

None. All four success criteria are backed by real code from the UI to the RPC to Postgres. Stock moves atomically inside the same transaction that issues or voids the document. Analyze, the full suite and the live probe all pass when re-run by this verifier.

Documentation notes (not gaps):
- 07-VALIDATION.md frontmatter still says `status: planned`.
- The 07-16 rows in the task table are still `⬜ pending`, although the sign-off and evidence rows show them done.
- Plan 17 has no 07-17-PLAN.md (it is a gap-closure plan, documented in 07-17-SUMMARY.md).

---

_Verified: 2026-11-16_
_Verifier: Claude (gsd-verifier)_

VERIFICATION: passed
