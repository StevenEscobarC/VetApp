import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/features/billing/data/services/cobro_pdf_service.dart';
import 'package:vetapp/features/billing/domain/cobro_failure.dart';
import 'package:vetapp/features/billing/domain/entities/cobro.dart';
import 'package:vetapp/features/billing/domain/entities/cobro_item.dart';
import 'package:vetapp/features/vaccination/data/services/carne_pdf_service.dart'
    show CargarLogoPdf, ValidarImagenPdf;

import 'helpers/fake_cobros.dart';
import 'helpers/fake_pdf.dart';

const _lineas = [
  CobroItem(
    orden: 1,
    tipo: TipoLinea.servicio,
    descripcion: 'Consulta',
    cantidad: 1,
    precioUnitarioCop: 50000,
  ),
  CobroItem(
    orden: 2,
    tipo: TipoLinea.producto,
    descripcion: 'Amoxicilina',
    cantidad: 2,
    precioUnitarioCop: 35000,
    productoId: 'p1',
  ),
];

const _telefonoCliente = '3001234567';

ClinicaCobroPdf _clinica({String? nit = '900123456-7', String? logoPath}) =>
    ClinicaCobroPdf(
      nombre: 'VetCare',
      ciudad: 'Medellín',
      direccion: 'Cra 1 # 2-3',
      telefono: '6045551234',
      nit: nit,
      logoPath: logoPath,
    );

Cobro _cc({
  EstadoCobro estado = EstadoCobro.pendiente,
  String? cedula = '1020304050',
  MetodoPago? metodo,
  DateTime? pagadaEl,
  DateTime? anuladaAt,
  String? motivo,
}) => cobroDePrueba(
  numero: 12,
  estado: estado,
  fecha: DateTime.utc(2026, 8, 18),
  clienteCedula: cedula,
  items: _lineas,
  autorNombre: 'Ana Ruiz',
  metodoPago: metodo,
  pagadaEl: pagadaEl,
  anuladaAt: anuladaAt,
  motivoAnulacion: motivo,
);

Cobro _cot({EstadoCobro estado = EstadoCobro.abierta, int? convertidaEn}) =>
    cobroDePrueba(
      id: 'q1',
      tipo: TipoCobro.cotizacion,
      numero: 4,
      estado: estado,
      fecha: DateTime.utc(2026, 8, 18),
      validaHasta: DateTime.utc(2026, 9, 2),
      clienteCedula: '1020304050',
      items: _lineas,
      autorNombre: 'Ana Ruiz',
      convertidaEnId: convertidaEn == null ? null : 'c13',
      convertidaEnNumero: convertidaEn,
    );

/// [esperados] aparece dentro de [todos] en el mismo orden.
void _enOrden(List<String> todos, List<String> esperados) {
  var desde = 0;
  for (final e in esperados) {
    final i = todos.indexOf(e, desde);
    expect(i, greaterThanOrEqualTo(0), reason: 'falta "$e" en $todos');
    desde = i + 1;
  }
}

final _prohibido = RegExp(r'factura|\bIVA\b|\bDIAN\b', caseSensitive: false);

void _sinProhibidos(Cobro c, ClinicaCobroPdf clinica) {
  final todo = [
    ...CobroPdfService.textosPdf(c, clinica),
    for (final f in CobroPdfService.filasPdf(c)) ...f,
    CobroPdfService.nombreArchivo(c),
  ];
  for (final t in todo) {
    expect(_prohibido.hasMatch(t), isFalse, reason: t);
    expect(t, isNot(contains(_telefonoCliente)));
  }
}

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

bool _esPdf(Uint8List b) => String.fromCharCodes(b.take(4)) == '%PDF';

CobroPdfService _servicio({
  CargarLogoPdf? cargarLogo,
  ValidarImagenPdf? validarImagen,
}) => CobroPdfService(
  cargarFuentes: fuentesDePrueba,
  cargarFuenteDisplay: fuenteDisplayDePrueba,
  cargarLogo: cargarLogo,
  validarImagen: validarImagen,
);

