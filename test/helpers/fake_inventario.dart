import 'dart:async';

import 'package:vetapp/features/inventory/data/repositories/supabase_inventario_repository.dart';
import 'package:vetapp/features/inventory/domain/entities/movimiento_stock.dart';
import 'package:vetapp/features/inventory/domain/entities/producto.dart';
import 'package:vetapp/features/inventory/domain/inventario_failure.dart';
import 'package:vetapp/features/inventory/domain/stock.dart';

Producto productoDePrueba({
  String id = 'p1',
  String nombre = 'Amoxicilina',
  Unidad unidad = Unidad.frasco,
  int cantidad = 5,
  int minimo = 2,
  DateTime? vencimiento,
  int? precioVentaCop,
  int? costoCop,
  CategoriaProducto categoria = CategoriaProducto.medicamento,
}) => Producto(
  id: id,
  clinicaId: 'c1',
  nombre: nombre,
  categoria: categoria,
  unidad: unidad,
  cantidad: cantidad,
  minimo: minimo,
  vencimiento: vencimiento,
  precioVentaCop: precioVentaCop,
  costoCop: costoCop,
);

/// Reemplazo en memoria de [SupabaseInventarioRepository] con estado: aplica
/// deltas como el servidor (sin negativos, un solo deshacer por movimiento),
/// registra [llamadas] y permite errores por método.
class FakeInventarioRepository implements SupabaseInventarioRepository {
  FakeInventarioRepository({
    List<Producto>? productos,
    List<MovimientoStock>? movimientos,
    this.resumenData,
    this.error,
    this.errorProductos,
    this.errorProducto,
    this.errorCrear,
    this.errorActualizar,
    this.errorArchivar,
    this.errorMover,
    this.errorMovimientos,
    this.errorResumen,
  }) : _productos = [...?productos],
       _movimientos = [...?movimientos];

  final List<Producto> _productos;
  final List<MovimientoStock> _movimientos;
  final ResumenInventario? resumenData;

  /// Error para cualquier método sin error propio.
  final Object? error;
  final Object? errorProductos;
  final Object? errorProducto;
  final Object? errorCrear;
  final Object? errorActualizar;
  final Object? errorArchivar;
  final Object? errorMover;
  final Object? errorMovimientos;
  final Object? errorResumen;

  final llamadas = <({String metodo, Map<String, Object?> args})>[];

  /// Si se asigna, [moverStock] espera aquí antes de aplicar el cambio.
  Completer<void>? bloqueoMover;

  int _seq = 0;

  void _log(String metodo, [Map<String, Object?> args = const {}]) =>
      llamadas.add((metodo: metodo, args: args));

  void _falla(Object? propio) {
    final e = propio ?? error;
    if (e != null) throw e;
  }

  @override
  Future<List<Producto>> productos() async {
    _log('productos');
    _falla(errorProductos);
    return [..._productos.where((p) => !p.archivado)];
  }

