import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/core/utils/formato_hora.dart';

DateTime t(int h, int m) => DateTime.utc(2026, 9, 30, h, m);

void main() {
  group('hora12', () {
    test('formatos a. m. / p. m.', () {
      expect(hora12(t(10, 30)), '10:30 a. m.');
      expect(hora12(t(12, 0)), '12:00 p. m.');
      expect(hora12(t(0, 15)), '12:15 a. m.');
      expect(hora12(t(18, 5)), '6:05 p. m.');
    });

    test('sin espacios no separables', () {
      final s = hora12(t(10, 30));
      expect(s.contains(' '), isFalse);
      expect(s.contains(' '), isFalse);
    });
  });

  group('días y fechas', () {
    final miercoles = DateTime.utc(2026, 9, 30);
    test('diaAbrev', () {
      expect(diaAbrev(DateTime.utc(2026, 9, 28)), 'LUN');
      expect(diaAbrev(DateTime.utc(2026, 9, 29)), 'MAR');
      expect(diaAbrev(miercoles), 'MIÉ');
      expect(diaAbrev(DateTime.utc(2026, 10, 1)), 'JUE');
      expect(diaAbrev(DateTime.utc(2026, 10, 2)), 'VIE');
      expect(diaAbrev(DateTime.utc(2026, 10, 3)), 'SÁB');
      expect(diaAbrev(DateTime.utc(2026, 10, 4)), 'DOM');
    });

    test('diaCorto y fechaLarga', () {
      expect(diaCorto(miercoles), 'mié 30/09');
      expect(fechaLarga(miercoles), 'mié 30/09/2026');
    });

    test('nombreDiaLargo', () {
      expect(nombreDiaLargo(DateTime.utc(2026, 9, 28)), 'Lunes');
      expect(nombreDiaLargo(DateTime.utc(2026, 10, 4)), 'Domingo');
    });

    test('rangoSemanaTexto', () {
      expect(rangoSemanaTexto(DateTime.utc(2026, 9, 28)), '28 sep – 4 oct');
      expect(rangoSemanaTexto(DateTime.utc(2026, 10, 5)), '5 – 11 oct');
    });

    test('encabezadoDia', () {
      final hoy = DateTime.utc(2026, 9, 30);
      expect(encabezadoDia(hoy, hoy), 'Hoy, mié 30/09');
      expect(encabezadoDia(DateTime.utc(2026, 10, 1), hoy), 'Mañana, jue 01/10');
      expect(encabezadoDia(DateTime.utc(2026, 10, 2), hoy), 'vie 02/10');
    });

    test('fechaHoraCorta', () {
      expect(fechaHoraCorta(DateTime.utc(2026, 9, 29, 18, 15)), '29/09 6:15 p. m.');
    });
  });

  group('rangos y duraciones', () {
    test('rangoHoras', () {
      expect(rangoHoras(t(10, 30), t(11, 0)), '10:30 – 11:00 a. m.');
      expect(rangoHoras(t(11, 30), t(12, 30)), '11:30 a. m. – 12:30 p. m.');
    });

    test('duracionTexto', () {
      expect(duracionTexto(15), '15 min');
      expect(duracionTexto(60), '1 h');
      expect(duracionTexto(90), '1 h 30 min');
      expect(duracionTexto(120), '2 h');
    });

    test('conteoCitas', () {
      expect(conteoCitas(0), 'Sin citas');
      expect(conteoCitas(1), '1 cita');
      expect(conteoCitas(4), '4 citas');
    });

    test('enCuanto', () {
      expect(enCuanto(const Duration(minutes: 25)), 'en 25 min');
      expect(enCuanto(const Duration(minutes: 60)), 'en 1 h');
      expect(enCuanto(const Duration(minutes: 70)), 'en 1 h 10 min');
    });
  });
}
