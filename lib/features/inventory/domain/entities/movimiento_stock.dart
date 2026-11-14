/// Motivo de un movimiento del ledger de inventario.
enum MotivoMovimiento {
  compra('compra', 'Compra'),
  uso('uso', 'Uso'),
  vencidoDanado('vencido_danado', 'Vencido o dañado'),
  conteo('conteo', 'Conteo'),
  alta('alta', 'Alta inicial'),
  deshacer('deshacer', 'Ajuste deshecho'),
  venta('venta', 'Venta'),
  dosis('dosis', 'Dosis');

  const MotivoMovimiento(this.bd, this.etiqueta);

  final String bd;
  final String etiqueta;

  static MotivoMovimiento desdeBd(String v) => MotivoMovimiento.values
      .firstWhere((m) => m.bd == v, orElse: () => MotivoMovimiento.conteo);

  /// Motivos que el usuario puede elegir al ajustar a mano.
  static const List<MotivoMovimiento> ajustables = [
    compra,
    uso,
    vencidoDanado,
    conteo,
  ];
}

/// Una fila del historial de un producto. Solo lectura: el ledger es
/// solo-append y se corrige con un movimiento `deshacer`.
class MovimientoStock {
  const MovimientoStock({
    required this.id,
    required this.productoId,
    required this.delta,
    required this.cantidadResultante,
    required this.motivo,
    required this.origen,
    required this.creadoEn,
    this.deshaceId,
    this.autorNombre,
    this.nota,
  });

  final String id;
  final String productoId;
  final int delta;
  final int cantidadResultante;
  final MotivoMovimiento motivo;
  final String origen;
  final String? deshaceId;
  final String? autorNombre;
  final DateTime creadoEn;

  /// Número del documento que movió el stock ("CC-0012" o
  /// "Anulada CC-0012"); `null` en los ajustes manuales.
  final String? nota;
}

/// Valor interno del origen de cobro reservado en la Fase 6; nunca se muestra.
const String kOrigenCobro = 'factura';

/// Respuesta del servidor tras un ajuste: la cantidad la decide él.
class ResultadoAjuste {
  const ResultadoAjuste({
    required this.movimientoId,
    required this.cantidadNueva,
  });

  final String movimientoId;
  final int cantidadNueva;
}
