/// Veterinario perteneciente a una clínica (fila de `perfiles` con rol
/// VETERINARIO). [rolClinica] es 'admin' o 'veterinario'; un miembro con
/// [activo] en `false` fue retirado pero se conserva por su historial.
class Miembro {
  const Miembro({
    required this.id,
    required this.nombre,
    required this.rolClinica,
    required this.activo,
    this.matricula,
    required this.createdAt,
  });

  final String id;
  final String nombre;
  final String rolClinica;
  final bool activo;
  final String? matricula;
  final DateTime createdAt;

  bool get esAdmin => rolClinica == 'admin';

  /// Primer nombre, usado en textos cortos ("Cita de Laura").
  String get nombrePila {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    return partes.first;
  }
}

/// Índice de color estable de [id] dentro de [ordenados] (ya ordenados por
/// `createdAt`): posición % 4, o 0 si no está en la lista.
int indiceColorVet(List<Miembro> ordenados, String id) {
  final pos = ordenados.indexWhere((m) => m.id == id);
  return pos < 0 ? 0 : pos % 4;
}
