import '../stock.dart';

/// Unidad en que se cuenta un producto. Cantidades siempre enteras (D-03).
enum Unidad {
  unidad,
  tableta,
  frasco,
  ml,
  dosis,
  caja,
  kg;

  /// Texto del chip del selector.
  String get chip => switch (this) {
    Unidad.unidad => 'Unidad',
    Unidad.tableta => 'Tableta',
    Unidad.frasco => 'Frasco',
    Unidad.ml => 'ml',
    Unidad.dosis => 'Dosis',
    Unidad.caja => 'Caja',
    Unidad.kg => 'kg',
  };

  /// Etiqueta con concordancia de número: "1 frasco", "3 frascos".
  String etiqueta(int n) {
    final uno = n == 1;
    return switch (this) {
      Unidad.unidad => uno ? 'unidad' : 'unidades',
      Unidad.tableta => uno ? 'tableta' : 'tabletas',
      Unidad.frasco => uno ? 'frasco' : 'frascos',
      Unidad.caja => uno ? 'caja' : 'cajas',
      Unidad.ml => 'ml',
      Unidad.dosis => 'dosis',
      Unidad.kg => 'kg',
    };
  }

  String get bd => name;

  static Unidad desdeBd(String v) =>
      Unidad.values.firstWhere((u) => u.name == v, orElse: () => Unidad.unidad);
}

enum CategoriaProducto {
  medicamento,
  insumo,
  alimento,
  otro;

  String get etiqueta => switch (this) {
    CategoriaProducto.medicamento => 'Medicamento',
    CategoriaProducto.insumo => 'Insumo',
    CategoriaProducto.alimento => 'Alimento',
    CategoriaProducto.otro => 'Otro',
  };

  String get bd => name;

  static CategoriaProducto desdeBd(String v) => CategoriaProducto.values
      .firstWhere((c) => c.name == v, orElse: () => CategoriaProducto.otro);
}

/// Ítem de inventario de la clínica (D-01: pertenece a la clínica, no a un
/// veterinario). La cantidad solo cambia por movimientos del ledger en el
/// servidor; el cliente nunca la calcula.
class Producto {
  const Producto({
    required this.id,
    required this.clinicaId,
    required this.nombre,
    required this.categoria,
    required this.unidad,
    required this.cantidad,
    required this.minimo,
    this.vencimiento,
    this.precioVentaCop,
    this.costoCop,
    this.archivado = false,
  });

  final String id;
  final String clinicaId;
  final String nombre;
  final CategoriaProducto categoria;
  final Unidad unidad;
  final int cantidad;
  final int minimo;
  final DateTime? vencimiento;
  final int? precioVentaCop;
  final int? costoCop;
  final bool archivado;

  /// D-07: bajo es estrictamente `cantidad < minimo`. Estar justo en el
  /// mínimo no es bajo, y con mínimo 0 nunca hay alerta.
  bool get bajo => cantidad < minimo;

  /// Sin existencias en un producto que sí tiene mínimo.
  bool get agotado => cantidad == 0 && minimo > 0;

  /// Días calendario hasta el vencimiento (negativo si ya venció), o `null`
  /// sin fecha. [hoyBogota] viene del reloj inyectado, nunca del reloj del sistema.
  int? diasParaVencer(DateTime hoyBogota) {
    final v = vencimiento;
    if (v == null) return null;
    final a = DateTime.utc(v.year, v.month, v.day);
    final b = DateTime.utc(hoyBogota.year, hoyBogota.month, hoyBogota.day);
    return a.difference(b).inDays;
  }

  bool vencePronto(DateTime hoyBogota) {
    final d = diasParaVencer(hoyBogota);
    return d != null && d >= 0 && d <= kDiasVencePronto;
  }

  bool vencido(DateTime hoyBogota) {
    final d = diasParaVencer(hoyBogota);
    return d != null && d < 0;
  }

  Producto copyWith({
    String? nombre,
    CategoriaProducto? categoria,
    Unidad? unidad,
    int? cantidad,
    int? minimo,
    DateTime? vencimiento,
    int? precioVentaCop,
    int? costoCop,
    bool? archivado,
  }) => Producto(
    id: id,
    clinicaId: clinicaId,
    nombre: nombre ?? this.nombre,
    categoria: categoria ?? this.categoria,
    unidad: unidad ?? this.unidad,
    cantidad: cantidad ?? this.cantidad,
    minimo: minimo ?? this.minimo,
    vencimiento: vencimiento ?? this.vencimiento,
    precioVentaCop: precioVentaCop ?? this.precioVentaCop,
    costoCop: costoCop ?? this.costoCop,
    archivado: archivado ?? this.archivado,
  );
}

/// Conteos para la tarjeta de Inicio.
class ResumenInventario {
  const ResumenInventario({
    this.bajos = 0,
    this.porVencer = 0,
    this.vencidos = 0,
  });

  final int bajos;
  final int porVencer;
  final int vencidos;
}
