---
phase: 07-facturaci-n
plan: 08
subsystem: database
tags: [supabase, live-apply, smoke-test, facturacion]
requires:
  - phase: 07-facturaci-n
    provides: "07-01 + 07-04 bloque Fase 7 en schema.sql y bloque T del smoke (291 checks)"
provides:
  - "Esquema de facturación en vivo: 4 tablas, 10 RPC, guarda en 13 tablas, actualizar_clinica con NIT"
requirements-completed: [BILL-01, BILL-02, BILL-03, BILL-04]
completed: 2026-11-13
---

# Plan 07-08: aplicar en vivo el delta de la Fase 7 y correr el smoke de 291 checks

**Completo.** Delta aplicado en vivo. Las dos sondas anon dan `LIVE_SCHEMA_OK` y `LIVE_F7_OK`, y el smoke pegado por el usuario dio `RLS SMOKE: PASS (291 checks) - cambios revertidos`.

## Task 1: revisión estática antes de aplicar

- Gate: `PREAPPLY_F7_OK`.
- Rango del delta en `supabase/schema.sql`: líneas 4547-5631 (`-- ===== Fase 7: Facturación (delta idempotente) =====` hasta `notify pgrst, 'reload schema';`). Fuera del bloque solo cambia un comentario (línea 3740).
- Revisión manual:
  - la búsqueda de idempotencia va antes de cualquier bloqueo;
  - el bloqueo y el contador van dentro del sub-bloque con el manejador de `unique_violation`;
  - el total se calcula en bigint;
  - los índices parciales de "una CC activa por visita" excluyen las anuladas;
  - los helpers privados están revocados a `authenticated`;
  - las 4 tablas solo tienen policies de `select`;
  - `mover_stock` no se recrea.
- Correcciones: sin cambios.

## Task 2: aplicación en vivo

- Autorización del usuario en el chat: "Autorizo y ola 3".
- Supabase MCP `apply_migration` en dos partes, en el mismo orden del bloque y ambas con `{"success":true}`:
  - `fase_07_facturacion_a`: líneas 4547-5272 (tablas, RLS, helpers, `crear_cuenta_cobro`, `crear_cotizacion`, `marcar_cobro_pagado`, `anular_cobro`);
  - `fase_07_facturacion_b`: líneas 5274-5631 (parte B, guardas, autoría, grants y notify).
- Consultas de solo lectura después de aplicar:
  - cobros, cobro_items, cobro_contadores y clinica_servicios: `0, 0, 0, 0`;
  - triggers `guard_solo_lectura`: 13 tablas (cita_mascotas, citas, clientes, clinica_servicios, cobro_contadores, cobro_items, cobros, consultas, dosis_aplicadas, mascota_pesos, mascotas, movimientos_inventario, productos);
  - `actualizar_clinica` con 5 argumentos borrada `true`; con 6 argumentos existe `true`.
- Smoke pegado completo por el usuario en el SQL Editor (primera corrida), línea literal:

```
RLS SMOKE: PASS (291 checks) - cambios revertidos
```

- Concurrencia entre dos sesiones (manual y opcional): no se corrió. La cubren por construcción el contador con `on conflict` en el mismo sub-bloque y el bloqueo de productos en orden de `producto_id`.

## Task 3: sonda anon en vivo

- Primera corrida: `FAIL cobros conversion embed 400` (PGRST200). PostgREST no resuelve el hint por nombre de constraint (`cobros!cobros_convertida_en_fkey`) en una relación de `cobros` consigo misma, aunque la FK existe en vivo. El mismo select estaba en `SupabaseCobrosRepository.kSelectCobro`, así que la lista de Cobros habría fallado en vivo. Las pruebas no lo detectaban porque corren contra el fake.
- Desviación (Rule 1, bug): los embeds de conversión usan la columna como hint (`cobros!convertida_en_id`, `cobros!cotizacion_origen_id`) en el repositorio y en la sonda.
  - Regresión con TDD: `228f51a` (rojo, `+0 -1`) → `d86965c` (verde, `+30`).
  - Probado en vivo como anon: el hint por columna da 401 (resuelve) y el hint por constraint da 400.
- Segunda corrida: `OK cobros conversion embed (anon sin privilegio 401; el hint de la FK resolvió, no hubo 400)`, `LIVE_SCHEMA_OK`, `LIVE_F7_OK`.
- No se registra ninguna clave ni el ref del proyecto.
