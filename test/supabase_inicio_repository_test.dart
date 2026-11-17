import 'dart:async';
import 'dart:io' as io;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:vetapp/core/data/inicio_revision.dart';
import 'package:vetapp/features/home/data/supabase_inicio_repository.dart';
import 'package:vetapp/features/home/domain/inicio_failure.dart';
import 'package:vetapp/features/home/domain/resumen_inicio.dart';

SupabaseClient _cliente(http.Client httpClient) => SupabaseClient(
  'http://localhost:54321',
  'clave-de-prueba',
  httpClient: httpClient,
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

/// Repositorio sobre un cliente HTTP que siempre lanza [error]: así se
/// prueba la clasificación de fallos de red sin red real.
SupabaseInicioRepository _repoQueLanza(Object error) =>
    SupabaseInicioRepository(_cliente(MockClient((_) async => throw error)));

/// Repositorio que responde [body] con [status] y guarda cada petición.
SupabaseInicioRepository _repoQueGuarda(
  List<http.BaseRequest> peticiones, {
  String body = '[]',
  int status = 200,
}) => SupabaseInicioRepository(
  _cliente(
    MockClient((r) async {
      peticiones.add(r);
      return http.Response(
        body,
        status,
        headers: {'content-type': 'application/json'},
        request: r,
      );
    }),
  ),
);

Future<InicioFailure> _fallo(SupabaseInicioRepository repo) async {
  try {
    await repo.resumen();
  } on InicioFailure catch (f) {
    return f;
  }
  fail('resumen() debía lanzar InicioFailure');
}

void main() {
  group('SupabaseInicioRepository.resumen', () {
    test('llama la RPC inicio_resumen y mapea las 3 cifras', () async {
      final peticiones = <http.BaseRequest>[];
      final repo = _repoQueGuarda(
        peticiones,
        body:
            '[{"consultas_mes":42,"ingresos_mes":3849999,'
            '"pacientes_nuevos_mes":7}]',
      );
      final r = await repo.resumen();
      expect(r.consultasMes, 42);
      expect(r.ingresosMes, 3849999);
      expect(r.pacientesNuevos, 7);
      expect(peticiones, hasLength(1));
      expect(peticiones.single.method, 'POST');
      expect(
        peticiones.single.url.path,
        endsWith('/rest/v1/rpc/inicio_resumen'),
      );
    });

    test('lista vacía da todo en cero', () async {
      final r = await _repoQueGuarda([]).resumen();
      expect(r.consultasMes, 0);
      expect(r.ingresosMes, 0);
      expect(r.pacientesNuevos, 0);
    });

    test('campos nulos se leen como 0', () async {
      final r = await _repoQueGuarda(
        [],
        body:
            '[{"consultas_mes":null,"ingresos_mes":null,'
            '"pacientes_nuevos_mes":null}]',
      ).resumen();
      expect(r.consultasMes, 0);
      expect(r.ingresosMes, 0);
      expect(r.pacientesNuevos, 0);
    });

    for (final (nombre, error) in <(String, Object)>[
      ('SocketException', const io.SocketException('sin red')),
      ('http.ClientException', http.ClientException('Connection failed')),
      ('TimeoutException', TimeoutException('lento')),
    ]) {
      test('$nombre → sin conexión', () async {
        final f = await _fallo(_repoQueLanza(error));
        expect(f.message, kMensajeSinConexionLectura);
        expect(
          f.message,
          'Sin conexión. Inténtalo de nuevo cuando tengas señal.',
        );
        expect(f.sinConexion, isTrue);
      });
    }

    test('PostgrestException (400) → mensaje genérico del resumen', () async {
      final f = await _fallo(
        _repoQueGuarda(
          [],
          body: '{"code":"42501","message":"texto crudo del servidor"}',
          status: 400,
        ),
      );
      expect(f.message, 'No pudimos cargar el resumen del mes.');
      expect(f.message, kErrorResumenInicio);
      expect(f.sinConexion, isFalse);
    });

    test('otro error → mensaje genérico del resumen', () async {
      final f = await _fallo(_repoQueLanza(StateError('raro')));
      expect(f.message, kErrorResumenInicio);
      expect(f.sinConexion, isFalse);
    });
  });

  test('ResumenInicio por defecto es todo cero', () {
    const r = ResumenInicio();
    expect([r.consultasMes, r.ingresosMes, r.pacientesNuevos], [0, 0, 0]);
  });

  test('inicioRevisionProvider arranca en 0 e incrementar suma 1', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(inicioRevisionProvider), 0);
    c.read(inicioRevisionProvider.notifier).incrementar();
    expect(c.read(inicioRevisionProvider), 1);
  });
}
