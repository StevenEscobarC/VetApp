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

import 'helpers/fake_citas.dart';
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
  ],
  overrides: [
    citaRepositoryProvider.overrideWithValue(repo),
    vacunaRepositoryProvider.overrideWithValue(
      vacunas ?? FakeVacunaRepository(),
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
    expect(find.text('Rocky'), findsOneWidget);
    expect(find.text('Luna'), findsOneWidget);
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
        tester.element(find.text('Rocky')),
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
}
