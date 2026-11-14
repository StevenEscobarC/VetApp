import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vetapp/features/inventory/domain/entities/movimiento_stock.dart';
import 'package:vetapp/features/inventory/domain/entities/producto.dart';
import 'package:vetapp/features/inventory/presentation/widgets/movimiento_tile.dart';

import 'helpers/router_harness.dart';

MovimientoStock _mov({
  required int delta,
  required MotivoMovimiento motivo,
  String origen = 'ajuste',
  String? nota,
}) => MovimientoStock(
  id: 'm1',
  productoId: 'p1',
  delta: delta,
  cantidadResultante: 4,
  motivo: motivo,
  origen: origen,
  nota: nota,
  autorNombre: 'Ana',
  creadoEn: DateTime(2026, 11, 13, 15, 30),
);

Future<void> _montar(
  WidgetTester tester,
  MovimientoStock m, {
  Unidad unidad = Unidad.frasco,
}) async {
  await tester.pumpWidget(
    routerHarness(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: MovimientoTile(movimiento: m, unidad: unidad),
          ),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('kOrigenCobro es el valor interno del origen de cobro', () {
    expect(kOrigenCobro, 'factura');
  });

  testWidgets('venta por cuenta de cobro: "−3 frascos · Cuenta de cobro '
      'CC-0012"', (tester) async {
    await _montar(
      tester,
      _mov(
        delta: -3,
        motivo: MotivoMovimiento.venta,
        origen: kOrigenCobro,
        nota: 'CC-0012',
      ),
    );
    expect(find.text('−3 frascos · Cuenta de cobro CC-0012'), findsOneWidget);
    expect(find.textContaining('Venta'), findsNothing);
    expect(find.textContaining(RegExp('actura')), findsNothing);
  });

  testWidgets('anulación: "+3 frascos · Anulada CC-0012"', (tester) async {
    await _montar(
      tester,
      _mov(
        delta: 3,
        motivo: MotivoMovimiento.deshacer,
        origen: kOrigenCobro,
        nota: 'Anulada CC-0012',
      ),
    );
    expect(find.text('+3 frascos · Anulada CC-0012'), findsOneWidget);
    expect(find.textContaining('Ajuste deshecho'), findsNothing);
  });

  testWidgets('origen de cobro sin nota: "· Cuenta de cobro"', (tester) async {
    await _montar(
      tester,
      _mov(delta: -1, motivo: MotivoMovimiento.venta, origen: kOrigenCobro),
    );
    expect(find.text('−1 frasco · Cuenta de cobro'), findsOneWidget);
  });

  testWidgets('ajustes manuales conservan su título', (tester) async {
    await _montar(tester, _mov(delta: -1, motivo: MotivoMovimiento.uso));
    expect(find.text('−1 frasco · Uso'), findsOneWidget);
    await _montar(tester, _mov(delta: 2, motivo: MotivoMovimiento.deshacer));
    expect(find.text('+2 frascos · Ajuste deshecho'), findsOneWidget);
  });

  testWidgets('subtítulo intacto y sin acción al tocar', (tester) async {
    await _montar(
      tester,
      _mov(
        delta: -3,
        motivo: MotivoMovimiento.venta,
        origen: kOrigenCobro,
        nota: 'CC-0012',
      ),
    );
    expect(find.textContaining('Quedaron 4 · 13/11/2026'), findsOneWidget);
    expect(find.textContaining('· Ana'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MovimientoTile),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(MovimientoTile),
        matching: find.byType(GestureDetector),
      ),
      findsNothing,
    );
    expect(find.text('Deshacer'), findsNothing);
  });
}
