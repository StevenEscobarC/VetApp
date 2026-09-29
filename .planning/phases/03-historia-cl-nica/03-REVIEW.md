---
phase: 03-historia-cl-nica
reviewed: 2026-09-29T00:00:00Z
depth: standard
files_reviewed: 25
files_reviewed_list:
  - README.md
  - lib/core/utils/formato.dart
  - lib/features/clients/presentation/clientes_routes.dart
  - lib/features/clinical_history/data/repositories/supabase_consulta_repository.dart
  - lib/features/clinical_history/data/services/historia_clinica_pdf_service.dart
  - lib/features/clinical_history/domain/consulta_failure.dart
  - lib/features/clinical_history/domain/entities/consulta.dart
  - lib/features/clinical_history/domain/formato_consulta.dart
  - lib/features/clinical_history/presentation/providers/consultas_providers.dart
  - lib/features/clinical_history/presentation/providers/historia_clinica_pdf_providers.dart
  - lib/features/clinical_history/presentation/screens/consulta_form_screen.dart
  - lib/features/clinical_history/presentation/widgets/historia_clinica_timeline.dart
  - lib/features/patients/presentation/pacientes_routes.dart
  - lib/features/patients/presentation/screens/mascota_detail_screen.dart
  - pubspec.yaml
  - supabase/schema.sql
  - supabase/tests/rls_smoke_test.sql
  - supabase/tests/verify_live_schema.sh
  - test/consulta_form_screen_test.dart
  - test/consultas_providers_test.dart
  - test/formato_test.dart
  - test/helpers/fake_consultas.dart
  - test/helpers/fake_pdf.dart
  - test/historia_clinica_pdf_service_test.dart
  - test/mascota_detail_screen_test.dart
  - test/mascota_form_screen_test.dart
findings:
  critical: 0
  warning: 4
  info: 3
  total: 7
status: issues_found
---

# Phase 03: Historia Clínica — Code Review Report

**Reviewed:** 2026-09-29
**Depth:** standard
**Files Reviewed:** 25 (source + tests, per `files` scope in config)
**Status:** issues_found

## Summary

Reviewed the Fase 3 "Historia Clínica" slice: the `consultas` schema delta + `registrar_consulta` RPC (`supabase/schema.sql`), the Supabase repository/provider/domain layers, the "Nueva consulta" form, the read-only clinical timeline, the PDF export service/provider, their wiring into `MascotaDetailScreen`, and the associated tests.

The core design is sound: RLS on `consultas` correctly scopes by `clinica_id` through the owning `mascotas` row, `veterinario_id` is pinned server-side (`auth.uid()`, not client-supplied) so it can't be spoofed even on a direct insert, the append-only contract (HIST-04, no update/delete policy) is enforced both in SQL and verified by `rls_smoke_test.sql` (G10/G11/H-series), the PDF/consulta write paths are properly wrapped in domain-specific `Failure` types, and no SQL/command injection, hardcoded secrets, or unsafe eval-equivalents were found anywhere in this slice.

No Critical/security-blocking issues were found. The Warnings below are correctness/robustness gaps: a missing re-entrancy guard on two save actions (risk of duplicate permanent records on a fast double-tap, inconsistent with the guard already present on the PDF export action in the same file), a client-side validation boundary that doesn't match the underlying `numeric(4,1)` column precision (producing an opaque generic error instead of a validation message for boundary values), the PDF-export action staying active/enabled even while the patient failed to load, and an already partially-acknowledged `ON DELETE CASCADE` on `consultas.veterinario_id` that would silently destroy clinical records if a vet account is ever deleted. Info items note some literal/helper duplication and a minor stale-error-text UX detail.

## Warnings

### WR-01: No re-entrancy guard on "Guardar consulta" / "Guardar" (peso) — duplicate permanent record on fast double-tap

**File:** `lib/features/clinical_history/presentation/screens/consulta_form_screen.dart:79-142` (`_ConsultaFormScreenState._submit`)
**File:** `lib/features/patients/presentation/screens/mascota_detail_screen.dart:415-442` (`_RegistrarPesoSheetState._guardar`)

**Issue:** Both `_submit()` and `_guardar()` set `_loading`/`_guardando = true` *inside* the same async function that performs validation and the network call, but neither function checks that flag before doing any work. The button only becomes visually disabled once `AppButton`'s `isLoading` prop flips and the widget rebuilds (`lib/core/widgets/buttons/app_button.dart:28`, `effectiveOnPressed = isLoading ? null : onPressed`) — i.e., disabling is reactive, not preventative. A fast double-tap (common on touch devices, and not physically impossible before the first frame's setState commits) can invoke `_submit()`/`_guardar()` twice concurrently, resulting in two `registrar_consulta` RPC calls / two `registrarPeso` calls from a single logical save action.

