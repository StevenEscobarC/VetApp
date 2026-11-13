import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetapp/core/errors/limite_plan.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/inventory/domain/entities/movimiento_stock.dart';
import 'package:vetapp/features/inventory/domain/entities/producto.dart';
import 'package:vetapp/features/inventory/domain/inventario_failure.dart';
import 'package:vetapp/features/inventory/presentation/providers/inventario_providers.dart';
import 'package:vetapp/features/inventory/presentation/widgets/ajuste_sheet.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_inventario.dart';
import 'helpers/fake_plan.dart';
import 'helpers/router_harness.dart';

final _amoxi = productoDePrueba();

Future<void> _abrir(
  WidgetTester tester,
  FakeInventarioRepository repo, {
  MotivoMovimiento motivo = MotivoMovimiento.compra,
  Producto? producto,
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
                onPressed: () => mostrarAjusteSheet(
                  context,
                  producto: producto ?? _amoxi,
                  motivoInicial: motivo,
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ],
      overrides: [
        ...planOverrides(),
        authProfileProvider.overrideWith(
          () => FakeAuthProfileNotifier(profile: vetProfile),
        ),
        inventarioRepositoryProvider.overrideWithValue(repo),
      ],
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

Future<void> _escribir(WidgetTester tester, String texto) async {
  await tester.enterText(find.byType(TextField), texto);
  await tester.pump();
}

Finder get _aplicar => find.byType(ElevatedButton);

bool _aplicarHabilitado(WidgetTester tester) =>
    tester.widget<ElevatedButton>(_aplicar).onPressed != null;

Future<void> _aplicarAjuste(WidgetTester tester) async {
  await tester.tap(_aplicar);
  await tester.pumpAndSettle();
}

List<({String metodo, Map<String, Object?> args})> _movs(
  FakeInventarioRepository r,
) => r.llamadas.where((l) => l.metodo == 'moverStock').toList();

FakeInventarioRepository _repo({Object? errorMover}) =>
    FakeInventarioRepository(productos: [_amoxi], errorMover: errorMover);

void main() {
  testWidgets('abre con Compra, campo vacío y enfocado; la vista previa sigue '
      'lo que se escribe y Aplicar registra la compra', (tester) async {
    final repo = _repo();
    await _abrir(tester, repo);

    expect(find.text('Ajustar stock'), findsOneWidget);
    expect(find.text('Amoxicilina · hay 5 frascos'), findsOneWidget);
    expect(find.text('Cantidad que entra'), findsOneWidget);
    for (final m in ['Compra', 'Uso', 'Vencido o dañado', 'Conteo']) {
      expect(find.text(m), findsOneWidget);
    }
    final campo = tester.widget<TextField>(find.byType(TextField));
    expect(campo.controller!.text, isEmpty);
    expect(campo.focusNode?.hasFocus ?? campo.autofocus, isTrue);
    expect(_aplicarHabilitado(tester), isFalse);

    await _escribir(tester, '3');
    expect(find.text('Quedarán 8 frascos'), findsOneWidget);
    expect(_aplicarHabilitado(tester), isTrue);

    await _aplicarAjuste(tester);
    final m = _movs(repo);
    expect(m, hasLength(1));
    expect(m.single.args['delta'], 3);
    expect(m.single.args['motivo'], MotivoMovimiento.compra);
    expect(find.text('Ajustar stock'), findsNothing);
    expect(
      find.text('Agregaste 3 frascos a Amoxicilina. Ahora hay 8.'),
      findsOneWidget,
    );
    expect(find.text('Deshacer'), findsOneWidget);
  });

  testWidgets('Uso: etiqueta propia y no deja el stock por debajo de 0', (
    tester,
  ) async {
    final repo = _repo();
    await _abrir(tester, repo);
    await tester.tap(find.text('Uso'));
    await tester.pumpAndSettle();
    expect(find.text('Cantidad que sale'), findsOneWidget);

    await _escribir(tester, '6');
    expect(
      find.text('No puedes dejar el stock por debajo de 0.'),
      findsOneWidget,
    );
    expect(_aplicarHabilitado(tester), isFalse);

    await _escribir(tester, '2');
    expect(find.text('Quedarán 3 frascos'), findsOneWidget);
    await _aplicarAjuste(tester);
    expect(_movs(repo).single.args['delta'], -2);
    expect(_movs(repo).single.args['motivo'], MotivoMovimiento.uso);
    expect(
      find.text('Descontaste 2 frascos de Amoxicilina. Ahora hay 3.'),
      findsOneWidget,
    );
  });

  testWidgets('Vencido o dañado envía delta negativo con su motivo', (
    tester,
  ) async {
    final repo = _repo();
    await _abrir(tester, repo);
    await tester.tap(find.text('Vencido o dañado'));
    await tester.pumpAndSettle();
    await _escribir(tester, '1');
    await _aplicarAjuste(tester);
    final a = _movs(repo).single.args;
    expect(a['delta'], -1);
    expect(a['motivo'], MotivoMovimiento.vencidoDanado);
  });

  testWidgets('Conteo: precarga la cantidad seleccionada, rechaza la misma y '
      'envía la diferencia', (tester) async {
    final repo = _repo();
    await _abrir(tester, repo);
    await tester.tap(find.text('Conteo'));
    await tester.pumpAndSettle();
    expect(find.text('Cantidad contada'), findsOneWidget);
    final c = tester.widget<TextField>(find.byType(TextField)).controller!;
    expect(c.text, '5');
    expect(c.selection.baseOffset, 0);
    expect(c.selection.extentOffset, 1);
    expect(find.text('Es la misma cantidad que hay ahora.'), findsOneWidget);
    expect(_aplicarHabilitado(tester), isFalse);

    await _escribir(tester, '2');
    expect(find.text('Quedarán 2 frascos'), findsOneWidget);
    await _aplicarAjuste(tester);
    final a = _movs(repo).single.args;
    expect(a['delta'], -3);
    expect(a['motivo'], MotivoMovimiento.conteo);
    expect(find.text('Stock de Amoxicilina corregido a 2.'), findsOneWidget);
    expect(find.text('Deshacer'), findsOneWidget);
  });

  testWidgets('abrir directo en Conteo precarga la cantidad actual', (
    tester,
  ) async {
    await _abrir(tester, _repo(), motivo: MotivoMovimiento.conteo);
    expect(find.text('Cantidad contada'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '5',
    );
  });

  testWidgets('validaciones de cantidad y botones +/−', (tester) async {
    await _abrir(tester, _repo());

    await _escribir(tester, '0');
    expect(find.text('Escribe una cantidad mayor que 0.'), findsOneWidget);
    expect(_aplicarHabilitado(tester), isFalse);

    await _escribir(tester, '');
    expect(find.text('Escribe una cantidad mayor que 0.'), findsOneWidget);

    await _escribir(tester, '1000001');
    expect(find.text('La cantidad máxima es 1.000.000.'), findsOneWidget);
    expect(_aplicarHabilitado(tester), isFalse);

    await _escribir(tester, '');
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '2',
    );
    expect(find.text('Quedarán 7 frascos'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '1',
    );
  });

  testWidgets('ajuste grande pide confirmar; Revisar conserva los datos y '
      'Confirmar aplica sin Deshacer', (tester) async {
    final repo = _repo();
    await _abrir(tester, repo);
    await _escribir(tester, '15');
    await tester.tap(_aplicar);
    await tester.pumpAndSettle();

    expect(find.text('¿Confirmas este ajuste?'), findsOneWidget);
    expect(
      find.text('Vas a sumar 15 frascos a Amoxicilina. Quedarán 20.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Revisar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Confirmas este ajuste?'), findsNothing);
    expect(find.text('Ajustar stock'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '15',
    );
    expect(_movs(repo), isEmpty);

    await tester.tap(_aplicar);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar ajuste'));
    await tester.pumpAndSettle();
    expect(_movs(repo).single.args['delta'], 15);
    expect(
      find.text('Ajuste aplicado a Amoxicilina. Ahora hay 20.'),
      findsOneWidget,
    );
    expect(find.text('Deshacer'), findsNothing);
  });

  testWidgets('un ajuste de exactamente 10 se aplica directo con Deshacer', (
    tester,
  ) async {
    final repo = _repo();
    await _abrir(tester, repo);
    await _escribir(tester, '10');
    await _aplicarAjuste(tester);
    expect(find.text('¿Confirmas este ajuste?'), findsNothing);
    expect(_movs(repo).single.args['delta'], 10);
    expect(find.text('Deshacer'), findsOneWidget);
  });

  testWidgets('en vuelo: spinner, botón y campo deshabilitados, una sola '
      'llamada', (tester) async {
    final repo = _repo()..bloqueoMover = Completer<void>();
    await _abrir(tester, repo);
    await _escribir(tester, '3');
    await tester.tap(_aplicar);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(_aplicarHabilitado(tester), isFalse);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    await tester.tap(_aplicar, warnIfMissed: false);
    await tester.pump();
    expect(_movs(repo), hasLength(1));

    repo.bloqueoMover!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Ajustar stock'), findsNothing);
  });

  group('errores en línea', () {
    testWidgets('stock insuficiente: mensaje y la hoja conserva los datos', (
      tester,
    ) async {
      await _abrir(
        tester,
        _repo(
          errorMover: const InventarioFailure(
            'x',
            tipo: ErrorInventario.stockInsuficiente,
          ),
        ),
      );
      await _escribir(tester, '3');
      await _aplicarAjuste(tester);
      expect(
        find.text(
          'No hay suficiente stock para ese ajuste. Actualiza la lista y '
          'revisa la cantidad.',
        ),
        findsOneWidget,
      );
      expect(find.text('Ajustar stock'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '3',
      );
      expect(_aplicarHabilitado(tester), isTrue);
    });

    testWidgets('sin conexión', (tester) async {
      await _abrir(
        tester,
        _repo(
          errorMover: const InventarioFailure(
            'x',
            tipo: ErrorInventario.sinConexion,
          ),
        ),
      );
      await _escribir(tester, '3');
      await _aplicarAjuste(tester);
      expect(
        find.text(
          'Sin conexión. El ajuste no se guardó. Inténtalo de nuevo cuando '
          'tengas señal.',
        ),
        findsOneWidget,
      );
      expect(find.text('Ajustar stock'), findsOneWidget);
    });

    testWidgets('producto no disponible deshabilita Aplicar', (tester) async {
      await _abrir(
        tester,
        _repo(
          errorMover: const InventarioFailure(
            'x',
            tipo: ErrorInventario.noDisponible,
          ),
        ),
      );
      await _escribir(tester, '3');
      await _aplicarAjuste(tester);
      expect(find.text('Ese producto ya no está disponible.'), findsOneWidget);
      expect(_aplicarHabilitado(tester), isFalse);
    });

    testWidgets('otro error', (tester) async {
      await _abrir(tester, _repo(errorMover: const InventarioFailure('x')));
      await _escribir(tester, '3');
      await _aplicarAjuste(tester);
      expect(
        find.text('No pudimos completar la operación. Intenta de nuevo.'),
        findsOneWidget,
      );
    });

    testWidgets('límite de solo lectura abre la hoja del plan y conserva lo '
        'escrito', (tester) async {
      await _abrir(
        tester,
        _repo(
          errorMover: const InventarioFailure(
            'x',
            tipo: ErrorInventario.soloLectura,
            limite: LimitePlan.soloLectura,
          ),
        ),
      );
      await _escribir(tester, '3');
      await _aplicarAjuste(tester);
      expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
      expect(find.text('Ajustar stock'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '3',
      );
    });
  });

  testWidgets('Cancelar cierra sin registrar nada', (tester) async {
    final repo = _repo();
    await _abrir(tester, repo);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Ajustar stock'), findsNothing);
    expect(_movs(repo), isEmpty);
  });

  group('conteo con stock desactualizado (CR-01)', () {
    testWidgets('el conteo envía la cantidad esperada; los demás motivos no', (
      tester,
    ) async {
      final repo = _repo();
      await _abrir(tester, repo, motivo: MotivoMovimiento.conteo);
      await _escribir(tester, '3');
      await _aplicarAjuste(tester);
      expect(_movs(repo).single.args['cantidadEsperada'], 5);
      expect(_movs(repo).single.args['delta'], -2);

      final repo2 = _repo();
      await _abrir(tester, repo2);
      await _escribir(tester, '2');
      await _aplicarAjuste(tester);
      expect(_movs(repo2).single.args['cantidadEsperada'], isNull);
    });

    testWidgets('si el stock cambió (IN004) no mueve nada, avisa y muestra la '
        'cantidad fresca; al reintentar fija lo contado', (tester) async {
      // La hoja se abre con 5 (copia vieja); en el servidor ya hay 8.
      final repo = FakeInventarioRepository(
        productos: [productoDePrueba(cantidad: 8)],
      );
      await _abrir(tester, repo, motivo: MotivoMovimiento.conteo);
      expect(find.text('Amoxicilina · hay 5 frascos'), findsOneWidget);

      await _escribir(tester, '7');
      await _aplicarAjuste(tester);

      expect(
        find.text(
          'El stock cambió mientras contabas. Revisa la cantidad actual e '
          'intenta de nuevo.',
        ),
        findsOneWidget,
      );
      expect(find.text('Ajustar stock'), findsOneWidget);
      expect(find.text('Amoxicilina · hay 8 frascos'), findsOneWidget);
      expect((await repo.producto('p1'))!.cantidad, 8);
      expect(_movs(repo).single.args['cantidadEsperada'], 5);

      await _escribir(tester, '7');
      expect(find.text('Quedarán 7 frascos'), findsOneWidget);
      await _aplicarAjuste(tester);
      final ultimo = _movs(repo).last;
      expect(ultimo.args['delta'], -1);
      expect(ultimo.args['cantidadEsperada'], 8);
      expect((await repo.producto('p1'))!.cantidad, 7);
      expect(find.text('Stock de Amoxicilina corregido a 7.'), findsOneWidget);
    });
  });

  group('topes del servidor (WR-02)', () {
    testWidgets('un ajuste de más de 100.000 no se puede aplicar', (
      tester,
    ) async {
      final repo = _repo();
      await _abrir(tester, repo);
      await _escribir(tester, '100001');
      expect(find.text('El ajuste máximo es 100.000.'), findsOneWidget);
      expect(_aplicarHabilitado(tester), isFalse);

      await _escribir(tester, '100000');
      expect(find.text('El ajuste máximo es 100.000.'), findsNothing);
      expect(_aplicarHabilitado(tester), isTrue);
    });

    testWidgets('un conteo que mueve más de 100.000 no se puede aplicar', (
      tester,
    ) async {
      await _abrir(tester, _repo(), motivo: MotivoMovimiento.conteo);
      await _escribir(tester, '100006');
      expect(find.text('El ajuste máximo es 100.000.'), findsOneWidget);
      expect(_aplicarHabilitado(tester), isFalse);

      await _escribir(tester, '100005');
      expect(_aplicarHabilitado(tester), isTrue);
    });

    testWidgets('una compra que deja más de 1.000.000 no se puede aplicar', (
      tester,
    ) async {
      final grande = productoDePrueba(cantidad: 950000);
      final repo = FakeInventarioRepository(productos: [grande]);
      await _abrir(tester, repo, producto: grande);
      await _escribir(tester, '50001');
      expect(find.text('El stock no puede superar 1.000.000.'), findsOneWidget);
      expect(_aplicarHabilitado(tester), isFalse);
      await tester.tap(_aplicar);
      await tester.pumpAndSettle();
      expect(_movs(repo), isEmpty);

      await _escribir(tester, '50000');
      expect(find.text('El stock no puede superar 1.000.000.'), findsNothing);
      expect(_aplicarHabilitado(tester), isTrue);
    });
  });
}
