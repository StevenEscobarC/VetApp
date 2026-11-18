import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/core/theme/app_colors.dart';
import 'package:vetapp/core/theme/app_theme.dart';
import 'package:vetapp/core/utils/zona_bogota.dart';
import 'package:vetapp/core/widgets/buttons/app_button.dart';
import 'package:vetapp/core/widgets/status/vet_avatar.dart';
import 'package:vetapp/features/appointments/domain/entities/cita.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/home/presentation/widgets/bloque_error.dart';
import 'package:vetapp/features/home/presentation/widgets/proximas_citas.dart';
import 'package:vetapp/features/plan/domain/mi_plan.dart';
import 'package:vetapp/features/team/domain/miembro.dart';
import 'package:vetapp/features/team/presentation/providers/team_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_citas.dart';
import 'helpers/fake_inicio.dart';
import 'helpers/fake_plan.dart';
import 'helpers/fake_team.dart';
import 'helpers/router_harness.dart';

/// Lunes 16/11/2026 9:00 a. m. Bogotá.
final _ahora = DateTime.utc(2026, 11, 16, 14);

const _luna = MascotaDeCita(id: 'm-luna', nombre: 'Luna', especie: 'perro');

Cita _cita(
  String id,
  DateTime fecha, {
  EstadoCita estado = EstadoCita.pendiente,
  String motivo = 'Control',
  String vet = 'vet-1',
}) => Cita(
  id: id,
  clinicaId: 'cli-1',
  clienteId: 'c-maria',
  veterinarioId: vet,
  fechaHora: fecha,
  duracionMin: 30,
  modalidad: ModalidadCita.consultorio,
  motivo: motivo,
  estado: estado,
  clienteNombre: 'María Pérez',
  mascotas: const [_luna],
);

final _cuatro = [
  _cita('lun-1', deBogota(2026, 11, 16, 10), estado: EstadoCita.confirmada),
  _cita('lun-2', deBogota(2026, 11, 16, 11, 30), vet: 'vet-2'),
  _cita('mar-1', deBogota(2026, 11, 17, 9), vet: 'vet-3'),
  _cita('jue-1', deBogota(2026, 11, 19, 15), motivo: ''),
];

/// Retiene [proximas] hasta que [suelta] se complete (estado de carga).
class _CitasRetenidas extends FakeCitaRepository {
  _CitasRetenidas() : super();
  final suelta = Completer<void>();

  @override
  Future<List<Cita>> proximas({
    required DateTime desdeUtc,
    int limite = 5,
  }) async {
    await suelta.future;
    return super.proximas(desdeUtc: desdeUtc, limite: limite);
  }
}

Widget _app({
  FakeCitaRepository? citas,
  bool multiVet = false,
  List<Miembro> activos = const [],
  MiPlan? plan,
  ThemeData? tema,
}) {
  final routes = [
    GoRoute(
      path: '/',
      builder: (_, _) => Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [ProximasCitas()],
        ),
      ),
    ),
    GoRoute(path: '/agenda', builder: (_, _) => const Text('PANTALLA AGENDA')),
    GoRoute(
      path: '/agenda/:id',
      builder: (_, state) => Text('DETALLE ${state.pathParameters['id']}'),
    ),
    GoRoute(
      path: '/citas/nueva',
      builder: (_, _) => const Text('PANTALLA NUEVA CITA'),
    ),
  ];
  final overrides = [
    ...planOverrides(plan: plan),
    ...inicioOverrides(citas: citas ?? FakeCitaRepository(citas: _cuatro)),
    authProfileProvider.overrideWith(
      () => FakeAuthProfileNotifier(profile: vetProfile),
    ),
    clockProvider.overrideWithValue(() => _ahora),
    esClinicaMultiVetProvider.overrideWithValue(multiVet),
    miembrosActivosProvider.overrideWithValue(activos),
    indicesColorVetProvider.overrideWithValue(const {
      'vet-1': 0,
      'vet-2': 1,
      'vet-3': 2,
    }),
  ];
  if (tema == null) {
    return routerHarness(
      initialLocation: '/',
      routes: routes,
      overrides: overrides,
    );
  }
  return ProviderScope(
    retry: (retryCount, error) => null,
    overrides: overrides,
    child: MaterialApp.router(
      theme: tema,
      routerConfig: GoRouter(initialLocation: '/', routes: routes),
    ),
  );
}

