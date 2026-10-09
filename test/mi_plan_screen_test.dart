import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vetapp/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/plan/domain/mi_plan.dart';
import 'package:vetapp/features/plan/domain/plan_failure.dart';
import 'package:vetapp/features/plan/presentation/providers/plan_providers.dart';
import 'package:vetapp/features/plan/presentation/screens/mi_plan_screen.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_plan.dart';
import 'helpers/router_harness.dart';

const _barra = ValueKey('uso-barra');

List<Override> _overrides(
  FakePlanRepository repo, {
  AuthProfile perfil = vetAdminProfile,
}) => [
  authProfileProvider.overrideWith(
    () => FakeAuthProfileNotifier(profile: perfil),
  ),
  planRepositoryProvider.overrideWithValue(repo),
];

Widget _pantalla(
  FakePlanRepository repo, {
  AuthProfile perfil = vetAdminProfile,
}) => routerHarness(
  initialLocation: '/mas/plan',
  routes: [GoRoute(path: '/mas/plan', builder: (_, _) => const MiPlanScreen())],
  overrides: _overrides(repo, perfil: perfil),
);

Future<void> _abrir(
  WidgetTester tester,
  MiPlan plan, {
  AuthProfile perfil = vetAdminProfile,
  FakePlanRepository? repo,
}) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _pantalla(repo ?? FakePlanRepository(plan: plan), perfil: perfil),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('trial Pro shows tag, date line and remaining days', (
    tester,
  ) async {
    await _abrir(tester, planProTrial);
    expect(find.text('Plan Pro'), findsOneWidget);
    expect(find.text('Prueba'), findsOneWidget);
    expect(find.text('Prueba Pro hasta el 31/10/2026'), findsOneWidget);
    expect(find.text('Te quedan 12 días. Sin tarjeta.'), findsOneWidget);
    expect(find.text('Activo'), findsOneWidget);
  });

  testWidgets('Gratis below 80 % shows counter and bar, no helper', (
    tester,
  ) async {
    await _abrir(tester, planGratis.copyWith(pacientesCount: 30));
    expect(find.text('Plan Gratis'), findsOneWidget);
    expect(find.text('30 de 50 pacientes'), findsOneWidget);
    expect(find.byKey(_barra), findsOneWidget);
    expect(find.textContaining('Te quedan'), findsNothing);
    expect(find.textContaining('Límite alcanzado'), findsNothing);
    expect(find.text('Plan sin vencimiento'), findsOneWidget);
    expect(find.text('Hasta 50 pacientes y 1 veterinario.'), findsOneWidget);
  });

  testWidgets('Gratis 42 of 50 (84 %) already warns with Te quedan 8', (
    tester,
  ) async {
    await _abrir(tester, planGratis);
    expect(find.text('42 de 50 pacientes'), findsOneWidget);
    expect(find.text('Te quedan 8'), findsOneWidget);
  });

  testWidgets('Gratis 45 of 50 shows Te quedan 5', (tester) async {
    await _abrir(tester, planGratis.copyWith(pacientesCount: 45));
    expect(find.text('Te quedan 5'), findsOneWidget);
  });

  testWidgets('Gratis at the limit explains it without alarm', (tester) async {
    await _abrir(tester, planGratisAlTope);
    expect(find.text('50 de 50 pacientes'), findsOneWidget);
    expect(
      find.text(
        'Límite alcanzado: puedes seguir atendiendo, pero no registrar más.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Beta has no patient limit and no seat cap', (tester) async {
    await _abrir(tester, planBeta);
    expect(find.text('Plan Beta'), findsOneWidget);
    expect(find.text('Acceso Beta completo'), findsOneWidget);
    expect(find.text('42 pacientes'), findsOneWidget);
    expect(find.text('Sin límite'), findsOneWidget);
    expect(find.text('2 veterinarios'), findsOneWidget);
    expect(find.text('Sin tope'), findsOneWidget);
    expect(find.byKey(_barra), findsNothing);
  });

  testWidgets('Clínica trial shows seat counter with bar and Cupo completo', (
    tester,
  ) async {
    await _abrir(tester, planClinicaTrial.copyWith(veterinariosActivos: 5));
    expect(find.text('5 de 5 veterinarios'), findsOneWidget);
    expect(find.text('Cupo completo'), findsOneWidget);
    expect(find.byKey(_barra), findsOneWidget);
  });

  testWidgets('logo row states', (tester) async {
    await _abrir(tester, planClinicaTrial);
    expect(find.text('Logo en carné, PDF y página'), findsOneWidget);
    expect(find.text('Incluido'), findsNWidgets(2));

    await _abrir(tester, planGratis);
    expect(find.text('No incluido en Gratis'), findsNWidgets(2));
    expect(
      find.text('Los protocolos estándar siguen disponibles.'),
      findsOneWidget,
    );

    await _abrir(tester, planGratis.copyWith(logoGuardado: true));
    expect(find.text('Guardado, oculto en Gratis'), findsOneWidget);
  });

  testWidgets('read-only notice shows at the top', (tester) async {
    await _abrir(tester, planSoloLectura, perfil: vetColegaProfile);
    expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
    expect(
      find.textContaining('Habla con el administrador de tu clínica'),
      findsOneWidget,
    );
    expect(
      find.text('Tu prueba terminó el 01/09/2026. Tus datos están intactos.'),
      findsNothing,
    );
  });

  testWidgets('Qué incluye cada plan is collapsed until tapped', (
    tester,
  ) async {
    await _abrir(tester, planProTrial);
    expect(find.text('Qué incluye cada plan'), findsOneWidget);
    expect(find.text('Clínica'), findsNothing);
    expect(find.text('Tu plan'), findsNothing);

    await tester.tap(find.text('Qué incluye cada plan'));
    await tester.pumpAndSettle();
    expect(find.text('Gratis'), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('Clínica'), findsOneWidget);
    expect(find.text('Tu plan'), findsOneWidget);
    expect(
      find.text(
        'El carné, la historia clínica, la agenda y las alertas de vacunas '
        'están incluidos en todos los planes.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('error shows the message and Reintentar reads again', (
    tester,
  ) async {
    final repo = FakePlanRepository(
      error: const PlanFailure('No pudimos cargar tu plan. Intenta de nuevo.'),
    );
    await _abrir(tester, planGratis, repo: repo);
    expect(
      find.text('No pudimos cargar tu plan. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(repo.llamadas, 1);

    repo.error = null;
    repo.plan = planGratis;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(repo.llamadas, 2);
    expect(find.text('Plan Gratis'), findsOneWidget);
  });

  testWidgets('no money wording in any state', (tester) async {
    final estados = [
      planBeta,
      planGratis,
      planGratisAlTope,
      planProTrial,
      planClinicaTrial,
      planProPagadoFundador,
      planGracia,
      planSoloLectura,
    ];
    for (final plan in estados) {
      await _abrir(tester, plan);
      await tester.tap(find.text('Qué incluye cada plan'));
      await tester.pumpAndSettle();
      for (final prohibida in [
        'precio',
        'pagar',
        'pago',
        'pagado',
        'COP',
        r'$',
        'factura',
      ]) {
        expect(
          find.textContaining(prohibida),
          findsNothing,
          reason: '${plan.plan}/${plan.origen}: $prohibida',
        );
      }
    }
  });
}
