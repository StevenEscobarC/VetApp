---
phase: 06-inventario
plan: 07
subsystem: inventory-ui
tags: [flutter, riverpod, go_router, inventario, tdd, alertas]
requires: [06-02, 06-03, 06-05]
provides:
  - Filtros Todos / Bajos / Vence pronto, ?filtro=bajos, ResumenBajosStrip
  - mensajePedidoStock (dominio puro) + boton "Pedir por WhatsApp" en Bajos
  - StockBajoCard en Inicio, pill "N bajos" en Mas
affects: [06-08, 06-09]
requirements: [INV-02]
key-files:
  created:
    - lib/features/inventory/domain/pedido_whatsapp.dart
    - lib/features/inventory/presentation/widgets/resumen_bajos_strip.dart
    - lib/features/inventory/presentation/widgets/stock_bajo_card.dart
    - test/pedido_stock_test.dart
    - test/stock_bajo_card_test.dart
  modified:
    - lib/features/inventory/presentation/screens/inventario_screen.dart
    - lib/features/inventory/presentation/inventario_routes.dart
    - lib/features/home/presentation/screens/inicio_screen.dart
    - lib/features/home/presentation/screens/mas_screen.dart
    - test/inventario_screen_test.dart
    - test/inicio_screen_test.dart
    - test/router_inventario_cross_shell_test.dart
completed: 2026-11-12
---

# Phase 06 Plan 07: Alertas de stock bajo Summary

El veterinario ve el stock bajo en Inicio (tarjeta), en Mas (pill), en la lista (chips, tira "Ver bajos") y puede compartir el pedido de reposicion en un toque; todo sobre `FakeInventarioRepository` y `FakeCompartidor`.

## Commits

- 3abbace test(06-07): filtros y tira de bajos (RED)
- ce1d630 feat(06-07): filtros Todos/Bajos/Vence pronto, ?filtro=bajos y tira
- 87ebd0a test(06-07): pedido por WhatsApp (RED)
- e1a4658 feat(06-07): pedido por WhatsApp con texto puro y compartir
- eb612cf test(06-07): tarjeta de Inicio, pill de Mas y navegacion (RED)
- cf5f4a2 feat(06-07): tarjeta de stock bajo en Inicio y pill de bajos en Mas

## Evidencia de verificacion (para 06-VALIDATION.md, 2026-11-12, ultimo commit cf5f4a2)

| Tarea | Marcador | Pruebas |
|-------|----------|---------|
| 06-07-T1 | FILTROS_INV_OK | test/inventario_screen_test.dart: 27 (incluye T2) |
| 06-07-T2 | PEDIDO_WA_OK | test/pedido_stock_test.dart: 3; inventario_screen_test (grupo pedido): 5 |
| 06-07-T3 | ALERTA_INV_OK | stock_bajo_card_test: 6; inicio_screen_test: 15; router_inventario_cross_shell_test: 9 |

`flutter analyze`: No issues found. Suite completa: 970 pruebas verdes. "Pedir por WhatsApp" entro completo (no se corto). El QA en emulador corre en 06-09 (F4, F5).

## Deviations from Plan

- **Asercion de insignia acotada (test/inventario_screen_test.dart):** la tira de bajos usa `Icons.trending_down` por especificacion, igual que la insignia "Bajo"; el caso existente `find.byIcon(Icons.trending_down), findsOneWidget` pasaba a 2. Se acoto a los descendientes de `InsigniaStock` (misma intencion, sin debilitarla).
- **test/inicio_screen_test.dart solo suma lineas:** los casos nuevos usan un harness propio `_appInicioConInventario` (el `_appUnderTest` existente fija un repo vacio). Se revirtio un reflow de `dart format` para mantener el diff aditivo.
- **test/router_inventario_cross_shell_test.dart:** `_app`/`_abrirMas` reciben un repo opcional (cambio retrocompatible).
- **Pill y ajuste:** el caso de refresco usa `inventarioActionsProvider.ajustar` (la API publica actual) en lugar de `moverStock`; ambos invalidan `resumenInventarioProvider`.
- El worktree se reseteo a c742170 (base indicada). `flutter pub get` regenero archivos de plugins de plataforma; no se commitearon.

## Known Stubs

Ninguno.

## Threat Flags

Ninguno. T-06-30: el texto compartido solo lleva nombres y cantidades, sin destinatario fijo. T-06-31: conteos desde el RPC (solo la clinica propia). T-06-32: `StockBajoCard` no pinta nada en carga/error/0 (probado).

## Self-Check: PASSED
