import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/core/utils/formato.dart';

void main() {
  group('parsearFecha', () {
    test('formato válido dd/mm/aaaa', () {
      final resultado = parsearFecha('05/03/2021');
      expect(resultado.valor, DateTime(2021, 3, 5));
      expect(resultado.error, isNull);
    });

    test('formato ISO es rechazado', () {
      final resultado = parsearFecha('2021-03-05');
      expect(resultado.valor, isNull);
      expect(resultado.error, 'Usa el formato dd/mm/aaaa');
    });

    test('día inválido para el mes es rechazado', () {
      final resultado = parsearFecha('31/02/2020');
      expect(resultado.valor, isNull);
      expect(resultado.error, 'Usa el formato dd/mm/aaaa');
    });

    test('fecha futura es rechazada', () {
      final futura = DateTime.now().add(const Duration(days: 5));
      final resultado = parsearFecha(formatearFecha(futura));
      expect(resultado.valor, isNull);
      expect(resultado.error, 'La fecha no puede ser futura');
    });

    test('vacío no es error', () {
      final resultado = parsearFecha('');
      expect(resultado.valor, isNull);
      expect(resultado.error, isNull);
    });
  });

  group('parsearPeso', () {
    test('coma decimal', () {
      final resultado = parsearPeso('12,5');
      expect(resultado.valor, 12.5);
      expect(resultado.error, isNull);
    });

    test('punto decimal', () {
      final resultado = parsearPeso('12.5');
      expect(resultado.valor, 12.5);
      expect(resultado.error, isNull);
    });

    test('cero es inválido', () {
      final resultado = parsearPeso('0');
      expect(resultado.valor, isNull);
      expect(resultado.error, 'Ingresa un peso válido en kg');
    });

    test('texto no numérico es inválido', () {
      final resultado = parsearPeso('abc');
      expect(resultado.valor, isNull);
      expect(resultado.error, 'Ingresa un peso válido en kg');
    });

    test('vacío no es error', () {
      final resultado = parsearPeso('');
      expect(resultado.valor, isNull);
      expect(resultado.error, isNull);
    });
  });

  group('formatearFecha', () {
    test('formatea a dd/mm/aaaa', () {
      expect(formatearFecha(DateTime(2021, 3, 5)), '05/03/2021');
    });
  });

  group('formatearPeso', () {
    test('con decimales usa coma como separador', () {
      expect(formatearPeso(12.5), '12,5 kg');
    });

    test('entero sin decimales sobrantes', () {
      expect(formatearPeso(12), '12 kg');
    });
  });

  group('formatearEdad', () {
    test('0 años', () {
      expect(formatearEdad(0), 'Menos de 1 año');
    });

    test('1 año, singular', () {
      expect(formatearEdad(1), '1 año');
    });

    test('varios años, plural', () {
      expect(formatearEdad(3), '3 años');
    });

    test('null devuelve cadena vacía', () {
      expect(formatearEdad(null), '');
    });
  });
}
