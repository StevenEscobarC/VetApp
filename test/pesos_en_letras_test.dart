import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/features/billing/domain/pesos_en_letras.dart';

void main() {
  void caso(int pesos, String esperado) {
    test('$pesos -> $esperado', () => expect(pesosEnLetras(pesos), esperado));
  }

  group('unidades y decenas', () {
    caso(0, 'cero pesos');
    caso(1, 'un peso');
    caso(2, 'dos pesos');
    caso(15, 'quince pesos');
    caso(16, 'dieciséis pesos');
    caso(21, 'veintiún pesos');
    caso(22, 'veintidós pesos');
    caso(30, 'treinta pesos');
    caso(31, 'treinta y un pesos');
  });

  group('centenas', () {
    caso(100, 'cien pesos');
    caso(101, 'ciento un pesos');
    caso(500, 'quinientos pesos');
    caso(999, 'novecientos noventa y nueve pesos');
  });

  group('miles', () {
    caso(1000, 'mil pesos');
    caso(1001, 'mil un pesos');
    caso(21000, 'veintiún mil pesos');
    caso(85000, 'ochenta y cinco mil pesos');
    caso(100000, 'cien mil pesos');
    caso(120000, 'ciento veinte mil pesos');
    caso(
      999999,
      'novecientos noventa y nueve mil novecientos noventa y nueve pesos',
    );
  });

  group('millones', () {
    caso(1000000, 'un millón de pesos');
    caso(2000000, 'dos millones de pesos');
    caso(1500000, 'un millón quinientos mil pesos');
    caso(3850000, 'tres millones ochocientos cincuenta mil pesos');
    caso(21000000, 'veintiún millones de pesos');
    caso(
      999999999,
      'novecientos noventa y nueve millones novecientos noventa y nueve mil '
          'novecientos noventa y nueve pesos',
    );
  });

  group('rango', () {
    test('-1 lanza ArgumentError', () {
      expect(() => pesosEnLetras(-1), throwsArgumentError);
    });
    test('1000000000 lanza ArgumentError', () {
      expect(() => pesosEnLetras(1000000000), throwsArgumentError);
    });
  });
}
