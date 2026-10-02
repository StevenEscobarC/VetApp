import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetapp/features/auth/data/repositories/supabase_auth_repository.dart';

void main() {
  group('datosRegistro', () {
    test('con código: solo codigo_invitacion, sin claves clinica_*', () {
      final d = datosRegistro(
        nombre: 'Ana',
        telefono: '300',
        rol: 'VETERINARIO',
        clinicaNombre: 'X',
        ciudad: 'Y',
        codigoInvitacion: 'k7mq-4p2x',
      );
      expect(d['codigo_invitacion'], 'K7MQ4P2X');
      expect(d.keys.where((k) => k.startsWith('clinica_')), isEmpty);
    });

    test('sin código conserva las claves actuales', () {
      final d = datosRegistro(
        nombre: ' Ana ',
        telefono: '300',
        rol: 'VETERINARIO',
        clinicaNombre: 'Patitas',
        ciudad: 'Cali',
        direccion: 'Calle 1',
        clinicaTelefono: '555',
      );
      expect(d['nombre'], 'Ana');
      expect(d['rol'], 'VETERINARIO');
      expect(d['clinica_nombre'], 'Patitas');
      expect(d['clinica_ciudad'], 'Cali');
      expect(d['clinica_direccion'], 'Calle 1');
      expect(d['clinica_telefono'], '555');
      expect(d.containsKey('codigo_invitacion'), isFalse);
    });

    test('nunca incluye claves que decide el servidor (T2)', () {
      final d = datosRegistro(
        nombre: 'Ana',
        telefono: '300',
        rol: 'VETERINARIO',
        clinicaNombre: 'X',
        codigoInvitacion: 'K7MQ4P2X',
      );
      for (final k in ['clinica_id', 'rol_clinica', 'activo', 'matricula']) {
        expect(d.containsKey(k), isFalse, reason: k);
      }
    });

    test('CLIENTE ignora el código', () {
      final d = datosRegistro(
        nombre: 'Ana',
        telefono: '300',
        rol: 'CLIENTE',
        codigoInvitacion: 'X',
      );
      expect(d.containsKey('codigo_invitacion'), isFalse);
    });
  });

  group('mensajeErrorAuth', () {
    const error = AuthException('Database error saving new user');

    test('con código mapea el 500 del trigger', () {
      expect(
        mensajeErrorAuth(error, conCodigo: true),
        'Ese código no es válido o ya venció. Pídele al administrador uno nuevo.',
      );
    });

    test('sin código devuelve el mensaje genérico', () {
      expect(
        mensajeErrorAuth(error),
        'No fue posible completar la solicitud. Intenta de nuevo.',
      );
    });

    test('mapeos existentes intactos', () {
      expect(
        mensajeErrorAuth(const AuthException('Invalid login credentials')),
        'Correo o contraseña incorrectos.',
      );
      expect(
        mensajeErrorAuth(const AuthException('User already registered')),
        'Ya existe una cuenta con este correo.',
      );
      expect(
        mensajeErrorAuth(const AuthException('Email not confirmed')),
        'Confirma tu correo electrónico antes de iniciar sesión.',
      );
    });
  });
}
