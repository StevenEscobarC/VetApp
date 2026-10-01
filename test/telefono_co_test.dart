import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/core/utils/telefono_co.dart';

void main() {
  group('normalizarTelefono', () {
    test('celular colombiano en varias formas -> 573001234567', () {
      for (final raw in [
        '300 123 4567',
        '3001234567',
        '573001234567',
        '+57 300 123 4567',
        '0057 300 1234567',
      ]) {
        final r = normalizarTelefono(raw);
        expect(r.guardado, '573001234567', reason: raw);
        expect(r.clase, ClaseTelefono.celularCo, reason: raw);
        expect(r.formateado, '+57 300 123 4567', reason: raw);
      }
    });

    test('fijo colombiano', () {
      for (final raw in ['(601) 234 5678', '576012345678', '6012345678']) {
        final r = normalizarTelefono(raw);
        expect(r.guardado, '576012345678', reason: raw);
        expect(r.clase, ClaseTelefono.fijoCo, reason: raw);
        expect(r.formateado, '+57 601 234 5678', reason: raw);
      }
    });

    test('internacional conserva el +', () {
      for (final raw in ['+1 415 555 0123', '001 415 555 0123']) {
        final r = normalizarTelefono(raw);
        expect(r.guardado, '+14155550123', reason: raw);
        expect(r.clase, ClaseTelefono.internacional, reason: raw);
        expect(r.formateado, '+14155550123', reason: raw);
      }
    });

    test('desconocido conserva los dígitos tal cual', () {
      for (final raw in ['2345678', '30012345', '123456789']) {
        final r = normalizarTelefono(raw);
        expect(r.guardado, raw);
        expect(r.clase, ClaseTelefono.desconocido, reason: raw);
      }
    });

    test('vacío', () {
      for (final raw in ['', '   ']) {
        final r = normalizarTelefono(raw);
        expect(r.guardado, '');
        expect(r.clase, ClaseTelefono.vacio);
        expect(r.formateado, '');
      }
    });

    test('idempotente', () {
      for (final raw in [
        '300 123 4567',
        '3001234567',
        '573001234567',
        '+57 300 123 4567',
        '0057 300 1234567',
        '(601) 234 5678',
        '576012345678',
        '+1 415 555 0123',
        '001 415 555 0123',
        '2345678',
        '30012345',
        '123456789',
        '',
        '   ',
      ]) {
        final una = normalizarTelefono(raw).guardado;
        expect(normalizarTelefono(una).guardado, una, reason: raw);
      }
    });

    test('solo dígitos o +dígitos (sin inyección en URL)', () {
      final r = normalizarTelefono('300/123?x=1 4567#');
      expect(RegExp(r'^\+?\d*$').hasMatch(r.guardado), isTrue);
    });
  });

  group('requiereAvisoTelefono', () {
    test('true para fijo y desconocido; false para el resto', () {
      expect(requiereAvisoTelefono('6012345678'), isTrue);
      expect(requiereAvisoTelefono('2345678'), isTrue);
      expect(requiereAvisoTelefono('300 123 4567'), isFalse);
      expect(requiereAvisoTelefono('+1 415 555 0123'), isFalse);
      expect(requiereAvisoTelefono(''), isFalse);
    });
  });

  group('telefonoGuardable / telefonoSinDigitos', () {
    test('texto sin dígitos no es guardable', () {
      for (final raw in ['N/A', '---', 'abc', '  ']) {
        expect(telefonoGuardable(raw), isFalse, reason: raw);
      }
      expect(telefonoSinDigitos('N/A'), isTrue);
      expect(telefonoSinDigitos(''), isFalse);
      expect(telefonoGuardable('300 123 4567'), isTrue);
      expect(telefonoSinDigitos('2345678'), isFalse);
    });
  });

  group('numeroWhatsApp', () {
    test('celular, internacional y nulos', () {
      expect(numeroWhatsApp('300 123 4567'), '573001234567');
      expect(numeroWhatsApp('+1 415 555 0123'), '14155550123');
      expect(numeroWhatsApp('6012345678'), isNull);
      expect(numeroWhatsApp('2345678'), isNull);
      expect(numeroWhatsApp(''), isNull);
    });
  });
}
