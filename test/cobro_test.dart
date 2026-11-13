import 'package:flutter_test/flutter_test.dart';

import 'package:vetapp/core/errors/limite_plan.dart';
import 'package:vetapp/features/billing/domain/cobro_failure.dart';
import 'package:vetapp/features/billing/domain/entities/cobro.dart';
import 'package:vetapp/features/billing/domain/entities/cobro_item.dart';
import 'package:vetapp/features/billing/domain/entities/servicio.dart';
import 'package:vetapp/features/billing/domain/numeracion.dart';

CobroItem _item(
  int orden, {
  TipoLinea tipo = TipoLinea.servicio,
  String descripcion = 'Consulta',
  int cantidad = 1,
  int precio = 50000,
  String? productoId,
}) => CobroItem(
  orden: orden,
  tipo: tipo,
  descripcion: descripcion,
  cantidad: cantidad,
  precioUnitarioCop: precio,
  productoId: productoId,
);

Cobro _cobro({
  TipoCobro tipo = TipoCobro.cuentaCobro,
  EstadoCobro estado = EstadoCobro.pendiente,
  List<CobroItem>? items,
  DateTime? validaHasta,
}) => Cobro(
  id: 'c1',
  tipo: tipo,
  numero: 12,
  estado: estado,
  fecha: DateTime.utc(2026, 11, 1),
  clienteNombre: 'Laura Gómez',
  items: items ?? [_item(1)],
  totalCop: 50000,
  validaHasta: validaHasta,
  creadoPor: 'vet1',
);

