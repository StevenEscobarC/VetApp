import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/core/utils/whatsapp_soporte.dart';

void main() {
  test('mensajeSoporte is neutral and names clinic, app and plan', () {
    expect(
      mensajeSoporte(clinica: 'Clínica Sol', planInteres: 'Clínica'),
      'Hola, soy de la clínica "Clínica Sol" (VetApp). Quiero activar o '
      'cambiar el plan (interés: Plan Clínica).',
    );
  });

  test('enlaceSoporte encodes spaces as %20, never +', () {
    final uri = enlaceSoporte('573001234567', 'a b');
    expect(uri.toString(), 'https://wa.me/573001234567?text=a%20b');
    expect(uri.toString(), isNot(contains('+')));
  });

  test('enlaceSoporte encodes quotes and accents of the full message', () {
    final uri = enlaceSoporte(
      '573001234567',
      mensajeSoporte(clinica: 'Clínica Sol', planInteres: 'Pro'),
    );
    expect(uri.host, 'wa.me');
    expect(uri.path, '/573001234567');
    expect(uri.queryParameters['text'], contains('Plan Pro'));
    expect(uri.toString(), contains('Plan%20Pro'));
    expect(uri.toString(), contains('%22Cl%C3%ADnica%20Sol%22'));
  });

  test('formatearSoporte formats Colombian mobiles', () {
    expect(formatearSoporte('573001234567'), '+57 300 123 4567');
    expect(formatearSoporte('14155550100'), '+14155550100');
  });
}
