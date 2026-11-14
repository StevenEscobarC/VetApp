import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/billing/domain/entities/cobro.dart';
import 'package:vetapp/features/billing/domain/entities/cobro_item.dart';
import 'package:vetapp/features/billing/presentation/providers/cobros_providers.dart';
import 'package:vetapp/features/billing/presentation/screens/cobros_screen.dart';
import 'package:vetapp/features/billing/presentation/widgets/cobro_fila.dart';
import 'package:vetapp/features/billing/presentation/widgets/estado_cobro_chip.dart';
import 'package:vetapp/features/plan/domain/mi_plan.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_cobros.dart';
import 'helpers/fake_plan.dart';
import 'helpers/router_harness.dart';

// "Hoy" en Bogotá: 13/11/2026.
final _hoy = DateTime.utc(2026, 11, 13, 17);

const _tresLineas = [
  CobroItem(
    orden: 1,
    tipo: TipoLinea.servicio,
    descripcion: 'Consulta',
    cantidad: 1,
    precioUnitarioCop: 50000,
  ),
  CobroItem(
    orden: 2,
    tipo: TipoLinea.servicio,
    descripcion: 'Baño',
    cantidad: 1,
    precioUnitarioCop: 40000,
  ),
  CobroItem(
    orden: 3,
    tipo: TipoLinea.otro,
    descripcion: 'Collar',
    cantidad: 1,
    precioUnitarioCop: 30000,
  ),
];

final _pendiente = cobroDePrueba(
  id: 'c1',
  numero: 12,
  fecha: DateTime.utc(2026, 8, 18),
  items: _tresLineas,
);
final _pendiente2 = cobroDePrueba(
  id: 'c2',
  numero: 11,
  clienteNombre: 'Pedro Ruiz',
  mascotaNombre: 'Luna',
);
final _pagada = cobroDePrueba(
  id: 'c3',
  numero: 10,
  clienteNombre: 'Marta Díaz',
  mascotaNombre: 'Toby',
  estado: EstadoCobro.pagada,
  metodoPago: MetodoPago.nequi,
);
final _anulada = cobroDePrueba(
  id: 'c4',
  numero: 9,
  clienteNombre: 'Sara León',
  mascotaNombre: 'Kiwi',
  estado: EstadoCobro.anulada,
);
final _cotAbierta = cobroDePrueba(
  id: 'q1',
  tipo: TipoCobro.cotizacion,
  numero: 4,
  estado: EstadoCobro.abierta,
  clienteNombre: 'Julia Paz',
  mascotaNombre: 'Max',
  fecha: DateTime.utc(2026, 11, 5),
  validaHasta: DateTime.utc(2026, 11, 20),
);
final _cotVencida = cobroDePrueba(
  id: 'q2',
  tipo: TipoCobro.cotizacion,
  numero: 3,
  estado: EstadoCobro.abierta,
  clienteNombre: 'Iván Soto',
  mascotaNombre: 'Nala',
  fecha: DateTime.utc(2026, 10, 1),
  validaHasta: DateTime.utc(2026, 10, 16),
);
final _cotConvertida = cobroDePrueba(
  id: 'q3',
  tipo: TipoCobro.cotizacion,
  numero: 2,
  estado: EstadoCobro.convertida,
  clienteNombre: 'Ana Gil',
  mascotaNombre: 'Coco',
);

const _resumen = ResumenCobros(
  cobradoMes: 3850000,
  porCobrar: 450000,
  pendientes: 1,
);

FakeCobrosRepository _repo({
  List<Cobro>? cobros,
  ResumenCobros? resumen = _resumen,
  Object? errorResumen,
  Object? errorCobros,
}) => FakeCobrosRepository(
  cobros:
      cobros ??
      [
        _pendiente,
        _pendiente2,
        _pagada,
        _anulada,
        _cotAbierta,
        _cotVencida,
        _cotConvertida,
      ],
  resumenData: resumen,
  errorResumen: errorResumen,
  errorCobros: errorCobros,
);

Widget _app(
  FakeCobrosRepository repo, {
  MiPlan? plan,
  TipoCobro tipoInicial = TipoCobro.cuentaCobro,
  double textScale = 1,
}) => MediaQuery(
  data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
  child: routerHarness(
    initialLocation: '/cobros',
    routes: [
      GoRoute(
        path: '/cobros',
        builder: (_, _) => CobrosScreen(tipoInicial: tipoInicial),
      ),
      GoRoute(
        path: '/cobros/nuevo',
        builder: (_, s) =>
            Scaffold(body: Text('NUEVO ${s.uri.queryParameters['tipo']}')),
      ),
      GoRoute(
        path: '/cobros/:id',
        builder: (_, s) =>
            Scaffold(body: Text('DETALLE ${s.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/servicios',
        builder: (_, _) => const Scaffold(body: Text('SERVICIOS')),
      ),
    ],
    overrides: [
      ...planOverrides(plan: plan),
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: vetProfile),
      ),
      cobrosRepositoryProvider.overrideWithValue(repo),
      clockProvider.overrideWithValue(() => _hoy),
    ],
  ),
);

