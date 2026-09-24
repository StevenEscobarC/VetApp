enum CategoriaProducto { medicamento, insumo, alimento, otro }

/// Ítem de inventario propio del veterinario (no del cliente).
class Producto {
  const Producto({
    required this.id,
    required this.veterinarioId,
    required this.nombre,
    required this.categoria,
    required this.stockActual,
    required this.stockMinimo,
    required this.unidad,
    this.precioCompraCop,
    this.precioVentaCop,
  });

  final String id;
  final String veterinarioId;
  final String nombre;
  final CategoriaProducto categoria;
  final double stockActual;
  final double stockMinimo;
  final String unidad;
  final int? precioCompraCop;
  final int? precioVentaCop;

  bool get stockBajo => stockActual <= stockMinimo;

  Producto copyWith({
    String? nombre,
    CategoriaProducto? categoria,
    double? stockActual,
    double? stockMinimo,
    String? unidad,
    int? precioCompraCop,
    int? precioVentaCop,
  }) {
    return Producto(
      id: id,
      veterinarioId: veterinarioId,
      nombre: nombre ?? this.nombre,
      categoria: categoria ?? this.categoria,
      stockActual: stockActual ?? this.stockActual,
      stockMinimo: stockMinimo ?? this.stockMinimo,
      unidad: unidad ?? this.unidad,
      precioCompraCop: precioCompraCop ?? this.precioCompraCop,
      precioVentaCop: precioVentaCop ?? this.precioVentaCop,
    );
  }
}
