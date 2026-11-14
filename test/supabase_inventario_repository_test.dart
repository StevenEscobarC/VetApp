import 'dart:async';
import 'dart:io' as io;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:vetapp/core/errors/limite_plan.dart';
import 'package:vetapp/features/inventory/data/repositories/supabase_inventario_repository.dart';
import 'package:vetapp/features/inventory/domain/entities/movimiento_stock.dart';
import 'package:vetapp/features/inventory/domain/entities/producto.dart';
import 'package:vetapp/features/inventory/domain/inventario_failure.dart';

/// Como `_ClientSocketException` de `package:http`: subclase privada de
/// [http.ClientException], cuyo `runtimeType` no se llama `ClientException`.
class _SubclaseClientException extends http.ClientException {
  _SubclaseClientException() : super('Connection failed');
}

/// Excepción cuyo nombre contiene `SocketException` sin ser la de `dart:io`
/// (p. ej. la variante web o una envoltura).
class _MiSocketException implements Exception {}

PostgrestException _pg(String code, {String? hint}) => PostgrestException(
  message: 'texto crudo del servidor',
  code: code,
  hint: hint,
);

void main() {
  group('mensajeErrorInventario / inventarioFailureDe', () {
    final casos = <String, (String, ErrorInventario)>{
      'IN001': (
        'No hay suficiente stock para ese ajuste.',
        ErrorInventario.stockInsuficiente,
      ),
      'IN002': (
        'Ese producto ya no está disponible. Actualiza la lista.',
        ErrorInventario.noDisponible,
      ),
      'IN003': ('Ese ajuste ya se deshizo.', ErrorInventario.yaDeshecho),
      'IN004': (
        'El stock cambió mientras contabas. Revisa la cantidad actual e '
            'intenta de nuevo.',
        ErrorInventario.stockCambio,
      ),
      '23505': (
        'Ya tienes un producto con ese nombre.',
        ErrorInventario.nombreDuplicado,
      ),
      '42501': (
        'Solo el administrador de la clínica puede hacer esto.',
        ErrorInventario.sinPermiso,
      ),
      '23514': (
        'Revisa los datos: las cantidades deben ser enteros válidos.',
        ErrorInventario.datosInvalidos,
      ),
      'XX999': (
        'No pudimos completar la operación. Intenta de nuevo.',
        ErrorInventario.otro,
      ),
    };
    casos.forEach((code, esperado) {
      test('código $code', () {
        final f = inventarioFailureDe(_pg(code));
        expect(f.message, esperado.$1);
        expect(f.tipo, esperado.$2);
        expect(mensajeErrorInventario(_pg(code)), esperado.$1);
        expect(f.message, isNot(contains('crudo')));
      });
    });

    const lp004 =
        'Tu cuenta está en solo lectura. Pide al administrador que active el plan.';
    test('LP004 por código', () {
      final f = inventarioFailureDe(_pg('LP004'));
      expect(f.message, lp004);
      expect(f.tipo, ErrorInventario.soloLectura);
      expect(f.limite, LimitePlan.soloLectura);
    });
    test('LP004 por hint con código P0001', () {
      final f = inventarioFailureDe(_pg('P0001', hint: 'LP004'));
      expect(f.message, lp004);
      expect(f.limite, LimitePlan.soloLectura);
    });
  });

  group('esErrorDeRed', () {
    test('verdadero para timeout y tipos de red', () {
      expect(esErrorDeRed(TimeoutException('x')), isTrue);
      expect(esErrorDeRed(const io.SocketException('x')), isTrue);
      expect(esErrorDeRed(http.ClientException('x')), isTrue);
      expect(
        esErrorDeRed(http.ClientException('x', Uri.parse('https://x.co'))),
        isTrue,
      );
    });
    test(
      'verdadero para subclases de ClientException (_ClientSocketException)',
      () {
        final e = _SubclaseClientException();
        expect(e.runtimeType.toString(), isNot('ClientException'));
        expect(esErrorDeRed(e), isTrue);
      },
    );
    test('verdadero si el nombre del tipo contiene SocketException', () {
      expect(esErrorDeRed(_MiSocketException()), isTrue);
    });
    test('falso para otros', () {
      expect(esErrorDeRed(const FormatException()), isFalse);
      expect(esErrorDeRed(_pg('IN001')), isFalse);
    });
  });

  group('params', () {
    test('paramsMoverStock', () {
      final p = SupabaseInventarioRepository.paramsMoverStock(
        productoId: 'p1',
        delta: -2,
        motivo: MotivoMovimiento.vencidoDanado,
      );
      expect(p.keys.toSet(), {
        'p_producto_id',
        'p_delta',
        'p_motivo',
        'p_origen',
        'p_ref_id',
        'p_nota',
        'p_deshace_id',
      });
      expect(p['p_origen'], 'ajuste');
      expect(p['p_motivo'], 'vencido_danado');
      expect(p['p_delta'], -2);
      expect(p['p_deshace_id'], isNull);
      expect(p.containsKey('p_cantidad_esperada'), isFalse);
    });
    test('paramsMoverStock con cantidad esperada (conteo, CR-01)', () {
      final p = SupabaseInventarioRepository.paramsMoverStock(
        productoId: 'p1',
        delta: -3,
        motivo: MotivoMovimiento.conteo,
        cantidadEsperada: 13,
      );
      expect(p['p_cantidad_esperada'], 13);
      expect(p['p_delta'], -3);
      expect(p['p_motivo'], 'conteo');
    });
    test('paramsCrearProducto', () {
      final p = SupabaseInventarioRepository.paramsCrearProducto(
        nombre: '  Amoxicilina ',
        unidad: Unidad.frasco,
        cantidad: 5,
        minimo: 2,
        categoria: CategoriaProducto.medicamento,
        vencimiento: DateTime(2027, 3, 9),
      );
      expect(p.keys.toSet(), {
        'p_nombre',
        'p_unidad',
        'p_cantidad',
        'p_minimo',
        'p_categoria',
        'p_vencimiento',
        'p_precio_venta_cop',
        'p_costo_cop',
      });
      expect(p['p_nombre'], 'Amoxicilina');
      expect(p['p_vencimiento'], '2027-03-09');
      expect(p['p_precio_venta_cop'], isNull);
      expect(
        SupabaseInventarioRepository.paramsCrearProducto(
          nombre: 'x',
          unidad: Unidad.ml,
          cantidad: 1,
          minimo: 0,
          categoria: CategoriaProducto.otro,
        )['p_vencimiento'],
        isNull,
      );
    });
    test('paramsActualizarProducto', () {
      final p = SupabaseInventarioRepository.paramsActualizarProducto(
        id: 'p1',
        nombre: ' N ',
        categoria: CategoriaProducto.insumo,
        minimo: 3,
        costoCop: 1000,
      );
      expect(p.keys.toSet(), {
        'p_id',
        'p_nombre',
        'p_categoria',
        'p_vencimiento',
        'p_minimo',
        'p_precio_venta_cop',
        'p_costo_cop',
      });
      expect(p['p_nombre'], 'N');
      expect(p['p_costo_cop'], 1000);
    });
  });

  group('mapeo de filas', () {
    test('productoDesdeFila', () {
      final p = productoDesdeFila({
        'id': 'p1',
        'clinica_id': 'c1',
        'nombre': 'Amoxicilina',
        'categoria': 'insumo',
        'unidad': 'tableta',
        'cantidad': 7,
        'minimo': 2,
        'vencimiento': '2027-03-09',
        'precio_venta_cop': 15000,
        'costo_cop': null,
        'archivado_at': '2026-10-01T10:00:00Z',
      });
      expect(p.cantidad, 7);
      expect(p.minimo, 2);
      expect(p.unidad, Unidad.tableta);
      expect(p.categoria, CategoriaProducto.insumo);
      expect(p.vencimiento, DateTime.utc(2027, 3, 9));
      expect(p.precioVentaCop, 15000);
      expect(p.costoCop, isNull);
      expect(p.archivado, isTrue);
    });
    test('productoDesdeFila sin archivar ni vencimiento', () {
      final p = productoDesdeFila({
        'id': 'p1',
        'clinica_id': 'c1',
        'nombre': 'X',
        'categoria': 'otro',
        'unidad': 'kg',
        'cantidad': 0,
        'minimo': 0,
        'vencimiento': null,
        'archivado_at': null,
      });
      expect(p.archivado, isFalse);
      expect(p.vencimiento, isNull);
    });
    test('movimientoDesdeFila', () {
      final m = movimientoDesdeFila({
        'id': 'm1',
        'producto_id': 'p1',
        'delta': -3,
        'cantidad_resultante': 4,
        'motivo': 'vencido_danado',
        'origen': 'ajuste',
        'deshace_id': null,
        'created_at': '2026-10-31T15:00:00Z',
        'autor': {'nombre': 'Ana'},
      });
      expect(m.delta, -3);
      expect(m.cantidadResultante, 4);
      expect(m.motivo, MotivoMovimiento.vencidoDanado);
      expect(m.autorNombre, 'Ana');
      expect(m.creadoEn.isUtc, isFalse);
      expect(m.creadoEn.toUtc(), DateTime.utc(2026, 10, 31, 15));
    });
    test('movimientoDesdeFila sin autor', () {
      final m = movimientoDesdeFila({
        'id': 'm1',
        'producto_id': 'p1',
        'delta': 1,
        'cantidad_resultante': 1,
        'motivo': 'alta',
        'origen': 'ajuste',
        'created_at': '2026-10-31T15:00:00Z',
      });
      expect(m.autorNombre, isNull);
    });
    test('movimientoDesdeFila mapea la nota (null si no viene)', () {
      final conNota = movimientoDesdeFila({
        'id': 'm2',
        'producto_id': 'p1',
        'delta': -3,
        'cantidad_resultante': 2,
        'motivo': 'venta',
        'origen': kOrigenCobro,
        'nota': 'CC-0012',
        'created_at': '2026-11-13T15:00:00Z',
      });
      expect(conNota.nota, 'CC-0012');
      expect(conNota.origen, kOrigenCobro);
      expect(conNota.motivo, MotivoMovimiento.venta);
      final sinNota = movimientoDesdeFila({
        'id': 'm3',
        'producto_id': 'p1',
        'delta': 1,
        'cantidad_resultante': 1,
        'motivo': 'alta',
        'origen': 'ajuste',
        'created_at': '2026-11-13T15:00:00Z',
      });
      expect(sinNota.nota, isNull);
    });
  });
}
