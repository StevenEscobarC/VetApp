import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:vetapp/features/team/domain/codigo_invitacion.dart';

void main() {
  test('normalizarCodigoInvitacion uppercases and strips non-alphanumerics', () {
    expect(normalizarCodigoInvitacion('k7mq-4p2x '), 'K7MQ4P2X');
  });

  test('formatearCodigoInvitacion inserts the dash after 4 chars', () {
    expect(formatearCodigoInvitacion('K7MQ4P2X'), 'K7MQ-4P2X');
    expect(formatearCodigoInvitacion('K7M'), 'K7M');
  });

  test('esCodigoInvitacionCompleto validates alphabet and length', () {
    expect(esCodigoInvitacionCompleto('K7MQ-4P2X'), isTrue);
    expect(esCodigoInvitacionCompleto('K7MQ-4P20'), isFalse);
    expect(esCodigoInvitacionCompleto('K7MQ-4PO2'), isFalse);
    expect(esCodigoInvitacionCompleto('K7MQ-4PI2'), isFalse);
    expect(esCodigoInvitacionCompleto('K7MQ-4PL2'), isFalse);
    expect(esCodigoInvitacionCompleto('K7MQ-4P12'), isFalse);
    expect(esCodigoInvitacionCompleto('K7MQ-4P2'), isFalse);
  });

  test('const AuthProfile without new fields keeps defaults', () {
    const p = AuthProfile(
      id: 'x',
      nombre: 'n',
      email: 'e',
      rol: 'VETERINARIO',
      telefono: '',
    );
    expect(p.activo, isTrue);
    expect(p.esAdmin, isFalse);
  });
}
