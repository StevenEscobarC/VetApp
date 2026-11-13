import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/core/errors/limite_plan.dart';
import 'package:vetapp/core/widgets/buttons/app_button.dart';
import 'package:vetapp/core/widgets/chips/app_filter_chip.dart';
import 'package:vetapp/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/inventory/domain/entities/producto.dart';
import 'package:vetapp/features/inventory/domain/inventario_failure.dart';
import 'package:vetapp/features/inventory/presentation/providers/inventario_providers.dart';
import 'package:vetapp/features/inventory/presentation/screens/producto_form_screen.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_inventario.dart';
import 'helpers/fake_plan.dart';
import 'helpers/router_harness.dart';

Widget _app(FakeInventarioRepository repo) => routerHarness(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, _) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => context.push('/nuevo'),
            child: const Text('ABRIR'),
          ),
        ),
      ),
    ),
    GoRoute(path: '/nuevo', builder: (_, _) => const ProductoFormScreen()),
  ],
  overrides: [
    ...planOverrides(),
    authProfileProvider.overrideWith(
      () => FakeAuthProfileNotifier(profile: vetProfile),
    ),
    inventarioRepositoryProvider.overrideWithValue(repo),
  ],
);

Future<void> _abrir(WidgetTester tester, FakeInventarioRepository repo) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(repo));
  await tester.pumpAndSettle();
  await tester.tap(find.text('ABRIR'));
  await tester.pumpAndSettle();
}

Finder _campo(int i) => find.byType(TextFormField).at(i);
Future<void> _escribir(WidgetTester tester, int i, String t) async {
  await tester.enterText(_campo(i), t);
  await tester.pump();
}

Future<void> _guardar(
  WidgetTester tester, [
  String boton = 'Guardar producto',
]) async {
  await tester.tap(find.widgetWithText(AppButton, boton));
  await tester.pumpAndSettle();
}

Future<void> _detalles(WidgetTester tester) async {
  await tester.tap(find.text('Agregar más detalles'));
  await tester.pumpAndSettle();
}

bool _seleccionado(WidgetTester tester, String label) => tester
    .widget<AppFilterChip>(find.widgetWithText(AppFilterChip, label))
    .selected;

Map<String, Object?> _ultimaCrear(FakeInventarioRepository repo) =>
    repo.llamadas.lastWhere((l) => l.metodo == 'crearProducto').args;

