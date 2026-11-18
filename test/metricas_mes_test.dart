import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/core/theme/app_colors.dart';
import 'package:vetapp/core/theme/app_theme.dart';
import 'package:vetapp/features/home/domain/inicio_failure.dart';
import 'package:vetapp/features/home/domain/resumen_inicio.dart';
import 'package:vetapp/features/home/presentation/widgets/inicio_encabezado.dart';
import 'package:vetapp/features/home/presentation/widgets/metricas_mes.dart';

import 'helpers/fake_inicio.dart';
import 'helpers/router_harness.dart';

Widget _metricas({
  FakeInicioRepository? inicio,
  ThemeData? tema,
  double? escala,
}) {
  return routerHarness(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) {
          Widget cuerpo = const Scaffold(
            body: SingleChildScrollView(child: MetricasMes()),
          );
          if (escala != null) {
            cuerpo = MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(escala)),
              child: cuerpo,
            );
          }
          return tema == null ? cuerpo : Theme(data: tema, child: cuerpo);
        },
      ),
      GoRoute(
        path: '/cobros',
        builder: (_, _) => const Text('PANTALLA COBROS'),
      ),
      GoRoute(
        path: '/pacientes',
        builder: (_, _) => const Text('PANTALLA PACIENTES'),
      ),
    ],
    overrides: inicioOverrides(inicio: inicio),
  );
}

Widget _encabezado({String? nombre, String? clinica}) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: InicioEncabezado(nombre: nombre, clinica: clinica),
  ),
);

FakeInicioRepository _conDatos({
  int consultas = 42,
  int ingresos = 3849999,
  int nuevos = 7,
}) => FakeInicioRepository(
  resumenData: ResumenInicio(
    consultasMes: consultas,
    ingresosMes: ingresos,
    pacientesNuevos: nuevos,
  ),
);

