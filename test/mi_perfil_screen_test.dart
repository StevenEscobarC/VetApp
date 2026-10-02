import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetapp/features/appointments/presentation/providers/citas_providers.dart';
import 'package:vetapp/features/appointments/presentation/providers/recordatorios_providers.dart';
import 'package:vetapp/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/home/presentation/screens/mas_screen.dart';
import 'package:vetapp/features/team/domain/team_failure.dart';
import 'package:vetapp/features/team/presentation/equipo_routes.dart';
import 'package:vetapp/features/team/presentation/providers/perfil_providers.dart';
import 'package:vetapp/features/team/presentation/providers/team_providers.dart';
import 'package:vetapp/features/team/presentation/screens/mi_perfil_screen.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_citas.dart';
import 'helpers/fake_perfil.dart';
import 'helpers/fake_recordatorios.dart';
import 'helpers/fake_team.dart';
import 'helpers/router_harness.dart';

const _conMatricula = AuthProfile(
  id: 'vet-1',
  nombre: 'Ana Ramírez',
  email: 'ana@vetapp.co',
  rol: 'VETERINARIO',
  telefono: '3001234567',
  clinicaId: 'cli-1',
  clinicaNombre: 'Clínica Patitas',
  rolClinica: 'admin',
  matricula: '12345',
);

List<Override> _overrides(FakePerfilRepository repo, AuthProfile perfil) {
  SharedPreferences.setMockInitialValues({});
  return [
    authProfileProvider.overrideWith(
      () => FakeAuthProfileNotifier(profile: perfil),
    ),
    perfilRepositoryProvider.overrideWithValue(repo),
    teamRepositoryProvider.overrideWithValue(
      FakeTeamRepository(miembrosFixture: [miembroAna]),
    ),
    citaRepositoryProvider.overrideWithValue(FakeCitaRepository()),
    recordatoriosServiceProvider.overrideWithValue(FakeRecordatoriosService()),
  ];
}

Widget _perfil(
  FakePerfilRepository repo, {
  AuthProfile perfil = _conMatricula,
}) => routerHarness(
  initialLocation: '/perfil',
  routes: [GoRoute(path: '/perfil', builder: (_, _) => const MiPerfilScreen())],
  overrides: _overrides(repo, perfil),
);

void main() {
  testWidgets('pre-llena los campos y muestra el texto de matrícula', (
    tester,
  ) async {
    await tester.pumpWidget(_perfil(FakePerfilRepository()));
    await tester.pumpAndSettle();
    expect(find.text('Ana Ramírez'), findsOneWidget);
    expect(find.text('3001234567'), findsOneWidget);
    expect(find.text('12345'), findsOneWidget);
    expect(find.text('Matrícula profesional (opcional)'), findsWidgets);
    expect(find.text('Ej. 12345'), findsOneWidget);
    expect(
      find.text('Se mostrará en tus documentos, como el carné de vacunación.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.badge_outlined), findsOneWidget);
    final tf = tester.widget<TextField>(
      find.widgetWithText(TextField, '12345'),
    );
    expect(tf.maxLength, 20);
  });

  testWidgets('guarda matrícula recortada y muestra snackbar', (tester) async {
    final repo = FakePerfilRepository();
    await tester.pumpWidget(_perfil(repo));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '12345'), '  67890 ');
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(repo.llamadas, hasLength(1));
    expect(repo.llamadas.single.matricula, '67890');
    expect(repo.llamadas.single.id, 'vet-1');
    expect(find.text('Perfil actualizado'), findsOneWidget);
  });

  testWidgets('matrícula vacía envía null y no bloquea', (tester) async {
    final repo = FakePerfilRepository();
    await tester.pumpWidget(_perfil(repo));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '12345'), '');
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(repo.llamadas.single.matricula, isNull);
  });

  testWidgets('nombre vacío bloquea el guardado', (tester) async {
    final repo = FakePerfilRepository();
    await tester.pumpWidget(_perfil(repo));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Ana Ramírez'), '');
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa tu nombre'), findsOneWidget);
    expect(repo.llamadas, isEmpty);
  });

  testWidgets('fallo muestra mensaje y conserva los valores', (tester) async {
    final repo = FakePerfilRepository(
      error: const TeamFailure(
        'No pudimos guardar tu perfil. Intenta de nuevo.',
      ),
    );
    await tester.pumpWidget(_perfil(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(
      find.text('No pudimos guardar tu perfil. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(find.text('Ana Ramírez'), findsOneWidget);
    expect(find.text('12345'), findsOneWidget);
  });

  testWidgets('Más muestra Mi perfil con Mat. y navega a /mas/perfil', (
    tester,
  ) async {
    await tester.pumpWidget(
      routerHarness(
        initialLocation: '/mas',
        routes: [
          GoRoute(
            path: '/mas',
            builder: (_, _) => const MasScreen(),
            routes: masTeamRoutes,
          ),
        ],
        overrides: _overrides(FakePerfilRepository(), _conMatricula),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mi perfil'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.text('Mat. 12345'), findsOneWidget);
    await tester.tap(find.text('Mi perfil'));
    await tester.pumpAndSettle();
    expect(find.byType(MiPerfilScreen), findsOneWidget);
  });
}
