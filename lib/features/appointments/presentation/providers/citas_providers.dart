import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/supabase_client_provider.dart';
import '../../../../core/utils/zona_bogota.dart';
import '../../data/repositories/supabase_cita_repository.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clients/domain/entities/cliente.dart';
import '../../../clients/presentation/providers/clientes_providers.dart';
import '../../domain/entities/cita.dart';
import '../../domain/filtro_agenda.dart';

final citaRepositoryProvider = Provider<SupabaseCitaRepository>((ref) {
  return SupabaseCitaRepository(ref.watch(supabaseClientProvider));
});

/// Citas de la semana LUN-DOM que empieza en [lunes] (un `DateTime.utc` de
/// la fecha de Bogotá), ordenadas por hora ascendente. Solo RLS aísla por
/// clínica — no hay filtro de clínica en el cliente.
final agendaSemanaProvider = FutureProvider.autoDispose
    .family<List<Cita>, DateTime>((ref, lunes) async {
  final rango = rangoSemanaUtc(lunes);
  final citas = await ref
      .watch(citaRepositoryProvider)
      .entre(rango.inicio, rango.fin);
  return [...citas]..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
});

/// Una cita por id (detalle de cita).
final citaProvider = FutureProvider.autoDispose.family<Cita, String>((
  ref,
  id,
) {
  return ref.watch(citaRepositoryProvider).obtener(id);
});

/// Contador de "las citas cambiaron": se incrementa tras cada escritura
/// exitosa. Los proveedores de recordatorios locales lo escuchan para
/// resincronizarse (04-07).
class CitasRevision extends Notifier<int> {
  @override
  int build() => 0;

  void incrementar() => state++;
}

final citasRevisionProvider = NotifierProvider<CitasRevision, int>(
  CitasRevision.new,
);

/// Filtro de la agenda. `autoDispose` y sin persistencia: la agenda siempre
/// reabre en "Mías" (D-08).
class FiltroAgendaNotifier extends Notifier<FiltroAgenda> {
  @override
  FiltroAgenda build() => FiltroAgenda.mias;

  void set(FiltroAgenda filtro) => state = filtro;
}

final filtroAgendaProvider =
    NotifierProvider.autoDispose<FiltroAgendaNotifier, FiltroAgenda>(
      FiltroAgendaNotifier.new,
    );

/// Escrituras de citas. Guarda el [Ref] (no `WidgetRef`) y por eso
/// [citaActionsProvider] NO es `autoDispose` — mismo patrón que
/// `RegistrarConsulta`.
class CitaActions {
  CitaActions(this._ref);

  final Ref _ref;

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
    final id = await _ref
        .read(citaRepositoryProvider)
        .crear(
          clienteId: clienteId,
          mascotaIds: mascotaIds,
          fechaHora: fechaHora,
          duracionMin: duracionMin,
          modalidad: modalidad,
          direccion: direccion,
          motivo: motivo,
          notas: notas,
        );
    _ref.invalidate(agendaSemanaProvider);
    _ref.read(citasRevisionProvider.notifier).incrementar();
    return id;
  }

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
    await _ref
        .read(citaRepositoryProvider)
        .actualizar(
          citaId: citaId,
          mascotaIds: mascotaIds,
          fechaHora: fechaHora,
          duracionMin: duracionMin,
          modalidad: modalidad,
          direccion: direccion,
          motivo: motivo,
          notas: notas,
        );
    _refrescar(citaId);
    _ref.read(citasRevisionProvider.notifier).incrementar();
  }

  Future<void> cambiarEstado(String citaId, EstadoCita nuevo) async {
    await _ref.read(citaRepositoryProvider).cambiarEstado(citaId, nuevo);
    _refrescar(citaId);
    _ref.read(citasRevisionProvider.notifier).incrementar();
  }

  /// No incrementa la revisión: los recordatorios locales no dependen de esto.
  Future<void> marcarRecordatorioEnviado(
    String citaId,
    DateTime? enviadoAt,
  ) async {
    await _ref
        .read(citaRepositoryProvider)
        .marcarRecordatorioEnviado(citaId, enviadoAt);
    _refrescar(citaId);
  }

  void _refrescar(String citaId) {
    _ref.invalidate(agendaSemanaProvider);
    _ref.invalidate(citaProvider(citaId));
  }
}

final citaActionsProvider = Provider<CitaActions>((ref) => CitaActions(ref));

/// Búsqueda de clientes local al formulario de cita: así el query global de
/// `ClientesNotifier` (pestaña Clientes) no se muta. Usa el mismo
/// repositorio y la misma búsqueda sanitizada. La UI aplica el debounce.
final busquedaClientesCitaProvider = FutureProvider.autoDispose
    .family<List<Cliente>, String>((ref, query) async {
      if (query.trim().isEmpty) return [];
      final clinicaId = (await ref.watch(
        authProfileProvider.future,
      ))?.clinicaId;
      if (clinicaId == null) return [];
      return ref
          .watch(clienteRepositoryProvider)
          .buscar(query, clinicaId: clinicaId);
    });
