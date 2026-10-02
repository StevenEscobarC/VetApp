import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/features/appointments/presentation/providers/citas_providers.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/team/domain/team_failure.dart';
import 'package:vetapp/features/team/presentation/providers/team_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_team.dart';

(ProviderContainer, FakeTeamRepository) _setup() {
  final repo = FakeTeamRepository(miembrosFixture: [miembroAna, miembroLuis]);
  final c = ProviderContainer(
    retry: (retryCount, error) => null,
    overrides: [
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: vetAdminProfile),
      ),
      teamRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(c.dispose);
  return (c, repo);
}

void main() {
  test('retirar forwards null destination, returns count, refreshes', () async {
    final (c, repo) = _setup();
    repo.citasAbiertas = 3;
    final sub = c.listen(teamProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(teamProvider.future);
    final antes = repo.llamadas;
    final rev = c.read(citasRevisionProvider);

    final n = await c.read(teamActionsProvider).retirar('vet-2');
    await c.read(teamProvider.future);

    expect(n, 3);
    expect(repo.retiradas, [('vet-2', null)]);
    expect(repo.llamadas, greaterThan(antes));
    expect(c.read(citasRevisionProvider), rev + 1);
  });

  test('retirar forwards the chosen destination', () async {
    final (c, repo) = _setup();
    await c.read(teamActionsProvider).retirar('vet-2', reasignarA: 'vet-1');
    expect(repo.retiradas, [('vet-2', 'vet-1')]);
  });

  test('cambiarRol forwards and refreshes teamProvider', () async {
    final (c, repo) = _setup();
    final sub = c.listen(teamProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(teamProvider.future);
    final antes = repo.llamadas;
    await c.read(teamActionsProvider).cambiarRol('vet-2', 'admin');
    await c.read(teamProvider.future);
    expect(repo.rolesCambiados, [('vet-2', 'admin')]);
    expect(repo.llamadas, greaterThan(antes));
  });

  test('last-admin error surfaces as TeamFailure with exact message', () async {
    final (c, repo) = _setup();
    repo.errorCambio = const TeamFailure(
      'La clínica debe tener al menos un administrador.',
    );
    await expectLater(
      c.read(teamActionsProvider).retirar('vet-1'),
      throwsA(
        isA<TeamFailure>().having(
          (e) => e.message,
          'message',
          'La clínica debe tener al menos un administrador.',
        ),
      ),
    );
  });

  test('retiring oneself invalidates authProfileProvider', () async {
    final (c, _) = _setup();
    var cambios = 0;
    final sub = c.listen(authProfileProvider, (_, _) => cambios++);
    addTearDown(sub.close);
    await c.read(authProfileProvider.future);
    cambios = 0;
    await c.read(teamActionsProvider).retirar('vet-1');
    await c.read(authProfileProvider.future);
    expect(cambios, greaterThan(0));
  });

  test('contarCitasAbiertas delegates to the repository', () async {
    final (c, repo) = _setup();
    repo.citasAbiertas = 2;
    expect(await c.read(teamActionsProvider).contarCitasAbiertas('vet-2'), 2);
  });
}
