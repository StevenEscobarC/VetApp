---
id: SEED-001
status: dormant
planted: 2026-10-03
planted_during: Fase 5 (cierre de diseño)
trigger_when: al cerrar el móvil v1 / al planear el siguiente milestone, o si clínicas o admins piden usar la app desde el computador
scope: large
---

# SEED-001: Acceso web para veterinario, dueño y admin

## Why This Matters

El usuario quiere ofrecer más adelante acceso desde la web para quien lo prefiera. **Primero se termina el móvil.** Ventajas:
- Clínicas con computador en recepción.
- El admin gestiona el equipo y los reportes con más comodidad.
- El cobro de la suscripción en la web no tiene las restricciones de Google Play/App Store.

En la auditoría del 02/10/2026, los competidores eran solo web; nuestro diferencial es el móvil nativo. La web debe complementarlo, no reemplazarlo.

## When to Surface

Al planear el milestone posterior al móvil v1, o antes si la demanda de clínicas lo justifica.

## Scope Estimate

Grande: Flutter Web o app web aparte sobre el mismo Supabase.
- **Veterinario:** paridad con el móvil.
- **Admin de clínica:** equipo, plan y pagos, exportaciones y reportes.
- **Dueño:** portal de solo lectura (carné, citas).
- **Super-admin interno:** soporte con bitácora, sin acceso a datos clínicos sin auditoría.

Mismas políticas RLS por `clinica_id`. Cookies y analítica según el todo de la landing.

## Breadcrumbs

- `supabase/schema.sql` (RLS multi-tenant)
- `lib/features/auth/` (roles)
- `web/` (scaffold Flutter Web existente)
- `.planning/todos/pending/2026-10-03-landing-con-precios-y-cookies-sin-trackers-previos.md`
