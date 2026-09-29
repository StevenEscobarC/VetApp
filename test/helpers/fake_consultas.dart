import 'package:vetapp/features/clinical_history/data/repositories/supabase_consulta_repository.dart';
import 'package:vetapp/features/clinical_history/domain/entities/consulta.dart';
import 'package:vetapp/features/patients/domain/entities/peso_registro.dart';

import 'fake_mascotas.dart';

/// In-memory [SupabaseConsultaRepository] stand-in so no test in this phase
/// touches a real Supabase client. Mirrors [FakeMascotaRepository]'s "fixed
/// data or fixed error + call log" shape. [registros] logs every
/// [registrarConsulta] call as a named-arg record so tests can assert
/// exactly-once-per-submit and null-not-empty-optionals behavior without
/// inspecting a real RPC payload.
///
/// [mascotas], when set, receives a [PesoRegistro] directly in its
/// `pesosPorMascota` map when [registrarConsulta] is called with a non-null
/// `pesoKg` — this simulates the `registrar_consulta` RPC's server-side
/// atomic insert into `mascota_pesos` (D-02) WITHOUT ever calling
/// [FakeMascotaRepository.registrarPeso], so `pesosRegistrados` stays empty
/// even when a consulta carries a weight.
class FakeConsultaRepository implements SupabaseConsultaRepository {
  FakeConsultaRepository({
    List<Consulta> consultas = const [],
    this.error,
    this.idResultado = 'con-nueva',
    this.mascotas,
  }) : consultas = List.of(consultas);

  final List<Consulta> consultas;
  final Object? error;
  final String idResultado;
  final FakeMascotaRepository? mascotas;

  /// Every call to [registrarConsulta], in call order.
  final List<
    ({
      String mascotaId,
      String diagnostico,
      String tratamiento,
      String? anamnesis,
      String? evolucion,
      double? pesoKg,
      double? temperaturaC,
      int? frecuenciaCardiaca,
      int? frecuenciaRespiratoria,
      String? mucosas,
    })
  >
  registros = [];

  /// Deliberately NOT sorted here — same reasoning as
  /// [FakeMascotaRepository.pesosPorMascota]'s comment: the fake returns the
  /// mascota's consultas exactly as seeded, so tests verify the
  /// screen/provider does the defensive sort, not the fake.
  @override
  Future<List<Consulta>> porMascota(String mascotaId) async {
    if (error != null) throw error!;
    return consultas.where((c) => c.mascotaId == mascotaId).toList();
  }

  @override
  Future<String> registrarConsulta({
    required String mascotaId,
    required String diagnostico,
    required String tratamiento,
    String? anamnesis,
    String? evolucion,
    double? pesoKg,
    double? temperaturaC,
    int? frecuenciaCardiaca,
    int? frecuenciaRespiratoria,
    String? mucosas,
  }) async {
    registros.add((
      mascotaId: mascotaId,
      diagnostico: diagnostico,
      tratamiento: tratamiento,
      anamnesis: anamnesis,
      evolucion: evolucion,
      pesoKg: pesoKg,
      temperaturaC: temperaturaC,
      frecuenciaCardiaca: frecuenciaCardiaca,
      frecuenciaRespiratoria: frecuenciaRespiratoria,
      mucosas: mucosas,
    ));
    if (error != null) throw error!;

    consultas.add(
      Consulta(
        id: idResultado,
        mascotaId: mascotaId,
        veterinarioId: 'vet-1',
        fecha: DateTime.now(),
        diagnostico: diagnostico,
        tratamiento: tratamiento,
        anamnesis: anamnesis,
        examenFisico: ExamenFisico(
          pesoKg: pesoKg,
          temperaturaC: temperaturaC,
          frecuenciaCardiaca: frecuenciaCardiaca,
          frecuenciaRespiratoria: frecuenciaRespiratoria,
          mucosas: mucosas,
        ),
        evolucion: evolucion,
      ),
    );

    final mascotasRepo = mascotas;
    if (pesoKg != null && mascotasRepo != null) {
      final lista = mascotasRepo.pesosPorMascota.putIfAbsent(
        mascotaId,
        () => [],
      );
      lista.add(
        PesoRegistro(
          id: 'p-consulta-${lista.length + 1}',
          mascotaId: mascotaId,
          pesoKg: pesoKg,
          registradoEn: DateTime.now(),
        ),
      );
    }

    return idResultado;
  }
}

/// Fixtures reused verbatim by later plans (03-04/03-05) — ids/fechas must
/// not change. Dates deliberately distinct from the weight fixtures in
/// mascota_detail_screen_test.dart. All belong to mascotaId 'm-1'.
/// `DateTime`'s default constructor is not `const`, so these fixtures can't
/// be `const` either — mirrors why `mascotaRocky` (fake_mascotas.dart) is
/// `const` (no `DateTime` field) while these need `final`.
final consultaOtitis = Consulta(
  id: 'con-1',
  mascotaId: 'm-1',
  veterinarioId: 'vet-1',
  fecha: DateTime(2026, 2, 20),
  diagnostico: 'Otitis externa',
  tratamiento: 'Gotas óticas cada 12 horas',
  anamnesis: 'Se rasca la oreja derecha',
  examenFisico: const ExamenFisico(
    pesoKg: 4.2,
    temperaturaC: 38.5,
    frecuenciaCardiaca: 90,
    frecuenciaRespiratoria: 24,
    mucosas: 'rosadas',
  ),
  evolucion: 'Mejoría a los 5 días',
);

final consultaGastro = Consulta(
  id: 'con-2',
  mascotaId: 'm-1',
  veterinarioId: 'vet-1',
  fecha: DateTime(2026, 8, 5),
  diagnostico: 'Gastroenteritis leve',
  tratamiento: 'Dieta blanda 3 días',
  anamnesis: 'Vómito desde ayer',
  examenFisico: const ExamenFisico(temperaturaC: 39.1),
);

final consultaControl = Consulta(
  id: 'con-3',
  mascotaId: 'm-1',
  veterinarioId: 'vet-1',
  fecha: DateTime(2026, 4, 12),
  diagnostico: 'Control general',
  tratamiento: 'Ninguno',
);

/// Unsorted on purpose (Feb, Aug, Apr) — same "fake never sorts" reasoning
/// as [FakeMascotaRepository.pesosPorMascota].
final consultasRocky = [consultaOtitis, consultaGastro, consultaControl];
