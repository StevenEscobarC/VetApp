import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetapp/features/appointments/presentation/providers/citas_providers.dart';
import 'package:vetapp/features/appointments/domain/entities/cita.dart';
import 'package:vetapp/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/clinical_history/domain/consulta_failure.dart';
import 'package:vetapp/features/clinical_history/domain/entities/consulta.dart';
import 'package:vetapp/features/clinical_history/presentation/providers/consultas_providers.dart';
import 'package:vetapp/features/patients/domain/entities/peso_registro.dart';
import 'package:vetapp/features/patients/presentation/providers/mascotas_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_citas.dart';
import 'helpers/fake_consultas.dart';
import 'helpers/fake_mascotas.dart';

ProviderContainer _containerWith({
  required FakeConsultaRepository repo,
  FakeMascotaRepository? mascotaRepo,
  AuthProfile? profile = vetProfile,
  FakeCitaRepository? citaRepo,
}) {
  return ProviderContainer(
    // Same convention as mascotas_providers_test.dart: disable Riverpod 3's
    // default exponential-backoff retry so an intentionally thrown
    // ConsultaFailure settles into AsyncError immediately.
    retry: (retryCount, error) => null,
    overrides: [
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: profile),
      ),
      consultaRepositoryProvider.overrideWithValue(repo),
      if (citaRepo != null) citaRepositoryProvider.overrideWithValue(citaRepo),
      if (mascotaRepo != null)
        mascotaRepositoryProvider.overrideWithValue(mascotaRepo),
    ],
  );
}

