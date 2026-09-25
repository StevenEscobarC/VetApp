enum Especie { perro, gato, otro }

/// Etiquetas en español para [Especie] — usadas por el selector de chips
/// (nunca un campo de texto libre, per D-04) y por el filtro de especie en
/// `PacientesListScreen` (Plan 06).
extension EspecieLabels on Especie {
  String get etiqueta => switch (this) {
    Especie.perro => 'Perro',
    Especie.gato => 'Gato',
    Especie.otro => 'Otro',
  };

  String get etiquetaPlural => switch (this) {
    Especie.perro => 'Perros',
    Especie.gato => 'Gatos',
    Especie.otro => 'Otros',
  };
}

/// Convierte el valor crudo de la columna `especie` (texto libre en la BD)
/// a un [Especie] conocido — cualquier valor no reconocido cae en
/// [Especie.otro] en vez de lanzar.
Especie especieDesdeTexto(String raw) {
  final normalizado = raw.trim().toLowerCase();
  for (final especie in Especie.values) {
    if (especie.name == normalizado) return especie;
  }
  return Especie.otro;
}

/// Paciente (mascota), reconciliado contra `supabase/schema.sql`: pertenece
/// a un [Cliente] ([duenoId]) dentro de una clínica ([clinicaId]). El peso
/// NO es un campo aquí — vive como historial en `mascota_pesos` (PAT-05),
/// nunca como un valor mutable en esta entidad. [fotoPath] es la ruta del
/// objeto en el bucket privado `mascota-fotos`, nunca una URL firmada (las
/// URLs firmadas expiran; la ruta no).
class Mascota {
  const Mascota({
    required this.id,
    required this.duenoId,
    required this.clinicaId,
    required this.nombre,
    required this.especie,
    this.raza,
    this.fechaNacimiento,
    this.fotoPath,
    this.duenoNombre,
  });

  final String id;
  final String duenoId;
  final String clinicaId;
  final String nombre;
  final Especie especie;
  final String? raza;
  final DateTime? fechaNacimiento;
  final String? fotoPath;

  /// Nombre del dueño, presente solo cuando la consulta lo embebe (ej.
  /// `SupabaseMascotaRepository.porCliente`'s join con `clientes`).
  final String? duenoNombre;

  int? get edadEnAnios {
    if (fechaNacimiento == null) return null;
    final now = DateTime.now();
    var edad = now.year - fechaNacimiento!.year;
    if (now.month < fechaNacimiento!.month ||
        (now.month == fechaNacimiento!.month &&
            now.day < fechaNacimiento!.day)) {
      edad--;
    }
    return edad;
  }

  Mascota copyWith({
    String? nombre,
    Especie? especie,
    String? raza,
    DateTime? fechaNacimiento,
    String? fotoPath,
  }) => Mascota(
    id: id,
    duenoId: duenoId,
    clinicaId: clinicaId,
    nombre: nombre ?? this.nombre,
    especie: especie ?? this.especie,
    raza: raza ?? this.raza,
    fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
    fotoPath: fotoPath ?? this.fotoPath,
    duenoNombre: duenoNombre,
  );
}
