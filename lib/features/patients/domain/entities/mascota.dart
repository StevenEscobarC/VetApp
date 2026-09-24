enum Especie { perro, gato, otro }

enum Sexo { macho, hembra }

/// Paciente (mascota). Pertenece a un [Cliente]; acumula el historial
/// de [Consulta] y [Vacuna] asociado por su id.
class Mascota {
  const Mascota({
    required this.id,
    required this.clienteId,
    required this.veterinarioId,
    required this.nombre,
    required this.especie,
    this.raza,
    this.fechaNacimiento,
    required this.sexo,
    this.pesoKg,
    this.color,
    this.fotoUrl,
    this.esterilizado = false,
  });

  final String id;
  final String clienteId;
  final String veterinarioId;
  final String nombre;
  final Especie especie;
  final String? raza;
  final DateTime? fechaNacimiento;
  final Sexo sexo;
  final double? pesoKg;
  final String? color;
  final String? fotoUrl;
  final bool esterilizado;

  int? get edadEnAnios {
    if (fechaNacimiento == null) return null;
    final now = DateTime.now();
    var edad = now.year - fechaNacimiento!.year;
    if (now.month < fechaNacimiento!.month ||
        (now.month == fechaNacimiento!.month && now.day < fechaNacimiento!.day)) {
      edad--;
    }
    return edad;
  }

  Mascota copyWith({
    String? nombre,
    Especie? especie,
    String? raza,
    DateTime? fechaNacimiento,
    Sexo? sexo,
    double? pesoKg,
    String? color,
    String? fotoUrl,
    bool? esterilizado,
  }) {
    return Mascota(
      id: id,
      clienteId: clienteId,
      veterinarioId: veterinarioId,
      nombre: nombre ?? this.nombre,
      especie: especie ?? this.especie,
      raza: raza ?? this.raza,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
      sexo: sexo ?? this.sexo,
      pesoKg: pesoKg ?? this.pesoKg,
      color: color ?? this.color,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      esterilizado: esterilizado ?? this.esterilizado,
    );
  }
}
