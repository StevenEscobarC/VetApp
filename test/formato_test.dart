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

  group('parsearNumeroPositivo', () {
    test('vacío no es error', () {
      final resultado = parsearNumeroPositivo('');
      expect(resultado.valor, isNull);
      expect(resultado.error, isNull);
    });

    test('coma decimal', () {
      final resultado = parsearNumeroPositivo('38,5');
      expect(resultado.valor, 38.5);
      expect(resultado.error, isNull);
    });

    test('punto decimal', () {
      final resultado = parsearNumeroPositivo('38.5');
      expect(resultado.valor, 38.5);
      expect(resultado.error, isNull);
    });

    test('texto no numérico es inválido', () {
      final resultado = parsearNumeroPositivo('abc');
      expect(resultado.valor, isNull);
      expect(resultado.error, 'Ingresa un valor numérico válido');
    });

    test('cero es inválido', () {
      final resultado = parsearNumeroPositivo('0');
      expect(resultado.valor, isNull);
      expect(resultado.error, 'Ingresa un valor numérico válido');
    });

    test('negativo es inválido', () {
      final resultado = parsearNumeroPositivo('-3');
      expect(resultado.valor, isNull);
      expect(resultado.error, 'Ingresa un valor numérico válido');
    });

    test('igual al máximo es inválido', () {
      final resultado = parsearNumeroPositivo('1000');
      expect(resultado.valor, isNull);
      expect(resultado.error, 'Ingresa un valor numérico válido');
    });

    test('entero: valor sin parte fraccionaria es válido', () {
      final resultado = parsearNumeroPositivo('90', entero: true);
      expect(resultado.valor, 90.0);
      expect(resultado.error, isNull);
    });

    test('entero: valor con parte fraccionaria es inválido', () {
      final resultado = parsearNumeroPositivo('90,5', entero: true);
      expect(resultado.valor, isNull);
      expect(resultado.error, 'Ingresa un valor numérico válido');
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

  group('COP y miles', () {
    test('formatearMiles agrupa con punto', () {
      expect(formatearMiles(0), '0');
      expect(formatearMiles(999), '999');
      expect(formatearMiles(1000), '1.000');
      expect(formatearMiles(85000), '85.000');
      expect(formatearMiles(1000000), '1.000.000');
      expect(formatearMiles(-1000), '-1.000');
    });

    test('formatearCop', () {
      expect(formatearCop(85000), r'$ 85.000');
      expect(formatearCop(0), r'$ 0');
    });

    test('parsearCop vacío', () {
      final r = parsearCop('  ');
      expect(r.valor, isNull);
      expect(r.error, isNull);
    });

    test('parsearCop acepta variantes enteras', () {
      for (final t in ['85000', '85.000', r'$ 85.000', r'$85.000']) {
        final r = parsearCop(t);
        expect(r.valor, 85000, reason: t);
        expect(r.error, isNull, reason: t);
      }
    });

    test('parsearCop rechaza coma y no dígitos', () {
      for (final t in ['85,5', '85.000,00', 'abc']) {
        final r = parsearCop(t);
        expect(r.valor, isNull, reason: t);
        expect(r.error, 'Usa pesos enteros, sin coma.', reason: t);
      }
    });

    test('parsearCop límite superior', () {
      expect(parsearCop('100000001').error, 'El valor es demasiado alto.');
      expect(parsearCop('100.000.000').valor, 100000000);
    });
  });

  group('parsearFecha permitirFuturo', () {
    test('por defecto rechaza futuro', () {
      expect(parsearFecha('31/12/2099').error, 'La fecha no puede ser futura');
    });

    test('permitirFuturo acepta futuro', () {
      final r = parsearFecha('31/12/2099', permitirFuturo: true);
      expect(r.valor, DateTime(2099, 12, 31));
      expect(r.error, isNull);
    });

    test('errores de formato iguales en ambos modos', () {
      expect(parsearFecha('2021-03-05', permitirFuturo: true).error,
          'Usa el formato dd/mm/aaaa');
      expect(parsearFecha('31/02/2099', permitirFuturo: true).error,
          'Usa el formato dd/mm/aaaa');
    });
  });
}
