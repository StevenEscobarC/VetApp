enum EstadoFactura { cotizacion, pendiente, pagada, anulada }

class ItemFactura {
  const ItemFactura({
    required this.descripcion,
    required this.cantidad,
    required this.precioUnitarioCop,
    this.productoId,
  });

  final String descripcion;
  final double cantidad;
  final int precioUnitarioCop;
  final String? productoId;

  int get totalCop => (cantidad * precioUnitarioCop).round();
}

/// Cotización/recibo simple. `pdfUrl` se llena tras generar el PDF;
/// el puente a facturación electrónica DIAN (Siigo/Alegra/Factus) se
/// añade después como un caso de uso adicional, no cambia este modelo.
class Factura {
  const Factura({
    required this.id,
    required this.veterinarioId,
    required this.clienteId,
    this.mascotaId,
    required this.items,
    required this.fecha,
    this.estado = EstadoFactura.cotizacion,
    this.pdfUrl,
  });

  final String id;
  final String veterinarioId;
  final String clienteId;
  final String? mascotaId;
  final List<ItemFactura> items;
  final DateTime fecha;
  final EstadoFactura estado;
  final String? pdfUrl;

  int get totalCop => items.fold(0, (sum, item) => sum + item.totalCop);
}
