---
phase: 06-inventario
plan: 02
subsystem: inventory
tags: [flutter, riverpod, supabase, inventario, tdd]
requires: [06-01 RPC contract (crear_producto, actualizar_producto, archivar_producto, mover_stock, inventario_resumen)]
provides:
  - Producto/Unidad/CategoriaProducto/ResumenInventario, MovimientoStock/MotivoMovimiento/ResultadoAjuste, InventarioFailure/ErrorInventario, stock constants
  - SupabaseInventarioRepository (+ mensajeErrorInventario, inventarioFailureDe, esErrorDeRed)
  - inventarioRepositoryProvider, productosProvider, productoProvider, resumenInventarioProvider, movimientosProvider, puedeAdministrarInventarioProvider, invalidarInventario, inventarioActionsProvider
  - FakeInventarioRepository + productoDePrueba
affects: [06-05, 06-06, 06-07, 06-08]
key-files:
  created:
    - lib/features/inventory/domain/stock.dart
    - lib/features/inventory/domain/entities/movimiento_stock.dart
    - lib/features/inventory/domain/inventario_failure.dart
    - lib/features/inventory/data/repositories/supabase_inventario_repository.dart
    - lib/features/inventory/presentation/providers/inventario_providers.dart
    - test/helpers/fake_inventario.dart
    - test/producto_test.dart
    - test/supabase_inventario_repository_test.dart
    - test/inventario_invalidacion_test.dart
  modified:
    - lib/features/inventory/domain/entities/producto.dart (stub rewritten)
    - test/helpers/fake_auth.dart (appUnderTest gains optional overrides)
    - 9 existing tests (inventarioRepositoryProvider override)
decisions:
  - "bajo es estrictamente cantidad < minimo (D-07); diasParaVencer compara dias calendario normalizados a UTC"
  - "Una sola tabla de traduccion de errores (_tipoDe + mensajeErrorInventario); esErrorDeRed por nombre de tipo, sin dart:io"
  - "stockInsuficiente/noDisponible en ajustar tambien invalidan (la UI pide actualizar la lista)"
metrics:
  completed: 2026-11-12
  tasks: 3
---

# Phase 06 Plan 02: Contrato Dart de inventario Summary

Dominio entero y de la clinica, repositorio contra las RPC de 06-01 con errores tipados en espanol (incluye sin conexion), providers a mano con invalidacion G4, fake con estado y override Wave 0 en 9 tests existentes.

## Commits

- 9ad87c5 feat(06-02): dominio de inventario (Producto, MovimientoStock, InventarioFailure)
- 5cc7482 feat(06-02): SupabaseInventarioRepository con RPC y errores tipados
- a1d4e58 feat(06-02): providers y acciones de inventario, fake y overrides Wave 0

## Evidencia de verificacion (para 06-VALIDATION.md, 2026-11-12)

| Tarea | Marcador | Pruebas |
|-------|----------|---------|
| 06-02-T1 | DOMINIO_INV_OK | test/producto_test.dart: 15 |
| 06-02-T2 | REPO_INV_OK | test/supabase_inventario_repository_test.dart: 18 |
| 06-02-T3 | CONTRATO_INV_OK | test/inventario_invalidacion_test.dart: 10; 9 overrides presentes |

`flutter analyze`: No issues found. Suite completa: 899 pruebas verdes (baseline 856 + 43 nuevas). Ultimo commit de codigo: a1d4e58.

## Deviations from Plan

- **[Rule 3 - Blocking]** `router_equipo_test.dart` usa `appUnderTest` (helper) que no aceptaba overrides; se agrego un parametro opcional `overrides` a `appUnderTest` en `test/helpers/fake_auth.dart` (aditivo; los demas llamadores no cambian) y el test lo pasa. Se reformateo una linea del helper por `dart format`.
- **Orden TDD:** dominio y repositorio se escribieron junto a sus pruebas en un solo paso (sin commit RED separado); las pruebas cubren todos los casos del plan.
- Una expectativa propia del test de deshacer se corrigio (2 cargas, no 3: las invalidaciones se fusionan sin lector intermedio).
- El worktree se reseteo a fd53b7f al inicio (base distinta); `flutter pub get` modifico archivos de plugins de plataforma que no se commitearon.

## Known Stubs

Ninguno.

## Threat Flags

Ninguno. T-06-11/12/14/15 mitigados (solo delta, sin update/insert/delete directos, traduccion unica de errores, deteccion de red).

## Self-Check: PASSED
