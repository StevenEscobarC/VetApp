import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/recordatorios_plan.dart';

/// Recordatorios locales de citas. Supabase es la fuente de verdad; la
/// agenda del sistema operativo es una caché derivada que [reprogramar]
/// reconstruye siempre empezando por cancelar todo (seguro: esta app no
/// programa ninguna otra notificación).
abstract class RecordatoriosService {
  /// Prepara el plugin y registra [alTocar], llamado con el id de la cita
  /// cuando el usuario toca un recordatorio.
  Future<void> inicializar({required void Function(String citaId) alTocar});

  /// `true` si las notificaciones están permitidas ahora mismo.
  Future<bool> permisoConcedido();

  /// Pide el permiso del sistema; devuelve si quedó concedido.
  Future<bool> solicitarPermiso();

  /// Abre los ajustes de notificaciones de la app.
  Future<void> abrirAjustes();

  /// Reemplaza todo lo programado por [planes] (idempotente).
  Future<void> reprogramar(List<NotificacionPlan> planes);

  /// Cancela todo lo programado (cierre de sesión).
  Future<void> cancelarTodo();

  /// Id de cita del recordatorio que abrió la app desde cerrada, si lo hubo.
  Future<String?> citaIdDeLanzamiento();
}

const _zona = 'America/Bogota';

/// Implementación con `flutter_local_notifications` (solo Android).
///
/// Alarmas inexactas con permiso mínimo (sin SCHEDULE_EXACT_ALARM) y
/// visibilidad privada: la pantalla de bloqueo no muestra nombres de
/// clientes. El payload es solo el id de la cita.
class LocalNotificationsRecordatorios implements RecordatoriosService {
  LocalNotificationsRecordatorios(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  bool _inicializado = false;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> inicializar({
    required void Function(String citaId) alTocar,
  }) async {
    if (_inicializado) return;
    try {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation(_zona));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (r) {
          final id = r.payload;
          if (id != null && id.isNotEmpty) alTocar(id);
        },
      );
      _inicializado = true;
    } catch (_) {
      // Reintento silencioso en el próximo disparo.
    }
  }

  @override
  Future<bool> permisoConcedido() async {
    try {
      return await _android?.areNotificationsEnabled() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> solicitarPermiso() async {
    try {
      return await _android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> abrirAjustes() async {
    try {
      await _android?.openAppNotificationSettings();
    } catch (_) {}
  }

  @override
  Future<void> reprogramar(List<NotificacionPlan> planes) async {
    try {
      await _plugin.cancelAll();
      final zona = tz.getLocation(_zona);
      const detalles = NotificationDetails(
        android: AndroidNotificationDetails(
          'citas',
          'Recordatorios de citas',
          importance: Importance.high,
          priority: Priority.high,
          visibility: NotificationVisibility.private,
        ),
      );
      for (final plan in planes) {
        await _plugin.zonedSchedule(
          id: plan.id,
          scheduledDate: tz.TZDateTime.from(plan.cuando, zona),
          notificationDetails: detalles,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: plan.titulo,
          body: plan.cuerpo,
          payload: plan.citaId,
        );
      }
    } catch (_) {
      // Silencioso: se reintenta en el próximo disparo.
    }
  }

  @override
  Future<void> cancelarTodo() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  @override
  Future<String?> citaIdDeLanzamiento() async {
    try {
      final d = await _plugin.getNotificationAppLaunchDetails();
      if (d != null && d.didNotificationLaunchApp) {
        return d.notificationResponse?.payload;
      }
    } catch (_) {}
    return null;
  }
}

/// Para escritorio/web y pruebas: nunca toca el plugin.
class RecordatoriosNoop implements RecordatoriosService {
  @override
  Future<void> inicializar({
    required void Function(String citaId) alTocar,
  }) async {}

  @override
  Future<bool> permisoConcedido() async => false;

  @override
  Future<bool> solicitarPermiso() async => false;

  @override
  Future<void> abrirAjustes() async {}

  @override
  Future<void> reprogramar(List<NotificacionPlan> planes) async {}

  @override
  Future<void> cancelarTodo() async {}

  @override
  Future<String?> citaIdDeLanzamiento() async => null;
}
