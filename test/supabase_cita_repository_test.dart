import 'dart:io' as io;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vetapp/core/data/limite_plan_postgrest.dart';
import 'package:vetapp/core/errors/limite_plan.dart';
import 'package:vetapp/features/appointments/data/repositories/supabase_cita_repository.dart';
import 'package:vetapp/features/appointments/domain/cita_failure.dart';

PostgrestException _check(String mensaje) =>
    PostgrestException(message: mensaje, code: '23514');

SupabaseCitaRepository _repoHttp(MockClient httpClient) =>
    SupabaseCitaRepository(
      SupabaseClient(
        'http://localhost:54321',
        'clave-de-prueba',
        httpClient: httpClient,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    );

/// Repositorio que responde [body]/[status] y guarda cada petición.
SupabaseCitaRepository _repoQueGuarda(
  List<http.BaseRequest> peticiones, {
  String body = '[]',
  int status = 200,
}) => _repoHttp(
  MockClient((r) async {
    peticiones.add(r);
    return http.Response(
      body,
      status,
      headers: {'content-type': 'application/json'},
      request: r,
    );
  }),
);

void main() {
  group('proximas', () {
    test('filtra estado en SQL, desde, orden y límite', () async {
      final peticiones = <http.BaseRequest>[];
      final r = await _repoQueGuarda(
        peticiones,
      ).proximas(desdeUtc: DateTime.utc(2026, 11, 16, 14), limite: 5);
      expect(r, isEmpty);
      expect(peticiones, hasLength(1));
      final req = peticiones.single;
      expect(req.method, 'GET');
      expect(req.url.path, endsWith('/rest/v1/citas'));
      final q = req.url.queryParameters;
      // postgrest-dart cita cada valor; PostgREST lo lee igual que sin comillas.
      expect(
        q['estado'],
        anyOf('in.(pendiente,confirmada)', 'in.("pendiente","confirmada")'),
      );
      expect(q['fecha_hora'], 'gte.2026-11-16T14:00:00.000Z');
      expect(q['order'], anyOf('fecha_hora.asc', 'fecha_hora.asc.nullslast'));
      expect(q['limit'], '5');
    });

    test('un SocketException se relanza tal cual (no CitaFailure)', () async {
      final repo = _repoHttp(
        MockClient((_) async => throw const io.SocketException('sin red')),
      );
      await expectLater(
        repo.proximas(desdeUtc: DateTime.utc(2026, 11, 16)),
        throwsA(isA<io.SocketException>()),
      );
    });

    test('un 400 JSON se vuelve CitaFailure', () async {
      final repo = _repoQueGuarda(
        [],
        body: '{"code":"42501","message":"texto crudo"}',
        status: 400,
      );
      await expectLater(
        repo.proximas(desdeUtc: DateTime.utc(2026, 11, 16)),
        throwsA(isA<CitaFailure>()),
      );
    });
  });

  group('mensajeErrorCita - límites del plan', () {
    const soloLectura =
        'Tu cuenta está en solo lectura. Pide al administrador que active el '
        'plan.';
    test('LP004 por code', () {
      expect(
        mensajeErrorCita(PostgrestException(message: 'x', code: 'LP004')),
        soloLectura,
      );
    });
    test('LP004 solo en hint', () {
      expect(
        mensajeErrorCita(
          PostgrestException(message: 'x', code: 'P0001', hint: 'LP004'),
          estado: true,
        ),
        soloLectura,
      );
    });
    test('limitePlanDe detecta soloLectura', () {
      expect(
        limitePlanDe(PostgrestException(message: 'x', code: 'LP004')),
        LimitePlan.soloLectura,
      );
    });
    test('otros códigos conservan su mensaje', () {
      expect(
        mensajeErrorCita(PostgrestException(message: 'x', code: 'PGRST116')),
        'Esta cita ya no existe.',
      );
    });
  });

  group('mensajeErrorCita - reasignación', () {
    test('veterinario fuera de la clínica (23503)', () {
      expect(
        mensajeErrorCita(
          PostgrestException(
            message: 'Ese veterinario ya no está en tu clínica.',
            code: '23503',
          ),
        ),
        'Ese veterinario ya no está en tu clínica.',
      );
    });

    test('reasignar una cita cerrada (23514)', () {
      expect(
        mensajeErrorCita(
          _check('Solo se pueden reasignar citas pendientes o confirmadas.'),
        ),
        'Solo se pueden reasignar citas pendientes o confirmadas.',
      );
    });
  });

  group('mensajeErrorCita - check_violation (23514)', () {
    test('quitar una mascota con consulta no se confunde con "elige una"', () {
      expect(
        mensajeErrorCita(
          _check(
            'No puedes quitar una mascota que ya tiene consulta registrada '
            'en esta cita.',
          ),
        ),
        'No puedes quitar una mascota que ya tiene consulta registrada en '
        'esta cita.',
      );
    });

    test('sin mascotas pide elegir al menos una', () {
      expect(
        mensajeErrorCita(_check('Elige al menos una mascota.')),
        'Elige al menos una mascota.',
      );
    });

    test('domicilio sin dirección', () {
      expect(
        mensajeErrorCita(_check('citas_domicilio_direccion')),
        'Escribe la dirección para la visita a domicilio.',
      );
    });

    test('cita terminal no editable', () {
      expect(
        mensajeErrorCita(
          _check('Solo se pueden editar citas pendientes o confirmadas.'),
        ),
        'Solo se pueden editar citas pendientes o confirmadas.',
      );
    });

    test('transición de estado rechazada por el trigger', () {
      expect(
        mensajeErrorCita(
          _check('Cambio de estado no permitido: cancelada -> completada.'),
          estado: true,
        ),
        'Esta cita ya no puede cambiar a ese estado.',
      );
    });

    test('columnas fijas de la cita', () {
      expect(
        mensajeErrorCita(
          _check(
            'No se puede cambiar el cliente, la clínica ni el veterinario '
            'de una cita.',
          ),
        ),
        'No se puede cambiar el cliente de una cita.',
      );
    });

    test('mensaje desconocido cae en el genérico', () {
      expect(
        mensajeErrorCita(_check('otra cosa')),
        'Revisa los datos de la cita.',
      );
    });
  });

  group('citaDesdeFila', () {
    Map<String, dynamic> fila() => {
      'id': 'c1',
      'clinica_id': 'cli-1',
      'cliente_id': 'c-1',
      'veterinario_id': 'vet-2',
      'fecha_hora': '2026-09-30T15:30:00Z',
      'duracion_min': 30,
      'modalidad': 'consultorio',
      'motivo': 'Control',
      'estado': 'pendiente',
    };

    test('lee el nombre del embed veterinario', () {
      final c = citaDesdeFila({
        ...fila(),
        'veterinario': {'nombre': 'Luis Torres'},
      });
      expect(c.veterinarioNombre, 'Luis Torres');
    });

    test('sin embed el nombre es null', () {
      expect(citaDesdeFila(fila()).veterinarioNombre, isNull);
    });
  });
}
