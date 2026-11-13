# Phase 7: Facturación - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-11-13
**Phase:** 07-facturación
**Areas discussed:** Legal document type, Building the invoice, Stock deduction rules, Payment/sharing/plan, Permissions/navigation, Offline/PDF/client data

In every question the user picked the recommended option. The table lists the alternatives that were offered.

## Legal document type

| Question | Chosen | Alternatives |
|---|---|---|
| Document name | Cotización + Cuenta de cobro | Cotización + Recibo · Cotización + Factura (with disclaimer) |
| Numbering | Sequential per clinic (server) | No number |
| VAT | No VAT in v1 | Optional VAT % per item |
| Issuer data | Clinic + optional NIT/cédula | Clinic data only |

## Building the invoice

| Question | Chosen | Alternatives |
|---|---|---|
| Entry point | From appointment/consultation + standalone | Standalone only |
| Services | Saved services list | Free text each time |
| Line price | Editable per line | Fixed price |
| Global discount | No, in v1 | Optional $ or % |
| Quote to CC | One tap | Separate documents |
| Editing a CC | Void and reissue | Editable while pending |

## Stock deduction rules

| Question | Chosen | Alternatives |
|---|---|---|
| When to deduct | On issuing the CC | On marking paid |
| More than stock | Block with a clear message | Allow negative with a warning |
| Voiding | Stock returns automatically | Ask per product |
| Archived products | Can't be added | Show with a warning |

## Payment, sharing, plan

| Question | Chosen | Alternatives |
|---|---|---|
| Payment | Pending/Paid + method | Pending/Paid only · Partial payments |
| Sharing | PDF via WhatsApp + share sheet | Public link like the carnet |
| Income | Simple header on Cobros | Nothing yet |
| Plan limit | No limit, all plans | 10 per month in Free |

## Permissions and navigation

| Question | Chosen | Alternatives |
|---|---|---|
| Permissions | Any vet issues and charges; admin or the issuer voids | Any vet can do everything |
| Navigation | Más > Cobros + "Cobrar" shortcuts | Also a quick action on Inicio now |

## Offline, PDF, client data

| Question | Chosen | Alternatives |
|---|---|---|
| Offline | Clear failure, no queue, with an idempotency key | Offline queue |
| PDF | Same style as the carnet | Minimal receipt |
| Quote validity | "Válida por 15 días" | Nothing |
| Client data | Full name + optional ID | Name only |

## Claude's Discretion

- Table, RLS and RPC model (Phase 6 pattern).
- Seed of the services list.
- Form and PDF layout, within the UI-SPEC.

## Deferred Ideas

- DIAN and VAT.
- Partial payments.
- Limit of 10 per month in Free.
- Deducting stock when recording a dose.
- Inicio card, charts and quick action (Phase 8).
- Public link for billing documents.
- Offline queue.
