/// Signos vitales del examen físico. Todos opcionales (D-03) — no todos se
/// toman en cada visita (ej. control telefónico o revisión rápida).
/// [pesoKg], si se llena, alimenta también `mascota_pesos` (D-02) vía la RPC
/// `registrar_consulta` — nunca un insert separado.
class ExamenFisico {
  const ExamenFisico({
    this.pesoKg,
    this.temperaturaC,
    this.frecuenciaCardiaca,
    this.frecuenciaRespiratoria,
    this.mucosas,
  });

  final double? pesoKg;
  final double? temperaturaC;
  final int? frecuenciaCardiaca;
  final int? frecuenciaRespiratoria;
  final String? mucosas;

  /// `true` cuando ningún signo vital fue registrado — usado por la
  /// pantalla/PDF para mostrar una sola línea "Sin registrar" en vez de
  /// cinco filas vacías.
  bool get estaVacio =>
      pesoKg == null &&
      temperaturaC == null &&
      frecuenciaCardiaca == null &&
      frecuenciaRespiratoria == null &&
      (mucosas == null || mucosas!.isEmpty);
}

/// Entrada de historia clínica (HIST-01/04) — append-only: sin `copyWith`,
/// a propósito, igual que [PesoRegistro] — no existe un caso de uso
/// legítimo para "editar" una consulta ya guardada; una corrección se
/// registra siempre como una consulta nueva (D-01). Solo [diagnostico] y
/// [tratamiento] son obligatorios (D-03) — si [anamnesis]/[evolucion]/
/// [examenFisico] quedan sin llenar al crear, permanecen así para siempre.
class Consulta {
  const Consulta({
    required this.id,
    required this.mascotaId,
    required this.veterinarioId,
    required this.fecha,
    required this.diagnostico,
    required this.tratamiento,
    this.anamnesis,
    this.examenFisico = const ExamenFisico(),
    this.evolucion,
  });

  final String id;
  final String mascotaId;
  final String veterinarioId;
  final DateTime fecha;
  final String diagnostico;
  final String tratamiento;
  final String? anamnesis;
  final ExamenFisico examenFisico;
  final String? evolucion;
}
