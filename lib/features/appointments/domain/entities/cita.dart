/// Estado de una [Cita]. `noAsistio` se serializa como `no_asistio`.
enum EstadoCita {
  pendiente,
  confirmada,
  completada,
  cancelada,
  noAsistio;

  /// Valor guardado en la columna `estado`.
  String get valor => switch (this) {
    EstadoCita.noAsistio => 'no_asistio',
    _ => name,
  };

  /// Defensivo (D-10): un valor desconocido o `solicitada` se trata como
  /// pendiente para que una fila inesperada nunca rompa la agenda.
  static EstadoCita desdeValor(String v) => switch (v) {
    'confirmada' => EstadoCita.confirmada,
    'completada' => EstadoCita.completada,
    'cancelada' => EstadoCita.cancelada,
    'no_asistio' => EstadoCita.noAsistio,
    _ => EstadoCita.pendiente,
  };

  /// Una cita terminal ya no admite cambios de estado.
  bool get esTerminal =>
      this == completada || this == cancelada || this == noAsistio;
}

/// Dónde se atiende la cita.
enum ModalidadCita {
  consultorio,
  domicilio;

  String get valor => name;

  static ModalidadCita desdeValor(String v) =>
      v == 'domicilio' ? ModalidadCita.domicilio : ModalidadCita.consultorio;
}

/// Mascota incluida en una [Cita] (una cita puede tener varias).
class MascotaDeCita {
  const MascotaDeCita({
    required this.id,
    required this.nombre,
    required this.especie,
    this.fotoPath,
  });

  final String id;
  final String nombre;
  final String especie;
  final String? fotoPath;
}

/// Cita agendada. Refleja la tabla `citas` más sus embeds (cliente,
/// mascotas, consultas ligadas). [fechaHora] es un instante UTC; se muestra
/// siempre a través de `aBogota`, nunca con la zona del dispositivo.
class Cita {
  const Cita({
    required this.id,
    required this.clinicaId,
    required this.clienteId,
    required this.veterinarioId,
    required this.fechaHora,
    required this.duracionMin,
    required this.modalidad,
    required this.motivo,
    required this.estado,
    required this.clienteNombre,
    required this.mascotas,
    this.direccion,
    this.notas,
    this.recordatorioEnviadoAt,
    this.clienteTelefono,
    this.clienteDireccion,
    this.mascotasConConsulta = const {},
    this.veterinarioNombre,
  });

  final String id;
  final String clinicaId;
  final String clienteId;
  final String veterinarioId;

  /// Nombre del veterinario asignado (embed de `perfiles`); sirve para firmar
  /// mensajes y marcar la cita en la agenda de equipo.
  final String? veterinarioNombre;
  final DateTime fechaHora;
  final int duracionMin;
  final ModalidadCita modalidad;
  final String? direccion;
  final String motivo;
  final String? notas;
  final EstadoCita estado;
  final DateTime? recordatorioEnviadoAt;
  final String clienteNombre;
  final String? clienteTelefono;
  final String? clienteDireccion;
  final List<MascotaDeCita> mascotas;

  /// Ids de mascotas que ya tienen una consulta ligada a esta cita.
  final Set<String> mascotasConConsulta;

  /// Instante en que termina la cita.
  DateTime get fin => fechaHora.add(Duration(minutes: duracionMin));

  /// `Luna` / `Luna y Rocky` / `Luna, Rocky y Max`.
  String get nombresMascotas {
    final n = mascotas.map((m) => m.nombre).toList();
    if (n.isEmpty) return '';
    if (n.length == 1) return n.first;
    return '${n.sublist(0, n.length - 1).join(', ')} y ${n.last}';
  }

  /// Igual que [nombresMascotas] hasta 2; con 3 o más: `Luna, Rocky y 1 más`.
  String get nombresMascotasCorto {
    final n = mascotas.map((m) => m.nombre).toList();
    if (n.length <= 2) return nombresMascotas;
    return '${n[0]}, ${n[1]} y ${n.length - 2} más';
  }

  Cita copyWith({
    String? veterinarioId,
    String? veterinarioNombre,
    DateTime? fechaHora,
    int? duracionMin,
    ModalidadCita? modalidad,
    String? direccion,
    String? motivo,
    String? notas,
    EstadoCita? estado,
    DateTime? recordatorioEnviadoAt,
    List<MascotaDeCita>? mascotas,
    Set<String>? mascotasConConsulta,
  }) {
    return Cita(
      id: id,
      clinicaId: clinicaId,
      clienteId: clienteId,
      veterinarioId: veterinarioId ?? this.veterinarioId,
      veterinarioNombre: veterinarioNombre ?? this.veterinarioNombre,
      fechaHora: fechaHora ?? this.fechaHora,
      duracionMin: duracionMin ?? this.duracionMin,
      modalidad: modalidad ?? this.modalidad,
      direccion: direccion ?? this.direccion,
      motivo: motivo ?? this.motivo,
      notas: notas ?? this.notas,
      estado: estado ?? this.estado,
      recordatorioEnviadoAt:
          recordatorioEnviadoAt ?? this.recordatorioEnviadoAt,
      clienteNombre: clienteNombre,
      clienteTelefono: clienteTelefono,
      clienteDireccion: clienteDireccion,
      mascotas: mascotas ?? this.mascotas,
      mascotasConConsulta: mascotasConConsulta ?? this.mascotasConConsulta,
    );
  }
}
