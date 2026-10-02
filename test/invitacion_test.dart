import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/team/domain/invitacion.dart';
import 'package:vetapp/features/team/presentation/providers/team_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_team.dart';

void main() {
  // 2026-10-04 20:15 UTC = 3:15 p. m. en Bogotá.
  final expira = DateTime.utc(2026, 10, 4, 20, 15);

  test('vigencia muestra fecha y hora de Bogotá y horas restantes', () {
    final ahora = expira.subtract(const Duration(hours: 71, minutes: 30));
    expect(
      textoVigenciaInvitacion(expira, ahora),
      'Vence el 04/10/2026 · 3:15 p. m. (en 71 h)',
    );
  });

  test('menos de una hora muestra minutos', () {
    final ahora = expira.subtract(const Duration(minutes: 45));
    expect(
      textoVigenciaInvitacion(expira, ahora),
      'Vence el 04/10/2026 · 3:15 p. m. (en 45 min)',
    );
  });

  test('vencida', () {
    expect(textoVigenciaInvitacion(expira, expira), 'Vencida');
  });

  test('mensajeInvitacion usa el texto fijo con código formateado', () {
    expect(
      mensajeInvitacion(
        clinica: 'Clínica Patitas',
        codigo: 'K7MQ4P2X',
        expiraEn: expira,
      ),
      'Hola, te invito a unirte a Clínica Patitas en VetApp. Regístrate como '
      'veterinario, elige «Tengo un código» e ingresa: K7MQ-4P2X. El código '
      'vence el 04/10/2026 a las 3:15 p. m. y sirve una sola vez.',
    );
  });

  ProviderContainer container(FakeTeamRepository repo, {required bool admin}) {
    final c = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        authProfileProvider.overrideWith(
          () => FakeAuthProfileNotifier(
            profile: admin ? vetAdminProfile : vetColegaProfile,
          ),
        ),
        teamRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('no admin: null sin llamar al repositorio', () async {
    final repo = FakeTeamRepository()..invitacion = invitacionFixture;
    final c = container(repo, admin: false);
    expect(await c.read(invitacionVigenteProvider.future), isNull);
    expect(repo.llamadas, 0);
  });

  test('generarInvitacion invalida el provider', () async {
    final repo = FakeTeamRepository();
    final c = container(repo, admin: true);
    final sub = c.listen(invitacionVigenteProvider, (_, _) {});
    addTearDown(sub.close);
    expect(await c.read(invitacionVigenteProvider.future), isNull);
    await c.read(teamActionsProvider).generarInvitacion();
    final inv = await c.read(invitacionVigenteProvider.future);
    expect(inv?.codigo, 'K7MQ4P2X');
    expect(repo.generadas, 1);
  });
}
