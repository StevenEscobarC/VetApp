import '../../../core/utils/formato_hora.dart';
import '../../../core/utils/zona_bogota.dart';
import 'entities/cita.dart';

/// Un recordatorio local ya resuelto: qué id de alarma, cuándo, y el texto.
/// El único dato identificador que viaja es [citaId] (sin teléfono ni
/// dirección) porque la bandeja del sistema no es un canal seguro.
class NotificacionPlan {
  const NotificacionPlan({
    required this.id,
    required this.citaId,
    required this.cuando,
    required this.titulo,
    required this.cuerpo,
  });

  final int id;
  final String citaId;
  final DateTime cuando;
  final String titulo;
  final String cuerpo;
}

/// Id de alarma estable derivado del uuid de la cita (FNV-1a 32 bits).
///
/// No se usa el hash nativo de String porque no es estable entre
/// ejecuciones: tras reiniciar la app el mismo uuid daría otro id y las
/// alarmas quedarían huérfanas o duplicadas.
int idNotificacion(String citaId) {
  var h = 0x811c9dc5;
  for (final c in citaId.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h & 0x7fffffff;
}

/// `Cita en 15 min` / `Cita en 1 hora` / `Cita en 2 horas`.
String tituloRecordatorio(int minutosAntes) {
  if (minutosAntes < 60) return 'Cita en $minutosAntes min';
  final h = minutosAntes ~/ 60;
  return h == 1 ? 'Cita en 1 hora' : 'Cita en $h horas';
}

/// `Luna — María Pérez a las 10:30 a. m.` (+ ` · A domicilio`).
String cuerpoRecordatorio(Cita cita) {
  final base =
      '${cita.nombresMascotas} — ${cita.clienteNombre} a las '
      '${hora12(aBogota(cita.fechaHora))}';
  return cita.modalidad == ModalidadCita.domicilio
      ? '$base · A domicilio'
      : base;
}

/// Recordatorios a programar: solo citas pendiente/confirmada cuyo aviso
/// ([minutosAntes] antes) cae después de [ahora] y dentro de [horizonte];
/// las [maximo] más tempranas, en orden ascendente.
List<NotificacionPlan> planificar(
  Iterable<Cita> citas,
  int minutosAntes,
  DateTime ahora, {
  Duration horizonte = const Duration(days: 30),
  int maximo = 60,
}) {
  final limite = ahora.add(horizonte);
  final planes = <NotificacionPlan>[];
  for (final c in citas) {
    if (c.estado != EstadoCita.pendiente &&
        c.estado != EstadoCita.confirmada) {
      continue;
    }
    final cuando = c.fechaHora.subtract(Duration(minutes: minutosAntes));
    if (!cuando.isAfter(ahora) || c.fechaHora.isAfter(limite)) continue;
    planes.add(
      NotificacionPlan(
        id: idNotificacion(c.id),
        citaId: c.id,
        cuando: cuando,
        titulo: tituloRecordatorio(minutosAntes),
        cuerpo: cuerpoRecordatorio(c),
      ),
    );
  }
  planes.sort((a, b) => a.cuando.compareTo(b.cuando));
  return planes.length > maximo ? planes.sublist(0, maximo) : planes;
}
