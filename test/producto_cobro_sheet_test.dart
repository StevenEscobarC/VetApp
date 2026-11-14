import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vetapp/features/billing/presentation/widgets/producto_cobro_sheet.dart';
import 'package:vetapp/features/inventory/domain/entities/producto.dart';
import 'package:vetapp/features/inventory/presentation/providers/inventario_providers.dart';
import 'package:vetapp/features/inventory/presentation/widgets/insignia_stock.dart';

import 'helpers/fake_inventario.dart';
import 'helpers/fake_plan.dart';
import 'helpers/router_harness.dart';

final _amox = productoDePrueba(cantidad: 3, precioVentaCop: 85000);
final _gasas = productoDePrueba(
  id: 'p2',
  nombre: 'Gasas',
  unidad: Unidad.unidad,
  cantidad: 10,
  categoria: CategoriaProducto.insumo,
);

class _Resultado {
  Producto? producto;
  bool cerrado = false;
}

Future<_Resultado> _abrir(
  WidgetTester tester, {
  bool esCuentaCobro = true,
  List<Producto>? productos,
  FakeInventarioRepository? repo,
  List<Override> extra = const [],
}) async {
  final r = _Resultado();
  final inv = repo ?? FakeInventarioRepository(productos: productos);
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    routerHarness(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  r.producto = await showProductoCobroSheet(
                    context,
                    esCuentaCobro: esCuentaCobro,
                  );
                  r.cerrado = true;
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ],
      overrides: <Override>[
        ...planOverrides(),
        inventarioRepositoryProvider.overrideWithValue(inv),
        ...extra,
      ],
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return r;
}

void main() {
  testWidgets('encabezado, búsqueda con autofocus que filtra y sin resultados', (
    tester,
  ) async {
    await _abrir(tester, productos: [_gasas, _amox]);
    expect(find.text('Agregar producto'), findsOneWidget);
    final campo = tester.widget<TextField>(find.byType(TextField));
    expect(campo.autofocus, isTrue);
    expect(campo.decoration?.hintText, 'Buscar producto');

    // A–Z.
    final yAmox = tester.getTopLeft(find.text('Amoxicilina')).dy;
    final yGasas = tester.getTopLeft(find.text('Gasas')).dy;
    expect(yAmox, lessThan(yGasas));

    await tester.enterText(find.byType(TextField), 'amox');
    await tester.pumpAndSettle();
    expect(find.text('Amoxicilina'), findsOneWidget);
    expect(find.text('Gasas'), findsNothing);

    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pumpAndSettle();
    expect(find.text('No encontramos productos con «xyz»'), findsOneWidget);
  });

  testWidgets('filas: existencias y precio, o Sin precio', (tester) async {
    await _abrir(tester, productos: [_amox, _gasas]);
    expect(find.text('Quedan 3 frascos · \$ 85.000'), findsOneWidget);
    expect(find.text('Quedan 10 unidades · Sin precio'), findsOneWidget);
  });

  testWidgets('cuenta de cobro: agotado no se puede elegir', (tester) async {
    final r = await _abrir(
      tester,
      productos: [productoDePrueba(cantidad: 0, precioVentaCop: 85000)],
    );
    expect(find.byType(InsigniaStock), findsOneWidget);
    expect(find.text('Agotado'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Amoxicilina, agotado, no disponible'),
      findsOneWidget,
    );
    await tester.tap(find.text('Amoxicilina'));
    await tester.pumpAndSettle();
    expect(r.cerrado, isFalse);
    expect(find.text('Agregar producto'), findsOneWidget);
  });

  testWidgets('cotización: agotado sí se puede elegir', (tester) async {
    final agotado = productoDePrueba(cantidad: 0, precioVentaCop: 85000);
    final r = await _abrir(tester, esCuentaCobro: false, productos: [agotado]);
    await tester.tap(find.text('Amoxicilina'));
    await tester.pumpAndSettle();
    expect(r.cerrado, isTrue);
    expect(r.producto?.id, 'p1');
  });

  testWidgets('tocar una fila cierra la hoja y devuelve el producto', (
    tester,
  ) async {
    final r = await _abrir(tester, productos: [_amox, _gasas]);
    await tester.tap(find.text('Gasas'));
    await tester.pumpAndSettle();
    expect(r.cerrado, isTrue);
    expect(r.producto?.id, 'p2');
    expect(find.text('Agregar producto'), findsNothing);
  });

  testWidgets('cargando: 4 filas esqueleto', (tester) async {
    final pendiente = Completer<List<Producto>>();
    await _abrir(
      tester,
      extra: [productosProvider.overrideWith((ref) => pendiente.future)],
    );
    expect(
      find.byKey(const ValueKey('esqueleto-producto')),
      findsNWidgets(4),
    );
  });

  testWidgets('error: mensaje y Reintentar vuelve a pedir', (tester) async {
    final repo = FakeInventarioRepository(errorProductos: Exception('x'));
    await _abrir(tester, repo: repo);
    expect(find.text('No pudimos cargar el inventario.'), findsOneWidget);
    final antes = repo.llamadas.where((l) => l.metodo == 'productos').length;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    final despues = repo.llamadas.where((l) => l.metodo == 'productos').length;
    expect(despues, greaterThan(antes));
  });

  testWidgets('inventario vacío', (tester) async {
    await _abrir(tester, productos: const []);
    expect(
      find.text('Aún no tienes productos en el inventario.'),
      findsOneWidget,
    );
  });

  testWidgets('nunca lista archivados', (tester) async {
    final archivado = Producto(
      id: 'p3',
      clinicaId: 'c1',
      nombre: 'Viejo',
      categoria: CategoriaProducto.otro,
      unidad: Unidad.unidad,
      cantidad: 4,
      minimo: 1,
      archivado: true,
    );
    await _abrir(tester, productos: [_amox, archivado]);
    expect(find.text('Viejo'), findsNothing);
    expect(find.text('Amoxicilina'), findsOneWidget);
  });
}
