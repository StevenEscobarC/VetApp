/// Normaliza texto de búsqueda libre antes de interpolarlo en un filtro
/// `.or()` de PostgREST. Elimina `,` y `(`/`)` — los delimitadores que
/// PostgREST usa para separar condiciones dentro de `.or()` — para que un
/// término de búsqueda que los contenga (ej. un apellido con paréntesis)
/// nunca rompa ni altere la consulta. Colapsa espacios repetidos y recorta
/// los extremos.
String sanitizarBusqueda(String raw) {
  final sinDelimitadores = raw.replaceAll(RegExp('[,()]'), ' ');
  return sinDelimitadores.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Construye el fragmento `.or()` de PostgREST combinando un `ilike`
/// case-insensitive por cada columna en [columnas], y opcionalmente un
/// `in.()` sobre [columnaIn]/[valoresIn] — usado por el filtro de dos pasos
/// de búsqueda de mascotas por dueño (columnas propias + ids de dueño ya
/// resueltos aparte). Devuelve `null` cuando la búsqueda saneada queda
/// vacía, para que el llamador omita `.or()` por completo en vez de mandar
/// un filtro vacío. Compartido entre Clientes (este plan) y Pacientes (Plan
/// 06) — no duplicar esta lógica en otro repositorio.
String? filtroOrIlike({
  required List<String> columnas,
  required String query,
  String? columnaIn,
  List<String> valoresIn = const [],
}) {
  final q = sanitizarBusqueda(query);
  if (q.isEmpty) return null;
  final partes = columnas.map((columna) => '$columna.ilike.%$q%').toList();
  if (columnaIn != null && valoresIn.isNotEmpty) {
    partes.add('$columnaIn.in.(${valoresIn.join(',')})');
  }
  return partes.join(',');
}
