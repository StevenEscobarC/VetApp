# Phase 7: Facturación - Context

**Gathered:** 2026-11-13
**Status:** Ready for planning

<domain>
## Phase Boundary

From the phone, the vet bills consultations, services and inventory products with two simple documents:
- a **Cotización** (quote);
- a **Cuenta de cobro** (CC), what the client owes.

Each document is a PDF shared with the client, and a CC is marked pending or paid.

Issuing a CC with inventory products deducts the stock automatically, in the same server transaction. Voiding the CC returns the stock.

Requirements: BILL-01..04.

Out of scope:
- electronic invoicing with the DIAN (Colombia's tax authority) and VAT;
- partial payments;
- an offline queue;
- dashboard charts (Phase 8);
- deducting stock when a vaccine dose is recorded.

</domain>

<decisions>
## Implementation Decisions

### Legal document type
- **D-01:** There are two document types: **Cotización** and **Cuenta de cobro**. The word "Factura" never appears in the app, the PDFs or the copy for the client.
  - A cuenta de cobro is the legal format independent professionals in Colombia who are not VAT-registered already use.
  - The stub `lib/features/billing/domain/entities/factura.dart` gets replaced by the real model.
- **D-02:** **Numbering is sequential per clinic and assigned by the server:** `COT-0001…` for quotes and `CC-0001…` for cuentas de cobro.
  - Numbers are never reused; a voided document keeps its number.
  - The number is taken inside the same transaction that creates the document, so it is safe under concurrency.
- **D-03:** **No VAT in v1.** Prices are final totals in whole COP with no decimals (`formatearCop`), and the PDF says nothing about VAT. VAT is revisited with an accountant together with the DIAN integration.
- **D-04:** **PDF header:** clinic name, logo (the plan rules from 5.1 D-06 apply), phone and address. It also shows an optional **"NIT o cédula"** field of the clinic, which the admin fills in once in the clinic data.

### Building the document
- **D-05:** **Entry points:**
  - **"Cobrar"** when completing an appointment or after a consultation. Client and pet come pre-filled, and the CC stays linked to the appointment or consultation (same pattern as the dose↔appointment link in 5 D-22).
  - **"Nueva cuenta de cobro"** from Cobros and from the client profile, for walk-in sales. The pet is optional.
- **D-06:** **Service lines come from a saved services list.**
  - The clinic keeps a short list of services (Consulta, Vacunación, Cirugía…) with a default price in COP. Only the admin edits it, as with inventory prices (6 D-13).
  - One tap adds a service, and **"Otro"** adds a free-text line with a price.
  - Product lines come from inventory and only active products can be picked.
- **D-07:** **The price can be changed on a single line**, as a discount or special price. The base price of the product or service does not change; it stays admin-only.
- **D-08:** **No discount on the whole document** in v1.
- **D-09:** **A quote turns into a cuenta de cobro with one tap.**
  - The lines are copied and stay editable, and the new CC gets its own number.
  - The quote is marked "Convertida en CC-00NN".
  - Stock is checked and deducted at that moment.
- **D-10:** **A cuenta de cobro is append-only:** it is never edited, only **voided with a reason** and reissued (same as the clinical history and the doses). Quotes stay editable while they are not converted.

### Stock deduction
- **D-11:** **Stock is deducted when the CC is issued**, whether it is paid or not. Quotes never deduct stock.
  - The deduction goes through movements with origen `factura` and `ref_id` = the CC.
  - Phase 6 already reserved that origin in `mover_stock` and `movimientos_inventario`.
  - The planner decides whether to extend `mover_stock` or create a billing RPC that inserts the movements in the same transaction.
- **D-12:** **Asking for more than the stock is blocked** with a clear message, for example "Solo quedan 2 frascos de Amoxicilina." The whole CC fails atomically; there is no negative stock (Phase 6 D-04).
- **D-13:** **Voiding a CC returns the stock automatically** with reverse movements (origen `factura`, reference to the CC) in the same transaction. The product history shows "Anulada CC-0012".
  - This overrides 6 WR-04 for this origin: the undo restricted to `ajuste` stays as it is, but this reversal is a separate operation of the billing RPC.
- **D-14:** **Archived products cannot be added.** An existing CC that references one shows its line as it was saved, with the description and price copied into the line.

### Payment, sharing and plan
- **D-15:** **The state is Pending or Paid.**
  - "Marcar como pagada" only asks for the method, with chips: Efectivo, Nequi, Daviplata, Transferencia, Tarjeta, Otro. The payment date defaults to today.
  - Paid can go back to pending only together with voiding the CC.
  - There are **no partial payments** in v1.
- **D-16:** **Sharing:** the **PDF goes to the client by WhatsApp** at their +57 number with a formal message, using "usted" as in 4 D-14, plus the native **share sheet**.
  - There is **no public link** for billing documents, because amounts are private data.
  - Reuse the existing sharing utilities.
- **D-17:** **The Cobros screen has a simple header** with "Cobrado este mes" and "Por cobrar" (from the mockup).
  - It has a Cotizaciones / Cuentas de cobro toggle and cards with their state (Pagada / Pendiente / Anulada / Convertida).
  - Charts and the Inicio card wait for Phase 8.
- **D-18:** **No plan limit:** billing is in every plan without a new limit. This keeps the rule of exactly 4 limits from 5.1 D-01 and matches inventory 6 D-15. The business proposal of 10 per month in Free was considered and rejected for now; it gets revisited with usage data.

### Permissions and navigation
- **D-19:** **Any active vet** creates quotes and CCs and marks them paid, always with authorship.
  - **Voiding a CC** is allowed to the admin or to the vet who issued it, always with a reason.
  - Read-only colleagues (5.1 D-12) can see but not create: extend `guard_solo_lectura` to the new tables and use the padlock treatment (`ControlEscritura`) in the UI.
- **D-20:** **Cobros lives in Más**, as a row next to Inventario. The bottom nav does not change. The "Cobrar" shortcuts go on completed appointments, consultations and the client profile. The "Factura" quick action on Inicio from the mockup waits for the Phase 8 redesign.

### Network, PDF and client data
- **D-21:** **No connection means a clear failure, with no queue**, as in inventory 6 D-12: "Sin conexión, el cobro no se creó."
  - The draft stays on screen so the vet can retry.
  - The creation RPC takes an **idempotency key per draft**, so a retry never duplicates the CC, its number or the stock deduction. This avoids the 6 WR-03 problem from the start.
- **D-22:** **The PDF follows the carnet and clinical history style** (reuse the existing PDF services). It contains:
  - the header from D-04;
  - the number and the date in dd/mm/aaaa;
  - the client and the pet;
  - the lines as quantity × unit price, and the total in COP;
  - the state and the payment method;
  - the "Hecho con VetApp" footer (5.1 D-05).
- **D-23:** **A quote shows "Válida por 15 días"** with the date it expires. Its state never changes automatically.
- **D-24:** **Client data on the PDF:** the **full name** of the payer and **their cédula if available**.
  - That means a new optional field on the client, editable in the client form with a minimal, optional cédula. The planner decides whether it goes in the existing client table.
  - The phone is not printed by default.
  - This PDF only goes to the client, unlike the public carnet (5 D-20).

### Claude's Discretion
- How the CC and its lines are modeled (header + items table, copying description and price into each line), the RLS policies and the RPCs, following the Phase 6 pattern: security definer with a tenant check, and smoke checks added to `rls_smoke_test.sql`.
- How the saved services list is set up: first-time seed (Consulta, Vacunación, Desparasitación, Cirugía?) versus empty with a CTA.
- The exact layout of the form and the PDF, within the UI-SPEC that `/gsd-ui-phase 7` will produce.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope and requirements
- `.planning/ROADMAP.md` (Phase 7): goal and the 4 success criteria.
- `.planning/REQUIREMENTS.md`: BILL-01..04.
- `.planning/PROJECT.md`: DIAN out of scope for v1; zero-friction principle.

### Prior decisions that bind this phase
- `.planning/phases/06-inventario/06-CONTEXT.md`:
  - D-02: `mover_stock`, origen `factura` reserved;
  - D-04: no negative stock;
  - D-12: offline behavior;
  - D-13: admin-only prices;
  - D-15: no plan limit;
  - D-16: COP prices.
- `.planning/phases/06-inventario/06-REVIEW.md`: WR-03 (idempotency) and WR-04 (undo restricted to `ajuste`).
- `.planning/phases/05.1-planes-y-l-mites/05.1-CONTEXT.md`:
  - D-01: 4 limits;
  - D-05: "Hecho con VetApp" footer;
  - D-06: logo by plan;
  - D-12: read-only colleagues.
- `.planning/phases/05-vacunaci-n-y-desparasitaci-n/05-CONTEXT.md`:
  - D-17: PDF and WhatsApp sharing;
  - D-20: data minimization;
  - D-22: record linked to an appointment.
- `.planning/phases/04.1-equipo-de-la-cl-nica/04.1-CONTEXT.md`: authorship (`es_autor_en_mi_clinica`).

### Design
- `.planning/design/DESIGN-REFERENCE.md` §9 Facturación: "Ingresos del mes" summary, Cotizaciones/Facturas toggle (here: Cotizaciones/Cuentas de cobro), cards with state.
- `.planning/design/vetapp-mobile-designs.html`: mockup.

### Architecture
- `.claude/skills/arquitecto-vetapp/SKILL.md` and `references/modelo-dominio.md` §9: inventory model and the `security definer` exception.
- `supabase/schema.sql`: Phase 6 block, the `mover_stock` pattern.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/features/vaccination/data/services/carne_pdf_service.dart` and `lib/features/clinical_history/data/services/historia_clinica_pdf_service.dart`: PDF generation with the clinic header, logo and footer, as a base for the quote and CC PDF.
- `lib/core/utils/formato.dart`: `formatearCop`, `parsearCop`, `formatearMiles` and dd/mm/aaaa dates.
- `lib/core/utils/compartir.dart` and `telefono_co.dart`: share sheet and WhatsApp to the +57 number.
- The inventory feature (`lib/features/inventory/**`) has the repository, typed failure, providers with invalidation, the active-products picker and the read-only padlocks.
- `lib/features/billing/domain/entities/factura.dart` is a stub to replace: it says "Factura" and uses `double` quantities, which contradicts 6 D-03.

### Established Patterns
- Writes go only through `security definer` RPCs with an `es_veterinario()`/`mi_clinica_id()` check and nothing written directly to tables, as in Phase 6.
- Append-only records with void plus reason, as in the clinical history and doses.
- `guard_solo_lectura` covers 9 tables; the new tables get added to it.
- Repositories translate `PostgrestException` into a typed failure, and the presentation layer never imports supabase.

### Integration Points
- "Completar cita" and the consultation get the "Cobrar" action.
- The client profile gets "Nueva cuenta de cobro" and the client form gets the optional cédula.
- Más gets the Cobros row.
- Inventory gets the movements with origen `factura` in the product history.
- Clinic data gets the optional NIT/cédula field.

</code_context>

<specifics>
## Specific Ideas

- Blocking message when stock is short: "Solo quedan 2 frascos de Amoxicilina."
- Voiding visible in the product history: "Anulada CC-0012".
- Payment method chips: Efectivo, Nequi, Daviplata, Transferencia, Tarjeta, Otro.
- Quote text: "Válida por 15 días".

</specifics>

<deferred>
## Deferred Ideas

- **Electronic invoicing with the DIAN** (Siigo/Alegra/Factus) and **VAT**: a later phase, with an accountant.
- **Partial payments**: a future phase if there is demand (surgeries).
- **A 10 per month limit on CCs in Free** (vetapp-negocio proposal): rejected for now; revisit with usage data.
- **Deducting stock when recording a dose** (Phase 6 D-05, IDEAS #50): its own phase (6.x) or later.
- **Inicio card and income charts**, plus the "Factura" quick action on Inicio: Phase 8.
- **Public link for billing documents**: rejected for privacy.
- **Offline queue**: rejected, as in Phase 6.

</deferred>

---

*Phase: 07-facturación*
*Context gathered: 2026-11-13*
