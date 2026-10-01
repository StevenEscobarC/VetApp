import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/data/clock_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/services/recordatorios_service.dart';
import '../../domain/recordatorios_plan.dart';
import 'citas_providers.dart';

/// Android usa el plugin; el resto de plataformas (escritorio, web, donde la
/// inicialización lanzaría) usa el no-op.
final recordatoriosServiceProvider = Provider<RecordatoriosService>((ref) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return LocalNotificationsRecordatorios(FlutterLocalNotificationsPlugin());
  }
  return RecordatoriosNoop();
});

final sharedPreferencesProvider = FutureProvider<SharedPreferences>(
  (ref) => SharedPreferences.getInstance(),
);

const _claveAnticipacion = 'recordatorio_minutos_antes';
const _anticipacionesValidas = [15, 30, 60, 120];

/// Minutos de anticipación del recordatorio (D-12): global, no por cita.
class AnticipacionRecordatorio extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    final guardado = prefs.getInt(_claveAnticipacion);
    return _anticipacionesValidas.contains(guardado) ? guardado! : 60;
  }

  Future<void> cambiar(int minutos) async {
    if (!_anticipacionesValidas.contains(minutos)) {
      throw ArgumentError.value(minutos, 'minutos', 'Valor no permitido');
    }
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setInt(_claveAnticipacion, minutos);
    state = AsyncData(minutos);
  }
}

final anticipacionRecordatorioProvider =
    AsyncNotifierProvider<AnticipacionRecordatorio, int>(
      AnticipacionRecordatorio.new,
    );

/// Si las notificaciones están permitidas; 04-10 lo invalida al volver a la
/// app y tras pedir el permiso.
final permisoNotificacionesProvider = FutureProvider<bool>(
  (ref) => ref.watch(recordatoriosServiceProvider).permisoConcedido(),
);

/// Qué hacer al tocar un recordatorio. Es un provider para que los tests lo
/// sustituyan sin necesidad de un router real.
final abrirCitaDesdeNotificacionProvider =
    Provider<void Function(String citaId)>((ref) {
      return (id) => ref.read(routerProvider).push('/agenda/$id');
    });

/// Mantiene la agenda del sistema sincronizada con Supabase: reprograma al
/// abrir/volver a la app, tras cambios de citas y de anticipación, y cancela
/// todo al cerrar sesión (los textos contienen nombres de clientes).
class RecordatoriosSync {
  RecordatoriosSync(this._ref) {
    final servicio = _ref.read(recordatoriosServiceProvider);
    unawaited(
      servicio.inicializar(
        alTocar: (id) => _ref.read(abrirCitaDesdeNotificacionProvider)(id),
      ),
    );

    _ref.listen(authProfileProvider, (previo, siguiente) {
      final perfil = siguiente.value;
      if (perfil == null) {
        if (previo?.value != null) {
          unawaited(_ref.read(recordatoriosServiceProvider).cancelarTodo());
        }
      } else if (perfil.esVeterinario) {
        unawaited(sincronizar());
      }
    });
    _ref.listen(citasRevisionProvider, (_, _) => unawaited(sincronizar()));
    _ref.listen(anticipacionRecordatorioProvider, (previo, siguiente) {
      if (previo?.hasValue == true &&
          siguiente.hasValue &&
          previo!.value != siguiente.value) {
        unawaited(sincronizar());
      }
    });

    final listener = AppLifecycleListener(
      onResume: () {
        _ref.invalidate(permisoNotificacionesProvider);
        unawaited(sincronizar());
      },
    );
    _ref.onDispose(listener.dispose);

    // Si el perfil aún carga, el listener de arriba sincroniza al llegar.
    if (_ref.read(authProfileProvider).value?.esVeterinario ?? false) {
      unawaited(sincronizar());
    }
  }

  final Ref _ref;
  Future<void>? _enCurso;
  bool _repetir = false;
  bool _lanzamientoAtendido = false;

  /// Reconstruye los recordatorios. Si ya hay una ejecución en curso pide
  /// una repetición y devuelve el mismo future (así quien espera ve el
  /// resultado final). Nunca lanza: los fallos se reintentan en el
  /// siguiente disparo.
  Future<void> sincronizar() {
    final actual = _enCurso;
    if (actual != null) {
      _repetir = true;
      return actual;
    }
    final f = _correr();
    _enCurso = f;
    return f;
  }

  Future<void> _correr() async {
    try {
      do {
        _repetir = false;
        await _una();
      } while (_repetir);
    } finally {
      _enCurso = null;
    }
  }

  Future<void> _una() async {
    try {
      final perfil = await _ref.read(authProfileProvider.future);
      if (perfil == null || !perfil.esVeterinario) return;

      final servicio = _ref.read(recordatoriosServiceProvider);
      if (!await servicio.permisoConcedido()) return;

      final minutos = await _ref.read(anticipacionRecordatorioProvider.future);
      final ahora = _ref.read(clockProvider)();
      final citas = await _ref
          .read(citaRepositoryProvider)
          .entre(ahora, ahora.add(const Duration(days: 30)));
      await servicio.reprogramar(planificar(citas, minutos, ahora));

      if (!_lanzamientoAtendido) {
        _lanzamientoAtendido = true;
        // El callback de respuesta no se dispara para la notificación que
        // abrió la app desde cerrada.
        final id = await servicio.citaIdDeLanzamiento();
        if (id != null) _ref.read(abrirCitaDesdeNotificacionProvider)(id);
      }
    } catch (_) {
      // Silencioso: se reintenta en el próximo disparo.
    }
  }
}

final recordatoriosSyncProvider = Provider<RecordatoriosSync>(
  RecordatoriosSync.new,
);
