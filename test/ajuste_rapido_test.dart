import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/core/errors/limite_plan.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/inventory/domain/entities/movimiento_stock.dart';
import 'package:vetapp/features/inventory/domain/entities/producto.dart';
import 'package:vetapp/features/inventory/domain/inventario_failure.dart';
import 'package:vetapp/features/inventory/presentation/providers/inventario_providers.dart';
import 'package:vetapp/features/inventory/presentation/screens/inventario_screen.dart';
import 'package:vetapp/features/plan/domain/mi_plan.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_inventario.dart';
import 'helpers/fake_plan.dart';
import 'helpers/router_harness.dart';

const _menos = ValueKey('ajuste-menos-uno');
const _mas = ValueKey('ajuste-mas');

/// Repo cuyo deshacer siempre falla con stock insuficiente (IN001).
class _RepoDeshacerFalla extends FakeInventarioRepository {
  _RepoDeshacerFalla({super.productos});

  @override
  Future<ResultadoAjuste> moverStock({
    required String productoId,
    required int delta,
    required MotivoMovimiento motivo,
    String? deshaceId,
  }) {
    if (motivo == MotivoMovimiento.deshacer) {
      throw const InventarioFailure(
        'x',
        tipo: ErrorInventario.stockInsuficiente,
      );
    }
    return super.moverStock(
      productoId: productoId,
      delta: delta,
      motivo: motivo,
      deshaceId: deshaceId,
    );
  }
}

FakeInventarioRepository _repo({
  int cantidad = 5,
  Object? errorMover,
}) => FakeInventarioRepository(
  productos: [productoDePrueba(cantidad: cantidad)],
  errorMover: errorMover,
);

Future<void> _abrir(
  WidgetTester tester,
  FakeInventarioRepository repo, {
  MiPlan? plan,
}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    routerHarness(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const InventarioScreen()),
      ],
      overrides: [
        ...planOverrides(plan: plan),
        authProfileProvider.overrideWith(
          () => FakeAuthProfileNotifier(profile: vetProfile),
        ),
        inventarioRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 31, 17)),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

List<({String metodo, Map<String, Object?> args})> _movs(
  FakeInventarioRepository r,
) => r.llamadas.where((l) => l.metodo == 'moverStock').toList();

