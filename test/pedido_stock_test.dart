import 'package:flutter_test/flutter_test.dart';

import 'package:vetapp/features/inventory/domain/entities/producto.dart';
import 'package:vetapp/features/inventory/domain/pedido_whatsapp.dart';

import 'helpers/fake_inventario.dart';

void main() {
  final gasas = productoDePrueba(
    id: 'g',
    nombre: 'Gasas',
    unidad: Unidad.unidad,
    cantidad: 0,
    minimo: 3,
  );
  final amoxi = productoDePrueba(
    id: 'a',
    nombre: 'Amoxicilina',
    unidad: Unidad.frasco,
    cantidad: 1,
    minimo: 2,
  );
  final suero = productoDePrueba(
    id: 's',
    nombre: 'Suero',
    cantidad: 2,
    minimo: 2,
  );

  test('solo bajos, A-Z, mínimo x 2 - cantidad con plural por lo sugerido', () {
    expect(
      mensajePedidoStock(
        productos: [gasas, amoxi, suero],
        clinica: 'Clínica Sol',
      ),
      'Pedido de Clínica Sol:\n'
      '- Amoxicilina: pedir 3 frascos (quedan 1)\n'
      '- Gasas: pedir 6 unidades (quedan 0)',
    );
  });

  test('sin clínica o en blanco usa "insumos"', () {
    expect(
      mensajePedidoStock(productos: [amoxi]),
      startsWith('Pedido de insumos:\n'),
    );
    expect(
      mensajePedidoStock(productos: [amoxi], clinica: '   '),
      startsWith('Pedido de insumos:\n'),
    );
  });

  test('cantidades de 1000 o más llevan punto de miles', () {
    final granel = productoDePrueba(
      id: 'k',
      nombre: 'Granel',
      unidad: Unidad.ml,
      cantidad: 100,
      minimo: 1500,
    );
    expect(
      mensajePedidoStock(productos: [granel]),
      'Pedido de insumos:\n- Granel: pedir 2.900 ml (quedan 100)',
    );
  });
}
