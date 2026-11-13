import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/core/utils/compartir.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/inventory/domain/entities/producto.dart';
import 'package:vetapp/features/inventory/presentation/inventario_routes.dart';
import 'package:vetapp/features/inventory/presentation/providers/inventario_providers.dart';
import 'package:vetapp/features/inventory/presentation/screens/inventario_screen.dart';
import 'package:vetapp/features/inventory/presentation/widgets/insignia_stock.dart';
import 'package:vetapp/features/inventory/presentation/widgets/resumen_bajos_strip.dart';
import 'package:vetapp/features/plan/domain/mi_plan.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_compartir.dart';
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

Widget _app(
  FakeInventarioRepository repo, {
  MiPlan? plan,
  bool bajos = false,
  FakeCompartidor? compartidor,
}) => routerHarness(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => InventarioScreen(filtroBajosInicial: bajos),
    ),
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
    if (compartidor != null) compartidorProvider.overrideWithValue(compartidor),
  ],
);

Future<void> _abrir(
  WidgetTester tester,
  FakeInventarioRepository repo, {
  MiPlan? plan,
  bool bajos = false,
  FakeCompartidor? compartidor,
}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _app(repo, plan: plan, bajos: bajos, compartidor: compartidor),
  );
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
    // La tira de bajos también usa trending_down: se acota a la insignia.
    expect(
      find.descendant(
        of: find.byType(InsigniaStock),
        matching: find.byIcon(Icons.trending_down),
      ),
      findsOneWidget,
    );
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

  group('filtros', () {
    testWidgets('chips con conteos', (tester) async {
      await _abrir(tester, _repoTodos());
      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('Bajos (2)'), findsOneWidget);
      expect(find.text('Vence pronto (2)'), findsOneWidget);
    });

    testWidgets('sin productos bajos el chip se lee solo Bajos', (
      tester,
    ) async {
      await _abrir(
        tester,
        FakeInventarioRepository(productos: [_suero, _alcohol]),
      );
      expect(find.text('Bajos'), findsOneWidget);
      expect(find.text('Vence pronto'), findsOneWidget);
    });

    testWidgets('Bajos solo cantidad < mínimo, A-Z, sin borde ni mínimo 0', (
      tester,
    ) async {
      await _abrir(tester, _repoTodos());
      await tester.tap(find.text('Bajos (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Amoxicilina'), findsOneWidget);
      expect(find.text('Gasas'), findsOneWidget);
      expect(find.text('Suero'), findsNothing);
      expect(find.text('Alcohol'), findsNothing);
      expect(find.text('Zinc'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Amoxicilina')).dy,
        lessThan(tester.getTopLeft(find.text('Gasas')).dy),
      );
    });

    testWidgets('Vence pronto incluye vencidos y ordena por vencimiento', (
      tester,
    ) async {
      await _abrir(tester, _repoTodos());
      await tester.tap(find.text('Vence pronto (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Gasas'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Zinc')).dy,
        lessThan(tester.getTopLeft(find.text('Vacuna')).dy),
      );
    });

    testWidgets('filtroBajosInicial arranca en Bajos', (tester) async {
      await _abrir(tester, _repoTodos(), bajos: true);
      expect(find.text('Amoxicilina'), findsOneWidget);
      expect(find.text('Zinc'), findsNothing);
    });

    testWidgets('la ruta /inventario?filtro=bajos arranca en Bajos', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        routerHarness(
          initialLocation: '/inventario?filtro=bajos',
          routes: inventarioRoutes,
          overrides: [
            ...planOverrides(),
            authProfileProvider.overrideWith(
              () => FakeAuthProfileNotifier(profile: vetProfile),
            ),
            inventarioRepositoryProvider.overrideWithValue(_repoTodos()),
            clockProvider.overrideWithValue(() => _hoy),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Zinc'), findsNothing);
      expect(find.text('Gasas'), findsOneWidget);
    });

    testWidgets('tira: conteo, Ver bajos selecciona Bajos; se oculta con '
        'búsqueda', (tester) async {
      await _abrir(tester, _repoTodos());
      expect(find.byType(ResumenBajosStrip), findsOneWidget);
      expect(find.text('2 productos con stock bajo'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'a');
      await tester.pumpAndSettle();
      expect(find.byType(ResumenBajosStrip), findsNothing);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(find.byType(ResumenBajosStrip), findsOneWidget);

      await tester.tap(find.text('Ver bajos'));
      await tester.pumpAndSettle();
      expect(find.byType(ResumenBajosStrip), findsNothing);
      expect(find.text('Zinc'), findsNothing);
      expect(find.text('Gasas'), findsOneWidget);
    });

    testWidgets('tira en singular', (tester) async {
      await _abrir(
        tester,
        FakeInventarioRepository(productos: [_amoxi, _suero]),
      );
      expect(find.text('1 producto con stock bajo'), findsOneWidget);
    });

    testWidgets('sin bajos no hay tira', (tester) async {
      await _abrir(
        tester,
        FakeInventarioRepository(productos: [_suero, _alcohol]),
      );
      expect(find.byType(ResumenBajosStrip), findsNothing);
    });

    testWidgets('estados vacíos de cada filtro', (tester) async {
      await _abrir(
        tester,
        FakeInventarioRepository(productos: [_suero, _alcohol]),
      );
      await tester.tap(find.text('Bajos'));
      await tester.pumpAndSettle();
      expect(find.text('Nada por reabastecer'), findsOneWidget);
      expect(
        find.text('Todos tus productos están en el mínimo o por encima.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

      await tester.tap(find.text('Vence pronto'));
      await tester.pumpAndSettle();
      expect(find.text('Nada por vencer pronto'), findsOneWidget);
      expect(
        find.text('Ningún producto vence en los próximos 30 días.'),
        findsOneWidget,
      );
    });
  });
}
