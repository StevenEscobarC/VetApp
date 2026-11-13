import '../../../core/utils/formato.dart';
import '../../appointments/domain/whatsapp_recordatorio.dart';

/// Firma del cobro: 'Dr(a). Nombre, Clínica'; solo la clínica si no hay
/// nombre de veterinario, y solo el veterinario si no hay clínica.
String _firmaCobro(String veterinario, String clinica) {
  final vet = firmaVeterinario(veterinario);
  final c = clinica.trim();
  if (vet.isEmpty) return c;
  return c.isEmpty ? vet : '$vet, $c';
}

/// Texto formal (trato de "usted", D-16) que acompaña el PDF de una
/// cotización o cuenta de cobro al compartirlo por WhatsApp. Plantillas
/// fijas de UI-SPEC §4.3. Lleva solo nombre, número, valor, mascota y
/// fecha: nunca cédula ni teléfono (D-24), y nunca nombra el documento
/// como tributario (D-01), porque la app no emite documentos ante la DIAN.
String mensajeCobroWhatsApp({
  required String cliente,
  required String numero,
  required int totalCop,
  required String clinica,
  required String veterinario,
  String? mascota,
  required bool esCotizacion,
  bool pagada = false,
  DateTime? validaHasta,
}) {
  final firma = _firmaCobro(veterinario, clinica);
  final total = formatearCop(totalCop);
  final m = blancoANull(mascota);

  if (esCotizacion) {
    final para = m == null ? '' : ', para $m';
    final vigencia = validaHasta == null
        ? ''
        : ' Es válida hasta el ${formatearFecha(validaHasta)}.';
    return 'Hola, $cliente. Le compartimos la cotización $numero de $clinica '
        'por $total$para.$vigencia — $firma';
  }

  if (pagada) {
    return 'Hola, $cliente. Le compartimos la cuenta de cobro $numero de '
        '$clinica por $total, ya pagada. Gracias por su confianza. — $firma';
  }

  final atencion = m == null ? '' : ', por la atención de $m';
  return 'Hola, $cliente. Le compartimos la cuenta de cobro $numero de '
      '$clinica por $total$atencion. Quedamos atentos a su pago. — $firma';
}
