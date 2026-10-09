import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vetapp/core/errors/limite_plan.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/plan/domain/mi_plan.dart';
import 'package:vetapp/features/plan/presentation/limite_plan_gate.dart';
import 'package:vetapp/features/plan/presentation/providers/plan_providers.dart';
import 'package:vetapp/features/plan/presentation/widgets/limite_plan_sheet.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_plan.dart';
import 'helpers/router_harness.dart';

class _Fallo implements Exception, ConLimitePlan {
  const _Fallo(this.limite);

  @override
  final LimitePlan? limite;
}

final _prohibidas = RegExp(
  r'precio|pagar|\bpago\b|factura|\$',
  caseSensitive: false,
);

Widget _app({
  required Future<Object?> Function(BuildContext, WidgetRef) accion,
  List<Override> overrides = const [],
  bool admin = true,
}) {
  return routerHarness(
    initialLocation: '/',
    overrides: [
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(
          profile: admin ? vetAdminProfile : vetColegaProfile,
        ),
      ),
      ...overrides,
    ],
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: Consumer(
            builder: (context, ref, _) => Center(
              child: TextButton(
                onPressed: () => accion(context, ref),
                child: const Text('ir'),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/mas/plan',
        builder: (_, _) => const Scaffold(body: Text('PANTALLA MI PLAN')),
      ),
    ],
  );
}

Future<void> _abrir(
  WidgetTester tester, {
  required Future<Object?> Function(BuildContext, WidgetRef) accion,
  List<Override> overrides = const [],
  bool admin = true,
}) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _app(accion: accion, overrides: overrides, admin: admin),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('ir'));
  await tester.pumpAndSettle();
}

Future<void> _mostrar(
  WidgetTester tester, {
  required LimitePlan limite,
  FuncionPro? funcion,
  MiPlan? plan,
  bool esAdmin = true,
}) {
  return _abrir(
    tester,
    accion: (context, ref) async {
      await mostrarLimitePlanSheet(
        context,
        limite: limite,
        funcion: funcion,
        plan: plan,
        esAdmin: esAdmin,
      );
      return null;
    },
  );
}

