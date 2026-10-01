import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/core/utils/zona_bogota.dart';

void main() {
  group('deBogota / aBogota', () {
    test('23:30 Bogotá es 04:30 UTC del día siguiente', () {
      final instante = deBogota(2026, 9, 30, 23, 30);
      expect(instante, DateTime.utc(2026, 10, 1, 4, 30));
      final b = aBogota(instante);
      expect(b.day, 30);
      expect(b.hour, 23);
      expect(b.minute, 30);
    });
  });

  group('diaBogota', () {
    test('04:30 UTC del 1 oct sigue siendo 30 sep en Bogotá (23:30)', () {
      expect(
        diaBogota(DateTime.utc(2026, 10, 1, 4, 30)),
        DateTime.utc(2026, 9, 30),
      );
    });

    test('05:15 UTC del 1 oct ya es 1 oct en Bogotá (00:15)', () {
      expect(
        diaBogota(DateTime.utc(2026, 10, 1, 5, 15)),
        DateTime.utc(2026, 10, 1),
      );
    });
  });

  group('rangoDiaUtc', () {
    test('un día Bogotá abarca 05:00 UTC a 05:00 UTC', () {
      final r = rangoDiaUtc(DateTime.utc(2026, 9, 30));
      expect(r.inicio, DateTime.utc(2026, 9, 30, 5));
      expect(r.fin, DateTime.utc(2026, 10, 1, 5));
    });

    test('normaliza fin de mes y fin de año', () {
      expect(
        rangoDiaUtc(DateTime.utc(2026, 12, 31)).fin,
        DateTime.utc(2027, 1, 1, 5),
      );
      expect(
        rangoDiaUtc(DateTime.utc(2026, 9, 30)).fin,
        DateTime.utc(2026, 10, 1, 5),
      );
    });
  });

  group('lunesDeSemana / rangoSemanaUtc', () {
    test('miércoles 30/09/2026 -> lunes 28/09', () {
      expect(
        lunesDeSemana(DateTime.utc(2026, 9, 30)),
        DateTime.utc(2026, 9, 28),
      );
    });

    test('un domingo pertenece al lunes anterior', () {
      expect(
        lunesDeSemana(DateTime.utc(2026, 10, 4)),
        DateTime.utc(2026, 9, 28),
      );
    });

    test('un lunes devuelve el mismo día', () {
      expect(
        lunesDeSemana(DateTime.utc(2026, 9, 28)),
        DateTime.utc(2026, 9, 28),
      );
    });

    test('rangoSemanaUtc abarca 7 días Bogotá', () {
      final r = rangoSemanaUtc(DateTime.utc(2026, 9, 28));
      expect(r.inicio, DateTime.utc(2026, 9, 28, 5));
      expect(r.fin, DateTime.utc(2026, 10, 5, 5));
    });
  });

  group('mismoDia', () {
    test('true para mismo y/m/d, false en otro caso', () {
      expect(
        mismoDia(DateTime.utc(2026, 9, 30), DateTime.utc(2026, 9, 30, 12)),
        isTrue,
      );
      expect(
        mismoDia(DateTime.utc(2026, 9, 30), DateTime.utc(2026, 10, 1)),
        isFalse,
      );
    });
  });
}
