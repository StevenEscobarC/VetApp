import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/core/widgets/buttons/app_button.dart';
import 'package:vetapp/features/auth/data/repositories/supabase_auth_repository.dart';
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
  String creadoPor = 'vet1',
}) => cobroDePrueba(
  id: id,
  creadoPor: creadoPor,
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
  AuthProfile profile = vetProfile,
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
          () => FakeAuthProfileNotifier(profile: profile),
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

  group('anular (07-12)', () {
    const anularCc = 'Anular cuenta de cobro';

    List<AppButton> primarios(WidgetTester tester) => tester
        .widgetList<AppButton>(find.byType(AppButton))
        .where((b) => b.variant == AppButtonVariant.primary)
        .toList();

    Cobro pagada({String creadoPor = 'vet1'}) => _cc(
      estado: EstadoCobro.pagada,
      metodoPago: MetodoPago.nequi,
      pagadaEl: DateTime.utc(2026, 8, 20),
      creadoPor: creadoPor,
    );

    testWidgets('admin, CC pendiente: "Anular cuenta de cobro" destructiva '
        'como última acción y abre la hoja', (tester) async {
      await _abrir(tester, FakeCobrosRepository(cobros: [_cc()]));
      final botones = tester
          .widgetList<AppButton>(find.byType(AppButton))
          .toList();
      expect(botones.last.label, anularCc);
      expect(botones.last.variant, AppButtonVariant.destructive);
      expect(botones.last.icon, isNull);
      expect(primarios(tester).single.label, 'Marcar como pagada');

      await tester.tap(find.text(anularCc));
      await tester.pumpAndSettle();
      expect(find.text('Anular CC-0012'), findsOneWidget);
      expect(find.text('Los productos vuelven al inventario.'), findsOneWidget);
    });

    testWidgets('autor no admin, CC pagada: ve la acción, un solo primario', (
      tester,
    ) async {
      await _abrir(
        tester,
        FakeCobrosRepository(cobros: [pagada(creadoPor: 'vet-2')]),
        profile: vetColegaProfile,
      );
      final botones = tester
          .widgetList<AppButton>(find.byType(AppButton))
          .toList();
      expect(botones.last.label, anularCc);
      expect(botones.last.variant, AppButtonVariant.destructive);
      expect(primarios(tester).single.label, 'Enviar al cliente');
    });

    testWidgets('ni admin ni autor: sin acción y sin candado', (tester) async {
      for (final c in [_cc(), pagada()]) {
        await tester.pumpWidget(const SizedBox());
        await _abrir(
          tester,
          FakeCobrosRepository(cobros: [c]),
          profile: vetColegaProfile,
        );
        expect(find.textContaining('Anular'), findsNothing);
        expect(find.byIcon(Icons.lock_outline), findsNothing);
      }
    });

    testWidgets('solo lectura, autor: candado en su lugar y hoja del plan', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _abrir(
        tester,
        FakeCobrosRepository(cobros: [pagada(creadoPor: 'vet-2')]),
        profile: vetColegaProfile,
        plan: planSoloLectura,
      );
      final anular = tester.widget<AppButton>(
        find.widgetWithText(AppButton, anularCc),
      );
      expect(anular.icon, Icons.lock_outline);
      expect(anular.variant, AppButtonVariant.destructive);
      expect(
        find.bySemanticsLabel('$anularCc, bloqueado, solo lectura'),
        findsOneWidget,
      );
      await tester.tap(find.text(anularCc));
      await tester.pumpAndSettle();
      expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
      expect(find.text('Anular CC-0012'), findsNothing);
      semantics.dispose();
    });

    testWidgets('tras anular: total tachado, chip, motivo y sin acciones', (
      tester,
    ) async {
      final repo = FakeCobrosRepository(cobros: [_cc()]);
      await _abrir(tester, repo);
      await tester.tap(find.text(anularCc));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Error en el precio');
      await tester.pump();
      await tester.tap(find.widgetWithText(AppButton, 'Anular'));
      await tester.pumpAndSettle();

      expect(
        find.text('CC-0012 anulada. Los productos volvieron al inventario.'),
        findsOneWidget,
      );
      expect(find.text('Anulada'), findsOneWidget);
      expect(find.text('Motivo: Error en el precio'), findsOneWidget);
      final totales = tester.widgetList<Text>(find.text('\$ 120.000'));
      expect(totales.first.style?.decoration, TextDecoration.lineThrough);
      expect(find.text('Marcar como pagada'), findsNothing);
      expect(find.text('Enviar al cliente'), findsNothing);
      expect(find.text(anularCc), findsNothing);
      // 07-15: la única acción de una CC anulada es "Emitir una nueva".
      expect(
        tester
            .widgetList<AppButton>(find.byType(AppButton))
            .map((b) => b.label),
        ['Emitir una nueva'],
      );
      _sinFactura();
    });
  });

  group('acciones completas (07-15)', () {
    List<AppButton> botones(WidgetTester tester) =>
        tester.widgetList<AppButton>(find.byType(AppButton)).toList();

    int primarios(WidgetTester tester) => botones(
      tester,
    ).where((b) => b.variant == AppButtonVariant.primary).length;

    AppButton boton(WidgetTester tester, String label) =>
        tester.widget<AppButton>(find.widgetWithText(AppButton, label));

    Cobro convertida() => _cot(
      estado: EstadoCobro.convertida,
      convertidaEnId: 'c13',
      convertidaEnNumero: 13,
    );

    Cobro ccAnulada() => _cc(
      estado: EstadoCobro.anulada,
      citaId: 'cita1',
      motivoAnulacion: 'Error en el precio',
    );

    /// El detalle con las rutas de destino de sus acciones como marcadores.
    Future<void> abrirConRutas(
      WidgetTester tester,
      List<Cobro> cobros, {
      required String id,
      MiPlan? plan,
      AuthProfile profile = vetProfile,
    }) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Widget destino(GoRouterState s) => Scaffold(body: Text('RUTA ${s.uri}'));
      await tester.pumpWidget(
        routerHarness(
          initialLocation: '/cobros/$id',
          routes: [
            GoRoute(path: '/cobros/nuevo', builder: (_, s) => destino(s)),
            GoRoute(path: '/cobros/:id/editar', builder: (_, s) => destino(s)),
            GoRoute(
              path: '/cobros/:id/convertir',
              builder: (_, s) => destino(s),
            ),
            GoRoute(
              path: '/cobros/:id',
              builder: (_, s) =>
                  CobroDetailScreen(cobroId: s.pathParameters['id']!),
            ),
          ],
          overrides: [
            ...planOverrides(plan: plan),
            authProfileProvider.overrideWith(
              () => FakeAuthProfileNotifier(profile: profile),
            ),
            cobrosRepositoryProvider.overrideWithValue(
              FakeCobrosRepository(cobros: cobros),
            ),
            clockProvider.overrideWithValue(() => _hoy),
          ],
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('cotización abierta: primario Convertir, outline Enviar y '
        'Editar, Anular cotización destructiva al final', (tester) async {
      await abrirConRutas(tester, [_cot()], id: 'q1');
      final bs = botones(tester);
      expect(bs.map((b) => b.label), [
        'Convertir en cuenta de cobro',
        'Enviar al cliente',
        'Editar cotización',
        'Anular cotización',
      ]);
      expect(bs[0].variant, AppButtonVariant.primary);
      expect(bs[0].icon, Icons.swap_horiz);
      expect(bs[1].variant, AppButtonVariant.outline);
      expect(bs[1].icon, Icons.ios_share);
      expect(bs[2].variant, AppButtonVariant.outline);
      expect(bs[2].icon, Icons.edit_outlined);
      expect(bs[3].variant, AppButtonVariant.destructive);
      _sinFactura();
    });

    testWidgets('Convertir y Editar abren sus rutas', (tester) async {
      await abrirConRutas(tester, [_cot()], id: 'q1');
      await tester.tap(find.text('Convertir en cuenta de cobro'));
      await tester.pumpAndSettle();
      expect(find.text('RUTA /cobros/q1/convertir'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar cotización'));
      await tester.pumpAndSettle();
      expect(find.text('RUTA /cobros/q1/editar'), findsOneWidget);
    });

    testWidgets('Anular cotización abre la hoja (07-12) y Enviar la de envío', (
      tester,
    ) async {
      await abrirConRutas(tester, [_cot()], id: 'q1');
      await tester.tap(find.text('Anular cotización'));
      await tester.pumpAndSettle();
      expect(find.text('Anular COT-0004'), findsOneWidget);
      Navigator.of(tester.element(find.text('Anular COT-0004'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar al cliente'));
      await tester.pumpAndSettle();
      expect(find.text('Enviar COT-0004'), findsOneWidget);
    });

    testWidgets('cotización abierta, ni admin ni autor: sin Anular y sin '
        'candado', (tester) async {
      await abrirConRutas(
        tester,
        [_cot()],
        id: 'q1',
        profile: vetColegaProfile,
      );
      expect(find.text('Anular cotización'), findsNothing);
      expect(find.byIcon(Icons.lock_outline), findsNothing);
      expect(primarios(tester), 1);
    });

    testWidgets('cotización convertida: outline Ver CC-0013 y Enviar, sin '
        'primario', (tester) async {
      await abrirConRutas(tester, [
        convertida(),
        _cc(id: 'c13', numero: 13),
      ], id: 'q1');
      expect(botones(tester).map((b) => b.label), [
        'Ver CC-0013',
        'Enviar al cliente',
      ]);
      expect(primarios(tester), 0);
      expect(boton(tester, 'Ver CC-0013').variant, AppButtonVariant.outline);
      await tester.tap(find.text('Ver CC-0013'));
      await tester.pumpAndSettle();
      expect(find.text('CC-0013'), findsOneWidget);
    });

    testWidgets('cotización anulada: sin acciones', (tester) async {
      await abrirConRutas(tester, [
        _cot(estado: EstadoCobro.anulada),
      ], id: 'q1');
      expect(find.byType(AppButton), findsNothing);
    });

    testWidgets('CC anulada: outline Emitir una nueva abre el formulario con '
        'cliente, mascota, visita y origen; sin enviar ni pagar', (
      tester,
    ) async {
      await abrirConRutas(tester, [ccAnulada()], id: 'c1');
      expect(botones(tester).map((b) => b.label), ['Emitir una nueva']);
      expect(
        boton(tester, 'Emitir una nueva').variant,
        AppButtonVariant.outline,
      );
      expect(find.text('Enviar al cliente'), findsNothing);
      expect(find.text('Marcar como pagada'), findsNothing);

      await tester.tap(find.text('Emitir una nueva'));
      await tester.pumpAndSettle();
      final ruta = find.textContaining('RUTA /cobros/nuevo');
      expect(ruta, findsOneWidget);
      final uri = Uri.parse(
        tester.widget<Text>(ruta).data!.replaceFirst('RUTA ', ''),
      );
      expect(uri.queryParameters, {
        'tipo': 'cc',
        'clienteId': 'cli1',
        'mascotaId': 'm1',
        'citaId': 'cita1',
        'desdeCobroId': 'c1',
      });
    });

    testWidgets('un solo primario en CC pendiente, CC pagada y cotización '
        'abierta; ninguno en convertida, CC anulada y cotización anulada', (
      tester,
    ) async {
      final casos = <(Cobro, int)>[
        (_cc(), 1),
        (
          _cc(
            estado: EstadoCobro.pagada,
            metodoPago: MetodoPago.nequi,
            pagadaEl: DateTime.utc(2026, 8, 20),
          ),
          1,
        ),
        (_cot(), 1),
        (convertida(), 0),
        (ccAnulada(), 0),
        (_cot(estado: EstadoCobro.anulada), 0),
      ];
      for (final (c, n) in casos) {
        await tester.pumpWidget(const SizedBox());
        await abrirConRutas(tester, [c], id: c.id);
        expect(primarios(tester), n, reason: '${c.tipo} ${c.estado}');
      }
    });

    testWidgets('solo lectura: candado en Convertir, Editar y Anular; Enviar '
        'sigue usable', (tester) async {
      final semantics = tester.ensureSemantics();
      await abrirConRutas(tester, [_cot()], id: 'q1', plan: planSoloLectura);
      for (final l in [
        'Convertir en cuenta de cobro',
        'Editar cotización',
        'Anular cotización',
      ]) {
        expect(boton(tester, l).icon, Icons.lock_outline, reason: l);
        expect(
          find.bySemanticsLabel('$l, bloqueado, solo lectura'),
          findsOneWidget,
        );
      }
      expect(
        boton(tester, 'Convertir en cuenta de cobro').variant,
        AppButtonVariant.primary,
      );
      expect(boton(tester, 'Enviar al cliente').icon, Icons.ios_share);

      await tester.tap(find.text('Convertir en cuenta de cobro'));
      await tester.pumpAndSettle();
      expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
      expect(find.textContaining('RUTA'), findsNothing);
      Navigator.of(
        tester.element(find.text('Tu cuenta está en solo lectura')),
      ).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Editar cotización'));
      await tester.pumpAndSettle();
      expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
      Navigator.of(
        tester.element(find.text('Tu cuenta está en solo lectura')),
      ).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enviar al cliente'));
      await tester.pumpAndSettle();
      expect(find.text('Enviar COT-0004'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('solo lectura: candado en Emitir una nueva; Ver CC sigue '
        'usable', (tester) async {
      await abrirConRutas(
        tester,
        [ccAnulada()],
        id: 'c1',
        plan: planSoloLectura,
      );
      expect(boton(tester, 'Emitir una nueva').icon, Icons.lock_outline);
      await tester.tap(find.text('Emitir una nueva'));
      await tester.pumpAndSettle();
      expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
      expect(find.textContaining('RUTA'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await abrirConRutas(
        tester,
        [convertida(), _cc(id: 'c13', numero: 13)],
        id: 'q1',
        plan: planSoloLectura,
      );
      expect(find.byIcon(Icons.lock_outline), findsNothing);
      await tester.tap(find.text('Ver CC-0013'));
      await tester.pumpAndSettle();
      expect(find.text('CC-0013'), findsOneWidget);
    });
  });
}
