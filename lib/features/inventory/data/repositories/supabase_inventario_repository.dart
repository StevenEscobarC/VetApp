import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/data/limite_plan_postgrest.dart';
import '../../../../core/errors/limite_plan.dart';
import '../../../vaccination/domain/fecha_bd.dart';
import '../../domain/entities/movimiento_stock.dart';
import '../../domain/entities/producto.dart';
import '../../domain/inventario_failure.dart';
import '../../domain/stock.dart';

const String kMensajeSinConexion =
    'Sin conexión. No se guardaron los cambios. Inténtalo de nuevo cuando tengas señal.';
const String kMensajeSinConexionAjuste =
    'Sin conexión. El ajuste no se guardó. Inténtalo de nuevo cuando tengas señal.';

/// Acceso concreto a Supabase para el inventario de la clínica.
///
/// La cantidad nunca se calcula ni se escribe desde aquí: solo se envía el
/// `delta` a la RPC `mover_stock` y el servidor decide el resultado (ledger
/// solo-append). No hay `.update/.insert/.delete` directos: toda escritura es
/// RPC y el aislamiento por clínica lo da la RLS, sin filtrar en Dart.
class SupabaseInventarioRepository {
  SupabaseInventarioRepository(this._client);

  final SupabaseClient _client;

  Future<T> _run<T>(
    Future<T> Function() op,
    String generico, {
    String sinConexion = kMensajeSinConexion,
  }) async {
    try {
      return await op();
    } on PostgrestException catch (e) {
      throw inventarioFailureDe(e);
    } catch (e) {
      if (esErrorDeRed(e)) {
        throw InventarioFailure(sinConexion, tipo: ErrorInventario.sinConexion);
      }
      throw InventarioFailure(generico);
    }
  }

  List<Map<String, dynamic>> _filas(Object? r) => [
    for (final f in (r as List? ?? const [])) f as Map<String, dynamic>,
  ];

  /// Productos activos de la clínica, por nombre.
  Future<List<Producto>> productos() => _run(() async {
    final r = await _client
        .from('productos')
        .select()
        .isFilter('archivado_at', null)
        .order('nombre');
    return _filas(r).map(productoDesdeFila).toList();
  }, 'No pudimos cargar el inventario. Intenta de nuevo.');

  /// `null` si no existe o no es visible. Los archivados llegan con
  /// `archivado: true`.
  Future<Producto?> producto(String id) => _run(() async {
    final f = await _client
        .from('productos')
        .select()
        .eq('id', id)
        .maybeSingle();
    return f == null ? null : productoDesdeFila(f);
  }, 'No pudimos cargar el producto. Intenta de nuevo.');

  Future<String> crearProducto({
    required String nombre,
    required Unidad unidad,
    required int cantidad,
    int minimo = kMinimoPorDefecto,
    CategoriaProducto categoria = CategoriaProducto.medicamento,
    DateTime? vencimiento,
    int? precioVentaCop,
    int? costoCop,
  }) => _run(() async {
    final r = await _client.rpc(
      'crear_producto',
      params: paramsCrearProducto(
        nombre: nombre,
        unidad: unidad,
        cantidad: cantidad,
        minimo: minimo,
        categoria: categoria,
        vencimiento: vencimiento,
        precioVentaCop: precioVentaCop,
        costoCop: costoCop,
      ),
    );
    return r as String;
  }, 'No pudimos guardar el producto. Intenta de nuevo.');

  Future<void> actualizarProducto({
    required String id,
    required String nombre,
    required CategoriaProducto categoria,
    DateTime? vencimiento,
    required int minimo,
    int? precioVentaCop,
    int? costoCop,
  }) => _run(() async {
    await _client.rpc(
      'actualizar_producto',
      params: paramsActualizarProducto(
        id: id,
        nombre: nombre,
        categoria: categoria,
        vencimiento: vencimiento,
        minimo: minimo,
        precioVentaCop: precioVentaCop,
        costoCop: costoCop,
      ),
    );
  }, 'No pudimos guardar los cambios. Intenta de nuevo.');

