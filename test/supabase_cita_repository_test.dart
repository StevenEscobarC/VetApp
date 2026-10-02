import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetapp/features/appointments/data/repositories/supabase_cita_repository.dart';

PostgrestException _check(String mensaje) =>
    PostgrestException(message: mensaje, code: '23514');

void main() {
  group('mensajeErrorCita - reasignación', () {
    test('veterinario fuera de la clínica (23503)', () {
      expect(
        mensajeErrorCita(
          PostgrestException(
            message: 'Ese veterinario ya no está en tu clínica.',
            code: '23503',
          ),
        ),
        'Ese veterinario ya no está en tu clínica.',
      );
    });

    test('reasignar una cita cerrada (23514)', () {
      expect(
        mensajeErrorCita(
          _check('Solo se pueden reasignar citas pendientes o confirmadas.'),
        ),
        'Solo se pueden reasignar citas pendientes o confirmadas.',
      );
    });
  });

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

    test('transición de estado rechazada por el trigger', () {
      expect(
        mensajeErrorCita(
          _check('Cambio de estado no permitido: cancelada -> completada.'),
          estado: true,
        ),
        'Esta cita ya no puede cambiar a ese estado.',
      );
    });

    test('columnas fijas de la cita', () {
      expect(
        mensajeErrorCita(
          _check(
            'No se puede cambiar el cliente, la clínica ni el veterinario '
            'de una cita.',
          ),
        ),
        'No se puede cambiar el cliente de una cita.',
      );
    });

    test('mensaje desconocido cae en el genérico', () {
      expect(
        mensajeErrorCita(_check('otra cosa')),
        'Revisa los datos de la cita.',
      );
    });
  });

  group('citaDesdeFila', () {
    Map<String, dynamic> fila() => {
      'id': 'c1',
      'clinica_id': 'cli-1',
      'cliente_id': 'c-1',
      'veterinario_id': 'vet-2',
      'fecha_hora': '2026-09-30T15:30:00Z',
      'duracion_min': 30,
      'modalidad': 'consultorio',
      'motivo': 'Control',
      'estado': 'pendiente',
    };

    test('lee el nombre del embed veterinario', () {
      final c = citaDesdeFila({
        ...fila(),
        'veterinario': {'nombre': 'Luis Torres'},
      });
      expect(c.veterinarioNombre, 'Luis Torres');
    });

    test('sin embed el nombre es null', () {
      expect(citaDesdeFila(fila()).veterinarioNombre, isNull);
    });
  });
}
