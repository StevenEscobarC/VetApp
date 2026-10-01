import 'package:vetapp/core/utils/zona_bogota.dart';
import 'package:vetapp/features/appointments/data/repositories/supabase_cita_repository.dart';
import 'package:vetapp/features/appointments/domain/cita_failure.dart';
import 'package:vetapp/features/appointments/domain/entities/cita.dart';

/// In-memory [SupabaseCitaRepository] stand-in so no test touches a real
/// Supabase client. [entre] filters by range but deliberately does NOT sort,
/// so tests prove the provider does the ordering. [consultasEntre] logs
/// every [entre] call.
class FakeCitaRepository implements SupabaseCitaRepository {
  FakeCitaRepository({List<Cita> citas = const [], this.error})
      : citas = List.of(citas);

  final List<Cita> citas;
  final Object? error;

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
