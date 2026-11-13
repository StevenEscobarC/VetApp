import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/core/router/app_router.dart';
import 'package:vetapp/features/appointments/presentation/providers/citas_providers.dart';
import 'package:vetapp/features/appointments/presentation/providers/recordatorios_providers.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/clients/presentation/providers/clientes_providers.dart';
import 'package:vetapp/features/inventory/domain/entities/movimiento_stock.dart';
import 'package:vetapp/features/inventory/domain/entities/producto.dart';
import 'package:vetapp/features/inventory/presentation/providers/inventario_providers.dart';
import 'package:vetapp/features/inventory/presentation/screens/inventario_screen.dart';
import 'package:vetapp/features/inventory/presentation/screens/producto_detail_screen.dart';
import 'package:vetapp/features/inventory/presentation/screens/producto_form_screen.dart';
import 'package:vetapp/features/patients/presentation/providers/mascotas_providers.dart';
import 'package:vetapp/features/team/domain/miembro.dart';
import 'package:vetapp/features/team/presentation/providers/team_providers.dart';
import 'package:vetapp/features/vaccination/presentation/providers/vacuna_providers.dart';
import 'package:vetapp/main.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_citas.dart';
import 'helpers/fake_clientes.dart';
import 'helpers/fake_inventario.dart';
import 'helpers/fake_mascotas.dart';
import 'helpers/fake_plan.dart';
import 'helpers/fake_recordatorios.dart';
import 'helpers/fake_team.dart';
import 'helpers/fake_vacunas.dart';

/// G5: `/inventario` y `/inventario/nuevo` son rutas raíz apiladas sobre el
/// `StatefulShellRoute`. Usa el `routerProvider` real (con `AppShell`), no el
/// `routerHarness` plano que ocultaría una página de shell duplicada.

Widget _app({FakeInventarioRepository? inventario}) {
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
        inventario ?? FakeInventarioRepository(productos: [productoDePrueba()]),
      ),
      vacunaRepositoryProvider.overrideWithValue(FakeVacunaRepository()),
      clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 31, 17)),
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

Future<void> _abrirMas(
  WidgetTester tester, {
  FakeInventarioRepository? inventario,
}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(inventario: inventario));
  await tester.pumpAndSettle();
  _container(tester).read(routerProvider).go('/mas');
  await tester.pumpAndSettle();
  expect(_ubicacion(tester), '/mas');
}

