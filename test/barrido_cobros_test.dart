import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/core/theme/app_colors.dart';
import 'package:vetapp/core/widgets/buttons/app_button.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/billing/domain/cobro_failure.dart';
import 'package:vetapp/features/billing/domain/entities/cobro.dart';
import 'package:vetapp/features/billing/presentation/providers/borrador_cobro_provider.dart';
import 'package:vetapp/features/billing/presentation/providers/cobros_providers.dart';
import 'package:vetapp/features/billing/presentation/screens/cobro_form_screen.dart';
import 'package:vetapp/features/billing/presentation/screens/servicios_screen.dart';
import 'package:vetapp/features/billing/presentation/widgets/anular_cobro_sheet.dart';
import 'package:vetapp/features/billing/presentation/widgets/marcar_pagada_sheet.dart';
import 'package:vetapp/features/billing/presentation/widgets/producto_cobro_sheet.dart';
import 'package:vetapp/features/clients/domain/entities/cliente.dart';
import 'package:vetapp/features/clients/presentation/providers/clientes_providers.dart';
import 'package:vetapp/features/inventory/presentation/providers/inventario_providers.dart';
import 'package:vetapp/features/patients/presentation/providers/mascotas_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_clientes.dart';
import 'helpers/fake_cobros.dart';
import 'helpers/fake_inventario.dart';
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

final _hoy = DateTime.utc(2026, 11, 13, 17);

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

class _RepoLento extends FakeCobrosRepository {
  _RepoLento({super.servicios});

  final bloqueo = Completer<void>();

  @override
  Future<String> guardarServicio({
    String? id,
    required String nombre,
    required int precioCop,
  }) async {
    await bloqueo.future;
    return super.guardarServicio(id: id, nombre: nombre, precioCop: precioCop);
  }
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

  group('hojas', () {
    List<Override> base(FakeCobrosRepository r) => [
      ...planOverrides(),
      cobrosRepositoryProvider.overrideWithValue(r),
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: vetProfile),
      ),
      clockProvider.overrideWithValue(() => _hoy),
    ];

    testWidgets('anular: Cancelar es AppButton y cierra', (tester) async {
      final c = cobroDePrueba(numero: 12);
      await _pump(
        tester,
        abrir: (context) => TextButton(
          onPressed: () => showAnularCobroSheet(context, c),
          child: const Text('abrir'),
        ),
        overrides: base(FakeCobrosRepository(cobros: [c])),
      );
      expect(find.widgetWithText(AppButton, 'Cancelar'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Cancelar'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppButton, 'Anular'), findsNothing);
    });

    testWidgets('marcar pagada: Cambiar y Cancelar son AppButton', (
      tester,
    ) async {
      final c = cobroDePrueba(
        numero: 12,
        fecha: DateTime.utc(2026, 11, 1),
        items: null,
      ).copyWith(totalCop: 120000);
      await _pump(
        tester,
        abrir: (context) => TextButton(
          onPressed: () => showMarcarPagadaSheet(context, c),
          child: const Text('abrir'),
        ),
        overrides: base(FakeCobrosRepository(cobros: [c])),
      );
      expect(find.widgetWithText(AppButton, 'Cambiar'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Cancelar'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Marcar como pagada'), findsNothing);
    });

    testWidgets('producto: Reintentar es AppButton', (tester) async {
      final inv = FakeInventarioRepository(errorProductos: Exception('x'));
      await _pump(
        tester,
        abrir: (context) => TextButton(
          onPressed: () => showProductoCobroSheet(context, esCuentaCobro: true),
          child: const Text('abrir'),
        ),
        overrides: [
          ...planOverrides(),
          inventarioRepositoryProvider.overrideWithValue(inv),
        ],
      );
      expect(find.widgetWithText(AppButton, 'Reintentar'), findsOneWidget);
    });

    testWidgets('servicio: Quitar servicio destructivo, deshabilitado al '
        'guardar; la acción Quitar del diálogo es destructiva', (tester) async {
      final repo = _RepoLento(
        servicios: [
          servicioDePrueba(id: 's1', nombre: 'Consulta', precioCop: 50000),
        ],
      );
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        routerHarness(
          initialLocation: '/servicios',
          routes: [
            GoRoute(
              path: '/servicios',
              builder: (_, _) => const ServiciosScreen(),
            ),
          ],
          overrides: [
            ...planOverrides(),
            authProfileProvider.overrideWith(
              () => FakeAuthProfileNotifier(profile: vetAdminProfile),
            ),
            cobrosRepositoryProvider.overrideWithValue(repo),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Consulta'));
      await tester.pumpAndSettle();

      final quitar = find.widgetWithText(AppButton, 'Quitar servicio');
      expect(quitar, findsOneWidget);
      final b = tester.widget<AppButton>(quitar);
      expect(b.variant, AppButtonVariant.destructive);
      expect(b.expand, isTrue);
      final texto = tester.widget<DefaultTextStyle>(
        find
            .ancestor(
              of: find.text('Quitar servicio'),
              matching: find.byType(DefaultTextStyle),
            )
            .first,
      );
      expect(texto.style.color, AppColors.destructive);

      await tester.tap(quitar);
      await tester.pumpAndSettle();
      final accion = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(AppButton, 'Quitar'),
      );
      expect(
        tester.widget<AppButton>(accion).variant,
        AppButtonVariant.destructive,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(AppButton, 'Cancelar'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(AppButton, 'Cancelar'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Guardar servicio'));
      await tester.pump();
      expect(tester.widget<AppButton>(quitar).onPressed, isNull);
      repo.bloqueo.complete();
      await tester.pumpAndSettle();
    });
  });
}
