import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/features/clinical_history/domain/autor_consulta.dart';
import 'package:vetapp/features/clinical_history/domain/entities/consulta.dart';

Consulta _c({bool? activo, String vetId = 'vet-1'}) => Consulta(
  id: 'c1',
  mascotaId: 'm1',
  veterinarioId: vetId,
  fecha: DateTime(2026, 1, 1),
  diagnostico: 'd',
  tratamiento: 't',
  veterinarioNombre: 'Laura Gómez',
  veterinarioActivo: activo,
);

void main() {
  group('debeMostrarAutor', () {
    test('multiVet siempre muestra', () {
      expect(
        debeMostrarAutor(
          _c(activo: true),
          multiVet: true,
          idsActivos: {'vet-1'},
        ),
        isTrue,
      );
    });
    test('un solo vet con autor miembro activo no muestra', () {
      expect(
        debeMostrarAutor(
          _c(activo: true),
          multiVet: false,
          idsActivos: {'vet-1'},
        ),
        isFalse,
      );
    });
    test('un solo vet con autor inactivo muestra', () {
      expect(
        debeMostrarAutor(
          _c(activo: false),
          multiVet: false,
          idsActivos: {'vet-1'},
        ),
        isTrue,
      );
    });
    test('un solo vet con autor fuera de idsActivos muestra', () {
      expect(
        debeMostrarAutor(
          _c(activo: true),
          multiVet: false,
          idsActivos: {'otro'},
        ),
        isTrue,
      );
    });
    test('idsActivos nulo con autor activo no fuerza la línea', () {
      expect(debeMostrarAutor(_c(activo: true), multiVet: false), isFalse);
    });
  });

  test('autorRetirado y autorEsMiembroActivo son complementarios', () {
    expect(autorRetirado(_c(activo: false), null), isTrue);
    expect(autorEsMiembroActivo(_c(activo: true), {'vet-1'}), isTrue);
    expect(autorRetirado(_c(activo: true), {'x'}), isTrue);
  });
}