void main() {
  testWidgets('Más > Inventario abre una sola página /inventario y Atrás '
      'vuelve a Más', (tester) async {
    await _abrirMas(tester);

    await tester.tap(find.text('Inventario'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(InventarioScreen), findsOneWidget);
    expect(_ubicacion(tester), '/inventario');

    _container(tester).read(routerProvider).pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_ubicacion(tester), '/mas');
    expect(find.byType(InventarioScreen), findsNothing);
  });

  testWidgets('Nuevo producto desde /inventario abre el formulario sin romper '
      'el Navigator y Atrás vuelve a la lista', (tester) async {
    await _abrirMas(tester);
    await tester.tap(find.text('Inventario'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo producto'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_ubicacion(tester), '/inventario/nuevo');
    expect(find.byType(ProductoFormScreen), findsOneWidget);

    _container(tester).read(routerProvider).pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_ubicacion(tester), '/inventario');
    expect(find.byType(InventarioScreen), findsOneWidget);
  });

  testWidgets('tocar una fila abre una sola página /inventario/p1 y Atrás '
      'vuelve a la lista; /inventario/nuevo sigue siendo el formulario', (
    tester,
  ) async {
    await _abrirMas(tester);
    await tester.tap(find.text('Inventario'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Amoxicilina'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_ubicacion(tester), '/inventario/p1');
    expect(find.byType(ProductoDetailScreen), findsOneWidget);

    _container(tester).read(routerProvider).pop();
    await tester.pumpAndSettle();
    expect(_ubicacion(tester), '/inventario');
    expect(find.byType(ProductoDetailScreen), findsNothing);
    expect(find.byType(InventarioScreen), findsOneWidget);

    _container(tester).read(routerProvider).push('/inventario/nuevo');
    await tester.pumpAndSettle();
    expect(find.byType(ProductoFormScreen), findsOneWidget);
    expect(find.byType(ProductoDetailScreen), findsNothing);
  });

  testWidgets('editar desde el detalle abre una sola página '
      '/inventario/p1/editar', (tester) async {
    await _abrirMas(tester);
    await tester.tap(find.text('Inventario'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Amoxicilina'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Editar producto'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_ubicacion(tester), '/inventario/p1/editar');
    expect(find.byType(ProductoFormScreen), findsOneWidget);
  });

  testWidgets('la fila de Más: icono, alto mínimo, chevron y orden entre '
      'Mi plan y Recordatorios', (tester) async {
    await _abrirMas(tester);

    final fila = find.ancestor(
      of: find.text('Inventario'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(
        of: fila,
        matching: find.byIcon(Icons.inventory_2_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: fila, matching: find.byIcon(Icons.chevron_right)),
      findsOneWidget,
    );
    expect(tester.getSize(fila).height, greaterThanOrEqualTo(56));

    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    expect(y('Mi plan'), lessThan(y('Inventario')));
    expect(y('Inventario'), lessThan(y('Recordatorios')));
  });

  testWidgets('Inicio > tarjeta de stock bajo abre una sola lista en Bajos y '
      'Atrás vuelve a Inicio', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        inventario: FakeInventarioRepository(
          productos: [
            productoDePrueba(id: 'a', nombre: 'Amoxicilina', cantidad: 0),
            productoDePrueba(id: 'b', nombre: 'Zinc', cantidad: 9),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    _container(tester).read(routerProvider).go('/inicio');
    await tester.pumpAndSettle();
    expect(_ubicacion(tester), '/inicio');

    await tester.tap(find.text('1 producto con stock bajo'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(InventarioScreen), findsOneWidget);
    expect(_ubicacion(tester), '/inventario');
    // Preseleccionó Bajos: Zinc (no bajo) no aparece en la lista.
    expect(find.text('Amoxicilina'), findsOneWidget);
    expect(find.text('Zinc'), findsNothing);

    _container(tester).read(routerProvider).pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_ubicacion(tester), '/inicio');
    expect(find.byType(InventarioScreen), findsNothing);
  });

  group('pill de Más', () {
    Finder pill(String texto) => find.text(texto);

    testWidgets('muestra "2 bajos" con trending_down y semántica compuesta', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _abrirMas(
        tester,
        inventario: FakeInventarioRepository(
          resumenData: const ResumenInventario(bajos: 2),
        ),
      );
      expect(pill('2 bajos'), findsOneWidget);
      final fila = find.ancestor(
        of: find.text('Inventario'),
        matching: find.byType(Card),
      );
      expect(
        find.descendant(of: fila, matching: find.byIcon(Icons.trending_down)),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Inventario, 2 bajos'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('singular y sin pill con 0 bajos', (tester) async {
      await _abrirMas(
        tester,
        inventario: FakeInventarioRepository(
          resumenData: const ResumenInventario(bajos: 1),
        ),
      );
      expect(pill('1 bajo'), findsOneWidget);
    });

    testWidgets('sin bajos no hay pill', (tester) async {
      await _abrirMas(tester, inventario: FakeInventarioRepository());
      expect(find.textContaining('bajo'), findsNothing);
      expect(find.byIcon(Icons.trending_down), findsNothing);
    });

    testWidgets('con error la fila queda sin pill', (tester) async {
      await _abrirMas(
        tester,
        inventario: FakeInventarioRepository(errorResumen: Exception('red')),
      );
      expect(find.text('Inventario'), findsOneWidget);
      expect(find.byIcon(Icons.trending_down), findsNothing);
    });

    testWidgets('tras un ajuste el pill y la tarjeta se refrescan', (
      tester,
    ) async {
      final producto = productoDePrueba(id: 'a', cantidad: 2, minimo: 2);
      final repo = FakeInventarioRepository(productos: [producto]);
      await _abrirMas(tester, inventario: repo);
      expect(find.textContaining('bajo'), findsNothing);

      await _container(tester)
          .read(inventarioActionsProvider)
          .ajustar(producto: producto, delta: -1, motivo: MotivoMovimiento.uso);
      await tester.pumpAndSettle();
      expect(pill('1 bajo'), findsOneWidget);
    });
  });
}
