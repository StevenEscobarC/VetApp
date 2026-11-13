import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/inventory/domain/entities/producto.dart';
import 'package:vetapp/features/inventory/presentation/providers/inventario_providers.dart';
import 'package:vetapp/features/inventory/presentation/screens/inventario_screen.dart';
import 'package:vetapp/features/inventory/presentation/widgets/insignia_stock.dart';
import 'package:vetapp/features/plan/domain/mi_plan.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_inventario.dart';
import 'helpers/fake_plan.dart';
import 'helpers/router_harness.dart';

// "Hoy" en Bogotá: 31/10/2026.
final _hoy = DateTime.utc(2026, 10, 31, 17);

final _zinc = productoDePrueba(
  id: 'zinc',
  nombre: 'Zinc',
  vencimiento: DateTime(2026, 10, 30),
);
final _amoxi = productoDePrueba(
  id: 'amoxi',
  nombre: 'Amoxicilina',
  cantidad: 1,
  minimo: 2,
);
final _gasas = productoDePrueba(
  id: 'gasas',
  nombre: 'Gasas',
  unidad: Unidad.caja,
  cantidad: 0,
  minimo: 3,
);
final _suero = productoDePrueba(
  id: 'suero',
  nombre: 'Suero',
  cantidad: 2,
  minimo: 2,
);
final _alcohol = productoDePrueba(
  id: 'alcohol',
  nombre: 'Alcohol',
  cantidad: 0,
  minimo: 0,
);
final _vacuna = productoDePrueba(
  id: 'vacuna',
  nombre: 'Vacuna',
  vencimiento: DateTime(2026, 11, 10),
);

Widget _app(FakeInventarioRepository repo, {MiPlan? plan}) => routerHarness(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, _) => const InventarioScreen()),
    GoRoute(
      path: '/inventario/nuevo',
      builder: (_, _) => const Scaffold(body: Text('PANTALLA NUEVO')),
    ),
  ],
  overrides: [
    ...planOverrides(plan: plan),
    authProfileProvider.overrideWith(
      () => FakeAuthProfileNotifier(profile: vetProfile),
    ),
    inventarioRepositoryProvider.overrideWithValue(repo),
    clockProvider.overrideWithValue(() => _hoy),
  ],
);

Future<void> _abrir(
  WidgetTester tester,
  FakeInventarioRepository repo, {
  MiPlan? plan,
}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(repo, plan: plan));
  await tester.pumpAndSettle();
}

FakeInventarioRepository _repoTodos() => FakeInventarioRepository(
  productos: [_zinc, _amoxi, _gasas, _suero, _alcohol, _vacuna],
);

