import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/core/widgets/buttons/app_button.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/billing/domain/entities/cobro.dart';
import 'package:vetapp/features/billing/domain/entities/cobro_item.dart';
import 'package:vetapp/features/billing/presentation/providers/cobros_providers.dart';
import 'package:vetapp/features/billing/presentation/screens/cobro_detail_screen.dart';
import 'package:vetapp/features/clients/domain/entities/cliente.dart';
import 'package:vetapp/features/clients/presentation/providers/clientes_providers.dart';
import 'package:vetapp/features/plan/domain/mi_plan.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_cobros.dart';
import 'helpers/fake_plan.dart';
import 'helpers/router_harness.dart';

// "Hoy" en Bogotá: 13/11/2026.
final _hoy = DateTime.utc(2026, 11, 13, 17);

const _lineas = [
  CobroItem(
    orden: 1,
    tipo: TipoLinea.servicio,
    descripcion: 'Consulta general',
    cantidad: 1,
    precioUnitarioCop: 50000,
  ),
  CobroItem(
    orden: 2,
    tipo: TipoLinea.servicio,
    descripcion: 'Vacuna',
    cantidad: 2,
    precioUnitarioCop: 25000,
  ),
  // Producto archivado después: el documento conserva lo guardado (D-14).
  CobroItem(
    orden: 3,
    tipo: TipoLinea.producto,
    descripcion: 'Amoxicilina 500',
    cantidad: 1,
    precioUnitarioCop: 20000,
    productoId: 'p-archivado',
  ),
];

Cobro _cc({
  String id = 'c1',
  EstadoCobro estado = EstadoCobro.pendiente,
  MetodoPago? metodoPago,
  DateTime? pagadaEl,
  String? citaId,
  String? consultaId,
  String? cotizacionOrigenId,
  int? cotizacionOrigenNumero,
  DateTime? anuladaAt,
  String? anuladaPorNombre,
  String? motivoAnulacion,
  String? clienteCedula = '1020304050',
  int numero = 12,
}) => cobroDePrueba(
  id: id,
  numero: numero,
  estado: estado,
  fecha: DateTime.utc(2026, 8, 18),
  autorNombre: 'Ana Ruiz',
  clienteCedula: clienteCedula,
  items: _lineas,
  metodoPago: metodoPago,
  pagadaEl: pagadaEl,
  citaId: citaId,
  consultaId: consultaId,
  cotizacionOrigenId: cotizacionOrigenId,
  cotizacionOrigenNumero: cotizacionOrigenNumero,
  anuladaAt: anuladaAt,
  anuladaPorNombre: anuladaPorNombre,
  motivoAnulacion: motivoAnulacion,
);

Cobro _cot({
  String id = 'q1',
  EstadoCobro estado = EstadoCobro.abierta,
  DateTime? validaHasta,
  String? convertidaEnId,
  int? convertidaEnNumero,
}) => cobroDePrueba(
  id: id,
  tipo: TipoCobro.cotizacion,
  numero: 4,
  estado: estado,
  fecha: DateTime.utc(2026, 11, 5),
  validaHasta: validaHasta ?? DateTime.utc(2026, 11, 20),
  autorNombre: 'Ana Ruiz',
  convertidaEnId: convertidaEnId,
  convertidaEnNumero: convertidaEnNumero,
);

