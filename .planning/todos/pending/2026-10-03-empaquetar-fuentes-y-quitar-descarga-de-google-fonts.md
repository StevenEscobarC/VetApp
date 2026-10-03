---
created: 2026-10-03T05:08:22.752Z
title: Empaquetar fuentes y quitar la descarga de google_fonts
area: ui
files:
  - lib/core/theme/app_typography.dart:2
  - pubspec.yaml:37
---

## Problem

`app_typography.dart` usa `google_fonts`, que descarga Caprasimo y Figtree desde servidores de Google en tiempo de ejecución. Tiene dos efectos:
1. Envía la IP del usuario a Google, un tercero que no está declarado en la política de tratamiento.
2. Sin conexión (uso típico a domicilio) se pierde la tipografía del diseño aprobado en el primer arranque.

## Solution

- Descargar los TTF de Caprasimo y Figtree (licencia OFL) a `assets/google_fonts/` y declararlos en `pubspec.yaml`. `google_fonts` los toma de assets si coinciden los nombres.
- En `main()`, poner `GoogleFonts.config.allowRuntimeFetching = false;`.
- Verificar que los tests de widgets siguen en verde (vetapp-gate) y que la tipografía se ve igual en el emulador sin red.
