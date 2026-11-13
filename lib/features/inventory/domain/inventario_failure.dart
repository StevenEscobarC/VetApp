import '../../../core/errors/limite_plan.dart';

/// Clasificación del error para que la UI decida (p. ej. refrescar la lista).
enum ErrorInventario {
  stockInsuficiente,
  noDisponible,
  yaDeshecho,

  /// IN004: el conteo se hizo sobre una cantidad que ya cambió en el servidor.
  stockCambio,
  nombreDuplicado,
  sinPermiso,
  datosInvalidos,
  sinConexion,
  soloLectura,
  otro,
}

/// Error de inventario con mensaje ya traducido al español. La capa de datos
/// ([SupabaseInventarioRepository]) traduce `PostgrestException` y fallos de
/// red a este tipo; el texto crudo del servidor nunca llega a la UI.
class InventarioFailure implements Exception, ConLimitePlan {
  const InventarioFailure(
    this.message, {
    this.tipo = ErrorInventario.otro,
    this.limite,
  });

  final String message;
  final ErrorInventario tipo;

  @override
  final LimitePlan? limite;

  @override
  String toString() => message;
}
