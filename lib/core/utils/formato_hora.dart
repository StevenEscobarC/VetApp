import 'zona_bogota.dart';

// Escritos a mano con espacios ASCII: la app nunca llama
// `initializeDateFormatting`, así que `DateFormat` con locale lanzaría.
// Todas las entradas son horas de pared de Bogotá (ver `aBogota`).

const _dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _diasLargos = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
const _meses = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

String _dos(int n) => n.toString().padLeft(2, '0');

String _horaSola(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${_dos(t.minute)}';
}

String _meridiem(DateTime t) => t.hour < 12 ? 'a. m.' : 'p. m.';

/// `10:30 a. m.` — nunca formato de 24 horas.
String hora12(DateTime t) => '${_horaSola(t)} ${_meridiem(t)}';

/// `LUN`..`DOM`.
String diaAbrev(DateTime dia) => _dias[dia.weekday - 1].toUpperCase();

/// `Lunes`..`Domingo`.
String nombreDiaLargo(DateTime dia) => _diasLargos[dia.weekday - 1];

/// `mié 30/09`.
String diaCorto(DateTime dia) =>
    '${_dias[dia.weekday - 1]} ${_dos(dia.day)}/${_dos(dia.month)}';

/// `mié 30/09/2026`.
String fechaLarga(DateTime dia) => '${diaCorto(dia)}/${dia.year}';

/// `28 sep – 4 oct` o, dentro del mismo mes, `5 – 11 oct`.
String rangoSemanaTexto(DateTime lunes) {
  final dom = DateTime.utc(lunes.year, lunes.month, lunes.day + 6);
  if (dom.month == lunes.month) {
    return '${lunes.day} – ${dom.day} ${_meses[dom.month - 1]}';
  }
  return '${lunes.day} ${_meses[lunes.month - 1]} – '
      '${dom.day} ${_meses[dom.month - 1]}';
}

/// `10:30 – 11:00 a. m.` (mismo meridiano) o `11:30 a. m. – 12:30 p. m.`.
String rangoHoras(DateTime ini, DateTime fin) {
  if (_meridiem(ini) == _meridiem(fin)) {
    return '${_horaSola(ini)} – ${hora12(fin)}';
  }
  return '${hora12(ini)} – ${hora12(fin)}';
}

/// `15 min` / `1 h` / `1 h 30 min`.
String duracionTexto(int min) {
  final h = min ~/ 60;
  final m = min % 60;
  if (h == 0) return '$m min';
  if (m == 0) return '$h h';
  return '$h h $m min';
}

/// `29/09 6:15 p. m.`.
String fechaHoraCorta(DateTime t) =>
    '${_dos(t.day)}/${_dos(t.month)} ${hora12(t)}';

/// `Hoy, mié 30/09` / `Mañana, jue 01/10` / `vie 02/10`.
String encabezadoDia(DateTime dia, DateTime hoy) {
  if (mismoDia(dia, hoy)) return 'Hoy, ${diaCorto(dia)}';
  final manana = DateTime.utc(hoy.year, hoy.month, hoy.day + 1);
  if (mismoDia(dia, manana)) return 'Mañana, ${diaCorto(dia)}';
  return diaCorto(dia);
}

/// `Sin citas` / `1 cita` / `4 citas`.
String conteoCitas(int n) => switch (n) {
      0 => 'Sin citas',
      1 => '1 cita',
      _ => '$n citas',
    };

/// `en 25 min` / `en 1 h` / `en 1 h 10 min`.
String enCuanto(Duration d) => 'en ${duracionTexto(d.inMinutes)}';
