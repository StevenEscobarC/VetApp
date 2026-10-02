import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/clock_provider.dart';
import '../../../../core/utils/lanzador_externo.dart';
import '../../../../core/utils/telefono_co.dart';
import '../../../../core/utils/zona_bogota.dart';
import '../../../appointments/domain/whatsapp_recordatorio.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/carne.dart';
import '../../domain/whatsapp_vacunas.dart';
import 'invalidar_vacunas.dart';
import 'vacuna_providers.dart';

/// Alertas de vacunas de toda la clínica (VAC-03), ya ordenadas por el
/// servidor y con las ventanas por tipo (D-11). Solo vive con la pantalla.
final vacunasPendientesProvider =
    FutureProvider.autoDispose<List<PendienteVacuna>>((ref) {
      return ref.watch(vacunaRepositoryProvider).pendientes();
    });

/// Conteos para la tarjeta de Inicio y el pie de "ocultas" (D-13).
final resumenVacunasProvider = FutureProvider.autoDispose<ResumenVacunas>((
  ref,
) {
  return ref.watch(vacunaRepositoryProvider).resumen();
});

/// Acciones sobre una alerta (D-12). No programa notificaciones push ni
/// locales (D-10).
final alertasActionsProvider = Provider<AlertasActions>(AlertasActions.new);

class AlertasActions {
  AlertasActions(this._ref);

  final Ref _ref;

  void _refrescar() => invalidarAlertasVacunas(_ref);

  /// Abre WhatsApp con el recordatorio formal. Solo si la app se abrió de
  /// verdad marca "recordatorio enviado" (VET-25); devuelve ese resultado.
  Future<bool> recordar(PendienteVacuna p) async {
    final numero = numeroWhatsApp(p.clienteTelefono);
    if (numero == null) return false;
    // Esperar el perfil: si aún carga, la firma saldría vacía.
    final perfil = await _ref.read(authProfileProvider.future);
    final mensaje = mensajeRecordatorioVacuna(
      dueno: p.clienteNombre,
      mascota: p.mascotaNombre,
      biologico: p.biologicoNombre,
      proximaFecha: p.proximaFecha,
      vencida: p.estado == EstadoCarne.vencida,
      veterinario: firmaVeterinario(perfil?.nombre ?? ''),
      clinica: perfil?.clinicaNombre,
    );
    final ok = await _ref
        .read(lanzadorExternoProvider)
        .abrirEnApp(whatsappUri(numero, mensaje));
    if (!ok) return false;
    await _ref
        .read(vacunaRepositoryProvider)
        .gestionarAlerta(
          dosisRefId: p.ultimaDosisId,
          accion: AccionAlerta.recordado,
        );
    _refrescar();
    return true;
  }

  Future<void> descartar(PendienteVacuna p, String motivo) async {
    await _ref
        .read(vacunaRepositoryProvider)
        .gestionarAlerta(
          dosisRefId: p.ultimaDosisId,
          accion: AccionAlerta.descartar,
          motivo: motivo,
        );
    _refrescar();
  }

  /// Devuelve la fecha hasta la que queda oculta (solo para el texto del
  /// snackbar; el servidor calcula la real).
  Future<DateTime> posponer(PendienteVacuna p, int dias) async {
    await _ref
        .read(vacunaRepositoryProvider)
        .gestionarAlerta(
          dosisRefId: p.ultimaDosisId,
          accion: AccionAlerta.posponer,
          dias: dias,
        );
    _refrescar();
    return diaBogota(_ref.read(clockProvider)()).add(Duration(days: dias));
  }

  Future<void> restaurar(PendienteVacuna p) async {
    await _ref
        .read(vacunaRepositoryProvider)
        .gestionarAlerta(
          dosisRefId: p.ultimaDosisId,
          accion: AccionAlerta.restaurar,
        );
    _refrescar();
  }
}
