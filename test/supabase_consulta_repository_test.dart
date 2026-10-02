import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetapp/features/clinical_history/data/repositories/supabase_consulta_repository.dart';

void main() {
  group('consultaDesdeFila', () {
    final base = {
      'id': 'c1',
      'mascota_id': 'm1',
      'veterinario_id': 'v1',
      'fecha': '2026-01-01T10:00:00Z',
      'diagnostico': 'd',
      'tratamiento': 't',
    };
    test('lee el autor embebido', () {
      final c = consultaDesdeFila({
        ...base,
        'veterinario': {'nombre': 'Laura Gómez', 'activo': false},
      });
      expect(c.veterinarioNombre, 'Laura Gómez');
      expect(c.veterinarioActivo, isFalse);
    });
    test('sin embed deja los campos nulos', () {
      final c = consultaDesdeFila(base);
      expect(c.veterinarioNombre, isNull);
      expect(c.veterinarioActivo, isNull);
    });
  });

  group('mensajeErrorConsulta', () {
    test('cita que no admite consultas (23514)', () {
      expect(
        mensajeErrorConsulta(
          const PostgrestException(
            message:
                'Esta cita no admite consultas (está cancelada, no asistió o '
                'es solo una solicitud).',
            code: '23514',
          ),
        ),
        'Esta cita ya no admite consultas.',
      );
    });

    test('otro check_violation cae en el genérico de datos', () {
      expect(
        mensajeErrorConsulta(
          const PostgrestException(message: 'peso_kg', code: '23514'),
        ),
        'Revisa los datos ingresados.',
      );
    });

    test('mascota fuera de la cita (23503)', () {
      expect(
        mensajeErrorConsulta(
          const PostgrestException(
            message: 'La mascota no pertenece a esta cita.',
            code: '23503',
          ),
        ),
        'La mascota no pertenece a esta cita.',
      );
    });
  });
}
