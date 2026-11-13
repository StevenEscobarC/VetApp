import 'entities/cobro.dart';

/// Tamaño de cada lista de cobros (las más recientes primero).
const int kCobrosLista = 50;

/// Días de validez de una cotización desde su fecha (D-23).
const int kDiasValidezCotizacion = 15;

/// Tope del total de un documento, igual al check del servidor.
const int kTotalMaximoCop = 999999999;

/// Máximo de líneas por documento, igual al check del servidor.
const int kLineasMaximas = 50;

/// Número visible del documento, con la misma regla que `_numero_cobro` en
/// SQL: prefijo + 4 dígitos con ceros a la izquierda, sin truncar cuando el
/// consecutivo pasa de 9999 ('CC-0012', 'COT-0004', 'CC-12345'). El número
/// lo asigna siempre el servidor; aquí solo se formatea.
String formatearNumeroCobro(TipoCobro tipo, int numero) {
  final n = numero < 10000 ? numero.toString().padLeft(4, '0') : '$numero';
  return '${tipo.prefijo}-$n';
}
