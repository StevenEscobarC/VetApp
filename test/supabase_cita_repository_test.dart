import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetapp/features/appointments/data/repositories/supabase_cita_repository.dart';

PostgrestException _check(String mensaje) =>
    PostgrestException(message: mensaje, code: '23514');

void main() {
  group('mensajeErrorCita - check_violation (23514)', () {
    test('quitar una mascota con consulta no se confunde con "elige una"', () {
      expect(
        mensajeErrorCita(
          _check(
            'No puedes quitar una mascota que ya tiene consulta registrada '
            'en esta cita.',
          ),
        ),
        'No puedes quitar una mascota que ya tiene consulta registrada en '
        'esta cita.',
      );
    });

    test('sin mascotas pide elegir al menos una', () {
      expect(
        mensajeErrorCita(_check('Elige al menos una mascota.')),
        'Elige al menos una mascota.',
      );
    });

    test('domicilio sin dirección', () {
      expect(
        mensajeErrorCita(_check('citas_domicilio_direccion')),
        'Escribe la dirección para la visita a domicilio.',
      );
    });

    test('cita terminal no editable', () {
      expect(
        mensajeErrorCita(
          _check('Solo se pueden editar citas pendientes o confirmadas.'),
        ),
        'Solo se pueden editar citas pendientes o confirmadas.',
      );
    });

    test('mensaje desconocido cae en el genérico', () {
      expect(
        mensajeErrorCita(_check('otra cosa')),
        'Revisa los datos de la cita.',
      );
    });
  });
}
