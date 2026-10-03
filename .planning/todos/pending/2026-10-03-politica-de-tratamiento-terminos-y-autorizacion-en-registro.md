---
created: 2026-10-03T05:08:22.752Z
title: Política de tratamiento, términos y autorización en registro
area: auth
files:
  - lib/features/auth/presentation/screens/register_screen.dart
  - supabase/schema.sql
---

## Problem

La Ley 1581/2012 exige autorización previa, expresa e informada para tratar datos personales. VetApp trata datos de veterinarios y de dueños de mascotas, y hoy no tiene política de tratamiento, términos ni autorización registrada. Los tres competidores auditados fallan justo aquí, así que hacerlo bien es diferenciador ("privado por diseño"). Bloquea el cobro y el registro público.

## Solution

- Redactar la política de tratamiento: responsable con NIT, finalidades, derechos ARCO y canal de reclamos. Rol de VetApp: encargado frente a los datos de los dueños y responsable frente a los del veterinario. Lista de proveedores (Supabase, etc.).
- Redactar los términos de servicio.
- En `register_screen.dart`: casilla **sin marcar** "Acepto la política y los términos", con enlaces.
- Guardar en el perfil la aceptación (versión de la política + fecha/hora), con una columna o tabla nueva vía vetapp-supabase y RLS.
- Pedir revisión legal antes de publicar.
