import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/supabase_client_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/supabase_inventario_repository.dart';
import '../../domain/entities/movimiento_stock.dart';
import '../../domain/entities/producto.dart';
import '../../domain/inventario_failure.dart';
import '../../domain/stock.dart';

final inventarioRepositoryProvider = Provider<SupabaseInventarioRepository>((
  ref,
) {
  return SupabaseInventarioRepository(ref.watch(supabaseClientProvider));
});

/// Productos activos de la clínica.
final productosProvider = FutureProvider.autoDispose<List<Producto>>((ref) {
  return ref.watch(inventarioRepositoryProvider).productos();
});

/// Un producto por id (puede venir archivado); `null` si no existe.
final productoProvider = FutureProvider.autoDispose.family<Producto?, String>((
  ref,
  id,
) {
  return ref.watch(inventarioRepositoryProvider).producto(id);
});

/// Conteos de la tarjeta de Inicio.
final resumenInventarioProvider = FutureProvider.autoDispose<ResumenInventario>(
  (ref) {
    return ref.watch(inventarioRepositoryProvider).resumen();
  },
);

/// Historial reciente de un producto.
final movimientosProvider = FutureProvider.autoDispose
    .family<List<MovimientoStock>, String>((ref, productoId) {
      return ref.watch(inventarioRepositoryProvider).movimientos(productoId);
    });

/// Solo los administradores crean, editan y archivan. El servidor es la
/// autoridad (42501); esto solo oculta acciones.
final puedeAdministrarInventarioProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(authProfileProvider).value?.esAdmin ?? false,
);

/// Refresca toda lectura derivada del stock tras una mutación (G4): los
/// providers son `autoDispose`, pero la rama de Inicio del shell sigue
/// montada, así que sin invalidarlos nunca se recargan.
void invalidarInventario(Ref ref, {String? productoId}) {
  ref.invalidate(productosProvider);
  ref.invalidate(resumenInventarioProvider);
  if (productoId != null) {
    ref.invalidate(productoProvider(productoId));
    ref.invalidate(movimientosProvider(productoId));
  }
}

final inventarioActionsProvider = Provider<InventarioActions>(
  InventarioActions.new,
);

/// Escrituras de inventario. Solo se envía el `delta`: la cantidad nueva la
/// decide el servidor.
class InventarioActions {
  InventarioActions(this._ref);

  final Ref _ref;

  SupabaseInventarioRepository get _repo =>
      _ref.read(inventarioRepositoryProvider);

  Future<String> crear({
    required String nombre,
    required Unidad unidad,
    required int cantidad,
    int minimo = kMinimoPorDefecto,
    CategoriaProducto categoria = CategoriaProducto.medicamento,
    DateTime? vencimiento,
    int? precioVentaCop,
    int? costoCop,
  }) async {
    final id = await _repo.crearProducto(
      nombre: nombre,
      unidad: unidad,
      cantidad: cantidad,
      minimo: minimo,
      categoria: categoria,
      vencimiento: vencimiento,
      precioVentaCop: precioVentaCop,
      costoCop: costoCop,
    );
    invalidarInventario(_ref, productoId: id);
    return id;
  }

  Future<void> actualizar({
    required String id,
    required String nombre,
    required CategoriaProducto categoria,
    DateTime? vencimiento,
    required int minimo,
    int? precioVentaCop,
    int? costoCop,
  }) async {
    await _repo.actualizarProducto(
      id: id,
      nombre: nombre,
      categoria: categoria,
      vencimiento: vencimiento,
      minimo: minimo,
      precioVentaCop: precioVentaCop,
      costoCop: costoCop,
    );
    invalidarInventario(_ref, productoId: id);
  }

  Future<void> archivar(String id) async {
    await _repo.archivarProducto(id);
    invalidarInventario(_ref, productoId: id);
  }

  Future<ResultadoAjuste> ajustar({
    required Producto producto,
    required int delta,
    required MotivoMovimiento motivo,
  }) => _mover(productoId: producto.id, delta: delta, motivo: motivo);

  /// Revierte un movimiento con su inverso (`deshacer`, solo-append).
  Future<ResultadoAjuste> deshacer({
    required String productoId,
    required String movimientoId,
    required int delta,
  }) => _mover(
    productoId: productoId,
    delta: -delta,
    motivo: MotivoMovimiento.deshacer,
    deshaceId: movimientoId,
  );

  Future<ResultadoAjuste> _mover({
    required String productoId,
    required int delta,
    required MotivoMovimiento motivo,
    String? deshaceId,
  }) async {
    try {
      final r = await _repo.moverStock(
        productoId: productoId,
        delta: delta,
        motivo: motivo,
        deshaceId: deshaceId,
      );
      invalidarInventario(_ref, productoId: productoId);
      return r;
    } on InventarioFailure catch (e) {
      // La UI dice "Actualiza la lista": el estado local ya no es fiable.
      if (e.tipo == ErrorInventario.stockInsuficiente ||
          e.tipo == ErrorInventario.noDisponible) {
        invalidarInventario(_ref, productoId: productoId);
      }
      rethrow;
    }
  }
}
