import '../../../core/errors/limite_plan.dart';

/// Clasificación del error para que la UI decida (refrescar, quitar una
/// línea, abrir la hoja del plan).
enum ErrorCobro {
  stockInsuficiente,
  productoNoDisponible,
  estadoInvalido,
  cotizacionNoDisponible,
  visitaYaCobrada,
  nombreDuplicado,
  sinPermiso,
  datosInvalidos,
  sinConexion,
  soloLectura,
  otro,
}

/// Error de cobros con mensaje ya traducido al español. La capa de datos
/// traduce `PostgrestException` y fallos de red a este tipo en un solo lugar;
/// el texto crudo del servidor nunca llega a la UI. Lleva los datos que la UI
/// necesita para actuar ([productoId], [quedan], [numeroExistente]).
class CobroFailure implements Exception, ConLimitePlan {
  const CobroFailure(
    this.message, {
    this.tipo = ErrorCobro.otro,
    this.limite,
    this.productoId,
    this.quedan,
    this.numeroExistente,
  });

  final String message;
  final ErrorCobro tipo;

  @override
  final LimitePlan? limite;

  /// Producto que causó IN001/IN002, si el servidor lo informó.
  final String? productoId;

  /// Existencias que quedan (IN001).
  final int? quedan;

  /// Número visible de la cuenta de cobro que ya tiene la visita (BC003).
  final String? numeroExistente;

  @override
  String toString() => message;
}
