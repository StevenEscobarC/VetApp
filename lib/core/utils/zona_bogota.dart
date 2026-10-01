/// Colombia no tiene horario de verano desde 1993, así que UTC-5 es fijo
/// todo el año. La agenda usa este desfase en vez de `toLocal()` para que
/// la zona horaria del dispositivo nunca mueva los límites de un día.
const Duration _offset = Duration(hours: 5);

/// Convierte un instante real [instante] en un `DateTime` marcado UTC cuyos
/// campos (`hour`, `day`...) son la hora de pared de Bogotá. Solo sirve para
/// leer campos / formatear, nunca para comparar contra instantes reales.
DateTime aBogota(DateTime instante) => instante.toUtc().subtract(_offset);

/// Instante UTC real que corresponde a la hora de pared de Bogotá
/// [y]-[m]-[d] [h]:[min]. Dart normaliza desbordes (día 32, mes 13...).
DateTime deBogota(int y, int m, int d, [int h = 0, int min = 0]) =>
    DateTime.utc(y, m, d, h, min).add(_offset);

/// Fecha de Bogotá de [instante] como `DateTime.utc(y, m, d)` — un "día"
/// en toda la agenda es siempre este valor.
DateTime diaBogota(DateTime instante) {
  final b = aBogota(instante);
  return DateTime.utc(b.year, b.month, b.day);
}

/// Rango UTC `[inicio, fin)` que cubre el día de Bogotá [dia].
({DateTime inicio, DateTime fin}) rangoDiaUtc(DateTime dia) => (
      inicio: deBogota(dia.year, dia.month, dia.day),
      fin: deBogota(dia.year, dia.month, dia.day + 1),
    );

/// Lunes de la semana (LUN-DOM) que contiene [dia].
DateTime lunesDeSemana(DateTime dia) {
  final d = DateTime.utc(dia.year, dia.month, dia.day);
  return DateTime.utc(d.year, d.month, d.day - (d.weekday - DateTime.monday));
}

/// Rango UTC `[inicio, fin)` de los 7 días de Bogotá desde [lunes].
({DateTime inicio, DateTime fin}) rangoSemanaUtc(DateTime lunes) => (
      inicio: deBogota(lunes.year, lunes.month, lunes.day),
      fin: deBogota(lunes.year, lunes.month, lunes.day + 7),
    );

/// `true` si [a] y [b] tienen el mismo año, mes y día (sus campos).
bool mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