void main() {
  testWidgets('-1 descuenta uno con motivo Uso, muestra la cantidad del '
      'servidor y Deshacer aplica el movimiento inverso', (tester) async {
    final repo = _repo();
    await _abrir(tester, repo);

    await tester.tap(find.byKey(_menos));
    await tester.pumpAndSettle();

    final m = _movs(repo);
    expect(m, hasLength(1));
    expect(m.single.args['delta'], -1);
    expect(m.single.args['motivo'], MotivoMovimiento.uso);
    expect(find.text('4'), findsOneWidget);
    expect(
      find.text('Descontaste 1 frasco de Amoxicilina. Ahora hay 4.'),
      findsOneWidget,
    );
    expect(find.text('Deshacer'), findsOneWidget);

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    final u = _movs(repo);
    expect(u, hasLength(2));
    expect(u.last.args['delta'], 1);
    expect(u.last.args['motivo'], MotivoMovimiento.deshacer);
    expect(u.last.args['deshaceId'], 'mov-1');
    expect(find.text('Ajuste deshecho. Ahora hay 5.'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('en vuelo ambos botones se deshabilitan, hay spinner de 20 px '
      'y un segundo toque no repite la llamada', (tester) async {
    final repo = _repo()..bloqueoMover = Completer<void>();
    await _abrir(tester, repo);

    await tester.tap(find.byKey(_menos));
    await tester.pump();

    expect(tester.widget<OutlinedButton>(find.byKey(_menos)).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(find.byKey(_mas)).onPressed, isNull);
    final spinner = find.descendant(
      of: find.byKey(_menos),
      matching: find.byType(CircularProgressIndicator),
    );
    expect(spinner, findsOneWidget);
    expect(tester.getSize(find.ancestor(
      of: spinner,
      matching: find.byType(SizedBox),
    ).first).width, 20);

    await tester.tap(find.byKey(_menos), warnIfMissed: false);
    await tester.pump();
    expect(_movs(repo), hasLength(1));

    repo.bloqueoMover!.complete();
    await tester.pumpAndSettle();
    expect(
      tester.widget<OutlinedButton>(find.byKey(_menos)).onPressed,
      isNotNull,
    );
    expect(tester.widget<OutlinedButton>(find.byKey(_mas)).onPressed, isNotNull);
    expect(_movs(repo), hasLength(1));
  });

  testWidgets('con cantidad 0, -1 queda deshabilitado, sin Opacity y con '
      'semántica propia', (tester) async {
    final semantics = tester.ensureSemantics();
    await _abrir(tester, _repo(cantidad: 0));

    expect(tester.widget<OutlinedButton>(find.byKey(_menos)).onPressed, isNull);
    expect(find.bySemanticsLabel('Descontar 1, no hay stock'), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(_menos), matching: find.byType(Opacity)),
      findsNothing,
    );
    expect(
      find.bySemanticsLabel('Agregar stock a Amoxicilina'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('semántica de los botones activos nombra el producto', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _abrir(tester, _repo());
    expect(
      find.bySemanticsLabel('Descontar 1 de Amoxicilina'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Agregar stock a Amoxicilina'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  group('errores', () {
    for (final c in <(ErrorInventario, String)>[
      (
        ErrorInventario.sinConexion,
        'Sin conexión. El ajuste no se guardó. Inténtalo de nuevo cuando tengas señal.',
      ),
      (
        ErrorInventario.stockInsuficiente,
        'No hay suficiente stock para ese ajuste. Actualiza la lista.',
      ),
      (
        ErrorInventario.noDisponible,
        'Ese producto ya no está disponible. Actualiza la lista.',
      ),
      (
        ErrorInventario.otro,
        'No pudimos completar la operación. Intenta de nuevo.',
      ),
    ]) {
      testWidgets('${c.$1.name} muestra su mensaje y no ofrece Deshacer', (
        tester,
      ) async {
        await _abrir(tester, _repo(errorMover: InventarioFailure('x', tipo: c.$1)));
        await tester.tap(find.byKey(_menos));
        await tester.pumpAndSettle();
        expect(find.text(c.$2), findsOneWidget);
        expect(find.text('Deshacer'), findsNothing);
        // Tras el error los botones vuelven a estar disponibles.
        expect(
          tester.widget<OutlinedButton>(find.byKey(_menos)).onPressed,
          isNotNull,
        );
      });
    }
  });

  testWidgets('deshacer rechazado por IN001 avisa que el stock cambió', (
    tester,
  ) async {
    final repo = _RepoDeshacerFalla(productos: [productoDePrueba()]);
    await _abrir(tester, repo);
    await tester.tap(find.byKey(_menos));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(
      find.text('El stock cambió. Ajusta la cantidad manualmente.'),
      findsOneWidget,
    );
  });

  testWidgets('solo lectura: candados, semántica bloqueada y la hoja se abre '
      'sin registrar movimientos', (tester) async {
    final semantics = tester.ensureSemantics();
    final repo = _repo();
    await _abrir(tester, repo, plan: planSoloLectura);

    expect(
      find.descendant(
        of: find.byKey(_menos),
        matching: find.byIcon(Icons.lock_outline),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(_mas),
        matching: find.byIcon(Icons.lock_outline),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Descontar 1, bloqueado, solo lectura'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Agregar stock, bloqueado, solo lectura'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(_menos));
    await tester.pumpAndSettle();
    expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
    expect(_movs(repo), isEmpty);
    semantics.dispose();
  });

  testWidgets('límite soloLectura devuelto por el servidor abre la hoja del '
      'plan en lugar de un snackbar', (tester) async {
    final repo = _repo(
      errorMover: const InventarioFailure(
        'x',
        tipo: ErrorInventario.soloLectura,
        limite: LimitePlan.soloLectura,
      ),
    );
    await _abrir(tester, repo);
    await tester.tap(find.byKey(_menos));
    await tester.pumpAndSettle();
    expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
    expect(
      find.text('No pudimos completar la operación. Intenta de nuevo.'),
      findsNothing,
    );
  });
}
