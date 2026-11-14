import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/billing/domain/entities/cobro.dart';
import 'package:vetapp/features/billing/presentation/providers/cobros_providers.dart';
import 'package:vetapp/features/billing/presentation/widgets/cobrar_boton.dart';
import 'package:vetapp/features/billing/presentation/widgets/estado_cobro_chip.dart';
import 'package:vetapp/features/plan/domain/mi_plan.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_cobros.dart';
import 'helpers/fake_plan.dart';
import 'helpers/router_harness.dart';

/// Lectura que nunca termina: deja el vínculo en carga.
class _CobrosLento extends FakeCobrosRepository {
  @override
  Future<CobroVinculado?> cobroVinculado({
    String? citaId,
    String? consultaId,
  }) => Completer<CobroVinculado?>().future;
}

Future<void> _abrir(
  WidgetTester tester,
  Widget hijo, {
  MiPlan? plan,
  FakeCobrosRepository? repo,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    routerHarness(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(body: Center(child: hijo)),
        ),
        GoRoute(
          path: '/destino',
          builder: (_, _) => const Scaffold(body: Text('DESTINO')),
        ),
        GoRoute(
          path: '/cobros/:id',
          builder: (_, s) =>
              Scaffold(body: Text('DETALLE ${s.pathParameters['id']}')),
        ),
      ],
      overrides: [
        ...planOverrides(plan: plan),
        authProfileProvider.overrideWith(
          () => FakeAuthProfileNotifier(profile: vetProfile),
        ),
        cobrosRepositoryProvider.overrideWithValue(
          repo ?? FakeCobrosRepository(),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

const _boton = CobrarBoton(ruta: '/destino');
const _siNoHay = Text('SIN COBRO');

void main() {
  group('CobrarBoton', () {
    testWidgets('outline "Cobrar" con recibo; empuja la ruta', (tester) async {
      await _abrir(tester, _boton);
      expect(find.text('Cobrar'), findsOneWidget);
      expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(
        tester.getSize(find.byType(OutlinedButton)).height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.text('Cobrar'));
      await tester.pumpAndSettle();
      expect(find.text('DESTINO'), findsOneWidget);
    });

    testWidgets('solo lectura: candado, semántica y hoja sin navegar', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _abrir(tester, _boton, plan: planSoloLectura);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byIcon(Icons.receipt_long_outlined), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('bloqueado, solo lectura')),
        findsOneWidget,
      );
      await tester.tap(find.text('Cobrar'));
      await tester.pumpAndSettle();
      expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
      expect(find.text('DESTINO'), findsNothing);
      semantics.dispose();
    });

    testWidgets('etiqueta e icono propios', (tester) async {
      await _abrir(
        tester,
        const CobrarBoton(ruta: '/destino', label: 'Nueva cuenta de cobro'),
      );
      expect(find.text('Nueva cuenta de cobro'), findsOneWidget);
    });
  });

  group('CobroVinculadoFila', () {
    testWidgets('con CC vinculada: "Cobrada: CC-0012" + chip; abre detalle', (
      tester,
    ) async {
      await _abrir(
        tester,
        const CobroVinculadoFila(citaId: 'cita1', siNoHay: _siNoHay),
        repo: FakeCobrosRepository(
          vinculado: const CobroVinculado(
            id: 'c1',
            numero: 12,
            estado: EstadoCobro.pagada,
          ),
        ),
      );
      expect(find.text('Cobrada: CC-0012'), findsOneWidget);
      expect(find.byType(EstadoCobroChip), findsOneWidget);
      expect(find.text('Pagada'), findsOneWidget);
      expect(find.text('SIN COBRO'), findsNothing);
      final fila = find.ancestor(
        of: find.text('Cobrada: CC-0012'),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(fila.first).height, greaterThanOrEqualTo(48));
      await tester.tap(find.text('Cobrada: CC-0012'));
      await tester.pumpAndSettle();
      expect(find.text('DETALLE c1'), findsOneWidget);
    });

    testWidgets('sin CC vinculada muestra el botón dado', (tester) async {
      await _abrir(
        tester,
        const CobroVinculadoFila(consultaId: 'con1', siNoHay: _siNoHay),
      );
      expect(find.text('SIN COBRO'), findsOneWidget);
      expect(find.textContaining('Cobrada'), findsNothing);
    });

    testWidgets('cargando muestra el botón (nunca bloquea)', (tester) async {
      await _abrir(
        tester,
        const CobroVinculadoFila(citaId: 'cita1', siNoHay: _siNoHay),
        repo: _CobrosLento(),
      );
      expect(find.text('SIN COBRO'), findsOneWidget);
    });

    testWidgets('con error muestra el botón en silencio', (tester) async {
      await _abrir(
        tester,
        const CobroVinculadoFila(citaId: 'cita1', siNoHay: _siNoHay),
        repo: FakeCobrosRepository(errorCobro: Exception('red')),
      );
      expect(find.text('SIN COBRO'), findsOneWidget);
      expect(find.textContaining('No pudimos'), findsNothing);
    });
  });
}
