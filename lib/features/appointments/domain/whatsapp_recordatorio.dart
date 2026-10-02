import '../../../core/utils/formato_hora.dart';
import '../../../core/utils/telefono_co.dart';
import '../../../core/utils/zona_bogota.dart';
import 'entities/cita.dart';

/// Firma del veterinario asignado: 'Dr(a). {nombre}', o vacío si no hay
/// nombre. El prefijo vive solo aquí.
String firmaVeterinario(String nombre) {
  final n = nombre.trim();
  return n.isEmpty ? '' : 'Dr(a). $n';
}

/// Mensaje formal (D-14, trato de "usted") con plantilla fija; la plantilla
/// editable es una idea diferida.
String mensajeRecordatorio({
  required Cita cita,
  required String veterinario,
  String? clinica,
}) {
  final cuando = aBogota(cita.fechaHora);
  final dir = cita.direccion ?? '';
  final lugar = cita.modalidad == ModalidadCita.domicilio
      ? 'a domicilio en $dir'
      : 'en el consultorio';
  final firma = (clinica == null || clinica.isEmpty)
      ? veterinario
      : '$veterinario, $clinica';
  return 'Hola ${cita.clienteNombre}, le recordamos la cita de '
      '${cita.nombresMascotas} el ${diaCorto(cuando)} a las ${hora12(cuando)} '
      '$lugar. — $firma. Responda SÍ para confirmar.';
}

/// Enlace `wa.me`. Se usa `Uri.encodeComponent` y nunca `queryParameters`,
/// que emite `+` para los espacios.
Uri whatsappUri(String numero, String mensaje) =>
    Uri.parse('https://wa.me/$numero?text=${Uri.encodeComponent(mensaje)}');

/// Indicaciones de Google Maps hacia [direccion] sin pedir permiso de
/// ubicación (D-02).
Uri mapsUri(String direccion) => Uri.parse(
  'https://www.google.com/maps/dir/?api=1'
  '&destination=${Uri.encodeComponent(direccion)}',
);

/// Si se puede enviar WhatsApp a [telefono] y, si no, el motivo para mostrar.
({bool habilitado, String? motivo}) estadoWhatsApp(String telefono) {
  switch (normalizarTelefono(telefono).clase) {
    case ClaseTelefono.celularCo:
    case ClaseTelefono.internacional:
      return (habilitado: true, motivo: null);
    case ClaseTelefono.fijoCo:
    case ClaseTelefono.desconocido:
      return (
        habilitado: false,
        motivo:
            'Este número parece un teléfono fijo; no se puede enviar WhatsApp.',
      );
    case ClaseTelefono.vacio:
      return (habilitado: false, motivo: 'Este cliente no tiene teléfono.');
  }
}