void main() {
  group('formatearNumeroCobro', () {
    test('rellena a 4 dígitos y no trunca números grandes', () {
      expect(formatearNumeroCobro(TipoCobro.cuentaCobro, 1), 'CC-0001');
      expect(formatearNumeroCobro(TipoCobro.cuentaCobro, 12), 'CC-0012');
      expect(formatearNumeroCobro(TipoCobro.cotizacion, 4), 'COT-0004');
      expect(formatearNumeroCobro(TipoCobro.cuentaCobro, 9999), 'CC-9999');
      expect(formatearNumeroCobro(TipoCobro.cuentaCobro, 12345), 'CC-12345');
    });

    test('constantes del contrato', () {
      expect(kCobrosLista, 50);
      expect(kDiasValidezCotizacion, 15);
      expect(kTotalMaximoCop, 999999999);
      expect(kLineasMaximas, 50);
    });
  });

  group('CobroItem', () {
    test('subtotal entero; precio 0 permitido', () {
      expect(_item(1, cantidad: 3, precio: 25000).subtotalCop, 75000);
      expect(_item(1, cantidad: 2, precio: 0).subtotalCop, 0);
    });
  });

  group('Cobro', () {
    test('numeroTexto y getters de estado', () {
      final c = _cobro();
      expect(c.numeroTexto, 'CC-0012');
      expect(c.esCuentaCobro, isTrue);
      expect(c.esCotizacion, isFalse);
      expect(c.pendiente, isTrue);
      expect(c.pagada, isFalse);
      expect(c.anulada, isFalse);
      expect(
        _cobro(
          tipo: TipoCobro.cotizacion,
          estado: EstadoCobro.abierta,
        ).numeroTexto,
        'COT-0012',
      );
      expect(_cobro(estado: EstadoCobro.pagada).pagada, isTrue);
      expect(_cobro(estado: EstadoCobro.anulada).anulada, isTrue);
      final cot = _cobro(
        tipo: TipoCobro.cotizacion,
        estado: EstadoCobro.convertida,
      );
      expect(cot.convertida, isTrue);
      expect(cot.abierta, isFalse);
    });

    test('resumenLineas', () {
      expect(_cobro().resumenLineas, 'Consulta');
      expect(
        _cobro(
          items: [
            _item(1),
            _item(2, descripcion: 'Vacuna'),
            _item(3, descripcion: 'Gasas'),
          ],
        ).resumenLineas,
        'Consulta +2',
      );
    });

    test('productoIds solo de líneas de producto, sin duplicados', () {
      final c = _cobro(
        items: [
          _item(1),
          _item(2, tipo: TipoLinea.producto, productoId: 'p1'),
          _item(3, tipo: TipoLinea.producto, productoId: 'p2'),
          _item(4, tipo: TipoLinea.producto, productoId: 'p1'),
          _item(5, tipo: TipoLinea.otro),
        ],
      );
      expect(c.productoIds, {'p1', 'p2'});
    });

    test('vencida solo para cotización abierta con fecha pasada', () {
      final abierta = _cobro(
        tipo: TipoCobro.cotizacion,
        estado: EstadoCobro.abierta,
        validaHasta: DateTime.utc(2026, 11, 10),
      );
      expect(abierta.vencida(DateTime(2026, 11, 11)), isTrue);
      expect(abierta.vencida(DateTime(2026, 11, 10)), isFalse);
      expect(abierta.vencida(DateTime(2026, 11, 10, 23, 59)), isFalse);
      for (final e in [EstadoCobro.convertida, EstadoCobro.anulada]) {
        expect(
          abierta.copyWith(estado: e).vencida(DateTime(2026, 12, 1)),
          isFalse,
        );
      }
      expect(
        _cobro(
          validaHasta: DateTime.utc(2026, 11, 10),
        ).vencida(DateTime(2026, 12, 1)),
        isFalse,
      );
    });

    test('copyWith conserva lo no cambiado', () {
      final c = _cobro().copyWith(
        estado: EstadoCobro.pagada,
        metodoPago: MetodoPago.nequi,
      );
      expect(c.estado, EstadoCobro.pagada);
      expect(c.metodoPago, MetodoPago.nequi);
      expect(c.id, 'c1');
      expect(c.totalCop, 50000);
      expect(c.clienteNombre, 'Laura Gómez');
    });
  });

  group('enums bd/desdeBd', () {
    test('TipoCobro', () {
      expect(TipoCobro.cuentaCobro.bd, 'cuenta_cobro');
      expect(TipoCobro.cotizacion.bd, 'cotizacion');
      expect(TipoCobro.cuentaCobro.prefijo, 'CC');
      expect(TipoCobro.cotizacion.prefijo, 'COT');
      expect(TipoCobro.cuentaCobro.etiqueta, 'Cuenta de cobro');
      expect(TipoCobro.cotizacion.etiqueta, 'Cotización');
      for (final t in TipoCobro.values) {
        expect(TipoCobro.desdeBd(t.bd), t);
      }
    });

    test('EstadoCobro', () {
      expect(EstadoCobro.values.map((e) => e.etiqueta).toList(), [
        'Abierta',
        'Convertida',
        'Pendiente',
        'Pagada',
        'Anulada',
      ]);
      for (final e in EstadoCobro.values) {
        expect(e.bd, e.name);
        expect(EstadoCobro.desdeBd(e.bd), e);
      }
    });

    test('MetodoPago en el orden de los chips', () {
      expect(MetodoPago.values.map((m) => m.etiqueta).toList(), [
        'Efectivo',
        'Nequi',
        'Daviplata',
        'Transferencia',
        'Tarjeta',
        'Otro',
      ]);
      for (final m in MetodoPago.values) {
        expect(MetodoPago.desdeBd(m.bd), m);
      }
      expect(MetodoPago.nequi.bd, 'nequi');
    });

    test('TipoLinea', () {
      for (final t in TipoLinea.values) {
        expect(TipoLinea.desdeBd(t.bd), t);
      }
      expect(TipoLinea.producto.bd, 'producto');
    });
  });

  group('otros tipos del contrato', () {
    test('ResumenCobros, CobroVinculado, Servicio, ClinicaCobroPdf', () {
      const r = ResumenCobros();
      expect((r.cobradoMes, r.porCobrar, r.pendientes), (0, 0, 0));
      const v = CobroVinculado(
        id: 'x',
        numero: 7,
        estado: EstadoCobro.pendiente,
      );
      expect(v.numeroTexto, 'CC-0007');
      const s = Servicio(id: 's1', nombre: 'Consulta', precioCop: 50000);
      expect(s.precioCop, 50000);
      const cl = ClinicaCobroPdf(nombre: 'Clínica Sol', nit: '900123456-7');
      expect(cl.logoPath, isNull);
      const ResultadoCobro res = (id: 'c1', numero: 1, yaExistia: false);
      expect(res.yaExistia, isFalse);
      const l = LineaCobroNueva(
        tipo: TipoLinea.otro,
        descripcion: 'Baño',
        cantidad: 1,
        precioUnitarioCop: 20000,
      );
      expect(l.productoId, isNull);
    });
  });

  group('CobroFailure', () {
    test('expone el límite y toString es el mensaje', () {
      const f = CobroFailure(
        'Solo lectura',
        tipo: ErrorCobro.soloLectura,
        limite: LimitePlan.soloLectura,
      );
      expect(limiteDe(f), LimitePlan.soloLectura);
      expect(f.toString(), 'Solo lectura');
      const g = CobroFailure('x');
      expect(g.tipo, ErrorCobro.otro);
      expect(limiteDe(g), isNull);
    });
  });
}
