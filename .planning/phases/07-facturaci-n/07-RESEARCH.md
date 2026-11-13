# Phase 7: Facturación - Research

**Researched:** 2026-11-13
**Domain:** Postgres transactional billing (numbering, idempotency, stock coupling) + Flutter PDF/share, on Supabase
**Confidence:** HIGH on the Postgres/Flutter design (grounded in the repo's own Phase 6 code); MEDIUM on Colombian legal wording (needs accountant review)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
D-01..D-24 in `.planning/phases/07-facturaci-n/07-CONTEXT.md` are locked. The ones that drive the design:
- **D-01** Two document types, Cotización and Cuenta de cobro. The word "Factura" never appears in the app, the PDFs or the client copy. The stub `factura.dart` is replaced.
- **D-02** Per-clinic sequential numbering assigned by the server (`COT-0001`, `CC-0001`). Never reused; a voided document keeps its number. The number is taken in the same transaction that creates the document.
- **D-03** No VAT. Whole COP, no decimals.
- **D-04** PDF header: clinic name, logo (5.1 D-06 plan rule), phone, address, optional "NIT o cédula" of the clinic (admin fills it in once).
- **D-05** Entry points: "Cobrar" (appointment or consultation, linked) and "Nueva cuenta de cobro" (Cobros and client profile, pet optional).
- **D-06** Service lines come from a saved services list (admin-only edit, default price COP) plus "Otro" (free text with price). Product lines come from active inventory only.
- **D-07** The price can be changed on a single line; the base price does not change.
- **D-08** No whole-document discount.
- **D-09** Quote to CC in one tap: lines copied and editable, new number, quote marked "Convertida en CC-00NN", stock checked and deducted then.
- **D-10** A CC is append-only: only voided with a reason. Quotes stay editable until converted.
- **D-11** Stock is deducted when the CC is issued (paid or not), through movements with origen `factura` and `ref_id` = the CC. The planner decides: extend `mover_stock` or a billing RPC.
- **D-12** Asking for more than the stock is blocked ("Solo quedan 2 frascos de Amoxicilina."). The whole CC fails atomically.
- **D-13** Voiding returns the stock with reverse movements in the same transaction ("Anulada CC-0012"). It is a separate operation of the billing RPC (the `ajuste`-only undo of 6 WR-04 stays).
- **D-14** Archived products cannot be added; existing lines show the copied description and price.
- **D-15** State is Pending or Paid. Method chips: Efectivo, Nequi, Daviplata, Transferencia, Tarjeta, Otro. Payment date defaults to today. No partial payments. Paid goes back to pending only together with voiding.
- **D-16** PDF to the client by WhatsApp (+57, formal "usted" message) plus the native share sheet. No public link.
- **D-17** Cobros header "Cobrado este mes" / "Por cobrar", Cotizaciones/Cuentas de cobro toggle, state cards (Pagada / Pendiente / Anulada / Convertida).
- **D-18** No plan limit (the 4 limits of 5.1 D-01 stay at 4).
- **D-19** Any active vet creates and marks paid, always with authorship. Voiding is for the admin or the issuing vet, with a reason. Read-only colleagues see but do not create: extend `guard_solo_lectura` and use `ControlEscritura`.
- **D-20** Cobros lives in Más next to Inventario. The "Cobrar" shortcuts go on completed appointments, consultations and the client profile.
- **D-21** No connection means a clear failure with no queue ("Sin conexión, el cobro no se creó."). The draft stays. The creation RPC takes an idempotency key per draft.
- **D-22** PDF follows the carnet and clinical history style. Contents: header, number, date dd/mm/aaaa, client and pet, lines (quantity × unit price), total COP, state and method, "Hecho con VetApp" footer.
- **D-23** Quote shows "Válida por 15 días" and the expiry date. The state never changes automatically.
- **D-24** The client PDF shows the full name and the cédula if available (new optional client field). The phone is not printed by default. The PDF goes only to the client.

### Claude's Discretion
- How the CC and its lines are modeled (header + items, description and price copied into each line), the RLS policies and the RPCs, following the Phase 6 pattern (security definer with a tenant check, smoke checks in `rls_smoke_test.sql`).
- How the saved services list is set up: first-time seed vs empty with a CTA.
- The exact layout of the form and the PDF, within the UI-SPEC from `/gsd-ui-phase 7`.

### Deferred Ideas (OUT OF SCOPE)
- DIAN electronic invoicing and VAT.
- Partial payments.
- A 10 per month limit on CCs in Free.
- Deducting stock when recording a dose.
- Inicio card, income charts and the "Factura" quick action (Phase 8).
- Public link for billing documents.
- Offline queue.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BILL-01 | Generate a quote or simple document as a PDF for a client | `cobros` header table with `tipo`, `cobro_para_pdf` read RPC, `CobroPdfService` (pdf + printing already in pubspec), legal wording in the Colombia section |
| BILL-02 | A document has one or more items (services/products) with price | `cobro_items` with description and price copied in; server-computed totals; `clinica_servicios` list |
| BILL-03 | Billing an inventory product deducts the stock automatically | `crear_cuenta_cobro` RPC with a private stock helper, `IN001` insufficient stock, `anular_cuenta_cobro` reversal, movements with origen `factura` |
| BILL-04 | Mark paid / pending | `marcar_cobro_pagado` RPC, state machine, `cobros_resumen` |
</phase_requirements>

## Summary

The phase fits cleanly on the Phase 6 foundation. Phase 6 already reserved `origen = 'factura'` and `motivo = 'venta'` in the `movimientos_inventario` check constraints. `mover_stock` deliberately accepts only `origen = 'ajuste'` (the WR-04 hardening). So the billing RPCs do not call `mover_stock`. They share a private helper (`_aplicar_movimiento_stock`, no grant to `authenticated`) that performs the `for update` lock, the no-negative check and the append-only ledger insert. `mover_stock` stays byte-for-byte unchanged, which protects the 261-check smoke baseline. [VERIFIED: supabase/schema.sql 4176-4547]

The core invariant is that one security-definer RPC does everything in one transaction: idempotency lookup, per-clinic counter increment, header and items insert, stock movements. If any step raises (insufficient stock, invalid product), the plpgsql exception rolls back the counter increment too. So numbers stay gapless, which a Postgres `SEQUENCE` cannot guarantee. A counter table with `INSERT ... ON CONFLICT DO UPDATE ... RETURNING` serializes concurrent issuance per clinic and is rolled back with the transaction. [CITED: postgresql.org/docs/current/sql-createsequence.html — "sequences are never rolled back"]

Legally, a "cuenta de cobro" is an informal document, not a DIAN invoice, and has no single mandated format. It is the document used by natural persons who are not VAT-responsible. Two risks need an accountant: (a) a clinic that is a legal entity (persona jurídica) must issue electronic invoices; (b) selling goods (inventory products) may not fit a pure cuenta de cobro for services. Mitigation: the issuer's NIT/cédula, an explicit disclaimer line on the PDF, and never the word "factura". The legal reading is reported as MEDIUM and flagged for review (Assumptions A1-A3).

**Primary recommendation:** Add one `cobros` header table (type `cotizacion` or `cuenta_cobro`) and a `cobro_items` table, with no direct writes. Add the `cobro_contadores` counter table and the `clinica_servicios` list. Expose 6 security-definer RPCs plus a private stock helper. Leave `mover_stock` untouched. Add a smoke block T (about 30 checks, total about 291).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Number assignment, totals, state machine | Database (RPC) | — | Must be atomic and tamper-proof; the client never sends a number or a total |
| Stock deduction/return | Database (RPC + private helper) | — | Same transaction as the CC; `productos.cantidad` is changed only by RPC |
| Idempotency | Database (unique key) + client (UUID per draft) | — | The client generates the key once per draft; the server dedupes |
| Authorization (admin or issuing vet voids, read-only block) | Database (RPC checks + `guard_solo_lectura`) | UI (`ControlEscritura`) | The UI hides, the DB enforces |
| PDF generation | Client (Flutter `pdf`) | DB read RPC (data and plan-gated logo) | Matches the existing carnet and historia services |
| Sharing | Client (share sheet and `wa.me`) | — | No server-hosted file (D-16) |
| Resumen "Cobrado este mes / Por cobrar" | Database (`cobros_resumen` RPC) | — | Bogotá month boundary computed in SQL with `_hoy_bogota()` |
| Cache coherence | Client (Riverpod invalidation) | — | Billing and inventory lists both go stale after a CC |

## Standard Stack

No new packages are needed. Everything is already in `pubspec.yaml`: `pdf 3.12.0`, `printing 5.14.3`, `share_plus ^13.3.1`, `url_launcher ^6.3.2`, `flutter_riverpod 3.x`, `go_router`, `supabase_flutter`, `intl`. The `pdf`/`printing` versions are pinned deliberately below 3.13/5.15 because those require Dart >= 3.12 (note in pubspec). [VERIFIED: pubspec.yaml lines 49-59]

**Package Legitimacy Audit:** Not applicable. No external package is installed in this phase; slopcheck was not run. Do not add a new dependency (no `uuid` package needed: check whether `uuid` is already present before generating the idempotency key; if not, generate with `Random.secure()` or ask the DB — see Pitfall 8).

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Counter table `ON CONFLICT DO UPDATE` | Postgres `SEQUENCE` per clinic | Sequences leave gaps on rollback (a failed stock check would burn a number) and need DDL per clinic. Rejected. |
| Counter table | `select max(numero)+1 ... for update` | Breaks on the first row of a clinic (nothing to lock) and on a retry; rejected. |
| Private helper | Extend `mover_stock` with `p_origen = 'factura'` | Weakens the WR-04 guarantee: any vet could call `mover_stock(..., 'factura', ref)` by PostgREST and desync the ledger from billing. Rejected. |
| Single `cobros` table with `tipo` | Two tables (`cotizaciones`, `cuentas_cobro`) | One table gives one list, one number format, one PDF path, one guard. The tipo-specific rules live in check constraints. |

## Architecture Patterns

### System Architecture Diagram

```
Vet taps "Cobrar" (cita/consulta/cliente) -> BorradorCobro (Riverpod, client UUID = clave)
   |  lines: servicio (clinica_servicios) | producto (active productos) | otro (free text)
   v
CobrosRepository.crearCuentaCobro(clave, cliente, mascota?, cita?, items[])
   | PostgrestException -> CobroFailure (typed, Spanish)
   v
RPC crear_cuenta_cobro  [security definer, es_veterinario() + mi_clinica_id()]
   1. clave already used by this clinic?  -> return existing row (ya_existia=true), stop
   2. begin sub-block (savepoint)
        - validate cliente/mascota/cita belong to the clinic
        - UPDATE cobro_contadores ... RETURNING numero   (row lock = serialization)
        - INSERT cobros (snapshots, unique clave)         (unique_violation -> return existing)
        - INSERT cobro_items (description/price copied; product lines: name from DB)
        - for each distinct producto (sorted by id): _aplicar_movimiento_stock(-qty, 'venta','factura', ref_id=cobro)
             lock FOR UPDATE -> archived? IN002 -> stock < qty? IN001 (detail has stock/unit/name)
        - total = sum(items) written to cobros
      any raise -> rollback whole sub-block (number returns to the counter)
   v
returns {id, numero, ya_existia}
   v
Client: invalidate cobros list + resumen + inventory (productos, resumen, producto(id), movimientos(id)) + link providers
   v
cobro_para_pdf(id) -> jsonb (cobro + items + clinic header, logo_path null if plan disallows)
   v
CobroPdfService.generar() -> bytes -> Printing.sharePdf (share sheet) / wa.me text to +57
```

Other RPCs follow the same shape: `crear_cotizacion`, `editar_cotizacion`, `marcar_cobro_pagado`, `anular_cuenta_cobro` (reverse stock), `cobros_resumen`, `guardar_servicio` / `archivar_servicio` (admin).

### Recommended Project Structure
```
lib/features/billing/
├── domain/
│   ├── entities/            # cobro.dart, cobro_item.dart, servicio.dart (replace factura.dart)
│   ├── cobro_failure.dart   # typed failure, ErrorCobro enum (see inventario_failure.dart)
│   └── numeracion.dart      # formatearNumero('CC', 12) -> 'CC-0012' (pure Dart, tested)
├── data/
│   ├── repositories/supabase_cobros_repository.dart   # only place that imports supabase
│   └── services/cobro_pdf_service.dart                # reuses CargarFuentesPdf / CargarLogoPdf
└── presentation/
    ├── providers/cobros_providers.dart                # repo, lists, resumen, BorradorCobro, actions with invalidation
    ├── screens/                                       # cobros_screen, cobro_form_screen, cobro_detail_screen, servicios_screen
    └── widgets/
supabase/schema.sql   # new block "Fase 7: Facturación (delta idempotente)" appended after Fase 6
supabase/tests/rls_smoke_test.sql   # new block T before the final report
```

### Pattern 1: Counter table, gapless per clinic and per type
```sql
-- Source: PostgreSQL INSERT ... ON CONFLICT docs (postgresql.org/docs/current/sql-insert.html)
create table if not exists public.cobro_contadores (
  clinica_id uuid not null references public.clinicas(id) on delete cascade,
  tipo text not null check (tipo in ('cotizacion','cuenta_cobro')),
  ultimo int not null default 0,
  primary key (clinica_id, tipo)
);
-- inside the RPC:
insert into public.cobro_contadores (clinica_id, tipo, ultimo) values (v_clinica, v_tipo, 1)
on conflict (clinica_id, tipo) do update set ultimo = cobro_contadores.ultimo + 1
returning ultimo into v_numero;
```
The row lock is held until commit, so two concurrent CCs in the same clinic serialize (milliseconds). Different clinics never contend. `unique (clinica_id, tipo, numero)` on `cobros` is the safety net.

### Pattern 2: Idempotency key with the unique-violation fallback
```sql
-- cobros: clave_idempotencia uuid not null, unique (clinica_id, clave_idempotencia)
select * into v_prev from public.cobros where clinica_id = v_clinica and clave_idempotencia = p_clave;
if found then return query select v_prev.id, v_prev.numero, true; return; end if;
begin
  -- counter + insert header + items + stock (all in this sub-block)
exception when unique_violation then
  -- an identical concurrent retry committed first; its work is complete, ours rolled back
  select * into v_prev from public.cobros where clinica_id = v_clinica and clave_idempotencia = p_clave;
  if found then return query select v_prev.id, v_prev.numero, true; return; end if;
  raise;
end;
```
Catch `unique_violation` narrowly: other unique violations (for example the `(clinica_id,tipo,numero)` net) must re-raise, hence the `found` check. The key is the `ya_existia` signal the client uses to show "Cuenta de cobro ya creada" instead of an error. This directly fixes the 6 WR-03 problem (timeout after a server commit then a retry duplicates). [VERIFIED: 06-REVIEW.md WR-03]

### Pattern 3: Private stock helper (not granted to authenticated)
```sql
create or replace function public._aplicar_movimiento_stock(
  p_clinica uuid, p_producto uuid, p_delta int, p_motivo text, p_ref uuid, p_nota text,
  p_deshace uuid, p_permitir_archivado boolean)
returns uuid language plpgsql security definer set search_path = public as $$
-- select ... for update; archived -> IN002 unless p_permitir_archivado (voiding)
-- new qty < 0 -> raise ... using errcode='IN001', detail = json {producto, quedan, unidad}
-- update productos; insert movimientos_inventario (origen 'factura', ref_id, veterinario_id = auth.uid())
$$;
revoke all on function public._aplicar_movimiento_stock(uuid,uuid,int,text,uuid,text,uuid,boolean)
  from public, anon, authenticated;
```
`security definer` functions called from another definer function work without a grant to `authenticated`. Keep the movement `motivo` for issuance as `venta` (already allowed by the check constraint) and for the reversal `deshacer` with `deshace_id` = the original movement, because the unique index `movimientos_deshace_uq` then makes a double reversal impossible at the DB level (belt and braces next to the `anulada_at is null` check). Set `nota` to `'CC-0012'` and `'Anulada CC-0012'` (nota allows 120 chars). The product history then shows the text with no join; numbers are immutable, so denormalizing is safe. [VERIFIED: schema.sql 4206-4244]

### Pattern 4: Void with reversal in the same transaction
```sql
-- lock the cobro first, check estado <> 'anulada', check (es_admin_clinica() or creado_por = auth.uid())
-- for each original movement of this cobro (origen 'factura', ref_id = cobro, delta < 0), ordered by producto_id:
--   _aplicar_movimiento_stock(+abs(delta), 'deshacer', 'factura', cobro, 'Anulada CC-0012', mov.id, true)
-- update cobros set estado='anulada', anulada_at=now(), anulada_por=auth.uid(), motivo_anulacion=...
```
Reverse from the ledger movements (not from `cobro_items`) so the amounts match exactly what was deducted even if lines repeat a product.

### Anti-Patterns to Avoid
- **Trusting client totals, numbers, product names or movement amounts.** The server recomputes the total, assigns the number and copies the product name; the client only sends product id, quantity and the line price.
- **Calling `mover_stock` from the billing RPC.** It rejects `origen <> 'ajuste'` by design.
- **Locking products in arbitrary order.** Aggregate quantity per product and lock in `producto_id` order to avoid deadlocks between two concurrent CCs.
- **A `SEQUENCE` for numbering.** It leaves gaps on rollback.
- **A composite FK `(cliente_id, clinica_id)` with `ON DELETE RESTRICT` on the document.** It would make clients with documents undeletable; use a plain FK with `on delete set null` plus a name snapshot (see the data model).
- **Reading the plan from the client for the PDF logo.** Return `logo_path` already nulled by the server (same as `carne_de_mascota`, schema.sql ~4033).

## Data model (recommended DDL contract)

| Table | Key columns | Notes |
|-------|-------------|-------|
| `cobros` | `id`, `clinica_id`, `tipo` ('cotizacion'\|'cuenta_cobro'), `numero int`, `estado`, `clave_idempotencia uuid`, `fecha date` (Bogotá), `cliente_id` (set null) + `cliente_nombre`, `cliente_cedula` (snapshot), `mascota_id` (set null) + `mascota_nombre`, `cita_id`, `consulta_id` (set null), `total_cop int check (0..2_000_000_000)`, `metodo_pago`, `pagada_el date`, `valida_hasta date` (quote), `cotizacion_origen_id`, `convertida_en_id`, `creado_por`, `pagado_por`, `anulada_at/por`, `motivo_anulacion`, `created_at`, `updated_at` | `unique (clinica_id, tipo, numero)`, `unique (clinica_id, clave_idempotencia)`. Checks: estado in (`abierta`,`convertida`) for quotes and (`pendiente`,`pagada`,`anulada`) for CCs; `metodo_pago` required iff `pagada`; reason required iff `anulada`. |
| `cobro_items` | `id`, `cobro_id` (cascade), `clinica_id`, `orden`, `tipo` ('servicio'\|'producto'\|'otro'), `descripcion` (1..120), `cantidad int check (1..100000)`, `precio_unitario_cop int check (0..100000000)`, `producto_id` (set null), `servicio_id` (set null) | Description and price are copied in (D-14). Subtotal = `cantidad * precio_unitario_cop`; the `int` multiplication can overflow, so cast to `bigint` in the sum and check the total. |
| `cobro_contadores` | see Pattern 1 | no policies, no privileges for authenticated |
| `clinica_servicios` | `id`, `clinica_id`, `nombre` (1..80), `precio_cop int`, `archivado_at`, `creado_por` | Partial unique index on `(clinica_id, lower(btrim(nombre))) where archivado_at is null` (as `productos`). Admin-only RPC writes. |
| `clinicas.nit text null` | check length <= 30 | Extend `actualizar_clinica` with a new param |
| `clientes.cedula text null` | check length <= 20 | Written through the existing PostgREST update path |

Notes on columns:
- Both `clinicas.nit` and `clientes.cedula` are NULL by default, so no backfill is needed.
- Legal-document snapshots (client name, cédula, pet name) mean later edits to the client never rewrite an issued CC. The clinic header is read live (current name, address, NIT). That is acceptable for v1 (A4).
- Do not use `clientes.cedula` anywhere except the PDF payload. It is personal data; the public carnet must keep excluding it (5 D-20).

### RLS, grants, guard
Copy the Phase 6 block exactly:
- `enable row level security` on all 4 new tables.
- `select` policy `es_veterinario() and clinica_id = mi_clinica_id()` for `cobros`, `cobro_items`, `clinica_servicios`.
- `cobro_contadores` gets no policy at all.
- `revoke all ... from anon`; `revoke insert, update, delete, truncate ... from authenticated` on the 4 tables.
- `guard_solo_lectura` triggers on `cobros`, `cobro_items`, `clinica_servicios`, `cobro_contadores`. That moves "exactly 9 tables" to 13 tables, so the smoke check R44 (schema.sql comment at line 3740 and smoke line 4295) must be updated to 13. The guard fires under the definer RPCs, so the read-only vet gets `LP004`.
- `grant execute ... to authenticated` and `revoke ... from public, anon` for each public RPC. Do this per exact signature, and `drop function if exists` old signatures when a signature changes.
- `notify pgrst, 'reload schema';` at the end.
- Authorship: redefine `es_autor_en_mi_clinica(uuid)` once more. **Copy all four existing arms** (citas, consultas, dosis_aplicadas, movimientos_inventario; schema.sql 4512-4530) and add `cobros.creado_por/pagado_por/anulada_por` and `clinica_servicios.creado_por`. Dropping an arm is a silent regression of the 4.1 authorship rule.
- `actualizar_clinica` takes a new `p_nit text default null`. The old 5-argument signature must be dropped first (else PostgREST sees an ambiguous overload) and the Dart call site and `Clinica` entity updated. Run the full text through a trim and a length check.

### RPC list
| RPC | Who | Notes |
|-----|-----|-------|
| `crear_cuenta_cobro(p_clave, p_cliente_id, p_mascota_id, p_cita_id, p_consulta_id, p_items jsonb, p_cotizacion_id default null)` | active vet | Idempotent; when `p_cotizacion_id` is given it locks the quote (`estado='abierta'`, else error), uses the edited `p_items`, marks the quote `convertida` and stores `convertida_en_id` (D-09). Stock check happens here. |
| `crear_cotizacion(p_clave, p_cliente_id, p_mascota_id, p_items jsonb)` | active vet | No stock movement. `valida_hasta = fecha + 15`. Product lines allowed but not stock-checked. |
| `editar_cotizacion(p_id, p_items jsonb, ...)` | active vet | Only `abierta`; replaces items inside the RPC. |
| `marcar_cobro_pagado(p_id, p_metodo, p_fecha default null)` | active vet | CC `pendiente` only; already `pagada` returns the same row (idempotent). Default date `_hoy_bogota()`. |
| `anular_cuenta_cobro(p_id, p_motivo)` | admin or `creado_por` | Pattern 4. Voiding an already voided CC raises a typed error. Reason 3..200 chars after trim. |
| `cobros_resumen()` | vet | `cobrado_mes` (pagadas with `pagada_el` in the current Bogotá month) and `por_cobrar` (pendientes). Voided excluded. |
| `cobro_para_pdf(p_id)` | vet | jsonb: cobro, items, clinic header (nombre, direccion, telefono, nit, logo_path nulled by plan via `_plan_efectivo(...).logo_permitido`). |
| `guardar_servicio` / `archivar_servicio` | admin | Mirror `crear_producto`/`archivar_producto`. |

Error codes (5 chars): reuse `IN001` (insufficient stock) and `IN002` (product unavailable) so the mapping stays consistent; add `BC001` (document not found or invalid state, for example already voided or already converted) and `BC002` (quote converted or not open). Permissions raise `insufficient_privilege`, read-only raises `LP004` from the guard. Keep a Spanish message in the exception and put structured data in `detail` (for example `producto`, `quedan`, `unidad`) so Dart can pluralize ("frascos") and build "Solo quedan 2 frascos de Amoxicilina." on its own.

Stock-check order: aggregate per product, lock in id order. If several products are short, the first by id is reported; the client shows one message at a time. This is acceptable.

## Colombia legal basics for a "cuenta de cobro" (not a DIAN invoice)

What is established [CITED: actualicese.com/cuenta-de-cobro-para-una-persona-que-presta-servicios-y-no-es-responsable-de-iva, colombiamove.com/blog/cuenta-de-cobro-documento-soporte-independiente-colombia, gerencie.com/personas-no-obligadas-a-expedir-factura.html]:
- There is no single legally mandated format. It is used by natural persons providing services who are not VAT-responsible and not obliged to invoice. It is not a DIAN invoice and does not by itself produce tax effects for the buyer.
- Entities that are legal persons, or persons who are VAT-responsible or exceed the thresholds, must issue electronic invoices. This is why DIAN integration is deferred (DIFF-02).
- When the document is meant to act as a "documento equivalente" (a DIAN concept from 2017), it should carry the issuer's name and NIT/cédula and the buyer's name and NIT/cédula. [CITED: cdn.actualicese.com/normatividad/2017/Conceptos/C024119-17.pdf, as quoted in search results; the full requirement list was not retrieved, verify against the primary concept]

Prescriptive recommendations for the PDF (all derive from D-01..D-24, plus the legal hygiene items):
1. Title "COTIZACIÓN" or "CUENTA DE COBRO" and number `COT-0001` / `CC-0001`. Never "Factura". Neither "recibo oficial".
2. Issuer: clinic name, optional "NIT o cédula" (D-04), phone, address. Strongly suggest the admin fills the NIT/cédula, with a soft hint in the clinic form (not a block).
3. Payer: full name and cédula if available (D-24). No phone.
4. Date dd/mm/aaaa, lines, total in COP, state and payment method and payment date for paid.
5. Quote: "Válida por 15 días, hasta dd/mm/aaaa" and "Esta cotización no es una factura ni una cuenta de cobro".
6. A one-line neutral footer on a CC: "Este documento es una cuenta de cobro y no constituye factura de venta." The wording is a recommendation, not verified law (A1). It states what the document is without claiming tax status, and the clinic stays responsible for its own tax obligations.
7. Do not print "IVA" at all (D-03). Do not print "Responsable/No responsable de IVA".
8. Voided CC: if the PDF is re-generated, watermark/banner "ANULADA" with the reason and keep the number.

Open legal risks to surface to the user (not to resolve in code): clinics that are legal persons, and sales of physical products (goods), may be outside what a cuenta de cobro covers. Recommend a one-time accountant review before launching billing to paying clinics (also in the Open Questions).

## Flutter patterns

### PDF reuse
- `HistoriaClinicaPdfService` shows the seam: `CargarFuentesPdf` (injected so tests never download `PdfGoogleFonts`), `generar()` that wraps any failure in a typed Spanish failure, a pure `nombreArchivo()` static, and `pw.MultiPage`. `CarnePdfService` adds `CargarLogoPdf` (with a 5 s timeout, `imagenDecodificable` check so corrupt bytes never reach `pw.MemoryImage`) and the "Hecho con VetApp" footer. [VERIFIED: both files read]
- Create `CobroPdfService` in `lib/features/billing/data/services/` and import the two typedefs, `imagenDecodificable` and the logo-loading helper from the existing files (do not copy them). Inject them into the service for tests. Use `pw.MultiPage` with a table of lines (description / qty / unit price / subtotal) and a total row, since a CC can exceed one page.
- Logo and fonts: reuse the Noto fonts and `logo_path` returned by `cobro_para_pdf` (already nulled when the plan does not allow a logo, 5.1 D-06). The carné's `Hecho con VetApp` footer is always present (5.1 D-05).
- File name: `CC-0012_<cliente>.pdf` using the same sanitizer approach as `nombreArchivo` (`[^A-Za-z0-9]+` to `_`).

### Sharing
- The existing `compartirPdfProvider` (`Printing.sharePdf(bytes, filename)`) opens the native share sheet from where the vet can pick WhatsApp. Its failure type is `ConsultaFailure`; either generalize the provider or add a billing analog `compartirCobroProvider` with a `CobroFailure`, so billing does not import clinical-history types. [VERIFIED: historia_clinica_pdf_providers.dart]
- WhatsApp: a `wa.me` link cannot attach a file; it carries only text. So the flow is two steps: the primary action shares the PDF via the share sheet (user picks WhatsApp and the chat), and a secondary "Abrir chat de WhatsApp" opens `wa.me/<+57 number>?text=<formal message>` through `LanzadorExterno.abrirEnApp` (never in a browser; VET-25 rule) so the vet can paste or send the message to the correct number. `Printing.sharePdf` also accepts a `body` text that many targets pre-fill (behavior varies per app; A5, verify on the emulator). Phone normalization comes from `normalizarTelefono` (`telefono_co.dart`), which is safe for `wa.me`. Message in "usted": "Buen día, {nombre}. Le comparto la cuenta de cobro CC-0012 por $ 85.000 de {clínica}. Quedo atento a sus dudas. Gracias."
- A client with no phone: hide the WhatsApp row and keep the share sheet. The tests must run without the platform channel (inject `Compartidor`/`LanzadorExterno`/`CompartirPdf` overrides).
- No public link (D-16).

### Riverpod invalidation
Follow the Phase 6 `inventarioActionsProvider` pattern (`inventario_providers.dart` lines 53-61: a helper that invalidates the lists and the per-product family). A `cobrosActionsProvider` does, after crear / anular / pagar / convertir:
- always `cobrosProvider` (list by tipo), `cobroProvider(id)`, `resumenCobrosProvider`;
- when product lines are involved (crear CC, convert, anular): `productosProvider`, `resumenInventarioProvider`, and for each affected id `productoProvider(id)` and `movimientosProvider(id)`;
- the screens that show "Cobrar" or "ya cobrada": the appointment and client providers if they expose a link (cobro por `cita_id`).
Invalidate even on error classes `sinConexion` and `otro`, because the server may have committed (WR-03 lesson: the old inventory code invalidated only on two classes, which left stale numbers). With the idempotency key the retry is safe, so the UI should say "Revisando…" and re-fetch rather than "no se creó" when the failure is a timeout after a response was possible; the D-21 wording applies to a confirmed lack of connection. Keep the draft and the same key until success.

### Draft state
Hold a `BorradorCobro` (client id, pet, lines, the key UUID) in a Riverpod `Notifier` so the draft survives rebuilds. The key is created when the draft is created and never regenerated on retry. The edit of a line price changes only the line (D-07). Product picker: reuse the active-products picker and filter `archivado_at is null`. For the `Cobrar` shortcut pre-fill client and pet from the appointment or consultation.

### Cuenta de cobro entity
Replace `factura.dart`: `Cobro` (id, tipo, numero, estado, fecha, cliente snapshot, mascotaNombre, items, totalCop, metodoPago, pagadaEl, validaHasta, anulacion, convertidaEn), `CobroItem` with `int cantidad` (the stub's `double` contradicts 6 D-03), `Servicio`. No other file imports `factura.dart` (verified by grep), so deletion is safe. [VERIFIED: grep over lib and test]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Gapless numbering | A client-side counter or `max()+1` | `cobro_contadores` + `ON CONFLICT DO UPDATE` inside the RPC | Race conditions, burned numbers |
| Idempotent retry | A client "pending" flag | `unique (clinica_id, clave_idempotencia)` + early lookup | Survives timeout-after-commit |
| Stock deduction | Direct `update productos` | `_aplicar_movimiento_stock` (lock, no-negative, ledger row) | Ledger rule: quantity changes only with a movement |
| PDF | A new renderer | `pdf` + `printing` (existing services) | Already solved fonts, logo, failures |
| Share | A custom intent channel | `Printing.sharePdf` / `LanzadorExterno` | Tested seams already exist |
| COP formatting | String math | `formatearCop` / `parsearCop` (`formato.dart`) | Phase 6 rule: whole COP, rejects commas |
| Phone to wa.me | Regex per screen | `normalizarTelefono` | Idempotent and URL-safe |
| Bogotá dates | `DateTime.now()` in SQL or Dart | `_hoy_bogota()` and `zona_bogota.dart` | Month boundary at 7 pm Bogotá in UTC would be wrong |

## Runtime State Inventory

Not a rename or migration phase. The only schema alteration of live data is additive: two new nullable columns and a function-signature change.

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | `clinicas.nit` and `clientes.cedula` are new NULL columns; no backfill | none (code and DDL only) |
| Live service config | `actualizar_clinica` has a new 6-arg signature; the old 5-arg is dropped | re-paste the delta in the Supabase SQL editor; the app and DB must ship together or the clinic edit breaks |
| OS-registered state | None, verified: no cron or task touches billing | none |
| Secrets/env vars | None | none |
| Build artifacts | None; no new package | none |

## Common Pitfalls

### Pitfall 1: Burned or duplicated numbers
**What goes wrong:** a failed stock check leaves a skipped number, or a retry creates two CCs.
**Why:** sequences, or the idempotent lookup placed after the counter increment.
**Avoid:** the lookup first, the counter increment inside the same sub-block as the stock moves, the `unique_violation` fallback. Smoke: after a rejected CC, the next number is `n+1`.

### Pitfall 2: Deadlock on concurrent CCs
**Why:** two CCs lock products in different orders. **Avoid:** aggregate per product and lock `order by producto_id`; take the quote row first, then the counter, then the products, in every RPC.

### Pitfall 3: Voiding a CC whose product was archived
**Why:** `mover_stock` rejects archived products. **Avoid:** the helper's `p_permitir_archivado` flag for reversals; add a smoke check.

### Pitfall 4: Weakening `mover_stock`
Do not change `mover_stock`; the Phase 6 smoke checks S1..S23 (including S23, the undo-restriction) depend on its current rules. The UI must also not offer "Deshacer" on `origen = 'factura'` movement tiles. Check `movimiento_tile.dart` and `ajuste_stock.dart` for gating by origin.

### Pitfall 5: Redefining `es_autor_en_mi_clinica` without the old arms
See the RLS section. It silently hides retired authors on earlier phases.

### Pitfall 6: Signature drift on `actualizar_clinica`
PostgREST resolves overloads by parameter names. Drop the old signature, update `clinica_repository`, `Clinica.copyWith`, the clinic form and every fake in tests.

### Pitfall 7: `int` overflow in subtotals and total
`cantidad (<= 100000) * precio (<= 100M)` overflows `int4`. Compute in `bigint` and check the total before inserting.

### Pitfall 8: The client generating the idempotency key
A UUID v4 in Dart needs either a `uuid` dependency or manual generation with `Random.secure()`. Check `pubspec.lock` for `uuid` (transitive via supabase_flutter) before adding anything; a direct dependency would require the legitimacy audit. [ASSUMED: uuid is transitively present]

### Pitfall 9: "Cobrado este mes" by creation date vs payment date
Use the payment date (`pagada_el`), and a voided CC leaves the total. Document it in the UI copy (the label already says "cobrado").

### Pitfall 10: Word "Factura" leaking
Enum values, route paths, tests and logs may contain `factura` (the DB origen `factura` is an internal value and stays). Add a grep gate over `lib/` user-visible strings and the PDF service for `factura` excluding the origen constant.

### Pitfall 11: Client deletion and cascade
Appointments cascade on client delete; documents must not. Use `on delete set null` plus the snapshot so a deleted client never deletes a legal document. If the product decides clients are never hard-deleted, this is moot but harmless.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Supabase cloud SQL editor | applying the delta, running the smoke | yes (used in phases 5-6) | — | — |
| Flutter SDK + `pdf`/`printing`/`share_plus`/`url_launcher` | PDF and share | yes (pinned in pubspec) | pdf 3.12.0, printing 5.14.3 | — |
| Android emulator for QA | share-sheet and WhatsApp checks | yes per project memory (`vetapp-qa`) | — | The user has only an iPhone; real-device checks use emulator + Safari |
| WhatsApp on the emulator | the `wa.me` open | uncertain | — | Verify that `abrirEnApp` returns false and the UI falls back to the share sheet |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (widget and unit) + the SQL smoke `supabase/tests/rls_smoke_test.sql` + `supabase/tests/verify_live_schema.sh` |
| Config file | none beyond `analysis_options.yaml` |
| Quick run command | `flutter analyze` and `flutter test test/<file>` for the plan's files |
| Full suite command | `flutter test`, paste `rls_smoke_test.sql` (expect `RLS SMOKE: PASS (N checks)`), `bash supabase/tests/verify_live_schema.sh` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BILL-01 | PDF generates for quote and CC, contains number, "Cuenta de cobro", no "Factura", logo omitted if null, a failure becomes `CobroFailure` | unit | `flutter test test/cobro_pdf_service_test.dart` | Wave 0 |
| BILL-01 | Numbers format `CC-0012` and `COT-0001` | unit | `flutter test test/numeracion_test.dart` | Wave 0 |
| BILL-02 | Multi-line CC: totals, price override on one line, server copies the product name, rejects an archived product | SQL smoke (T block) + unit for the entity | smoke, `flutter test test/cobro_test.dart` | Wave 0 |
| BILL-03 | Deducts stock with origen `factura` and `ref_id`, blocks with `IN001` atomically (nothing moves, number not burned), voiding returns stock, double void rejected, void of an archived product works | SQL smoke | smoke T block | Wave 0 |
| BILL-03 | Repository maps `IN001`/`IN002`/`LP004`/network to typed failures and the "Solo quedan 2 frascos…" message | unit | `flutter test test/supabase_cobros_repository_test.dart` | Wave 0 |
| BILL-03 | Creating or voiding invalidates billing and inventory providers | unit | `flutter test test/cobros_invalidacion_test.dart` | Wave 0 |
| BILL-04 | Pending to paid with method and date; paid to pending only via void; idempotent re-pay | SQL smoke + widget | smoke, `flutter test test/cobro_detail_screen_test.dart` | Wave 0 |
| D-19 | Read-only vet gets `LP004` on create; non-author non-admin cannot void; admin can | SQL smoke + widget (padlock) | smoke, `flutter test test/cobros_screen_test.dart` | Wave 0 |
| D-21 | Same `clave` twice returns the same id/number and moves stock once | SQL smoke | smoke | Wave 0 |
| D-09 | Quote converted: new CC number, quote `convertida`, stock deducted at that moment, second conversion rejected | SQL smoke | smoke | Wave 0 |
| D-16 | Share and wa.me use the injected seams; no wa.me without a phone | widget | `flutter test test/compartir_cobro_test.dart` | Wave 0 |
| Router | Más to /cobros without duplicating the shell (the G5 lesson of Phase 6) | widget/router | `flutter test test/router_cobros_cross_shell_test.dart` | Wave 0 |
| Copy | No "Factura" in user-visible strings | grep gate | `rg -i "factura" lib --glob '!**/*.g.dart'` reviewed against an allow-list (the `origen` constant) | gate in each plan |

A single-session DO block cannot test true parallel contention. Concurrency safety is shown by construction (the counter row lock and the unique constraints); the smoke checks the observable results (sequence, replay, rollback). Add one manual two-session check to the plan: two SQL editor tabs issue a CC in the same clinic at the same time and both succeed with consecutive numbers.

### Smoke extension plan (block T, baseline 261 = 238 + S23)
All run inside the existing single transaction with the same `set_config('request.jwt.claims', ...)` / `set_config('role', ...)` helpers used by block S, and are rolled back at the end. Target about 30 checks, so about 291 total (the exact number is fixed in the plan; ask the user to paste the literal result as in 06-04).

| # | Check |
|---|-------|
| T1-T3 | Tenant isolation: clinic B vet cannot select `cobros`, `cobro_items`, `clinica_servicios` of clinic A; a CLIENTE role sees none |
| T4-T5 | `anon` has no table or RPC access (also in `verify_live_schema.sh`) |
| T6-T7 | `authenticated` direct `insert/update/delete` on `cobros` and `cobro_items` fail (permission denied); `cobro_contadores` unreadable |
| T8 | `_aplicar_movimiento_stock` is not executable by `authenticated` |
| T9-T11 | CC with 2 products and 1 service: number `1`, total matches, stock deducted, movements have origen `factura`, motivo `venta`, `ref_id` = the CC, nota `CC-0001` |
| T12 | Server copies the product name even when the client sends another (BILL-02) |
| T13 | Line price override changes only the line, not `productos.precio_venta_cop` |
| T14-T15 | Insufficient stock raises `IN001`; no header, no items, no movements, stock unchanged |
| T16 | After the rejection, the next CC gets the next number with no gap |
| T17-T18 | Same `clave` replay returns the same id and number, `ya_existia = true`, stock moved once |
| T19 | Archived product rejected `IN002` on create |
| T20-T22 | Void: reverse movements (`deshacer`, `deshace_id` set, nota `Anulada CC-0001`), stock restored, estado `anulada`, number kept |
| T23 | Double void rejected (`BC001`) with no extra movement |
| T24 | Void works when the product was archived after issuance |
| T25 | A non-author non-admin vet cannot void (`insufficient_privilege`); the author and the admin can |
| T26 | Void requires a reason |
| T27-T28 | Mark paid: needs a valid method, sets `pagada_el`; re-marking is idempotent; a voided CC cannot be paid |
| T29 | Quote does not move stock; `valida_hasta = fecha + 15` |
| T30-T31 | Quote conversion: new CC number, quote `convertida`, `convertida_en_id` set, stock deducted then; converting twice rejected |
| T32 | Read-only vet (`puede_escribir() = false`) gets `LP004` on create, pay and void; `mover_stock` checks S1..S23 still pass |
| T33 | `cobros_resumen`: cobrado_mes counts only the current Bogotá month and excludes voided; por_cobrar counts pendientes |
| T34 | `es_autor_en_mi_clinica` still true for authors of citas, consultas, dosis and movements (regression of the 4 old arms) plus the new arm for cobros |
| T35 | `actualizar_clinica` accepts and trims `p_nit`; non-admin rejected; length check |
| R44 | Updated from 9 to 13 guarded tables |

### Sampling Rate
- **Per task commit:** `flutter analyze` and the plan's `flutter test` files; for SQL tasks the grep gates over the Fase 7 block.
- **Per wave merge:** `flutter test` complete.
- **Phase gate:** full suite green, smoke `PASS (N checks)` pasted by the user, `LIVE_SCHEMA_OK`, and emulator QA (`vetapp-qa`). Record a checkmark or cross per task in `07-VALIDATION.md` (project rule: verify and document each plan).

### Wave 0 Gaps
- [ ] The test files in the table above.
- [ ] Fakes for `SupabaseCobrosRepository` and the PDF fonts/logo loaders (reuse the fake seams of Phase 5/6).
- [ ] `verify_live_schema.sh`: probes for the 4 tables, 8 RPCs and the `anon` denial; embed hints if the UI embeds `cobro_items`.
- [ ] No framework install is needed.

## Security Domain

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no (existing Supabase Auth) | — |
| V3 Session Management | no | — |
| V4 Access Control | yes | RLS select by clinic; writes only through RPCs with `es_veterinario()`/`mi_clinica_id()`; void restricted to admin or author; `guard_solo_lectura` |
| V5 Input Validation | yes | DB checks (lengths, ranges, enums) plus RPC validation of jsonb items (array, types, bounds, max items about 50); client re-validates for UX only |
| V6 Cryptography | no (no new secrets) | — |
| V8 Data Protection | yes | cédula only on the PDF payload; no public link; the PDF only leaves via the user-initiated share |

### Known Threat Patterns
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Cross-tenant id guessing (`cliente_id`, `producto_id`, `cita_id` of another clinic in the payload) | Tampering/Info disclosure | The RPC re-verifies each id with `clinica_id = v_clinica` |
| Client-supplied total or number | Tampering | Server computes both |
| Direct PostgREST write to `cobros` or `productos.cantidad` | Tampering | Privileges revoked; no write policies |
| Forged ledger via `mover_stock` with origen factura | Tampering/Repudiation | `mover_stock` unchanged (origen `ajuste` only) |
| A non-author voids another vet's CC | Elevation of privilege | Check in the RPC; a smoke test |
| Replayed request creating duplicates | Tampering | Idempotency key |
| jsonb payload abuse (huge arrays, wrong types) | DoS | cap item count and string lengths in the RPC; `jsonb_typeof` checks |
| `security definer` search_path hijack | Elevation | `set search_path = public` on every function (as in Phase 6); qualify `public.` names |
| PII in logs and filenames | Info disclosure | sanitize the PDF filename; never log the cédula |

## Code Examples

### Typed failure mapping (Dart, follows `inventario_failure.dart`)
```dart
// enum ErrorCobro { stockInsuficiente, productoNoDisponible, yaAnulada, yaConvertida,
//   sinPermiso, datosInvalidos, sinConexion, soloLectura, otro }
// Repository: catch PostgrestException e -> switch (e.code) { 'IN001' => stock failure with
// a message built from e.details; 'IN002' => ...; 'LP004' => soloLectura; 'BC001' => ... }
// A timeout or SocketException -> sinConexion. The presentation layer never imports supabase.
```
Source: repo pattern, `lib/features/inventory/domain/inventario_failure.dart`.

### Spanish stock message with a unit plural
```dart
String mensajeStock(String nombre, int quedan, String unidad) {
  final plural = switch (unidad) { 'ml' || 'kg' => unidad, 'unidad' => quedan == 1 ? 'unidad' : 'unidades',
    _ => quedan == 1 ? unidad : '${unidad}s' };
  return quedan == 0 ? 'No quedan existencias de $nombre.'
      : 'Solo ${quedan == 1 ? 'queda' : 'quedan'} $quedan $plural de $nombre.';
}
```
(Spanish pluralization: "unidad" to "unidades", "tableta" to "tabletas", "caja" to "cajas", "dosis" stays "dosis" so add that case.)

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| Stub `Factura` with `double` quantity | `Cobro`/`CobroItem` with `int` and copied description and price | Aligns with 6 D-03 and D-14 |
| `mover_stock` as the only stock writer | `mover_stock` for manual adjustments; billing RPCs through a private helper | Keeps WR-04 protection |
| Retry duplicates a write (WR-03) | Client-generated idempotency key per draft | No duplicates under flaky signal |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The recommended CC disclaimer wording is adequate and does not pose as a factura | Colombia legal | Medium: a clinic could be challenged; needs an accountant's review |
| A2 | Clinics that are legal persons, or that sell goods, may be outside a pure cuenta de cobro | Colombia legal | High for the target users who are companies: the feature may need a "para independientes" notice or an earlier DIAN step |
| A3 | The issuer NIT/cédula plus the payer cédula are enough for the "documento equivalente" expectation | Colombia legal | Medium: more fields could be required |
| A4 | Reading the clinic header live (not snapshotted) on old documents is acceptable | Data model | Low: an old PDF shows the current clinic name/address |
| A5 | `Printing.sharePdf` `body` pre-fills the text in WhatsApp | Flutter sharing | Low: UX only; fall back to the two-step flow |
| A6 | `uuid` is transitively available for the idempotency key | Pitfall 8 | Low: generate with `Random.secure()` |
| A7 | `PG >= 15` features are not needed (the design avoids `ON DELETE SET NULL (col)`) | Data model | None as designed |
| A8 | A seeded list of services is not needed; an empty list plus an admin CTA is enough because "Otro" always works | Discretion | Low: friction on day one; a "Agregar sugeridos" button (Consulta, Vacunación, Desparasitación, Cirugía) is a cheap alternative that asks the admin to type each price |

## Open Questions

1. **Legal review.** Has an accountant confirmed the cuenta de cobro wording and the case of a clinic that is a legal entity or that sells goods (A1-A3)?
   - Recommendation: ship v1 as designed (D-01 locked), add the neutral disclaimer, and add a user task "validate with an accountant" before charging clinics for the feature.
2. **Void window.** Should voiding a paid CC be allowed at any time? D-19 and D-15 allow it with a reason. Recommend yes, and record the earlier payment in the void row (the `metodo_pago` and `pagada_el` stay for audit).
3. **Services list seeding (Claude's discretion).** Recommend the empty list with an admin CTA "Agregar servicios sugeridos" (four names, price entered by the admin), as a seed with invented prices would put wrong amounts on legal documents.
4. **Print of voided CC.** Recommend allowing PDF re-generation with the "ANULADA" banner.
5. **A quote edit changing the date.** Recommend `valida_hasta` stays tied to the original date and does not reset on edit (simple and predictable); confirm in the UI-SPEC.

## Sources

### Primary (HIGH confidence)
- `supabase/schema.sql` lines 3740-3800 (guard), 4176-4547 (Phase 6 block: tables, `mover_stock`, grants, `es_autor_en_mi_clinica`) — read in this session.
- `.planning/phases/07-facturaci-n/07-CONTEXT.md`, `06-REVIEW.md` (WR-03, WR-04), `06-VALIDATION.md` (261-check baseline).
- `lib/features/clinical_history/data/services/historia_clinica_pdf_service.dart`, `.../historia_clinica_pdf_providers.dart`, `lib/features/vaccination/data/services/carne_pdf_service.dart` (typedefs and logo seams), `lib/core/utils/compartir.dart`, `telefono_co.dart`, `lanzador_externo.dart`, `lib/features/inventory/.../inventario_providers.dart`.
- `pubspec.yaml` (pinned versions).

### Secondary (MEDIUM confidence)
- [Actualícese: cuenta de cobro para una persona que presta servicios y no es responsable de IVA](https://actualicese.com/cuenta-de-cobro-para-una-persona-que-presta-servicios-y-no-es-responsable-de-iva/)
- [Gerencie: personas no obligadas a expedir factura](https://www.gerencie.com/personas-no-obligadas-a-expedir-factura.html)
- [Colombia Move: cuenta de cobro y documento soporte](https://colombiamove.com/blog/cuenta-de-cobro-documento-soporte-independiente-colombia/)
- [DIAN concept 024119/2017 via Actualícese](https://cdn.actualicese.com/normatividad/2017/Conceptos/C024119-17.pdf) (cited through search results; not read in full)
- PostgreSQL documentation on sequences and `INSERT ... ON CONFLICT` (from training knowledge, standard behavior: sequences are not transactional).

### Tertiary (LOW confidence)
- WhatsApp attachment behavior through `wa.me` and `Printing.sharePdf` `body` (A5).

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH (no new packages; verified in pubspec)
- Architecture and Postgres design: HIGH (built on verified Phase 6 code; the concurrency reasoning is standard Postgres semantics)
- Legal wording: MEDIUM-LOW (informal document, no official template; accountant review)
- Pitfalls: HIGH (most come from reading the actual code and WR-03/WR-04)

**Research date:** 2026-11-13
**Valid until:** 2026-12-13 (stable domain; the legal items should be re-checked if DIAN rules change)

## Project Constraints (from CLAUDE.md)
- Flutter + Supabase; the mockup design (terracota/crema, Caprasimo + Figtree) is mandatory; no generic Material.
- Real backend, no mocks; COP and dd/mm/aaaa.
- Domain terms stay in Spanish; repositories translate to typed failures, and the presentation layer never imports supabase; usecases and domain layers are mostly bypassed in this repo, so follow the Phase 6 repository plus providers pattern rather than reviving the unused usecase layer.
- `flutter_lints` default; `///` docs on domain entities and reusable widgets only.
- GSD workflow: all repo edits go through a GSD command. Project memory: verify and document every plan (record the result per task in VALIDATION.md); the `.planning/business/` and market folders are local-only; the brand-rename (Rondavet) is gated, so use "VetApp" in the PDF footer ("Hecho con VetApp", 5.1 D-05).
