---
phase: quick-261001-huq
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - .claude/skills/arquitecto-vetapp/SKILL.md
  - .claude/skills/arquitecto-vetapp/references/modelo-dominio.md
  - .claude/skills/arquitecto-vetapp/references/colombia.md
autonomous: true
requirements: [VET-24]

must_haves:
  truths:
    - "SKILL.md describes the VetApp repo as it actually is today (stack, lib/ layout, providers, errors, tests, backend workflow), with every claim backed by a real path"
    - "Ideal-architecture items (Result<T>, freezed, riverpod_generator, mocktail, migrations folder, use-case layer) appear only as 'Refactors candidatos (no aplicar sin decisión)' pointing to Linear, never as rules"
    - "modelo-dominio.md mirrors supabase/schema.sql tables and marks each invariant as enforced by DB or by app"
    - "colombia.md matches the real behavior of lib/core/utils (telefono_co, formato_hora, formato, zona_bogota) and does not contradict locked decisions"
    - "The description frontmatter no longer mentions Bluetooth, IDEXX or Dog API"
  artifacts:
    - path: ".claude/skills/arquitecto-vetapp/SKILL.md"
      provides: "Project architecture skill (current reality)"
      contains: "name: arquitecto-vetapp"
    - path: ".claude/skills/arquitecto-vetapp/references/modelo-dominio.md"
      provides: "Domain model derived from schema.sql"
      contains: "cita_mascotas"
    - path: ".claude/skills/arquitecto-vetapp/references/colombia.md"
      provides: "Colombia-specific rules aligned with code"
      contains: "1581"
  key_links:
    - from: "SKILL.md"
      to: "references/modelo-dominio.md, references/colombia.md"
      via: "relative links in a 'Referencias' section"
      pattern: "references/(modelo-dominio|colombia)\\.md"
---

<objective>
Rewrite the project skill `.claude/skills/arquitecto-vetapp` (SKILL.md + references/modelo-dominio.md + references/colombia.md) so that it describes the CURRENT VetApp project, not an idealized architecture. Linear issue: VET-24.

Purpose: the skill is loaded when designing/reviewing/refactoring/debugging VetApp code; today it prescribes patterns the repo does not use (freezed, Result<T>, riverpod_generator, mocktail, migrations folder, use cases), which misleads agents.
Output: three rewritten markdown files, all in Spanish, every claim verified against code.

Ground rule for the executor: THE CODE WINS. `.planning/codebase/*.md` and the CLAUDE.md "Architecture" section are partly stale (they say Riverpod/go_router are unused, router dir empty, etc. — this is no longer true). Verify each statement with grep/ls before writing it. If a claim in this plan turns out false in the code, write what the code does and mention the discrepancy in the SUMMARY.

Linear: the orchestrator (not this executor) moves VET-24 to Done with a short comment after the commit. The executor must NOT call Linear tools.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@./CLAUDE.md
@.claude/skills/arquitecto-vetapp/SKILL.md
@.claude/skills/arquitecto-vetapp/references/modelo-dominio.md
@.claude/skills/arquitecto-vetapp/references/colombia.md
@.planning/ROADMAP.md

<interfaces>
Facts already verified by the planner (2026-10-01):

pubspec.yaml dependencies: flutter_riverpod ^3.3.2, go_router ^17.3.0, supabase_flutter ^2.9.1, intl ^0.20.2, google_fonts ^8.2.0, image_picker, flutter_image_compress, permission_handler, cached_network_image, pdf 3.12.0, printing 5.14.3, flutter_local_notifications ^22.3.1, timezone ^0.11.1, url_launcher ^6.3.2, shared_preferences ^2.5.5, flutter_localizations. dev: flutter_test, flutter_lints ^6.0.0 only.
NOT present: freezed, json_serializable, build_runner, riverpod_generator, riverpod_annotation, dio, mocktail, mockito.

lib/core: data/ (busqueda.dart, clock_provider.dart, supabase_client_provider.dart), router/app_router.dart, theme/ (app_colors, app_spacing, app_theme, app_typography), utils/ (captura_foto, formato, formato_hora, lanzador_externo, telefono_co, zona_bogota), widgets/ (app_bar/app_top_bar, buttons/app_button, cards/app_card, chips/app_filter_chip, inputs/app_text_field, media/app_photo_picker, status/app_status_chip).