Because `consultas` and `mascota_pesos` are both append-only by design (HIST-04 — no update/delete policy exists), a duplicate created this way can **never be corrected or removed** by the vet; it becomes a permanent, incorrect entry in the patient's legal clinical history.

Notably, the same file's `_exportarPdf()` (`mascota_detail_screen.dart:62-64`) *does* have this guard (`if (_exportando) return;`), showing the pattern was known but not applied consistently to the save actions.

**Fix:**
```dart
// consulta_form_screen.dart
Future<void> _submit() async {
  if (_loading) return;
  const errorNumerico = 'Ingresa un valor numérico válido';
  ...
}

// mascota_detail_screen.dart (_RegistrarPesoSheetState)
Future<void> _guardar() async {
  if (_guardando) return;
  final peso = parsearPeso(_pesoCtrl.text);
  ...
}
```

### WR-02: "Exportar historia clínica a PDF" stays enabled while the patient is loading or failed to load

**File:** `lib/features/patients/presentation/screens/mascota_detail_screen.dart:160-189`

**Issue:** `build()` renders the `AppTopBar` actions (the export icon / spinner) unconditionally, outside of `mascotaAsync.when(...)`. Only the *body* is gated on `mascotaAsync` (`data`/`loading`/`error`). If `mascotaProvider` is still loading, or has settled into an `AsyncError` (body shows "No pudimos cargar la mascota. Intenta de nuevo."), the export button is still visible and tappable. Tapping it calls `_exportarPdf()`, which does `ref.read(mascotaProvider(widget.mascotaId).future)` — for the error case this immediately rethrows the same failure, caught by the generic `on MascotaFailure` branch, and shows a second, differently-worded toast ("No pudimos generar el PDF. Intenta de nuevo.") on top of a screen that already told the vet the patient failed to load. This is confusing and lets the user attempt an action on data that is known not to be available.

**Fix:** Gate the export action on `mascotaAsync` having data, e.g. move the action into the `data:` branch of the `mascotaAsync.when(...)` used for the AppBar, or compute `final canExport = mascotaAsync.hasValue;` and disable/hide the button when `!canExport`.

### WR-03: Client-side temperature validation range doesn't match the `numeric(4,1)` column precision

**File:** `lib/features/clinical_history/presentation/screens/consulta_form_screen.dart:82` (calls `parsearNumeroPositivo(_temperaturaCtrl.text)` with the default `maximo: 1000`)
**File:** `supabase/schema.sql:483` (`temperatura_c numeric(4,1) check (temperatura_c is null or temperatura_c > 0)`)

**Issue:** `parsearNumeroPositivo` (`lib/core/utils/formato.dart:69-86`) accepts any value with `0 < valor < maximo`, and the temperature field doesn't override the default `maximo: 1000`. So a value like `999.95` passes client validation. But `temperatura_c` is `numeric(4,1)` — 4 total significant digits, 1 after the decimal point — whose maximum representable magnitude is `999.9`. Postgres rounds to the declared scale before checking precision, so `999.95` rounds to `1000.0`, which no longer fits in `numeric(4,1)` and raises a `numeric field overflow` (SQLSTATE `22003`) inside the `registrar_consulta` RPC. That code is not one of the cases handled in `SupabaseConsultaRepository._messageFor` (`lib/features/clinical_history/data/repositories/supabase_consulta_repository.dart:109-121`, only `42501`/`23503`/`23514`/`23502` are mapped), so it falls through to the generic `'No pudimos guardar la consulta. Intenta de nuevo.'` — the vet gets no indication that the number they typed is the actual problem, for a value the UI itself told them was valid.

**Fix:** Cap the temperature field's `maximo` to something consistent with the column (e.g. `parsearNumeroPositivo(_temperaturaCtrl.text, maximo: 999.9)` or a physiologically sane bound like 45–50°C), and/or add SQLSTATE `22003` to `_messageFor`'s mapping so an overflow surfaces as "Revisa los datos ingresados." instead of the generic save-failure message.

### WR-04: `consultas.veterinario_id` cascades on delete of the authoring vet's auth account

**File:** `supabase/schema.sql:471-476`

**Issue:** `veterinario_id uuid not null references auth.users(id) on delete cascade` means that if a veterinarian's `auth.users` row is ever deleted, **every consulta they ever authored is deleted along with it** — permanently destroying what are effectively legally-relevant clinical records, for every patient they ever treated, not just their own data. This is the opposite of HIST-04's append-only/no-delete guarantee: HIST-04 protects records from being edited/deleted through the app, but this FK lets them be destroyed as a side effect of an unrelated account-lifecycle action. The schema comment above it already flags this as a known theoretical risk ("hoy no existe esa funcionalidad, así que el riesgo es teórico"), but there is no tracking mechanism in this codebase (no TODO/issue reference) to make sure a future account-deletion feature revisits it, so it is easy for this to slip through unnoticed once that feature is built.

