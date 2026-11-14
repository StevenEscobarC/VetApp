import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetapp/features/billing/domain/entities/cobro.dart';
import 'package:vetapp/features/billing/domain/entities/cobro_item.dart';
import 'package:vetapp/features/billing/presentation/providers/borrador_cobro_provider.dart';

import 'helpers/fake_cobros.dart';

const PrefillCobro _nuevo = (
  modo: ModoFormCobro.nuevo,
  tipo: TipoCobro.cuentaCobro,
  clienteId: null,
  mascotaId: null,
  citaId: null,
  consultaId: null,
  origenId: null,
);

const PrefillCobro _desdeCita = (
  modo: ModoFormCobro.nuevo,
  tipo: TipoCobro.cuentaCobro,
  clienteId: 'cli1',
  mascotaId: 'm1',
  citaId: 'cita1',
  consultaId: null,
  origenId: null,
);

const PrefillCobro _desdeCliente = (
  modo: ModoFormCobro.nuevo,
  tipo: TipoCobro.cotizacion,
  clienteId: 'cli1',
  mascotaId: 'm1',
  citaId: null,
  consultaId: null,
  origenId: null,
);

void main() {
  late int generadas;
  late ProviderContainer container;

  setUp(() {
    generadas = 0;
    container = ProviderContainer(
      overrides: [
        claveIdempotenciaProvider.overrideWithValue(
          () => 'clave-${++generadas}',
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  BorradorCobroNotifier notifier([PrefillCobro p = _nuevo]) =>
      container.read(borradorCobroProvider(p).notifier);
  BorradorCobro leer([PrefillCobro p = _nuevo]) =>
      container.read(borradorCobroProvider(p));

  group('clave de idempotencia', () {
    test('se genera una sola vez por borrador y no cambia al editar', () {
      final sub = container.listen(borradorCobroProvider(_nuevo), (_, _) {});
      addTearDown(sub.close);
      expect(leer().clave, 'clave-1');
      notifier().agregarServicio(servicioDePrueba());
      notifier().agregarOtro();
      notifier().cambiarTipo(TipoCobro.cotizacion);
      expect(leer().clave, 'clave-1');
      expect(generadas, 1);
    });

    test(
      'un borrador nuevo (tras liberar el anterior) trae otra clave',
      () async {
        final sub = container.listen(borradorCobroProvider(_nuevo), (_, _) {});
        expect(leer().clave, 'clave-1');
        sub.close();
        await container.pump();
        final sub2 = container.listen(borradorCobroProvider(_nuevo), (_, _) {});
        addTearDown(sub2.close);
        expect(leer().clave, 'clave-2');
      },
    );
  });

  group('servicios', () {
    late ProviderSubscription<BorradorCobro> sub;
    setUp(
      () => sub = container.listen(borradorCobroProvider(_nuevo), (_, _) {}),
    );
    tearDown(() => sub.close());

    test('el mismo servicio dos veces suma cantidad en una sola línea', () {
      notifier().agregarServicio(servicioDePrueba());
      notifier().agregarServicio(servicioDePrueba());
      final lineas = leer().lineas;
      expect(lineas, hasLength(1));
      expect(lineas.single.cantidad, 2);
      expect(lineas.single.subtotalCop, 100000);
      expect(lineas.single.tipo, TipoLinea.servicio);
      expect(lineas.single.precioBaseCop, 50000);
    });

    test('otro servicio agrega una segunda línea', () {
      notifier().agregarServicio(servicioDePrueba());
      notifier().agregarServicio(
        servicioDePrueba(id: 's2', nombre: 'Baño', precioCop: 30000),
      );
      expect(leer().lineas.map((l) => l.descripcion), ['Consulta', 'Baño']);
    });
  });

  group('Otro y edición', () {
    late ProviderSubscription<BorradorCobro> sub;
    setUp(
      () => sub = container.listen(borradorCobroProvider(_nuevo), (_, _) {}),
    );
    tearDown(() => sub.close());

    test('agregarOtro crea una línea libre vacía', () {
      notifier().agregarOtro();
      final l = leer().lineas.single;
      expect(l.tipo, TipoLinea.otro);
      expect(l.descripcion, '');
      expect(l.precioUnitarioCop, isNull);
      expect(l.cantidad, 1);
    });

    test('cambiarPrecio solo toca esa línea y nunca el precio base', () {
      final consulta = servicioDePrueba();
      notifier().agregarServicio(consulta);
      notifier().agregarOtro();
      final k = leer().lineas.first.key;
      notifier().cambiarPrecio(k, 40000);
      final lineas = leer().lineas;
      expect(lineas.first.precioUnitarioCop, 40000);
      expect(lineas.first.precioBaseCop, 50000);
      expect(lineas.last.precioUnitarioCop, isNull);
      expect(consulta.precioCop, 50000);
    });

    test('cambiarDescripcion edita la línea libre', () {
      notifier().agregarOtro();
      final k = leer().lineas.single.key;
      notifier().cambiarDescripcion(k, 'Baño medicado');
      expect(leer().lineas.single.descripcion, 'Baño medicado');
    });

    test('las claves de línea son únicas', () {
      notifier().agregarOtro();
      notifier().agregarOtro();
      final ks = leer().lineas.map((l) => l.key).toSet();
      expect(ks, hasLength(2));
    });
  });

  group('cantidades', () {
    late ProviderSubscription<BorradorCobro> sub;
    setUp(
      () => sub = container.listen(borradorCobroProvider(_nuevo), (_, _) {}),
    );
    tearDown(() => sub.close());

    test('cambiarCantidad a 0 se ajusta a 1', () {
      notifier().agregarServicio(servicioDePrueba());
      final k = leer().lineas.single.key;
      notifier().cambiarCantidad(k, 0);
      expect(leer().lineas.single.cantidad, 1);
      notifier().cambiarCantidad(k, 3);
      expect(leer().lineas.single.cantidad, 3);
    });

    test('quitar elimina la línea', () {
      notifier().agregarServicio(servicioDePrueba());
      notifier().agregarOtro();
      final k = leer().lineas.first.key;
      notifier().quitar(k);
      expect(leer().lineas, hasLength(1));
      expect(leer().lineas.single.tipo, TipoLinea.otro);
    });
  });

  test('totalCop suma los subtotales (precio vacío cuenta 0)', () {
    final sub = container.listen(borradorCobroProvider(_nuevo), (_, _) {});
    addTearDown(sub.close);
    notifier().agregarServicio(servicioDePrueba());
    notifier().agregarServicio(servicioDePrueba());
    notifier().agregarServicio(
      servicioDePrueba(id: 's2', nombre: 'Baño', precioCop: 30000),
    );
    notifier().agregarOtro();
    expect(leer().totalCop, 130000);
  });

  group('prefill', () {
    test('con citaId queda vinculado y elegirCliente no borra la mascota', () {
      final sub = container.listen(
        borradorCobroProvider(_desdeCita),
        (_, _) {},
      );
      addTearDown(sub.close);
      final b = leer(_desdeCita);
      expect(b.vinculado, isTrue);
      expect(b.clienteId, 'cli1');
      expect(b.mascotaId, 'm1');
      expect(b.citaId, 'cita1');
      notifier(_desdeCita).elegirCliente('cli1');
      expect(leer(_desdeCita).mascotaId, 'm1');
    });

    test('sin vínculo elegirCliente borra la mascota', () {
      final sub = container.listen(
        borradorCobroProvider(_desdeCliente),
        (_, _) {},
      );
      addTearDown(sub.close);
      expect(leer(_desdeCliente).vinculado, isFalse);
      expect(leer(_desdeCliente).tipo, TipoCobro.cotizacion);
      notifier(_desdeCliente).elegirCliente('x');
      expect(leer(_desdeCliente).clienteId, 'x');
      expect(leer(_desdeCliente).mascotaId, isNull);
    });

    test('elegirMascota elige y limpia', () {
      final sub = container.listen(borradorCobroProvider(_nuevo), (_, _) {});
      addTearDown(sub.close);
      notifier().elegirCliente('cli1');
      notifier().elegirMascota('m1');
      expect(leer().mascotaId, 'm1');
      notifier().elegirMascota(null);
      expect(leer().mascotaId, isNull);
    });
  });

  test('lineasNuevas conserva servicioId y precio vacío va como 0', () {
    final sub = container.listen(borradorCobroProvider(_nuevo), (_, _) {});
    addTearDown(sub.close);
    notifier().agregarServicio(servicioDePrueba());
    notifier().agregarOtro();
    final k = leer().lineas.last.key;
    notifier().cambiarDescripcion(k, 'Baño');
    final nuevas = leer().lineasNuevas();
    expect(nuevas, hasLength(2));
    expect(nuevas.first.servicioId, 's1');
    expect(nuevas.first.tipo, TipoLinea.servicio);
    expect(nuevas.first.precioUnitarioCop, 50000);
    expect(nuevas.first.descripcion, 'Consulta');
    expect(nuevas.last.tipo, TipoLinea.otro);
    expect(nuevas.last.precioUnitarioCop, 0);
    expect(nuevas.last.descripcion, 'Baño');
    expect(nuevas.last.servicioId, isNull);
  });

  group('sucio', () {
    test('un borrador prellenado recién abierto no está sucio', () {
      final sub = container.listen(
        borradorCobroProvider(_desdeCliente),
        (_, _) {},
      );
      addTearDown(sub.close);
      expect(leer(_desdeCliente).sucio, isFalse);
      notifier(_desdeCliente).agregarOtro();
      expect(leer(_desdeCliente).sucio, isTrue);
    });

    test('elegir cliente en un borrador vacío lo ensucia', () {
      final sub = container.listen(borradorCobroProvider(_nuevo), (_, _) {});
      addTearDown(sub.close);
      expect(leer().sucio, isFalse);
      notifier().elegirCliente('cli1');
      expect(leer().sucio, isTrue);
    });
  });
}
