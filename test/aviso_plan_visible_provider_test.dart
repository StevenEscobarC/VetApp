import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/plan/data/repositories/supabase_plan_repository.dart';
import 'package:vetapp/features/plan/domain/mi_plan.dart';
import 'package:vetapp/features/plan/domain/plan_failure.dart';
import 'package:vetapp/features/plan/presentation/aviso_plan.dart';
import 'package:vetapp/features/plan/presentation/providers/aviso_plan_visible_provider.dart';
import 'package:vetapp/features/plan/presentation/providers/plan_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_plan.dart';

/// Repositorio cuyo plan nunca llega: deja [miPlanProvider] cargando.
class _PlanColgado extends FakePlanRepository {
  final _nunca = Completer<MiPlan>();

  @override
  Future<MiPlan> miPlan() => _nunca.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer contenedor({
    MiPlan? plan,
    Object? error,
    SupabasePlanRepository? repo,
    AuthProfile perfil = vetAdminProfile,
  }) {
    final c = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        if (repo != null)
          planRepositoryProvider.overrideWithValue(repo)
        else
          ...planOverrides(plan: plan, error: error),
        authProfileProvider.overrideWith(
          () => FakeAuthProfileNotifier(profile: perfil),
        ),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(avisoPlanVisibleProvider, (_, _) {});
    addTearDown(sub.close);
    return c;
  }

  /// Deja resolver el perfil y el plan (o su error).
  Future<AvisoPlan?> leer(ProviderContainer c) async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return c.read(avisoPlanVisibleProvider);
  }

  test('null while the plan loads', () async {
    final c = contenedor(repo: _PlanColgado());
    expect(c.read(avisoPlanVisibleProvider), isNull);
    expect(await leer(c), isNull);
  });

  test('null when the plan errors', () async {
    final c = contenedor(error: const PlanFailure('x'));
    expect(await leer(c), isNull);
  });

  test('null without a notice (Beta, Pro fundador)', () async {
    expect(await leer(contenedor(plan: planBeta)), isNull);
    expect(await leer(contenedor(plan: planProPagadoFundador)), isNull);
  });

  test('returns the notice PlanBanner shows', () async {
    final casos = <MiPlan, TipoAviso>{
      planSoloLectura: TipoAviso.soloLectura,
      planGracia: TipoAviso.gracia,
      planGratisAlTope: TipoAviso.pacientesTope,
      planGratis: TipoAviso.pacientes80,
      planProTrial.copyWith(diasRestantes: 5): TipoAviso.ultimosDias,
    };
    for (final MapEntry(key: plan, value: tipo) in casos.entries) {
      final aviso = await leer(contenedor(plan: plan));
      expect(aviso?.tipo, tipo, reason: '$tipo');
    }
  });

  test('a dismissed dismissible notice is hidden', () async {
    final c = contenedor(plan: planGratis);
    expect((await leer(c))?.tipo, TipoAviso.pacientes80);
    c.read(avisosDescartadosProvider.notifier).descartar(TipoAviso.pacientes80);
    expect(c.read(avisoPlanVisibleProvider), isNull);
  });

  test('a non-dismissible notice ignores the dismissed set', () async {
    final c = contenedor(plan: planGratisAlTope);
    c
        .read(avisosDescartadosProvider.notifier)
        .descartar(TipoAviso.pacientesTope);
    expect((await leer(c))?.tipo, TipoAviso.pacientesTope);
  });

  test('admin and non-admin get the same notice as PlanBanner', () async {
    for (final plan in [planGracia, planGratisAlTope]) {
      final admin = await leer(contenedor(plan: plan));
      final colega = await leer(
        contenedor(plan: plan, perfil: vetColegaProfile),
      );
      expect(admin?.mensaje, avisoPlanPara(plan, esAdmin: true)!.mensaje);
      expect(colega?.mensaje, avisoPlanPara(plan, esAdmin: false)!.mensaje);
      expect(admin?.mensaje, isNot(colega?.mensaje));
    }
  });
}
