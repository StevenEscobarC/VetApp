import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/team/domain/miembro.dart';
import 'package:vetapp/features/team/domain/team_failure.dart';
import 'package:vetapp/features/team/presentation/providers/team_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_team.dart';

ProviderContainer _container({
  List<Miembro> miembros = const [],
  Object? error,
  bool sinClinica = false,
}) {
  final c = ProviderContainer(
    retry: (retryCount, error) => null,
    overrides: [
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(
          profile: sinClinica ? clienteProfile : vetAdminProfile,
        ),
      ),
      teamRepositoryProvider.overrideWithValue(
        FakeTeamRepository(miembrosFixture: miembros, error: error),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<bool> _multiVet(ProviderContainer c) async {
  final sub = c.listen(esClinicaMultiVetProvider, (_, _) {});
  addTearDown(sub.close);
  await c.read(teamProvider.future).catchError((_) => <Miembro>[]);
  return c.read(esClinicaMultiVetProvider);
}

void main() {
  group('esClinicaMultiVetProvider', () {
    test('false with a single active vet', () async {
      expect(await _multiVet(_container(miembros: [miembroAna])), isFalse);
    });
    test('true with two active vets', () async {
      expect(
        await _multiVet(_container(miembros: [miembroAna, miembroLuis])),
        isTrue,
      );
    });
    test('false when the second vet is retired', () async {
      expect(
        await _multiVet(_container(miembros: [miembroAna, miembroRetirado])),
        isFalse,
      );
    });
    test('false on repository error', () async {
      expect(
        await _multiVet(_container(error: const TeamFailure('x'))),
        isFalse,
      );
    });
    test('false while loading', () {
      final c = _container(miembros: [miembroAna, miembroLuis]);
      expect(c.read(esClinicaMultiVetProvider), isFalse);
    });
  });

  test('indicesColorVetProvider wraps at 4 and keeps retired indexes', () async {
    final base = DateTime(2026, 1, 1);
    final ms = [
      for (var i = 0; i < 5; i++)
        Miembro(
          id: 'v$i',
          nombre: 'Vet $i',
          rolClinica: 'veterinario',
          activo: i != 1,
          createdAt: base.add(Duration(days: i)),
        ),
    ];
    final c = _container(miembros: ms.reversed.toList());
    final sub = c.listen(indicesColorVetProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(teamProvider.future);
    final idx = c.read(indicesColorVetProvider);
    expect([for (final m in ms) idx[m.id]], [0, 1, 2, 3, 0]);
  });

  test('teamProvider returns [] when profile has no clinicaId', () async {
    final c = _container(miembros: [miembroAna], sinClinica: true);
    expect(await c.read(teamProvider.future), isEmpty);
  });
}
