import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetapp/core/utils/lanzador_externo.dart';
import 'package:vetapp/features/appointments/presentation/providers/citas_providers.dart';
import 'package:vetapp/features/appointments/presentation/providers/recordatorios_providers.dart';
import 'package:vetapp/features/home/presentation/screens/mas_screen.dart';
import 'package:vetapp/features/team/presentation/providers/team_providers.dart';
import 'package:vetapp/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/plan/domain/mi_plan.dart';
import 'package:vetapp/features/plan/domain/plan_failure.dart';
import 'package:vetapp/features/plan/presentation/providers/plan_providers.dart';
import 'package:vetapp/features/plan/presentation/screens/mi_plan_screen.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_citas.dart';
import 'helpers/fake_recordatorios.dart';
import 'helpers/fake_team.dart';
import 'helpers/fake_url_launcher.dart';
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

  group('Soporte por WhatsApp', () {
    const numero = '573001234567';

    Future<void> abrirSoporte(
      WidgetTester tester,
      MiPlan plan, {
      AuthProfile perfil = vetAdminProfile,
      String? soporte = numero,
      FakeLanzadorExterno? lanzador,
    }) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        routerHarness(
          initialLocation: '/mas/plan',
          routes: [
            GoRoute(path: '/mas/plan', builder: (_, _) => const MiPlanScreen()),
          ],
          overrides: [
            ..._overrides(FakePlanRepository(plan: plan), perfil: perfil),
            soporteWhatsappProvider.overrideWithValue(soporte),
            if (lanzador != null)
              lanzadorExternoProvider.overrideWithValue(lanzador),
          ],
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('admin with number sees the full block', (tester) async {
      await abrirSoporte(tester, planClinicaTrial);
      expect(find.text('Activa o cambia tu plan'), findsOneWidget);
      expect(
        find.text('Para activar o cambiar tu plan escríbenos por WhatsApp.'),
        findsOneWidget,
      );
      expect(find.text('Plan de interés'), findsOneWidget);
      expect(find.text('Pro'), findsOneWidget);
      expect(find.text('Clínica'), findsOneWidget);
      expect(
        find.text('WhatsApp de soporte: +57 300 123 4567'),
        findsOneWidget,
      );
      expect(find.text('Escribir por WhatsApp'), findsOneWidget);
    });

    testWidgets('chip is preselected to Clínica on a Clínica plan', (
      tester,
    ) async {
      final lanzador = FakeLanzadorExterno();
      await abrirSoporte(tester, planClinicaTrial, lanzador: lanzador);
      await tester.tap(find.text('Escribir por WhatsApp'));
      await tester.pumpAndSettle();
      expect(
        lanzador.abiertos.single.toString(),
        contains('Plan%20Cl%C3%ADnica'),
      );
    });

    testWidgets('chip is preselected to Pro on any other plan', (tester) async {
      final lanzador = FakeLanzadorExterno();
      await abrirSoporte(tester, planGratis, lanzador: lanzador);
      await tester.tap(find.text('Escribir por WhatsApp'));
      await tester.pumpAndSettle();
      expect(lanzador.abiertos.single.toString(), contains('Plan%20Pro'));
    });

    testWidgets('tap opens wa.me with the encoded clinic and chosen plan', (
      tester,
    ) async {
      final lanzador = FakeLanzadorExterno();
      await abrirSoporte(tester, planGratis, lanzador: lanzador);
      await tester.tap(find.text('Clínica'));
      await tester.pump();
      await tester.tap(find.text('Escribir por WhatsApp'));
      await tester.pumpAndSettle();
      final uri = lanzador.abiertos.single;
      expect(lanzador.metodos, ['abrirEnApp']);
      expect(uri.host, 'wa.me');
      expect(uri.path, '/$numero');
      expect(uri.toString(), contains('%22Cl%C3%ADnica%20Patitas%22'));
      expect(uri.toString(), contains('Plan%20Cl%C3%ADnica'));
      expect(uri.toString(), isNot(contains('+')));
    });

    testWidgets('falls back to abrir when the app cannot open it', (
      tester,
    ) async {
      final lanzador = FakeLanzadorExterno()
        ..resultadoApp = false
        ..resultado = true;
      await abrirSoporte(tester, planGratis, lanzador: lanzador);
      await tester.tap(find.text('Escribir por WhatsApp'));
      await tester.pumpAndSettle();
      expect(lanzador.metodos, ['abrirEnApp', 'abrir']);
      expect(find.text('No pudimos abrir WhatsApp.'), findsNothing);
    });

    testWidgets('both failing shows the snackbar', (tester) async {
      final lanzador = FakeLanzadorExterno()..resultado = false;
      await abrirSoporte(tester, planGratis, lanzador: lanzador);
      await tester.tap(find.text('Escribir por WhatsApp'));
      await tester.pumpAndSettle();
      expect(lanzador.metodos, ['abrirEnApp', 'abrir']);
      expect(find.text('No pudimos abrir WhatsApp.'), findsOneWidget);
    });

    testWidgets('admin without number sees only the fallback text', (
      tester,
    ) async {
      await abrirSoporte(tester, planGratis, soporte: null);
      expect(
        find.text('Para activar o cambiar tu plan, comunícate con soporte.'),
        findsOneWidget,
      );
      expect(find.text('Escribir por WhatsApp'), findsNothing);
      expect(find.textContaining('WhatsApp de soporte'), findsNothing);
      expect(find.text('Plan de interés'), findsNothing);
    });

    testWidgets('non-admin sees no number and no button', (tester) async {
      await abrirSoporte(tester, planGratis, perfil: vetColegaProfile);
      expect(
        find.text(
          'Solo el administrador de tu clínica puede pedir cambios de plan. '
          'Habla con él para activar o cambiar el plan.',
        ),
        findsOneWidget,
      );
      expect(find.text('Escribir por WhatsApp'), findsNothing);
      expect(find.textContaining('WhatsApp de soporte'), findsNothing);
      expect(find.text('Activa o cambia tu plan'), findsNothing);
    });

    testWidgets('no money wording in any support variant', (tester) async {
      final variantes = <(MiPlan, AuthProfile, String?)>[
        (planGratis, vetAdminProfile, numero),
        (planClinicaTrial, vetAdminProfile, numero),
        (planGratis, vetAdminProfile, null),
        (planGratis, vetColegaProfile, numero),
      ];
      for (final (plan, perfil, soporte) in variantes) {
        await abrirSoporte(tester, plan, perfil: perfil, soporte: soporte);
        for (final prohibida in [
          'precio',
          'pagar',
          'pago',
          'COP',
          r'$',
          'factura',
          'tarjeta',
        ]) {
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('soporte-bloque')),
              matching: find.textContaining(prohibida),
            ),
            findsNothing,
            reason: '${plan.plan}/$soporte/${perfil.rolClinica}: $prohibida',
          );
        }
      }
    });
  });

  group('Más row', () {
    Widget mas(FakePlanRepository repo) {
      SharedPreferences.setMockInitialValues({});
      return routerHarness(
        initialLocation: '/mas',
        routes: [
          GoRoute(
            path: '/mas',
            builder: (_, _) => const MasScreen(),
            routes: [
              GoRoute(path: 'plan', builder: (_, _) => const MiPlanScreen()),
            ],
          ),
        ],
        overrides: [
          ..._overrides(repo),
          teamRepositoryProvider.overrideWithValue(FakeTeamRepository()),
          citaRepositoryProvider.overrideWithValue(FakeCitaRepository()),
          recordatoriosServiceProvider.overrideWithValue(
            FakeRecordatoriosService(),
          ),
        ],
      );
    }

    testWidgets('shows the insignia and opens Mi plan on tap', (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(mas(FakePlanRepository(plan: planClinicaTrial)));
      await tester.pumpAndSettle();
      expect(find.text('Mi plan'), findsOneWidget);
      expect(find.text('Prueba Clínica · 12 días'), findsOneWidget);

      await tester.tap(find.text('Mi plan'));
      await tester.pumpAndSettle();
      expect(find.text('Uso de tu clínica'), findsOneWidget);
    });

    testWidgets('read-only colleague sees Solo lectura', (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(mas(FakePlanRepository(plan: planSoloLectura)));
      await tester.pumpAndSettle();
      expect(find.text('Solo lectura'), findsOneWidget);
    });

    testWidgets('on error the row stays without insignia', (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        mas(FakePlanRepository(error: const PlanFailure('x'))),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mi plan'), findsOneWidget);
      expect(find.textContaining('Prueba'), findsNothing);
      expect(find.textContaining('Plan '), findsNothing);
    });
  });
}
