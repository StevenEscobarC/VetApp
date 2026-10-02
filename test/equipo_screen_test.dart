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
  group('unirme a otra clínica', () {
    testWidgets('sole admin sees the entry and the data error shows', (
      tester,
    ) async {
      final repo = FakeTeamRepository(miembrosFixture: [miembroAna])
        ..errorUnirse = const TeamFailure(
          'Tu clínica ya tiene datos; no se pueden fusionar clínicas. '
          'Regístrate con otro correo para unirte.',
        );
      await tester.pumpWidget(_equipo(repo));
      await tester.pumpAndSettle();
      const entrada = '¿Te registraste sin código? Unirme a otra clínica';
      await tester.ensureVisible(find.text(entrada));
      await tester.tap(find.text(entrada));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'K7MQ4P2X');
      await tester.tap(find.text('Unirme'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ya tiene datos'), findsOneWidget);
    });

    testWidgets('entry absent with 2+ members', (tester) async {
      final repo = FakeTeamRepository(miembrosFixture: [miembroAna, miembroLuis]);
      await tester.pumpWidget(_equipo(repo));
      await tester.pumpAndSettle();
      expect(find.textContaining('Unirme a otra clínica'), findsNothing);
    });
  });

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

  group('acciones de miembro', () {
    final luisAdmin = Miembro(
      id: 'vet-2',
      nombre: 'Luis Gómez',
      rolClinica: 'admin',
      activo: true,
      createdAt: DateTime(2026, 2, 1),
    );
    final pablo = Miembro(
      id: 'vet-4',
      nombre: 'Pablo Díaz',
      rolClinica: 'veterinario',
      activo: true,
      createdAt: DateTime(2026, 4, 1),
    );

    Future<FakeTeamRepository> abrir(
      WidgetTester tester,
      List<Miembro> miembros, {
      int citas = 0,
      String tocar = 'Luis Gómez',
    }) async {
      final repo = FakeTeamRepository(miembrosFixture: miembros)
        ..citasAbiertas = citas;
      await tester.pumpWidget(_equipo(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining(tocar));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('Hacer administrador confirma y avisa', (tester) async {
      final repo = await abrir(tester, [miembroAna, miembroLuis]);
      expect(find.text('Retirar del equipo'), findsOneWidget);
      await tester.tap(find.text('Hacer administrador'));
      await tester.pumpAndSettle();
      expect(find.text('¿Hacer administrador a Luis Gómez?'), findsOneWidget);
      expect(
        find.text('Podrá invitar, retirar miembros y cambiar roles.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Hacer administrador'));
      await tester.pumpAndSettle();
      expect(repo.rolesCambiados, [('vet-2', 'admin')]);
      expect(find.text('Luis Gómez ahora es administrador'), findsOneWidget);
    });

    testWidgets('admin colega ofrece Hacer veterinario', (tester) async {
      await abrir(tester, [miembroAna, luisAdmin]);
      expect(find.text('Hacer veterinario'), findsOneWidget);
    });

    testWidgets('Retirar sin citas abiertas', (tester) async {
      final repo = await abrir(tester, [miembroAna, miembroLuis]);
      await tester.tap(find.text('Retirar del equipo'));
      await tester.pumpAndSettle();
      expect(find.text('¿Retirar a Luis Gómez del equipo?'), findsOneWidget);
      await tester.tap(find.text('Retirar'));
      await tester.pumpAndSettle();
      expect(repo.retiradas, [('vet-2', null)]);
      expect(find.text('Luis Gómez ya no tiene acceso'), findsOneWidget);
    });

    testWidgets('Retirar con citas y otro veterinario abre reasignar', (
      tester,
    ) async {
      final repo = await abrir(tester, [
        miembroAna,
        miembroLuis,
        pablo,
      ], citas: 3);
      await tester.tap(find.text('Retirar del equipo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retirar'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Luis Gómez tiene 3 citas próximas sin atender. ¿A quién se las '
          'asignamos?',
        ),
        findsOneWidget,
      );
      expect(find.text('Ana Ramírez (Tú)'), findsWidgets);
      expect(find.text('Reasignar 3 citas'), findsOneWidget);
      await tester.tap(find.text('Pablo Díaz').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reasignar 3 citas'));
      await tester.pumpAndSettle();
      expect(repo.retiradas, [('vet-2', 'vet-4')]);
    });

    testWidgets('Volver en reasignar cancela sin retirar', (tester) async {
      final repo = await abrir(tester, [
        miembroAna,
        miembroLuis,
        pablo,
      ], citas: 1);
      await tester.tap(find.text('Retirar del equipo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retirar'));
      await tester.pumpAndSettle();
      expect(find.text('Reasignar 1 cita'), findsOneWidget);
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect(repo.retiradas, isEmpty);
    });

    testWidgets('con citas y solo yo como opcion pasa null', (tester) async {
      final repo = await abrir(tester, [miembroAna, miembroLuis], citas: 2);
      await tester.tap(find.text('Retirar del equipo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retirar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Reasignar'), findsNothing);
      expect(repo.retiradas, [('vet-2', null)]);
    });

    testWidgets('fila propia como unico admin solo explica', (tester) async {
      await abrir(tester, [miembroAna, miembroLuis], tocar: 'Ana Ramírez');
      expect(
        find.text(
          'Eres el único administrador. Nombra a otro antes de dejar el '
          'cargo.',
        ),
        findsOneWidget,
      );
      expect(find.text('Salir de la clínica'), findsNothing);
      expect(find.text('Dejar de ser administrador'), findsNothing);
    });

    testWidgets('fila propia con otro admin: dejar cargo y salir', (
      tester,
    ) async {
      final repo = await abrir(tester, [
        miembroAna,
        luisAdmin,
      ], tocar: 'Ana Ramírez');
      await tester.tap(find.text('Dejar de ser administrador'));
      await tester.pumpAndSettle();
      expect(find.text('¿Dejar de ser administrador?'), findsOneWidget);
      expect(
        find.text('Seguirás en la clínica como veterinario.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Confirmar cambio'));
      await tester.pumpAndSettle();
      expect(repo.rolesCambiados, [('vet-1', 'veterinario')]);

      await tester.tap(find.textContaining('Ana Ramírez'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salir de la clínica'));
      await tester.pumpAndSettle();
      expect(find.text('¿Salir de la clínica?'), findsOneWidget);
      await tester.tap(find.text('Salir'));
      await tester.pumpAndSettle();
      expect(repo.retiradas, [('vet-1', null)]);
    });

    testWidgets('no admin no abre acciones', (tester) async {
      final repo = FakeTeamRepository(
        miembrosFixture: [miembroAna, miembroLuis],
      );
      await tester.pumpWidget(_equipo(repo, perfil: vetColegaProfile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana Ramírez'));
      await tester.pumpAndSettle();
      expect(find.text('Retirar del equipo'), findsNothing);
      expect(find.text('Hacer veterinario'), findsNothing);
    });

    testWidgets('retirados no abren acciones', (tester) async {
      final repo = FakeTeamRepository(
        miembrosFixture: [miembroAna, miembroRetirado],
      );
      await tester.pumpWidget(_equipo(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retirados (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marta Ruiz'));
      await tester.pumpAndSettle();
      expect(find.text('Retirar del equipo'), findsNothing);
    });

    testWidgets('TeamFailure se muestra en snackbar', (tester) async {
      final repo = await abrir(tester, [miembroAna, miembroLuis]);
      repo.errorCambio = const TeamFailure(
        'La clínica debe tener al menos un administrador.',
      );
      await tester.tap(find.text('Hacer administrador'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hacer administrador'));
      await tester.pumpAndSettle();
      expect(
        find.text('La clínica debe tener al menos un administrador.'),
        findsOneWidget,
      );
    });
  });
}
