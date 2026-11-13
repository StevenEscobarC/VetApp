import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetapp/features/inventory/presentation/providers/inventario_providers.dart';
import 'package:vetapp/features/appointments/presentation/providers/citas_providers.dart';
import 'package:vetapp/features/appointments/presentation/providers/recordatorios_providers.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/home/presentation/app_shell.dart';
import 'package:vetapp/features/home/presentation/screens/mas_screen.dart';
import 'package:vetapp/features/plan/presentation/plan_textos.dart';
import 'package:vetapp/features/plan/presentation/providers/plan_providers.dart';
import 'package:vetapp/features/plan/presentation/screens/mi_plan_screen.dart';
import 'package:vetapp/features/team/presentation/providers/team_providers.dart';

import 'helpers/fake_inventario.dart';
import 'helpers/fake_auth.dart';
import 'helpers/fake_citas.dart';
import 'helpers/fake_plan.dart';
import 'helpers/fake_recordatorios.dart';
import 'helpers/fake_team.dart';
import 'helpers/router_harness.dart';

/// Stand-in de Inicio: mantiene vivo [miPlanProvider] vía
/// [puedeEscribirProvider], igual que las pantallas reales montadas en el
/// shell, y muestra el plan que ve.
class _InicioStub extends ConsumerWidget {
  const _InicioStub({this.conBotonPlan = false});

  final bool conBotonPlan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final puedeEscribir = ref.watch(puedeEscribirProvider);
    final plan = ref.watch(miPlanProvider).value;
    return Scaffold(
      body: Column(
        children: [
          Text(plan == null ? 'sin-plan' : nombrePlan(plan.plan)),
          if (!puedeEscribir) const Text('solo-lectura'),
          if (conBotonPlan)
            TextButton(
              onPressed: () => context.push('/mas/plan'),
              child: const Text('abrir-plan'),
            ),
        ],
      ),
    );
  }
}

List<Override> _overrides(FakePlanRepository repo) => [
  authProfileProvider.overrideWith(
    () => FakeAuthProfileNotifier(profile: vetAdminProfile),
  ),
  planRepositoryProvider.overrideWithValue(repo),
  inventarioRepositoryProvider.overrideWithValue(FakeInventarioRepository()),
];

void _vista(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Harness con el [AppShell] real y las 5 ramas.
Widget _conShell(FakePlanRepository repo) {
  SharedPreferences.setMockInitialValues({});
  return routerHarness(
    initialLocation: '/inicio',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/inicio', builder: (_, _) => const _InicioStub()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/pacientes',
                builder: (_, _) => const Text('pacientes-stub'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/agenda',
                builder: (_, _) => const Text('agenda-stub'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/clientes',
                builder: (_, _) => const Text('clientes-stub'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/mas',
                builder: (_, _) => const MasScreen(),
                routes: [
                  GoRoute(
                    path: 'plan',
                    builder: (_, _) => const MiPlanScreen(),
                  ),
                ],
              ),
            ],
          ),
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

Finder _destino(String etiqueta) => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.text(etiqueta),
);

void main() {
  group('Mi plan', () {
    testWidgets('con el plan en caché lo relee al abrirse', (tester) async {
      _vista(tester);
      final repo = FakePlanRepository(plan: planGratis);
      await tester.pumpWidget(
        routerHarness(
          initialLocation: '/inicio',
          routes: [
            GoRoute(
              path: '/inicio',
              builder: (_, _) => const _InicioStub(conBotonPlan: true),
            ),
            GoRoute(path: '/mas/plan', builder: (_, _) => const MiPlanScreen()),
          ],
          overrides: _overrides(repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.llamadas, 1);

      repo.plan = planProPagadoFundador;
      await tester.tap(find.text('abrir-plan'));
      await tester.pumpAndSettle();

      expect(repo.llamadas, 2);
      expect(find.text(nombrePlan(planProPagadoFundador.plan)), findsWidgets);
    });

    testWidgets('en frío pide el plan una sola vez', (tester) async {
      _vista(tester);
      final repo = FakePlanRepository(plan: planGratis);
      await tester.pumpWidget(
        routerHarness(
          initialLocation: '/mas/plan',
          routes: [
            GoRoute(path: '/mas/plan', builder: (_, _) => const MiPlanScreen()),
          ],
          overrides: _overrides(repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(repo.llamadas, 1);
    });
  });

  group('AppShell', () {
    testWidgets('al pasar a Más relee el plan y la insignia se actualiza', (
      tester,
    ) async {
      _vista(tester);
      final repo = FakePlanRepository(plan: planGratis);
      await tester.pumpWidget(_conShell(repo));
      await tester.pumpAndSettle();
      expect(repo.llamadas, 1);
      final antes = repo.llamadas;

      repo.plan = planProPagadoFundador;
      await tester.tap(_destino('Más'));
      await tester.pumpAndSettle();

      expect(repo.llamadas, greaterThan(antes));
      expect(find.text(insigniaPlan(planProPagadoFundador).texto), findsOne);
    });

    testWidgets('al volver a Inicio por toque relee el plan', (tester) async {
      _vista(tester);
      final repo = FakePlanRepository(plan: planGratis);
      await tester.pumpWidget(_conShell(repo));
      await tester.pumpAndSettle();
      await tester.tap(_destino('Más'));
      await tester.pumpAndSettle();
      final antes = repo.llamadas;

      repo.plan = planSoloLectura;
      await tester.tap(_destino('Inicio'));
      await tester.pumpAndSettle();

      expect(repo.llamadas, greaterThan(antes));
      expect(find.text('solo-lectura'), findsOneWidget);
    });

    testWidgets('al volver a Inicio con context.go relee el plan', (
      tester,
    ) async {
      _vista(tester);
      final repo = FakePlanRepository(plan: planGratis);
      await tester.pumpWidget(_conShell(repo));
      await tester.pumpAndSettle();
      await tester.tap(_destino('Más'));
      await tester.pumpAndSettle();
      final antes = repo.llamadas;

      repo.plan = planSoloLectura;
      GoRouter.of(tester.element(find.byType(MasScreen))).go('/inicio');
      await tester.pumpAndSettle();

      expect(repo.llamadas, greaterThan(antes));
      expect(find.text('solo-lectura'), findsOneWidget);
    });

    testWidgets('sin navegación ni ciclo de vida no hay relecturas', (
      tester,
    ) async {
      _vista(tester);
      final repo = FakePlanRepository(plan: planGratis);
      await tester.pumpWidget(_conShell(repo));
      await tester.pumpAndSettle();
      expect(repo.llamadas, 1);

      await tester.pump(const Duration(minutes: 10));
      await tester.pumpAndSettle();

      expect(repo.llamadas, 1);
    });
  });

  group('Ciclo de vida', () {
    testWidgets('al volver la app a primer plano relee el plan', (
      tester,
    ) async {
      _vista(tester);
      final repo = FakePlanRepository(plan: planGratis);
      await tester.pumpWidget(
        routerHarness(
          initialLocation: '/inicio',
          routes: [
            GoRoute(path: '/inicio', builder: (_, _) => const _InicioStub()),
          ],
          overrides: _overrides(repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.llamadas, 1);
      expect(find.text('Plan Gratis'), findsOneWidget);

      repo.plan = planProPagadoFundador;
      // AppLifecycleListener valida las transiciones: se baja y se sube paso a paso.
      for (final estado in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(estado);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(repo.llamadas, greaterThan(1));
      expect(find.text('Plan Pro'), findsOneWidget);
    });
  });
}