  Future<void> archivarProducto(String id) => _run(() async {
    await _client.rpc('archivar_producto', params: {'p_id': id});
  }, 'No pudimos archivar el producto. Intenta de nuevo.');

  Future<ResultadoAjuste> moverStock({
    required String productoId,
    required int delta,
    required MotivoMovimiento motivo,
    String? deshaceId,
  }) => _run(
    () async {
      final p = paramsMoverStock(
        productoId: productoId,
        delta: delta,
        motivo: motivo,
        deshaceId: deshaceId,
      );
      final r = await _client.rpc('mover_stock', params: p);
      final f = _filas(r).first;
      return ResultadoAjuste(
        movimientoId: f['movimiento_id'] as String,
        cantidadNueva: f['cantidad_nueva'] as int,
      );
    },
    'No pudimos guardar el ajuste. Intenta de nuevo.',
    sinConexion: kMensajeSinConexionAjuste,
  );

  /// Historial del producto, del más reciente al más antiguo.
  Future<List<MovimientoStock>> movimientos(String productoId) =>
      _run(() async {
        final r = await _client
            .from('movimientos_inventario')
            .select(
              '*, autor:perfiles!movimientos_veterinario_perfil_fkey(nombre)',
            )
            .eq('producto_id', productoId)
            .order('created_at', ascending: false)
            .limit(kMovimientosHistorial);
        return _filas(r).map(movimientoDesdeFila).toList();
      }, 'No pudimos cargar el historial. Intenta de nuevo.');

  Future<ResumenInventario> resumen() => _run(() async {
    final r = _filas(await _client.rpc('inventario_resumen'));
    if (r.isEmpty) return const ResumenInventario();
    final f = r.first;
    return ResumenInventario(
      bajos: (f['bajos'] as int?) ?? 0,
      porVencer: (f['por_vencer'] as int?) ?? 0,
      vencidos: (f['vencidos'] as int?) ?? 0,
    );
  }, 'No pudimos cargar el resumen del inventario. Intenta de nuevo.');

  @visibleForTesting
  static Map<String, Object?> paramsCrearProducto({
    required String nombre,
    required Unidad unidad,
    required int cantidad,
    required int minimo,
    required CategoriaProducto categoria,
    DateTime? vencimiento,
    int? precioVentaCop,
    int? costoCop,
  }) => {
    'p_nombre': nombre.trim(),
    'p_unidad': unidad.bd,
    'p_cantidad': cantidad,
    'p_minimo': minimo,
    'p_categoria': categoria.bd,
    'p_vencimiento': vencimiento == null ? null : fechaABd(vencimiento),
    'p_precio_venta_cop': precioVentaCop,
    'p_costo_cop': costoCop,
  };

  @visibleForTesting
  static Map<String, Object?> paramsActualizarProducto({
    required String id,
    required String nombre,
    required CategoriaProducto categoria,
    DateTime? vencimiento,
    required int minimo,
    int? precioVentaCop,
    int? costoCop,
  }) => {
    'p_id': id,
    'p_nombre': nombre.trim(),
    'p_categoria': categoria.bd,
    'p_vencimiento': vencimiento == null ? null : fechaABd(vencimiento),
    'p_minimo': minimo,
    'p_precio_venta_cop': precioVentaCop,
    'p_costo_cop': costoCop,
  };

  @visibleForTesting
  static Map<String, Object?> paramsMoverStock({
    required String productoId,
    required int delta,
    required MotivoMovimiento motivo,
    String? deshaceId,
  }) => {
    'p_producto_id': productoId,
    'p_delta': delta,
    'p_motivo': motivo.bd,
    'p_origen': 'ajuste',
    'p_ref_id': null,
    'p_nota': null,
    'p_deshace_id': deshaceId,
  };
}

