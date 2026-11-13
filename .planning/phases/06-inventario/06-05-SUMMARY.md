---
phase: 06-inventario
plan: 05
subsystem: inventory-ui
tags: [flutter, riverpod, go_router, inventario, tdd]
requires: [06-02 contrato Dart de inventario, 06-03 helpers COP/AppTextField]
provides:
  - InventarioScreen, ProductoFila, InsigniaStock (+ estadosDe/insigniasDe), ProductoFormScreen
  - inventarioRoutes, kRutaNuevoProducto, rutaInventario({bajos}); fila "Inventario" en Más
affects: [06-06, 06-07, 06-08]
requirements: [INV-01, INV-02]
key-files:
  created:
    - lib/features/inventory/presentation/screens/inventario_screen.dart
    - lib/features/inventory/presentation/screens/producto_form_screen.dart
    - lib/features/inventory/presentation/widgets/producto_fila.dart
    - lib/features/inventory/presentation/widgets/insignia_stock.dart
    - lib/features/inventory/presentation/inventario_routes.dart
    - test/inventario_screen_test.dart
    - test/producto_form_screen_test.dart
    - test/router_inventario_cross_shell_test.dart
  modified:
    - lib/core/router/app_router.dart
    - lib/features/home/presentation/screens/mas_screen.dart
    - test/widget_test.dart
completed: 2026-11-12
---

# Phase 06 Plan 05: Primer corte de la app de inventario Summary

Más > Inventario abre la lista (A-Z, insignias icono+texto, búsqueda local, estados vacío/error/carga) y "Nuevo producto" registra un producto en un paso, todo sobre `FakeInventarioRepository` y rutas de primer nivel (sin duplicar el shell, G5).

## Commits

- 4a5afde test(06-05): pruebas de la lista de inventario (RED)
- b8d4225 feat(06-05): lista de inventario con insignias de stock y busqueda
- 99a8081 test(06-05): pruebas del formulario de alta de producto (RED)
- 0069795 feat(06-05): formulario de alta de producto en un paso
- 10d1cca test(06-05): pruebas de rutas de inventario y fila de Mas (RED)
- 9b9cd0c feat(06-05): rutas /inventario de primer nivel y fila Inventario en Mas

## Evidencia de verificación (para 06-VALIDATION.md, 2026-11-12)

| Tarea | Marcador | Pruebas |
|-------|----------|---------|
| 06-05-T1 | LISTA_INV_OK | test/inventario_screen_test.dart: 12 |
| 06-05-T2 | FORM_ALTA_OK | test/producto_form_screen_test.dart: 12 |
| 06-05-T3 | SLICE_ALTA_OK | test/router_inventario_cross_shell_test.dart: 3 |

`flutter analyze`: No issues found. Suite completa: 938 pruebas verdes. Ultimo commit de código: 9b9cd0c. El QA en emulador de este corte corre en 06-09 (F1, F2).

## Deviations from Plan

- **[Rule 1 - Gate defectuoso]** El grep `Colors\.[a-z]` del plan también coincide con `AppColors.x`; se verificó con `\bColors\.` (sin coincidencias reales). No hay `Color(0x` ni `DateTime.now()` en presentation.
- **Campos de precio/costo:** el plan pide "digitsOnly" pero también el error "Usa pesos enteros, sin coma." para `85,5`; con `digitsOnly` la coma nunca llegaría al parser. Se usa `allow([\d.,])` y `parsearCop` valida; los puntos de miles se agrupan al salir del campo.
- **Vencimiento:** el ícono de calendario es decorativo (`prefixIcon`); se escribe a mano `dd/mm/aaaa` (sin selector de fecha, AppTextField no admite sufijo).
- **[Rule 3]** `test/widget_test.dart` ("Más lista Recordatorios") necesitaba `ensureVisible` porque la nueva fila empuja Recordatorios fuera de la vista; no se debilitó ninguna aserción.
- **Semántica de fila:** `Semantics(excludeSemantics: true)` envuelve la tarjeta; 06-06/06-08 deberán exponer botones y tap por separado.
- Al inicio el worktree se reseteó a c5bd13a (base distinta); `flutter pub get` regeneró archivos de plugins de plataforma que no se commitearon. Un `dart format lib test` accidental tocó archivos ajenos; se revirtieron uno a uno antes de commitear.

## Known Stubs

Ninguno. Pendiente por diseño (otros planes): ajuste rápido (06-06), filtros/tira/WhatsApp/tarjeta Inicio/pill Más (06-07), detalle y edición (06-08).

## Threat Flags

Ninguno. T-06-22 (validación + rangos en cliente), T-06-23 (asegurarEscritura + candado + LP004 vía manejarLimitePlan), T-06-24 (solo `InventarioFailure.message`, genérico en el resto) y T-06-25 (rutas de primer nivel, test cross-shell sin excepción) mitigados.

## Self-Check: PASSED