void main() {
  group('textosPdf', () {
    test('CC pendiente: encabezado, partes, suma, estado y autor', () {
      final t = CobroPdfService.textosPdf(_cc(), _clinica());
      _enOrden(t, [
        'Cuenta de cobro',
        'CC-0012',
        'Fecha: 18/08/2026',
        'VetCare',
        'NIT o cédula: 900.123.456-7',
        'Cra 1 # 2-3 · Medellín',
        'Tel. 6045551234',
        'Cliente',
        'Laura Gómez',
        'C.C. 1.020.304.050',
        'Mascota: Rocky',
        'Debe a: VetCare, NIT o cédula 900.123.456-7',
        'La suma de: ciento veinte mil pesos (\$ 120.000)',
        'Estado: Pendiente de pago',
        'Emitida por Dr(a). Ana Ruiz',
      ]);
      expect(t, isNot(contains('ANULADA')));
    });

    test('CC pagada: fecha y método', () {
      final t = CobroPdfService.textosPdf(
        _cc(
          estado: EstadoCobro.pagada,
          metodo: MetodoPago.nequi,
          pagadaEl: DateTime.utc(2026, 8, 20),
        ),
        _clinica(),
      );
      expect(t, contains('Estado: Pagada el 20/08/2026 · Nequi'));
      expect(t, isNot(contains('Estado: Pendiente de pago')));
    });

    test('CC anulada: sello ANULADA y motivo', () {
      final t = CobroPdfService.textosPdf(
        _cc(
          estado: EstadoCobro.anulada,
          anuladaAt: DateTime.utc(2026, 8, 21, 15),
          motivo: 'Error de precio',
        ),
        _clinica(),
      );
      expect(t, contains('ANULADA'));
      expect(t, contains('Anulada el 21/08/2026. Motivo: Error de precio'));
      expect(t.where((s) => s.startsWith('Estado:')), isEmpty);
    });

    test('cotización: título, sin Debe a ni La suma de, con validez', () {
      final t = CobroPdfService.textosPdf(_cot(), _clinica());
      _enOrden(t, [
        'Cotización',
        'COT-0004',
        'Fecha: 18/08/2026',
        'Cliente: Laura Gómez',
        'C.C. 1.020.304.050',
        'Mascota: Rocky',
        'Válida por 15 días, hasta el 02/09/2026.',
      ]);
      expect(t.where((s) => s.startsWith('Debe a')), isEmpty);
      expect(t.where((s) => s.startsWith('La suma de')), isEmpty);
      expect(t.where((s) => s.startsWith('Convertida')), isEmpty);
    });

    test('cotización convertida: "Convertida en CC-0013"', () {
      final t = CobroPdfService.textosPdf(
        _cot(estado: EstadoCobro.convertida, convertidaEn: 13),
        _clinica(),
      );
      expect(t, contains('Convertida en CC-0013'));
    });

    test('sin NIT ni cédula: se omiten', () {
      final t = CobroPdfService.textosPdf(_cc(cedula: null), _clinica(nit: null));
      expect(t.where((s) => s.contains('NIT')), isEmpty);
      expect(t, contains('Debe a: VetCare'));
      expect(t.where((s) => s.startsWith('C.C.')), isEmpty);
    });
  });

  test('filasPdf: descripción, cantidad, unitario y subtotal', () {
    expect(CobroPdfService.filasPdf(_cc()), [
      ['Consulta', '1', '\$ 50.000', '\$ 50.000'],
      ['Amoxicilina', '2', '\$ 35.000', '\$ 70.000'],
    ]);
  });

  test('nunca contenido prohibido ni el teléfono del cliente', () {
    final clinica = _clinica();
    for (final c in [
      _cc(),
      _cc(
        estado: EstadoCobro.pagada,
        metodo: MetodoPago.efectivo,
        pagadaEl: DateTime.utc(2026, 8, 20),
      ),
      _cc(estado: EstadoCobro.anulada, motivo: 'x'),
      _cot(),
      _cot(estado: EstadoCobro.convertida, convertidaEn: 13),
    ]) {
      _sinProhibidos(c, clinica);
    }
  });

  group('generar', () {
    test('devuelve un PDF con fuentes de prueba', () async {
      final bytes = await _servicio().generar(
        cobro: _cc(),
        clinica: _clinica(),
        generadoEn: DateTime.utc(2026, 8, 18, 15),
      );
      expect(bytes, isNotEmpty);
      expect(_esPdf(bytes), isTrue);
    });

    test('cotización y anulada también generan', () async {
      for (final c in [
        _cot(),
        _cc(estado: EstadoCobro.anulada, motivo: 'Error de precio'),
      ]) {
        final bytes = await _servicio().generar(
          cobro: c,
          clinica: _clinica(),
          generadoEn: DateTime.utc(2026, 8, 18),
        );
        expect(_esPdf(bytes), isTrue);
      }
    });

    test('sin logoPath nunca llama al cargador del logo', () async {
      var n = 0;
      final bytes = await _servicio(
        cargarLogo: (_) async {
          n++;
          return _png;
        },
      ).generar(
        cobro: _cc(),
        clinica: _clinica(),
        generadoEn: DateTime.utc(2026, 8, 18),
      );
      expect(_esPdf(bytes), isTrue);
      expect(n, 0);
    });

    test('con logoPath y PNG válido llama al cargador una vez', () async {
      final rutas = <String>[];
      final bytes = await _servicio(
        cargarLogo: (p) async {
          rutas.add(p);
          return _png;
        },
        validarImagen: (_) async => true,
      ).generar(
        cobro: _cc(),
        clinica: _clinica(logoPath: 'c1/logo.png'),
        generadoEn: DateTime.utc(2026, 8, 18),
      );
      expect(_esPdf(bytes), isTrue);
      expect(rutas, ['c1/logo.png']);
    });

    test('cargador que lanza: genera sin logo', () async {
      final bytes = await _servicio(
        cargarLogo: (_) => throw Exception('sin red'),
      ).generar(
        cobro: _cc(),
        clinica: _clinica(logoPath: 'c1/logo.png'),
        generadoEn: DateTime.utc(2026, 8, 18),
      );
      expect(_esPdf(bytes), isTrue);
    });

    testWidgets('imagen corrupta: genera sin logo', (tester) async {
      await tester.runAsync(() async {
        final bytes = await _servicio(
          cargarLogo: (_) async =>
              Uint8List.fromList(utf8.encode('no es imagen')),
        ).generar(
          cobro: _cc(),
          clinica: _clinica(logoPath: 'c1/logo.png'),
          generadoEn: DateTime.utc(2026, 8, 18),
        );
        expect(_esPdf(bytes), isTrue);
      });
    });

    test('fuentes que fallan -> CobroFailure', () async {
      expect(
        CobroPdfService(cargarFuentes: fuentesQueFallan).generar(
          cobro: _cc(),
          clinica: _clinica(),
          generadoEn: DateTime.utc(2026, 8, 18),
        ),
        throwsA(
          isA<CobroFailure>().having(
            (e) => e.message,
            'message',
            'No pudimos generar el PDF. Intenta de nuevo.',
          ),
        ),
      );
    });
  });

  test('nombreArchivo', () {
    expect(CobroPdfService.nombreArchivo(_cc()), 'Cuenta_de_cobro_CC-0012.pdf');
    expect(CobroPdfService.nombreArchivo(_cot()), 'Cotizacion_COT-0004.pdf');
  });
}
