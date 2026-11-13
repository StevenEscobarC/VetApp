import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/core/theme/app_colors.dart';
import 'package:vetapp/core/widgets/buttons/app_button.dart';
import 'package:vetapp/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/inventory/domain/entities/movimiento_stock.dart';
import 'package:vetapp/features/inventory/domain/entities/producto.dart';
import 'package:vetapp/features/inventory/domain/inventario_failure.dart';
import 'package:vetapp/features/inventory/presentation/providers/inventario_providers.dart';
import 'package:vetapp/features/inventory/presentation/screens/producto_detail_screen.dart';
import 'package:vetapp/features/inventory/presentation/widgets/movimiento_tile.dart';
import 'package:vetapp/features/plan/domain/mi_plan.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_inventario.dart';
import 'helpers/fake_plan.dart';
import 'helpers/router_harness.dart';

final _hoy = DateTime.utc(2026, 10, 31);

Future<void> _abrir(
  WidgetTester tester,
  FakeInventarioRepository repo, {
  MiPlan? plan,
  AuthProfile? perfil,
  String id = 'p1',
}) async {
  tester.view.physicalSize = const Size(800, 4000);
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
                onPressed: () => context.push('/inventario/$id'),
                child: const Text('LISTA'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/inventario/:id',
          builder: (_, s) =>
              ProductoDetailScreen(productoId: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/inventario/:id/editar',
          builder: (_, _) => const Scaffold(body: Text('EDITAR')),
        ),
      ],
      overrides: [
        ...planOverrides(plan: plan),
        authProfileProvider.overrideWith(
          () => FakeAuthProfileNotifier(profile: perfil ?? vetProfile),
        ),
        inventarioRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 31, 17)),
      ],
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('LISTA'));
  await tester.pumpAndSettle();
}

Producto _amoxicilina({
  int cantidad = 5,
  DateTime? vencimiento,
  bool conVencimiento = true,
}) => productoDePrueba(
  cantidad: cantidad,
  minimo: 2,
  vencimiento: conVencimiento
      ? (vencimiento ?? _hoy.add(const Duration(days: 12)))
      : null,
  precioVentaCop: 85000,
  costoCop: 40000,
);

MovimientoStock _mov(
  int i, {
  int delta = 10,
  int quedaron = 15,
  MotivoMovimiento motivo = MotivoMovimiento.compra,
  String? autor = 'Ana',
}) => MovimientoStock(
  id: 'm$i',
  productoId: 'p1',
  delta: delta,
  cantidadResultante: quedaron,
  motivo: motivo,
  origen: 'ajuste',
  autorNombre: autor,
  creadoEn: DateTime(2026, 10, 31, 10, 5),
);

List<({String metodo, Map<String, Object?> args})> _movs(
  FakeInventarioRepository r,
) => r.llamadas.where((l) => l.metodo == 'moverStock').toList();

