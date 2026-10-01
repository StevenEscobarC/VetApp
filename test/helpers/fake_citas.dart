import 'package:vetapp/core/utils/zona_bogota.dart';
import 'package:vetapp/features/appointments/data/repositories/supabase_cita_repository.dart';
import 'package:vetapp/features/appointments/domain/cita_failure.dart';
import 'package:vetapp/features/appointments/domain/entities/cita.dart';

/// In-memory [SupabaseCitaRepository] stand-in so no test touches a real
/// Supabase client. [entre] filters by range but deliberately does NOT sort,
/// so tests prove the provider does the ordering. [consultasEntre] logs
/// every [entre] call.
class FakeCitaRepository implements SupabaseCitaRepository {
  FakeCitaRepository({
    List<Cita> citas = const [],
    this.error,
    this.errorCrear,
    this.idResultado = 'cita-nueva',
  }) : citas = List.of(citas);

  final List<Cita> citas;
  final Object? error;
  final String idResultado;

  /// Si se establece, solo [crear] lo lanza (la lectura sigue funcionando).
  final Object? errorCrear;

  /// Cada llamada a [crear], en orden.
  final List<
    ({
      String clienteId,
      List<String> mascotaIds,
      DateTime fechaHora,
      int duracionMin,
      ModalidadCita modalidad,
      String direccion,
      String motivo,
      String notas,
    })
  >
  creadas = [];

  @override
  Future<String> crear({
    required String clienteId,
    required List<String> mascotaIds,
    required DateTime fechaHora,
    required int duracionMin,
    required ModalidadCita modalidad,
    required String direccion,
    required String motivo,
    required String notas,
  }) async {
    if (errorCrear != null) throw errorCrear!;
    if (error != null) throw error!;
    creadas.add((
      clienteId: clienteId,
      mascotaIds: mascotaIds,
      fechaHora: fechaHora,
      duracionMin: duracionMin,
      modalidad: modalidad,
      direccion: direccion,
      motivo: motivo,
      notas: notas,
    ));
    return idResultado;
  }

  /// Cada [cambiarEstado], en orden.
  final List<({String citaId, EstadoCita estado})> estadosCambiados = [];

  /// Cada [actualizar], en orden.
  final List<
    ({
      String citaId,
      List<String> mascotaIds,
      DateTime fechaHora,
      int duracionMin,
      ModalidadCita modalidad,
      String direccion,
      String motivo,
      String notas,
    })
  >
  actualizadas = [];

  /// Cada [marcarRecordatorioEnviado], en orden.
  final List<({String citaId, DateTime? enviadoAt})> recordatorios = [];

  int _indice(String id) {
    final i = citas.indexWhere((c) => c.id == id);
    if (i < 0) throw const CitaFailure('Esta cita ya no existe.');
    return i;
  }

  @override
  Future<void> cambiarEstado(String citaId, EstadoCita estado) async {
    if (error != null) throw error!;
    final i = _indice(citaId);
    estadosCambiados.add((citaId: citaId, estado: estado));
    citas[i] = citas[i].copyWith(estado: estado);
  }

  @override
  Future<void> actualizar({
    required String citaId,
    required List<String> mascotaIds,
    required DateTime fechaHora,
    required int duracionMin,
    required ModalidadCita modalidad,
    required String direccion,
    required String motivo,
    required String notas,
  }) async {
    if (error != null) throw error!;
    final i = _indice(citaId);
    actualizadas.add((
      citaId: citaId,
      mascotaIds: mascotaIds,
      fechaHora: fechaHora,
      duracionMin: duracionMin,
      modalidad: modalidad,
      direccion: direccion,
      motivo: motivo,
      notas: notas,
    ));
    citas[i] = citas[i].copyWith(
      fechaHora: fechaHora,
      duracionMin: duracionMin,
      modalidad: modalidad,
      direccion: direccion,
      motivo: motivo,
      notas: notas,
    );
  }

  @override
  Future<void> marcarRecordatorioEnviado(
    String citaId,
    DateTime? enviadoAt,
  ) async {
    if (error != null) throw error!;
    final i = _indice(citaId);
    recordatorios.add((citaId: citaId, enviadoAt: enviadoAt));
    final c = citas[i];
    // copyWith no puede volver a null: se reconstruye para deshacer.
    citas[i] = Cita(
      id: c.id,
      clinicaId: c.clinicaId,
      clienteId: c.clienteId,
      veterinarioId: c.veterinarioId,
      fechaHora: c.fechaHora,
      duracionMin: c.duracionMin,
      modalidad: c.modalidad,
      direccion: c.direccion,
      motivo: c.motivo,
      notas: c.notas,
      estado: c.estado,
      recordatorioEnviadoAt: enviadoAt,
      clienteNombre: c.clienteNombre,
      clienteTelefono: c.clienteTelefono,
      clienteDireccion: c.clienteDireccion,
      mascotas: c.mascotas,
      mascotasConConsulta: c.mascotasConConsulta,
    );
  }

