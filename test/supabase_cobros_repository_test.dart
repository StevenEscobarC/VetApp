import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:vetapp/core/errors/limite_plan.dart';
import 'package:vetapp/features/billing/data/repositories/supabase_cobros_repository.dart';
import 'package:vetapp/features/billing/domain/cobro_failure.dart';
import 'package:vetapp/features/billing/domain/entities/cobro.dart';
import 'package:vetapp/features/billing/domain/entities/cobro_item.dart';

PostgrestException _pg(String code, {String? hint, String? details}) =>
    PostgrestException(
      message: 'texto crudo del servidor',
      code: code,
      hint: hint,
      details: details,
    );

/// Repositorio sobre un cliente HTTP que siempre lanza [error]: así se
/// prueba la clasificación de fallos de red sin red real.
SupabaseCobrosRepository _repoQueLanza(Object error) =>
    SupabaseCobrosRepository(
      SupabaseClient(
        'http://localhost:54321',
        'clave-de-prueba',
        httpClient: MockClient((_) async => throw error),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    );

/// Repositorio que responde `[]` y guarda cada petición en [peticiones].
SupabaseCobrosRepository _repoQueGuarda(List<http.BaseRequest> peticiones) =>
    SupabaseCobrosRepository(
      SupabaseClient(
        'http://localhost:54321',
        'clave-de-prueba',
        httpClient: MockClient((r) async {
          peticiones.add(r);
          return http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
            request: r,
          );
        }),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    );

const _lineas = [
  LineaCobroNueva(
    tipo: TipoLinea.producto,
    descripcion: '  Amoxicilina ',
    cantidad: 2,
    precioUnitarioCop: 18000,
    productoId: 'p1',
  ),
];

void main() {
  group('cobroFailureDe / mensajeErrorCobro', () {
    test('IN001 con detalle arma el mensaje con plural de la unidad', () {
      String det(int quedan) =>
          '{"producto_id":"p1","producto":"Amoxicilina","quedan":$quedan,'
          '"unidad":"frasco"}';
      final f = cobroFailureDe(_pg('IN001', details: det(2)));
      expect(f.message, 'Solo quedan 2 frascos de Amoxicilina.');
      expect(f.tipo, ErrorCobro.stockInsuficiente);
      expect(f.productoId, 'p1');
      expect(f.quedan, 2);
      expect(
        cobroFailureDe(_pg('IN001', details: det(1))).message,
        'Solo queda 1 frasco de Amoxicilina.',
      );
      expect(
        cobroFailureDe(_pg('IN001', details: det(0))).message,
        'Amoxicilina está agotado.',
      );
    });

    test('IN001 sin detalle o ilegible usa el mensaje genérico', () {
      for (final d in [null, 'no es json', '[1,2]', '{"quedan":"x"}']) {
        final f = cobroFailureDe(_pg('IN001', details: d));
        expect(f.message, 'No hay suficiente stock para esta cuenta de cobro.');
        expect(f.tipo, ErrorCobro.stockInsuficiente);
      }
    });

    test('IN002 con y sin detalle', () {
      final f = cobroFailureDe(
        _pg('IN002', details: '{"producto_id":"p9","producto":"Gasas"}'),
      );
      expect(f.message, 'Gasas ya no está disponible. Quítalo del cobro.');
      expect(f.tipo, ErrorCobro.productoNoDisponible);
      expect(f.productoId, 'p9');
      final g = cobroFailureDe(_pg('IN002'));
      expect(
        g.message,
        'Ese producto ya no está disponible. Quítalo del cobro.',
      );
      expect(g.tipo, ErrorCobro.productoNoDisponible);
    });

    test('BC003 lleva el número existente', () {
      final f = cobroFailureDe(_pg('BC003', details: '{"numero":"CC-0012"}'));
      expect(f.message, 'Esta visita ya tiene la cuenta de cobro CC-0012.');
      expect(f.tipo, ErrorCobro.visitaYaCobrada);
      expect(f.numeroExistente, 'CC-0012');
    });

    final casos = <String, (String, ErrorCobro)>{
      'BC001': (
        'Esta cuenta de cobro cambió. Actualiza para ver su estado.',
        ErrorCobro.estadoInvalido,
      ),
      'BC002': (
        'Esta cotización ya no se puede usar. Actualiza la lista.',
        ErrorCobro.cotizacionNoDisponible,
      ),
      // WR-06: un 23505 sin la constraint de servicios no es "nombre repetido".
      '23505': (
        'No pudimos completar la operación. Intenta de nuevo.',
        ErrorCobro.otro,
      ),
      '42501': (
        'Solo el administrador o quien la emitió puede hacer esto.',
        ErrorCobro.sinPermiso,
      ),
      '23514': ('Revisa los datos del cobro.', ErrorCobro.datosInvalidos),
      'XX999': (
        'No pudimos completar la operación. Intenta de nuevo.',
        ErrorCobro.otro,
      ),
    };
    casos.forEach((code, esperado) {
      test('código $code', () {
        final e = _pg(code);
        final f = cobroFailureDe(e);
        expect(f.message, esperado.$1);
        expect(mensajeErrorCobro(e), esperado.$1);
        expect(f.tipo, esperado.$2);
        expect(f.limite, isNull);
        expect(f.message, isNot(contains('crudo')));
      });
    });

    test('23505 de clinica_servicios_nombre_activo_uq → nombre repetido', () {
      final e = PostgrestException(
        message:
            'duplicate key value violates unique constraint '
            '"clinica_servicios_nombre_activo_uq"',
        code: '23505',
      );
      final f = cobroFailureDe(e);
      expect(f.tipo, ErrorCobro.nombreDuplicado);
      expect(f.message, 'Ya tienes un servicio con ese nombre.');
    });

    test('23505 de otra constraint (cobros_numero_uq) → genérico', () {
      final e = PostgrestException(
        message:
            'duplicate key value violates unique constraint "cobros_numero_uq"',
        code: '23505',
        details: 'Key (clinica_id, tipo, numero)=(x, cuenta_cobro, 3) exists.',
      );
      final f = cobroFailureDe(e);
      expect(f.tipo, ErrorCobro.otro);
      expect(f.message, isNot(contains('servicio')));
    });

    const soloLectura =
        'Tu cuenta está en solo lectura. Pide al administrador que active el '
        'plan.';

    test('LP004 por código', () {
      final f = cobroFailureDe(_pg('LP004'));
      expect(f.message, soloLectura);
      expect(f.tipo, ErrorCobro.soloLectura);
      expect(f.limite, LimitePlan.soloLectura);
    });

    test('LP004 por hint con código P0001', () {
      final f = cobroFailureDe(_pg('P0001', hint: 'LP004'));
      expect(f.message, soloLectura);
      expect(f.tipo, ErrorCobro.soloLectura);
      expect(f.limite, LimitePlan.soloLectura);
    });
  });

  group('fallos de red por tipo', () {
    Future<CobroFailure> fallo(Object error) async {
      try {
        await _repoQueLanza(
          error,
        ).crearCuentaCobro(clave: 'k1', clienteId: 'cli1', lineas: _lineas);
      } on CobroFailure catch (f) {
        return f;
      }
      fail('debía lanzar CobroFailure');
    }

    test('TimeoutException → sin conexión del cobro', () async {
      final f = await fallo(TimeoutException('lento'));
      expect(f.tipo, ErrorCobro.sinConexion);
      expect(f.message, kMensajeSinConexionCobro);
      expect(f.message, 'Sin conexión, el cobro no se creó.');
    });

    test('http.ClientException → sin conexión del cobro', () async {
      final f = await fallo(http.ClientException('Connection failed'));
      expect(f.tipo, ErrorCobro.sinConexion);
      expect(f.message, kMensajeSinConexionCobro);
    });

    test('FormatException → genérico de la operación', () async {
      final f = await fallo(const FormatException('basura'));
      expect(f.tipo, ErrorCobro.otro);
      expect(f.message, 'No pudimos crear el cobro. Intenta de nuevo.');
    });

    test('mensajes sin conexión por operación (D-21)', () {
      expect(
        kMensajeSinConexionCotizacion,
        'Sin conexión, la cotización no se guardó.',
      );
      expect(
        kMensajeSinConexionPago,
        'Sin conexión, el pago no se guardó. Inténtalo de nuevo cuando tengas '
        'señal.',
      );
      expect(
        kMensajeSinConexionAnulacion,
        'Sin conexión, la anulación no se guardó. Inténtalo de nuevo cuando '
        'tengas señal.',
      );
      expect(
        kMensajeSinConexionServicio,
        'Sin conexión. No se guardaron los cambios. Inténtalo de nuevo cuando '
        'tengas señal.',
      );
    });
  });

  group('lecturas sin conexión (WR-05)', () {
    test('el texto de lectura no dice que se perdieron cambios', () {
      expect(
        kMensajeSinConexionLectura,
        'Sin conexión. Inténtalo de nuevo cuando tengas señal.',
      );
    });

    final lecturas =
        <String, Future<Object?> Function(SupabaseCobrosRepository)>{
          'cobros': (r) => r.cobros(TipoCobro.cuentaCobro),
          'cobro': (r) => r.cobro('c1'),
          'resumen': (r) => r.resumen(),
          'servicios': (r) => r.servicios(),
          'cobroVinculado': (r) => r.cobroVinculado(citaId: 'cita1'),
          'datosPdf': (r) => r.datosPdf('c1'),
        };
    lecturas.forEach((nombre, leer) {
      test('$nombre sin red → mensaje de lectura', () async {
        try {
          await leer(_repoQueLanza(http.ClientException('Connection failed')));
          fail('debía lanzar CobroFailure');
        } on CobroFailure catch (f) {
          expect(f.tipo, ErrorCobro.sinConexion);
          expect(f.message, kMensajeSinConexionLectura);
          expect(f.message, isNot(contains('No se guardaron')));
        }
      });
    });
  });

  group('cobros: filtro por estado en el servidor (WR-02)', () {
    test('con estado filtra tipo y estado en la consulta', () async {
      final peticiones = <http.BaseRequest>[];
      await _repoQueGuarda(
        peticiones,
      ).cobros(TipoCobro.cuentaCobro, estado: EstadoCobro.pendiente);
      final q = peticiones.single.url.queryParameters;
      expect(q['tipo'], 'eq.cuenta_cobro');
      expect(q['estado'], 'eq.pendiente');
      expect(q['limit'], '50');
    });

    test('pagadas', () async {
      final peticiones = <http.BaseRequest>[];
      await _repoQueGuarda(
        peticiones,
      ).cobros(TipoCobro.cuentaCobro, estado: EstadoCobro.pagada);
      expect(peticiones.single.url.queryParameters['estado'], 'eq.pagada');
    });

    test('sin estado no filtra por estado', () async {
      final peticiones = <http.BaseRequest>[];
      await _repoQueGuarda(peticiones).cobros(TipoCobro.cotizacion);
      final q = peticiones.single.url.queryParameters;
      expect(q['tipo'], 'eq.cotizacion');
      expect(q.containsKey('estado'), isFalse);
    });
  });

  group('params', () {
    test('paramsCrearCuentaCobro: todas las claves, sin total ni número', () {
      final p = SupabaseCobrosRepository.paramsCrearCuentaCobro(
        clave: 'k1',
        clienteId: 'cli1',
        lineas: _lineas,
        mascotaId: 'm1',
        citaId: 'ci1',
      );
      expect(p.keys.toSet(), {
        'p_clave',
        'p_cliente_id',
        'p_items',
        'p_mascota_id',
        'p_cita_id',
        'p_consulta_id',
        'p_cotizacion_id',
      });
      expect(p['p_clave'], 'k1');
      expect(p['p_mascota_id'], 'm1');
      expect(p['p_cita_id'], 'ci1');
      expect(p['p_consulta_id'], isNull);
      expect(p['p_cotizacion_id'], isNull);
      expect(p['p_items'], [lineaAJson(_lineas.first)]);
    });

    test('paramsCrearCotizacion', () {
      final p = SupabaseCobrosRepository.paramsCrearCotizacion(
        clave: 'k2',
        clienteId: 'cli1',
        lineas: _lineas,
      );
      expect(p.keys.toSet(), {
        'p_clave',
        'p_cliente_id',
        'p_items',
        'p_mascota_id',
      });
    });

    test('paramsEditarCotizacion', () {
      final p = SupabaseCobrosRepository.paramsEditarCotizacion(
        id: 'c1',
        clienteId: 'cli1',
        lineas: _lineas,
        mascotaId: 'm1',
      );
      expect(p.keys.toSet(), {
        'p_id',
        'p_cliente_id',
        'p_items',
        'p_mascota_id',
      });
    });

    test('paramsMarcarPagado', () {
      final p = SupabaseCobrosRepository.paramsMarcarPagado(
        id: 'c1',
        metodo: MetodoPago.nequi,
        fecha: DateTime(2026, 11, 13),
      );
      expect(p, {'p_id': 'c1', 'p_metodo': 'nequi', 'p_fecha': '2026-11-13'});
      final q = SupabaseCobrosRepository.paramsMarcarPagado(
        id: 'c1',
        metodo: MetodoPago.efectivo,
      );
      expect(q.keys.toSet(), {'p_id', 'p_metodo', 'p_fecha'});
      expect(q['p_fecha'], isNull);
    });

    test('paramsAnular recorta el motivo', () {
      final p = SupabaseCobrosRepository.paramsAnular(
        id: 'c1',
        motivo: '  Error en el precio ',
      );
      expect(p, {'p_id': 'c1', 'p_motivo': 'Error en el precio'});
    });

    test('paramsGuardarServicio', () {
      final p = SupabaseCobrosRepository.paramsGuardarServicio(
        nombre: ' Baño ',
        precioCop: 30000,
      );
      expect(p, {'p_id': null, 'p_nombre': 'Baño', 'p_precio_cop': 30000});
    });

    test('ningún builder envía total ni número', () {
      final todos = [
        SupabaseCobrosRepository.paramsCrearCuentaCobro(
          clave: 'k',
          clienteId: 'c',
          lineas: _lineas,
        ),
        SupabaseCobrosRepository.paramsCrearCotizacion(
          clave: 'k',
          clienteId: 'c',
          lineas: _lineas,
        ),
        SupabaseCobrosRepository.paramsEditarCotizacion(
          id: 'x',
          clienteId: 'c',
          lineas: _lineas,
        ),
        SupabaseCobrosRepository.paramsMarcarPagado(
          id: 'x',
          metodo: MetodoPago.otro,
        ),
        SupabaseCobrosRepository.paramsAnular(id: 'x', motivo: 'abc'),
        SupabaseCobrosRepository.paramsGuardarServicio(
          nombre: 'n',
          precioCop: 1,
        ),
      ];
      for (final p in todos) {
        for (final k in p.keys) {
          expect(k, isNot(contains('total')));
          expect(k, isNot(contains('numero')));
        }
      }
    });

    test('lineaAJson', () {
      final j = lineaAJson(_lineas.first);
      expect(j, {
        'tipo': 'producto',
        'producto_id': 'p1',
        'servicio_id': null,
        'descripcion': 'Amoxicilina',
        'cantidad': 2,
        'precio_unitario_cop': 18000,
      });
      expect(j['cantidad'], isA<int>());
      expect(j['precio_unitario_cop'], isA<int>());
    });

    test('kSelectCobro trae ítems y embeds', () {
      expect(SupabaseCobrosRepository.kSelectCobro, contains('cobro_items(*)'));
      expect(
        SupabaseCobrosRepository.kSelectCobro,
        contains('autor:perfiles!cobros_creado_por_perfil_fkey(nombre)'),
      );
    });
  });

  group('mapeo de filas', () {
    Map<String, dynamic> fila() => {
      'id': 'c1',
      'tipo': 'cuenta_cobro',
      'numero': 12,
      'estado': 'pagada',
      'fecha': '2026-11-01',
      'cliente_id': 'cli1',
      'cliente_nombre': 'Laura Gómez',
      'cliente_cedula': '1020304050',
      'mascota_id': 'm1',
      'mascota_nombre': 'Rocky',
      'cita_id': 'ci1',
      'consulta_id': null,
      'total_cop': 86000,
      'metodo_pago': 'nequi',
      'pagada_el': '2026-11-02',
      'valida_hasta': null,
      'cotizacion_origen_id': 'cot1',
      'convertida_en_id': null,
      'creado_por': 'vet1',
      'anulada_at': null,
      'motivo_anulacion': null,
      'created_at': '2026-11-01T15:00:00Z',
      'cobro_items': [
        {
          'orden': 2,
          'tipo': 'producto',
          'descripcion': 'Amoxicilina',
          'cantidad': 2,
          'precio_unitario_cop': 18000,
          'producto_id': 'p1',
          'servicio_id': null,
        },
        {
          'orden': 1,
          'tipo': 'servicio',
          'descripcion': 'Consulta',
          'cantidad': 1,
          'precio_unitario_cop': 50000,
          'producto_id': null,
          'servicio_id': 's1',
        },
      ],
      'autor': {'nombre': 'Ana'},
      'anulador': null,
      'convertida': null,
      'origen': {'numero': 4},
    };

    test('cobroDesdeFila completa, ítems ordenados', () {
      final c = cobroDesdeFila(fila());
      expect(c.id, 'c1');
      expect(c.tipo, TipoCobro.cuentaCobro);
      expect(c.numeroTexto, 'CC-0012');
      expect(c.estado, EstadoCobro.pagada);
      expect(c.fecha, DateTime.utc(2026, 11, 1));
      expect(c.pagadaEl, DateTime.utc(2026, 11, 2));
      expect(c.validaHasta, isNull);
      expect(c.metodoPago, MetodoPago.nequi);
      expect(c.clienteCedula, '1020304050');
      expect(c.mascotaNombre, 'Rocky');
      expect(c.citaId, 'ci1');
      expect(c.totalCop, 86000);
      expect(c.items.map((i) => i.orden).toList(), [1, 2]);
      expect(c.items.first.servicioId, 's1');
      expect(c.items.last.tipo, TipoLinea.producto);
      expect(c.items.last.subtotalCop, 36000);
      expect(c.productoIds, {'p1'});
      expect(c.autorNombre, 'Ana');
      expect(c.cotizacionOrigenId, 'cot1');
      expect(c.cotizacionOrigenNumero, 4);
      expect(c.convertidaEnNumero, isNull);
      expect(c.anuladaPorNombre, isNull);
    });

    test('cotización anulada, sin método, con embeds nulos', () {
      final f = fila()
        ..['tipo'] = 'cotizacion'
        ..['estado'] = 'anulada'
        ..['metodo_pago'] = null
        ..['pagada_el'] = null
        ..['valida_hasta'] = '2026-11-16'
        ..['anulada_at'] = '2026-11-03T14:30:00Z'
        ..['motivo_anulacion'] = 'Precio errado'
        ..['autor'] = null
        ..['origen'] = null
        ..['anulador'] = {'nombre': 'Admin'}
        ..['convertida'] = {'numero': 7}
        ..['convertida_en_id'] = 'cc7';
      final c = cobroDesdeFila(f);
      expect(c.tipo, TipoCobro.cotizacion);
      expect(c.anulada, isTrue);
      expect(c.metodoPago, isNull);
      expect(c.validaHasta, DateTime.utc(2026, 11, 16));
      expect(c.anuladaAt, DateTime.parse('2026-11-03T14:30:00Z').toLocal());
      expect(c.motivoAnulacion, 'Precio errado');
      expect(c.autorNombre, isNull);
      expect(c.cotizacionOrigenNumero, isNull);
      expect(c.anuladaPorNombre, 'Admin');
      expect(c.convertidaEnNumero, 7);
    });

    test('cobroDesdeFila acepta la forma plana de cobro_para_pdf', () {
      final f = fila()
        ..remove('autor')
        ..remove('origen')
        ..['autor_nombre'] = 'Ana'
        ..['cotizacion_origen_numero'] = 4;
      final c = cobroDesdeFila(f);
      expect(c.autorNombre, 'Ana');
      expect(c.cotizacionOrigenNumero, 4);
    });

    test('servicioDesdeFila', () {
      final s = servicioDesdeFila({
        'id': 's1',
        'nombre': 'Consulta',
        'precio_cop': 50000,
        'archivado_at': null,
      });
      expect((s.id, s.nombre, s.precioCop), ('s1', 'Consulta', 50000));
    });
  });
}
