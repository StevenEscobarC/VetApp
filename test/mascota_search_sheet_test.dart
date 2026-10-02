import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/patients/presentation/providers/mascota_foto_providers.dart';
import 'package:vetapp/features/patients/presentation/providers/mascotas_providers.dart';
import 'package:vetapp/features/vaccination/domain/entities/carne.dart';
import 'package:vetapp/features/vaccination/presentation/providers/vacuna_providers.dart';
import 'package:vetapp/features/vaccination/presentation/widgets/mascota_search_sheet.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_fotos.dart';
import 'helpers/fake_mascotas.dart';
import 'helpers/fake_vacunas.dart';
import 'helpers/router_harness.dart';

Widget _app() {
  return routerHarness(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => showMascotaSearchSheet(context),
            child: const Text('ABRIR'),
          ),
        ),
      ),
      GoRoute(
        path: '/dosis/nueva',
        builder: (_, state) =>
            Text('DOSIS ${state.uri.queryParameters['mascotaId']}'),
      ),
      GoRoute(
        path: '/clientes/nuevo',
        builder: (_, _) => const Text('NUEVO PACIENTE'),
      ),
    ],
    overrides: [
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: vetProfile),
      ),
      mascotaRepositoryProvider.overrideWithValue(
        FakeMascotaRepository(mascotas: [mascotaRocky, mascotaLuna]),
      ),
      vacunaRepositoryProvider.overrideWithValue(
        FakeVacunaRepository(
          resumenPorMascotaData: {
            'm-2': const ResumenVacunasMascota(vencidas: 1, proximas: 0),
          },
        ),
      ),
      mascotaFotoDatasourceProvider.overrideWithValue(
        FakeMascotaFotoDatasource(),
      ),
    ],
  );
}

Future<void> _abrir(WidgetTester tester) async {
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
  await tester.tap(find.text('ABRIR'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('buscar "lu" lista Luna con especie, dueño y chip; tocar abre el '
      'formulario de dosis', (tester) async {
    await _abrir(tester);
    await tester.enterText(find.byType(TextFormField), 'lu');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Luna'), findsOneWidget);
    expect(find.text('Gato · Rita Gómez'), findsOneWidget);
    expect(find.text('Vencida'), findsOneWidget);

    await tester.tap(find.text('Luna'));
    await tester.pumpAndSettle();
    expect(find.text('DOSIS m-2'), findsOneWidget);
  });

  testWidgets('sin resultados ofrece Registrar paciente nuevo', (tester) async {
    await _abrir(tester);
    await tester.enterText(find.byType(TextFormField), 'zzz');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('No encontramos esa mascota.'), findsOneWidget);
    await tester.tap(find.text('Registrar paciente nuevo'));
    await tester.pumpAndSettle();
    expect(find.text('NUEVO PACIENTE'), findsOneWidget);
  });
}