  @override
  Future<Producto?> producto(String id) async {
    _log('producto', {'id': id});
    _falla(errorProducto);
    for (final p in _productos) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<String> crearProducto({
    required String nombre,
    required Unidad unidad,
    required int cantidad,
    int minimo = kMinimoPorDefecto,
    CategoriaProducto categoria = CategoriaProducto.medicamento,
    DateTime? vencimiento,
    int? precioVentaCop,
    int? costoCop,
  }) async {
    _log('crearProducto', {
      'nombre': nombre,
      'unidad': unidad,
      'cantidad': cantidad,
      'minimo': minimo,
      'categoria': categoria,
      'vencimiento': vencimiento,
      'precioVentaCop': precioVentaCop,
      'costoCop': costoCop,
    });
    _falla(errorCrear);
    final id = 'nuevo-${++_seq}';
    _productos.add(
      productoDePrueba(
        id: id,
        nombre: nombre.trim(),
        unidad: unidad,
        cantidad: cantidad,
        minimo: minimo,
        categoria: categoria,
        vencimiento: vencimiento,
        precioVentaCop: precioVentaCop,
        costoCop: costoCop,
      ),
    );
    return id;
  }

  @override
  Future<void> actualizarProducto({
    required String id,
    required String nombre,
    required CategoriaProducto categoria,
    DateTime? vencimiento,
    required int minimo,
    int? precioVentaCop,
    int? costoCop,
  }) async {
    _log('actualizarProducto', {
      'id': id,
      'nombre': nombre,
      'categoria': categoria,
      'vencimiento': vencimiento,
      'minimo': minimo,
      'precioVentaCop': precioVentaCop,
      'costoCop': costoCop,
    });
    _falla(errorActualizar);
    final i = _productos.indexWhere((p) => p.id == id);
    if (i < 0) return;
    final p = _productos[i];
    _productos[i] = Producto(
      id: p.id,
      clinicaId: p.clinicaId,
      nombre: nombre.trim(),
      categoria: categoria,
      unidad: p.unidad,
      cantidad: p.cantidad,
      minimo: minimo,
      vencimiento: vencimiento,
      precioVentaCop: precioVentaCop,
      costoCop: costoCop,
      archivado: p.archivado,
    );
  }

  @override
  Future<void> archivarProducto(String id) async {
    _log('archivarProducto', {'id': id});
    _falla(errorArchivar);
    final i = _productos.indexWhere((p) => p.id == id);
    if (i >= 0) _productos[i] = _productos[i].copyWith(archivado: true);
  }

  @override
  Future<ResultadoAjuste> moverStock({
    required String productoId,
    required int delta,
    required MotivoMovimiento motivo,
    String? deshaceId,
    int? cantidadEsperada,
  }) async {
    _log('moverStock', {
      'productoId': productoId,
      'delta': delta,
      'motivo': motivo,
      'deshaceId': deshaceId,
      'cantidadEsperada': cantidadEsperada,
    });
    final gate = bloqueoMover;
    if (gate != null) await gate.future;
    _falla(errorMover);
    final i = _productos.indexWhere((p) => p.id == productoId);
    if (i < 0) {
      throw const InventarioFailure(
        'Ese producto ya no está disponible. Actualiza la lista.',
        tipo: ErrorInventario.noDisponible,
      );
    }
    // Como el servidor (IN004): el conteo se rechaza si el stock cambió.
    if (cantidadEsperada != null &&
        cantidadEsperada != _productos[i].cantidad) {
      throw const InventarioFailure(
        'El stock cambió mientras contabas. Revisa la cantidad actual e '
        'intenta de nuevo.',
        tipo: ErrorInventario.stockCambio,
      );
    }
    if (deshaceId != null &&
        _movimientos.any((m) => m.deshaceId == deshaceId)) {
      throw const InventarioFailure(
        'Ese ajuste ya se deshizo.',
        tipo: ErrorInventario.yaDeshecho,
      );
    }
    final nueva = _productos[i].cantidad + delta;
    if (nueva < 0) {
      throw const InventarioFailure(
        'No hay suficiente stock para ese ajuste.',
        tipo: ErrorInventario.stockInsuficiente,
      );
    }
    _productos[i] = _productos[i].copyWith(cantidad: nueva);
    final id = 'mov-${++_seq}';
    _movimientos.insert(
      0,
      MovimientoStock(
        id: id,
        productoId: productoId,
        delta: delta,
        cantidadResultante: nueva,
        motivo: motivo,
        origen: 'ajuste',
        deshaceId: deshaceId,
        autorNombre: 'Ana',
        creadoEn: DateTime(2026, 10, 31, 10),
      ),
    );
    return ResultadoAjuste(movimientoId: id, cantidadNueva: nueva);
  }

  @override
  Future<List<MovimientoStock>> movimientos(String productoId) async {
    _log('movimientos', {'productoId': productoId});
    _falla(errorMovimientos);
    return [
      for (final m in _movimientos)
        if (m.productoId == productoId) m,
    ].take(kMovimientosHistorial).toList();
  }

  @override
  Future<ResumenInventario> resumen() async {
    _log('resumen');
    _falla(errorResumen);
    final fijo = resumenData;
    if (fijo != null) return fijo;
    return ResumenInventario(
      bajos: _productos.where((p) => !p.archivado && p.bajo).length,
    );
  }
}
