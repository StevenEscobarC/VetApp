import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/core/utils/compartir.dart';
import 'package:vetapp/core/utils/lanzador_externo.dart';
import 'helpers/fake_compartir.dart';
import 'helpers/fake_url_launcher.dart';
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

  group('invitaciones', () {
    final ahora = DateTime.utc(2026, 10, 1, 15);

    Widget pantalla(
      FakeTeamRepository repo, {
      FakeCompartidor? compartidor,
      FakeLanzadorExterno? lanzador,
      AuthProfile perfil = vetAdminProfile,
    }) => routerHarness(
      initialLocation: '/equipo',
      routes: [
        GoRoute(path: '/equipo', builder: (_, _) => const EquipoScreen()),
      ],
      overrides: [
        ..._overrides(repo, perfil: perfil),
        clockProvider.overrideWithValue(() => ahora),
        compartidorProvider.overrideWithValue(compartidor ?? FakeCompartidor()),
        lanzadorExternoProvider.overrideWithValue(
          lanzador ?? FakeLanzadorExterno(),
        ),
      ],
    );

    testWidgets('admin sin código: CTA genera y muestra la tarjeta', (
      tester,
    ) async {
      final repo = FakeTeamRepository(miembrosFixture: [miembroAna]);
      await tester.pumpWidget(pantalla(repo));
      await tester.pumpAndSettle();
      expect(find.text('Invitaciones'), findsOneWidget);
      expect(
        find.text('No hay códigos activos. Genera uno para invitar a un colega.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Invitar veterinario'));
      await tester.pumpAndSettle();
      expect(find.text('K7MQ-4P2X'), findsOneWidget);
      expect(find.text('Código generado'), findsOneWidget);
      expect(find.text('Generar código nuevo'), findsOneWidget);
    });

    testWidgets('con código vigente pide confirmar antes de generar', (
      tester,
    ) async {
      final repo = FakeTeamRepository(miembrosFixture: [miembroAna])
        ..invitacion = invitacionFixture;
      await tester.pumpWidget(pantalla(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generar código nuevo'));
      await tester.pumpAndSettle();
      expect(find.text('¿Generar un código nuevo?'), findsOneWidget);
      expect(find.text('El código actual dejará de funcionar.'), findsOneWidget);
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect(repo.generadas, 0);
      await tester.tap(find.text('Generar código nuevo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generar nuevo'));
      await tester.pumpAndSettle();
      expect(repo.generadas, 1);
    });

    testWidgets('Compartir envía el mensaje al compartidor', (tester) async {
      final repo = FakeTeamRepository(miembrosFixture: [miembroAna])
        ..invitacion = invitacionFixture;
      final comp = FakeCompartidor();
      await tester.pumpWidget(pantalla(repo, compartidor: comp));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compartir código'));
      await tester.pumpAndSettle();
      expect(comp.compartidos, hasLength(1));
      expect(comp.compartidos.first, contains('Clínica Patitas'));
      expect(comp.compartidos.first, contains('K7MQ-4P2X'));
    });

    testWidgets('si compartir falla abre WhatsApp con texto codificado', (
      tester,
    ) async {
      final repo = FakeTeamRepository(miembrosFixture: [miembroAna])
        ..invitacion = invitacionFixture;
      final lanz = FakeLanzadorExterno();
      await tester.pumpWidget(
        pantalla(
          repo,
          compartidor: FakeCompartidor(error: Exception('sin hoja')),
          lanzador: lanz,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compartir código'));
      await tester.pumpAndSettle();
      expect(lanz.abiertos, hasLength(1));
      final uri = lanz.abiertos.first.toString();
      expect(uri, startsWith('https://wa.me/?text=Hola%2C%20te%20invito'));
      expect(uri, isNot(contains('+')));
    });

    testWidgets('Copiar código usa el portapapeles', (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final repo = FakeTeamRepository(miembrosFixture: [miembroAna])
        ..invitacion = invitacionFixture;
      await tester.pumpWidget(pantalla(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copiar código'));
      await tester.pumpAndSettle();
      final set = calls.firstWhere((c) => c.method == 'Clipboard.setData');
      expect((set.arguments as Map)['text'], 'K7MQ-4P2X');
      expect(find.text('Código copiado'), findsOneWidget);
    });

    testWidgets('Revocar confirma y revoca', (tester) async {
      final repo = FakeTeamRepository(miembrosFixture: [miembroAna])
        ..invitacion = invitacionFixture;
      await tester.pumpWidget(pantalla(repo));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Revocar código'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revocar código'));
      await tester.pumpAndSettle();
      expect(find.text('¿Revocar este código?'), findsOneWidget);
      expect(find.text('Nadie podrá usar el código K7MQ-4P2X.'), findsOneWidget);
      await tester.tap(find.text('Revocar'));
      await tester.pumpAndSettle();
      expect(repo.revocadas, ['inv-1']);
      expect(find.text('Código revocado'), findsOneWidget);
    });

    testWidgets('error al generar muestra snackbar', (tester) async {
      final repo = FakeTeamRepository(miembrosFixture: [miembroAna])
        ..errorInvitacion = const TeamFailure(
          'No pudimos generar el código. Intenta de nuevo.',
        );
      await tester.pumpWidget(pantalla(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invitar veterinario'));
      await tester.pumpAndSettle();
      expect(
        find.text('No pudimos generar el código. Intenta de nuevo.'),
        findsOneWidget,
      );
    });

    testWidgets('no admin no ve invitaciones ni CTA', (tester) async {
      final repo = FakeTeamRepository(miembrosFixture: [miembroAna, miembroLuis])
        ..invitacion = invitacionFixture;
      await tester.pumpWidget(pantalla(repo, perfil: vetColegaProfile));
      await tester.pumpAndSettle();
      expect(find.text('Invitaciones'), findsNothing);
      expect(find.text('Invitar veterinario'), findsNothing);
      expect(find.text('K7MQ-4P2X'), findsNothing);
    });
  });
}