Future<void> _abrir(
  WidgetTester tester,
  FakeCobrosRepository repo, {
  String id = 'c1',
  MiPlan? plan,
}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    routerHarness(
      initialLocation: '/cobros/$id',
      routes: [
        GoRoute(
          path: '/cobros',
          builder: (_, _) => const Scaffold(body: Text('LISTA')),
        ),
        GoRoute(
          path: '/cobros/:id',
          builder: (_, s) =>
              CobroDetailScreen(cobroId: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/clientes/:id',
          builder: (_, s) =>
              Scaffold(body: Text('CLIENTE ${s.pathParameters['id']}')),
        ),
      ],
      overrides: [
        ...planOverrides(plan: plan),
        clienteProvider.overrideWith(
          (ref, id) async => Cliente(
            id: id,
            clinicaId: 'cli-1',
            nombre: 'Laura Gómez',
            telefono: '3001234567',
          ),
        ),
        authProfileProvider.overrideWith(
          () => FakeAuthProfileNotifier(profile: vetProfile),
        ),
        cobrosRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => _hoy),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

void _sinFactura() =>
    expect(find.textContaining(RegExp('actura')), findsNothing);

void main() {
  testWidgets('CC pendiente: encabezado, cliente, detalle y sin Editar', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _abrir(tester, FakeCobrosRepository(cobros: [_cc()]));

    expect(find.text('Cuenta de cobro'), findsOneWidget);
    expect(find.text('CC-0012'), findsOneWidget);
    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsOneWidget);
    // Total del encabezado (Display) + fila Total del detalle.
    expect(find.text('\$ 120.000'), findsNWidgets(2));
    expect(find.bySemanticsLabel(RegExp('120\\.000 pesos')), findsWidgets);
    expect(
      find.text('Emitida el 18/08/2026 por Dr(a). Ana Ruiz'),
      findsOneWidget,
    );

    expect(find.text('Cliente'), findsOneWidget);
    expect(find.text('Laura Gómez'), findsOneWidget);
    expect(find.text('C.C. 1.020.304.050'), findsOneWidget);
    expect(find.text('Mascota: Rocky'), findsOneWidget);

    expect(find.text('Detalle'), findsOneWidget);
    expect(find.text('Consulta general'), findsOneWidget);
    expect(find.text('1 × \$ 50.000'), findsOneWidget);
    expect(find.text('Vacuna'), findsOneWidget);
    expect(find.text('2 × \$ 25.000'), findsOneWidget);
    expect(find.text('\$ 50.000'), findsNWidgets(2));
    expect(find.text('Total'), findsOneWidget);

    // Línea de producto archivado: descripción y precio guardados (D-14).
    expect(find.text('Amoxicilina 500'), findsOneWidget);
    expect(find.text('1 × \$ 20.000'), findsOneWidget);
    expect(find.text('\$ 20.000'), findsOneWidget);

    // D-10: una CC nunca ofrece editar.
    expect(find.textContaining('Editar'), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    _sinFactura();
    semantics.dispose();
  });

  testWidgets('sin cédula no muestra la línea C.C.', (tester) async {
    await _abrir(
      tester,
      FakeCobrosRepository(cobros: [_cc(clienteCedula: null)]),
    );
    expect(find.textContaining('C.C.'), findsNothing);
  });

  testWidgets('CC pagada: fecha y método', (tester) async {
    await _abrir(
      tester,
      FakeCobrosRepository(
        cobros: [
          _cc(
            estado: EstadoCobro.pagada,
            metodoPago: MetodoPago.nequi,
            pagadaEl: DateTime.utc(2026, 8, 20),
          ),
        ],
      ),
    );
    expect(find.text('Pagada el 20/08/2026 · Nequi'), findsOneWidget);
    expect(find.text('Pagada'), findsOneWidget);
    expect(find.textContaining('Editar'), findsNothing);
  });

  testWidgets('cotización abierta: título, creada y validez', (tester) async {
    await _abrir(tester, FakeCobrosRepository(cobros: [_cot()]), id: 'q1');
    expect(find.text('Cotización'), findsOneWidget);
    expect(find.text('COT-0004'), findsOneWidget);
    expect(
      find.text('Creada el 05/11/2026 por Dr(a). Ana Ruiz'),
      findsOneWidget,
    );
    expect(
      find.text('Válida por 15 días, hasta el 20/11/2026'),
      findsOneWidget,
    );
    _sinFactura();
  });

  testWidgets('cotización abierta vencida: "Venció el"', (tester) async {
    await _abrir(
      tester,
      FakeCobrosRepository(
        cobros: [_cot(validaHasta: DateTime.utc(2026, 10, 16))],
      ),
      id: 'q1',
    );
    expect(find.text('Venció el 16/10/2026'), findsOneWidget);
    expect(find.textContaining('Válida por'), findsNothing);
  });

  testWidgets('cotización convertida: fila de 48dp a la CC', (tester) async {
    await _abrir(
      tester,
      FakeCobrosRepository(
        cobros: [
          _cot(
            estado: EstadoCobro.convertida,
            convertidaEnId: 'c13',
            convertidaEnNumero: 13,
          ),
          _cc(id: 'c13', numero: 13),
        ],
      ),
      id: 'q1',
    );
    expect(find.text('Convertida'), findsOneWidget);
    final fila = find.ancestor(
      of: find.text('Convertida en CC-0013'),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(fila.first).height, greaterThanOrEqualTo(48));
    await tester.tap(find.text('Convertida en CC-0013'));
    await tester.pumpAndSettle();
    expect(find.text('CC-0013'), findsOneWidget);
    expect(find.text('Cuenta de cobro'), findsOneWidget);
  });

  testWidgets('CC desde cotización: "Viene de la cotización" abre la COT', (
    tester,
  ) async {
    await _abrir(
      tester,
      FakeCobrosRepository(
        cobros: [
          _cc(cotizacionOrigenId: 'q1', cotizacionOrigenNumero: 4),
          _cot(
            estado: EstadoCobro.convertida,
            convertidaEnId: 'c1',
            convertidaEnNumero: 12,
          ),
        ],
      ),
    );
    expect(find.text('Viene de la cotización COT-0004'), findsOneWidget);
    await tester.tap(find.text('Viene de la cotización COT-0004'));
    await tester.pumpAndSettle();
    expect(find.text('COT-0004'), findsOneWidget);
  });

  testWidgets('CC anulada: total tachado y bloque de anulación', (
    tester,
  ) async {
    await _abrir(
      tester,
      FakeCobrosRepository(
        cobros: [
          _cc(
            estado: EstadoCobro.anulada,
            anuladaAt: DateTime.utc(2026, 11, 13, 15),
            anuladaPorNombre: 'Luis Gómez',
            motivoAnulacion: 'Error en el precio',
          ),
        ],
      ),
    );
    expect(find.text('Anulada'), findsOneWidget);
    expect(
      find.text('Anulada el 13/11/2026 por Dr(a). Luis Gómez.'),
      findsOneWidget,
    );
    expect(find.text('Motivo: Error en el precio'), findsOneWidget);
    final totales = tester.widgetList<Text>(find.text('\$ 120.000'));
    expect(totales.first.style?.decoration, TextDecoration.lineThrough);
    _sinFactura();
  });

  testWidgets('vínculos: cita y consulta', (tester) async {
    await _abrir(
      tester,
      FakeCobrosRepository(
        cobros: [
          _cc(citaId: 'cita1'),
          _cc(id: 'c2', numero: 13, consultaId: 'con1'),
        ],
      ),
    );
    expect(find.text('De la cita del 18/08/2026'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await _abrir(
      tester,
      FakeCobrosRepository(
        cobros: [_cc(id: 'c2', numero: 13, consultaId: 'con1')],
      ),
      id: 'c2',
    );
    expect(find.text('De la consulta del 18/08/2026'), findsOneWidget);
  });

  testWidgets('la fila del cliente abre su detalle', (tester) async {
    await _abrir(tester, FakeCobrosRepository(cobros: [_cc()]));
    final fila = find.ancestor(
      of: find.text('Laura Gómez'),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(fila.first).height, greaterThanOrEqualTo(48));
    await tester.tap(find.text('Laura Gómez'));
    await tester.pumpAndSettle();
    expect(find.text('CLIENTE cli1'), findsOneWidget);
  });

  testWidgets('no encontrado: mensaje y Volver a Cobros', (tester) async {
    await _abrir(tester, FakeCobrosRepository(), id: 'nada');
    expect(find.text('Este cobro ya no está disponible.'), findsOneWidget);
    await tester.tap(find.text('Volver a Cobros'));
    await tester.pumpAndSettle();
    expect(find.text('LISTA'), findsOneWidget);
  });

  testWidgets('error: mensaje y Reintentar vuelve a leer', (tester) async {
    final repo = FakeCobrosRepository(errorCobro: Exception('red'));
    await _abrir(tester, repo);
    expect(
      find.text('No pudimos cargar el cobro. Intenta de nuevo.'),
      findsOneWidget,
    );
    final antes = repo.llamadas.where((l) => l.metodo == 'cobro').length;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(
      repo.llamadas.where((l) => l.metodo == 'cobro').length,
      greaterThan(antes),
    );
    _sinFactura();
  });

  group('acciones (07-09)', () {
    List<AppButton> primarios(WidgetTester tester) => tester
        .widgetList<AppButton>(find.byType(AppButton))
        .where((b) => b.variant == AppButtonVariant.primary)
        .toList();

    AppButton boton(WidgetTester tester, String label) =>
        tester.widget<AppButton>(find.widgetWithText(AppButton, label));

    testWidgets('CC pendiente: un solo primario "Marcar como pagada" y '
        'outline "Enviar al cliente"', (tester) async {
      await _abrir(tester, FakeCobrosRepository(cobros: [_cc()]));
      final p = primarios(tester);
      expect(p, hasLength(1));
      expect(p.single.label, 'Marcar como pagada');
      expect(p.single.icon, Icons.payments_outlined);
      final enviar = boton(tester, 'Enviar al cliente');
      expect(enviar.variant, AppButtonVariant.outline);
      expect(enviar.icon, Icons.ios_share);
    });

    testWidgets('CC pagada: un solo primario "Enviar al cliente"', (
      tester,
    ) async {
      await _abrir(
        tester,
        FakeCobrosRepository(
          cobros: [
            _cc(
              estado: EstadoCobro.pagada,
              metodoPago: MetodoPago.nequi,
              pagadaEl: DateTime.utc(2026, 8, 20),
            ),
          ],
        ),
      );
      final p = primarios(tester);
      expect(p, hasLength(1));
      expect(p.single.label, 'Enviar al cliente');
      expect(find.text('Marcar como pagada'), findsNothing);
    });

    testWidgets('CC anulada: ni pagar ni enviar', (tester) async {
      await _abrir(
        tester,
        FakeCobrosRepository(
          cobros: [_cc(estado: EstadoCobro.anulada, motivoAnulacion: 'Error')],
        ),
      );
      expect(find.text('Marcar como pagada'), findsNothing);
      expect(find.text('Enviar al cliente'), findsNothing);
    });

    testWidgets('solo lectura: candado en pagar, Enviar sigue usable', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _abrir(
        tester,
        FakeCobrosRepository(cobros: [_cc()]),
        plan: planSoloLectura,
      );
      final pagar = boton(tester, 'Marcar como pagada');
      expect(pagar.icon, Icons.lock_outline);
      expect(pagar.variant, AppButtonVariant.primary);
      expect(
        find.bySemanticsLabel('Marcar como pagada, bloqueado, solo lectura'),
        findsOneWidget,
      );
      expect(boton(tester, 'Enviar al cliente').icon, Icons.ios_share);

      await tester.tap(find.text('Marcar como pagada'));
      await tester.pumpAndSettle();
      expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
      expect(find.text('Confirmar pago'), findsNothing);

      Navigator.of(
        tester.element(find.text('Tu cuenta está en solo lectura')),
      ).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar al cliente'));
      await tester.pumpAndSettle();
      expect(find.text('Enviar CC-0012'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('Enviar al cliente abre la hoja de envío', (tester) async {
      await _abrir(tester, FakeCobrosRepository(cobros: [_cc()]));
      await tester.tap(find.text('Enviar al cliente'));
      await tester.pumpAndSettle();
      expect(find.text('Enviar CC-0012'), findsOneWidget);
      expect(find.text('Para Laura Gómez'), findsOneWidget);
    });

    testWidgets('pagar refresca el detalle a Pagada', (tester) async {
      final repo = FakeCobrosRepository(cobros: [_cc()]);
      await _abrir(tester, repo);
      await tester.tap(find.text('Marcar como pagada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nequi'));
      await tester.pump();
      await tester.tap(find.widgetWithText(AppButton, 'Confirmar pago'));
      await tester.pumpAndSettle();
      expect(find.text('CC-0012 marcada como pagada.'), findsOneWidget);
      expect(find.text('Pagada el 13/11/2026 · Nequi'), findsOneWidget);
      expect(find.text('Marcar como pagada'), findsNothing);
      expect(primarios(tester).single.label, 'Enviar al cliente');
    });
  });
}