**Fix:** Before any account-deletion feature ships, change this to `on delete restrict` (block deleting a vet who has authored consultas) or `on delete set null`/a dedicated "deleted user" placeholder, so historical clinical records survive independent of the authoring account's lifecycle. At minimum, track this explicitly (e.g. a `-- TODO(account-deletion):` comment referencing the tracking doc) rather than relying on institutional memory.

## Info

### IN-01: Duplicated user-facing string literals across files

**File:** `lib/core/utils/formato.dart:77` and `lib/features/clinical_history/presentation/screens/consulta_form_screen.dart:80`
**File:** `lib/features/clinical_history/data/services/historia_clinica_pdf_service.dart:146-148`, `lib/features/clinical_history/presentation/providers/historia_clinica_pdf_providers.dart:33-35`, `lib/features/patients/presentation/screens/mascota_detail_screen.dart:82-94`

**Issue:** `'Ingresa un valor numérico válido'` is defined once as `const error` inside `parsearNumeroPositivo` and re-declared verbatim as `errorNumerico` inside `_submit()`. Likewise `'No pudimos generar el PDF. Intenta de nuevo.'` is hardcoded independently in three different files. Any future copy change requires updating all occurrences in lockstep, with no compiler help if one is missed.

**Fix:** Export the numeric-error message as a named constant from `formato.dart` (e.g. `const kErrorNumericoInvalido = 'Ingresa un valor numérico válido';`) and a single `kPdfGenerarError` constant reused by the three PDF-failure sites.

### IN-02: Duplicate `_blancoANull` implementation

**File:** `lib/features/clinical_history/presentation/providers/consultas_providers.dart:75-78` and `lib/features/clinical_history/data/repositories/supabase_consulta_repository.dart:84-87`

**Issue:** The exact same "blank/whitespace-only string → null" helper is implemented privately and independently in both `RegistrarConsulta` (provider layer) and `SupabaseConsultaRepository` (data layer), each with its own doc comment repeating the same D-03 rationale. Since the provider already normalizes before calling the repository, the repository's copy is currently dead weight duplicating logic that will silently drift if only one copy is ever updated.

**Fix:** Move `_blancoANull` into a shared utility (e.g. `lib/core/utils/formato.dart`) and have both call sites use it, or drop the redundant provider-layer normalization now that the repository already re-does it on every call.

### IN-03: Field-level error text isn't cleared as the user edits the value

**File:** `lib/features/clinical_history/presentation/screens/consulta_form_screen.dart:52-56, 74-108`

**Issue:** `initState` only attaches `_onCamposCambiaron` (which triggers a rebuild) to `_diagnosticoCtrl` and `_tratamientoCtrl`. The optional numeric controllers (`_pesoCtrl`, `_temperaturaCtrl`, `_frecuenciaCardiacaCtrl`, `_frecuenciaRespiratoriaCtrl`) have no listener, so once `_pesoError`/`_temperaturaError`/etc. are set by a failed submit, the red error text under that field stays visible even after the user types a corrected value — it only clears on the *next* tap of "Guardar consulta", not as they fix the input. This is a minor but real UX inconsistency: the visible error state briefly lies about the current validity of the field.

**Fix:** Either attach a lightweight listener to the numeric controllers that clears the corresponding `_xError` on change, or re-validate on `onChanged` for those `AppTextField`s.

---

## Resolution (2026-09-29)

| Finding | Outcome |
|---------|---------|
| WR-01 | ✅ Fixed — re-entrancy guard added to `_submit()` and `_guardar()` |
| WR-02 | ✅ Fixed — "Exportar PDF" gated on `mascotaAsync.hasValue` |
| WR-03 | ✅ Fixed — temperature capped to 999.9 client-side, SQLSTATE `22003` mapped server-error-side |
| WR-04 | ⏸ Deferred — requires another live Supabase migration; tracked in `STATE.md` Blockers/Concerns, must be revisited before any account-deletion feature ships |
| IN-01 | ✅ Fixed — `kErrorNumericoInvalido` shared constant in `formato.dart` |
| IN-02 | ✅ Fixed — `blancoANull` shared helper in `formato.dart` |
| IN-03 | ❌ Reverted — a `TextEditingController` listener attempt caused a real bug (fires on non-text `notifyListeners()` calls, clearing the error the same frame it was set); left as-is rather than ship a broken fix |

See `git log` commit `5bd9d80` for the fix diff. `flutter analyze` clean, `flutter test` 154/154 passing after fixes.

---

_Reviewed: 2026-09-29_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