Future<void> _abrir(
  WidgetTester tester,
  FakeCobrosRepository repo, {
  MiPlan? plan,
  TipoCobro tipoInicial = TipoCobro.cuentaCobro,
}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(repo, plan: plan, tipoInicial: tipoInicial));
  await tester.pumpAndSettle();
}

void _sinFactura() =>
    expect(find.textContaining(RegExp('actura')), findsNothing);

void main() {
  group('resumen', () {
    testWidgets('muestra cobrado del mes y por cobrar del servidor', (
      tester,
    ) async {
      await _abrir(tester, _repo());
      expect(find.text('Cobrado este mes'), findsOneWidget);
      expect(find.text('\$ 3.850.000'), findsOneWidget);
      expect(find.text('Noviembre 2026'), findsOneWidget);
      expect(find.text('Por cobrar'), findsOneWidget);
      expect(find.text('\$ 450.000'), findsOneWidget);
      expect(find.text('1 cuenta pendiente'), findsOneWidget);
      // El conteo del filtro viene del servidor (1), no de la lista (2).
      expect(find.text('Pendientes (1)'), findsOneWidget);
      _sinFactura();
    });

    testWidgets('plural y "Nada pendiente"', (tester) async {
      await _abrir(
        tester,
        _repo(resumen: const ResumenCobros(porCobrar: 10, pendientes: 3)),
      );
      expect(find.text('3 cuentas pendientes'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await _abrir(tester, _repo(resumen: const ResumenCobros()));
      expect(find.text('Nada pendiente'), findsOneWidget);
      expect(find.text('Pendientes'), findsOneWidget);
    });

    testWidgets('error del resumen: guiones y aviso, la lista sigue', (
      tester,
    ) async {
      await _abrir(tester, _repo(errorResumen: Exception('red')));
      expect(find.text('—'), findsNWidgets(2));
      expect(
        find.text(
          'No pudimos cargar el resumen. Desliza hacia abajo para reintentar.',
        ),
        findsOneWidget,
      );
      expect(find.text('Laura Gómez · Rocky'), findsOneWidget);
      _sinFactura();
    });

    testWidgets('a escala de texto 1.3 las columnas se apilan', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(_repo(), textScale: 1.3));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Por cobrar')).dy,
        greaterThan(tester.getTopLeft(find.text('\$ 3.850.000')).dy),
      );
    });
  });

  group('toggle y filtros', () {
    testWidgets('por defecto Cuentas de cobro; Cotizaciones cambia lista, '
        'oculta filtros y el FAB', (tester) async {
      final repo = _repo();
      await _abrir(tester, repo);
      expect(find.text('Nueva cuenta de cobro'), findsOneWidget);
      expect(find.text('Todas'), findsOneWidget);
      expect(find.text('Laura Gómez · Rocky'), findsOneWidget);
      expect(find.text('Julia Paz · Max'), findsNothing);

      await tester.tap(find.text('Cotizaciones'));
      await tester.pumpAndSettle();
      expect(
        repo.llamadas.where(
          (l) => l.metodo == 'cobros' && l.args['tipo'] == TipoCobro.cotizacion,
        ),
        isNotEmpty,
      );
      expect(find.text('Julia Paz · Max'), findsOneWidget);
      expect(find.text('Laura Gómez · Rocky'), findsNothing);
      expect(find.text('Todas'), findsNothing);
      expect(find.text('Pagadas'), findsNothing);
      expect(find.text('Nueva cotización'), findsOneWidget);
      _sinFactura();
    });

    testWidgets('tipoInicial cotizacion preselecciona Cotizaciones', (
      tester,
    ) async {
      await _abrir(tester, _repo(), tipoInicial: TipoCobro.cotizacion);
      expect(find.text('Julia Paz · Max'), findsOneWidget);
      expect(find.text('Nueva cotización'), findsOneWidget);
    });

    testWidgets('el toggle es un grupo de radio "Tipo de documento"', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _abrir(tester, _repo());
      expect(find.bySemanticsLabel('Tipo de documento'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Cuentas de cobro')),
        isSemantics(isInMutuallyExclusiveGroup: true, isChecked: true),
      );
      expect(
        tester.getSemantics(find.text('Cotizaciones')),
        isSemantics(isInMutuallyExclusiveGroup: true, isChecked: false),
      );
      semantics.dispose();
    });

    testWidgets('Pendientes y Pagadas filtran; la anulada solo en Todas', (
      tester,
    ) async {
      await _abrir(tester, _repo());
      expect(find.text('Sara León · Kiwi'), findsOneWidget);

      await tester.tap(find.text('Pendientes (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Laura Gómez · Rocky'), findsOneWidget);
      expect(find.text('Pedro Ruiz · Luna'), findsOneWidget);
      expect(find.text('Marta Díaz · Toby'), findsNothing);
      expect(find.text('Sara León · Kiwi'), findsNothing);

      await tester.tap(find.text('Pagadas'));
      await tester.pumpAndSettle();
      expect(find.text('Marta Díaz · Toby'), findsOneWidget);
      expect(find.text('Laura Gómez · Rocky'), findsNothing);
      expect(find.text('Sara León · Kiwi'), findsNothing);
    });
  });

  group('CobroFila', () {
    testWidgets('nombre, meta, monto y chip; un solo nodo; abre el detalle', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _abrir(tester, _repo());
      expect(find.text('Laura Gómez · Rocky'), findsOneWidget);
      expect(find.text('CC-0012 · 18/08/2026 · Consulta +2'), findsOneWidget);
      expect(find.text('\$ 120.000'), findsOneWidget);
      final fila = find.ancestor(
        of: find.text('Laura Gómez · Rocky'),
        matching: find.byType(CobroFila),
      );
      expect(
        find.descendant(of: fila, matching: find.text('Pendiente')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(
            r'^Cuenta de cobro CC-0012, Laura Gómez, Rocky, 120\.000 '
            r'pesos, Pendiente, 18/08/2026\. Abrir detalle\.$',
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Laura Gómez · Rocky'));
      await tester.pumpAndSettle();
      expect(find.text('DETALLE c1'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('anulada: monto tachado y chip Anulada', (tester) async {
      await _abrir(tester, _repo());
      final fila = find.ancestor(
        of: find.text('Sara León · Kiwi'),
        matching: find.byType(CobroFila),
      );
      expect(
        find.descendant(of: fila, matching: find.text('Anulada')),
        findsOneWidget,
      );
      final monto = tester.widget<Text>(
        find.descendant(of: fila, matching: find.text('\$ 50.000')),
      );
      expect(monto.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('cotización abierta sin chip, con validez o vencimiento', (
      tester,
    ) async {
      await _abrir(tester, _repo(), tipoInicial: TipoCobro.cotizacion);
      expect(
        find.text('COT-0004 · 05/11/2026 · Consulta · Válida hasta 20/11/2026'),
        findsOneWidget,
      );
      expect(
        find.text('COT-0003 · 01/10/2026 · Consulta · Venció el 16/10/2026'),
        findsOneWidget,
      );
      final abierta = find.ancestor(
        of: find.text('Julia Paz · Max'),
        matching: find.byType(CobroFila),
      );
      expect(
        find.descendant(of: abierta, matching: find.byType(EstadoCobroChip)),
        findsNothing,
      );
      expect(find.text('Convertida'), findsOneWidget);
    });
  });

  testWidgets('cada chip lleva icono y texto', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              EstadoCobroChip(EstadoCobro.pagada),
              EstadoCobroChip(EstadoCobro.pendiente),
              EstadoCobroChip(EstadoCobro.anulada),
              EstadoCobroChip(EstadoCobro.convertida),
            ],
          ),
        ),
      ),
    );
    for (final (texto, icono) in [
      ('Pagada', Icons.check_circle_outline),
      ('Pendiente', Icons.schedule),
      ('Anulada', Icons.block),
      ('Convertida', Icons.swap_horiz),
    ]) {
      expect(find.text(texto), findsOneWidget);
      expect(find.byIcon(icono), findsOneWidget);
    }
  });

  group('vacíos, error y tamaño', () {
    testWidgets('sin cuentas de cobro ni cotizaciones', (tester) async {
      await _abrir(tester, _repo(cobros: const []));
      expect(find.text('Aún no tienes cuentas de cobro'), findsOneWidget);
      await tester.tap(find.text('Cotizaciones'));
      await tester.pumpAndSettle();
      expect(find.text('Aún no tienes cotizaciones'), findsOneWidget);
      _sinFactura();
    });

    testWidgets('Pendientes sin ninguna: "Nada por cobrar"', (tester) async {
      await _abrir(tester, _repo(cobros: [_pagada]));
      await tester.tap(find.text('Pendientes (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Nada por cobrar'), findsOneWidget);
      await tester.tap(find.text('Pagadas'));
      await tester.pumpAndSettle();
      expect(find.text('Marta Díaz · Toby'), findsOneWidget);
    });

    testWidgets('solo lectura sin documentos: "Aún no hay cobros"', (
      tester,
    ) async {
      await _abrir(tester, _repo(cobros: const []), plan: planSoloLectura);
      expect(find.text('Aún no hay cobros'), findsOneWidget);
    });

    testWidgets('error de lista con Reintentar', (tester) async {
      final repo = _repo(errorCobros: Exception('red'));
      await _abrir(tester, repo);
      expect(
        find.text('No pudimos cargar los cobros. Intenta de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
      final antes = repo.llamadas.where((l) => l.metodo == 'cobros').length;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(
        repo.llamadas.where((l) => l.metodo == 'cobros').length,
        greaterThan(antes),
      );
      _sinFactura();
    });

    testWidgets('con 50 muestra el pie y el scroll deja 88 abajo', (
      tester,
    ) async {
      final muchos = [
        for (var i = 0; i < 50; i++)
          cobroDePrueba(id: 'x$i', numero: 100 - i, clienteNombre: 'C$i'),
      ];
      await _abrir(tester, _repo(cobros: muchos));
      final lista = tester.widget<ListView>(find.byType(ListView).last);
      expect((lista.padding as EdgeInsets).bottom, 88);
      await tester.scrollUntilVisible(
        find.text('Mostrando las últimas 50.'),
        400,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Mostrando las últimas 50.'), findsOneWidget);
    });

    testWidgets('con menos de 50 no hay pie', (tester) async {
      await _abrir(tester, _repo());
      expect(find.text('Mostrando las últimas 50.'), findsNothing);
    });

    testWidgets('refrescar invalida lista y resumen', (tester) async {
      final repo = _repo();
      await _abrir(tester, repo);
      final antes = repo.llamadas.where((l) => l.metodo == 'resumen').length;
      final antesLista = repo.llamadas
          .where((l) => l.metodo == 'cobros')
          .length;
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(
        repo.llamadas.where((l) => l.metodo == 'cobros').length,
        greaterThan(antesLista),
      );
      expect(
        repo.llamadas.where((l) => l.metodo == 'resumen').length,
        greaterThan(antes),
      );
    });
  });

  group('FAB y barra', () {
    testWidgets('FAB abre /cobros/nuevo con el tipo del toggle', (
      tester,
    ) async {
      await _abrir(tester, _repo());
      await tester.tap(find.text('Nueva cuenta de cobro'));
      await tester.pumpAndSettle();
      expect(find.text('NUEVO cc'), findsOneWidget);
    });

    testWidgets('FAB en Cotizaciones abre ?tipo=cot', (tester) async {
      await _abrir(tester, _repo(), tipoInicial: TipoCobro.cotizacion);
      await tester.tap(find.text('Nueva cotización'));
      await tester.pumpAndSettle();
      expect(find.text('NUEVO cot'), findsOneWidget);
    });

    testWidgets('acción Servicios y precios', (tester) async {
      await _abrir(tester, _repo());
      await tester.tap(find.byTooltip('Servicios y precios'));
      await tester.pumpAndSettle();
      expect(find.text('SERVICIOS'), findsOneWidget);
    });

    testWidgets('solo lectura: candado, semántica bloqueada, hoja sin '
        'navegar; lista, toggle y filtros siguen', (tester) async {
      final semantics = tester.ensureSemantics();
      await _abrir(tester, _repo(), plan: planSoloLectura);
      final fab = find.byType(FloatingActionButton);
      expect(
        find.descendant(of: fab, matching: find.byIcon(Icons.lock_outline)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: fab, matching: find.byIcon(Icons.add)),
        findsNothing,
      );
      expect(
        tester.getSemantics(fab).label,
        'Nueva cuenta de cobro, bloqueado, solo lectura',
      );

      await tester.tap(find.text('Pagadas'));
      await tester.pumpAndSettle();
      expect(find.text('Marta Díaz · Toby'), findsOneWidget);
      await tester.tap(find.text('Cotizaciones'));
      await tester.pumpAndSettle();
      expect(find.text('Julia Paz · Max'), findsOneWidget);

      await tester.tap(find.text('Nueva cotización'));
      await tester.pumpAndSettle();
      expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
      expect(find.textContaining('NUEVO'), findsNothing);
      semantics.dispose();
    });
  });
}
