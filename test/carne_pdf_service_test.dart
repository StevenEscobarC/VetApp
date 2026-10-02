import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/core/config/carne_config.dart';
import 'package:vetapp/features/vaccination/data/services/carne_pdf_service.dart';
import 'package:vetapp/features/vaccination/domain/entities/carne.dart';
import 'package:vetapp/features/vaccination/domain/entities/protocolo.dart';
import 'package:vetapp/features/vaccination/domain/vacuna_failure.dart';

import 'helpers/fake_pdf.dart';

DosisCarne _dosis(
  String id,
  String codigo,
  String nombre,
  TipoDosis tipo, {
  bool anulada = false,
  bool externa = false,
  bool esUltima = true,
  VeterinarioDosis? vet = const VeterinarioDosis(
    nombre: 'Laura Gómez',
    matricula: '12345',
    activo: true,
  ),
}) => DosisCarne(
  id: id,
  codigoProtocolo: codigo,
  biologicoNombre: nombre,
  tipo: tipo,
  fechaAplicacion: DateTime.utc(2026, 3, 12),
  esUltima: esUltima,
  producto: 'Producto $id',
  lote: 'L-$id',
  externa: externa,
  esRefuerzo: false,
  anulada: anulada,
  veterinario: vet,
);

Carne _carne({String? logoPath}) => Carne(
  hoy: DateTime.utc(2026, 10, 2),
  mascotaId: 'm-1',
  mascotaNombre: 'Luna',
  especie: 'perro',
  raza: 'Criollo',
  fechaNacimiento: DateTime.utc(2025, 3, 12),
  duenoNombre: 'María Fernanda Gómez',
  duenoTelefono: '3001234567',
  clinicaNombre: 'Clínica Patitas',
  clinicaCiudad: 'Bogotá',
  clinicaLogoPath: logoPath,
  biologicos: [
    BiologicoCarne(
      codigoProtocolo: 'rabia',
      biologicoNombre: 'Rabia',
      tipo: TipoDosis.vacuna,
      ultimaDosisId: 'd1',
      ultimaFecha: DateTime.utc(2026, 3, 12),
      posicion: 1,
      dosisSerie: 1,
      proximaFecha: DateTime.utc(2027, 3, 12),
      etiquetaProxima: 'Refuerzo anual',
      estado: EstadoCarne.vencida,
      diasVencida: 3,
      ventanaDias: 0,
      sugerirReiniciar: false,
    ),
  ],
  dosis: [
    _dosis('d1', 'rabia', 'Rabia', TipoDosis.vacuna),
    _dosis('d2', 'parvo', 'Parvovirus', TipoDosis.vacuna, anulada: true),
    _dosis(
      'd3',
      'int',
      'Desparasitante interno',
      TipoDosis.desparasitacionInterna,
      externa: true,
      vet: null,
    ),
  ],
);

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);
const _ruta = 'c1/logo-1700000000000.jpg';

Future<bool> _siempreValida(Uint8List _) async => true;

bool _esPdf(Uint8List b) => String.fromCharCodes(b.take(4)) == '%PDF';