double _y(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

void main() {
  testWidgets('separadores por día de Bogotá, cada uno antes de sus filas', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final hoy = find.text('Hoy, lun 16/11');
    final manana = find.text('Mañana, mar 17/11');
    final jueves = find.text('jue 19/11');
    expect(hoy, findsOneWidget);
    expect(manana, findsOneWidget);
    expect(jueves, findsOneWidget);
    for (final s in [hoy, manana, jueves]) {
      expect(tester.getSemantics(s), isSemantics(isHeader: true));
    }

    final filas = find.byType(ProximaCitaFila);
    expect(filas, findsNWidgets(4));
    expect(_y(tester, hoy), lessThan(_y(tester, filas.at(0))));
    expect(_y(tester, filas.at(1)), lessThan(_y(tester, manana)));
    expect(_y(tester, manana), lessThan(_y(tester, filas.at(2))));
    expect(_y(tester, filas.at(2)), lessThan(_y(tester, jueves)));
    expect(_y(tester, jueves), lessThan(_y(tester, filas.at(3))));
    expect(_y(tester, find.text('Próximas citas')), lessThan(_y(tester, hoy)));
    expect(
      tester.getSemantics(find.text('Próximas citas')),
      isSemantics(isHeader: true),
    );
    semantics.dispose();
  });

  testWidgets('fila: título, meta, chip, alto >= 72 y semántica', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Luna · Control'), findsNWidgets(3));
    // Motivo vacío: solo las mascotas, sin " · " colgando.
    expect(find.text('Luna'), findsOneWidget);
    expect(find.text('10:00 a. m. · María Pérez'), findsOneWidget);
    expect(find.text('11:30 a. m. · María Pérez'), findsOneWidget);
    expect(find.text('Confirmada'), findsOneWidget);
    expect(find.text('Pendiente'), findsNWidgets(3));

    final fila = find.byType(ProximaCitaFila).first;
    expect(tester.getSize(fila).height, greaterThanOrEqualTo(72));
    final label = tester.getSemantics(fila).label;
    expect(label, startsWith('10:00 a. m.'));
    expect(label, contains('Luna'));
    expect(label, contains('Control'));
    expect(label, contains('María Pérez'));
    expect(label, contains('Confirmada'));
    expect(label, endsWith('Abre el detalle de la cita'));
    semantics.dispose();
  });

  testWidgets('tocar una fila va a /agenda/{id} con go (sin apilar)', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ProximaCitaFila).at(2));
    await tester.pumpAndSettle();
    expect(find.text('DETALLE mar-1'), findsOneWidget);
    // go reemplaza la pila: no hay a dónde volver.
    expect(
      GoRouter.of(tester.element(find.text('DETALLE mar-1'))).canPop(),
      isFalse,
    );
  });

  testWidgets('Ver agenda va a /agenda con go', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    final ver = find.widgetWithText(AppButton, 'Ver agenda');
    expect(ver, findsOneWidget);
    expect(
      find.descendant(of: ver, matching: find.byIcon(Icons.chevron_right)),
      findsOneWidget,
    );
    await tester.tap(ver);
    await tester.pumpAndSettle();
    expect(find.text('PANTALLA AGENDA'), findsOneWidget);
    expect(
      GoRouter.of(tester.element(find.text('PANTALLA AGENDA'))).canPop(),
      isFalse,
    );
  });

  group('marca de veterinario (D-07)', () {
    testWidgets('multi-vet: VetAvatar de 40 en cada fila, retirado sin borde '
        'de color', (tester) async {
      await tester.pumpWidget(
        _app(multiVet: true, activos: [miembroAna, miembroLuis]),
      );
      await tester.pumpAndSettle();

      final avatares = find.byType(VetAvatar);
      expect(avatares, findsNWidgets(4));
      for (final a in tester.widgetList<VetAvatar>(avatares)) {
        expect(a.size, 40);
      }
      final delRetirado = tester.widget<VetAvatar>(
        find.descendant(
          of: find.byType(ProximaCitaFila).at(2),
          matching: find.byType(VetAvatar),
        ),
      );
      expect(delRetirado.retirado, isTrue);
      expect(delRetirado.indice, 2);
      final deAna = tester.widget<VetAvatar>(avatares.first);
      expect(deAna.retirado, isFalse);
      expect(find.byIcon(Icons.pets_outlined), findsNothing);
    });

    testWidgets('un solo vet: círculo con huella y sin VetAvatar', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byType(VetAvatar), findsNothing);
      expect(find.byIcon(Icons.pets_outlined), findsNWidgets(4));
      expect(
        tester.widget<Icon>(find.byIcon(Icons.pets_outlined).first).color,
        AppColors.primaryStrong,
      );
    });

    testWidgets('en oscuro la huella no usa una constante solo-clara', (
      tester,
    ) async {
      await tester.pumpWidget(_app(tema: AppTheme.dark));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.pets_outlined).first).color,
        isNot(AppColors.primaryStrong),
      );
    });
  });

  group('estados (D-08, D-14)', () {
    testWidgets('vacío: mensaje y Agendar cita que abre /citas/nueva', (
      tester,
    ) async {
      await tester.pumpWidget(_app(citas: FakeCitaRepository()));
      await tester.pumpAndSettle();

      expect(find.text('No tienes citas próximas.'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Ver agenda'), findsOneWidget);
      final agendar = find.widgetWithText(AppButton, 'Agendar cita');
      expect(agendar, findsOneWidget);
      expect(
        tester.widget<AppButton>(agendar).variant,
        AppButtonVariant.outline,
      );
      expect(
        find.descendant(of: agendar, matching: find.byIcon(Icons.add)),
        findsOneWidget,
      );
      await tester.tap(agendar);
      await tester.pumpAndSettle();
      expect(find.text('PANTALLA NUEVA CITA'), findsOneWidget);
    });

    testWidgets('vacío en solo lectura: candado y hoja de solo lectura', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(citas: FakeCitaRepository(), plan: planSoloLectura),
      );
      await tester.pumpAndSettle();
      final agendar = find.widgetWithText(AppButton, 'Agendar cita');
      expect(
        find.descendant(of: agendar, matching: find.byIcon(Icons.lock_outline)),
        findsOneWidget,
      );
      await tester.tap(agendar);
      await tester.pumpAndSettle();
      expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
      expect(find.text('PANTALLA NUEVA CITA'), findsNothing);
    });

    testWidgets('las filas se abren igual en solo lectura', (tester) async {
      await tester.pumpWidget(_app(plan: planSoloLectura));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ProximaCitaFila).first);
      await tester.pumpAndSettle();
      expect(find.text('DETALLE lun-1'), findsOneWidget);
    });

    testWidgets('cargando: 3 filas esqueleto y Ver agenda visible', (
      tester,
    ) async {
      final citas = _CitasRetenidas();
      await tester.pumpWidget(_app(citas: citas));
      await tester.pump();
      expect(find.byKey(const ValueKey('proxima-esqueleto')), findsNWidgets(3));
      expect(find.widgetWithText(AppButton, 'Ver agenda'), findsOneWidget);
      citas.suelta.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('proxima-esqueleto')), findsNothing);
    });

    testWidgets('error: BloqueError con su texto, Reintentar vuelve a pedir', (
      tester,
    ) async {
      final citas = FakeCitaRepository(error: Exception('boom'));
      await tester.pumpWidget(_app(citas: citas));
      await tester.pumpAndSettle();

      expect(find.byType(BloqueError), findsOneWidget);
      expect(
        find.text('No pudimos cargar las próximas citas.'),
        findsOneWidget,
      );
      expect(find.text('Próximas citas'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Ver agenda'), findsOneWidget);

      final antes = citas.consultasProximas.length;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(citas.consultasProximas.length, greaterThan(antes));
    });

    testWidgets('sin conexión: texto de offline', (tester) async {
      await tester.pumpWidget(
        _app(
          citas: FakeCitaRepository(error: const SocketException('sin red')),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Sin conexión. Inténtalo de nuevo cuando tengas señal.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('nunca dice Factura', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp('[Ff]actur')), findsNothing);
  });
}
