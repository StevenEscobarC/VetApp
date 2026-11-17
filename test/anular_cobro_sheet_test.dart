import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/core/errors/limite_plan.dart';
import 'package:vetapp/core/widgets/buttons/app_button.dart';
import 'package:vetapp/core/widgets/inputs/app_text_field.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/billing/domain/cobro_failure.dart';
import 'package:vetapp/features/billing/domain/entities/cobro.dart';
import 'package:vetapp/features/billing/domain/entities/cobro_item.dart';
import 'package:vetapp/features/billing/presentation/providers/cobros_providers.dart';
import 'package:vetapp/features/billing/presentation/widgets/anular_cobro_sheet.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_cobros.dart';
import 'helpers/fake_plan.dart';
import 'helpers/router_harness.dart';

final _hoy = DateTime.utc(2026, 11, 13, 17);

const _conProducto = [
  CobroItem(
    orden: 1,
    tipo: TipoLinea.servicio,
    descripcion: 'Consulta',
    cantidad: 1,
    precioUnitarioCop: 50000,
    servicioId: 's1',
  ),
  CobroItem(
    orden: 2,
    tipo: TipoLinea.producto,
    descripcion: 'Amoxicilina 500',
    cantidad: 2,
    precioUnitarioCop: 20000,
    productoId: 'p1',
  ),
];

Cobro _ccProductos({EstadoCobro estado = EstadoCobro.pendiente}) =>
    cobroDePrueba(
      numero: 12,
      estado: estado,
      items: _conProducto,
      metodoPago: estado == EstadoCobro.pagada ? MetodoPago.nequi : null,
    );

Cobro _ccServicios() => cobroDePrueba(numero: 12);

Cobro _cot() => cobroDePrueba(
  id: 'q1',
  tipo: TipoCobro.cotizacion,
  numero: 4,
  estado: EstadoCobro.abierta,
);

const _p1 = 'Queda anulada con su número y no se puede deshacer.';
const _pProductos = 'Los productos vuelven al inventario.';
const _pPagada = 'Estaba pagada: deja de contar en lo cobrado.';
const _pNueva = 'Si hace falta, emite una nueva.';