void main() {
  test('generar devuelve un PDF', () async {
    final bytes = await CarnePdfService(
      cargarFuentes: fuentesDePrueba,
    ).generar(carne: _carne(), generadoEn: DateTime.utc(2026, 10, 2, 15));
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('filasPdf excluye anuladas, separa tablas y marca externas', () {
    final f = CarnePdfService.filasPdf(_carne());
    expect(f.vacunacion.length, 1);
    expect(f.vacunacion.single.join('|'), contains('Rabia'));
    expect(
      f.vacunacion.single.join('|'),
      contains('Dr(a). Laura Gómez · Mat. 12345'),
    );
    expect(f.vacunacion.single.join('|'), contains('Vencida'));
    expect(f.desparasitacion.length, 1);
    expect(f.desparasitacion.single.last, 'Otra clínica');
    expect(f.desparasitacion.single.join('|'), isNot(contains('Parvovirus')));
  });

  test('propietarioCorto', () {
    expect(propietarioCorto('María Fernanda Gómez'), 'María F.');
    expect(propietarioCorto('Ana'), 'Ana');
  });

  test('fuentes que fallan -> VacunaFailure', () async {
    expect(
      CarnePdfService(
        cargarFuentes: fuentesQueFallan,
      ).generar(carne: _carne(), generadoEn: DateTime.utc(2026, 10, 2)),
      throwsA(
        isA<VacunaFailure>().having(
          (e) => e.message,
          'message',
          'No pudimos generar el PDF. Intenta de nuevo.',
        ),
      ),
    );
  });

  group('fuente de display', () {
    test('se carga una vez y el PDF se genera', () async {
      var n = 0;
      final bytes = await CarnePdfService(
        cargarFuentes: fuentesDePrueba,
        cargarFuenteDisplay: () {
          n++;
          return fuenteDisplayDePrueba();
        },
      ).generar(carne: _carne(), generadoEn: DateTime.utc(2026, 10, 2));
      expect(_esPdf(bytes), isTrue);
      expect(n, 1);
    });

    test(
      'estilosTitulo: nombre 28 y título 20 con la fuente display',
      () async {
        final f = await fuenteDisplayDePrueba();
        final e = CarnePdfService.estilosTitulo(f);
        expect(e.nombre.fontSize, 28);
        expect(e.titulo.fontSize, 20);
        expect(e.nombre.font, same(f));
        expect(e.titulo.font, same(f));
      },
    );

    test('si la fuente display falla igual genera el PDF', () async {
      final bytes = await CarnePdfService(
        cargarFuentes: fuentesDePrueba,
        cargarFuenteDisplay: fuenteDisplayQueFalla,
      ).generar(carne: _carne(), generadoEn: DateTime.utc(2026, 10, 2));
      expect(_esPdf(bytes), isTrue);
    });
  });

  group('logo de la clínica', () {
    Future<Uint8List> generar(CarnePdfService s, {String? ruta = _ruta}) =>
        s.generar(
          carne: _carne(logoPath: ruta),
          generadoEn: DateTime.utc(2026, 10, 2),
        );

    test('con ruta y PNG válido llama cargarLogo una vez', () async {
      final rutas = <String>[];
      final bytes = await generar(
        CarnePdfService(
          cargarFuentes: fuentesDePrueba,
          cargarLogo: (p) async {
            rutas.add(p);
            return _png;
          },
          validarImagen: _siempreValida,
        ),
      );
      expect(_esPdf(bytes), isTrue);
      expect(rutas, [_ruta]);
    });

    testWidgets('PNG real pasa el validador dart:ui por defecto', (
      tester,
    ) async {
      await tester.runAsync(() async {
        expect(await imagenDecodificable(_png), isTrue);
        expect(
          await imagenDecodificable(
            Uint8List.fromList(utf8.encode('no es imagen')),
          ),
          isFalse,
        );
        final bytes = await generar(
          CarnePdfService(
            cargarFuentes: fuentesDePrueba,
            cargarLogo: (_) async => _png,
          ),
        );
        expect(_esPdf(bytes), isTrue);
      });
    });

    test('sin ruta nunca llama cargarLogo', () async {
      var n = 0;
      final bytes = await generar(
        CarnePdfService(
          cargarFuentes: fuentesDePrueba,
          cargarLogo: (_) async {
            n++;
            return _png;
          },
        ),
        ruta: null,
      );
      expect(_esPdf(bytes), isTrue);
      expect(n, 0);
    });

    test('cargarLogo que lanza omite el logo sin fallar', () async {
      final bytes = await generar(
        CarnePdfService(
          cargarFuentes: fuentesDePrueba,
          cargarLogo: (_) => throw Exception('404'),
        ),
      );
      expect(_esPdf(bytes), isTrue);
    });

    test('cargarLogo que no termina vence por timeout', () async {
      final bytes = await generar(
        CarnePdfService(
          cargarFuentes: fuentesDePrueba,
          cargarLogo: (_) => Completer<Uint8List>().future,
          timeoutLogo: const Duration(milliseconds: 50),
        ),
      );
      expect(_esPdf(bytes), isTrue);
    });

    testWidgets('bytes basura se descartan antes del documento', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final bytes = await generar(
          CarnePdfService(
            cargarFuentes: fuentesDePrueba,
            cargarLogo: (_) async =>
                Uint8List.fromList(utf8.encode('no es imagen')),
          ),
        );
        expect(_esPdf(bytes), isTrue);
      });
    });
  });

  test('nombreArchivo', () {
    expect(
      CarnePdfService.nombreArchivo('Luna', DateTime.utc(2026, 10, 2)),
      'Carne_Luna_2026-10-02.pdf',
    );
  });

  test('urlCarne', () {
    final t = 'ab' * 32;
    expect(urlCarne(t), 'https://stevenescobarc.github.io/VetApp/c/#$t');
  });
}