lib/features: appointments, auth, billing, clients, clinical_history, home, inventory, patients, vaccination. Failure types: auth_failure.dart, cita_failure.dart, cliente_failure.dart, consulta_failure.dart, mascota_failure.dart (in each feature's domain/). billing, inventory, vaccination have only domain/entities (stubs for future phases). appointments/domain also has cita_solapes.dart, motivos_cita.dart, recordatorios_plan.dart, whatsapp_recordatorio.dart; clinical_history/domain has formato_consulta.dart.

test/: ~33 *_test.dart files at root; test/helpers: fake_auth, fake_citas, fake_clientes, fake_consultas, fake_fotos, fake_mascotas, fake_pdf, fake_recordatorios, fake_url_launcher, router_harness.dart.

supabase/: config.toml, schema.sql, tests/rls_smoke_test.sql, tests/verify_live_schema.sh. No migrations/ folder.
schema.sql tables (line): clinicas (11), perfiles (20), clientes (31), mascotas (60), mascota_pesos (229), consultas (468), citas (542), cita_mascotas (614).

lib/core/utils/telefono_co.dart exposes requiereAvisoTelefono, telefonoGuardable, telefonoSinDigitos, numeroWhatsApp (+ others above line 83 — read the file to confirm the stored format).

.claude/agents: vetapp-brand-ui, vetapp-gate, vetapp-opportunity-research, vetapp-qa, vetapp-supabase.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Rewrite SKILL.md to describe the current repo</name>
  <files>.claude/skills/arquitecto-vetapp/SKILL.md</files>
  <read_first>
    Current SKILL.md (keep "Cómo responder", testing expectations, naming, Colombia rules as source material). Then verify against code with grep/ls (do not read whole files unless needed): lib/core/router/app_router.dart (GoRouter setup, redirect/auth), lib/core/data/supabase_client_provider.dart and clock_provider.dart, one providers file per feature (e.g. grep -rn "FutureProvider\|NotifierProvider\|AsyncNotifier\|Provider<" lib/features), one data repository per feature (grep -rn "_messageFor\|mensajeError" lib/features), one screen catching a Failure (grep -rn "on .*Failure catch" lib/features), test/helpers/router_harness.dart header, supabase/tests/rls_smoke_test.sql (how the check count is asserted), supabase/tests/verify_live_schema.sh header, grep for "security invoker", "es_veterinario()", "mi_clinica_id()", "to authenticated" in supabase/schema.sql, .claude/agents/*.md frontmatter descriptions.
  </read_first>
  <action>
    Overwrite SKILL.md in Spanish. Frontmatter: keep `name: arquitecto-vetapp`; new `description` in Spanish that triggers on diseñar, revisar, refactorizar o depurar código Flutter/Supabase de VetApp (pantallas, providers Riverpod, repositorios Supabase, SQL/RLS, tests); remove any Bluetooth/IDEXX/Dog API mention.
    Sections (each claim cites a real path):
    1. Propósito: describe the repo as it is; "el código manda" — if the skill and the code disagree, follow the code and report the discrepancy.
    2. Stack real: from pubspec (list in interfaces), explicitly noting absent packages (no freezed/json_serializable/build_runner/riverpod_generator/dio/mocktail). Riverpod providers are hand-written.
    3. Estructura lib/: core/{data,router,theme,utils,widgets} and features/* with their real subfolders; note billing/inventory/vaccination are entity stubs for future phases; no use-case layer in active features.
    4. Patrón de providers: whatever the grep shows — expected: FutureProvider.autoDispose.family for reads, action classes holding Ref that call repositories and invalidate providers, Notifier/AsyncNotifier where used, supabaseClientProvider/clockProvider overridable in tests. Cite one concrete file per pattern.
    5. Routing: go_router in lib/core/router/app_router.dart (describe real redirect/shell structure briefly).
    6. Manejo de errores: one *Failure exception per feature (list the five files); data layer translates PostgrestException/AuthException via `_messageFor`/mensajeError* helpers with a specific branch + generic Spanish fallback; presentation catches only the Failure type.
    7. Backend Supabase workflow: supabase/schema.sql is the single idempotent source (no migrations/ folder); applied by the human in SQL Editor or by an agent via Supabase MCP only after explicit user OK; supabase/tests/rls_smoke_test.sql with check count; supabase/tests/verify_live_schema.sh; RPCs `security invoker`; RLS policies `to authenticated` using es_veterinario()/mi_clinica_id(); composite (x_id, clinica_id) FKs for tenant integrity; delegate SQL/RLS work to agent vetapp-supabase.
    8. Sistema de diseño: AppColors/AppSpacing/AppTypography/AppTheme tokens, Caprasimo + Figtree via google_fonts, terracota/crema palette, never raw Material 3 defaults; core widgets AppButton, AppCard, AppTextField, AppStatusChip, AppTopBar, AppFilterChip, AppPhotoPicker; delegate visual review to vetapp-brand-ui.
    9. Colombia: short summary + link to references/colombia.md (helpers zona_bogota, formato_hora, telefono_co, formato).
    10. Naming: Spanish domain terms (Cita, Mascota, Consulta...), English technical suffixes (Repository, Provider, Screen, Failure), snake_case files, usecase-free.
    11. Testing: flutter_test only, hand-written fakes in test/helpers/fake_*.dart, router_harness.dart for screens with routing, provider overrides; every new repository/provider/screen gets a test; `flutter analyze` + `flutter test` must pass.
    12. Flujo de trabajo: repo edits only through GSD (/gsd-quick, /gsd-fast, /gsd-execute-phase); project agents vetapp-gate, vetapp-qa, vetapp-supabase, vetapp-brand-ui, vetapp-opportunity-research (one line each from their frontmatter); Linear team VetApp, one project per phase + "Plataforma y Calidad" where refactor candidates and tech debt go.
    13. Cómo responder (adapted): plan → archivos por capa → archivos completos → SQL + RLS + checks de smoke test → tests → decisiones/riesgos.
    14. Refactors candidatos (no aplicar sin decisión): Result<T>, freezed/json_serializable, riverpod_generator, mocktail, supabase/migrations/, capa de use cases — one line each, "proponer en Linear (Plataforma y Calidad), no aplicar sin decisión del usuario".
    15. Fuera de v1 / proponer fase: lector Bluetooth de microchip, integración IDEXX/Abaxis, recetas PDF, Dog/Cat API, pagos — if requested, propose a phase, do not implement inline.
    16. Referencias: links to references/modelo-dominio.md and references/colombia.md.
    Keep it compact (target 150-250 lines). No fenced code blocks of invented code; short real snippets only if copied from the repo.
  </action>
  <verify>
    <automated>cd /c/Trabajo/VetApp && f=.claude/skills/arquitecto-vetapp/SKILL.md && grep -q '^name: arquitecto-vetapp' $f && ! sed -n '1,/^---$/{p}' $f | sed -n '2,20p' | grep -qiE 'bluetooth|idexx|dog api' && grep -q 'Refactors candidatos' $f && grep -q 'references/modelo-dominio.md' $f && grep -q 'references/colombia.md' $f && grep -q 'rls_smoke_test.sql' $f && grep -q 'vetapp-supabase' $f && grep -q 'gsd-quick' $f && for p in $(grep -oE '(lib|test|supabase)/[A-Za-z0-9_./-]+\.(dart|sql|sh)' $f | sort -u); do test -e "$p" || echo "MISSING $p"; done | tee /dev/stderr | (! grep -q MISSING) && echo OK</automated>
  </verify>
  <done>SKILL.md rewritten; frontmatter valid; every cited lib/test/supabase path exists; ideal patterns only appear under "Refactors candidatos".</done>
</task>

<task type="auto">
  <name>Task 2: Rewrite references/modelo-dominio.md from schema.sql</name>
  <files>.claude/skills/arquitecto-vetapp/references/modelo-dominio.md</files>
  <read_first>
    supabase/schema.sql table definitions (lines ~11-700: clinicas, perfiles, clientes, mascotas, mascota_pesos, consultas, citas, cita_mascotas) plus grep for: "create type", "check (", "unique", "on delete", "create trigger", "citas_validar_update", "codigo", "recordatorio_enviado_at", "modalidad", "no_asistio", "solicitada", "10 minutes" / "interval". Read the citas_validar_update function body for the allowed transitions. Grep .planning/ROADMAP.md for phase numbers of vacunación, inventario, facturación, directorio/reseñas.
  </read_first>
  <action>
    Overwrite in Spanish. Per table: purpose, key columns (only those present in schema.sql), relations/FKs (including composite (x_id, clinica_id) FKs and on delete behavior), and invariants each tagged [DB] (check/unique/trigger/RLS) or [App] (validated only in Flutter). Must cover: clinicas; perfiles (rol VETERINARIO/CLIENTE, clinica_id); clientes (dueño sin cuenta, perfiles_id nullable + código de vinculación — use the real column names); mascotas; mascota_pesos (append-only); consultas (solo-append, diagnóstico + tratamiento obligatorios, cita_id opcional, una por (cita, mascota)); citas + cita_mascotas (estados pendiente/confirmada/completada/cancelada/no_asistio, plus solicitada reservada para Fase 9; transiciones permitidas por trigger citas_validar_update incl. Deshacer dentro de 10 min — describe exactly what the function allows; modalidad consultorio/domicilio; recordatorio_enviado_at; veterinario_id on delete restrict). Add a short RLS summary (helpers es_veterinario()/mi_clinica_id(), policies to authenticated). Final section "Planeado (sin columnas definidas)": vacunas, inventario/productos, facturas, directorio/reseñas — each with its ROADMAP phase number, no invented columns; note the Dart stub entities in lib/features/{vaccination,inventory,billing}/domain/entities are not mapped to tables yet. Any claim in the planning prompt not found in schema.sql: omit it and mention in SUMMARY.
  </action>
  <verify>
    <automated>cd /c/Trabajo/VetApp && f=.claude/skills/arquitecto-vetapp/references/modelo-dominio.md && for t in clinicas perfiles clientes mascotas mascota_pesos consultas citas cita_mascotas citas_validar_update no_asistio solicitada '\[DB\]' '\[App\]' Planeado; do grep -q "$t" $f || echo "MISSING $t"; done | (! grep . ) && echo OK</automated>
  </verify>
  <done>Every table in schema.sql is documented with real columns; invariants tagged DB vs App; future entities listed as planned with ROADMAP phase, no invented columns.</done>
</task>

<task type="auto">
  <name>Task 3: Align references/colombia.md with the Colombia helpers</name>
  <files>.claude/skills/arquitecto-vetapp/references/colombia.md</files>
  <read_first>
    lib/core/utils/telefono_co.dart, formato_hora.dart, formato.dart, zona_bogota.dart (public functions + doc comments only; use grep -n "^[A-Za-z].*(\|^///" if long), and test/telefono_co_test.dart, formato_hora_test.dart, formato_test.dart for concrete expected outputs. Grep .planning/ (STATE.md, phase CONTEXT files) for decisions about documento/cédula being optional.
  </read_first>
  <action>
    Overwrite in Spanish, keeping the useful parts of the current file. State real behavior with the helper that implements it: teléfono — exact stored/normalized format as telefono_co.dart does it (confirm whether it is 57XXXXXXXXXX without '+', or 10 digits; write what the code does) and numeroWhatsApp for wa.me links; horas "10:30 a. m." style via formato_hora.dart (copy an exact expected string from the test); fechas dd/mm/aaaa via formato.dart; COP sin decimales con separador de miles (copy exact format from formato_test); zona horaria America/Bogota via zona_bogota.dart (no DST). Legal: Ley 1581 de 2012 (habeas data — consentimiento, datos mínimos); Ley 576 de 2000 tarjeta profesional as "futuro, cuando aplique (p. ej. directorio Fase 9)". Remove or mark as future any recommendation contradicting locked decisions (e.g. requiring documento de identidad of the dueño — mark optional/future per the decision found). Note out-of-v1 items (pagos, facturación electrónica DIAN) as "proponer fase".
  </action>
  <verify>
    <automated>cd /c/Trabajo/VetApp && f=.claude/skills/arquitecto-vetapp/references/colombia.md && for t in telefono_co formato_hora formato.dart zona_bogota 1581 576 'a. m.' 'dd/mm/aaaa' COP; do grep -q "$t" $f || echo "MISSING $t"; done | (! grep . ) && echo OK</automated>
  </verify>
  <done>colombia.md reflects the actual helper outputs (verified against tests), cites the helper files, and contains no rule that contradicts a locked decision.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| skill text -> future agents | Skill content steers agents that write code and SQL |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-huq-01 | Tampering | SKILL.md backend section | mitigate | Explicitly state schema changes to the live DB require user OK and go through vetapp-supabase + rls_smoke_test.sql; RLS `to authenticated` with tenant helpers is mandatory |
| T-huq-02 | Information disclosure | skill files | mitigate | Do not include project refs, URLs, anon keys or any credentials in the skill |
</threat_model>

<verification>
- All three automated verify commands print OK.
- `git diff --stat` touches only the three skill files (plus planning artifacts).
- No mention of freezed/Result<T>/riverpod_generator/mocktail/use cases outside the "Refactors candidatos" section of SKILL.md (grep -n and inspect).
</verification>

<success_criteria>
The arquitecto-vetapp skill describes the current VetApp repo accurately, with ideal-architecture items demoted to Linear refactor candidates, domain model derived from schema.sql, and Colombia rules matching the real helpers. Orchestrator then marks Linear VET-24 Done with a short comment.
</success_criteria>

<output>
Create `.planning/quick/261001-huq-reescribir-skill-arquitecto-vetapp-segun/261001-huq-SUMMARY.md` when done, listing any discrepancies found between the planning prompt and the code.
</output>
