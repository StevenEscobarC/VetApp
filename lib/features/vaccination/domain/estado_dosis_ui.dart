import '../../../core/widgets/status/dosis_estado_chip.dart';
import 'entities/carne.dart';

/// Estado visual del chip para un estado de carné; `completo` y `alDia` se
/// muestran igual.
DosisEstado dosisEstadoDe(EstadoCarne e) => switch (e) {
  EstadoCarne.vencida => DosisEstado.vencida,
  EstadoCarne.proxima => DosisEstado.proxima,
  EstadoCarne.alDia || EstadoCarne.completo => DosisEstado.alDia,
};

/// Texto de vencimiento relativo a [hoy] (ambos como fecha-sin-hora UTC).
String textoVencimiento(DateTime proxima, DateTime hoy) {
  final dias = DateTime.utc(proxima.year, proxima.month, proxima.day)
      .difference(DateTime.utc(hoy.year, hoy.month, hoy.day))
      .inDays;
  if (dias == 0) return 'Vence hoy';
  if (dias > 0) return 'Vence en $dias ${dias == 1 ? 'día' : 'días'}';
  final n = -dias;
  return 'Venció hace $n ${n == 1 ? 'día' : 'días'}';
}

/// Días relativos a [hoy] para la línea de contexto de la vista previa
/// ("en 21 días", "hoy", "hace 18 días"); ambos como fecha-sin-hora.
String textoEnDias(DateTime proxima, DateTime hoy) {
  final dias = DateTime.utc(proxima.year, proxima.month, proxima.day)
      .difference(DateTime.utc(hoy.year, hoy.month, hoy.day))
      .inDays;
  if (dias == 0) return 'hoy';
  final n = dias.abs();
  final texto = '$n ${n == 1 ? 'día' : 'días'}';
  return dias > 0 ? 'en $texto' : 'hace $texto';
}
