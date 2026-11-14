import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/core/errors/limite_plan.dart';
import 'package:vetapp/core/widgets/buttons/app_button.dart';
import 'package:vetapp/core/widgets/chips/app_filter_chip.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/billing/domain/cobro_failure.dart';
import 'package:vetapp/features/billing/domain/entities/cobro.dart';
import 'package:vetapp/features/billing/presentation/providers/cobros_providers.dart';
import 'package:vetapp/features/billing/presentation/widgets/marcar_pagada_sheet.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_cobros.dart';
import 'helpers/fake_plan.dart';
import 'helpers/router_harness.dart';

// "Hoy" en Bogotá: 13/11/2026.
final _hoy = DateTime.utc(2026, 11, 13, 17);

Cobro _cc() => cobroDePrueba(
  numero: 12,
  fecha: DateTime.utc(2026, 11, 1),
  items: null,
).copyWith(totalCop: 120000);

Future<FakeCobrosRepository> _abrir(
  WidgetTester tester, {
  FakeCobrosRepository? repo,
}) async {
  final c = _cc();
  final r = repo ?? FakeCobrosRepository(cobros: [c]);
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    routerHarness(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showMarcarPagadaSheet(context, c),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ],
      overrides: <Override>[
        ...planOverrides(),
        cobrosRepositoryProvider.overrideWithValue(r),
        authProfileProvider.overrideWith(
          () => FakeAuthProfileNotifier(profile: vetProfile),
        ),
        clockProvider.overrideWithValue(() => _hoy),
      ],
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return r;
}

Finder get _confirmar => find.widgetWithText(AppButton, 'Confirmar pago');

List<Map<String, Object?>> _pagos(FakeCobrosRepository r) => [
  for (final l in r.llamadas)
    if (l.metodo == 'marcarPagado') l.args,
];

void main() {
  testWidgets('encabezado, 6 chips sin selección y CTA deshabilitado', (
    tester,
  ) async {
    await _abrir(tester);
    expect(find.text('Marcar como pagada'), findsOneWidget);
    expect(find.text('CC-0012 · \$ 120.000'), findsOneWidget);
    expect(find.text('Método de pago'), findsOneWidget);

    final chips = tester
        .widgetList<AppFilterChip>(find.byType(AppFilterChip))
        .toList();
    expect(chips.map((c) => c.label), [
      'Efectivo',
      'Nequi',
      'Daviplata',
      'Transferencia',
      'Tarjeta',
      'Otro',
    ]);
    expect(chips.where((c) => c.selected), isEmpty);

    expect(tester.widget<AppButton>(_confirmar).onPressed, isNull);
    expect(find.text('Elige cómo pagó.'), findsOneWidget);
    expect(
      find.ancestor(of: _confirmar, matching: find.byType(Opacity)),
      findsNothing,
    );
    expect(find.text('Hoy, 13/11/2026'), findsOneWidget);
    expect(find.text('Cambiar'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
  });

  testWidgets('Cambiar abre el calendario entre la emisión y hoy', (
    tester,
  ) async {
    await _abrir(tester);
    await tester.tap(find.text('Cambiar'));
    await tester.pumpAndSettle();
    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(
      DateUtils.dateOnly(picker.firstDate),
      DateUtils.dateOnly(DateTime(2026, 11, 1)),
    );
    expect(
      DateUtils.dateOnly(picker.lastDate),
      DateUtils.dateOnly(DateTime(2026, 11, 13)),
    );
    await tester.tap(find.text('5'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('05/11/2026'), findsOneWidget);
    expect(find.textContaining('Hoy,'), findsNothing);
  });

  testWidgets('Nequi + Confirmar: guarda, cierra y avisa sin Deshacer', (
    tester,
  ) async {
    final repo = await _abrir(tester);
    await tester.tap(find.text('Nequi'));
    await tester.pump();
    expect(find.text('Elige cómo pagó.'), findsNothing);
    await tester.tap(_confirmar);
    await tester.pumpAndSettle();
    expect(_pagos(repo), [
      {'id': 'c1', 'metodo': MetodoPago.nequi, 'fecha': null},
    ]);
    expect(find.text('Confirmar pago'), findsNothing);
    expect(find.text('CC-0012 marcada como pagada.'), findsOneWidget);
    expect(find.text('Deshacer'), findsNothing);
  });

  testWidgets('fecha pasada se envía como fecha de pago', (tester) async {
    final repo = await _abrir(tester);
    await tester.tap(find.text('Efectivo'));
    await tester.tap(find.text('Cambiar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(_confirmar);
    await tester.pumpAndSettle();
    expect(_pagos(repo).single['fecha'], DateTime.utc(2026, 11, 5));
  });

  Future<void> fallo(
    WidgetTester tester,
    CobroFailure error,
    String texto,
  ) async {
    await _abrir(
      tester,
      repo: FakeCobrosRepository(cobros: [_cc()], errorPagar: error),
    );
    await tester.tap(find.text('Nequi'));
    await tester.pump();
    await tester.tap(_confirmar);
    await tester.pumpAndSettle();
    expect(find.text(texto), findsOneWidget);
    // La hoja sigue abierta.
    expect(find.text('Confirmar pago'), findsOneWidget);
  }

  testWidgets('sin conexión: mensaje en línea', (tester) async {
    await fallo(
      tester,
      const CobroFailure('x', tipo: ErrorCobro.sinConexion),
      'Sin conexión, el pago no se guardó. Inténtalo de nuevo cuando '
      'tengas señal.',
    );
  });

  testWidgets('estado inválido: mensaje y CTA deshabilitado', (tester) async {
    await fallo(
      tester,
      const CobroFailure('x', tipo: ErrorCobro.estadoInvalido),
      'Esta cuenta de cobro cambió. Actualiza para ver su estado.',
    );
    expect(tester.widget<AppButton>(_confirmar).onPressed, isNull);
  });

  testWidgets('otro error: mensaje genérico', (tester) async {
    await fallo(
      tester,
      const CobroFailure('x'),
      'No pudimos guardar el pago. Intenta de nuevo.',
    );
  });

  testWidgets('LP004: abre la hoja del plan', (tester) async {
    await _abrir(
      tester,
      repo: FakeCobrosRepository(
        cobros: [_cc()],
        errorPagar: const CobroFailure(
          'x',
          tipo: ErrorCobro.soloLectura,
          limite: LimitePlan.soloLectura,
        ),
      ),
    );
    await tester.tap(find.text('Nequi'));
    await tester.pump();
    await tester.tap(_confirmar);
    await tester.pumpAndSettle();
    expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
    expect(
      find.text('No pudimos guardar el pago. Intenta de nuevo.'),
      findsNothing,
    );
  });
}
