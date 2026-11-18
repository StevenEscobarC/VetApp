import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/core/theme/app_colors.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/home/presentation/widgets/accesos_rapidos.dart';
import 'package:vetapp/features/patients/presentation/providers/mascota_foto_providers.dart';
import 'package:vetapp/features/patients/presentation/providers/mascotas_providers.dart';
import 'package:vetapp/features/plan/domain/mi_plan.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_fotos.dart';
import 'helpers/fake_mascotas.dart';
import 'helpers/fake_plan.dart';
import 'helpers/router_harness.dart';

Widget _app({MiPlan? plan, double escala = 1}) {
  return routerHarness(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(escala)),
          child: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: const [AccesosRapidos()],
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/clientes/nuevo',
        builder: (_, _) => const Text('PANTALLA NUEVO CLIENTE'),
      ),
      GoRoute(
        path: '/citas/nueva',
        builder: (_, state) => Text('PANTALLA NUEVA CITA ${state.uri.path}'),
      ),
      GoRoute(
        path: '/cobros/nuevo',
        builder: (_, state) => Text('PANTALLA NUEVO COBRO ${state.uri}'),
      ),
    ],
    overrides: [
      ...planOverrides(plan: plan),
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: vetProfile),
      ),
      mascotaRepositoryProvider.overrideWithValue(FakeMascotaRepository()),
      mascotaFotoDatasourceProvider.overrideWithValue(
        FakeMascotaFotoDatasource(),
      ),
    ],
  );
}

const _labels = ['Paciente', 'Cita', 'Cobro', 'Vacunar'];
const _semanticas = [
  'Nuevo paciente',
  'Nueva cita',
  'Nueva cuenta de cobro',
  'Vacunar',
];

Finder _acceso(String label) => find.widgetWithText(AccesoRapido, label);

Finder _circulo(String label) => find.descendant(
  of: _acceso(label),
  matching: find.byWidgetPredicate(
    (w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration! as BoxDecoration).shape == BoxShape.circle,
  ),
);

Color? _relleno(WidgetTester tester, String label) =>
    (tester.widget<Container>(_circulo(label)).decoration! as BoxDecoration)
        .color;

void main() {
  testWidgets('título y las 4 acciones en orden, nunca Factura', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Accesos rápidos'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Accesos rápidos')),
      isSemantics(isHeader: true),
    );
    expect(find.byType(AccesoRapido), findsNWidgets(4));
    for (var i = 1; i < _labels.length; i++) {
      expect(
        tester.getTopLeft(find.text(_labels[i])).dx,
        greaterThan(tester.getTopLeft(find.text(_labels[i - 1])).dx),
      );
    }
    expect(find.textContaining(RegExp('[Ff]actur')), findsNothing);
    semantics.dispose();
  });

  testWidgets('círculos de 56, rellenos, íconos y objetivo táctil >= 48', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    const rellenos = [
      AppColors.primary,
      AppColors.success,
      AppColors.textSecondary,
      AppColors.primaryStrong,
    ];
    const iconos = [
      Icons.person_add_alt_1_outlined,
      Icons.event_outlined,
      Icons.receipt_long_outlined,
      Icons.vaccines_outlined,
    ];
    for (var i = 0; i < _labels.length; i++) {
      final label = _labels[i];
      expect(tester.getSize(_circulo(label)), const Size(56, 56));
      expect(_relleno(tester, label), rellenos[i]);
      final icono = find.descendant(
        of: _acceso(label),
        matching: find.byIcon(iconos[i]),
      );
      expect(icono, findsOneWidget);
      expect(tester.widget<Icon>(icono).color, AppColors.onPrimary);
      final tam = tester.getSize(_acceso(label));
      expect(tam.width, greaterThanOrEqualTo(48));
      expect(tam.height, greaterThanOrEqualTo(48));
    }
    // Solo Paciente usa el acento.
    expect(
      _labels.where((l) => _relleno(tester, l) == AppColors.primary),
      ['Paciente'],
    );
  });

  testWidgets('semántica de botones con escritura', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    for (final s in _semanticas) {
      expect(
        find.bySemanticsLabel(s),
        findsOneWidget,
        reason: 'falta la semántica "$s"',
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(s)),
        isSemantics(isButton: true, label: s),
      );
    }
    semantics.dispose();
  });

  group('toques con escritura', () {
    testWidgets('Paciente abre /clientes/nuevo', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paciente'));
      await tester.pumpAndSettle();
      expect(find.text('PANTALLA NUEVO CLIENTE'), findsOneWidget);
    });

    testWidgets('Cita abre /citas/nueva', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cita'));
      await tester.pumpAndSettle();
      expect(find.text('PANTALLA NUEVA CITA /citas/nueva'), findsOneWidget);
    });

    testWidgets('Cobro abre una cuenta de cobro nueva', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cobro'));
      await tester.pumpAndSettle();
      expect(
        find.text('PANTALLA NUEVO COBRO /cobros/nuevo?tipo=cc'),
        findsOneWidget,
      );
    });

    testWidgets('Vacunar abre la hoja ¿A quién vacuna?', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vacunar'));
      await tester.pumpAndSettle();
      expect(find.text('¿A quién vacuna?'), findsOneWidget);
    });

    testWidgets('Paciente con el tope de pacientes abre la hoja del tope', (
      tester,
    ) async {
      await tester.pumpWidget(_app(plan: planGratisAlTope));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paciente'));
      await tester.pumpAndSettle();
      expect(find.text('Llegaste a los 50 pacientes'), findsOneWidget);
      expect(find.text('PANTALLA NUEVO CLIENTE'), findsNothing);
    });
  });

  group('solo lectura (D-11)', () {
    testWidgets('4 candados, rellenos iguales y semántica bloqueada', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(plan: planSoloLectura));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_outline), findsNWidgets(4));
      expect(_relleno(tester, 'Paciente'), AppColors.primary);
      expect(_relleno(tester, 'Cita'), AppColors.success);
      expect(_relleno(tester, 'Cobro'), AppColors.textSecondary);
      expect(_relleno(tester, 'Vacunar'), AppColors.primaryStrong);
      for (final s in _semanticas) {
        expect(
          find.bySemanticsLabel('$s, bloqueado, solo lectura'),
          findsOneWidget,
        );
      }
      semantics.dispose();
    });

    for (final label in _labels) {
      testWidgets('$label abre la hoja de solo lectura y no navega', (
        tester,
      ) async {
        await tester.pumpWidget(_app(plan: planSoloLectura));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
        expect(find.textContaining('PANTALLA'), findsNothing);
        expect(find.text('¿A quién vacuna?'), findsNothing);
      });
    }
  });

  testWidgets('con texto a 1,5 pasa a 2 filas de 2 sin recortar', (
    tester,
  ) async {
    await tester.pumpWidget(_app(escala: 1.5));
    await tester.pumpAndSettle();

    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    double x(String t) => tester.getTopLeft(find.text(t)).dx;
    expect(y('Cita'), y('Paciente'));
    expect(y('Cobro'), greaterThan(y('Paciente')));
    expect(y('Vacunar'), y('Cobro'));
    expect(x('Cita'), greaterThan(x('Paciente')));
    expect(x('Vacunar'), greaterThan(x('Cobro')));
    expect(tester.takeException(), isNull);
    for (final l in _labels) {
      final t = tester.widget<Text>(find.text(l));
      expect(t.overflow, isNot(TextOverflow.ellipsis));
    }
  });
}
