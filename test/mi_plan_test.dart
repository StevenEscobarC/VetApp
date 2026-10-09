import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/plan/domain/mi_plan.dart';
import 'package:vetapp/features/plan/domain/plan_failure.dart';
import 'package:vetapp/features/plan/presentation/plan_textos.dart';
import 'package:vetapp/features/plan/presentation/providers/plan_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_plan.dart';

const _jsonCompleto = <String, dynamic>{
  'plan': 'clinica',
  'origen': 'prueba_clinica',
  'estado': 'sin_vencimiento',
  'fundador': true,
  'vigente_hasta': '2026-10-31',
  'gracia_hasta': '2026-11-15',
  'dias_restantes': 12,
  'ultimo_vencimiento': '2026-09-01',
  'ultimo_origen': 'prueba_pro',
  'pacientes_count': 42,
  'pacientes_max': null,
  'veterinarios_activos': 2,
  'miembros_max': 5,
  'logo_permitido': true,
  'logo_guardado': true,
  'protocolos_propios_permitidos': true,
  'puede_escribir': true,
  'prueba_clinica_disponible': false,
  'prueba_clinica_miembros': 5,
  'hay_colegas': true,
  'clinica_nombre': 'Clínica Patitas',
};

const _sinClinicaProfile = AuthProfile(
  id: 'vet-9',
  nombre: 'Sin Clínica',
  email: 'sin@vetapp.co',
  rol: 'VETERINARIO',
  telefono: '',
);

