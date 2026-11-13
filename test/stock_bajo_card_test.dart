import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/features/inventory/domain/entities/producto.dart';
import 'package:vetapp/features/inventory/presentation/providers/inventario_providers.dart';
import 'package:vetapp/features/inventory/presentation/widgets/stock_bajo_card.dart';

import 'helpers/fake_inventario.dart';
import 'helpers/router_harness.dart';

Widget _app(FakeInventarioRepository repo) => routerHarness(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const Scaffold(body: StockBajoCard()),
    ),
    GoRoute(
      path: '/inventario',
      builder: (_, state) => Text('INV ${state.uri.queryParameters['filtro']}'),
    ),
  ],
  overrides: [inventarioRepositoryProvider.overrideWithValue(repo)],
);

void main() {
  testWidgets('con 3 bajos muestra título, mensaje y semántica', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        FakeInventarioRepository(
          resumenData: const ResumenInventario(bajos: 3),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 productos con stock bajo'), findsOneWidget);
    expect(find.text('Revisa qué hay que reabastecer.'), findsOneWidget);
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
    expect(
      find.bySemanticsLabel('3 productos con stock bajo. Ver inventario.'),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byType(InkWell)).height,
      greaterThanOrEqualTo(56),
    );
    semantics.dispose();
  });

  testWidgets('con 1 bajo usa el singular', (tester) async {
    await tester.pumpWidget(
      _app(
        FakeInventarioRepository(
          resumenData: const ResumenInventario(bajos: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 producto con stock bajo'), findsOneWidget);
  });

  testWidgets('con 0 bajos no pinta nada', (tester) async {
    await tester.pumpWidget(_app(FakeInventarioRepository()));
    await tester.pumpAndSettle();
    expect(find.byType(StockBajoCard), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(StockBajoCard),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
    expect(tester.getSize(find.byType(StockBajoCard)), Size.zero);
  });

  testWidgets('cargando no pinta nada', (tester) async {
    await tester.pumpWidget(
      _app(
        FakeInventarioRepository(
          resumenData: const ResumenInventario(bajos: 3),
        ),
      ),
    );
    // Primer frame: el resumen aún no resolvió.
    expect(
      find.descendant(
        of: find.byType(StockBajoCard),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('con error no pinta nada', (tester) async {
    await tester.pumpWidget(
      _app(FakeInventarioRepository(errorResumen: Exception('red'))),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(StockBajoCard),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
    expect(tester.getSize(find.byType(StockBajoCard)), Size.zero);
  });

  testWidgets('tocar la tarjeta abre /inventario?filtro=bajos', (tester) async {
    await tester.pumpWidget(
      _app(
        FakeInventarioRepository(
          resumenData: const ResumenInventario(bajos: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(StockBajoCard));
    await tester.pumpAndSettle();
    expect(find.text('INV bajos'), findsOneWidget);
  });
}
