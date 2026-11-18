import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/core/widgets/buttons/app_button.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/billing/domain/cobro_failure.dart';
import 'package:vetapp/features/billing/domain/entities/cobro.dart';
import 'package:vetapp/features/billing/presentation/providers/borrador_cobro_provider.dart';
import 'package:vetapp/features/billing/presentation/providers/cobros_providers.dart';
import 'package:vetapp/features/billing/presentation/screens/cobro_form_screen.dart';
import 'package:vetapp/features/clients/domain/entities/cliente.dart';
import 'package:vetapp/features/clients/presentation/providers/clientes_providers.dart';
import 'package:vetapp/features/patients/presentation/providers/mascotas_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_clientes.dart';
import 'helpers/fake_cobros.dart';
import 'helpers/fake_mascotas.dart';
import 'helpers/fake_plan.dart';
import 'helpers/router_harness.dart';

/// Barrido DASH-04 de cobros (08-08): los botones sueltos del formulario y
/// de las hojas pasan a [AppButton] sin cambiar etiqueta ni callback.
const _archivos = [
  'lib/features/billing/presentation/screens/cobro_form_screen.dart',
  'lib/features/billing/presentation/widgets/anular_cobro_sheet.dart',
  'lib/features/billing/presentation/widgets/marcar_pagada_sheet.dart',
  'lib/features/billing/presentation/widgets/producto_cobro_sheet.dart',
  'lib/features/billing/presentation/widgets/servicio_sheet.dart',
  'lib/features/billing/presentation/widgets/linea_cobro_tile.dart',
];

String _codigo(String ruta) => File(
  ruta,
).readAsLinesSync().where((l) => !l.trimLeft().startsWith('//')).join('\n');

const _laura = Cliente(
  id: 'cli1',
  clinicaId: 'cli-1',
  nombre: 'Laura Gómez',
  telefono: '3001112233',
);

PrefillCobro _prefill() => (
  modo: ModoFormCobro.nuevo,
  tipo: TipoCobro.cuentaCobro,
  clienteId: 'cli1',
  mascotaId: null,
  citaId: null,
  consultaId: null,
  origenId: null,
);

Future<void> _pump(
  WidgetTester tester, {
  required Widget Function(BuildContext) abrir,
  List<Override> overrides = const [],
}) async {
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
            body: Center(child: Builder(builder: abrir)),
          ),
        ),
        GoRoute(
          path: '/servicios',
          builder: (_, _) => const Scaffold(body: Text('Pantalla servicios')),
        ),
      ],
      overrides: overrides,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

List<Override> _overridesForm(FakeCobrosRepository repo) {
  var n = 0;
  return [
    ...planOverrides(),
    authProfileProvider.overrideWith(
      () => FakeAuthProfileNotifier(profile: vetProfile),
    ),
    cobrosRepositoryProvider.overrideWithValue(repo),
    clienteRepositoryProvider.overrideWithValue(
      FakeClienteRepository(clientes: [_laura]),
    ),
    clientesProvider.overrideWith(
      () => FakeClientesNotifier(clientes: [_laura]),
    ),
    mascotaRepositoryProvider.overrideWithValue(FakeMascotaRepository()),
    claveIdempotenciaProvider.overrideWithValue(() => 'clave-${++n}'),
  ];
}

Future<void> _abrirForm(WidgetTester tester, FakeCobrosRepository repo) =>
    _pump(
      tester,
      abrir: (context) => TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CobroFormScreen(prefill: _prefill()),
          ),
        ),
        child: const Text('abrir'),
      ),
      overrides: _overridesForm(repo),
    );

Future<void> _agregarConsulta(WidgetTester tester) async {
  await tester.tap(find.text('Consulta · \$ 50.000'));
  await tester.pumpAndSettle();
}

void main() {
  group('fuente', () {
    for (final ruta in _archivos) {
      test('sin TextButton suelto ni la palabra prohibida: $ruta', () {
        final c = _codigo(ruta);
        expect(c.contains('TextButton('), isFalse);
        expect(c.contains('TextButton.icon('), isFalse);
        expect(c.contains('TextButton.styleFrom'), isFalse);
        expect(RegExp('[Ff]actura').hasMatch(c), isFalse);
      });
    }

    test('linea_cobro_tile sin SizedBox numérico de una dimensión', () {
      final c = _codigo(_archivos.last);
      expect(RegExp(r'SizedBox\((height|width): *[0-9]').hasMatch(c), isFalse);
    });

    test('Volver y Descartar del banner son AppButton', () {
      final c = _codigo(_archivos.first);
      expect(RegExp(r"AppButton\(\s*label: 'Volver',").hasMatch(c), isTrue);
      expect(
        RegExp(
          r"AppButton\(\s*label: 'Descartar',\s*variant: "
          r'AppButtonVariant\.text',
        ).hasMatch(c),
        isTrue,
      );
    });
  });

  group('formulario', () {
    testWidgets('diálogo de descartar: Seguir editando es AppButton, se '
        'queda; Descartar sale', (tester) async {
      await _abrirForm(
        tester,
        FakeCobrosRepository(servicios: [servicioDePrueba()]),
      );
      await _agregarConsulta(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppButton, 'Seguir editando'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Seguir editando'));
      await tester.pumpAndSettle();
      expect(find.byType(CobroFormScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Descartar'));
      await tester.pumpAndSettle();
      expect(find.byType(CobroFormScreen), findsNothing);
    });

    testWidgets('Cambiar cliente es AppButton y abre la hoja', (tester) async {
      await _abrirForm(
        tester,
        FakeCobrosRepository(servicios: [servicioDePrueba()]),
      );
      expect(find.widgetWithText(AppButton, 'Cambiar'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Cambiar'));
      await tester.pumpAndSettle();
      expect(find.text('Elegir cliente'), findsOneWidget);
    });

    testWidgets('Agregar servicios es AppButton y abre /servicios', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        routerHarness(
          initialLocation: '/form',
          routes: [
            GoRoute(
              path: '/form',
              builder: (_, _) => CobroFormScreen(prefill: _prefill()),
            ),
            GoRoute(
              path: '/servicios',
              builder: (_, _) =>
                  const Scaffold(body: Text('Pantalla servicios')),
            ),
          ],
          overrides: _overridesForm(FakeCobrosRepository(servicios: const [])),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(AppButton, 'Agregar servicios'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(AppButton, 'Agregar servicios'));
      await tester.pumpAndSettle();
      expect(find.text('Pantalla servicios'), findsOneWidget);
    });

    testWidgets('sin conexión: Descartar del banner es AppButton', (
      tester,
    ) async {
      final repo = FakeCobrosRepository(
        servicios: [servicioDePrueba()],
        errorCrear: const CobroFailure(
          'Sin conexión',
          tipo: ErrorCobro.sinConexion,
        ),
      );
      await _abrirForm(tester, repo);
      await _agregarConsulta(tester);
      await tester.tap(find.text('Emitir cuenta de cobro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Emitir'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppButton, 'Descartar'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Descartar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar este cobro?'), findsOneWidget);
    });
  });
}
