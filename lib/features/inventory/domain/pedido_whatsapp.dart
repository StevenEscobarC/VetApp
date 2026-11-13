import '../../../core/utils/formato.dart';
import 'entities/producto.dart';

/// Texto del pedido de reposición (D-11): una línea por producto bajo su
/// mínimo (`cantidad < minimo`), A-Z, pidiendo lo necesario para llegar al
/// doble del mínimo. Se comparte por el menú del sistema, sin destinatario.
String mensajePedidoStock({
  required List<Producto> productos,
  String? clinica,
}) {
  final nombre = clinica?.trim();
  final titulo = (nombre == null || nombre.isEmpty)
      ? 'Pedido de insumos:'
      : 'Pedido de $nombre:';
  final bajos = [
    for (final p in productos)
      if (p.bajo) p,
  ]..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
  final lineas = [
    for (final p in bajos)
      '- ${p.nombre}: pedir ${formatearMiles(p.minimo * 2 - p.cantidad)} '
          '${p.unidad.etiqueta(p.minimo * 2 - p.cantidad)} '
          '(quedan ${formatearMiles(p.cantidad)})',
  ];
  return [titulo, ...lineas].join('\n');
}
