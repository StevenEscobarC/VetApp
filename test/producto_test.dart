import 'package:flutter_test/flutter_test.dart';

import 'package:vetapp/core/errors/limite_plan.dart';
import 'package:vetapp/features/inventory/domain/entities/movimiento_stock.dart';
import 'package:vetapp/features/inventory/domain/entities/producto.dart';
import 'package:vetapp/features/inventory/domain/inventario_failure.dart';

Producto _p({int cantidad = 5, int minimo = 2, DateTime? vence}) => Producto(
  id: 'p1',
  clinicaId: 'c1',
  nombre: 'Amoxicilina',
  categoria: CategoriaProducto.medicamento,
  unidad: Unidad.frasco,
  cantidad: cantidad,
  minimo: minimo,
  vencimiento: vence,
);

void main() {
  group('bajo / agotado (D-07)', () {
    test('cantidad menor al mínimo es bajo', () {
      expect(_p(cantidad: 1, minimo: 2).bajo, isTrue);
    });
    test('cantidad igual al mínimo NO es bajo', () {
      expect(_p(cantidad: 2, minimo: 2).bajo, isFalse);
    });
    test('mínimo 0 nunca es bajo ni agotado', () {
      final p = _p(cantidad: 0, minimo: 0);
      expect(p.bajo, isFalse);
      expect(p.agotado, isFalse);
    });
    test('agotado solo con cantidad 0 y mínimo > 0', () {
      expect(_p(cantidad: 0, minimo: 2).agotado, isTrue);
      expect(_p(cantidad: 1, minimo: 2).agotado, isFalse);
    });
  });

  group('vencimiento', () {
    final hoy = DateTime(2026, 10, 31);
    test('hoy y hoy+30 vencen pronto', () {
      expect(_p(vence: DateTime(2026, 10, 31)).vencePronto(hoy), isTrue);
      expect(_p(vence: DateTime(2026, 11, 30)).vencePronto(hoy), isTrue);
    });
    test('hoy+31 no vence pronto ni está vencido', () {
      final p = _p(vence: DateTime(2026, 12, 1));
      expect(p.vencePronto(hoy), isFalse);
      expect(p.vencido(hoy), isFalse);
    });
    test('ayer está vencido y no vence pronto', () {
      final p = _p(vence: DateTime(2026, 10, 30));
      expect(p.vencido(hoy), isTrue);
      expect(p.vencePronto(hoy), isFalse);
    });
    test('sin fecha: ni pronto ni vencido, días null', () {
      final p = _p();
      expect(p.diasParaVencer(hoy), isNull);
      expect(p.vencePronto(hoy), isFalse);
      expect(p.vencido(hoy), isFalse);
    });
    test('vencimiento UTC (de la BD) cuenta días calendario', () {
      expect(_p(vence: DateTime.utc(2026, 11, 1)).diasParaVencer(hoy), 1);
    });
  });

  group('Unidad', () {
    test('plurales', () {
      expect(Unidad.frasco.etiqueta(1), 'frasco');
      expect(Unidad.frasco.etiqueta(3), 'frascos');
      expect(Unidad.unidad.etiqueta(2), 'unidades');
      expect(Unidad.ml.etiqueta(5), 'ml');
      expect(Unidad.dosis.etiqueta(1), 'dosis');
      expect(Unidad.kg.etiqueta(2), 'kg');
    });
    test('round-trip bd', () {
      for (final u in Unidad.values) {
        expect(Unidad.desdeBd(u.bd), u);
      }
      for (final c in CategoriaProducto.values) {
        expect(CategoriaProducto.desdeBd(c.bd), c);
      }
      for (final m in MotivoMovimiento.values) {
        expect(MotivoMovimiento.desdeBd(m.bd), m);
      }
    });
    test('chips y categorías', () {
      expect(Unidad.ml.chip, 'ml');
      expect(Unidad.tableta.chip, 'Tableta');
      expect(CategoriaProducto.insumo.etiqueta, 'Insumo');
    });
  });

  group('MotivoMovimiento', () {
    test('vencidoDanado', () {
      expect(MotivoMovimiento.vencidoDanado.bd, 'vencido_danado');
      expect(MotivoMovimiento.vencidoDanado.etiqueta, 'Vencido o dañado');
    });
    test('ajustables', () {
      expect(MotivoMovimiento.ajustables, [
        MotivoMovimiento.compra,
        MotivoMovimiento.uso,
        MotivoMovimiento.vencidoDanado,
        MotivoMovimiento.conteo,
      ]);
    });
  });

  group('InventarioFailure', () {
    test('expone límite por ConLimitePlan y toString es el mensaje', () {
      const f = InventarioFailure('x', limite: LimitePlan.soloLectura);
      expect(limiteDe(f), LimitePlan.soloLectura);
      expect(f.toString(), 'x');
      expect(const InventarioFailure('y').tipo, ErrorInventario.otro);
    });
  });
}
