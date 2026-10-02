/// Intervalos ofrecidos al registrar un biológico "Otro" (D-04). El chip
/// "Sin refuerzo" lo maneja la UI con `sinRefuerzo = true`.
const kIntervalosOtro = [21, 30, 90, 180, 365];

/// Etiqueta legible de una duración en días (D-03).
String etiquetaDuracion(int dias) {
  switch (dias) {
    case 30:
      return '1 mes';
    case 35:
      return '5 semanas';
    case 84:
    case 90:
      return '3 meses';
    case 180:
      return '6 meses';
    case 365:
      return '1 año';
    case 1095:
      return '3 años';
    default:
      return '$dias días';
  }
}