@visibleForTesting
Producto productoDesdeFila(Map<String, dynamic> f) => Producto(
  id: f['id'] as String,
  clinicaId: f['clinica_id'] as String,
  nombre: f['nombre'] as String,
  categoria: CategoriaProducto.desdeBd(f['categoria'] as String),
  unidad: Unidad.desdeBd(f['unidad'] as String),
  cantidad: f['cantidad'] as int,
  minimo: f['minimo'] as int,
  vencimiento: f['vencimiento'] == null
      ? null
      : fechaDeBd(f['vencimiento'] as String),
  precioVentaCop: f['precio_venta_cop'] as int?,
  costoCop: f['costo_cop'] as int?,
  archivado: f['archivado_at'] != null,
);

@visibleForTesting
MovimientoStock movimientoDesdeFila(Map<String, dynamic> f) {
  final autor = f['autor'];
  return MovimientoStock(
    id: f['id'] as String,
    productoId: f['producto_id'] as String,
    delta: f['delta'] as int,
    cantidadResultante: f['cantidad_resultante'] as int,
    motivo: MotivoMovimiento.desdeBd(f['motivo'] as String),
    origen: (f['origen'] as String?) ?? 'ajuste',
    deshaceId: f['deshace_id'] as String?,
    autorNombre: autor is Map ? autor['nombre'] as String? : null,
    creadoEn: DateTime.parse(f['created_at'] as String).toLocal(),
  );
}

/// [InventarioFailure] con mensaje en español, tipo y límite de plan.
@visibleForTesting
InventarioFailure inventarioFailureDe(PostgrestException e) {
  final limite = limitePlanDe(e);
  final tipo = _tipoDe(e, limite);
  return InventarioFailure(
    mensajeErrorInventario(e),
    tipo: tipo,
    limite: limite,
  );
}

ErrorInventario _tipoDe(PostgrestException e, LimitePlan? limite) {
  if (limite == LimitePlan.soloLectura) return ErrorInventario.soloLectura;
  return switch (e.code) {
    'IN001' => ErrorInventario.stockInsuficiente,
    'IN002' => ErrorInventario.noDisponible,
    'IN003' => ErrorInventario.yaDeshecho,
    '23505' => ErrorInventario.nombreDuplicado,
    '42501' => ErrorInventario.sinPermiso,
    '23514' => ErrorInventario.datosInvalidos,
    _ => ErrorInventario.otro,
  };
}

/// Única tabla de traducciones: nunca se muestra el texto crudo del servidor.
@visibleForTesting
String mensajeErrorInventario(PostgrestException e) {
  return switch (_tipoDe(e, limitePlanDe(e))) {
    ErrorInventario.soloLectura =>
      'Tu cuenta está en solo lectura. Pide al administrador que active el plan.',
    ErrorInventario.stockInsuficiente =>
      'No hay suficiente stock para ese ajuste.',
    ErrorInventario.noDisponible =>
      'Ese producto ya no está disponible. Actualiza la lista.',
    ErrorInventario.yaDeshecho => 'Ese ajuste ya se deshizo.',
    ErrorInventario.nombreDuplicado => 'Ya tienes un producto con ese nombre.',
    ErrorInventario.sinPermiso =>
      'Solo el administrador de la clínica puede hacer esto.',
    ErrorInventario.datosInvalidos =>
      'Revisa los datos: las cantidades deben ser enteros válidos.',
    _ => 'No pudimos completar la operación. Intenta de nuevo.',
  };
}

/// Fallos de conectividad. Sin importar la libreria de IO (el scaffold web debe compilar): se
/// reconoce por el nombre del tipo.
@visibleForTesting
bool esErrorDeRed(Object e) {
  if (e is TimeoutException) return true;
  final nombre = e.runtimeType.toString();
  return nombre == 'SocketException' || nombre == 'ClientException';
}
