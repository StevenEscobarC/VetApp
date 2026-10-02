---
phase: 05-vacunaci-n-y-desparasitaci-n
plan: 03
subsystem: public-carne
tags: [edge-function, github-pages, vanilla-js, security]
requires: [carne_publico RPC (05-01)]
provides: [Edge Function carne, public_carne static page, pages-carne workflow]
affects: [05-06 (kCarneBaseUrl), 05-11 (deploy)]
tech-stack:
  added: []
  patterns: [zero-import Deno function, textContent-only rendering, fragment token]
key-files:
  created:
    - supabase/functions/carne/index.ts
    - public_carne/index.html
    - public_carne/c/index.html
    - public_carne/c/carne.css
    - public_carne/c/carne.js
    - public_carne/c/carne_logica.js
    - public_carne/c/fonts/ (3 woff2 + OFL.txt)
    - .github/workflows/pages-carne.yml
    - test/web/carne_logica.test.mjs
  modified:
    - supabase/config.toml
decisions:
  - Fonts self-hosted (no Google Fonts link), deviating from UI-SPEC on purpose (privacy, CSP 'self')
metrics:
  tasks: 3
  completed: 2026-10-02
requirements: [VAC-04, VAC-05]
---

# Phase 5 Plan 03: Public carné (Edge Function + Pages) Summary

Dependency-free `carne` Edge Function (token in POST body, service role runtime-only, 300 s signed photo, uniform 404, CORS fixed to the Pages origin) plus a vanilla HTML/CSS/JS certificate page that reads the token from the URL fragment and renders only via textContent under a strict meta CSP.

## Tasks

| Task | Commit | Notes |
|------|--------|-------|
| 1 Edge Function + config.toml | c160d8d | EDGE_OK |
| 2 Page + logic (TDD) | RED test commit, then feat commit | 7 node tests pass, PAGE_OK |
| 3 Fonts + workflow | see git log | WORKFLOW_OK |

## Deviations from Plan

- Figtree 400 and 600 woff2 are the same file (Google serves one variable font for both weights); copied under both names so the @font-face URLs match.
- Fonts are self-hosted instead of the UI-SPEC Google Fonts link (intended by the plan).

## Not done (by design)

No deploy, no Pages enablement, no push. `config.js` is generated only by the workflow (05-11 sets `CARNE_FUNCTION_URL`).

## Known Stubs

None.

## Self-Check: PASSED
