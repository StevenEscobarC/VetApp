import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetapp/features/inventory/domain/entities/movimiento_stock.dart';
import 'package:vetapp/features/inventory/domain/entities/producto.dart';
import 'package:vetapp/features/inventory/domain/inventario_failure.dart';
import 'package:vetapp/features/inventory/presentation/providers/inventario_providers.dart';

import 'helpers/fake_inventario.dart';

/// Simula pantallas vivas (tarjeta de Inicio, lista, historial): con un
/// listener activo los providers `autoDispose` no se desechan solos, así que
/// solo se refrescan si la mutación los invalida (G4).
ProviderContainer _contenedor(FakeInventarioRepository repo) {
  final c = ProviderContainer(
    overrides: [inventarioRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  c.listen(productosProvider, (_, _) {});
  c.listen(resumenInventarioProvider, (_, _) {});
  c.listen(movimientosProvider('p1'), (_, _) {});
  return c;
}

Future<void> _cargar(ProviderContainer c) async {
  await c.read(productosProvider.future);
  await c.read(resumenInventarioProvider.future);
  await c.read(movimientosProvider('p1').future);
}

int _veces(FakeInventarioRepository repo, String metodo) =>
    repo.llamadas.where((l) => l.metodo == metodo).length;

void _esperaRecarga(FakeInventarioRepository repo, {bool movs = true}) {
  expect(_veces(repo, 'productos'), 2);
  expect(_veces(repo, 'resumen'), 2);
  if (movs) expect(_veces(repo, 'movimientos'), 2);
}

Future<void> _recargar(ProviderContainer c) async {
  await c.read(productosProvider.future);
  await c.read(resumenInventarioProvider.future);
  await c.read(movimientosProvider('p1').future);
}

void main() {
  FakeInventarioRepository repoBase() =>
      FakeInventarioRepository(productos: [productoDePrueba()]);

  test('ajustar refresca lista, resumen e historial', () async {
    final repo = repoBase();
    final c = _contenedor(repo);
    await _cargar(c);
    await c
        .read(inventarioActionsProvider)
        .ajustar(
          producto: productoDePrueba(),
          delta: -1,
          motivo: MotivoMovimiento.uso,
        );
    await _recargar(c);
    _esperaRecarga(repo);
    final enviado = repo.llamadas.firstWhere((l) => l.metodo == 'moverStock');
    expect(enviado.args['delta'], -1);
    expect(enviado.args['deshaceId'], isNull);
  });

  test('deshacer envía el delta inverso y refresca', () async {
    final repo = repoBase();
    final c = _contenedor(repo);
    await _cargar(c);
    final r = await c
        .read(inventarioActionsProvider)
        .ajustar(
          producto: productoDePrueba(),
          delta: -2,
          motivo: MotivoMovimiento.uso,
        );
    await c
        .read(inventarioActionsProvider)
        .deshacer(productoId: 'p1', movimientoId: r.movimientoId, delta: -2);
    final mov = repo.llamadas.where((l) => l.metodo == 'moverStock').last;
    expect(mov.args['delta'], 2);
    expect(mov.args['motivo'], MotivoMovimiento.deshacer);
    expect(mov.args['deshaceId'], r.movimientoId);
    await _recargar(c);
    expect(_veces(repo, 'productos'), 2);
  });

  test('crear refresca lista y resumen', () async {
    final repo = repoBase();
    final c = _contenedor(repo);
    await _cargar(c);
    final id = await c
        .read(inventarioActionsProvider)
        .crear(nombre: 'Gasas', unidad: Unidad.caja, cantidad: 3);
    expect(id, isNotEmpty);
    await _recargar(c);
    expect((await c.read(productosProvider.future)).length, 2);
    _esperaRecarga(repo, movs: false);
  });

  test('actualizar refresca lista, resumen e historial', () async {
    final repo = repoBase();
    final c = _contenedor(repo);
    await _cargar(c);
    await c
        .read(inventarioActionsProvider)
        .actualizar(
          id: 'p1',
          nombre: 'Otra',
          categoria: CategoriaProducto.insumo,
          minimo: 1,
        );
    await _recargar(c);
    _esperaRecarga(repo);
  });

  test('archivar refresca y saca el producto de la lista', () async {
    final repo = repoBase();
    final c = _contenedor(repo);
    await _cargar(c);
    await c.read(inventarioActionsProvider).archivar('p1');
    await _recargar(c);
    expect(await c.read(productosProvider.future), isEmpty);
    _esperaRecarga(repo);
  });

  test('stock insuficiente / no disponible igual invalidan', () async {
    final repo = repoBase();
    final c = _contenedor(repo);
    await _cargar(c);
    await expectLater(
      c
          .read(inventarioActionsProvider)
          .ajustar(
            producto: productoDePrueba(),
            delta: -99,
            motivo: MotivoMovimiento.uso,
          ),
      throwsA(
        isA<InventarioFailure>().having(
          (e) => e.tipo,
          'tipo',
          ErrorInventario.stockInsuficiente,
        ),
      ),
    );
    await _recargar(c);
    _esperaRecarga(repo);

    await expectLater(
      c
          .read(inventarioActionsProvider)
          .ajustar(
            producto: productoDePrueba(id: 'fantasma'),
            delta: 1,
            motivo: MotivoMovimiento.compra,
          ),
      throwsA(isA<InventarioFailure>()),
    );
    await c.read(productosProvider.future);
    expect(_veces(repo, 'productos'), 3);
  });

  test('conteo con stock desactualizado (IN004) falla sin mover e invalida '
      'para mostrar la cantidad fresca', () async {
    final repo = repoBase(); // en el "servidor" hay 5
    final c = _contenedor(repo);
    await _cargar(c);
    await expectLater(
      c
          .read(inventarioActionsProvider)
          .ajustar(
            producto: productoDePrueba(cantidad: 8),
            delta: -1,
            motivo: MotivoMovimiento.conteo,
            cantidadEsperada: 8,
          ),
      throwsA(
        isA<InventarioFailure>().having(
          (e) => e.tipo,
          'tipo',
          ErrorInventario.stockCambio,
        ),
      ),
    );
    final enviado = repo.llamadas.lastWhere((l) => l.metodo == 'moverStock');
    expect(enviado.args['cantidadEsperada'], 8);
    await _recargar(c);
    _esperaRecarga(repo);
    expect((await c.read(productosProvider.future)).single.cantidad, 5);
  });

  test('ajustar sin cantidad esperada no la envía', () async {
    final repo = repoBase();
    final c = _contenedor(repo);
    await _cargar(c);
    await c
        .read(inventarioActionsProvider)
        .ajustar(
          producto: productoDePrueba(),
          delta: 2,
          motivo: MotivoMovimiento.compra,
        );
    final enviado = repo.llamadas.lastWhere((l) => l.metodo == 'moverStock');
    expect(enviado.args['cantidadEsperada'], isNull);
  });

  test('otros fallos NO invalidan', () async {
    final repo = FakeInventarioRepository(
      productos: [productoDePrueba()],
      errorMover: const InventarioFailure(
        'Sin conexión.',
        tipo: ErrorInventario.sinConexion,
      ),
    );
    final c = _contenedor(repo);
    await _cargar(c);
    await expectLater(
      c
          .read(inventarioActionsProvider)
          .ajustar(
            producto: productoDePrueba(),
            delta: -1,
            motivo: MotivoMovimiento.uso,
          ),
      throwsA(isA<InventarioFailure>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(_veces(repo, 'productos'), 1);
    expect(_veces(repo, 'resumen'), 1);
    expect(_veces(repo, 'movimientos'), 1);
  });

  group('FakeInventarioRepository', () {
    test('delta que deja cantidad < 0 lanza stockInsuficiente', () async {
      final repo = repoBase();
      expect(
        () => repo.moverStock(
          productoId: 'p1',
          delta: -6,
          motivo: MotivoMovimiento.uso,
        ),
        throwsA(isA<InventarioFailure>()),
      );
    });
    test('segundo deshacer del mismo movimiento lanza yaDeshecho', () async {
      final repo = repoBase();
      final r = await repo.moverStock(
        productoId: 'p1',
        delta: -1,
        motivo: MotivoMovimiento.uso,
      );
      await repo.moverStock(
        productoId: 'p1',
        delta: 1,
        motivo: MotivoMovimiento.deshacer,
        deshaceId: r.movimientoId,
      );
      await expectLater(
        repo.moverStock(
          productoId: 'p1',
          delta: 1,
          motivo: MotivoMovimiento.deshacer,
          deshaceId: r.movimientoId,
        ),
        throwsA(
          isA<InventarioFailure>().having(
            (e) => e.tipo,
            'tipo',
            ErrorInventario.yaDeshecho,
          ),
        ),
      );
    });
    test('resumen derivado usa la regla D-07', () async {
      final repo = FakeInventarioRepository(
        productos: [
          productoDePrueba(id: 'a', cantidad: 1, minimo: 2),
          productoDePrueba(id: 'b', cantidad: 2, minimo: 2),
        ],
      );
      expect((await repo.resumen()).bajos, 1);
    });
  });
}