Future<FakeCobrosRepository> _abrir(
  WidgetTester tester,
  Cobro c, {
  FakeCobrosRepository? repo,
}) async {
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
                onPressed: () => showAnularCobroSheet(context, c),
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

Finder get _anular => find.widgetWithText(AppButton, 'Anular');

List<Map<String, Object?>> _anulaciones(FakeCobrosRepository r) => [
  for (final l in r.llamadas)
    if (l.metodo == 'anular') l.args,
];

void _sinPalabrasProhibidas() {
  expect(
    find.textContaining(RegExp('eliminar|borrar|factur', caseSensitive: false)),
    findsNothing,
  );
}

void main() {
  testWidgets('CC pendiente con productos: título y consecuencias', (
    tester,
  ) async {
    await _abrir(tester, _ccProductos());
    expect(find.text('Anular CC-0012'), findsOneWidget);
    expect(find.text(_p1), findsOneWidget);
    expect(find.text(_pProductos), findsOneWidget);
    expect(find.text(_pNueva), findsOneWidget);
    expect(find.text(_pPagada), findsNothing);
    expect(
      tester.widget<AppButton>(_anular).variant,
      AppButtonVariant.destructive,
    );
    expect(find.widgetWithText(TextButton, 'Cancelar'), findsOneWidget);
    _sinPalabrasProhibidas();
  });

  testWidgets('CC pendiente sin productos: no menciona el inventario', (
    tester,
  ) async {
    await _abrir(tester, _ccServicios());
    expect(find.text(_p1), findsOneWidget);
    expect(find.text(_pProductos), findsNothing);
    expect(find.text(_pNueva), findsOneWidget);
  });

  testWidgets('CC pagada: agrega que deja de contar en lo cobrado', (
    tester,
  ) async {
    await _abrir(tester, _ccProductos(estado: EstadoCobro.pagada));
    expect(find.text(_pPagada), findsOneWidget);
    expect(find.text(_pProductos), findsOneWidget);
    expect(find.text(_pNueva), findsOneWidget);
  });

  testWidgets('cotización: "Anular COT-0004" y solo la primera frase', (
    tester,
  ) async {
    await _abrir(tester, _cot());
    expect(find.text('Anular COT-0004'), findsOneWidget);
    expect(find.text(_p1), findsOneWidget);
    expect(find.text(_pProductos), findsNothing);
    expect(find.text(_pPagada), findsNothing);
    expect(find.text(_pNueva), findsNothing);
    _sinPalabrasProhibidas();
  });

  testWidgets('campo motivo: hint, maxLength 200 y autofocus', (tester) async {
    await _abrir(tester, _ccServicios());
    final campo = tester.widget<AppTextField>(find.byType(AppTextField));
    expect(campo.label, 'Motivo de la anulación');
    expect(campo.hintText, 'Ej. Error en el precio');
    expect(campo.maxLength, 200);
    expect(campo.autofocus, isTrue);
  });

  testWidgets('motivo corto: "Escribe el motivo." sin llamar', (tester) async {
    final repo = await _abrir(tester, _ccServicios());
    await tester.enterText(find.byType(TextField), ' ab ');
    await tester.tap(_anular);
    await tester.pumpAndSettle();
    expect(find.text('Escribe el motivo.'), findsOneWidget);
    expect(_anulaciones(repo), isEmpty);
    expect(find.text('Anular CC-0012'), findsOneWidget);
  });

  testWidgets('éxito con productos: una sola llamada, cierra y avisa', (
    tester,
  ) async {
    final repo = await _abrir(tester, _ccProductos());
    await tester.enterText(find.byType(TextField), '  Error en el precio  ');
    await tester.pump();
    await tester.tap(_anular);
    await tester.tap(_anular, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_anulaciones(repo), [
      {'id': 'c1', 'motivo': 'Error en el precio'},
    ]);
    expect(find.text('Anular CC-0012'), findsNothing);
    expect(
      find.text('CC-0012 anulada. Los productos volvieron al inventario.'),
      findsOneWidget,
    );
  });

  testWidgets('éxito sin productos: "CC-0012 anulada."', (tester) async {
    await _abrir(tester, _ccServicios());
    await tester.enterText(find.byType(TextField), 'Duplicada');
    await tester.pump();
    await tester.tap(_anular);
    await tester.pumpAndSettle();
    expect(find.text('CC-0012 anulada.'), findsOneWidget);
    expect(find.textContaining('inventario'), findsNothing);
  });

  testWidgets('éxito cotización: "COT-0004 anulada."', (tester) async {
    await _abrir(tester, _cot());
    await tester.enterText(find.byType(TextField), 'Cliente desistió');
    await tester.pump();
    await tester.tap(_anular);
    await tester.pumpAndSettle();
    expect(find.text('COT-0004 anulada.'), findsOneWidget);
  });

  Future<void> fallo(
    WidgetTester tester,
    CobroFailure error,
    String texto,
  ) async {
    final c = _ccProductos();
    await _abrir(
      tester,
      c,
      repo: FakeCobrosRepository(cobros: [c], errorAnular: error),
    );
    await tester.enterText(find.byType(TextField), 'Error en el precio');
    await tester.pump();
    await tester.tap(_anular);
    await tester.pumpAndSettle();
    expect(find.text(texto), findsOneWidget);
    // La hoja sigue abierta.
    expect(find.text('Anular CC-0012'), findsOneWidget);
    _sinPalabrasProhibidas();
  }

  testWidgets('sin conexión: mensaje en línea', (tester) async {
    await fallo(
      tester,
      const CobroFailure('x', tipo: ErrorCobro.sinConexion),
      'Sin conexión, la anulación no se guardó. Inténtalo de nuevo cuando '
      'tengas señal.',
    );
  });

  testWidgets('sin permiso (42501): mensaje en línea', (tester) async {
    await fallo(
      tester,
      const CobroFailure('x', tipo: ErrorCobro.sinPermiso),
      'Solo el administrador o quien la emitió puede anularla.',
    );
  });

  testWidgets('estado inválido: ya estaba anulada', (tester) async {
    await fallo(
      tester,
      const CobroFailure('x', tipo: ErrorCobro.estadoInvalido),
      'Ya estaba anulada. Actualiza para ver su estado.',
    );
  });

  testWidgets('BC002: la cotización ya se convirtió (IN-05)', (tester) async {
    final c = _cot();
    await _abrir(
      tester,
      c,
      repo: FakeCobrosRepository(
        cobros: [c],
        errorAnular: const CobroFailure(
          'x',
          tipo: ErrorCobro.cotizacionNoDisponible,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Cliente desistió');
    await tester.pump();
    await tester.tap(_anular);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Esta cotización ya se convirtió. Actualiza para ver su estado.',
      ),
      findsOneWidget,
    );
    expect(find.text('No pudimos anular. Intenta de nuevo.'), findsNothing);
    expect(find.text('Anular COT-0004'), findsOneWidget);
    _sinPalabrasProhibidas();
  });

  testWidgets('otro error: mensaje genérico', (tester) async {
    await fallo(
      tester,
      const CobroFailure('x'),
      'No pudimos anular. Intenta de nuevo.',
    );
  });

  testWidgets('LP004: abre la hoja del plan', (tester) async {
    final c = _ccServicios();
    await _abrir(
      tester,
      c,
      repo: FakeCobrosRepository(
        cobros: [c],
        errorAnular: const CobroFailure(
          'x',
          tipo: ErrorCobro.soloLectura,
          limite: LimitePlan.soloLectura,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Error en el precio');
    await tester.pump();
    await tester.tap(_anular);
    await tester.pumpAndSettle();
    expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
    expect(find.text('No pudimos anular. Intenta de nuevo.'), findsNothing);
  });

  testWidgets('Cancelar cierra sin llamar', (tester) async {
    final repo = await _abrir(tester, _ccServicios());
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Anular CC-0012'), findsNothing);
    expect(_anulaciones(repo), isEmpty);
  });
}