ProviderContainer _container({
  required AuthProfile? perfil,
  List<Override> extra = const [],
}) {
  final c = ProviderContainer(
    retry: (retryCount, error) => null,
    overrides: [
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: perfil),
      ),
      ...extra,
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('MiPlan.desdeJson', () {
    test('maps all 21 keys', () {
      final p = MiPlan.desdeJson(_jsonCompleto);
      expect(p.plan, PlanTipo.clinica);
      expect(p.origen, OrigenPlan.pruebaClinica);
      expect(p.estado, EstadoPlan.sinVencimiento);
      expect(p.fundador, isTrue);
      expect(p.vigenteHasta?.year, 2026);
      expect(p.vigenteHasta?.month, 10);
      expect(p.vigenteHasta?.day, 31);
      expect(p.graciaHasta?.day, 15);
      expect(p.diasRestantes, 12);
      expect(p.ultimoVencimiento?.month, 9);
      expect(p.ultimoOrigen, OrigenPlan.pruebaPro);
      expect(p.pacientesCount, 42);
      expect(p.pacientesMax, isNull);
      expect(p.veterinariosActivos, 2);
      expect(p.miembrosMax, 5);
      expect(p.logoPermitido, isTrue);
      expect(p.logoGuardado, isTrue);
      expect(p.protocolosPropiosPermitidos, isTrue);
      expect(p.puedeEscribir, isTrue);
      expect(p.pruebaClinicaDisponible, isFalse);
      expect(p.pruebaClinicaMiembros, 5);
      expect(p.hayColegas, isTrue);
      expect(p.clinicaNombre, 'Clínica Patitas');
    });

    test('unknown enum strings fall back instead of crashing', () {
      final p = MiPlan.desdeJson({
        ..._jsonCompleto,
        'plan': 'platino',
        'origen': 'regalo',
        'estado': 'misterio',
      });
      expect(p.plan, PlanTipo.gratis);
      expect(p.origen, OrigenPlan.gratis);
      expect(p.estado, EstadoPlan.sinVencimiento);
    });

    test('derived getters', () {
      expect(planProTrial.esPrueba, isTrue);
      expect(planProPagadoFundador.esPrueba, isFalse);
      expect(planGratis.pacientesAlTope, isFalse);
      expect(planGratisAlTope.pacientesAlTope, isTrue);
      expect(planBeta.pacientesAlTope, isFalse);
      expect(planGratis.sinCupoMiembros, isTrue);
      expect(planBeta.sinCupoMiembros, isFalse);
    });
  });

  group('plan_textos', () {
    test('nombrePlan and textoDias', () {
      expect(nombrePlan(PlanTipo.gratis), 'Plan Gratis');
      expect(nombrePlan(PlanTipo.pro), 'Plan Pro');
      expect(nombrePlan(PlanTipo.clinica), 'Plan Clínica');
      expect(nombrePlan(PlanTipo.beta), 'Plan Beta');
      expect(textoDias(0), 'último día');
      expect(textoDias(1), '1 día');
      expect(textoDias(12), '12 días');
    });

    test('insigniaPlan label table', () {
      var i = insigniaPlan(planGratis);
      expect((i.texto, i.estilo), ('Plan Gratis', EstiloPlan.gratis));

      final proVigente = planProPagadoFundador.copyWith(
        fundador: false,
        estado: EstadoPlan.vigente,
        diasRestantes: 20,
      );
      i = insigniaPlan(proVigente);
      expect((i.texto, i.estilo), ('Plan Pro', EstiloPlan.activo));

      i = insigniaPlan(planProPagadoFundador);
      expect((i.texto, i.estilo), ('Plan Pro · Fundador', EstiloPlan.activo));

      i = insigniaPlan(proVigente.copyWith(diasRestantes: 5));
      expect((i.texto, i.estilo), ('Plan Pro · 5 días', EstiloPlan.alerta));

      i = insigniaPlan(planProTrial);
      expect((i.texto, i.estilo), ('Prueba Pro · 12 días', EstiloPlan.prueba));

      i = insigniaPlan(planClinicaTrial.copyWith(diasRestantes: 3));
      expect(
        (i.texto, i.estilo),
        ('Prueba Clínica · 3 días', EstiloPlan.alerta),
      );

      i = insigniaPlan(planProTrial.copyWith(diasRestantes: 0));
      expect(i.texto, 'Prueba Pro · último día');

      i = insigniaPlan(planBeta);
      expect((i.texto, i.estilo), ('Beta', EstiloPlan.beta));

      i = insigniaPlan(planBeta.copyWith(fundador: true));
      expect(i.texto, 'Beta · Fundador');

      i = insigniaPlan(planGracia);
      expect((i.texto, i.estilo), ('Gracia · 9 días', EstiloPlan.alerta));

      i = insigniaPlan(planSoloLectura);
      expect((i.texto, i.estilo), ('Solo lectura', EstiloPlan.soloLectura));

      i = insigniaPlan(planGracia.copyWith(puedeEscribir: false));
      expect(i.texto, 'Solo lectura');
    });

    test('lineasVigencia table', () {
      var l = lineasVigencia(planGratis);
      expect(l.linea, 'Plan sin vencimiento');
      expect(l.detalle, 'Hasta 50 pacientes y 1 veterinario.');
      expect(l.nota, isNull);

      l = lineasVigencia(planProTrial);
      expect(l.linea, 'Prueba Pro hasta el 31/10/2026');
      expect(l.detalle, 'Te quedan 12 días. Sin tarjeta.');

      l = lineasVigencia(planClinicaTrial);
      expect(l.linea, 'Prueba Clínica hasta el 31/10/2026');

      l = lineasVigencia(planProTrial.copyWith(diasRestantes: 0));
      expect(l.detalle, contains('Último día.'));

      l = lineasVigencia(
        planProPagadoFundador.copyWith(
          fundador: false,
          estado: EstadoPlan.vigente,
          vigenteHasta: DateTime.utc(2026, 12, 5),
          diasRestantes: 20,
        ),
      );
      expect(l.linea, 'Activo hasta el 05/12/2026');
      expect(l.detalle, 'Te quedan 20 días.');

      l = lineasVigencia(planProPagadoFundador);
      expect(l.linea, 'Plan Fundador');
      expect(l.detalle, 'Sin fecha de vencimiento.');

      l = lineasVigencia(planBeta);
      expect(l.linea, 'Acceso Beta completo');
      expect(l.detalle, 'Todo está habilitado durante la Beta.');

      l = lineasVigencia(
        planBeta.copyWith(
          estado: EstadoPlan.vigente,
          vigenteHasta: DateTime.utc(2026, 11, 30),
          diasRestantes: 50,
        ),
      );
      expect(l.linea, 'Acceso Beta hasta el 30/11/2026');

      l = lineasVigencia(planGracia);
      expect(l.linea, 'Venció el 30/09/2026');
      expect(l.detalle, contains('9 días de gracia, hasta el 15/10/2026'));
      expect(l.detalle, contains('tus colegas quedarán en solo lectura'));

      l = lineasVigencia(planGracia.copyWith(hayColegas: false));
      expect(l.detalle, contains('volverás al plan Gratis'));

      l = lineasVigencia(
        planGratis.copyWith(
          ultimoOrigen: OrigenPlan.pruebaPro,
          ultimoVencimiento: DateTime.utc(2026, 10, 31),
        ),
      );
      expect(
        l.nota,
        'Tu prueba terminó el 31/10/2026. Tus datos están intactos.',
      );
    });

    test('no money wording in any produced string', () {
      final todos = [
        planBeta,
        planGratis,
        planGratisAlTope,
        planProTrial,
        planClinicaTrial,
        planProPagadoFundador,
        planGracia,
        planSoloLectura,
      ];
      final textos = <String>[
        for (final t in PlanTipo.values) nombrePlan(t),
        for (final p in todos) ...[
          insigniaPlan(p).texto,
          lineasVigencia(p).linea,
          lineasVigencia(p).detalle,
          lineasVigencia(p).nota ?? '',
        ],
      ];
      for (final t in textos) {
        for (final prohibida in [
          'precio',
          'pago',
          'pagar',
          'pagado',
          'COP',
          r'$',
          'factura',
        ]) {
          expect(t.contains(prohibida), isFalse, reason: '"$t" / $prohibida');
        }
      }
    });
  });

  group('providers', () {
    test('miPlanProvider is null for a profile without clinic', () async {
      final repo = FakePlanRepository();
      final c = _container(
        perfil: _sinClinicaProfile,
        extra: [planRepositoryProvider.overrideWithValue(repo)],
      );
      expect(await c.read(miPlanProvider.future), isNull);
      expect(repo.llamadas, 0);
    });

    test(
      'miPlanProvider reads the repository once for an active vet',
      () async {
        final repo = FakePlanRepository(plan: planGratis);
        final c = _container(
          perfil: vetAdminProfile,
          extra: [planRepositoryProvider.overrideWithValue(repo)],
        );
        expect(await c.read(miPlanProvider.future), planGratis);
        expect(repo.llamadas, 1);
      },
    );

    test(
      'miPlanProvider is null when the repository cannot be built',
      () async {
        final c = _container(
          perfil: vetAdminProfile,
          extra: [
            planRepositoryProvider.overrideWith(
              (ref) => throw StateError('sin'),
            ),
          ],
        );
        expect(await c.read(miPlanProvider.future), isNull);
      },
    );

    test(
      'RPC errors stay AsyncError and puedeEscribir defaults to true',
      () async {
        final repo = FakePlanRepository(error: const PlanFailure('x'));
        final c = _container(
          perfil: vetAdminProfile,
          extra: [planRepositoryProvider.overrideWithValue(repo)],
        );
        c.listen(miPlanProvider, (_, _) {});
        await expectLater(
          c.read(miPlanProvider.future),
          throwsA(isA<PlanFailure>()),
        );
        expect(c.read(miPlanProvider).hasError, isTrue);
        expect(c.read(puedeEscribirProvider), isTrue);
      },
    );

    test('puedeEscribirProvider follows the server flag', () async {
      final c = _container(
        perfil: vetAdminProfile,
        extra: [
          planRepositoryProvider.overrideWithValue(
            FakePlanRepository(plan: planSoloLectura),
          ),
        ],
      );
      c.listen(miPlanProvider, (_, _) {});
      await c.read(miPlanProvider.future);
      expect(c.read(puedeEscribirProvider), isFalse);
    });
  });
}
