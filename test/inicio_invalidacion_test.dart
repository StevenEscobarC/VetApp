import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetapp/core/data/inicio_revision.dart';
import 'package:vetapp/features/appointments/domain/cita_failure.dart';
import 'package:vetapp/features/appointments/domain/entities/cita.dart';
import 'package:vetapp/features/appointments/presentation/providers/citas_providers.dart';
import 'package:vetapp/features/billing/domain/cobro_failure.dart';
import 'package:vetapp/features/billing/domain/entities/cobro.dart';
import 'package:vetapp/features/billing/domain/entities/cobro_item.dart';
import 'package:vetapp/features/billing/presentation/providers/cobros_providers.dart';
import 'package:vetapp/features/clinical_history/domain/consulta_failure.dart';
import 'package:vetapp/features/clinical_history/presentation/providers/consultas_providers.dart';
import 'package:vetapp/features/inventory/presentation/providers/inventario_providers.dart';

import 'helpers/fake_citas.dart';
import 'helpers/fake_cobros.dart';
import 'helpers/fake_consultas.dart';
import 'helpers/fake_inventario.dart';

const _falloCita = CitaFailure('sin red');

const _linea = LineaCobroNueva(
  tipo: TipoLinea.otro,
  descripcion: 'Baño',
  cantidad: 1,
  precioUnitarioCop: 30000,
);

ProviderContainer _contenedor(List overrides) {
  final c = ProviderContainer(
    retry: (_, _) => null,
    overrides: [...overrides],
  );
  addTearDown(c.dispose);
  c.listen(inicioRevisionProvider, (_, _) {});
  return c;
}

ProviderContainer _citas(FakeCitaRepository repo) =>
    _contenedor([citaRepositoryProvider.overrideWithValue(repo)]);

Future<String> _crear(CitaActions a) => a.crear(
  clienteId: 'cli-1',
  mascotaIds: const ['m-luna'],
  fechaHora: DateTime.utc(2026, 9, 30, 15),
  duracionMin: 30,
  modalidad: ModalidadCita.consultorio,
  direccion: '',
  motivo: 'Control',
  notas: '',
);

Future<void> _actualizar(CitaActions a) => a.actualizar(
  citaId: 'cita-1',
  mascotaIds: const ['m-luna'],
  fechaHora: DateTime.utc(2026, 9, 30, 16),
  duracionMin: 30,
  modalidad: ModalidadCita.consultorio,
  direccion: '',
  motivo: 'Control',
  notas: '',
);

final _escriturasCita = <String, Future<void> Function(CitaActions)>{
  'crear': _crear,
  'actualizar': _actualizar,
  'reasignar': (a) => a.reasignar('cita-1', 'vet-2'),
  'cambiarEstado': (a) => a.cambiarEstado('cita-1', EstadoCita.confirmada),
};

void main() {
  group('CitaActions incrementa inicioRevision', () {
    for (final e in _escriturasCita.entries) {
      test('${e.key} con éxito suma uno', () async {
        final c = _citas(FakeCitaRepository(citas: [citaLunaHoy]));
        final antes = c.read(inicioRevisionProvider);
        await e.value(c.read(citaActionsProvider));
        expect(c.read(inicioRevisionProvider), antes + 1);
      });

      test('${e.key} que falla igual suma uno y relanza', () async {
        final c = _citas(
          FakeCitaRepository(
            citas: [citaLunaHoy],
            error: _falloCita,
            errorCrear: _falloCita,
            errorEstado: _falloCita,
          ),
        );
        final antes = c.read(inicioRevisionProvider);
        await expectLater(
          e.value(c.read(citaActionsProvider)),
          throwsA(same(_falloCita)),
        );
        expect(c.read(inicioRevisionProvider), antes + 1);
      });
    }

    test('marcarRecordatorioEnviado no suma', () async {
      final c = _citas(FakeCitaRepository(citas: [citaLunaHoy]));
      final antes = c.read(inicioRevisionProvider);
      await c
          .read(citaActionsProvider)
          .marcarRecordatorioEnviado('cita-1', DateTime.utc(2026, 9, 30));
      expect(c.read(inicioRevisionProvider), antes);
    });
  });

  group('RegistrarConsulta incrementa inicioRevision', () {
    Future<String> registrar(ProviderContainer c) => c
        .read(registrarConsultaProvider)
        .call(mascotaId: 'm-1', diagnostico: 'Otitis', tratamiento: 'Gotas');

    test('con éxito suma uno', () async {
      final c = _contenedor([
        consultaRepositoryProvider.overrideWithValue(FakeConsultaRepository()),
      ]);
      final antes = c.read(inicioRevisionProvider);
      await registrar(c);
      expect(c.read(inicioRevisionProvider), antes + 1);
    });

    test('que falla igual suma uno y relanza', () async {
      const falla = ConsultaFailure('sin red');
      final c = _contenedor([
        consultaRepositoryProvider.overrideWithValue(
          FakeConsultaRepository(error: falla),
        ),
      ]);
      final antes = c.read(inicioRevisionProvider);
      await expectLater(registrar(c), throwsA(same(falla)));
      expect(c.read(inicioRevisionProvider), antes + 1);
    });
  });

  group('cobros incrementan inicioRevision vía invalidarCobros', () {
    ProviderContainer cobros(FakeCobrosRepository repo) => _contenedor([
      cobrosRepositoryProvider.overrideWithValue(repo),
      inventarioRepositoryProvider.overrideWithValue(
        FakeInventarioRepository(productos: [productoDePrueba()]),
      ),
    ]);

    test('emitir con éxito suma uno', () async {
      final c = cobros(FakeCobrosRepository());
      final antes = c.read(inicioRevisionProvider);
      await c
          .read(cobrosActionsProvider)
          .emitirCuentaCobro(
            clave: 'k1',
            clienteId: 'cli1',
            lineas: const [_linea],
          );
      expect(c.read(inicioRevisionProvider), antes + 1);
    });

    test('emitir que falla igual suma uno y relanza', () async {
      const fallo = CobroFailure('sin red', tipo: ErrorCobro.sinConexion);
      final c = cobros(FakeCobrosRepository(errorCrear: fallo));
      final antes = c.read(inicioRevisionProvider);
      await expectLater(
        c
            .read(cobrosActionsProvider)
            .emitirCuentaCobro(
              clave: 'k1',
              clienteId: 'cli1',
              lineas: const [_linea],
            ),
        throwsA(same(fallo)),
      );
      expect(c.read(inicioRevisionProvider), antes + 1);
    });

    test('marcar pagado suma uno', () async {
      final c = cobros(FakeCobrosRepository(cobros: [cobroDePrueba()]));
      final antes = c.read(inicioRevisionProvider);
      await c
          .read(cobrosActionsProvider)
          .marcarPagado(cobro: cobroDePrueba(), metodo: MetodoPago.nequi);
      expect(c.read(inicioRevisionProvider), antes + 1);
    });
  });
}