  final List<({DateTime inicio, DateTime fin})> consultasEntre = [];

  @override
  Future<List<Cita>> entre(DateTime inicioUtc, DateTime finUtc) async {
    consultasEntre.add((inicio: inicioUtc, fin: finUtc));
    if (error != null) throw error!;
    return citas
        .where(
          (c) => !c.fechaHora.isBefore(inicioUtc) && c.fechaHora.isBefore(finUtc),
        )
        .toList();
  }

  @override
  Future<Cita> obtener(String id) async {
    if (error != null) throw error!;
    for (final c in citas) {
      if (c.id == id) return c;
    }
    throw const CitaFailure('Esta cita ya no existe.');
  }
}

const _luna = MascotaDeCita(id: 'm-luna', nombre: 'Luna', especie: 'perro');
const _rocky = MascotaDeCita(id: 'm-rocky', nombre: 'Rocky', especie: 'perro');
const _max = MascotaDeCita(id: 'm-max', nombre: 'Max', especie: 'gato');

/// 10:30 Bogotá, 30 min, pendiente, consultorio — mié 2026-09-30.
final citaLunaHoy = Cita(
  id: 'cita-1',
  clinicaId: 'cli-1',
  clienteId: 'c-maria',
  veterinarioId: 'vet-1',
  fechaHora: deBogota(2026, 9, 30, 10, 30),
  duracionMin: 30,
  modalidad: ModalidadCita.consultorio,
  motivo: 'Consulta general',
  estado: EstadoCita.pendiente,
  clienteNombre: 'María Pérez',
  clienteTelefono: '3001234567',
  mascotas: const [_luna],
);

/// 15:00 Bogotá, 60 min, confirmada, domicilio, dos mascotas.
final citaRockyLunaHoy = Cita(
  id: 'cita-2',
  clinicaId: 'cli-1',
  clienteId: 'c-maria',
  veterinarioId: 'vet-1',
  fechaHora: deBogota(2026, 9, 30, 15, 0),
  duracionMin: 60,
  modalidad: ModalidadCita.domicilio,
  direccion: 'Calle 10 # 20-30',
  motivo: 'Vacunación',
  estado: EstadoCita.confirmada,
  clienteNombre: 'María Pérez',
  clienteTelefono: '3001234567',
  mascotas: const [_rocky, _luna],
);

/// 12:00 Bogotá, cancelada.
final citaCanceladaHoy = Cita(
  id: 'cita-3',
  clinicaId: 'cli-1',
  clienteId: 'c-juan',
  veterinarioId: 'vet-1',
  fechaHora: deBogota(2026, 9, 30, 12, 0),
  duracionMin: 30,
  modalidad: ModalidadCita.consultorio,
  motivo: 'Control',
  estado: EstadoCita.cancelada,
  clienteNombre: 'Juan Gómez',
  clienteTelefono: '6012345678',
  mascotas: const [_max],
);

/// 23:30 Bogotá del 30/09 (= 04:30 UTC del 01/10): debe quedar en HOY.
final citaNocheBoundary = Cita(
  id: 'cita-4',
  clinicaId: 'cli-1',
  clienteId: 'c-juan',
  veterinarioId: 'vet-1',
  fechaHora: deBogota(2026, 9, 30, 23, 30),
  duracionMin: 30,
  modalidad: ModalidadCita.consultorio,
  motivo: 'Urgencia',
  estado: EstadoCita.pendiente,
  clienteNombre: 'Juan Gómez',
  mascotas: const [_max],
);

/// 09:00 Bogotá del jueves 2026-10-01.
final citaManana = Cita(
  id: 'cita-5',
  clinicaId: 'cli-1',
  clienteId: 'c-juan',
  veterinarioId: 'vet-1',
  fechaHora: deBogota(2026, 10, 1, 9, 0),
  duracionMin: 30,
  modalidad: ModalidadCita.consultorio,
  motivo: 'Control',
  estado: EstadoCita.pendiente,
  clienteNombre: 'Juan Gómez',
  mascotas: const [_max],
);

/// Las cinco fixtures, deliberadamente fuera de orden.
final List<Cita> citasSemanaFixture = [
  citaManana,
  citaRockyLunaHoy,
  citaNocheBoundary,
  citaCanceladaHoy,
  citaLunaHoy,
];