void main() {
  group('consultasProvider', () {
    test('devuelve solo las consultas de la mascota pedida', () async {
      final repo = FakeConsultaRepository(
        consultas: [
          consultaOtitis,
          Consulta(
            id: 'con-otra',
            mascotaId: 'm-2',
            veterinarioId: 'vet-1',
            fecha: DateTime(2026, 1, 1),
            diagnostico: 'Otro',
            tratamiento: 'Otro',
          ),
        ],
      );
      final container = _containerWith(repo: repo);
      addTearDown(container.dispose);

      final consultas = await container.read(consultasProvider('m-1').future);

      expect(consultas, hasLength(1));
      expect(consultas.single.id, 'con-1');
    });

    test(
      'un fake con error se propaga como AsyncError con ConsultaFailure',
      () async {
        const falla = ConsultaFailure(
          'No pudimos cargar la historia clínica. Intenta de nuevo.',
        );
        final repo = FakeConsultaRepository(error: falla);
        final container = _containerWith(repo: repo);
        addTearDown(container.dispose);

        await expectLater(
          container.read(consultasProvider('m-1').future),
          throwsA(isA<ConsultaFailure>()),
        );
      },
    );
  });

  group('registrarConsultaProvider', () {
    test('sin citaId registra citaId null', () async {
      final repo = FakeConsultaRepository();
      final container = _containerWith(repo: repo);
      addTearDown(container.dispose);

      await container.read(registrarConsultaProvider)(
        mascotaId: 'm-1',
        diagnostico: 'Dx',
        tratamiento: 'Tx',
      );

      expect(repo.registros.single.citaId, isNull);
    });

    test('con citaId lo reenvía e invalida citaProvider', () async {
      final repo = FakeConsultaRepository();
      final citaRepo = FakeCitaRepository(citas: [citaLunaHoy]);
      final container = _containerWith(repo: repo, citaRepo: citaRepo);
      addTearDown(container.dispose);

      final sub = container.listen(citaProvider('cita-1'), (_, _) {});
      addTearDown(sub.close);
      expect((await container.read(citaProvider('cita-1').future)).estado,
          EstadoCita.pendiente);
      // La cita cambia en el servidor; solo una invalidación la relee.
      citaRepo.citas[0] = citaLunaHoy.copyWith(
        mascotasConConsulta: {'m-luna'},
      );

      await container.read(registrarConsultaProvider)(
        mascotaId: 'm-luna',
        diagnostico: 'Dx',
        tratamiento: 'Tx',
        citaId: 'cita-1',
      );

      expect(repo.registros.single.citaId, 'cita-1');
      final cita = await container.read(citaProvider('cita-1').future);
      expect(cita.mascotasConConsulta, {'m-luna'});
    });
    test(
      'registrar solo con diagnóstico y tratamiento recortados no envía '
      'ningún campo opcional (D-03)',
      () async {
        final repo = FakeConsultaRepository();
        final container = _containerWith(repo: repo);
        addTearDown(container.dispose);

        await container.read(registrarConsultaProvider)(
          mascotaId: 'm-1',
          diagnostico: '  Otitis  ',
          tratamiento: 'Gotas',
        );

        expect(repo.registros, hasLength(1));
        final registro = repo.registros.single;
        expect(registro.diagnostico, 'Otitis');
        expect(registro.tratamiento, 'Gotas');
        expect(registro.anamnesis, isNull);
        expect(registro.evolucion, isNull);
        expect(registro.mucosas, isNull);
        expect(registro.pesoKg, isNull);
        expect(registro.temperaturaC, isNull);
        expect(registro.frecuenciaCardiaca, isNull);
        expect(registro.frecuenciaRespiratoria, isNull);
      },
    );

    test(
      'optionales en blanco se registran como null, nunca como cadena vacía',
      () async {
        final repo = FakeConsultaRepository();
        final container = _containerWith(repo: repo);
        addTearDown(container.dispose);

        await container.read(registrarConsultaProvider)(
          mascotaId: 'm-1',
          diagnostico: 'Dx',
          tratamiento: 'Tx',
          anamnesis: '   ',
          evolucion: '',
        );

        final registro = repo.registros.single;
        expect(registro.anamnesis, isNull);
        expect(registro.evolucion, isNull);
      },
    );

    test(
      'un peso en la consulta alimenta mascota_pesos sin una llamada '
      'separada, y ambos providers se invalidan (D-02/Pitfall 3)',
      () async {
        final mascotaRepo = FakeMascotaRepository(
          pesosPorMascota: {
            'm-1': [
              PesoRegistro(
                id: 'p-1',
                mascotaId: 'm-1',
                pesoKg: 10,
                registradoEn: DateTime(2026, 1, 1),
              ),
            ],
          },
        );
        final consultaRepo = FakeConsultaRepository(mascotas: mascotaRepo);
        final container = _containerWith(
          repo: consultaRepo,
          mascotaRepo: mascotaRepo,
        );
        addTearDown(container.dispose);

        // Keep both providers alive so invalidation is observable.
        container.listen(pesosProvider('m-1'), (_, _) {});
        container.listen(consultasProvider('m-1'), (_, _) {});

        await container.read(pesosProvider('m-1').future);
        await container.read(consultasProvider('m-1').future);

        await container.read(registrarConsultaProvider)(
          mascotaId: 'm-1',
          diagnostico: 'Control',
          tratamiento: 'Ninguno',
          pesoKg: 4.2,
        );

        expect(consultaRepo.registros, hasLength(1));
        expect(consultaRepo.registros.single.pesoKg, 4.2);
        expect(mascotaRepo.pesosRegistrados, isEmpty);

        final pesos = await container.read(pesosProvider('m-1').future);
        expect(pesos, hasLength(2));

        final consultas = await container.read(
          consultasProvider('m-1').future,
        );
        expect(
          consultas.any((c) => c.examenFisico.pesoKg == 4.2),
          isTrue,
        );
      },
    );

    test('un fake que falla hace que registrar lance ConsultaFailure', () async {
      const falla = ConsultaFailure(
        'No pudimos guardar la consulta. Intenta de nuevo.',
      );
      final repo = FakeConsultaRepository(error: falla);
      final container = _containerWith(repo: repo);
      addTearDown(container.dispose);

      await expectLater(
        container.read(registrarConsultaProvider)(
          mascotaId: 'm-1',
          diagnostico: 'Dx',
          tratamiento: 'Tx',
        ),
        throwsA(isA<ConsultaFailure>()),
      );
    });
  });
}
