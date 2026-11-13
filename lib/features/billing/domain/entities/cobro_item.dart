/// Clase de línea de un cobro.
enum TipoLinea {
  servicio('servicio'),
  producto('producto'),
  otro('otro');

  const TipoLinea(this.bd);

  final String bd;

  static TipoLinea desdeBd(String v) => TipoLinea.values.firstWhere(
    (t) => t.bd == v,
    orElse: () => TipoLinea.otro,
  );
}

/// Línea guardada de un cobro. La descripción y el precio unitario son una
/// copia tomada al emitir (D-14): si luego cambia el nombre del producto o la
/// tarifa del servicio, el documento ya emitido no cambia. Todo en pesos
/// enteros (D-03).
class CobroItem {
  const CobroItem({
    required this.orden,
    required this.tipo,
    required this.descripcion,
    required this.cantidad,
    required this.precioUnitarioCop,
    this.productoId,
    this.servicioId,
  });

  final int orden;
  final TipoLinea tipo;
  final String descripcion;
  final int cantidad;
  final int precioUnitarioCop;
  final String? productoId;
  final String? servicioId;

  int get subtotalCop => cantidad * precioUnitarioCop;
}

/// Línea que el cliente envía al crear o editar. No lleva total ni número:
/// el servidor calcula el total y copia nombres desde la base (D-14).
class LineaCobroNueva {
  const LineaCobroNueva({
    required this.tipo,
    required this.descripcion,
    required this.cantidad,
    required this.precioUnitarioCop,
    this.productoId,
    this.servicioId,
  });

  final TipoLinea tipo;
  final String descripcion;
  final int cantidad;
  final int precioUnitarioCop;
  final String? productoId;
  final String? servicioId;
}