void _ancho(WidgetTester tester, double ancho) {
  tester.view.physicalSize = Size(ancho, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('InicioEncabezado', () {
    testWidgets('muestra saludo, nombre y clínica en un solo encabezado', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _encabezado(nombre: 'Ana Ramírez', clinica: 'Clínica Patitas'),
      );

      expect(find.text('Hola,'), findsOneWidget);
      expect(find.text('Ana Ramírez'), findsOneWidget);
      expect(find.text('Clínica Patitas'), findsOneWidget);
      expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
      expect(
        find.bySemanticsLabel('Hola, Ana Ramírez. Clínica Patitas'),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Hola, Ana Ramírez. Clínica Patitas'),
        ),
        containsSemantics(isHeader: true),
      );
      semantics.dispose();
    });

    testWidgets('sin clínica muestra el texto de respaldo', (tester) async {
      await tester.pumpWidget(_encabezado(nombre: 'Ana Ramírez'));
      expect(find.text('Sin clínica asignada'), findsOneWidget);
    });

    testWidgets('cargando muestra Hola, y dos barras de esqueleto', (
      tester,
    ) async {
      await tester.pumpWidget(_encabezado());
      expect(find.text('Hola,'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('encabezado-esqueleto-nombre')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('encabezado-esqueleto-clinica')),
        findsOneWidget,
      );
    });
  });

  group('MetricasMes', () {
    testWidgets('muestra las 3 cifras con su formato', (tester) async {
      await tester.pumpWidget(_metricas(inicio: _conDatos()));
      await tester.pumpAndSettle();

      expect(find.text('Consultas'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('Ingresos'), findsOneWidget);
      expect(find.text('\$ 3,8 M'), findsOneWidget);
      expect(find.text('Pacientes nuevos'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('agrupa miles y muestra ceros como datos', (tester) async {
      await tester.pumpWidget(
        _metricas(inicio: _conDatos(consultas: 1250, ingresos: 0, nuevos: 0)),
      );
      await tester.pumpAndSettle();
      expect(find.text('1.250'), findsOneWidget);
      expect(find.text('\$ 0'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('semántica: Consultas no es botón; Ingresos y Pacientes sí', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_metricas(inicio: _conDatos()));
      await tester.pumpAndSettle();

      final consultas = find.bySemanticsLabel('Consultas del mes: 42');
      expect(consultas, findsOneWidget);
      expect(
        tester.getSemantics(consultas),
        containsSemantics(isButton: false, hasTapAction: false),
      );
      final ingresos = find.bySemanticsLabel(
        'Ingresos del mes: \$ 3.849.999. Abre Cobros',
      );
      expect(ingresos, findsOneWidget);
      expect(
        tester.getSemantics(ingresos),
        containsSemantics(isButton: true, hasTapAction: true),
      );
      final nuevos = find.bySemanticsLabel(
        'Pacientes nuevos del mes: 7. Abre Pacientes',
      );
      expect(nuevos, findsOneWidget);
      expect(
        tester.getSemantics(nuevos),
        containsSemantics(isButton: true, hasTapAction: true),
      );
      semantics.dispose();
    });

    testWidgets('Ingresos abre /cobros', (tester) async {
      await tester.pumpWidget(_metricas(inicio: _conDatos()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ingresos'));
      await tester.pumpAndSettle();
      expect(find.text('PANTALLA COBROS'), findsOneWidget);
    });

    testWidgets('Pacientes nuevos va a /pacientes', (tester) async {
      await tester.pumpWidget(_metricas(inicio: _conDatos()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pacientes nuevos'));
      await tester.pumpAndSettle();
      expect(find.text('PANTALLA PACIENTES'), findsOneWidget);
    });

    testWidgets('Consultas no navega, sin chevron; las tocables miden >= 48', (
      tester,
    ) async {
      await tester.pumpWidget(_metricas(inicio: _conDatos()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Consultas'));
      await tester.pumpAndSettle();
      expect(find.text('Consultas'), findsOneWidget);
      expect(find.text('PANTALLA COBROS'), findsNothing);
      expect(find.text('PANTALLA PACIENTES'), findsNothing);

      expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
      final tarjetas = find.byType(MetricaTarjeta);
      expect(tarjetas, findsNWidgets(3));
      for (final kicker in ['Ingresos', 'Pacientes nuevos']) {
        final t = find.ancestor(
          of: find.text(kicker),
          matching: find.byType(MetricaTarjeta),
        );
        final size = tester.getSize(t);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      final consultas = tester.widget<MetricaTarjeta>(
        find.ancestor(
          of: find.text('Consultas'),
          matching: find.byType(MetricaTarjeta),
        ),
      );
      expect(consultas.onTap, isNull);
    });

    testWidgets('cargando: kickers reales, esqueletos y toques inactivos', (
      tester,
    ) async {
      final bloqueo = Completer<void>();
      final repo = _conDatos()..bloqueo = bloqueo;
      await tester.pumpWidget(_metricas(inicio: repo));
      await tester.pump();

      expect(find.text('Consultas'), findsOneWidget);
      expect(find.text('Ingresos'), findsOneWidget);
      expect(find.text('Pacientes nuevos'), findsOneWidget);
      expect(find.byKey(const ValueKey('metrica-esqueleto')), findsNWidgets(3));
      expect(find.text('42'), findsNothing);

      await tester.tap(find.text('Ingresos'));
      await tester.pump();
      expect(find.text('PANTALLA COBROS'), findsNothing);

      bloqueo.complete();
      await tester.pumpAndSettle();
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('error: un solo BloqueError y Reintentar relee el resumen', (
      tester,
    ) async {
      final repo = FakeInicioRepository(
        error: const InicioFailure('No pudimos cargar el resumen del mes.'),
      );
      await tester.pumpWidget(_metricas(inicio: repo));
      await tester.pumpAndSettle();

      expect(
        find.text('No pudimos cargar el resumen del mes.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Consultas'), findsNothing);
      expect(repo.llamadas, ['resumen']);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(repo.llamadas, ['resumen', 'resumen']);
    });

    testWidgets('sin conexión: texto offline e ícono wifi_off', (tester) async {
      final repo = FakeInicioRepository(
        error: const InicioFailure(
          'Sin conexión. Inténtalo de nuevo cuando tengas señal.',
          sinConexion: true,
        ),
      );
      await tester.pumpWidget(_metricas(inicio: repo));
      await tester.pumpAndSettle();

      expect(
        find.text('Sin conexión. Inténtalo de nuevo cuando tengas señal.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    });

    testWidgets('un error desconocido muestra el mensaje genérico', (
      tester,
    ) async {
      final repo = FakeInicioRepository(error: Exception('detalle interno'));
      await tester.pumpWidget(_metricas(inicio: repo));
      await tester.pumpAndSettle();

      expect(
        find.text('No pudimos cargar el resumen del mes.'),
        findsOneWidget,
      );
      expect(find.textContaining('detalle interno'), findsNothing);
    });

    double topDe(WidgetTester tester, String kicker) => tester
        .getTopLeft(
          find.ancestor(
            of: find.text(kicker),
            matching: find.byType(MetricaTarjeta),
          ),
        )
        .dy;

    testWidgets('a 360 y escala 1.0 las 3 tarjetas comparten fila', (
      tester,
    ) async {
      _ancho(tester, 360);
      await tester.pumpWidget(_metricas(inicio: _conDatos()));
      await tester.pumpAndSettle();
      final a = topDe(tester, 'Consultas');
      expect(topDe(tester, 'Ingresos'), a);
      expect(topDe(tester, 'Pacientes nuevos'), a);
    });

    testWidgets('a 300 de ancho se apilan', (tester) async {
      _ancho(tester, 300);
      await tester.pumpWidget(_metricas(inicio: _conDatos()));
      await tester.pumpAndSettle();
      final a = topDe(tester, 'Consultas');
      final b = topDe(tester, 'Ingresos');
      final c = topDe(tester, 'Pacientes nuevos');
      expect(b, greaterThan(a));
      expect(c, greaterThan(b));
    });

    testWidgets('con escala de texto 1.5 se apilan', (tester) async {
      _ancho(tester, 360);
      await tester.pumpWidget(_metricas(inicio: _conDatos(), escala: 1.5));
      await tester.pumpAndSettle();
      final a = topDe(tester, 'Consultas');
      final b = topDe(tester, 'Ingresos');
      final c = topDe(tester, 'Pacientes nuevos');
      expect(b, greaterThan(a));
      expect(c, greaterThan(b));
    });

    testWidgets('cifra en primaryText (claro) y primaryHover (oscuro)', (
      tester,
    ) async {
      await tester.pumpWidget(_metricas(inicio: _conDatos()));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('42')).style?.color,
        AppColors.primaryText,
      );

      await tester.pumpWidget(
        _metricas(inicio: _conDatos(), tema: AppTheme.dark),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('42')).style?.color,
        AppColors.primaryHover,
      );
    });
  });
}
