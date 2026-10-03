---
created: 2026-10-03T05:08:22.752Z
title: Decidir marca antes del lanzamiento público
area: general
files:
  - android/app/build.gradle.kts
---

## Problem

La auditoría competitiva del 02/10/2026 encontró varios productos activos con nombres casi idénticos a "VetApp": vet-app.com.ar (AR), vetapp.cl (CL), vetapp.app (PL) y veteapp.com (CO, usa ®, a una letra de distancia). Riesgos:
- No vamos a posicionar la búsqueda "vetapp".
- Confusión de clientes.
- Posible oposición si se intenta registrar la marca en Colombia.

Esta decisión bloquea el registro público, la ficha de Google Play y cualquier dominio o landing. Es una decisión del usuario, no técnica.

## Solution

1. Buscar antecedentes en el SIPI de la SIC (VETAPP, VETEAPP, VET APP; clases Niza 9, 42 y 44).
2. Consultar a un abogado de propiedad industrial (lo de arriba no es asesoría legal).
3. Si hay riesgo, elegir un nombre distintivo y comprar el dominio .co / .com.
4. Actualizar el copy y los assets de la app. El `applicationId` interno `com.vetapp.vetapp` puede quedarse.

El detalle está en la carpeta local de negocio (market/ADVANTAGE.md, no versionada).
