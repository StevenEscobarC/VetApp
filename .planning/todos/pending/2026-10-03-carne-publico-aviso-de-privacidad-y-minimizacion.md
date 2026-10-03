---
created: 2026-10-03T05:08:22.752Z
title: Carné público con aviso de privacidad y minimización
area: ui
files:
  - supabase/functions/carne/index.ts
  - lib/core/config/carne_config.dart
  - .github/workflows/pages-carne.yml
---

## Problem

El carné público ya está bien protegido: el token va en el fragmento `#`, tiene noindex, no-store y no carga terceros. Faltan tres cosas:
- Un aviso de privacidad visible.
- Asegurar que nunca se exponga el teléfono ni la dirección del dueño.
- Un dominio propio (hoy se sirve desde github.io, lo que resta confianza y amarra la marca).

## Solution

- Agregar en el pie una línea de aviso de privacidad (quién trata los datos y para qué), con enlace a la política (depende del todo de política de tratamiento).
- Auditar el payload de la Edge Function `carne`: mostrar solo el nombre del dueño (o sus iniciales) y los datos de la mascota.
- Configurar un dominio propio una vez decidida la marca (depende del todo de marca), cambiando `carne_config.dart` y GitHub Pages.