String _todoElTexto(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .join(' | ');

void main() {
  group('LimitePlanSheet contenido', () {
    testWidgets('pacientes al tope muestra título, cuerpo y contador', (
      tester,
    ) async {
      await _mostrar(
        tester,
        limite: LimitePlan.pacientes,
        plan: planGratisAlTope,
      );
      expect(find.text('Llegaste a los 50 pacientes'), findsOneWidget);
      expect(
        find.textContaining(
          'El plan Gratis incluye hasta 50 pacientes. Con Pro registras pacientes ilimitados.',
        ),
        findsOneWidget,
      );
      expect(find.text('50 de 50 pacientes'), findsOneWidget);
      expect(find.byIcon(Icons.pets_outlined), findsOneWidget);
      expect(find.text('Ver mi plan'), findsOneWidget);
      expect(find.text('Ahora no'), findsOneWidget);
    });

    testWidgets('funcion logo', (tester) async {
      await _mostrar(
        tester,
        limite: LimitePlan.funcion,
        funcion: FuncionPro.logo,
        plan: planGratis,
      );
      expect(find.text('El logo es parte de Pro'), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.textContaining('Con Pro tu logo aparece'), findsOneWidget);
    });

    testWidgets('funcion logo con logo guardado', (tester) async {
      await _mostrar(
        tester,
        limite: LimitePlan.funcion,
        funcion: FuncionPro.logo,
        plan: planGratis.copyWith(logoGuardado: true),
      );
      expect(
        find.textContaining(
          'Tu logo está guardado y volverá a mostrarse cuando actives Pro o Clínica.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('funcion protocolos', (tester) async {
      await _mostrar(
        tester,
        limite: LimitePlan.funcion,
        funcion: FuncionPro.protocolos,
        plan: planGratis,
      );
      expect(
        find.text('Los protocolos propios son parte de Pro'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.tune), findsOneWidget);
    });

    testWidgets('miembros con plan Gratis o Pro', (tester) async {
      await _mostrar(tester, limite: LimitePlan.miembros, plan: planGratis);
      expect(
        find.text('Tu plan no tiene cupo para más veterinarios'),
        findsOneWidget,
      );
      expect(find.textContaining('2, 3 o 5 veterinarios'), findsOneWidget);
      expect(find.byIcon(Icons.group_outlined), findsOneWidget);
    });

    testWidgets('miembros con Clínica lleno', (tester) async {
      await _mostrar(
        tester,
        limite: LimitePlan.miembros,
        plan: planGracia, // clínica, 3 de 3
      );
      expect(
        find.textContaining(
          'Tu plan Clínica ya tiene sus 3 veterinarios activos.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('solo lectura', (tester) async {
      await _mostrar(
        tester,
        limite: LimitePlan.soloLectura,
        plan: planSoloLectura,
      );
      expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('no administrador agrega la frase del administrador', (
      tester,
    ) async {
      await _mostrar(
        tester,
        limite: LimitePlan.pacientes,
        plan: planGratisAlTope,
        esAdmin: false,
      );
      expect(
        find.textContaining(
          'Pídele al administrador de tu clínica que active el plan.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('administrador no ve la frase del administrador', (
      tester,
    ) async {
      await _mostrar(
        tester,
        limite: LimitePlan.pacientes,
        plan: planGratisAlTope,
      );
      expect(find.textContaining('Pídele al administrador'), findsNothing);
    });

    testWidgets('ninguna variante usa palabras de dinero', (tester) async {
      final variantes = <(LimitePlan, FuncionPro?, MiPlan)>[
        (LimitePlan.pacientes, null, planGratisAlTope),
        (LimitePlan.funcion, FuncionPro.logo, planGratis),
        (LimitePlan.funcion, FuncionPro.protocolos, planGratis),
        (LimitePlan.miembros, null, planGratis),
        (LimitePlan.miembros, null, planGracia),
        (LimitePlan.soloLectura, null, planSoloLectura),
      ];
      for (final (limite, funcion, plan) in variantes) {
        await _mostrar(
          tester,
          limite: limite,
          funcion: funcion,
          plan: plan,
          esAdmin: false,
        );
        final texto = _todoElTexto(tester);
        expect(texto, isNot(matches(_prohibidas)), reason: '$limite $funcion');
        expect(texto, isNot(contains('COP')));
        await tester.tap(find.text('Ahora no'));
        await tester.pumpAndSettle();
      }
    });
  });

  group('LimitePlanSheet acciones', () {
    testWidgets('Ver mi plan cierra la hoja y navega a /mas/plan', (
      tester,
    ) async {
      await _mostrar(
        tester,
        limite: LimitePlan.pacientes,
        plan: planGratisAlTope,
      );
      await tester.tap(find.text('Ver mi plan'));
      await tester.pumpAndSettle();
      expect(find.text('PANTALLA MI PLAN'), findsOneWidget);
      expect(find.text('Llegaste a los 50 pacientes'), findsNothing);
    });

    testWidgets('Ahora no cierra sin navegar', (tester) async {
      await _mostrar(
        tester,
        limite: LimitePlan.pacientes,
        plan: planGratisAlTope,
      );
      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();
      expect(find.text('Llegaste a los 50 pacientes'), findsNothing);
      expect(find.text('PANTALLA MI PLAN'), findsNothing);
      expect(find.text('ir'), findsOneWidget);
    });

    testWidgets('mantiene los botones visibles con texto al 200 %', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _mostrar(
        tester,
        limite: LimitePlan.pacientes,
        plan: planGratisAlTope,
        esAdmin: false,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Ver mi plan'), findsOneWidget);
      expect(find.text('Ahora no'), findsOneWidget);
    });
  });

  group('gates', () {
    testWidgets('asegurarNuevoPaciente al tope: false y hoja de pacientes', (
      tester,
    ) async {
      bool? r;
      await _abrir(
        tester,
        overrides: planOverrides(plan: planGratisAlTope),
        accion: (c, ref) async => r = await asegurarNuevoPaciente(c, ref),
      );
      expect(r, isFalse);
      expect(find.text('Llegaste a los 50 pacientes'), findsOneWidget);
      expect(find.text('50 de 50 pacientes'), findsOneWidget);
    });

    testWidgets('asegurarNuevoPaciente en solo lectura', (tester) async {
      bool? r;
      await _abrir(
        tester,
        overrides: planOverrides(plan: planSoloLectura),
        accion: (c, ref) async => r = await asegurarNuevoPaciente(c, ref),
      );
      expect(r, isFalse);
      expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
    });

    testWidgets('asegurarNuevoPaciente con plan Beta permite', (tester) async {
      bool? r;
      await _abrir(
        tester,
        overrides: planOverrides(),
        accion: (c, ref) async => r = await asegurarNuevoPaciente(c, ref),
      );
      expect(r, isTrue);
      expect(find.text('Llegaste a los 50 pacientes'), findsNothing);
    });

    testWidgets('usa el plan ya observado sin consultar el repositorio', (
      tester,
    ) async {
      bool? r;
      final repo = FakePlanRepository();
      await _abrir(
        tester,
        overrides: [planRepositoryProvider.overrideWithValue(repo)],
        accion: (c, ref) async =>
            r = await asegurarNuevoPaciente(c, ref, plan: planGratisAlTope),
      );
      expect(r, isFalse);
      expect(repo.llamadas, 0);
    });

    testWidgets('si el repositorio falla, permite y no muestra hoja', (
      tester,
    ) async {
      bool? r;
      await _abrir(
        tester,
        overrides: planOverrides(error: Exception('red')),
        accion: (c, ref) async => r = await asegurarNuevoPaciente(c, ref),
      );
      expect(r, isTrue);
      expect(find.text('Llegaste a los 50 pacientes'), findsNothing);
      expect(find.text('Tu cuenta está en solo lectura'), findsNothing);
    });

    testWidgets('asegurarEscritura en solo lectura', (tester) async {
      bool? r;
      await _abrir(
        tester,
        overrides: planOverrides(plan: planSoloLectura),
        accion: (c, ref) async => r = await asegurarEscritura(c, ref),
      );
      expect(r, isFalse);
      expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
    });

    testWidgets('asegurarFuncionPro bloquea logo en Gratis', (tester) async {
      bool? r;
      await _abrir(
        tester,
        overrides: planOverrides(plan: planGratis),
        accion: (c, ref) async =>
            r = await asegurarFuncionPro(c, ref, FuncionPro.logo),
      );
      expect(r, isFalse);
      expect(find.text('El logo es parte de Pro'), findsOneWidget);
    });

    testWidgets('asegurarFuncionPro bloquea protocolos en Gratis', (
      tester,
    ) async {
      bool? r;
      await _abrir(
        tester,
        overrides: planOverrides(plan: planGratis),
        accion: (c, ref) async =>
            r = await asegurarFuncionPro(c, ref, FuncionPro.protocolos),
      );
      expect(r, isFalse);
      expect(
        find.text('Los protocolos propios son parte de Pro'),
        findsOneWidget,
      );
    });

    testWidgets('asegurarFuncionPro permite en Pro', (tester) async {
      bool? r;
      await _abrir(
        tester,
        overrides: planOverrides(plan: planProTrial),
        accion: (c, ref) async =>
            r = await asegurarFuncionPro(c, ref, FuncionPro.logo),
      );
      expect(r, isTrue);
    });

    testWidgets('manejarLimitePlan con límite abre la hoja y devuelve true', (
      tester,
    ) async {
      bool? r;
      await _abrir(
        tester,
        overrides: planOverrides(plan: planGratisAlTope),
        accion: (c, ref) async => r = await manejarLimitePlan(
          c,
          ref,
          const _Fallo(LimitePlan.pacientes),
        ),
      );
      expect(r, isTrue);
      expect(find.text('Llegaste a los 50 pacientes'), findsOneWidget);
    });

    testWidgets('manejarLimitePlan sin límite devuelve false', (tester) async {
      bool? r;
      await _abrir(
        tester,
        overrides: planOverrides(),
        accion: (c, ref) async =>
            r = await manejarLimitePlan(c, ref, const _Fallo(null)),
      );
      expect(r, isFalse);
      expect(find.text('Llegaste a los 50 pacientes'), findsNothing);
    });

    testWidgets(
      'manejarLimitePlan abre la hoja aunque falle la lectura del plan',
      (tester) async {
        bool? r;
        await _abrir(
          tester,
          overrides: planOverrides(error: Exception('red')),
          accion: (c, ref) async => r = await manejarLimitePlan(
            c,
            ref,
            const _Fallo(LimitePlan.soloLectura),
          ),
        );
        expect(r, isTrue);
        expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
      },
    );
  });

  group('lock helpers', () {
    test('iconoEscritura', () {
      expect(iconoEscritura(true, Icons.add), Icons.add);
      expect(iconoEscritura(false, Icons.add), Icons.lock_outline);
    });

    test('semanticaEscritura', () {
      expect(semanticaEscritura(true, 'Nuevo cliente'), 'Nuevo cliente');
      expect(
        semanticaEscritura(false, 'Nuevo cliente'),
        'Nuevo cliente, bloqueado, solo lectura',
      );
    });
  });
}
