import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetapp/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/billing/domain/cobro_failure.dart';
import 'package:vetapp/features/billing/domain/entities/cobro.dart';
import 'package:vetapp/features/billing/domain/entities/cobro_item.dart';
import 'package:vetapp/features/billing/presentation/cobros_rutas.dart';
import 'package:vetapp/features/billing/presentation/providers/cobros_providers.dart';
import 'package:vetapp/features/inventory/presentation/providers/inventario_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_cobros.dart';
import 'helpers/fake_inventario.dart';

const _lineaProducto = LineaCobroNueva(
  tipo: TipoLinea.producto,
  descripcion: 'Amoxicilina',
  cantidad: 1,
  precioUnitarioCop: 18000,
  productoId: 'p1',
);

CobroItem _itemProducto(int orden, String productoId) => CobroItem(
  orden: orden,
  tipo: TipoLinea.producto,
  descripcion: 'Producto $productoId',
  cantidad: 1,
  precioUnitarioCop: 1000,
  productoId: productoId,
);

/// Simula pantallas vivas (lista, tarjeta de Inicio, detalle, inventario):
/// con un listener los providers `autoDispose` no se desechan, así que solo
/// recargan si la mutación los invalida.
ProviderContainer _contenedor(
  FakeCobrosRepository repo,
  FakeInventarioRepository inv,
) {
  final c = ProviderContainer(
    overrides: [
      cobrosRepositoryProvider.overrideWithValue(repo),
      inventarioRepositoryProvider.overrideWithValue(inv),
    ],
  );
  addTearDown(c.dispose);
  c.listen(cobrosProvider(TipoCobro.cuentaCobro), (_, _) {});
  c.listen(resumenCobrosProvider, (_, _) {});
  c.listen(cobroProvider('c1'), (_, _) {});
  c.listen(productosProvider, (_, _) {});
  c.listen(movimientosProvider('p1'), (_, _) {});
  return c;
}

Future<void> _leer(ProviderContainer c) async {
  await c.read(cobrosProvider(TipoCobro.cuentaCobro).future);
  await c.read(resumenCobrosProvider.future);
  await c.read(cobroProvider('c1').future);
  await c.read(productosProvider.future);
  await c.read(movimientosProvider('p1').future);
}

int _veces(List<({String metodo, Map<String, Object?> args})> l, String m) =>
    l.where((x) => x.metodo == m).length;

void _esperaRecarga(FakeCobrosRepository repo, FakeInventarioRepository inv) {
  expect(_veces(repo.llamadas, 'cobros'), 2);
  expect(_veces(repo.llamadas, 'resumen'), 2);
  expect(_veces(inv.llamadas, 'productos'), 2);
  expect(_veces(inv.llamadas, 'movimientos'), 2);
}

