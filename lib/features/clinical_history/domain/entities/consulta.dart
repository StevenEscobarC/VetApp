/// Signos vitales del examen físico. Todos opcionales porque no todos
/// se toman en cada visita (ej. control telefónico o revisión rápida).
class ExamenFisico {
  const ExamenFisico({
    this.temperaturaC,
    this.pesoKg,
    this.frecuenciaCardiaca,
    this.frecuenciaRespiratoria,
    this.mucosas,
  });

  final double? temperaturaC;
  final double? pesoKg;
  final int? frecuenciaCardiaca;
  final int? frecuenciaRespiratoria;
  final String? mucosas;
}

/// Entrada de historia clínica. Sigue la estructura estándar usada por
/// veterinarios en Colombia: anamnesis, examen físico, diagnóstico,
/// tratamiento, evolución.
class Consulta {
  const Consulta({
    required this.id,
    required this.mascotaId,
    required this.veterinarioId,
    required this.fecha,
    required this.anamnesis,
    required this.examenFisico,
    required this.diagnostico,
    required this.tratamiento,
    this.evolucion,
    this.proximaCita,
    this.adjuntoUrls = const [],
  });

  final String id;
  final String mascotaId;
  final String veterinarioId;
  final DateTime fecha;
  final String anamnesis;
  final ExamenFisico examenFisico;
  final String diagnostico;
  final String tratamiento;
  final String? evolucion;
  final DateTime? proximaCita;
  final List<String> adjuntoUrls;
}
