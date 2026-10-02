import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vetapp/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/home/presentation/screens/mas_screen.dart';
import 'package:vetapp/features/team/domain/miembro.dart';
import 'package:vetapp/features/team/domain/team_failure.dart';
import 'package:vetapp/features/team/presentation/equipo_routes.dart';
import 'package:vetapp/features/team/presentation/providers/team_providers.dart';
import 'package:vetapp/features/team/presentation/screens/equipo_screen.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_citas.dart';
import 'helpers/fake_recordatorios.dart';
import 'helpers/fake_team.dart';
import 'helpers/router_harness.dart';
import 'package:vetapp/features/appointments/presentation/providers/recordatorios_providers.dart';
import 'package:vetapp/features/appointments/presentation/providers/citas_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Override> _overrides(
  FakeTeamRepository repo, {
  AuthProfile perfil = vetAdminProfile,
}) {
  SharedPreferences.setMockInitialValues({});
  return [
    authProfileProvider.overrideWith(
      () => FakeAuthProfileNotifier(profile: perfil),
    ),
    teamRepositoryProvider.overrideWithValue(repo),
    citaRepositoryProvider.overrideWithValue(FakeCitaRepository()),
    recordatoriosServiceProvider.overrideWithValue(FakeRecordatoriosService()),
  ];
}

Widget _equipo(FakeTeamRepository repo, {AuthProfile perfil = vetAdminProfile}) =>
    routerHarness(
      initialLocation: '/equipo',
      routes: [GoRoute(path: '/equipo', builder: (_, _) => const EquipoScreen())],
      overrides: _overrides(repo, perfil: perfil),
    );

void main() {
  testWidgets('admin in single-vet clinic sees own tile and solo copy', (
    tester,
  ) async {
    await tester.pumpWidget(_equipo(FakeTeamRepository(miembrosFixture: [miembroAna])));
    await tester.pumpAndSettle();
    expect(find.textContaining('(Tú)'), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);
    expect(find.text('Mat. 12345'), findsOneWidget);
    expect(
      find.text(
        'Eres el único veterinario de la clínica. Invita a un colega para '
        'compartir pacientes y agenda.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Solo los administradores pueden invitar o retirar veterinarios.',
      ),
      findsNothing,
    );
  });

  testWidgets('retired members are collapsed under Retirados (1)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _equipo(
        FakeTeamRepository(
          miembrosFixture: [miembroAna, miembroLuis, miembroRetirado],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Luis Gómez'), findsOneWidget);
    expect(find.text('Marta Ruiz'), findsNothing);
    expect(find.text('Retirados (1)'), findsOneWidget);
    await tester.tap(find.text('Retirados (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Marta Ruiz'), findsOneWidget);
    expect(find.text('Retirado'), findsOneWidget);
  });

  testWidgets('non-admin sees read-only footer and no chevrons', (tester) async {
    await tester.pumpWidget(
      _equipo(
        FakeTeamRepository(miembrosFixture: [miembroAna, miembroLuis]),
        perfil: vetColegaProfile,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Solo los administradores pueden invitar o retirar veterinarios.',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('error shows message and Reintentar refetches', (tester) async {
    final repo = FakeTeamRepository(
      miembrosFixture: [miembroAna],
      error: const TeamFailure('No pudimos cargar el equipo. Intenta de nuevo.'),
    );
    await tester.pumpWidget(_equipo(repo));
    await tester.pumpAndSettle();
    expect(
      find.text('No pudimos cargar el equipo. Intenta de nuevo.'),
      findsOneWidget,
    );
    final antes = repo.llamadas;
    repo.error = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(repo.llamadas, greaterThan(antes));
    expect(find.textContaining('Ana Ramírez'), findsOneWidget);
  });

  Widget mas(FakeTeamRepository repo) => routerHarness(
    initialLocation: '/mas',
    routes: [
      GoRoute(
        path: '/mas',
        builder: (_, _) => const MasScreen(),
        routes: masTeamRoutes,
      ),
    ],
    overrides: _overrides(repo),
  );

  testWidgets('Más shows singular count and navigates to Equipo', (
    tester,
  ) async {
    await tester.pumpWidget(mas(FakeTeamRepository(miembrosFixture: [miembroAna])));
    await tester.pumpAndSettle();
    expect(find.text('1 miembro'), findsOneWidget);
    await tester.tap(find.text('Equipo'));
    await tester.pumpAndSettle();
    expect(find.byType(EquipoScreen), findsOneWidget);
  });

  testWidgets('Más shows plural count', (tester) async {
    final extra = Miembro(
      id: 'vet-4',
      nombre: 'Pablo Díaz',
      rolClinica: 'veterinario',
      activo: true,
      createdAt: DateTime(2026, 4, 1),
    );
    await tester.pumpWidget(
      mas(FakeTeamRepository(miembrosFixture: [miembroAna, miembroLuis, extra])),
    );
    await tester.pumpAndSettle();
    expect(find.text('3 miembros'), findsOneWidget);
  });
}
