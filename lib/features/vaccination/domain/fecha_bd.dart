/// Interpreta una columna Postgres `date` (`yyyy-mm-dd`) como medianoche UTC.
/// Nunca `DateTime.parse` directo: evita corrimientos por zona horaria en
/// fechas sin hora (carné de vacunación).
DateTime fechaDeBd(String yyyyMmDd) {
  final p = yyyyMmDd.substring(0, 10).split('-');
  return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// Inverso de [fechaDeBd]: `yyyy-mm-dd` usando año/mes/día de [d] tal cual.
String fechaABd(DateTime d) {
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${dos(d.month)}-${dos(d.day)}';
}
