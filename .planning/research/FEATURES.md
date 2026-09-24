# Feature Research

**Domain:** Veterinary practice management software — mobile-first, for independent/solo veterinarians and small clinics in Colombia
**Researched:** 2026-09-23
**Confidence:** MEDIUM-HIGH (feature landscape verified across multiple competitor sources; Colombia-specific regulatory details MEDIUM confidence — verify DIAN/IVA specifics with an accountant before building tax logic)

## Feature Landscape

### Table Stakes (Users Expect These)

Every competitor analyzed (Vetlogy, GVET, Panacea, Digitail, IDEXX Neo, Provet Cloud, DaySmart Vet/Vetter, Shepherd) has these. Missing any of them makes the product feel unfinished next to the incumbents a Colombian vet already knows.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Patient (pet) records — species, breed, age, weight, photo, owner link | Baseline of every PIMS (Practice/Patient Information Management System) in existence; Vetlogy, Digitail, IDEXX Neo all lead with this | LOW-MEDIUM | Already in VetApp scope. Weight history matters — feeds dosage calc and growth tracking. |
| Client (owner) records — contact info, linked pets, visit history | Same as above; needed for billing and reminders too | LOW | Already in scope. |
| Digital clinical history (anamnesis, exam, diagnosis, treatment, evolution) with timeline per patient | Vetlogy explicitly markets "the most complete medical module in Colombia with all guidelines"; IDEXX Neo's core pitch is "one-click access to complete patient history." This is the professional/legal record of care. | MEDIUM-HIGH | Colombian vets expect the SOAP-like structure (anamnesis → examen físico → diagnóstico → tratamiento → evolución) — matches what's already planned in PROJECT.md. |
| PDF export of clinical record | Needed for referrals, insurance, legal requests, pet travel | LOW-MEDIUM | Standard `pdf`/`printing` package territory in Flutter; not a differentiator, just expected. |
| Appointment scheduling / agenda | Every competitor has a calendar; IDEXX Neo dashboard leads with "today's appointments" | MEDIUM | Solo vet needs simple day/week view, not multi-provider scheduling (that's clinic-with-reception territory). |
| Appointment reminders (push/SMS/email) | Digitail: "automatically reminds clients... to reduce no-shows." Table stakes across the board. | LOW-MEDIUM | Push notifications via FCM/Supabase; WhatsApp is the Colombia-specific upgrade (see Differentiators). |
| Vaccination & deworming digital card with next-dose alerts | Vetlogy explicitly lists "reminders for upcoming vaccinations and deworming" as a headline feature; it is also a legal/practical necessity in Colombia (antirábica is ICA-mandated, fines up to ~$500,000 COP for non-compliance) | MEDIUM | Must model recurring schedules (e.g., annual/triennial rabies booster, puppy/kitten series) not just one-off dates. |
| Basic inventory of medicines/supplies with low-stock alerts | GVET: "controlar... stock"; Vetlogy: "counter inventory, intrahospital inventory... in real time" | MEDIUM | For a solo vet this can be simple (SKU, qty, reorder threshold) — no need for multi-warehouse or lot/batch tracking at MVP. |
| Simple invoicing / quotes (PDF receipt) | GVET, Vetlogy, Panacea, IDEXX Neo all have billing/invoicing as core | MEDIUM | This is the pre-DIAN "recibo/cotización" step already scoped; DIAN e-invoicing is a separate, harder feature (see Differentiators / regulatory pitfall). |
| Cloud backup / data persistence | Table stakes for any paid professional tool — losing medical records is unacceptable | LOW (if using Supabase, this is inherent) | Already covered by backend choice. |
| Basic dashboard / stats (consultations this month, revenue, new patients) | Original prompt lists this explicitly; IDEXX Neo's dashboard is one of its most marketed screens | LOW-MEDIUM | Simple counts/sums over existing tables — no separate analytics engine needed. |
| Search/filter across patients and clients | Implicit expectation once patient count grows past ~50 | LOW | Missing this is invisible in a demo but painful in real use — flag for QA. |

### Differentiators (Competitive Advantage)

These are where VetApp can win against desktop/reception-oriented incumbents. They should map directly to the "mobile-first solo/house-call vet in Colombia" positioning already stated in PROJECT.md.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| True mobile-first UX (not a responsive web app) | All researched incumbents (Vetlogy, GVET, Panacea, IDEXX Neo, Provet Cloud) are web/cloud platforms "accessible from any device with internet" — built for a receptionist at a desktop, then squeezed onto mobile. A Flutter app designed natively for one-handed, on-the-go use during a consult or house call is a structural advantage, not just a feature. | Already the core architecture decision | This is the #1 differentiator; every other feature below should reinforce it rather than compete with it. |
| Offline-first with background sync | Named explicitly in the original vision and confirmed as a real gap: incumbents offer "access from any device with internet" (GVET, Provet Cloud) but not true offline capture. Rural Colombia and home visits have unreliable connectivity. AcuroVet (a mobile-vet-focused competitor in the US market) calls out "offline access, auto-syncing" as a headline differentiator — confirming this is a recognized gap even in more mature markets. | HIGH | Currently deferred in PROJECT.md ("se evalúa después del CRUD online"). Correctly deferred for now, but flag it as a phase in the roadmap once online CRUD is solid — conflict resolution (edits made offline by the same vet on two devices) is the main technical risk. |
| WhatsApp-native reminders (appointments, vaccination due dates, invoices) | WhatsApp is the dominant client-communication channel in Colombia; no direct competitor researched (Vetlogy, GVET, Panacea, Digitail, IDEXX Neo) integrates it natively — Vetlogy does mention "automatic WhatsApp reminders" as a 2023+ addition, so this bar is rising, not static. Utility-template WhatsApp messages are cheap (~COP 35-120/conversation via Business API, or free via deep-link `wa.me` prefilled message for MVP). | LOW (deep-link MVP) → MEDIUM-HIGH (full Business API with templates/automation) | Two implementation tiers: (1) MVP — `wa.me` deep link with prefilled text, vet taps to send manually, zero backend cost; (2) V2 — WhatsApp Business API with approved templates for true automated reminders, needs a BSP (e.g., Twilio, 360dialog) and per-message cost. Start with tier 1; it alone already beats most incumbents' "email/push only" reminders. |
| Shareable digital vaccination card (public link or PDF) | Explicitly named in the original vision as a real, unsolved pain point — owners need to show proof of vaccination at daycare, grooming, boarding, or when traveling. Verified via WebSearch: single-purpose competitors (Pet-ID, VetCard, Vetipass in Colombia) exist ONLY to solve this problem, confirming real demand, but none of them are integrated into a full practice-management workflow — they're standalone consumer apps disconnected from the vet's clinical record. | MEDIUM | Differentiator specifically because it closes the loop: the vet's own clinical system produces the shareable artifact, vs. the owner re-entering data into a separate app. Public link should be read-only, revocable, and not expose full clinical history — only vaccination status. |
| DIAN e-invoicing (Colombia) | Table stakes for Vetlogy already (it markets "free DIAN electronic billing"), so this is catching up, not leading — but still a real differentiator vs. Digitail/IDEXX Neo/Provet Cloud (non-Colombian platforms with zero DIAN support). | HIGH | Requires integration with an authorized technology provider (Siigo, Alegra, Factus) via API — cannot build DIAN compliance from scratch. IMPORTANT regulatory nuance (MEDIUM confidence, verify with accountant): veterinary services to pets (dogs/cats) are generally NOT IVA-exempt in Colombia — exemption only applies to animal-health services certified by ICA for agricultural/livestock production. Do not assume vet consultations are tax-exempt; invoicing logic must charge IVA on companion-animal services by default. |
| AI voice-to-clinical-note (ambient scribe) | Validated as a live 2025-2026 trend: multiple dedicated products (ScribbleVet, Scribenote, VetRec, VetGeni, VetDoze, PawfectNotes) exist specifically to solve "hands busy with the patient, can't type." None of the Colombian incumbents (Vetlogy, GVET, Panacea) offer this yet — genuine differentiator in the local market even though it's becoming commoditized globally. | HIGH | Needs Spanish-language medical transcription (most scribe products above are English-first) — verify LLM/STT model has acceptable Spanish veterinary vocabulary accuracy before committing. Realistic as fase 2/3, not MVP. |
| AI-assisted dosage suggestions by weight/species | VetDoze and PawfectNotes both ship a dosing engine keyed to patient weight + species as a named feature — validates real demand, but it is also a patient-safety-critical feature: wrong output is a liability, not just a bad UX moment. | MEDIUM-HIGH | If built, treat as advisory only ("suggested range, confirm before administering") never an auto-filled prescription; log the source formula/reference used, and prefer a deterministic formula lookup table (calibrated against Plumb's or ICA-approved reference doses) over free-form LLM generation for the dosage number itself — reserve AI for interpreting the SOAP text, not for computing drug math. |
| Pricing/plans built for the informal, one-person Colombian vet (COP-priced, freemium, no long contracts) | Prompt document explicitly names this: most competitors "charge in dollars or have plans built for established clinics." This is a business-model differentiator, not a code feature, but affects what "free tier" limits should exist (e.g., patient count cap) in the app itself. | LOW (product decision, not engineering) | Worth flagging to whoever owns pricing — not a roadmap/engineering item, but influences which features must work well even on a free tier. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|------------------|-------------|
| Full multi-provider/multi-clinic scheduling (calendar with multiple vets, rooms, resources) | "Looks more professional/enterprise," mirrors what IDEXX Neo/Digitail offer for clinics with staff | The entire product thesis is solo/independent vet without a receptionist. Multi-user scheduling adds real-time conflict handling, roles/permissions, and a UI complexity that fights the mobile-first, one-handed design goal. Already correctly deferred to "fase 3" in PROJECT.md. | Single-owner calendar, sorted by day, with simple day/week toggle. Revisit only if user research shows multiple vets sharing one account. |
| Pet-owner-facing companion app (owner logs in to see history/appointments) | Digitail and GVET both offer this, and it look like a natural "differentiator" | Doubles the app surface (a second app, second auth flow, second design system) before the core vet-facing product is proven; explicitly deferred to fase 3 in PROJECT.md and correctly so. | Ship the shareable vaccination-card link/PDF as a lightweight, no-login substitute — gives owners the single artifact they actually want (proof of vaccination) without building a second product. |
| Telemedicine / video consultation | "Competitors like Provet Cloud/Digitail offer remote consults," feels like a growth feature | Video infra (WebRTC/third-party SDK), signaling, bandwidth handling — all in direct tension with the offline-first, rural-connectivity target user. A vet with bad signal doing a house call is the opposite of the persona who wants video calls. | Defer indefinitely; if ever built, treat as a separate low-bandwidth "photo + WhatsApp voice note" async workflow rather than live video, which fits the existing WhatsApp-reminder infrastructure. |
| Full DIAN e-invoicing built in-house (own signing, own XML/UBL generation, own DIAN habilitación) | Seems like "we control the whole stack, no per-invoice fees" | DIAN requires becoming an authorized/habilitado provider or integrating with one — building the compliance layer from scratch is a multi-month legal+technical project completely outside a mobile app's core competency, and errors have direct tax/legal consequences for the vet. | Integrate via API with an existing authorized provider (Siigo, Alegra, Factus) as already scoped — this is a partner integration, not a build. |
| Free-form LLM-generated drug dosages (no lookup table, no guardrails) | "AI can just calculate it from weight," feels like the fastest way to ship the differentiator | Dosage errors are a direct animal-safety and vet-liability issue; LLMs can hallucinate confident-sounding wrong numbers, and there is no way to audit "why did it suggest this dose" after the fact | Deterministic dosage tables/formulas per drug+species, reviewed against a veterinary pharmacology reference (e.g., Plumb's), with AI limited to natural-language interpretation of the SOAP note, not to generating the number itself |
| Real-time everything (live multi-device sync of every field, presence indicators, etc.) | Sounds "modern," matches consumer-app expectations (Google Docs-style collaboration) | Single-user-per-account product (solo vet) doesn't need live collaboration; this adds websocket/state-sync complexity that directly competes with the offline-first requirement (a field can't be "live synced" and "offline-durable" with the same simple design) | Standard CRUD + eventual sync on reconnect (already the plan) — optimize for "correct after sync," not "instant during edit." |
| Comprehensive multi-warehouse/lot-and-batch inventory tracking | "Real" pharmacies/clinics track batch numbers and expiry per lot for recalls | Solo vet's inventory is a handful of shelves, not a warehouse; batch/lot tracking is a data-entry burden with no payoff at this scale, and it's what desktop incumbents (Vetlogy's "intrahospital + counter + hospitalization" split) already over-engineer for bigger clinics | Simple SKU + quantity + reorder threshold + (optional, single) expiry date field — reintroduce lot tracking only if a real clinic customer asks for regulatory reasons |

## Feature Dependencies

```
Patient (pet) records
    └──requires──> Client (owner) records (every pet must link to an owner)

Digital clinical history
    └──requires──> Patient records
    └──enhances──> Vaccination card (vaccines administered during a consult should log into history)

Vaccination/deworming card + next-dose alerts
    └──requires──> Patient records
    └──enhances──> WhatsApp reminders (vaccine-due alert is a reminder payload)
    └──enhances──> Shareable vaccination card (public link renders from this same data)

Appointment scheduling
    └──requires──> Client + Patient records
    └──enhances──> WhatsApp reminders (appointment reminder is a reminder payload)

Simple invoicing/quotes (PDF)
    └──requires──> Patient + Client records
    └──requires──> Inventory (if invoice line items pull priced products/services)
    └──enhances──> DIAN e-invoicing (DIAN is invoicing + tax compliance layered on top of the same line items)

DIAN e-invoicing
    └──requires──> Simple invoicing/quotes (must exist first as the data model)
    └──requires──> External provider integration (Siigo/Alegra/Factus) ──conflicts with── "build in-house" anti-feature

Basic inventory
    └──enhances──> Simple invoicing (stock deduction on sale)
    └──enhances──> Low-stock alerts (reminder payload, same mechanism as vaccine/appointment alerts)

Offline-first + sync
    └──enhances──> ALL of the above (every module benefits, none strictly require it for MVP)
    └──conflicts with── "real-time everything" anti-feature (cannot have both live sync and offline-durable writes with the same simple design)

AI voice-to-clinical-note
    └──requires──> Digital clinical history (needs the structured fields to fill)
    └──enhances──> Consultation speed, not a standalone module

AI dosage suggestions
    └──requires──> Patient records (species/weight)
    └──enhances──> Digital clinical history (suggested dose surfaces during treatment entry)

Shareable vaccination card (public link)
    └──requires──> Vaccination/deworming card (same underlying data, different renderer)
    └──conflicts with── exposing full clinical history publicly (must be scoped to vaccination data only, not the whole record)
```

### Dependency Notes

- **Everything requires Client + Patient records:** these two entities are the foundation; every other module (history, agenda, vaccination, invoicing) is a child table pointing at a pet and/or an owner. This confirms the phase-1 scope already defined in PROJECT.md is correctly ordered.
- **WhatsApp reminders enhances three features, not one:** appointment reminders, vaccine-due alerts, and low-stock alerts (if the vet also gets an internal WhatsApp nudge) are all just different payloads through the same "send a WhatsApp message" mechanism. Build the reminder-sending capability once, generically, then wire three trigger sources into it — do not build three separate WhatsApp integrations.
- **DIAN e-invoicing requires simple invoicing first:** the line-item/quote data model must exist and be stable before adding a tax-compliance layer on top; trying to build both at once conflates "what did we charge" with "how do we report it to DIAN," which are separable concerns.
- **Offline-first is an enhancer, not a hard blocker, for MVP:** correctly deferred in PROJECT.md. It should be evaluated per-module once online CRUD works — clinical history (append-mostly, low conflict risk) is a much easier offline target than inventory (concurrent stock decrements are a classic sync-conflict source).
- **Shareable vaccination card conflicts with exposing full history:** the public link must be a narrow, read-only view (vaccine name, date, next-due date, vet's clinic name) — never a general "share my patient record" link, which would be a data-privacy/HIPAA-style incident waiting to happen for a health record.
- **AI dosage suggestions conflicts with free-form LLM generation (anti-feature):** the "enhances" relationship to clinical history only holds if the actual number comes from a deterministic table, not from the same LLM call that drafts the note text.

## MVP Definition

### Launch With (v1)

Minimum viable product — matches what's already scoped as "Active" in PROJECT.md. Confirmed correct by this research: every item below is table stakes across all competitors reviewed.

- [ ] Client (owner) records — foundation for everything else
- [ ] Patient (pet) records — foundation for everything else
- [ ] Digital clinical history (anamnesis/exam/diagnóstico/tratamiento/evolución) with per-patient timeline, PDF export
- [ ] Appointment scheduling with reminders (push notification is enough for v1; WhatsApp deep-link can piggyback cheaply — see below)
- [ ] Vaccination/deworming digital card with next-dose alerts
- [ ] Basic inventory with low-stock alerts
- [ ] Simple invoicing/quotes as PDF (no DIAN yet)
- [ ] Basic dashboard (consultations this month, revenue, new patients)

### Add After Validation (v1.x)

Cheap-to-add differentiators that don't require new infrastructure — worth pulling into v1.x once the core CRUD above is real and stable, because they are low complexity relative to their competitive payoff:

- [ ] WhatsApp deep-link reminders (`wa.me` prefilled message, vet taps send) — trigger for adding: as soon as appointment/vaccine reminder data exists, this is nearly free to wire in and is an immediate differentiator vs. all Colombian incumbents' push/email-only reminders
- [ ] Shareable vaccination card (public read-only link or downloadable PDF) — trigger for adding: once the vaccination module is stable, this reuses the same data with a new renderer and directly answers the "guardería/viaje" pain point named in the product vision

### Future Consideration (v2+)

Features to defer until the mobile-first core has real users and feedback — matches "Out of Scope" in PROJECT.md, now cross-checked against competitor maturity:

- [ ] Full WhatsApp Business API automation (auto-sent reminders, not tap-to-send) — defer until reminder volume justifies the per-message cost and the BSP integration effort
- [ ] DIAN e-invoicing via Siigo/Alegra/Factus — defer until the vet actually needs to invoice electronically at volume (many solo/informal vets in Colombia currently under-invoice or use manual receipts; validate real demand before integrating)
- [ ] AI voice-to-clinical-note — defer until Spanish-language STT/scribe accuracy is validated; commoditizing fast globally but not yet offered by any Colombian competitor, so timing is not urgent
- [ ] AI-assisted dosage suggestions — defer until a deterministic dosage-table data source is sourced and reviewed; do not ship LLM-only dosage math
- [ ] Offline-first with background sync — defer until online CRUD is proven end-to-end; then prioritize clinical history and vaccination modules first (lower conflict risk) before inventory (higher conflict risk)
- [ ] Pet-owner companion app, multi-vet/multi-clinic accounts, telemedicine — correctly deferred to fase 3; revisit only after solo-vet product-market fit

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|----------------------|----------|
| Patient + client records | HIGH | LOW | P1 |
| Digital clinical history + PDF | HIGH | MEDIUM | P1 |
| Appointment scheduling + push reminders | HIGH | MEDIUM | P1 |
| Vaccination/deworming card + alerts | HIGH | MEDIUM | P1 |
| Basic inventory + low-stock alerts | MEDIUM | MEDIUM | P1 |
| Simple invoicing/quotes (PDF) | HIGH | MEDIUM | P1 |
| Basic dashboard/stats | MEDIUM | LOW | P1 |
| WhatsApp deep-link reminders | HIGH | LOW | P2 |
| Shareable vaccination card | HIGH | MEDIUM | P2 |
| Offline-first + sync | HIGH (rural/house-call segment) | HIGH | P2 |
| DIAN e-invoicing | MEDIUM (grows with formalization) | HIGH | P3 |
| Full WhatsApp Business API automation | MEDIUM | MEDIUM-HIGH | P3 |
| AI voice-to-clinical-note | MEDIUM (novel, not yet expected) | HIGH | P3 |
| AI dosage suggestions | MEDIUM (safety-sensitive) | MEDIUM-HIGH | P3 |
| Pet-owner companion app | LOW (at this stage) | HIGH | P3 |
| Telemedicine | LOW (conflicts with offline/rural persona) | HIGH | Do not build (anti-feature) |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | Vetlogy (Colombia) | GVET / Panacea (Colombia) | Digitail / IDEXX Neo (International) | Our Approach |
|---------|--------------------|-----------------------------|----------------------------------------|---------------|
| Platform | Web/cloud (SaaS), "access from any device" | Web/cloud | Cloud web + companion mobile apps | Native Flutter mobile-first, designed for one-handed field use — not a responsive web wrapper |
| Offline capability | None found (cloud-dependent) | None found (cloud-dependent) | None found (cloud-dependent) | Offline-first with background sync (v2, after online CRUD proven) |
| Clinical history | Very complete, "10+ specialized consultation types," Colombia-guideline compliant | Web-based, template-driven | SOAP templates, collaborative records, AI SOAP dictation (Digitail) | Structured anamnesis/exam/diagnóstico/tratamiento/evolución, PDF export, timeline per patient |
| Vaccination reminders | Yes — birthdays, vaccination, deworming reminders + WhatsApp | Not confirmed in research | Push/email/text reminders (Digitail); no vaccination-specific card found | Vaccination card with automatic next-dose alerts (already table stakes, keep) |
| WhatsApp integration | Yes (as of ~2023+), automatic reminders | Not confirmed | No | Match with deep-link MVP, then Business API automation later — do not treat this as a novel differentiator anymore since Vetlogy already has it, but still ahead of GVET/Panacea/Digitail/IDEXX Neo |
| Shareable vaccination card | Not confirmed as integrated (Vetlogy has mobile app w/ gamification, not confirmed shareable card) | Not confirmed | Pet-parent app gives access to records (Digitail), not vaccination-specific shareable artifact | Build as a lightweight public link/PDF — appears to be a genuine gap even vs. Vetlogy |
| DIAN e-invoicing | Yes, free, headline feature | Not confirmed | No (not Colombia-focused) | Must match eventually (v2/v3) via Siigo/Alegra/Factus API — currently a catch-up item vs. Vetlogy, not a lead |
| Inventory | Counter + intrahospital + hospitalization inventory (comprehensive) | Stock control confirmed | Real-time inventory updates (Digitail) | Simple SKU+qty+threshold for solo vet — deliberately less granular than Vetlogy's multi-tier system (anti-feature: over-engineering for clinic scale) |
| AI features | None found | None found | AI SOAP dictation (Digitail only, international) | Voice-to-note and dosage suggestions as v2/v3 differentiators — ahead of all Colombian competitors currently |
| Pricing model | Not fully disclosed, positioned as "#1 in Colombia," 1000+ clinics — likely clinic-tier pricing | Not confirmed | USD-denominated, clinic-oriented plans | COP-priced, freemium/low-cost tier targeting the informal solo vet — a business-model differentiator, not just a feature |

## Sources

- [VETLOGY — Software Veterinario En La Nube](https://vetlogy.com/) — feature list, market position (MEDIUM confidence, vendor marketing site)
- [Software Veterinario Colombia | VETLOGY](https://softwareveterinario.com/) — DIAN billing, WhatsApp reminders
- [Digitail: Features of the Best Practice Management Software](https://digitail.com/features/) — scheduling, records, billing, pet-parent app
- [Digitail: All-in-one Cloud Veterinary Software for Mobile Vets](https://digitail.com/mobile-vets/) — mobile-vet positioning
- [GVET Software Veterinario: precios, funciones y opiniones](https://www.comparasoftware.com/gvet-software-veterinario) — GVET feature summary
- [Comparación de los principales softwares para veterinarios](https://www.diarioveterinario.com/t/3749848/comparacion-principales-softwares-veterinarios) — Panacea summary
- [IDEXX Neo Software | Cloud-Based Software](https://software.idexx.com/products/neo) — core PMS feature set
- [Vetipass — Dónde Vacunar a tu Perro Gratis en Bogotá](https://www.vetipass.com/blog/prevencion/perros/donde-vacunar-a-mi-perro-gratis-bogota) — Colombian vaccination-card app example
- [Pet-ID | Pasaporte digital de vacunación](https://pet-id.app/) and [VetCard | Libreta sanitaria digital](https://vetcard.pet/) — standalone shareable vaccination card competitors (LatAm-adjacent)
- [Más mascotas — Vacunas obligatorias para perros y gatos en Colombia (2025)](https://masmascotas.co/vacunas-obligatorias-para-perros-y-gatos-en-colombia/) — vaccine schedule specifics
- [Lineamiento para el manejo de biológico antirrábico de perros y gatos — MinSalud](https://www.minsalud.gov.co/sites/rid/Lists/BibliotecaDigital/RIDE/VS/PP/SA/lineamiento-manejo-biologico-antirrabico-perros-gatos.pdf) — official regulatory source, HIGH confidence
- [Exclusión de IVA en servicios veterinarios y bienestar animal — DIAN Concepto 1431 (Cr Consultores)](https://crconsultorescolombia.com/exclusion-de-iva-en-servicios-veterinarios-y-bienestar-animal-dian-concepto-1431012149.php) — IVA exemption scope, MEDIUM confidence (secondary source summarizing a DIAN concept; recommend verifying directly with an accountant before implementing tax logic)
- [Facturación Electrónica DIAN para Veterinarias — softwareveterinario.com](https://softwareveterinario.com/blog/facturacion-electronica-dian-veterinarias) — DIAN e-invoicing requirements for vet clinics
- [Best Veterinary Software for Mobile and Housecall Vets — PetDesk](https://petdesk.com/best-veterinary-software-for-mobile-vets) — mobile/housecall competitor landscape (US market, informative for positioning)
- [AcuroVet — Essential Tools for Mobile Veterinarians](https://acurovet.com/blog/essential-tools-for-mobile-veterinarians-&-other-vets) — offline access + auto-sync as a named mobile-vet differentiator
- [Best AI Voice Tools for Veterinarians in 2026](https://zackproser.com/blog/ai-voice-tools-for-veterinarians) and product pages for [ScribbleVet](https://www.scribblevet.com/), [Scribenote](https://www.scribenote.com/), [VetRec](https://vetrec.io/), [VetGeni](https://www.vetgeni.com/veterinary-soap-notes), [VetDoze](https://www.vetdoze.com/), [PawfectNotes](https://pawfectnotes.com/free-veterinary-tools/drug-dosage-calculator/) — AI scribe and dosage-calculator feature validation
- [Precios WhatsApp Business API 2026 — Simla.com](https://www.simla.com/blog/precios-whatsapp-business-api) — per-message cost data for Colombia

---
*Feature research for: Veterinary practice management (mobile-first, Colombia, solo/independent vet segment)*
*Researched: 2026-09-23*