void main() {
  testWidgets('lista A-Z con insignias por estado y línea de meta', (
    tester,
  ) async {
    await _abrir(tester, _repoTodos());

    final orden = [
      'Alcohol',
      'Amoxicilina',
      'Gasas',
      'Suero',
      'Vacuna',
      'Zinc',
    ];
    for (var i = 0; i < orden.length - 1; i++) {
      expect(
        tester.getTopLeft(find.text(orden[i])).dy,
        lessThan(tester.getTopLeft(find.text(orden[i + 1])).dy),
      );
    }

    // Una sola insignia de cada tipo, con su icono.
    expect(find.text('Bajo'), findsOneWidget);
    expect(find.byIcon(Icons.trending_down), findsOneWidget);
    expect(find.text('Agotado'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Vencido'), findsOneWidget);
    expect(find.byIcon(Icons.event_busy), findsOneWidget);
    expect(find.text('Vence pronto'), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsOneWidget);
    expect(find.byType(InsigniaStock), findsNWidgets(4));

    // Gasas agotada no suma "Bajo"; Suero y Alcohol no llevan insignia.
    final gasas = find.ancestor(
      of: find.text('Gasas'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: gasas, matching: find.byType(InsigniaStock)),
      findsOneWidget,
    );
    for (final n in ['Suero', 'Alcohol']) {
      final card = find.ancestor(of: find.text(n), matching: find.byType(Card));
      expect(
        find.descendant(of: card, matching: find.byType(InsigniaStock)),
        findsNothing,
      );
    }

    // Meta: "Vence" solo con vencimiento.
    expect(find.text('Mínimo 2 · Vence 10/11/2026'), findsOneWidget);
    expect(find.text('Mínimo 2 · Vence 30/10/2026'), findsOneWidget);
    expect(find.text('Mínimo 3'), findsOneWidget);
    expect(find.text('Mínimo 0'), findsOneWidget);
  });

  testWidgets('cantidad con puntos de miles y unidad en singular o plural', (
    tester,
  ) async {
    await _abrir(
      tester,
      FakeInventarioRepository(
        productos: [
          productoDePrueba(id: 'a', nombre: 'Granel', cantidad: 1000000),
          productoDePrueba(id: 'b', nombre: 'Uno', cantidad: 1),
        ],
      ),
    );
    expect(find.text('1.000.000'), findsOneWidget);
    expect(find.text('frascos'), findsOneWidget);
    expect(find.text('frasco'), findsOneWidget);
  });

  group('InsigniaStock', () {
    for (final e in EstadoStock.values) {
      testWidgets('$e lleva icono + texto y semántica igual al texto', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: InsigniaStock(estado: e)),
          ),
        );
        final base = find.byType(InsigniaStock);
        expect(
          find.descendant(of: base, matching: find.byType(Icon)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: base, matching: find.byType(Text)),
          findsOneWidget,
        );
        final texto = tester
            .widget<Text>(
              find.descendant(of: base, matching: find.byType(Text)),
            )
            .data;
        expect(tester.getSemantics(base).label, texto);
        semantics.dispose();
      });
    }
  });

  testWidgets('buscar filtra localmente y sin coincidencias lo dice', (
    tester,
  ) async {
    await _abrir(tester, _repoTodos());

    await tester.enterText(find.byType(TextField), 'amox');
    await tester.pumpAndSettle();
    expect(find.text('Amoxicilina'), findsOneWidget);
    expect(find.text('Gasas'), findsNothing);
    expect(find.text('Zinc'), findsNothing);

    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pumpAndSettle();
    expect(find.text('No encontramos productos con «xyz»'), findsOneWidget);
    expect(
      find.text('Revisa el nombre o crea un producto nuevo.'),
      findsOneWidget,
    );
  });

  testWidgets('lista vacía: copia de escritura y de solo lectura', (
    tester,
  ) async {
    await _abrir(tester, FakeInventarioRepository());
    expect(find.text('Aún no tienes productos'), findsOneWidget);
  });

  testWidgets('lista vacía en solo lectura', (tester) async {
    await _abrir(tester, FakeInventarioRepository(), plan: planSoloLectura);
    expect(find.text('Aún no hay productos'), findsOneWidget);
    expect(
      find.text('Tu clínica todavía no ha registrado productos.'),
      findsOneWidget,
    );
  });

  testWidgets('error: mensaje y Reintentar vuelve a pedir los productos', (
    tester,
  ) async {
    final repo = FakeInventarioRepository(errorProductos: Exception('red'));
    await _abrir(tester, repo);
    expect(
      find.text('No pudimos cargar el inventario. Intenta de nuevo.'),
      findsOneWidget,
    );
    final antes = repo.llamadas.where((l) => l.metodo == 'productos').length;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    final despues = repo.llamadas.where((l) => l.metodo == 'productos').length;
    expect(despues, greaterThan(antes));
  });

  testWidgets('FAB Nuevo producto navega a /inventario/nuevo', (tester) async {
    await _abrir(tester, _repoTodos());
    expect(find.byIcon(Icons.add), findsOneWidget);
    await tester.tap(find.text('Nuevo producto'));
    await tester.pumpAndSettle();
    expect(find.text('PANTALLA NUEVO'), findsOneWidget);
  });

  testWidgets('en solo lectura el FAB lleva candado, semántica bloqueada y '
      'abre la hoja sin navegar', (tester) async {
    final semantics = tester.ensureSemantics();
    await _abrir(tester, _repoTodos(), plan: planSoloLectura);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNothing);
    expect(
      tester.getSemantics(find.byType(FloatingActionButton)).label,
      'Nuevo producto, bloqueado, solo lectura',
    );

    await tester.tap(find.text('Nuevo producto'));
    await tester.pumpAndSettle();
    expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
    expect(find.text('PANTALLA NUEVO'), findsNothing);
    semantics.dispose();
  });
}
