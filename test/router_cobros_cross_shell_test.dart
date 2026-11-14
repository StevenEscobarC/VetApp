import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/core/router/app_router.dart';
import 'package:vetapp/features/appointments/presentation/providers/citas_providers.dart';
import 'package:vetapp/features/appointments/presentation/providers/recordatorios_providers.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/billing/domain/entities/cobro.dart';
import 'package:vetapp/features/billing/presentation/providers/cobros_providers.dart';
import 'package:vetapp/features/billing/presentation/screens/cobro_detail_screen.dart';
import 'package:vetapp/features/billing/presentation/screens/cobros_screen.dart';
import 'package:vetapp/features/clients/presentation/providers/clientes_providers.dart';
import 'package:vetapp/features/home/presentation/app_shell.dart';
import 'package:vetapp/features/inventory/presentation/providers/inventario_providers.dart';
import 'package:vetapp/features/patients/presentation/providers/mascotas_providers.dart';
import 'package:vetapp/features/team/domain/miembro.dart';
import 'package:vetapp/features/team/presentation/providers/team_providers.dart';
import 'package:vetapp/features/vaccination/presentation/providers/vacuna_providers.dart';
import 'package:vetapp/main.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_citas.dart';
import 'helpers/fake_clientes.dart';
import 'helpers/fake_cobros.dart';
import 'helpers/fake_inventario.dart';
import 'helpers/fake_mascotas.dart';
import 'helpers/fake_plan.dart';
import 'helpers/fake_recordatorios.dart';
import 'helpers/fake_team.dart';
import 'helpers/fake_vacunas.dart';

/// G5: `/cobros` y `/cobros/:id` son rutas raíz apiladas sobre el
/// `StatefulShellRoute`. Usa el `routerProvider` real (con `AppShell`), no el
/// `routerHarness` plano que ocultaría una página de shell duplicada.

Widget _app() {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      ...planOverrides(),
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: vetProfile),
      ),
      citaRepositoryProvider.overrideWithValue(FakeCitaRepository()),
      recordatoriosServiceProvider.overrideWithValue(
        FakeRecordatoriosService(),
      ),
      clienteRepositoryProvider.overrideWithValue(FakeClienteRepository()),
      mascotaRepositoryProvider.overrideWithValue(FakeMascotaRepository()),
      teamRepositoryProvider.overrideWithValue(FakeTeamRepository()),
      esClinicaMultiVetProvider.overrideWithValue(false),
      miembrosActivosProvider.overrideWithValue(const <Miembro>[]),
      indicesColorVetProvider.overrideWithValue(const <String, int>{}),
      inventarioRepositoryProvider.overrideWithValue(
        FakeInventarioRepository(),
      ),
      vacunaRepositoryProvider.overrideWithValue(FakeVacunaRepository()),
      cobrosRepositoryProvider.overrideWithValue(
        FakeCobrosRepository(
          cobros: [
            cobroDePrueba(id: 'c1'),
            cobroDePrueba(
              id: 'q1',
              tipo: TipoCobro.cotizacion,
              numero: 4,
              estado: EstadoCobro.abierta,
              clienteNombre: 'Julia Paz',
              mascotaNombre: 'Max',
            ),
          ],
        ),
      ),
      clockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 13, 17)),
    ],
    child: const VetApp(),
  );
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

/// Ubicación de la página superior (incluye las empujadas con `push`).
String _ubicacion(WidgetTester tester) => _container(
  tester,
).read(routerProvider).routerDelegate.currentConfiguration.last.matchedLocation;

Future<void> _abrirMas(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
  _container(tester).read(routerProvider).go('/mas');
  await tester.pumpAndSettle();
  expect(_ubicacion(tester), '/mas');
}

void main() {
  testWidgets('Más > Cobros abre una sola página /cobros sin duplicar el '
      'shell y Atrás vuelve a Más', (tester) async {
    await _abrirMas(tester);

    await tester.tap(find.text('Cobros'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(CobrosScreen), findsOneWidget);
    expect(_ubicacion(tester), '/cobros');
    expect(find.byType(AppShell, skipOffstage: false), findsOneWidget);

    _container(tester).read(routerProvider).pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_ubicacion(tester), '/mas');
    expect(find.byType(CobrosScreen), findsNothing);
  });

  testWidgets('/cobros?tipo=cot abre con Cotizaciones', (tester) async {
    await _abrirMas(tester);
    _container(tester).read(routerProvider).push('/cobros?tipo=cot');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(CobrosScreen), findsOneWidget);
    expect(find.text('Julia Paz · Max'), findsOneWidget);
    expect(find.text('Nueva cotización'), findsOneWidget);
  });

  testWidgets('tocar una tarjeta abre /cobros/c1 y Atrás vuelve a la lista', (
    tester,
  ) async {
    await _abrirMas(tester);
    await tester.tap(find.text('Cobros'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Laura Gómez · Rocky'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_ubicacion(tester), '/cobros/c1');
    expect(find.byType(CobroDetailScreen), findsOneWidget);
    expect(find.byType(AppShell, skipOffstage: false), findsOneWidget);

    _container(tester).read(routerProvider).pop();
    await tester.pumpAndSettle();
    expect(_ubicacion(tester), '/cobros');
    expect(find.byType(CobrosScreen), findsOneWidget);
  });

  testWidgets('/cobros/c1 directo muestra el detalle de c1', (tester) async {
    await _abrirMas(tester);
    _container(tester).read(routerProvider).push('/cobros/c1');
    await tester.pumpAndSettle();
    final detalle = tester.widget<CobroDetailScreen>(
      find.byType(CobroDetailScreen),
    );
    expect(detalle.cobroId, 'c1');
    expect(find.text('CC-0012'), findsOneWidget);
  });

  testWidgets('la fila de Más: icono, chevron, alto mínimo, sin pill y entre '
      'Inventario y Recordatorios', (tester) async {
    await _abrirMas(tester);

    final fila = find.ancestor(
      of: find.text('Cobros'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(
        of: fila,
        matching: find.byIcon(Icons.receipt_long_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: fila, matching: find.byIcon(Icons.chevron_right)),
      findsOneWidget,
    );
    expect(tester.getSize(fila).height, greaterThanOrEqualTo(56));
    // Sin pill: solo icono, texto y chevron.
    expect(
      find.descendant(of: fila, matching: find.byType(Text)),
      findsOneWidget,
    );

    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    expect(y('Inventario'), lessThan(y('Cobros')));
    expect(y('Cobros'), lessThan(y('Recordatorios')));
  });
}