void main() {
  testWidgets('muestra encabezado, insignia y tarjeta Detalles', (
    tester,
  ) async {
    await _abrir(tester, FakeInventarioRepository(productos: [_amoxicilina()]));

    expect(find.text('Producto'), findsOneWidget);
    expect(find.text('Amoxicilina'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('frascos'), findsOneWidget);
    expect(find.text('Mínimo 2'), findsOneWidget);
    expect(find.text('Vence pronto'), findsOneWidget);
    expect(find.text('Categoría'), findsOneWidget);
    expect(find.text('Medicamento'), findsOneWidget);
    expect(find.text('Unidad de conteo'), findsOneWidget);
    expect(find.text('Frasco'), findsOneWidget);
    expect(find.text('Vencimiento'), findsOneWidget);
    expect(find.text('12/11/2026 · en 12 días'), findsOneWidget);
    expect(find.text('Precio de venta'), findsOneWidget);
    expect(find.text(r'$ 85.000'), findsOneWidget);
    expect(find.text('Costo'), findsOneWidget);
    expect(find.text(r'$ 40.000'), findsOneWidget);
  });

  testWidgets('las filas opcionales solo aparecen si aplican', (tester) async {
    await _abrir(
      tester,
      FakeInventarioRepository(productos: [productoDePrueba(cantidad: 5)]),
    );
    expect(find.text('Categoría'), findsOneWidget);
    expect(find.text('Vencimiento'), findsNothing);
    expect(find.text('Precio de venta'), findsNothing);
    expect(find.text('Costo'), findsNothing);
  });

  testWidgets('textos del vencimiento: hoy, mañana, venció hace N días', (
    tester,
  ) async {
    await _abrir(
      tester,
      FakeInventarioRepository(productos: [_amoxicilina(vencimiento: _hoy)]),
    );
    expect(find.text('31/10/2026 · hoy'), findsOneWidget);
  });

  testWidgets('vencimiento mañana', (tester) async {
    await _abrir(
      tester,
      FakeInventarioRepository(
        productos: [
          _amoxicilina(vencimiento: _hoy.add(const Duration(days: 1))),
        ],
      ),
    );
    expect(find.text('01/11/2026 · mañana'), findsOneWidget);
  });

  testWidgets('vencimiento pasado: venció hace 3 días + insignia Vencido', (
    tester,
  ) async {
    await _abrir(
      tester,
      FakeInventarioRepository(
        productos: [
          _amoxicilina(vencimiento: _hoy.subtract(const Duration(days: 3))),
        ],
      ),
    );
    expect(find.text('28/10/2026 · venció hace 3 días'), findsOneWidget);
    expect(find.text('Vencido'), findsOneWidget);
  });

  group('ajustes', () {
    testWidgets('Descontar 1 envía -1 con motivo Uso y ofrece Deshacer', (
      tester,
    ) async {
      final repo = FakeInventarioRepository(productos: [_amoxicilina()]);
      await _abrir(tester, repo);

      await tester.tap(find.text('Descontar 1'));
      await tester.pumpAndSettle();

      final m = _movs(repo).single.args;
      expect(m['delta'], -1);
      expect(m['motivo'], MotivoMovimiento.uso);
      expect(
        find.text('Descontaste 1 frasco de Amoxicilina. Ahora hay 4.'),
        findsOneWidget,
      );
      expect(find.text('Deshacer'), findsOneWidget);
      // La cantidad mostrada es la del servidor.
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('Descontar 1 queda deshabilitado con cantidad 0', (
      tester,
    ) async {
      final repo = FakeInventarioRepository(
        productos: [_amoxicilina(cantidad: 0)],
      );
      await _abrir(tester, repo);
      await tester.tap(find.text('Descontar 1'));
      await tester.pumpAndSettle();
      expect(_movs(repo), isEmpty);
    });

    testWidgets('Agregar stock abre la hoja con Compra', (tester) async {
      await _abrir(
        tester,
        FakeInventarioRepository(productos: [_amoxicilina()]),
      );
      await tester.tap(find.text('Agregar stock'));
      await tester.pumpAndSettle();
      expect(find.text('Ajustar stock'), findsOneWidget);
      expect(find.text('Cantidad que entra'), findsOneWidget);
    });

    testWidgets('Ajustar cantidad abre la hoja con Conteo', (tester) async {
      await _abrir(
        tester,
        FakeInventarioRepository(productos: [_amoxicilina()]),
      );
      await tester.tap(find.text('Ajustar cantidad'));
      await tester.pumpAndSettle();
      expect(find.text('Ajustar stock'), findsOneWidget);
      expect(find.text('Cantidad contada'), findsOneWidget);
    });

    testWidgets('tras ajustar, el historial se refresca con el nuevo '
        'movimiento', (tester) async {
      final repo = FakeInventarioRepository(productos: [_amoxicilina()]);
      await _abrir(tester, repo);
      expect(find.text('Aún no hay movimientos.'), findsOneWidget);
      await tester.tap(find.text('Descontar 1'));
      await tester.pumpAndSettle();
      expect(find.text('−1 frasco · Uso'), findsOneWidget);
    });
  });

  group('historial', () {
    testWidgets('formato de título y subtítulo, autor y "Veterinario"', (
      tester,
    ) async {
      final repo = FakeInventarioRepository(
        productos: [_amoxicilina()],
        movimientos: [
          _mov(1),
          _mov(
            2,
            delta: -3,
            quedaron: 7,
            motivo: MotivoMovimiento.uso,
            autor: null,
          ),
          _mov(3, delta: 5, quedaron: 5, motivo: MotivoMovimiento.alta),
          _mov(4, delta: 1, quedaron: 8, motivo: MotivoMovimiento.deshacer),
        ],
      );
      await _abrir(tester, repo);

      expect(find.text('Historial de movimientos'), findsOneWidget);
      expect(find.text('+10 frascos · Compra'), findsOneWidget);
      expect(find.text('−3 frascos · Uso'), findsOneWidget);
      expect(find.text('+5 frascos · Alta inicial'), findsOneWidget);
      expect(find.text('+1 frasco · Ajuste deshecho'), findsOneWidget);
      expect(
        find.text('Quedaron 15 · 31/10/2026 10:05 a. m. · Ana'),
        findsOneWidget,
      );
      expect(
        find.text('Quedaron 7 · 31/10/2026 10:05 a. m. · Veterinario'),
        findsOneWidget,
      );
    });

    testWidgets('flechas: success al entrar, textSecondary al salir, nunca '
        'rojo', (tester) async {
      final repo = FakeInventarioRepository(
        productos: [_amoxicilina()],
        movimientos: [
          _mov(1),
          _mov(2, delta: -3, motivo: MotivoMovimiento.uso),
        ],
      );
      await _abrir(tester, repo);
      Icon icono(IconData d) => tester.widget<Icon>(
        find.descendant(
          of: find.byType(MovimientoTile),
          matching: find.byIcon(d),
        ),
      );
      expect(icono(Icons.arrow_upward).color, AppColors.success);
      expect(icono(Icons.arrow_downward).color, AppColors.textSecondary);
    });

    testWidgets('exactamente 50 movimientos muestran el pie', (tester) async {
      final repo = FakeInventarioRepository(
        productos: [_amoxicilina()],
        movimientos: [for (var i = 0; i < 50; i++) _mov(i)],
      );
      await _abrir(tester, repo);
      await tester.scrollUntilVisible(
        find.text('Mostrando los últimos 50 movimientos.'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Mostrando los últimos 50 movimientos.'),
        findsOneWidget,
      );
    });

    testWidgets('menos de 50 no muestran el pie', (tester) async {
      final repo = FakeInventarioRepository(
        productos: [_amoxicilina()],
        movimientos: [_mov(1)],
      );
      await _abrir(tester, repo);
      expect(find.textContaining('Mostrando los últimos'), findsNothing);
    });

    testWidgets('sin movimientos: Aún no hay movimientos.', (tester) async {
      await _abrir(
        tester,
        FakeInventarioRepository(productos: [_amoxicilina()]),
      );
      expect(find.text('Aún no hay movimientos.'), findsOneWidget);
    });

    testWidgets('error del historial: mensaje + Reintentar y el encabezado '
        'sigue visible', (tester) async {
      final repo = FakeInventarioRepository(
        productos: [_amoxicilina()],
        errorMovimientos: Exception('red'),
      );
      await _abrir(tester, repo);
      expect(find.text('Amoxicilina'), findsOneWidget);
      expect(find.text('No pudimos cargar el historial.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(
        repo.llamadas.where((l) => l.metodo == 'movimientos').length,
        greaterThan(1),
      );
    });
  });

  group('estados de pantalla', () {
    testWidgets('error del producto: mensaje + Reintentar', (tester) async {
      final repo = FakeInventarioRepository(errorProducto: Exception('x'));
      await _abrir(tester, repo);
      expect(
        find.text('No pudimos cargar el producto. Intenta de nuevo.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(
        repo.llamadas.where((l) => l.metodo == 'producto').length,
        greaterThan(1),
      );
    });

    testWidgets('producto inexistente: no disponible + Volver al inventario', (
      tester,
    ) async {
      await _abrir(tester, FakeInventarioRepository());
      expect(find.text('Este producto ya no está disponible.'), findsOneWidget);
      await tester.tap(find.text('Volver al inventario'));
      await tester.pumpAndSettle();
      expect(find.text('LISTA'), findsOneWidget);
    });

    testWidgets('producto archivado: no disponible', (tester) async {
      final repo = FakeInventarioRepository(productos: [_amoxicilina()]);
      await repo.archivarProducto('p1');
      await _abrir(tester, repo);
      expect(find.text('Este producto ya no está disponible.'), findsOneWidget);
      expect(find.text('Descontar 1'), findsNothing);
    });
  });

  testWidgets('el icono de editar abre /inventario/:id/editar', (tester) async {
    await _abrir(tester, FakeInventarioRepository(productos: [_amoxicilina()]));
    await tester.tap(find.byTooltip('Editar producto'));
    await tester.pumpAndSettle();
    expect(find.text('EDITAR'), findsOneWidget);
  });

  testWidgets('solo lectura: candado + hoja del plan en editar y ajustes; el '
      'historial sigue visible', (tester) async {
    final semantics = tester.ensureSemantics();
    final repo = FakeInventarioRepository(
      productos: [_amoxicilina()],
      movimientos: [_mov(1)],
    );
    await _abrir(tester, repo, plan: planSoloLectura, perfil: vetColegaProfile);

    expect(find.byIcon(Icons.lock_outline), findsNWidgets(4));
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.text('+10 frascos · Compra'), findsOneWidget);
    for (final s in [
      'Editar producto',
      'Descontar 1',
      'Agregar stock',
      'Ajustar cantidad',
    ]) {
      expect(
        find.bySemanticsLabel('$s, bloqueado, solo lectura'),
        findsOneWidget,
        reason: s,
      );
    }

    for (final t in ['Descontar 1', 'Agregar stock', 'Ajustar cantidad']) {
      await tester.tap(find.text(t));
      await tester.pumpAndSettle();
      expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    }
    expect(_movs(repo), isEmpty);
    expect(find.text('Ajustar stock'), findsNothing);
    semantics.dispose();
  });

  group('archivar', () {
    Future<void> irAlBoton(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.text('Archivar producto'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
    }

    testWidgets(
      'el administrador ve el botón destructivo con archive_outlined',
      (tester) async {
        await _abrir(
          tester,
          FakeInventarioRepository(productos: [_amoxicilina()]),
        );
        await irAlBoton(tester);
        expect(find.byIcon(Icons.archive_outlined), findsOneWidget);
        expect(
          tester
              .widget<AppButton>(
                find.widgetWithText(AppButton, 'Archivar producto'),
              )
              .variant,
          AppButtonVariant.destructive,
        );
      },
    );

    testWidgets('un colega no ve Archivar producto', (tester) async {
      await _abrir(
        tester,
        FakeInventarioRepository(productos: [_amoxicilina()]),
        perfil: vetColegaProfile,
      );
      expect(find.text('Archivar producto'), findsNothing);
      expect(find.byIcon(Icons.archive_outlined), findsNothing);
    });

    testWidgets('el diálogo explica y Cancelar no hace nada', (tester) async {
      final repo = FakeInventarioRepository(productos: [_amoxicilina()]);
      await _abrir(tester, repo);
      await irAlBoton(tester);
      await tester.tap(find.text('Archivar producto'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          '«Amoxicilina» dejará de aparecer en tu inventario y no podrás '
          'ajustar su stock. El historial de movimientos se conserva. Esta '
          'acción no se puede deshacer desde la app.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(
        repo.llamadas.where((l) => l.metodo == 'archivarProducto'),
        isEmpty,
      );
      expect(find.text('Amoxicilina'), findsOneWidget);
    });

    testWidgets('Archivar conserva el historial, vuelve y deja de listarse', (
      tester,
    ) async {
      final repo = FakeInventarioRepository(
        productos: [_amoxicilina()],
        movimientos: [_mov(1)],
      );
      await _abrir(tester, repo);
      await irAlBoton(tester);
      await tester.tap(find.text('Archivar producto'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Archivar'));
      await tester.pumpAndSettle();

      expect(
        repo.llamadas.where((l) => l.metodo == 'archivarProducto').single.args,
        {'id': 'p1'},
      );
      expect(find.text('LISTA'), findsOneWidget);
      expect(find.text('«Amoxicilina» archivado.'), findsOneWidget);
      expect(await repo.productos(), isEmpty);
      // Nada se borra: el historial sigue en el repositorio.
      expect((await repo.movimientos('p1')).length, 1);
    });

    testWidgets('sinPermiso del servidor: snackbar y se queda', (tester) async {
      final repo = FakeInventarioRepository(
        productos: [_amoxicilina()],
        errorArchivar: const InventarioFailure(
          'x',
          tipo: ErrorInventario.sinPermiso,
        ),
      );
      await _abrir(tester, repo);
      await irAlBoton(tester);
      await tester.tap(find.text('Archivar producto'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Archivar'));
      await tester.pumpAndSettle();
      expect(
        find.text('Solo el administrador de la clínica puede hacer esto.'),
        findsOneWidget,
      );
      expect(find.text('LISTA'), findsNothing);
    });

    testWidgets('noDisponible: snackbar y vuelve a la lista', (tester) async {
      final repo = FakeInventarioRepository(
        productos: [_amoxicilina()],
        errorArchivar: const InventarioFailure(
          'x',
          tipo: ErrorInventario.noDisponible,
        ),
      );
      await _abrir(tester, repo);
      await irAlBoton(tester);
      await tester.tap(find.text('Archivar producto'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Archivar'));
      await tester.pumpAndSettle();
      expect(find.text('Ese producto ya no está disponible.'), findsOneWidget);
      expect(find.text('LISTA'), findsOneWidget);
    });

    testWidgets('solo lectura: candado y hoja del plan, sin diálogo', (
      tester,
    ) async {
      final repo = FakeInventarioRepository(productos: [_amoxicilina()]);
      await _abrir(tester, repo, plan: planSoloLectura);
      await irAlBoton(tester);
      expect(find.byIcon(Icons.archive_outlined), findsNothing);
      await tester.tap(find.text('Archivar producto'));
      await tester.pumpAndSettle();
      expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
      expect(
        repo.llamadas.where((l) => l.metodo == 'archivarProducto'),
        isEmpty,
      );
    });
  });
}
