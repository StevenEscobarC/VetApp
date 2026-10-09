import '../config/soporte_config.dart';

/// Mensaje neutro para soporte: solo nombre de la clínica, nombre de la app y
/// plan de interés. Nunca datos de pacientes, dueños ni veterinarios, y nunca
/// palabras de dinero.
String mensajeSoporte({required String clinica, required String planInteres}) =>
    'Hola, soy de la clínica "$clinica" ($kNombreApp). Quiero activar o '
    'cambiar el plan (interés: Plan $planInteres).';

/// Enlace `wa.me` hacia [numero] (solo dígitos) con [mensaje] precargado.
/// Usa `encodeComponent` y no el mapa de parámetros de `Uri`, que codifica el
/// espacio como `+` y WhatsApp lo muestra literal.
Uri enlaceSoporte(String numero, String mensaje) =>
    Uri.parse('https://wa.me/$numero?text=${Uri.encodeComponent(mensaje)}');

/// Número para mostrar: `+57 300 123 4567` para celulares colombianos y
/// `+dígitos` para cualquier otro.
String formatearSoporte(String numero) {
  if (numero.length == 12 && numero.startsWith('57')) {
    return '+57 ${numero.substring(2, 5)} ${numero.substring(5, 8)} '
        '${numero.substring(8)}';
  }
  return '+$numero';
}
