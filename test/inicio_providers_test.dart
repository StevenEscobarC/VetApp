import 'dart:io' as io;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/core/data/inicio_revision.dart';
import 'package:vetapp/features/appointments/data/repositories/supabase_cita_repository.dart';
import 'package:vetapp/features/appointments/domain/cita_failure.dart';
import 'package:vetapp/features/appointments/domain/entities/cita.dart';
import 'package:vetapp/features/appointments/presentation/providers/citas_providers.dart';
import 'package:vetapp/features/home/data/supabase_inicio_repository.dart';
import 'package:vetapp/features/home/domain/inicio_failure.dart';
import 'package:vetapp/features/home/domain/resumen_inicio.dart';
import 'package:vetapp/features/home/presentation/providers/inicio_providers.dart';

import 'helpers/fake_citas.dart';
import 'helpers/fake_inicio.dart';

final _ahora = DateTime.utc(2026, 11, 16, 14); // 9:00 a. m. Bogotá

const _luna = MascotaDeCita(id: 'm-luna', nombre: 'Luna', especie: 'perro');

Cita _cita(
  String id,
  DateTime fecha, {
  EstadoCita estado = EstadoCita.pendiente,
}) => Cita(
  id: id,
  clinicaId: 'cli-1',
  clienteId: 'c-maria',
  veterinarioId: 'vet-1',
  fechaHora: fecha,
  duracionMin: 30,
  modalidad: ModalidadCita.consultorio,
  motivo: 'Control',
  estado: estado,
  clienteNombre: 'María Pérez',
  mascotas: const [_luna],
);

/// Desordenadas a propósito: el fake debe ordenar.
final _citas = [
  _cita('manana-2', DateTime.utc(2026, 11, 17, 20)),
  _cita('hoy-2', DateTime.utc(2026, 11, 16, 18), estado: EstadoCita.confirmada),
  _cita('pasada', DateTime.utc(2026, 11, 16, 13)),
  _cita(
    'cancelada',
    DateTime.utc(2026, 11, 16, 16),
    estado: EstadoCita.cancelada,
  ),
  _cita('en-3-dias', DateTime.utc(2026, 11, 19, 15)),
  _cita('hoy-1', DateTime.utc(2026, 11, 16, 15)),
  _cita('manana-1', DateTime.utc(2026, 11, 17, 14)),
];

ProviderContainer _contenedor({
  FakeInicioRepository? inicio,
  FakeCitaRepository? citas,
  List<Override>? reemplazo,
}) {
  final c = ProviderContainer(
    overrides: [
      ...?reemplazo ?? inicioOverrides(inicio: inicio, citas: citas),
      clockProvider.overrideWithValue(() => _ahora),
    ],
  );
  addTearDown(c.dispose);
  c.listen(inicioResumenProvider, (_, _) {});
  c.listen(proximasCitasProvider, (_, _) {});
  return c;
}

Future<Object> _errorDe(ProviderContainer c) async {
  try {
    await c.read(proximasCitasProvider.future);
  } catch (e) {
    return e;
  }
  fail('proximasCitasProvider debía fallar');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FakeCitaRepository.proximas', () {
    test(
      'solo pendiente/confirmada desde "desde", ordenadas y limitadas',
      () async {
        final fake = FakeCitaRepository(citas: _citas);
        final r = await fake.proximas(desdeUtc: _ahora, limite: 3);
        expect(r.map((c) => c.id), ['hoy-1', 'hoy-2', 'manana-1']);
        expect(fake.consultasProximas.single, (desde: _ahora, limite: 3));
      },
    );

    test('lanza error si está asignado', () async {
      final fake = FakeCitaRepository(error: const CitaFailure('x'));
      await expectLater(
        fake.proximas(desdeUtc: _ahora),
        throwsA(isA<CitaFailure>()),
      );
    });
  });

  group('inicioResumenProvider', () {
    test('devuelve las cifras y relee al incrementar la revisión', () async {
      final inicio = FakeInicioRepository(
        resumenData: const ResumenInicio(
          consultasMes: 42,
          ingresosMes: 3849999,
          pacientesNuevos: 7,
        ),
      );
      final c = _contenedor(inicio: inicio, citas: FakeCitaRepository());
      final r = await c.read(inicioResumenProvider.future);
      expect(r.consultasMes, 42);
      expect(r.ingresosMes, 3849999);
      expect(r.pacientesNuevos, 7);
      expect(inicio.llamadas, ['resumen']);

      c.read(inicioRevisionProvider.notifier).incrementar();
      await c.read(inicioResumenProvider.future);
      expect(inicio.llamadas, ['resumen', 'resumen']);
    });
  });

  group('proximasCitasProvider', () {
    test('usa el reloj como "desde" y límite 5', () async {
      final citas = FakeCitaRepository(citas: _citas);
      final c = _contenedor(inicio: FakeInicioRepository(), citas: citas);
      final r = await c.read(proximasCitasProvider.future);
      expect(r.map((x) => x.id), [
        'hoy-1',
        'hoy-2',
        'manana-1',
        'manana-2',
        'en-3-dias',
      ]);
      expect(citas.consultasProximas, [(desde: _ahora, limite: 5)]);
    });

    test(
      'relee con inicioRevisionProvider y con citasRevisionProvider',
      () async {
        final citas = FakeCitaRepository(citas: _citas);
        final c = _contenedor(inicio: FakeInicioRepository(), citas: citas);
        await c.read(proximasCitasProvider.future);
        expect(citas.consultasProximas, hasLength(1));

        c.read(inicioRevisionProvider.notifier).incrementar();
        await c.read(proximasCitasProvider.future);
        expect(citas.consultasProximas, hasLength(2));

        c.read(citasRevisionProvider.notifier).incrementar();
        await c.read(proximasCitasProvider.future);
        expect(citas.consultasProximas, hasLength(3));
      },
    );

    test('un error de red llega como InicioFailure sin conexión', () async {
      final c = _contenedor(
        inicio: FakeInicioRepository(),
        citas: FakeCitaRepository(error: const io.SocketException('sin red')),
      );
      final e = await _errorDe(c);
      expect(e, isA<InicioFailure>());
      e as InicioFailure;
      expect(e.message, kMensajeSinConexionLectura);
      expect(e.sinConexion, isTrue);
    });

    test('otro error llega como InicioFailure genérico', () async {
      final c = _contenedor(
        inicio: FakeInicioRepository(),
        citas: FakeCitaRepository(error: const CitaFailure('crudo')),
      );
      final e = await _errorDe(c);
      expect(e, isA<InicioFailure>());
      e as InicioFailure;
      expect(e.message, 'No pudimos cargar las próximas citas.');
      expect(e.sinConexion, isFalse);
      expect(c.read(proximasCitasProvider), isA<AsyncError<List<Cita>>>());
    });

    test('de punta a punta: repositorio real sin red → sin conexión', () async {
      final real = SupabaseCitaRepository(
        SupabaseClient(
          'http://localhost:54321',
          'clave-de-prueba',
          httpClient: MockClient(
            (_) async => throw const io.SocketException('sin red'),
          ),
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
      final c = _contenedor(
        reemplazo: [
          inicioRepositoryProvider.overrideWithValue(FakeInicioRepository()),
          citaRepositoryProvider.overrideWithValue(real),
        ],
      );
      final e = await _errorDe(c);
      expect(e, isA<InicioFailure>());
      e as InicioFailure;
      expect(e.message, kMensajeSinConexionLectura);
      expect(e.sinConexion, isTrue);
    });
  });
}