void main() {
  FakeInventarioRepository inventario() =>
      FakeInventarioRepository(productos: [productoDePrueba()]);

  group('CobrosActions invalida siempre', () {
    test('emitir con línea de producto refresca cobros e inventario', () async {
      final repo = FakeCobrosRepository(cobros: [cobroDePrueba()]);
      final inv = inventario();
      final c = _contenedor(repo, inv);
      await _leer(c);
      final r = await c
          .read(cobrosActionsProvider)
          .emitirCuentaCobro(
            clave: 'k1',
            clienteId: 'cli1',
            lineas: const [_lineaProducto],
          );
      expect(r.numero, 1);
      expect(r.yaExistia, isFalse);
      await _leer(c);
      _esperaRecarga(repo, inv);
    });

    final fallos = [
      const CobroFailure('sin red', tipo: ErrorCobro.sinConexion),
      const CobroFailure('otro'),
      const CobroFailure('stock', tipo: ErrorCobro.stockInsuficiente),
      const CobroFailure('estado', tipo: ErrorCobro.estadoInvalido),
    ];
    for (final fallo in fallos) {
      test(
        'emitir que falla (${fallo.tipo}) igual refresca y relanza',
        () async {
          final repo = FakeCobrosRepository(
            cobros: [cobroDePrueba()],
            errorCrear: fallo,
          );
          final inv = inventario();
          final c = _contenedor(repo, inv);
          await _leer(c);
          await expectLater(
            c
                .read(cobrosActionsProvider)
                .emitirCuentaCobro(
                  clave: 'k1',
                  clienteId: 'cli1',
                  lineas: const [_lineaProducto],
                ),
            throwsA(same(fallo)),
          );
          await _leer(c);
          _esperaRecarga(repo, inv);
        },
      );
    }

    test('convertir refresca el detalle de la cotización origen', () async {
      final repo = FakeCobrosRepository(
        cobros: [
          cobroDePrueba(
            tipo: TipoCobro.cotizacion,
            estado: EstadoCobro.abierta,
            numero: 4,
          ),
        ],
      );
      final inv = inventario();
      final c = _contenedor(repo, inv);
      await _leer(c);
      await c
          .read(cobrosActionsProvider)
          .emitirCuentaCobro(
            clave: 'k1',
            clienteId: 'cli1',
            lineas: const [_lineaProducto],
            cotizacionId: 'c1',
          );
      final detalle = await c.read(cobroProvider('c1').future);
      expect(_veces(repo.llamadas, 'cobro'), 2);
      expect(detalle!.convertida, isTrue);
    });

    test('anular refresca el detalle, el resumen y cada producto', () async {
      final cobro = cobroDePrueba(
        items: [_itemProducto(1, 'p1'), _itemProducto(2, 'p2')],
      );
      final repo = FakeCobrosRepository(cobros: [cobro]);
      final inv = inventario();
      final c = _contenedor(repo, inv);
      c.listen(movimientosProvider('p2'), (_, _) {});
      await _leer(c);
      await c.read(movimientosProvider('p2').future);
      await c
          .read(cobrosActionsProvider)
          .anular(cobro: cobro, motivo: 'Error en el precio');
      await _leer(c);
      await c.read(movimientosProvider('p2').future);
      expect(_veces(repo.llamadas, 'cobro'), 2);
      expect(_veces(repo.llamadas, 'resumen'), 2);
      final movs = inv.llamadas.where((l) => l.metodo == 'movimientos');
      expect(movs.where((l) => l.args['productoId'] == 'p1').length, 2);
      expect(movs.where((l) => l.args['productoId'] == 'p2').length, 2);
      expect((await c.read(cobroProvider('c1').future))!.anulada, isTrue);
    });

    test('anular que falla igual refresca', () async {
      final cobro = cobroDePrueba(items: [_itemProducto(1, 'p1')]);
      final repo = FakeCobrosRepository(
        cobros: [cobro],
        errorAnular: const CobroFailure('x', tipo: ErrorCobro.sinConexion),
      );
      final inv = inventario();
      final c = _contenedor(repo, inv);
      await _leer(c);
      await expectLater(
        c.read(cobrosActionsProvider).anular(cobro: cobro, motivo: 'abc'),
        throwsA(isA<CobroFailure>()),
      );
      await _leer(c);
      _esperaRecarga(repo, inv);
      expect(_veces(repo.llamadas, 'cobro'), 2);
    });

    test(
      'marcar pagado refresca detalle y resumen, también al fallar',
      () async {
        final repo = FakeCobrosRepository(cobros: [cobroDePrueba()]);
        final inv = inventario();
        final c = _contenedor(repo, inv);
        await _leer(c);
        await c
            .read(cobrosActionsProvider)
            .marcarPagado(cobro: cobroDePrueba(), metodo: MetodoPago.nequi);
        await _leer(c);
        expect(_veces(repo.llamadas, 'cobro'), 2);
        expect(_veces(repo.llamadas, 'resumen'), 2);
        expect((await c.read(cobroProvider('c1').future))!.pagada, isTrue);

        final repo2 = FakeCobrosRepository(
          cobros: [cobroDePrueba()],
          errorPagar: const CobroFailure('x', tipo: ErrorCobro.sinConexion),
        );
        final c2 = _contenedor(repo2, inventario());
        await _leer(c2);
        await expectLater(
          c2
              .read(cobrosActionsProvider)
              .marcarPagado(cobro: cobroDePrueba(), metodo: MetodoPago.nequi),
          throwsA(isA<CobroFailure>()),
        );
        await _leer(c2);
        expect(_veces(repo2.llamadas, 'cobro'), 2);
      },
    );

    test('editar cotización refresca su detalle', () async {
      final repo = FakeCobrosRepository(
        cobros: [
          cobroDePrueba(
            tipo: TipoCobro.cotizacion,
            estado: EstadoCobro.abierta,
          ),
        ],
      );
      final inv = inventario();
      final c = _contenedor(repo, inv);
      await _leer(c);
      await c
          .read(cobrosActionsProvider)
          .editarCotizacion(
            id: 'c1',
            clienteId: 'cli1',
            lineas: const [_lineaProducto],
          );
      final d = await c.read(cobroProvider('c1').future);
      expect(_veces(repo.llamadas, 'cobro'), 2);
      expect(d!.totalCop, 18000);
    });

    test('guardar y archivar servicio refrescan el catálogo', () async {
      final repo = FakeCobrosRepository(servicios: [servicioDePrueba()]);
      final c = ProviderContainer(
        overrides: [cobrosRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      c.listen(serviciosProvider, (_, _) {});
      await c.read(serviciosProvider.future);
      final id = await c
          .read(cobrosActionsProvider)
          .guardarServicio(nombre: ' Baño ', precioCop: 30000);
      expect((await c.read(serviciosProvider.future)).length, 2);
      await c.read(cobrosActionsProvider).archivarServicio(id);
      expect((await c.read(serviciosProvider.future)).length, 1);
      expect(_veces(repo.llamadas, 'servicios'), 3);
    });
  });

  group('permisos de cortesía', () {
    ProviderContainer conPerfil(AuthProfile perfil) {
      final c = ProviderContainer(
        overrides: [
          authProfileProvider.overrideWith(
            () => FakeAuthProfileNotifier(profile: perfil),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    AuthProfile perfil(String id, String rol) => AuthProfile(
      id: id,
      nombre: 'Vet',
      email: 'v@x.co',
      rol: 'veterinario',
      telefono: '3000000000',
      clinicaId: 'cl1',
      rolClinica: rol,
    );

    Future<bool> puede(AuthProfile p, String creadoPor) async {
      final c = conPerfil(p);
      c.listen(puedeAnularCobroProvider(creadoPor), (_, _) {});
      await c.read(authProfileProvider.future);
      return c.read(puedeAnularCobroProvider(creadoPor));
    }

    test('puedeAnularCobroProvider', () async {
      expect(await puede(perfil('u9', 'admin'), 'u1'), isTrue);
      expect(await puede(perfil('u1', 'veterinario'), 'u1'), isTrue);
      expect(await puede(perfil('u2', 'veterinario'), 'u1'), isFalse);
    });

    test('puedeAdministrarServiciosProvider', () async {
      final a = conPerfil(perfil('u9', 'admin'));
      await a.read(authProfileProvider.future);
      expect(a.read(puedeAdministrarServiciosProvider), isTrue);
      final b = conPerfil(perfil('u2', 'veterinario'));
      await b.read(authProfileProvider.future);
      expect(b.read(puedeAdministrarServiciosProvider), isFalse);
    });
  });

  group('FakeCobrosRepository', () {
    test('numera por tipo desde 1 y repite la clave', () async {
      final f = FakeCobrosRepository();
      final a = await f.crearCuentaCobro(
        clave: 'k1',
        clienteId: 'c',
        lineas: const [_lineaProducto],
      );
      final b = await f.crearCuentaCobro(
        clave: 'k2',
        clienteId: 'c',
        lineas: const [_lineaProducto],
      );
      final cot = await f.crearCotizacion(
        clave: 'k3',
        clienteId: 'c',
        lineas: const [_lineaProducto],
      );
      expect((a.numero, b.numero, cot.numero), (1, 2, 1));
      final again = await f.crearCuentaCobro(
        clave: 'k1',
        clienteId: 'c',
        lineas: const [_lineaProducto],
      );
      expect(again.yaExistia, isTrue);
      expect(again.numero, 1);
      expect(again.id, a.id);
      expect((await f.cobros(TipoCobro.cuentaCobro)).length, 2);
    });

    test('guarda total desde las líneas; pagar y anular', () async {
      final f = FakeCobrosRepository();
      final r = await f.crearCuentaCobro(
        clave: 'k1',
        clienteId: 'c',
        lineas: const [
          LineaCobroNueva(
            tipo: TipoLinea.otro,
            descripcion: 'Baño',
            cantidad: 2,
            precioUnitarioCop: 15000,
          ),
          _lineaProducto,
        ],
      );
      final c = (await f.cobro(r.id))!;
      expect(c.totalCop, 48000);
      await f.marcarPagado(id: r.id, metodo: MetodoPago.efectivo);
      expect((await f.cobro(r.id))!.pagada, isTrue);
      await f.anular(id: r.id, motivo: 'Duplicado');
      expect((await f.cobro(r.id))!.anulada, isTrue);
    });

    test('error por método y bloqueoCrear', () async {
      final f = FakeCobrosRepository(errorServicios: StateError('x'));
      expect(f.servicios(), throwsA(isA<StateError>()));
      final g = FakeCobrosRepository()..bloqueoCrear = Completer<void>();
      var listo = false;
      final fut = g
          .crearCuentaCobro(
            clave: 'k',
            clienteId: 'c',
            lineas: const [_lineaProducto],
          )
          .then((_) => listo = true);
      await Future<void>.delayed(Duration.zero);
      expect(listo, isFalse);
      g.bloqueoCrear!.complete();
      await fut;
      expect(listo, isTrue);
    });

    test('servicios devuelve la lista inyectada', () async {
      final f = FakeCobrosRepository(servicios: [servicioDePrueba()]);
      final s = await f.servicios();
      expect(s.single.nombre, 'Consulta');
    });
  });

  group('rutas', () {
    test('rutaNuevoCobro', () {
      expect(
        rutaNuevoCobro(clienteId: 'c', citaId: 'x'),
        '/cobros/nuevo?tipo=cc&clienteId=c&citaId=x',
      );
      expect(
        rutaNuevoCobro(tipo: TipoCobro.cotizacion),
        '/cobros/nuevo?tipo=cot',
      );
    });

    test('demás rutas', () {
      expect(kRutaCobros, '/cobros');
      expect(kRutaServicios, '/servicios');
      expect(rutaCobro('c1'), '/cobros/c1');
      expect(rutaEditarCotizacion('c1'), '/cobros/c1/editar');
      expect(rutaConvertirCotizacion('c1'), '/cobros/c1/convertir');
      expect(rutaCobrosTipo(TipoCobro.cotizacion), '/cobros?tipo=cot');
      expect(rutaCobrosTipo(TipoCobro.cuentaCobro), '/cobros');
    });
  });
}
