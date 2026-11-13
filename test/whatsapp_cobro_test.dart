import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/features/billing/domain/whatsapp_cobro.dart';

void main() {
  String cc({String? mascota, bool pagada = false, String vet = 'Ana Ruiz'}) =>
      mensajeCobroWhatsApp(
        cliente: 'Laura Gómez',
        numero: 'CC-0012',
        totalCop: 120000,
        clinica: 'VetCare',
        veterinario: vet,
        mascota: mascota,
        esCotizacion: false,
        pagada: pagada,
      );

  String cot() => mensajeCobroWhatsApp(
    cliente: 'Laura Gómez',
    numero: 'COT-0004',
    totalCop: 450000,
    clinica: 'VetCare',
    veterinario: 'Ana Ruiz',
    mascota: 'Rocky',
    esCotizacion: true,
    validaHasta: DateTime(2026, 11, 28),
  );

  test('cuenta de cobro pendiente con mascota', () {
    expect(
      cc(mascota: 'Rocky'),
      'Hola, Laura Gómez. Le compartimos la cuenta de cobro CC-0012 de '
      'VetCare por \$ 120.000, por la atención de Rocky. Quedamos atentos a '
      'su pago. — Dr(a). Ana Ruiz, VetCare',
    );
  });

  test('cuenta de cobro pendiente sin mascota omite la cláusula', () {
    final m = cc();
    expect(
      m,
      'Hola, Laura Gómez. Le compartimos la cuenta de cobro CC-0012 de '
      'VetCare por \$ 120.000. Quedamos atentos a su pago. — Dr(a). Ana '
      'Ruiz, VetCare',
    );
    expect(m, isNot(contains('por la atención de')));
  });

  test('cuenta de cobro pagada', () {
    expect(
      cc(mascota: 'Rocky', pagada: true),
      'Hola, Laura Gómez. Le compartimos la cuenta de cobro CC-0012 de '
      'VetCare por \$ 120.000, ya pagada. Gracias por su confianza. — '
      'Dr(a). Ana Ruiz, VetCare',
    );
  });

  test('cotización', () {
    expect(
      cot(),
      'Hola, Laura Gómez. Le compartimos la cotización COT-0004 de VetCare '
      'por \$ 450.000, para Rocky. Es válida hasta el 28/11/2026. — Dr(a). '
      'Ana Ruiz, VetCare',
    );
  });

  test('sin nombre de veterinario la firma es solo la clínica', () {
    expect(cc(vet: '  '), endsWith('— VetCare'));
  });

  test('nunca dice factura, IVA ni DIAN', () {
    for (final m in [
      cc(),
      cc(mascota: 'Rocky'),
      cc(pagada: true),
      cot(),
      cc(vet: ''),
    ]) {
      expect(m.toLowerCase(), isNot(contains('factura')));
      expect(m, isNot(contains('IVA')));
      expect(m, isNot(contains('DIAN')));
    }
  });
}
