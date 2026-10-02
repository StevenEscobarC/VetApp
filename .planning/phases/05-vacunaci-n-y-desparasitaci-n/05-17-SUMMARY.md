---
phase: 05-vacunaci-n-y-desparasitaci-n
plan: 17
subsystem: public-carne
tags: [edge-function, storage-signing, public-page, logo]
requires: ["05-04", "05-14"]
provides:
  - "Edge Function carne returns clinica.logo_url (300 s signed), never logo_path"
  - "Public carne page renders clinic logo with origin check and fallback"
key-files:
  modified:
    - supabase/functions/carne/index.ts
    - public_carne/c/carne_logica.js
    - public_carne/c/carne.js
    - public_carne/c/carne.css
    - test/web/carne_logica.test.mjs
metrics:
  completed: 2026-10-02
  tasks: 2
---

# Phase 5 Plan 17: Public carne clinic logo Summary

Edge Function signs the clinic logo (bucket clinica-logos, 300 s) through a shared `firmar()` helper and the static page renders it in the header, falling back to the clinic name only.

## Tasks

1. Page logic and render (commit 0fa666f): `modeloVista` exposes `clinica.logoUrl` (string or ''), never `logo_path`; `render()` shows `img.logo-clinica` inside `div.banda-clinica` only when the URL starts with the Supabase origin; `error` listener removes the img (no inline handlers, no innerHTML); CSS for the two classes; contract test updated plus two new tests. Node tests: 9/9 pass.
2. Edge Function (commit b553ab5): `firmar(base, headers, bucket, path)` extracted and used for pet photo (behavior unchanged) and logo; `LOGO_RE` restricts signed paths; `logo_path` always deleted; zero imports, no logging.

## Deviations from Plan

None. Note: Deno is not installed locally, so `deno check` was not run; 05-11 deploys and probes the function live. Not deployed, not pushed.

## Known Stubs

None.

## Self-Check: PASSED
LOGO_PAGE_OK criteria and LOGO_EDGE_OK gate verified; commits 0fa666f and b553ab5 exist.
