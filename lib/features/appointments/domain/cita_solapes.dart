import '../../../core/utils/zona_bogota.dart';
import 'entities/cita.dart';

/// `true` si `[aIni, aIni+aMin)` y `[bIni, bIni+bMin)` se cruzan. Terminar
/// justo cuando empieza otra NO es cruce.
bool solapa(DateTime aIni, int aMin, DateTime bIni, int bMin) {
  final aFin = aIni.add(Duration(minutes: aMin));
  final bFin = bIni.add(Duration(minutes: bMin));
  return aIni.isBefore(bFin) && bIni.isBefore(aFin);
}

/// Una cita cancelada o con `noAsistio` libera su hueco (D-21): no cuenta
/// para cruces ni para el primer hueco libre.
bool ocupaHorario(EstadoCita e) =>
    e != EstadoCita.cancelada && e != EstadoCita.noAsistio;

/// Citas activas que se cruzan con `[inicio, inicio+duracionMin)`, por hora.
List<Cita> solapesCon({
  required DateTime inicio,
  required int duracionMin,
  required Iterable<Cita> citas,
  String? excluirId,
}) {
  final r = citas
      .where(
        (c) =>
            c.id != excluirId &&
            ocupaHorario(c.estado) &&
            solapa(inicio, duracionMin, c.fechaHora, c.duracionMin),
      )
      .toList()
    ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
  return r;
}

/// Primer instante UTC libre del [dia] de Bogotá, en pasos de 15 min.
/// Hoy parte del siguiente cuarto desde [ahora]; otro día, de las 8:00.
/// Si nada cabe antes de las 22:00 devuelve el candidato inicial acotado
/// a las 22:00.
DateTime primerHuecoLibre({
  required Iterable<Cita> citas,
  required DateTime dia,
  required DateTime ahora,
  required int duracionMin,
  String? excluirId,
}) {
  final limite = deBogota(dia.year, dia.month, dia.day, 22);
  DateTime inicial;
  if (mismoDia(diaBogota(ahora), dia)) {
    final b = aBogota(ahora);
    final minutos = b.hour * 60 + b.minute;
    var redondeo = ((minutos + 14) ~/ 15) * 15;
    if (b.second > 0 && minutos % 15 == 0) redondeo += 15;
    inicial = deBogota(dia.year, dia.month, dia.day, 0, redondeo);
  } else {
    inicial = deBogota(dia.year, dia.month, dia.day, 8);
  }
  var candidato = inicial;
  while (!candidato.isAfter(limite)) {
    if (solapesCon(
      inicio: candidato,
      duracionMin: duracionMin,
      citas: citas,
      excluirId: excluirId,
    ).isEmpty) {
      return candidato;
    }
    candidato = candidato.add(const Duration(minutes: 15));
  }
  return inicial.isAfter(limite) ? limite : inicial;
}
