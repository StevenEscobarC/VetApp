import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/features/billing/domain/clave_idempotencia.dart';

void main() {
  final uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  test('cumple el formato UUID v4 (RFC 4122)', () {
    expect(generarClaveIdempotencia(), matches(uuidV4));
  });

  test('con semilla fija también cumple el formato', () {
    expect(generarClaveIdempotencia(Random(7)), matches(uuidV4));
  });

  test('1000 llamadas con el generador por defecto son distintas', () {
    final claves = {for (var i = 0; i < 1000; i++) generarClaveIdempotencia()};
    expect(claves.length, 1000);
    expect(claves.every(uuidV4.hasMatch), isTrue);
  });

  test('Random(42) dos veces da la misma clave (costura determinista)', () {
    expect(
      generarClaveIdempotencia(Random(42)),
      generarClaveIdempotencia(Random(42)),
    );
  });
}
