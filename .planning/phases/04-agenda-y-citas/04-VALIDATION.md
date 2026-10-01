---
phase: 4
slug: agenda-y-citas
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-09-30
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: `04-RESEARCH.md` §Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (SDK) + Riverpod overrides; `test/helpers/{fake_*.dart, router_harness.dart}`; SQL smoke `supabase/tests/rls_smoke_test.sql` (manual, Supabase SQL Editor, ends with `RLS SMOKE: PASS/FAIL`) |
| **Config file** | none — same convention as Phases 1-3 |
| **Quick run command** | `flutter test test/<file>_test.dart` |
| **Full suite command** | `flutter analyze && flutter test` (via `vetapp-gate` → `GATE: GREEN/RED/BLOCKED`) |
| **Estimated runtime** | ~20-30 seconds |

---

## Sampling Rate

- **After every task commit:** the relevant `flutter test test/<file>_test.dart` + `dart analyze` on touched files
- **After every plan wave:** `flutter analyze && flutter test` via `vetapp-gate`; SQL waves also run `rls_smoke_test.sql` (human applies schema to the cloud project first)
- **Before `/gsd:verify-work`:** full suite green, `RLS SMOKE: PASS`, `vetapp-brand-ui` audit, device UAT
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

Plan/task IDs are assigned by the planner; requirement → test mapping:

| Requirement | Behavior | Test Type | Automated Command | File Exists | Status |
|-------------|----------|-----------|-------------------|-------------|--------|
| AGND-01 | Bogota week bounds; 23:30/00:15 boundary; non-cancelled/no_asistio counts per day | unit | `flutter test test/zona_bogota_test.dart` | ✅ | ✅ green |
| AGND-01 | DayStrip counts/selection, opens on Hoy, week nav, loading/empty/error, "Próxima" banner | widget | `flutter test test/agenda_screen_test.dart` | ✅ | ✅ green |
| AGND-01 | RLS: vet A ≠ vet B citas/cita_mascotas; CLIENTE sees 0 | SQL smoke | `rls_smoke_test.sql` | ✅ | ✅ green |
| AGND-02 | `crear_cita` atomic w/ N mascotas; rejects other owner/clinic mascota; domicilio requires dirección | SQL smoke | `rls_smoke_test.sql` | ✅ | ✅ green |
| AGND-02 | Form: required fields, motivo→duration, domicilio prefill, overlap dialog, first free slot, combined-alta return | widget+unit | `flutter test test/cita_form_screen_test.dart test/cita_solapes_test.dart` | ✅ | ✅ green |
| AGND-02 | Overlap/free-slot pure functions (back-to-back, edit excludes self, cancelada/no_asistio ignored, 15-min rounding) | unit | `flutter test test/cita_solapes_test.dart` | ✅ | ✅ green |
| AGND-03 | Estado buttons, Deshacer, cancel confirm, reopen | widget/provider | `flutter test test/cita_actions_test.dart` | ✅ | ✅ green |
| AGND-03 | `estado` check rejects invalid; `solicitada` accepted, not exposed | SQL smoke | `rls_smoke_test.sql` | ✅ | ✅ green |
| AGND-04 | Reminder plan builder: pendiente/confirmada only, future, lead time, horizon, deterministic ids | unit | `flutter test test/recordatorios_plan_test.dart` | ✅ | ✅ green |
| AGND-04 | Reschedule on create/edit/estado/setting; cancel all on sign-out; permission banner/rationale | provider/widget | `flutter test test/recordatorios_providers_test.dart` | ✅ | ✅ green |
| AGND-05 | Phone normalizer (celular, 57, +/00 foreign, fijo 60X, empty; idempotent) | unit | `flutter test test/telefono_co_test.dart` | ✅ | ✅ green |
| AGND-05 | D-14 template text; wa.me encoding; disabled states; batch sheet state machine | unit/widget | `flutter test test/whatsapp_recordatorio_test.dart test/recordar_manana_sheet_test.dart` | ✅ | ✅ green |
| AGND-06 | `registrar_consulta(p_cita_id)` link, wrong mascota rejected, unique (cita,mascota), append-only holds | SQL smoke | `rls_smoke_test.sql` | ✅ | ✅ green |
| AGND-06 | Completar flow (registrar/omitir/finalizar/sin consulta, Deshacer); ConsultaForm with citaId prefill; existing consulta tests pass | widget | `flutter test test/completar_cita_screen_test.dart test/consulta_form_screen_test.dart test/consultas_providers_test.dart` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/helpers/fake_citas.dart`, `fake_recordatorios.dart`, `fake_url_launcher.dart`
- [ ] `test/zona_bogota_test.dart`, `telefono_co_test.dart`, `cita_solapes_test.dart`, `whatsapp_recordatorio_test.dart`, `recordatorios_plan_test.dart`
- [ ] `routerHarness` reuse with `es_CO` locale + localization delegates where date picker opens
- [ ] `supabase/tests/rls_smoke_test.sql` new sections for citas/cita_mascotas/crear_cita/registrar_consulta(p_cita_id)
- [ ] Android build spike: `flutter build apk --debug` after Gradle/manifest changes

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Permission rationale + OS prompt, denied banner "Activar" | AGND-04 | OS runtime permission | Android 13+: first cita → rationale → prompt; deny twice → banner opens settings |
| Notification fires at T-lead; tap opens `/agenda/:id` | AGND-04 | Real OS scheduler / Doze | Cita 17 min out, 15-min lead; allow minutes of slack; also cold start |
| Survives reboot, no duplicates after resync | AGND-04 | Boot receiver | Reboot with pending reminder; check `pendingNotificationRequests()` |
| No reminders after sign-out | AGND-04 | OS tray | Sign out, wait past reminder time |
| WhatsApp opens with exact text; fallback; fixed line disabled | AGND-05 | External app | Tap individual button on 3 numbers |
| "Recordar a todos los de mañana" serial flow | AGND-05 | App lifecycle with WhatsApp | 3 clients tomorrow; mark-on-return + manual fallback |
| "Cómo llegar" opens Maps | D-02 | External app | Domicilio cita → tap |
| Non-Bogota device timezone | AGND-01/04 | Device setting | Set device to UTC; day boundaries and reminder times remain Bogota |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-10-01 (automated suite green; manual device UAT approved by user on emulator)
