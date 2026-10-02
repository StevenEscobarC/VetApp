import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/features/appointments/domain/entities/cita.dart';
import 'package:vetapp/features/appointments/domain/whatsapp_recordatorio.dart';

import 'helpers/fake_citas.dart';

const _rocky = MascotaDeCita(id: 'm-rocky', nombre: 'Rocky', especie: 'perro');
const _luna = MascotaDeCita(id: 'm-luna', nombre: 'Luna', especie: 'perro');
const _max = MascotaDeCita(id: 'm-max', nombre: 'Max', especie: 'gato');

void main() {
  group('firmaVeterinario', () {
    test('antepone Dr(a). y recorta', () {
      expect(firmaVeterinario('Laura Gómez'), 'Dr(a). Laura Gómez');
      expect(firmaVeterinario('  Laura Gómez '), 'Dr(a). Laura Gómez');
    });
    test('vacío si no hay nombre', () => expect(firmaVeterinario('  '), ''));
  });

  group('mensajeRecordatorio', () {
    test('consultorio', () {
      expect(
        mensajeRecordatorio(
          cita: citaLunaHoy,
          veterinario: 'Ana Ramírez',
          clinica: 'Clínica Patitas',
        ),
        'Hola María Pérez, le recordamos la cita de Luna el mié 30/09 a las '
        '10:30 a. m. en el consultorio. — Ana Ramírez, Clínica Patitas. '
        'Responda SÍ para confirmar.',
      );
    });

    test('domicilio con dos mascotas', () {
      expect(
        mensajeRecordatorio(
          cita: citaRockyLunaHoy,
          veterinario: 'Ana Ramírez',
          clinica: 'Clínica Patitas',
        ),
        'Hola María Pérez, le recordamos la cita de Rocky y Luna el mié 30/09 '
        'a las 3:00 p. m. a domicilio en Calle 10 # 20-30. — Ana Ramírez, '
        'Clínica Patitas. Responda SÍ para confirmar.',
      );
    });

    test('tres mascotas y clínica nula', () {
      final c = citaLunaHoy.copyWith(mascotas: [_luna, _rocky, _max]);
      final m = mensajeRecordatorio(cita: c, veterinario: 'Ana Ramírez');
      expect(m, contains('la cita de Luna, Rocky y Max el'));
      expect(m, endsWith('— Ana Ramírez. Responda SÍ para confirmar.'));
    });
  });

  group('URLs', () {
    test('whatsappUri codifica con %20 y caracteres especiales', () {
      final u = whatsappUri('573001234567', 'Hola María ¿SÍ? — # &').toString();
      expect(u, startsWith('https://wa.me/573001234567?text='));
      expect(u, isNot(contains('+')));
      expect(u, contains('%20'));
      for (final s in ['%C2%BF', 'S%C3%8D', '%E2%80%94', '%23', '%26']) {
        expect(u, contains(s));
      }
    });

    test('mapsUri', () {
      expect(
        mapsUri('Calle 10 # 20-30').toString(),
        'https://www.google.com/maps/dir/?api=1'
        '&destination=Calle%2010%20%23%2020-30',
      );
    });
  });

  group('estadoWhatsApp', () {
    const fijo = 'Este número parece un teléfono fijo; no se puede enviar '
        'WhatsApp.';
    test('celular e internacional habilitados', () {
      expect(estadoWhatsApp('300 123 4567'), (habilitado: true, motivo: null));
      expect(
        estadoWhatsApp('+1 415 555 0123'),
        (habilitado: true, motivo: null),
      );
    });
    test('fijo', () {
      expect(estadoWhatsApp('6012345678'), (habilitado: false, motivo: fijo));
      expect(estadoWhatsApp('2345678'), (habilitado: false, motivo: fijo));
    });
    test('vacío', () {
      expect(
        estadoWhatsApp(''),
        (habilitado: false, motivo: 'Este cliente no tiene teléfono.'),
      );
    });
  });
}
