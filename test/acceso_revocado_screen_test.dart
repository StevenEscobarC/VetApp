import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vetapp/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/team/domain/team_failure.dart';
import 'package:vetapp/features/team/presentation/providers/team_providers.dart';
import 'package:vetapp/features/team/presentation/screens/acceso_revocado_screen.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_team.dart';
import 'helpers/router_harness.dart';

Widget _pantalla(
  FakeTeamRepository repo, {
  AuthProfile perfil = vetRetiradoProfile,
  FakeAuthProfileNotifier? auth,
}) => routerHarness(
  initialLocation: '/r',
  routes: [
    GoRoute(path: '/r', builder: (_, _) => const AccesoRevocadoScreen()),
  ],
  overrides: [
    authProfileProvider.overrideWith(
      () => auth ?? FakeAuthProfileNotifier(profile: perfil),
    ),
    teamRepositoryProvider.overrideWithValue(repo),
  ],
);

void main() {
  testWidgets('falls back to generic heading when clinic name is unreadable', (
    tester,
  ) async {
    await tester.pumpWidget(_pantalla(FakeTeamRepository()));
    await tester.pumpAndSettle();
    expect(find.text('Ya no tienes acceso a la clínica'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.text('Crear mi propia clínica'), findsOneWidget);
    expect(find.text('Tengo un código de invitación'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('shows the clinic name when readable', (tester) async {
    const perfil = AuthProfile(
      id: 'vet-3',
      nombre: 'Marta Ruiz',
      email: 'marta@vetapp.co',
      rol: 'VETERINARIO',
      telefono: '',
      clinicaId: 'cli-1',
      clinicaNombre: 'Clínica Patitas',
      activo: false,
    );
    await tester.pumpWidget(_pantalla(FakeTeamRepository(), perfil: perfil));
    await tester.pumpAndSettle();
    expect(find.text('Ya no tienes acceso a Clínica Patitas'), findsOneWidget);
  });

  testWidgets('crear: empty name errors, success calls the repository', (
    tester,
  ) async {
    final repo = FakeTeamRepository();
    await tester.pumpWidget(_pantalla(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear mi propia clínica'));
    await tester.pumpAndSettle();
    expect(find.text('Nombre de tu clínica'), findsOneWidget);

    await tester.tap(find.text('Crear clínica'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe el nombre de tu clínica.'), findsOneWidget);
    expect(repo.clinicasCreadas, isEmpty);

    await tester.enterText(find.byType(TextField), 'Mi Clínica');
    await tester.tap(find.text('Crear clínica'));
    await tester.pumpAndSettle();
    expect(repo.clinicasCreadas, ['Mi Clínica']);
  });

  testWidgets('crear: failure shows the message under the field', (
    tester,
  ) async {
    final repo = FakeTeamRepository()
      ..errorUnirse = const TeamFailure(
        'No pudimos crear la clínica. Intenta de nuevo.',
      );
    await tester.pumpWidget(_pantalla(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear mi propia clínica'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Mi Clínica');
    await tester.tap(find.text('Crear clínica'));
    await tester.pumpAndSettle();
    expect(
      find.text('No pudimos crear la clínica. Intenta de nuevo.'),
      findsOneWidget,
    );
  });

  testWidgets('unirse: incomplete code errors locally', (tester) async {
    final repo = FakeTeamRepository();
    await tester.pumpWidget(_pantalla(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tengo un código de invitación'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'K7MQ');
    await tester.tap(find.text('Unirme'));
    await tester.pumpAndSettle();
    expect(
      find.text('Ese código no es válido. Revísalo e inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(repo.codigosUsados, isEmpty);
  });

  testWidgets('unirse: expired code error appears; valid code is sent', (
    tester,
  ) async {
    final repo = FakeTeamRepository()
      ..errorUnirse = const TeamFailure(
        'Ese código ya venció. Pídele al administrador uno nuevo.',
      );
    await tester.pumpWidget(_pantalla(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tengo un código de invitación'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'K7MQ4P2X');
    await tester.tap(find.text('Unirme'));
    await tester.pumpAndSettle();
    expect(
      find.text('Ese código ya venció. Pídele al administrador uno nuevo.'),
      findsOneWidget,
    );

    repo.errorUnirse = null;
    await tester.tap(find.text('Unirme'));
    await tester.pumpAndSettle();
    expect(repo.codigosUsados, ['K7MQ4P2X']);
  });

  testWidgets('Cerrar sesión signs out', (tester) async {
    await tester.pumpWidget(_pantalla(FakeTeamRepository()));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(
      tester.element(find.byType(AccesoRevocadoScreen)),
    );
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(c.read(authProfileProvider).value, isNull);
  });
}