void main() {
  testWidgets('abre con Nombre enfocado, Unidad elegida, mínimo 2 y detalles '
      'colapsados', (tester) async {
    await _abrir(tester, FakeInventarioRepository());
    expect(find.text('Nuevo producto'), findsOneWidget);
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .focusNode
          .hasFocus,
      isTrue,
    );
    expect(_seleccionado(tester, 'Unidad'), isTrue);
    expect(_seleccionado(tester, 'Frasco'), isFalse);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Agregar más detalles'), findsOneWidget);
    expect(find.text('Categoría'), findsNothing);
    expect(find.text('Vencimiento (opcional)'), findsNothing);
    expect(find.text('Precio de venta (opcional)'), findsNothing);
  });

  testWidgets('guarda en un paso, vuelve y avisa', (tester) async {
    final repo = FakeInventarioRepository();
    await _abrir(tester, repo);
    await _escribir(tester, 0, 'Amoxicilina');
    await _escribir(tester, 1, '10');
    await _guardar(tester);

    final a = _ultimaCrear(repo);
    expect(a['nombre'], 'Amoxicilina');
    expect(a['unidad'], Unidad.unidad);
    expect(a['cantidad'], 10);
    expect(a['minimo'], 2);
    expect(a['categoria'], CategoriaProducto.medicamento);
    expect(a['vencimiento'], isNull);
    expect(a['precioVentaCop'], isNull);
    expect(a['costoCop'], isNull);
    expect(find.text('ABRIR'), findsOneWidget);
    expect(find.text('«Amoxicilina» agregado al inventario.'), findsOneWidget);
  });

  group('validación', () {
    testWidgets('campos obligatorios vacíos', (tester) async {
      final repo = FakeInventarioRepository();
      await _abrir(tester, repo);
      await _escribir(tester, 2, '');
      await _guardar(tester);
      expect(find.text('Escribe el nombre del producto.'), findsOneWidget);
      expect(find.text('Escribe la cantidad (puede ser 0).'), findsOneWidget);
      expect(find.text('Escribe el mínimo (puede ser 0).'), findsOneWidget);
      expect(repo.llamadas.where((l) => l.metodo == 'crearProducto'), isEmpty);
    });

    testWidgets('cantidad sobre el máximo', (tester) async {
      await _abrir(tester, FakeInventarioRepository());
      await _escribir(tester, 0, 'Gasas');
      await _escribir(tester, 1, '1000001');
      await _guardar(tester);
      expect(find.text('La cantidad máxima es 1.000.000.'), findsOneWidget);
    });

    testWidgets('precio con coma y vencimiento inválido', (tester) async {
      final repo = FakeInventarioRepository();
      await _abrir(tester, repo);
      await _escribir(tester, 0, 'Gasas');
      await _escribir(tester, 1, '3');
      await _detalles(tester);
      await _escribir(tester, 3, '31/02/2027');
      await _escribir(tester, 4, '85,5');
      await _guardar(tester);
      expect(find.text('Usa pesos enteros, sin coma.'), findsOneWidget);
      expect(
        find.text('Escribe una fecha válida (dd/mm/aaaa).'),
        findsOneWidget,
      );
      expect(repo.llamadas.where((l) => l.metodo == 'crearProducto'), isEmpty);
    });

    testWidgets('precio demasiado alto', (tester) async {
      await _abrir(tester, FakeInventarioRepository());
      await _escribir(tester, 0, 'Gasas');
      await _escribir(tester, 1, '3');
      await _detalles(tester);
      await _escribir(tester, 5, '100000001');
      await _guardar(tester);
      expect(find.text('El valor es demasiado alto.'), findsOneWidget);
    });

    testWidgets('un vencimiento futuro es válido', (tester) async {
      final repo = FakeInventarioRepository();
      await _abrir(tester, repo);
      await _escribir(tester, 0, 'Gasas');
      await _escribir(tester, 1, '3');
      await _detalles(tester);
      await _escribir(tester, 3, '15/12/2027');
      await _guardar(tester);
      expect(_ultimaCrear(repo)['vencimiento'], DateTime(2027, 12, 15));
    });
  });

  testWidgets('detalles: unidad, categoría y precio con puntos al salir', (
    tester,
  ) async {
    final repo = FakeInventarioRepository();
    await _abrir(tester, repo);
    await tester.tap(find.widgetWithText(AppFilterChip, 'Frasco'));
    await tester.pump();
    await _escribir(tester, 0, 'Suero');
    await _escribir(tester, 1, '4');
    await _detalles(tester);
    await tester.tap(find.widgetWithText(AppFilterChip, 'Insumo'));
    await tester.pump();
    await _escribir(tester, 4, '85000');
    await _escribir(tester, 5, '40000');
    expect(find.text('85.000'), findsOneWidget);
    await _guardar(tester);

    final a = _ultimaCrear(repo);
    expect(a['unidad'], Unidad.frasco);
    expect(a['categoria'], CategoriaProducto.insumo);
    expect(a['precioVentaCop'], 85000);
    expect(a['costoCop'], 40000);
  });

  testWidgets('nombre duplicado queda inline y el formulario se mantiene', (
    tester,
  ) async {
    final repo = FakeInventarioRepository(
      errorCrear: const InventarioFailure(
        'dup',
        tipo: ErrorInventario.nombreDuplicado,
      ),
    );
    await _abrir(tester, repo);
    await _escribir(tester, 0, 'Amoxicilina');
    await _escribir(tester, 1, '10');
    await _guardar(tester);
    expect(find.text('Ya tienes un producto con ese nombre.'), findsOneWidget);
    expect(find.text('Amoxicilina'), findsOneWidget);
    expect(find.text('ABRIR'), findsNothing);
  });

  testWidgets('LP004 abre la hoja de solo lectura y conserva lo escrito', (
    tester,
  ) async {
    final repo = FakeInventarioRepository(
      errorCrear: const InventarioFailure(
        'x',
        tipo: ErrorInventario.soloLectura,
        limite: LimitePlan.soloLectura,
      ),
    );
    await _abrir(tester, repo);
    await _escribir(tester, 0, 'Amoxicilina');
    await _escribir(tester, 1, '10');
    await _guardar(tester);
    expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
    expect(find.text('Amoxicilina'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('otro error muestra solo el mensaje traducido', (tester) async {
    final repo = FakeInventarioRepository(
      errorCrear: const InventarioFailure(
        'Sin conexión. Inténtalo de nuevo.',
        tipo: ErrorInventario.sinConexion,
      ),
    );
    await _abrir(tester, repo);
    await _escribir(tester, 0, 'Amoxicilina');
    await _escribir(tester, 1, '10');
    await _guardar(tester);
    expect(find.text('Sin conexión. Inténtalo de nuevo.'), findsOneWidget);
    expect(find.text('Amoxicilina'), findsOneWidget);
  });

  testWidgets('Guardar y agregar otro conserva unidad y categoría, limpia el '
      'resto y reenfoca el nombre', (tester) async {
    final repo = FakeInventarioRepository();
    await _abrir(tester, repo);
    await tester.tap(find.widgetWithText(AppFilterChip, 'Caja'));
    await tester.pump();
    await _escribir(tester, 0, 'Guantes');
    await _escribir(tester, 1, '8');
    await _detalles(tester);
    await tester.tap(find.widgetWithText(AppFilterChip, 'Insumo'));
    await tester.pump();
    await _escribir(tester, 4, '5000');
    await _guardar(tester, 'Guardar y agregar otro');

    expect(
      find.text('«Guantes» agregado. Puedes seguir con el siguiente.'),
      findsOneWidget,
    );
    expect(find.text('ABRIR'), findsNothing);
    expect(find.text('Guantes'), findsNothing);
    expect(_seleccionado(tester, 'Caja'), isTrue);
    expect(_seleccionado(tester, 'Insumo'), isTrue);
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .focusNode
          .hasFocus,
      isTrue,
    );
    await _escribir(tester, 0, 'Jeringas');
    await _escribir(tester, 1, '1');
    await _guardar(tester);
    final a = _ultimaCrear(repo);
    expect(a['nombre'], 'Jeringas');
    expect(a['unidad'], Unidad.caja);
    expect(a['categoria'], CategoriaProducto.insumo);
    expect(a['precioVentaCop'], isNull);
  });

  group('edición', () {
    final prod = productoDePrueba(
      cantidad: 5,
      minimo: 2,
      vencimiento: DateTime(2026, 12, 15),
      precioVentaCop: 85000,
      costoCop: 40000,
    );

    Future<void> abrirEditar(
      WidgetTester tester,
      FakeInventarioRepository repo, {
      AuthProfile perfil = vetProfile,
    }) async {
      tester.view.physicalSize = const Size(800, 3000);
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
                    onPressed: () => context.push('/inventario/p1/editar'),
                    child: const Text('ABRIR'),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/inventario/:id/editar',
              builder: (_, s) =>
                  ProductoFormScreen(productoId: s.pathParameters['id']),
            ),
          ],
          overrides: [
            ...planOverrides(),
            authProfileProvider.overrideWith(
              () => FakeAuthProfileNotifier(profile: perfil),
            ),
            inventarioRepositoryProvider.overrideWithValue(repo),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('ABRIR'));
      await tester.pumpAndSettle();
    }

    Map<String, Object?> ultimaActualizar(FakeInventarioRepository r) =>
        r.llamadas.lastWhere((l) => l.metodo == 'actualizarProducto').args;

    testWidgets('admin: prellena, muestra unidad de solo lectura y guarda el '
        'registro completo', (tester) async {
      final repo = FakeInventarioRepository(productos: [prod]);
      await abrirEditar(tester, repo);

      expect(find.text('Editar producto'), findsOneWidget);
      expect(find.text('Más detalles'), findsOneWidget);
      expect(find.text('Guardar cambios'), findsOneWidget);
      expect(find.text('Guardar producto'), findsNothing);
      expect(find.text('Guardar y agregar otro'), findsNothing);
      expect(find.text('Cantidad inicial'), findsNothing);
      // Unidad: fila de solo lectura, sin chips de unidad.
      expect(find.text('Unidad de conteo'), findsOneWidget);
      expect(find.text('Frasco'), findsOneWidget);
      expect(find.text('No se puede cambiar.'), findsOneWidget);
      expect(find.widgetWithText(AppFilterChip, 'Frasco'), findsNothing);
      expect(
        find.text('Para cambiar la cantidad usa Ajustar stock en el detalle.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Solo el administrador puede cambiar el mínimo y los '
          'precios.',
        ),
        findsNothing,
      );
      expect(find.widgetWithText(TextFormField, 'Amoxicilina'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '15/12/2026'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '85.000'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '40.000'), findsOneWidget);

      await _escribir(tester, 0, 'Amoxicilina 500');
      await _escribir(tester, 1, '4');
      await _guardar(tester, 'Guardar cambios');

      final a = ultimaActualizar(repo);
      expect(a['id'], 'p1');
      expect(a['nombre'], 'Amoxicilina 500');
      expect(a['minimo'], 4);
      expect(a['categoria'], CategoriaProducto.medicamento);
      expect(a['vencimiento'], DateTime(2026, 12, 15));
      expect(a['precioVentaCop'], 85000);
      expect(a['costoCop'], 40000);
      expect(find.text('ABRIR'), findsOneWidget);
      expect(find.text('Cambios guardados.'), findsOneWidget);
    });

    testWidgets('vaciar un precio lo envía como null', (tester) async {
      final repo = FakeInventarioRepository(productos: [prod]);
      await abrirEditar(tester, repo);
      await _escribir(tester, 3, '');
      await _guardar(tester, 'Guardar cambios');
      final a = ultimaActualizar(repo);
      expect(a['precioVentaCop'], isNull);
      expect(a['costoCop'], 40000);
    });

    testWidgets('colega: mínimo y precios son filas de solo lectura sin '
        'candado y se envían sin cambios', (tester) async {
      final repo = FakeInventarioRepository(productos: [prod]);
      await abrirEditar(tester, repo, perfil: vetColegaProfile);

      expect(
        find.text(
          'Solo el administrador puede cambiar el mínimo y los '
          'precios.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.lock_outline), findsNothing);
      expect(find.widgetWithText(TextFormField, '85.000'), findsNothing);
      expect(find.text('Stock mínimo'), findsOneWidget);
      expect(find.text('Precio de venta'), findsOneWidget);
      expect(find.text('Costo'), findsOneWidget);
      expect(find.text(r'$ 85.000'), findsOneWidget);
      expect(find.text(r'$ 40.000'), findsOneWidget);
      // Solo Nombre y Vencimiento son editables.
      expect(find.byType(TextFormField), findsNWidgets(2));

      await _escribir(tester, 0, 'Amoxicilina B');
      await _guardar(tester, 'Guardar cambios');

      final a = ultimaActualizar(repo);
      expect(a['nombre'], 'Amoxicilina B');
      expect(a['minimo'], 2);
      expect(a['precioVentaCop'], 85000);
      expect(a['costoCop'], 40000);
    });

    testWidgets('sinPermiso del servidor: snackbar y el formulario se '
        'queda', (tester) async {
      final repo = FakeInventarioRepository(
        productos: [prod],
        errorActualizar: const InventarioFailure(
          'x',
          tipo: ErrorInventario.sinPermiso,
        ),
      );
      await abrirEditar(tester, repo);
      await _guardar(tester, 'Guardar cambios');
      expect(
        find.text('Solo el administrador de la clínica puede hacer esto.'),
        findsOneWidget,
      );
      expect(find.text('Editar producto'), findsOneWidget);
    });

    testWidgets('nombre duplicado queda inline', (tester) async {
      final repo = FakeInventarioRepository(
        productos: [prod],
        errorActualizar: const InventarioFailure(
          'x',
          tipo: ErrorInventario.nombreDuplicado,
        ),
      );
      await abrirEditar(tester, repo);
      await _guardar(tester, 'Guardar cambios');
      expect(
        find.text('Ya tienes un producto con ese nombre.'),
        findsOneWidget,
      );
      expect(find.text('Editar producto'), findsOneWidget);
    });

    testWidgets('soloLectura del servidor abre la hoja del plan y conserva '
        'los datos', (tester) async {
      final repo = FakeInventarioRepository(
        productos: [prod],
        errorActualizar: const InventarioFailure(
          'x',
          tipo: ErrorInventario.soloLectura,
          limite: LimitePlan.soloLectura,
        ),
      );
      await abrirEditar(tester, repo);
      await _escribir(tester, 0, 'Otro nombre');
      await _guardar(tester, 'Guardar cambios');
      expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Otro nombre'), findsOneWidget);
    });

    testWidgets('nombre vacío no guarda', (tester) async {
      final repo = FakeInventarioRepository(productos: [prod]);
      await abrirEditar(tester, repo);
      await _escribir(tester, 0, '');
      await _guardar(tester, 'Guardar cambios');
      expect(find.text('Escribe el nombre del producto.'), findsOneWidget);
      expect(
        repo.llamadas.where((l) => l.metodo == 'actualizarProducto'),
        isEmpty,
      );
    });

    testWidgets('producto inexistente: no disponible', (tester) async {
      await abrirEditar(tester, FakeInventarioRepository());
      expect(find.text('Este producto ya no está disponible.'), findsOneWidget);
      expect(find.text('Guardar cambios'), findsNothing);
    });
  });
}
