import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/core/widgets/chips/app_filter_chip.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/patients/domain/mascota_failure.dart';
import 'package:vetapp/features/patients/presentation/providers/mascotas_providers.dart';
import 'package:vetapp/features/patients/presentation/screens/pacientes_list_screen.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_mascotas.dart';
import 'helpers/router_harness.dart';

Widget _appUnderTest({required FakeMascotaRepository repo}) {
  return routerHarness(
    initialLocation: '/pacientes',
    routes: [
      GoRoute(
        path: '/pacientes',
        builder: (_, _) => const PacientesListScreen(),
      ),
    ],
    overrides: [
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: vetProfile),
      ),
      mascotaRepositoryProvider.overrideWithValue(repo),
    ],
  );
}

void main() {
  testWidgets(
    'muestra las mascotas reales con raza, edad, dueño y chips de especie',
    (tester) async {
      final repo = FakeMascotaRepository(
        mascotas: [mascotaRocky, mascotaLuna, mascotaMichi],
      );
      await tester.pumpWidget(_appUnderTest(repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Rocky'), findsOneWidget);
      expect(find.textContaining('Labrador'), findsOneWidget);
      expect(find.text('Rita Gómez'), findsNWidgets(2));
      expect(
        find.text('Buscar por nombre, dueño o especie'),
        findsOneWidget,
      );
      expect(find.widgetWithText(AppFilterChip, 'Todos'), findsOneWidget);
      expect(find.widgetWithText(AppFilterChip, 'Perros'), findsOneWidget);
      expect(find.widgetWithText(AppFilterChip, 'Gatos'), findsOneWidget);
      expect(find.widgetWithText(AppFilterChip, 'Otros'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    },
  );

  testWidgets(
    'tocar Gatos oculta Rocky y muestra Luna y Michi sin nueva búsqueda; '
    'tocar Todos restaura todas',
    (tester) async {
      final repo = FakeMascotaRepository(
        mascotas: [mascotaRocky, mascotaLuna, mascotaMichi],
      );
      await tester.pumpWidget(_appUnderTest(repo: repo));
      await tester.pumpAndSettle();
      final busquedasAntes = repo.busquedas.length;

      await tester.tap(find.widgetWithText(AppFilterChip, 'Gatos'));
      await tester.pumpAndSettle();

      expect(find.text('Rocky'), findsNothing);
      expect(find.text('Luna'), findsOneWidget);
      expect(find.text('Michi'), findsOneWidget);
      expect(repo.busquedas.length, busquedasAntes);

      await tester.tap(find.widgetWithText(AppFilterChip, 'Todos'));
      await tester.pumpAndSettle();

      expect(find.text('Rocky'), findsOneWidget);
      expect(find.text('Luna'), findsOneWidget);
      expect(find.text('Michi'), findsOneWidget);
      expect(repo.busquedas.length, busquedasAntes);
    },
  );

  testWidgets('sin pacientes muestra el estado vacío inicial', (
    tester,
  ) async {
    final repo = FakeMascotaRepository();
    await tester.pumpWidget(_appUnderTest(repo: repo));
    await tester.pumpAndSettle();

    expect(
      find.text('Aún no tienes pacientes registrados'),
      findsOneWidget,
    );
    expect(
      find.text('Crea tu primer paciente desde la ficha de un cliente.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'escribir una búsqueda sin coincidencias muestra el estado vacío de '
    'búsqueda tras el debounce',
    (tester) async {
      final repo = FakeMascotaRepository(
        mascotas: [mascotaRocky, mascotaLuna, mascotaMichi],
      );
      await tester.pumpWidget(_appUnderTest(repo: repo));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'zz');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('No encontramos mascotas con «zz»'), findsOneWidget);
      expect(
        find.text('Verifica el nombre, dueño o especie e intenta de nuevo.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('error del repositorio muestra el mensaje de error genérico', (
    tester,
  ) async {
    final repo = FakeMascotaRepository(
      error: const MascotaFailure('No pudimos cargar la lista.'),
    );
    await tester.pumpWidget(_appUnderTest(repo: repo));
    await tester.pumpAndSettle();

    expect(
      find.text('No pudimos cargar la lista. Intenta de nuevo.'),
      findsOneWidget,
    );
  });
}
