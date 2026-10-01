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

/// Desde dónde se busca hueco en el [dia] de Bogotá (instante UTC): hoy, el
/// siguiente cuarto desde [ahora]; otro día, las 8:00. Nunca antes de las
/// 6:00 (el mínimo del selector de hora) ni después de las 22:00 (el
/// máximo), así el valor siempre es representable en el selector.
DateTime inicioBusquedaHueco({required DateTime dia, required DateTime ahora}) {
  final apertura = deBogota(dia.year, dia.month, dia.day, 6);
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
  if (inicial.isBefore(apertura)) return apertura;
  if (inicial.isAfter(limite)) return limite;
  return inicial;
}

/// Primer instante UTC libre del [dia] de Bogotá, en pasos de 15 min, entre
/// [inicioBusquedaHueco] y las 22:00. Devuelve `null` si nada cabe o si hoy
/// ya pasaron las 22:00: nunca sugiere como "libre" una hora que se cruza o
/// que ya pasó.
DateTime? primerHuecoLibre({
  required Iterable<Cita> citas,
  required DateTime dia,
  required DateTime ahora,
  required int duracionMin,
  String? excluirId,
}) {
  final limite = deBogota(dia.year, dia.month, dia.day, 22);
  var candidato = inicioBusquedaHueco(dia: dia, ahora: ahora);
  // Hoy después de las 22:00 el inicio queda acotado al límite, que ya pasó.
  if (candidato.isBefore(ahora)) return null;
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
  return null;
}
