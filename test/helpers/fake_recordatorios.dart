import 'package:vetapp/features/appointments/data/services/recordatorios_service.dart';
import 'package:vetapp/features/appointments/domain/recordatorios_plan.dart';

/// [RecordatoriosService] en memoria: registra llamadas y nunca toca el
/// plugin de notificaciones.
class FakeRecordatoriosService implements RecordatoriosService {
  bool permiso = true;
  int solicitudes = 0;
  int ajustesAbiertos = 0;
  final List<List<NotificacionPlan>> reprogramaciones = [];
  int cancelarTodoLlamadas = 0;
  String? lanzamiento;
  bool resultadoSolicitud = true;

  /// Si no es null, [permisoConcedido] espera este future (simula una
  /// sincronización en vuelo).
  Future<void>? retenerPermiso;

  void Function(String citaId)? _alTocar;

  /// Simula que el usuario toca un recordatorio.
  void simularToque(String citaId) => _alTocar?.call(citaId);

  @override
  Future<void> inicializar({
    required void Function(String citaId) alTocar,
  }) async {
    _alTocar = alTocar;
  }

  @override
  Future<bool> permisoConcedido() async {
    final retener = retenerPermiso;
    if (retener != null) await retener;
    return permiso;
  }

  @override
  Future<bool> solicitarPermiso() async {
    solicitudes++;
    if (resultadoSolicitud) permiso = true;
    return resultadoSolicitud;
  }

  @override
  Future<void> abrirAjustes() async => ajustesAbiertos++;

  @override
  Future<void> reprogramar(List<NotificacionPlan> planes) async =>
      reprogramaciones.add(List.of(planes));

  @override
  Future<void> cancelarTodo() async => cancelarTodoLlamadas++;

  @override
  Future<String?> citaIdDeLanzamiento() async => lanzamiento;
}
