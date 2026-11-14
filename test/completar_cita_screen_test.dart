import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vetapp/features/appointments/domain/cita_failure.dart';
import 'package:vetapp/features/appointments/domain/entities/cita.dart';
import 'package:vetapp/features/appointments/presentation/providers/citas_providers.dart';
import 'package:vetapp/features/appointments/presentation/screens/completar_cita_screen.dart';
import 'package:vetapp/core/widgets/buttons/app_button.dart';
import 'package:vetapp/features/vaccination/presentation/providers/vacuna_providers.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/billing/domain/entities/cobro.dart';
import 'package:vetapp/features/billing/presentation/providers/cobros_providers.dart';
import 'package:vetapp/features/plan/domain/mi_plan.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_citas.dart';
import 'helpers/fake_cobros.dart';
import 'helpers/fake_plan.dart';
import 'helpers/fake_vacunas.dart';
import 'helpers/router_harness.dart';

/// Falla solo al cambiar el estado (la lectura sigue funcionando).
class _FakeFallaEstado extends FakeCitaRepository {
  _FakeFallaEstado({super.citas});

  @override
  Future<void> cambiarEstado(String citaId, EstadoCita estado) async {
    throw const CitaFailure('boom');
  }
}

Widget _app(
  FakeCitaRepository repo,
  String id, [
  FakeVacunaRepository? vacunas,
  FakeCobrosRepository? cobros,
  MiPlan? plan,
]) => routerHarness(
  initialLocation: '/agenda/$id/completar',
  routes: [
    GoRoute(
      path: '/agenda',
      builder: (_, state) =>
          Scaffold(body: Text('agenda ${state.uri.queryParameters['dia']}')),
      routes: [
        GoRoute(
          path: ':id/completar',
          builder: (_, state) =>
              CompletarCitaScreen(citaId: state.pathParameters['id']!),
          routes: [
            GoRoute(
              path: 'consulta/:mascotaId',
              builder: (_, state) => Scaffold(
                body: Text('consulta ${state.pathParameters['mascotaId']}'),
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/dosis/nueva',
      builder: (_, state) => Scaffold(body: Text('dosis ${state.uri}')),
    ),
    GoRoute(
      path: '/cobros/nuevo',
      builder: (_, state) => Scaffold(body: Text('cobro ${state.uri}')),
    ),
    GoRoute(
      path: '/cobros/:id',
      builder: (_, state) =>
          Scaffold(body: Text('detalle ${state.pathParameters['id']}')),
    ),
  ],
  overrides: [
    citaRepositoryProvider.overrideWithValue(repo),
    vacunaRepositoryProvider.overrideWithValue(
      vacunas ?? FakeVacunaRepository(),
    ),
    cobrosRepositoryProvider.overrideWithValue(
      cobros ?? FakeCobrosRepository(),
    ),
    ...planOverrides(plan: plan ?? planBeta),
    authProfileProvider.overrideWith(
      () => FakeAuthProfileNotifier(profile: vetProfile),
    ),
  ],
);

Future<void> _abrir(
  WidgetTester tester,
  FakeCitaRepository repo,
  String id, {
  FakeVacunaRepository? vacunas,
}) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(repo, id, vacunas));
  await tester.pumpAndSettle();
}

/// Como [_abrir], con cobros y plan propios.
Future<void> _abrirCon(
  WidgetTester tester,
  FakeCitaRepository repo,
  String id, {
  FakeCobrosRepository? cobros,
  MiPlan? plan,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(repo, id, null, cobros, plan));
  await tester.pumpAndSettle();
}

AppButton _boton(WidgetTester tester, String label) =>
    tester.widget<AppButton>(find.widgetWithText(AppButton, label));

void main() {
  for (final estado in [EstadoCita.cancelada, EstadoCita.noAsistio]) {
    testWidgets('una cita ${estado.name} no se puede completar', (
      tester,
    ) async {
      final repo = FakeCitaRepository(
        citas: [citaRockyLunaHoy.copyWith(estado: estado)],
      );
      await _abrir(tester, repo, 'cita-2');

      expect(find.text('Esta cita ya no se puede completar.'), findsOneWidget);
      expect(find.text('Finalizar cita'), findsNothing);
      expect(find.text('Completar sin consulta'), findsNothing);
      expect(find.text('Registrar consulta'), findsNothing);
      expect(repo.estadosCambiados, isEmpty);
    });
  }

  testWidgets('lista cada mascota como Pendiente con Registrar y Omitir', (
    tester,
  ) async {
    await _abrir(
      tester,
      FakeCitaRepository(citas: [citaRockyLunaHoy]),
      'cita-2',
    );

    expect(find.text('Completar cita'), findsOneWidget);
    expect(find.text('¿Registrar la consulta?'), findsOneWidget);
    expect(
      find.text('Puedes registrarla ahora o completar la cita sin consulta.'),
      findsOneWidget,
    );
    // Nombre en la fila de la mascota y en la tarjeta de dosis (Vacunación).
    expect(find.text('Rocky'), findsNWidgets(2));
    expect(find.text('Luna'), findsNWidgets(2));
    expect(find.text('Pendiente'), findsNWidgets(2));
    expect(find.text('Registrar consulta'), findsNWidgets(2));
    expect(find.text('Omitir'), findsNWidgets(2));
    expect(_boton(tester, 'Finalizar cita').onPressed, isNull);
    expect(find.text('Completar sin consulta'), findsOneWidget);
  });

  testWidgets(
    'Registrar consulta navega a la ruta hija y al volver con la consulta '
    'la tarjeta pasa a Consulta registrada',
    (tester) async {
      final repo = FakeCitaRepository(citas: [citaRockyLunaHoy]);
      await _abrir(tester, repo, 'cita-2');

      await tester.tap(
        find.widgetWithText(AppButton, 'Registrar consulta').first,
      );
      await tester.pumpAndSettle();
      expect(find.text('consulta m-rocky'), findsOneWidget);

      // La consulta se guardó: la cita se relee con Rocky registrado.
      repo.citas[0] = citaRockyLunaHoy.copyWith(
        mascotasConConsulta: {'m-rocky'},
      );
      final container = ProviderScope.containerOf(
        tester.element(find.text('consulta m-rocky')),
      );
      container.invalidate(citaProvider('cita-2'));
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();

      expect(find.text('Consulta registrada'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.text('Registrar consulta'), findsOneWidget);
      expect(find.text('Pendiente'), findsOneWidget);
    },
  );

  testWidgets(
    'Omitir habilita Finalizar, que completa, navega al día y permite '
    'Deshacer sin tocar consultas',
    (tester) async {
      final repo = FakeCitaRepository(citas: [citaRockyLunaHoy]);
      await _abrir(tester, repo, 'cita-2');

      // Rocky registrado, Luna omitida.
      repo.citas[0] = citaRockyLunaHoy.copyWith(
        mascotasConConsulta: {'m-rocky'},
      );
      ProviderScope.containerOf(
        tester.element(find.text('Rocky').first),
      ).invalidate(citaProvider('cita-2'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Omitir'));
      await tester.pumpAndSettle();
      expect(find.text('Omitida'), findsOneWidget);
      expect(_boton(tester, 'Finalizar cita').onPressed, isNotNull);
      expect(find.text('Completar sin consulta'), findsNothing);

      await tester.tap(find.text('Finalizar cita'));
      await tester.pumpAndSettle();

      expect(repo.estadosCambiados.single, (
        citaId: 'cita-2',
        estado: EstadoCita.completada,
      ));
      expect(find.text('agenda 2026-09-30'), findsOneWidget);
      expect(find.text('Cita completada'), findsOneWidget);

      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();
      expect(repo.estadosCambiados.last, (
        citaId: 'cita-2',
        estado: EstadoCita.confirmada,
      ));
      expect(repo.estadosCambiados, hasLength(2));
    },
  );

  testWidgets('Completar sin consulta completa de inmediato, sin diálogo', (
    tester,
  ) async {
    final repo = FakeCitaRepository(citas: [citaRockyLunaHoy]);
    await _abrir(tester, repo, 'cita-2');

    await tester.tap(find.text('Completar sin consulta'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(repo.estadosCambiados.single.estado, EstadoCita.completada);
    expect(find.text('agenda 2026-09-30'), findsOneWidget);
    expect(find.text('Cita completada'), findsOneWidget);
  });

  testWidgets('si falla cambiarEstado muestra el error y permanece', (
    tester,
  ) async {
    await _abrir(tester, _FakeFallaEstado(citas: [citaLunaHoy]), 'cita-1');

    await tester.tap(find.text('Completar sin consulta'));
    await tester.pumpAndSettle();

    expect(
      find.text('No pudimos completar la cita. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(find.text('¿Registrar la consulta?'), findsOneWidget);
  });

  testWidgets(
    'cita de una sola mascota usa la misma pantalla con una tarjeta',
    (tester) async {
      await _abrir(tester, FakeCitaRepository(citas: [citaLunaHoy]), 'cita-1');

      expect(find.text('Luna'), findsOneWidget);
      expect(find.text('Registrar consulta'), findsOneWidget);
      expect(find.text('Omitir'), findsOneWidget);
    },
  );

  group('Registrar dosis aplicada (D-05b, D-22)', () {
    testWidgets('Vacunación ofrece la dosis y empuja /dosis/nueva', (
      tester,
    ) async {
      await _abrir(
        tester,
        FakeCitaRepository(citas: [citaRockyLunaHoy]),
        'cita-2',
      );

      expect(find.text('Registrar dosis aplicada'), findsNWidgets(2));
      expect(find.byIcon(Icons.vaccines_outlined), findsNWidgets(2));
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Registrar dosis aplicada, Luna',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Registrar dosis aplicada').last);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'dosis /dosis/nueva?mascotaId=m-luna&citaId=cita-2'
          '&categoria=vacunacion',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Desparasitación usa categoria=desparasitacion', (
      tester,
    ) async {
      await _abrir(
        tester,
        FakeCitaRepository(
          citas: [citaLunaHoy.copyWith(motivo: 'Desparasitación')],
        ),
        'cita-1',
      );

      await tester.tap(find.text('Registrar dosis aplicada'));
      await tester.pumpAndSettle();
      expect(find.textContaining('categoria=desparasitacion'), findsOneWidget);
    });

    testWidgets('otros motivos no muestran la oferta', (tester) async {
      await _abrir(
        tester,
        FakeCitaRepository(
          citas: [citaLunaHoy.copyWith(motivo: 'Consulta general')],
        ),
        'cita-1',
      );

      expect(find.text('Registrar dosis aplicada'), findsNothing);
      expect(find.text('Registrar consulta'), findsOneWidget);
    });

    testWidgets('dosis ya registrada reemplaza la oferta', (tester) async {
      await _abrir(
        tester,
        FakeCitaRepository(citas: [citaRockyLunaHoy]),
        'cita-2',
        vacunas: FakeVacunaRepository(
          dosisDeCitaData: const [
            (mascotaId: 'm-luna', biologicoNombre: 'Antirrábica'),
          ],
        ),
      );

      expect(find.text('Dosis registrada: Antirrábica'), findsOneWidget);
      expect(find.text('Registrar dosis aplicada'), findsOneWidget);
      expect(find.text('Registrar consulta'), findsNWidgets(2));
      expect(find.text('Omitir'), findsNWidgets(2));
    });
  });

  group('Finalizar y cobrar (D-05, D-19)', () {
    /// Omite las mascotas pendientes: Finalizar queda habilitado.
    Future<void> omitirTodo(WidgetTester tester) async {
      while (find.text('Omitir').evaluate().isNotEmpty) {
        await tester.tap(find.text('Omitir').first);
        await tester.pumpAndSettle();
      }
    }

    final completadaLuna = citaLunaHoy.copyWith(
      estado: EstadoCita.completada,
      mascotasConConsulta: {'m-luna'},
    );

    testWidgets('outline con recibo, 8px bajo Finalizar cita y misma regla', (
      tester,
    ) async {
      await _abrirCon(
        tester,
        FakeCitaRepository(citas: [citaLunaHoy]),
        'cita-1',
      );

      final cobrar = _boton(tester, 'Finalizar y cobrar');
      expect(cobrar.variant, AppButtonVariant.outline);
      expect(cobrar.icon, Icons.receipt_long_outlined);
      expect(cobrar.onPressed, isNull); // Luna pendiente
      expect(_boton(tester, 'Finalizar cita').onPressed, isNull);
      final yFinalizar = tester
          .getBottomLeft(find.widgetWithText(AppButton, 'Finalizar cita'))
          .dy;
      final yCobrar = tester
          .getTopLeft(find.widgetWithText(AppButton, 'Finalizar y cobrar'))
          .dy;
      expect(yCobrar - yFinalizar, 8);

      await omitirTodo(tester);
      expect(_boton(tester, 'Finalizar y cobrar').onPressed, isNotNull);
      expect(_boton(tester, 'Finalizar cita').onPressed, isNotNull);
    });

    testWidgets(
      'completa con snackbar y Deshacer y abre la CC con cliente, cita y '
      'la única mascota',
      (tester) async {
        final repo = FakeCitaRepository(citas: [citaLunaHoy]);
        await _abrirCon(tester, repo, 'cita-1');
        await omitirTodo(tester);

        await tester.tap(find.text('Finalizar y cobrar'));
        await tester.pumpAndSettle();

        expect(repo.estadosCambiados.single, (
          citaId: 'cita-1',
          estado: EstadoCita.completada,
        ));
        expect(
          find.text(
            'cobro /cobros/nuevo?tipo=cc&clienteId=c-maria&mascotaId=m-luna'
            '&citaId=cita-1',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('agenda'), findsNothing);
        expect(find.text('Cita completada'), findsOneWidget);
        expect(find.text('Deshacer'), findsOneWidget);
      },
    );

    testWidgets('con varias mascotas no prellena la mascota', (tester) async {
      final repo = FakeCitaRepository(
        citas: [
          citaRockyLunaHoy.copyWith(mascotasConConsulta: {'m-rocky', 'm-luna'}),
        ],
      );
      await _abrirCon(tester, repo, 'cita-2');

      await tester.tap(find.text('Finalizar y cobrar'));
      await tester.pumpAndSettle();

      expect(repo.estadosCambiados.single.estado, EstadoCita.completada);
      expect(
        find.text(
          'cobro /cobros/nuevo?tipo=cc&clienteId=c-maria&citaId=cita-2',
        ),
        findsOneWidget,
      );
    });

    testWidgets('si falla completar no navega', (tester) async {
      await _abrirCon(tester, _FakeFallaEstado(citas: [citaLunaHoy]), 'cita-1');
      await omitirTodo(tester);

      await tester.tap(find.text('Finalizar y cobrar'));
      await tester.pumpAndSettle();

      expect(
        find.text('No pudimos completar la cita. Intenta de nuevo.'),
        findsOneWidget,
      );
      expect(find.textContaining('cobro /cobros'), findsNothing);
      expect(find.text('¿Registrar la consulta?'), findsOneWidget);
    });

    testWidgets('cita ya completada sin CC abre el cobro sin recompletar', (
      tester,
    ) async {
      final repo = FakeCitaRepository(citas: [completadaLuna]);
      await _abrirCon(tester, repo, 'cita-1');

      await tester.tap(find.text('Finalizar y cobrar'));
      await tester.pumpAndSettle();

      expect(repo.estadosCambiados, isEmpty);
      expect(
        find.text(
          'cobro /cobros/nuevo?tipo=cc&clienteId=c-maria&mascotaId=m-luna'
          '&citaId=cita-1',
        ),
        findsOneWidget,
      );
    });

    testWidgets('cita completada con CC muestra Cobrada en su lugar', (
      tester,
    ) async {
      final cobros = FakeCobrosRepository(
        vinculado: const CobroVinculado(
          id: 'cc-12',
          numero: 12,
          estado: EstadoCobro.pagada,
        ),
      );
      await _abrirCon(
        tester,
        FakeCitaRepository(citas: [completadaLuna]),
        'cita-1',
        cobros: cobros,
      );

      expect(find.text('Finalizar y cobrar'), findsNothing);
      expect(find.text('Cobrada: CC-0012'), findsOneWidget);
      expect(find.text('Pagada'), findsOneWidget);
      expect(find.text('Finalizar cita'), findsOneWidget);
      expect(
        cobros.llamadas.firstWhere((l) => l.metodo == 'cobroVinculado').args,
        {'citaId': 'cita-1', 'consultaId': null},
      );

      await tester.tap(find.text('Cobrada: CC-0012'));
      await tester.pumpAndSettle();
      expect(find.text('detalle cc-12'), findsOneWidget);
    });

    testWidgets('si falla leer el cobro muestra Finalizar y cobrar', (
      tester,
    ) async {
      await _abrirCon(
        tester,
        FakeCitaRepository(citas: [citaLunaHoy]),
        'cita-1',
        cobros: FakeCobrosRepository(error: Exception('boom')),
      );

      expect(find.text('Finalizar y cobrar'), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
    });

    testWidgets(
      'solo lectura: candado y hoja, sin completar ni navegar; Finalizar '
      'cita igual que antes',
      (tester) async {
        final repo = FakeCitaRepository(citas: [citaLunaHoy]);
        await _abrirCon(tester, repo, 'cita-1', plan: planSoloLectura);
        await omitirTodo(tester);

        final cobrar = find.widgetWithText(AppButton, 'Finalizar y cobrar');
        expect(
          find.descendant(
            of: cobrar,
            matching: find.byIcon(Icons.lock_outline),
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Finalizar y cobrar, bloqueado, solo lectura'),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.widgetWithText(AppButton, 'Finalizar cita'),
            matching: find.byIcon(Icons.lock_outline),
          ),
          findsNothing,
        );

        await tester.tap(cobrar);
        await tester.pumpAndSettle();
        expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
        expect(repo.estadosCambiados, isEmpty);
        expect(find.textContaining('cobro /cobros'), findsNothing);
      },
    );
  });
}
