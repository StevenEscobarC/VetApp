import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/core/widgets/chips/app_filter_chip.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/patients/domain/mascota_failure.dart';
import 'package:vetapp/features/patients/presentation/providers/mascota_foto_providers.dart';
import 'package:vetapp/features/patients/presentation/providers/mascotas_providers.dart';
import 'package:vetapp/features/patients/presentation/screens/pacientes_list_screen.dart';
import 'package:vetapp/features/vaccination/domain/entities/carne.dart';
import 'package:vetapp/features/vaccination/presentation/providers/vacuna_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_fotos.dart';
import 'helpers/fake_mascotas.dart';
import 'helpers/fake_vacunas.dart';
import 'helpers/router_harness.dart';

Widget _appUnderTest({
  required FakeMascotaRepository repo,
  FakeVacunaRepository? vacunas,
}) {
  return routerHarness(
    initialLocation: '/pacientes',
    routes: [
      GoRoute(
        path: '/pacientes',
        builder: (_, _) => const PacientesListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                Text('FICHA MASCOTA ${state.pathParameters['id']}'),
          ),
        ],
      ),
    ],
    overrides: [
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: vetProfile),
      ),
      mascotaRepositoryProvider.overrideWithValue(repo),
      vacunaRepositoryProvider.overrideWithValue(
        vacunas ?? FakeVacunaRepository(),
      ),
      mascotaFotoDatasourceProvider.overrideWithValue(
        FakeMascotaFotoDatasource(),
      ),
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
      expect(find.text('Buscar por nombre, dueño o especie'), findsOneWidget);
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

  testWidgets('sin pacientes muestra el estado vacío inicial', (tester) async {
    final repo = FakeMascotaRepository();
    await tester.pumpWidget(_appUnderTest(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Aún no tienes pacientes registrados'), findsOneWidget);
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

  testWidgets('tocar la fila de Rocky navega a su ficha', (tester) async {
    final repo = FakeMascotaRepository(
      mascotas: [mascotaRocky, mascotaLuna, mascotaMichi],
    );
    await tester.pumpWidget(_appUnderTest(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rocky'));
    await tester.pumpAndSettle();

    expect(find.text('FICHA MASCOTA m-1'), findsOneWidget);
  });

  testWidgets(
    'chips Vencida/Próxima solo para mascotas con dosis pendientes y una '
    'sola llamada al resumen',
    (tester) async {
      final repo = FakeMascotaRepository(
        mascotas: [mascotaRocky, mascotaLuna, mascotaMichi],
      );
      final vacunas = FakeVacunaRepository(
        resumenPorMascotaData: {
          'm-1': const ResumenVacunasMascota(vencidas: 2, proximas: 1),
          'm-2': const ResumenVacunasMascota(vencidas: 0, proximas: 1),
        },
      );
      await tester.pumpWidget(_appUnderTest(repo: repo, vacunas: vacunas));
      await tester.pumpAndSettle();

      expect(find.text('Vencida'), findsOneWidget);
      expect(find.text('Próxima'), findsOneWidget);
      expect(
        vacunas.llamadas.where((l) => l.metodo == 'resumenPorMascota').length,
        1,
      );
    },
  );

  testWidgets('sin dosis pendientes no hay chips de vacunación', (
    tester,
  ) async {
    final repo = FakeMascotaRepository(mascotas: [mascotaRocky, mascotaLuna]);
    final vacunas = FakeVacunaRepository(
      resumenPorMascotaData: {
        'm-1': const ResumenVacunasMascota(vencidas: 0, proximas: 0),
      },
    );
    await tester.pumpWidget(_appUnderTest(repo: repo, vacunas: vacunas));
    await tester.pumpAndSettle();

    expect(find.text('Vencida'), findsNothing);
    expect(find.text('Próxima'), findsNothing);
  });
}
