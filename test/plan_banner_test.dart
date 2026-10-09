import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vetapp/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/plan/domain/mi_plan.dart';
import 'package:vetapp/features/plan/domain/plan_failure.dart';
import 'package:vetapp/features/plan/presentation/aviso_plan.dart';
import 'package:vetapp/features/plan/presentation/widgets/plan_banner.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_plan.dart';
import 'helpers/router_harness.dart';

/// Beta con fecha de fin: estado vigente y días del servidor.
MiPlan _betaConFecha(int dias, {bool colegas = true}) => planBeta.copyWith(
  estado: EstadoPlan.vigente,
  diasRestantes: dias,
  hayColegas: colegas,
);

MiPlan _clinica5(int activos) => planClinicaTrial.copyWith(
  origen: OrigenPlan.pagado,
  estado: EstadoPlan.sinVencimiento,
  miembrosMax: 5,
  veterinariosActivos: activos,
);

void main() {
  group('avisoPlanPara', () {
    test('solo lectura is not dismissible', () {
      final a = avisoPlanPara(planSoloLectura, esAdmin: true)!;
      expect(a.tipo, TipoAviso.soloLectura);
      expect(a.titulo, 'Tu cuenta está en solo lectura');
      expect(a.descartable, isFalse);
    });

    test('gracia admin and non-admin copy', () {
      final admin = avisoPlanPara(planGracia, esAdmin: true)!;
      expect(admin.tipo, TipoAviso.gracia);
      expect(admin.titulo, 'Tu plan venció');
      expect(
        admin.mensaje,
        'Tienes 9 días de gracia. Después, tus colegas quedarán en solo '
        'lectura.',
      );
      expect(admin.descartable, isFalse);

      final vet = avisoPlanPara(planGracia, esAdmin: false)!;
      expect(vet.titulo, 'El plan de tu clínica venció');
      expect(
        vet.mensaje,
        'Tienes 9 días de gracia. Avisa al administrador para renovarlo.',
      );

      final solo = avisoPlanPara(
        planGracia.copyWith(hayColegas: false),
        esAdmin: true,
      )!;
      expect(
        solo.mensaje,
        'Tienes 9 días de gracia. Después volverás al plan Gratis.',
      );
    });

    test('patients at the limit, admin and non-admin', () {
      final admin = avisoPlanPara(planGratisAlTope, esAdmin: true)!;
      expect(admin.tipo, TipoAviso.pacientesTope);
      expect(admin.titulo, 'Llegaste a los 50 pacientes');
      expect(admin.descartable, isFalse);
      expect(admin.mensaje, isNot(endsWith('Avisa al administrador.')));
      final vet = avisoPlanPara(planGratisAlTope, esAdmin: false)!;
      expect(vet.mensaje, endsWith(' Avisa al administrador.'));
    });

    test('patients 80 %', () {
      final a = avisoPlanPara(planGratis, esAdmin: true)!;
      expect(a.tipo, TipoAviso.pacientes80);
      expect(a.titulo, 'Vas en 42 de 50 pacientes');
      expect(a.mensaje, 'Con Pro registras pacientes ilimitados.');
      expect(a.descartable, isTrue);
      expect(
        avisoPlanPara(planGratis.copyWith(pacientesCount: 39), esAdmin: true),
        isNull,
      );
      expect(
        avisoPlanPara(planGratis.copyWith(pacientesCount: 40), esAdmin: true),
        isNotNull,
      );
    });

    test('Pro trial last days', () {
      final cinco = avisoPlanPara(
        planProTrial.copyWith(diasRestantes: 5),
        esAdmin: true,
      )!;
      expect(cinco.tipo, TipoAviso.ultimosDias);
      expect(cinco.titulo, 'Tu prueba Pro termina en 5 días');
      expect(
        cinco.mensaje,
        'Al terminar volverás al plan Gratis. No pierdes ningún dato.',
      );
      expect(cinco.descartable, isTrue);
      expect(
        avisoPlanPara(
          planProTrial.copyWith(diasRestantes: 1),
          esAdmin: true,
        )!.titulo,
        'Tu prueba Pro termina mañana',
      );
      expect(
        avisoPlanPara(
          planProTrial.copyWith(diasRestantes: 0),
          esAdmin: true,
        )!.titulo,
        'Tu prueba Pro termina hoy',
      );
      expect(
        avisoPlanPara(planProTrial.copyWith(diasRestantes: 8), esAdmin: true),
        isNull,
      );
      expect(
        avisoPlanPara(planProTrial.copyWith(diasRestantes: 7), esAdmin: true),
        isNotNull,
      );
    });

    test('Clínica trial last days', () {
      final conColegas = avisoPlanPara(
        planClinicaTrial.copyWith(diasRestantes: 3),
        esAdmin: true,
      )!;
      expect(conColegas.titulo, 'Tu prueba Clínica termina en 3 días');
      expect(
        conColegas.mensaje,
        'Después tendrás 15 días de gracia; luego tus colegas quedarán en '
        'solo lectura.',
      );
      final solo = avisoPlanPara(
        planClinicaTrial.copyWith(diasRestantes: 3, hayColegas: false),
        esAdmin: true,
      )!;
      expect(
        solo.mensaje,
        'Al terminar volverás a tu plan anterior. No pierdes ningún dato.',
      );
    });

    test('paid plan last days, admin and non-admin', () {
      final pagado = planProPagadoFundador.copyWith(
        fundador: false,
        estado: EstadoPlan.vigente,
        diasRestantes: 3,
      );
      final admin = avisoPlanPara(pagado, esAdmin: true)!;
      expect(admin.titulo, 'Tu plan termina en 3 días');
      expect(admin.mensaje, 'Escríbenos por WhatsApp para renovarlo.');
      final vet = avisoPlanPara(pagado, esAdmin: false)!;
      expect(
        vet.mensaje,
        'Avisa al administrador de tu clínica para renovarlo.',
      );
    });

    test('Fundador without date and Beta without date show nothing', () {
      expect(avisoPlanPara(planProPagadoFundador, esAdmin: true), isNull);
      expect(avisoPlanPara(planBeta, esAdmin: true), isNull);
    });

    test('Beta with date', () {
      final admin = avisoPlanPara(
        _betaConFecha(5, colegas: false),
        esAdmin: true,
      )!;
      expect(admin.tipo, TipoAviso.ultimosDias);
      expect(admin.titulo, 'Tu acceso Beta termina en 5 días');
      expect(
        admin.mensaje,
        'Después pasarás al plan Gratis. No pierdes ningún dato. Escríbenos '
        'por WhatsApp para activar tu plan.',
      );
      expect(admin.descartable, isTrue);

      expect(
        avisoPlanPara(_betaConFecha(5), esAdmin: true)!.mensaje,
        'Después pasarás al plan Gratis y tus colegas quedarán en solo '
        'lectura. No pierdes ningún dato.',
      );

      final vet = avisoPlanPara(_betaConFecha(5), esAdmin: false)!;
      expect(vet.titulo, 'El acceso Beta de tu clínica termina en 5 días');
      expect(
        vet.mensaje,
        'Avisa al administrador de tu clínica para activar un plan.',
      );

      expect(avisoPlanPara(_betaConFecha(8), esAdmin: true), isNull);
    });

    test('members 80 % only when the plan has 5 seats or more', () {
      final cuatro = avisoPlanPara(_clinica5(4), esAdmin: true)!;
      expect(cuatro.tipo, TipoAviso.miembros80);
      expect(cuatro.titulo, 'Vas en 4 de 5 veterinarios');
      expect(cuatro.mensaje, 'Escríbenos por WhatsApp si necesitan más cupos.');
      expect(cuatro.descartable, isTrue);
      expect(
        avisoPlanPara(_clinica5(5), esAdmin: false)!.mensaje,
        'Avisa al administrador si necesitan más cupos.',
      );
      expect(avisoPlanPara(_clinica5(3), esAdmin: true), isNull);

      final tres = _clinica5(3).copyWith(miembrosMax: 3);
      expect(avisoPlanPara(tres, esAdmin: true), isNull);
      final dos = _clinica5(2).copyWith(miembrosMax: 2);
      expect(avisoPlanPara(dos, esAdmin: true), isNull);
      final pro = planProPagadoFundador.copyWith(veterinariosActivos: 1);
      expect(avisoPlanPara(pro, esAdmin: true), isNull);
      expect(
        avisoPlanPara(planBeta.copyWith(veterinariosActivos: 9), esAdmin: true),
        isNull,
      );
    });

    test('priorities', () {
      // Gracia beats patients at 100 %.
      final graciaYTope = planGracia.copyWith(
        pacientesMax: 50,
        pacientesCount: 50,
      );
      expect(avisoPlanPara(graciaYTope, esAdmin: true)!.tipo, TipoAviso.gracia);

      // Read-only beats gracia.
      expect(
        avisoPlanPara(
          planGracia.copyWith(puedeEscribir: false),
          esAdmin: true,
        )!.tipo,
        TipoAviso.soloLectura,
      );

      // Patients 100 % beats the last days.
      expect(
        avisoPlanPara(
          planGratisAlTope.copyWith(
            origen: OrigenPlan.pruebaPro,
            estado: EstadoPlan.vigente,
            diasRestantes: 2,
          ),
          esAdmin: true,
        )!.tipo,
        TipoAviso.pacientesTope,
      );

      // Last days beat patients 80 % and members 80 %.
      final todo = _clinica5(5).copyWith(
        origen: OrigenPlan.pagado,
        estado: EstadoPlan.vigente,
        diasRestantes: 4,
        pacientesMax: 50,
        pacientesCount: 45,
      );
      expect(avisoPlanPara(todo, esAdmin: true)!.tipo, TipoAviso.ultimosDias);

      // Patients 80 % beats members 80 %.
      final pacYMiembros = _clinica5(
        5,
      ).copyWith(pacientesMax: 50, pacientesCount: 45);
      expect(
        avisoPlanPara(pacYMiembros, esAdmin: true)!.tipo,
        TipoAviso.pacientes80,
      );
    });
  });

  group('PlanBanner', () {
    String? ruta;

    Widget banner({
      MiPlan? plan,
      Object? error,
      AuthProfile perfil = vetAdminProfile,
    }) {
      ruta = null;
      return routerHarness(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: PlanBanner()),
          ),
          GoRoute(
            path: '/mas/plan',
            builder: (_, _) {
              ruta = '/mas/plan';
              return const Text('PANTALLA MI PLAN');
            },
          ),
        ],
        overrides: [
          ...planOverrides(plan: plan, error: error),
          authProfileProvider.overrideWith(
            () => FakeAuthProfileNotifier(profile: perfil),
          ),
        ],
      );
    }

    testWidgets('renders nothing without a notice', (tester) async {
      await tester.pumpWidget(banner(plan: planBeta));
      await tester.pumpAndSettle();
      expect(find.text('Ver mi plan'), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('renders nothing while loading', (tester) async {
      await tester.pumpWidget(banner(plan: planGratisAlTope));
      expect(find.text('Ver mi plan'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('Ver mi plan'), findsOneWidget);
    });

    testWidgets('renders nothing on error', (tester) async {
      await tester.pumpWidget(banner(error: const PlanFailure('x')));
      await tester.pumpAndSettle();
      expect(find.text('Ver mi plan'), findsNothing);
    });

    testWidgets('Ver mi plan opens Mi plan', (tester) async {
      await tester.pumpWidget(banner(plan: planGratisAlTope));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver mi plan'));
      await tester.pumpAndSettle();
      expect(ruta, '/mas/plan');
      expect(find.text('PANTALLA MI PLAN'), findsOneWidget);
    });

    testWidgets('tapping the body opens Mi plan', (tester) async {
      await tester.pumpWidget(banner(plan: planGratisAlTope));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Llegaste a los 50 pacientes'));
      await tester.pumpAndSettle();
      expect(find.text('PANTALLA MI PLAN'), findsOneWidget);
    });

    testWidgets('non-dismissible variants have no close icon', (tester) async {
      await tester.pumpWidget(banner(plan: planGratisAlTope));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byTooltip('Descartar aviso'), findsNothing);
    });

    testWidgets('dismissible variant hides for the session', (tester) async {
      await tester.pumpWidget(banner(plan: planGratis));
      await tester.pumpAndSettle();
      expect(find.text('Vas en 42 de 50 pacientes'), findsOneWidget);
      expect(find.byTooltip('Descartar aviso'), findsOneWidget);

      await tester.tap(find.byTooltip('Descartar aviso'));
      await tester.pumpAndSettle();
      expect(find.text('Vas en 42 de 50 pacientes'), findsNothing);
      expect(find.text('Ver mi plan'), findsNothing);
    });

    testWidgets('exposes one semantics node with title, message and action', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(banner(plan: planGratisAlTope));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(
          'Llegaste a los 50 pacientes. Sigues atendiendo con normalidad. '
          'Para registrar más pacientes, activa Pro.. Ver mi plan',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('no money wording in any variant', (tester) async {
      final planes = <MiPlan>[
        planSoloLectura,
        planGracia,
        planGratisAlTope,
        planGratis,
        planProTrial.copyWith(diasRestantes: 5),
        planClinicaTrial.copyWith(diasRestantes: 5),
        _betaConFecha(5),
        _clinica5(4),
        planProPagadoFundador.copyWith(
          fundador: false,
          estado: EstadoPlan.vigente,
          diasRestantes: 3,
        ),
      ];
      for (final plan in planes) {
        for (final perfil in [vetAdminProfile, vetColegaProfile]) {
          await tester.pumpWidget(banner(plan: plan, perfil: perfil));
          await tester.pumpAndSettle();
          expect(find.text('Ver mi plan'), findsOneWidget);
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
              find.textContaining(prohibida),
              findsNothing,
              reason: '${plan.plan}/${plan.origen}: $prohibida',
            );
          }
        }
      }
    });
  });
}
