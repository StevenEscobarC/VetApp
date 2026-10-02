import '../../../core/utils/formato.dart';
import '../../../core/utils/formato_hora.dart';
import '../../../core/utils/zona_bogota.dart';
import 'codigo_invitacion.dart';

/// Código de invitación vigente de la clínica. [codigo] son 8 caracteres sin
/// guion; para mostrarlo usa [formatearCodigoInvitacion].
class Invitacion {
  const Invitacion({
    required this.id,
    required this.codigo,
    required this.expiraEn,
  });

  final String id;
  final String codigo;
  final DateTime expiraEn;
}

/// `Vence el 04/10/2026 · 3:15 p. m. (en 71 h)`, en hora de Bogotá. [ahora]
/// se inyecta (nunca se lee el reloj aquí). Menos de 1 h muestra minutos;
/// vencida devuelve `Vencida`.
String textoVigenciaInvitacion(DateTime expiraEn, DateTime ahora) {
  final restante = expiraEn.difference(ahora);
  if (restante <= Duration.zero) return 'Vencida';
  final b = aBogota(expiraEn);
  final cuando = '${formatearFecha(b)} · ${hora12(b)}';
  final en = restante.inHours >= 1
      ? '${restante.inHours} h'
      : '${restante.inMinutes} min';
  return 'Vence el $cuando (en $en)';
}

/// Mensaje fijo para compartir el código por chat.
String mensajeInvitacion({
  required String clinica,
  required String codigo,
  required DateTime expiraEn,
}) {
  final b = aBogota(expiraEn);
  return 'Hola, te invito a unirte a $clinica en VetApp. Regístrate como '
      'veterinario, elige «Tengo un código» e ingresa: '
      '${formatearCodigoInvitacion(codigo)}. El código vence el '
      '${formatearFecha(b)} a las ${hora12(b)} y sirve una sola vez.';
}
