enum EstadoCita { pendiente, confirmada, cancelada, completada }

/// Cita agendada. Referencia a cliente y mascota por id (evita duplicar
/// datos) para que la agenda pueda mostrarse sin cargar los documentos
/// completos.
class Cita {
  const Cita({
    required this.id,
    required this.veterinarioId,
    required this.clienteId,
    required this.mascotaId,
    required this.fechaHora,
    required this.motivo,
    this.estado = EstadoCita.pendiente,
    this.recordatorioEnviado = false,
  });

  final String id;
  final String veterinarioId;
  final String clienteId;
  final String mascotaId;
  final DateTime fechaHora;
  final String motivo;
  final EstadoCita estado;
  final bool recordatorioEnviado;

  Cita copyWith({
    DateTime? fechaHora,
    String? motivo,
    EstadoCita? estado,
    bool? recordatorioEnviado,
  }) {
    return Cita(
      id: id,
      veterinarioId: veterinarioId,
      clienteId: clienteId,
      mascotaId: mascotaId,
      fechaHora: fechaHora ?? this.fechaHora,
      motivo: motivo ?? this.motivo,
      estado: estado ?? this.estado,
      recordatorioEnviado: recordatorioEnviado ?? this.recordatorioEnviado,
    );
  }
}
