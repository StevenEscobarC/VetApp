import '../../../core/utils/formato.dart';

String _conClinica(String veterinario, String? clinica) =>
    (clinica == null || clinica.trim().isEmpty)
    ? veterinario
    : '$veterinario de ${clinica.trim()}';

/// Recordatorio formal (trato de "usted", D-12/D-17) de una próxima dosis o
/// de una vencida. [veterinario] es la firma ya construida
/// (`firmaVeterinario`).
String mensajeRecordatorioVacuna({
  required String dueno,
  required String mascota,
  required String biologico,
  required DateTime proximaFecha,
  required bool vencida,
  required String veterinario,
  String? clinica,
}) {
  final bio = biologico.toLowerCase();
  final fecha = formatearFecha(proximaFecha);
  final cuerpo = vencida
      ? '$mascota tenía programada su $bio el $fecha y ya está vencida.'
      : '$mascota tiene programada su $bio para el $fecha.';
  return 'Buen día, $dueno. Le escribe ${_conClinica(veterinario, clinica)}. '
      'Le recordamos que $cuerpo '
      'Si desea, podemos agendar una cita. Quedamos atentos.';
}

/// Mensaje de WhatsApp al dueño con el enlace del carné.
String mensajeCarneWhatsApp({
  required String dueno,
  required String mascota,
  required String url,
  required String veterinario,
  String? clinica,
}) {
  final firma = (clinica == null || clinica.trim().isEmpty)
      ? '$veterinario.'
      : '$veterinario, ${clinica.trim()}.';
  return 'Buen día, $dueno. Le compartimos el carné de vacunación de '
      '$mascota, siempre actualizado: $url. Cualquier duda, con gusto le '
      'ayudamos. $firma';
}

/// Texto para el menú genérico de compartir del sistema.
String mensajeCompartirCarne({required String mascota, required String url}) =>
    'Carné de vacunación de $mascota: $url';
