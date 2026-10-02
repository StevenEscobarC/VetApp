---
phase: 05-vacunaci-n-y-desparasitaci-n
plan: 11
subsystem: infra
tags: [edge-function, github-pages, supabase, carne-publico]
requires: ["05-03", "05-04", "05-15", "05-17"]
provides:
  - Edge Function `carne` live (verify_jwt=false, version 1)
  - GitHub Pages carné at https://stevenescobarc.github.io/VetApp/c/
  - README section "Carné público (Fase 5)"
key-files:
  modified: [README.md]
metrics:
  completed: 2026-10-02
requirements: [VAC-04, VAC-05]
---

# Phase 5 Plan 11: Carné público deploy Summary

Edge Function `carne` deployed and the static carné page published on GitHub Pages; infrastructure probed and documented with its fallback. Real-token check deferred to 05-13.

## Task 1: Authorization

The user authorized scope a-d in chat on 2026-10-02: (a) deploy of the function, (b) repo variable, (c) enabling Pages, (d) push to master.

## Task 2: Deploy, publish, probe, document

1. Supabase MCP `deploy_edge_function` `carne`, verify_jwt=false: status ACTIVE, version 1 (index.ts from 05-17, commit b553ab5 lineage).
2. `gh variable set CARNE_FUNCTION_URL` (value `https://<ref>.supabase.co/functions/v1/carne`): OK.
3. `gh api -X POST repos/StevenEscobarC/VetApp/pages -f build_type=workflow`: html_url https://stevenescobarc.github.io/VetApp/, build_type workflow.
4. Before the push, `.planning/business/` was stripped from the unpushed history with git filter-branch (backup branch `backup/pre-business-strip-20261002`), restored locally and gitignored (46057f8). Secret scan: 0 JWT-like strings, no credential files tracked. The project ref appears in .planning docs and the README prior to this plan; it is not a secret (public in app builds and in the Pages config.js). `git push origin master` 97b3ba5..46057f8. Workflow "Carné público (GitHub Pages)" run 37066949864: build success, deploy success.
5. Probes (node fetch, since curl is blocked by a hook):
   - token "xx" -> 404 `{"error":"no_encontrado"}`
   - 64 zeros -> 404 `no_encontrado`
   - GET -> 405
   - OPTIONS with Origin https://evil.example -> 204, Access-Control-Allow-Origin https://stevenescobarc.github.io (never evil, never `*`)
   - https://stevenescobarc.github.io/VetApp/c/ -> 200; config.js 200 and contains `functions/v1/carne`; page has CSP meta, no-referrer, footer "Hecho con VetApp"
   - `REQUIRE_CARNE_FN=1 bash supabase/tests/verify_live_schema.sh` -> `OK carne edge function (token inválido -> 404)` ... `LIVE_SCHEMA_OK`
6. README section "Carné público (Fase 5)" added (architecture, why not HTML on Supabase, deploy steps, `CARNE_BASE_URL` dart-define override, privacy notes D-15/D-20/D-23/D-26, documented FALLBACK as a future gap, not enabled). Commit 6f83ed9.

## Deviations from Plan

**1. [Deferred] Step 5b real-token check not run (REAL_TOKEN_OK pending).** Production has 0 `carne_enlaces`, 0 doses and 0 clinics with a logo (read-only query), so there is nothing real to test. Deferred to 05-13: QA creates a logo, a dose and a share link in a test clinic on the emulator, then the orchestrator runs the REAL_TOKEN_OK node assertion (logo_url signed for clinica-logos, no `logo_path`/`foto_path` keys). D-26/D-27 behavior is therefore unverified live until then.

**2. [Tooling] Probes used node fetch instead of curl** (curl blocked by a hook). Same assertions.

## Known Stubs

None.

## Threat Flags

None.

## Commits

- 6f83ed9 docs(05-11): README carné público

## Self-Check: PASSED
