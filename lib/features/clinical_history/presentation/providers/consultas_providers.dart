import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/supabase_client_provider.dart';
import '../../../../core/utils/formato.dart';
import '../../../appointments/presentation/providers/citas_providers.dart';
import '../../../patients/presentation/providers/mascotas_providers.dart';
import '../../data/repositories/supabase_consulta_repository.dart';
import '../../domain/entities/consulta.dart';

final consultaRepositoryProvider = Provider<SupabaseConsultaRepository>((
  ref,
) {
  return SupabaseConsultaRepository(ref.watch(supabaseClientProvider));
});

/// Historia clínica de una mascota (HIST-02), más reciente primero —
/// consumido por `HistoriaClinicaTimeline`. `autoDispose.family` — solo
/// vive mientras la ficha está montada.
final consultasProvider = FutureProvider.autoDispose.family<List<Consulta>, String>((
  ref,
  mascotaId,
) {
  return ref.watch(consultaRepositoryProvider).porMascota(mascotaId);
});

/// Registra una consulta nueva (HIST-01) — una sola llamada al
/// repositorio, seguida de la invalidación de todos los providers cuyo
/// dato subyacente cambió. Verbo-frase sin sufijo `UseCase`, por
/// convención (`SignInWithEmail`, etc.).
///
/// Guarda el [Ref] del provider (no `WidgetRef`) para poder invalidar
/// después de que `call` resuelva — de ahí que [registrarConsultaProvider]
/// NO sea `autoDispose`: el `Ref` almacenado debe seguir siendo válido
/// mientras el formulario esté enviando.
class RegistrarConsulta {
  RegistrarConsulta(this._ref);

  final Ref _ref;

  /// Recorta los campos requeridos y convierte cualquier opcional en
  /// blanco a `null` (nunca `''`, D-03) antes de llamar al repositorio
  /// exactamente una vez. Cuando [pesoKg] no es `null`, esa misma llamada
  /// alimenta `mascota_pesos` (D-02) — por eso, y solo en ese caso, también
  /// se invalida `pesosProvider` (Pitfall 3), además de siempre invalidar
  /// `consultasProvider`.
  Future<String> call({
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
    String? citaId,
  }) async {
    final id = await _ref.read(consultaRepositoryProvider).registrarConsulta(
      mascotaId: mascotaId,
      diagnostico: diagnostico.trim(),
      tratamiento: tratamiento.trim(),
      anamnesis: blancoANull(anamnesis),
      evolucion: blancoANull(evolucion),
      pesoKg: pesoKg,
      temperaturaC: temperaturaC,
      frecuenciaCardiaca: frecuenciaCardiaca,
      frecuenciaRespiratoria: frecuenciaRespiratoria,
      mucosas: blancoANull(mucosas),
      citaId: citaId,
    );
    _ref.invalidate(consultasProvider(mascotaId));
    if (pesoKg != null) {
      _ref.invalidate(pesosProvider(mascotaId));
    }
    if (citaId != null) {
      _ref.invalidate(citaProvider(citaId));
      _ref.invalidate(agendaSemanaProvider);
    }
    return id;
  }
}

final registrarConsultaProvider = Provider<RegistrarConsulta>(
  (ref) => RegistrarConsulta(ref),
);
