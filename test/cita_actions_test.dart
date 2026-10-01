import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/core/utils/zona_bogota.dart';
import 'package:vetapp/features/appointments/domain/cita_failure.dart';
import 'package:vetapp/features/appointments/domain/entities/cita.dart';
import 'package:vetapp/features/appointments/presentation/providers/citas_providers.dart';
import 'package:vetapp/features/appointments/presentation/screens/agenda_screen.dart';

import 'helpers/fake_citas.dart';
import 'helpers/router_harness.dart';

Widget _agenda(FakeCitaRepository repo) => routerHarness(
  initialLocation: '/agenda',
  routes: [
    GoRoute(
      path: '/agenda',
      builder: (_, _) => const AgendaScreen(),
      routes: [
        GoRoute(
          path: ':id',
          builder: (_, state) =>
              Scaffold(body: Text('detalle ${state.pathParameters['id']}')),
          routes: [
            GoRoute(
              path: 'editar',
              builder: (_, state) =>
                  Scaffold(body: Text('editar ${state.pathParameters['id']}')),
            ),
          ],
        ),
      ],
    ),
  ],
  overrides: [
    citaRepositoryProvider.overrideWithValue(repo),
    clockProvider.overrideWithValue(() => deBogota(2026, 9, 30, 9, 35)),
  ],
);

Future<void> _abrir(WidgetTester tester, FakeCitaRepository repo) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_agenda(repo));
  await tester.pumpAndSettle();
}

/// Avanza lo justo para ver el snackbar sin dejar correr su temporizador.
Future<void> _snack(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('CitaActions', () {
    test('cambiarEstado escribe, refresca y suma una revisión', () async {
      final repo = FakeCitaRepository(citas: [citaLunaHoy]);
      final container = ProviderContainer(
        overrides: [citaRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(citaProvider('cita-1'), (_, _) {});
      addTearDown(sub.close);
      await container.read(citaProvider('cita-1').future);
      final antes = container.read(citasRevisionProvider);

      await container
          .read(citaActionsProvider)
          .cambiarEstado('cita-1', EstadoCita.confirmada);

      expect(repo.estadosCambiados, hasLength(1));
      expect(repo.estadosCambiados.single.estado, EstadoCita.confirmada);
      final cita = await container.read(citaProvider('cita-1').future);
      expect(cita.estado, EstadoCita.confirmada);
      expect(container.read(citasRevisionProvider), antes + 1);
    });

    test('marcarRecordatorioEnviado registra y no suma revisión', () async {
      final repo = FakeCitaRepository(citas: [citaLunaHoy]);
      final container = ProviderContainer(
        overrides: [citaRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final t = deBogota(2026, 9, 29, 18, 15);

      await container
          .read(citaActionsProvider)
          .marcarRecordatorioEnviado('cita-1', t);

      expect(repo.recordatorios.single.citaId, 'cita-1');
      expect(repo.recordatorios.single.enviadoAt, t);
      expect(container.read(citasRevisionProvider), 0);
    });
  });

  group('CitaCard acciones', () {
    testWidgets('pendiente: Confirmar y Más acciones; Deshacer restaura', (
      tester,
    ) async {
      final repo = FakeCitaRepository(citas: [citaLunaHoy]);
      await _abrir(tester, repo);

      expect(find.text('Confirmar'), findsOneWidget);
      expect(find.byTooltip('Más acciones'), findsOneWidget);

      await tester.tap(find.text('Confirmar'));
      await _snack(tester);
      expect(repo.estadosCambiados.single.estado, EstadoCita.confirmada);
      expect(find.text('Cita confirmada'), findsOneWidget);

      await tester.tap(find.text('Deshacer'));
      await _snack(tester);
      expect(repo.estadosCambiados.last.estado, EstadoCita.pendiente);
      expect(repo.estadosCambiados.last.citaId, 'cita-1');
    });

    testWidgets('confirmada no muestra Confirmar; terminales sin acciones', (
      tester,
    ) async {
      await _abrir(
        tester,
        FakeCitaRepository(citas: [citaRockyLunaHoy, citaCanceladaHoy]),
      );
      expect(find.text('Confirmar'), findsNothing);
      // Solo la confirmada tiene "Más acciones"; la cancelada no.
      expect(find.byTooltip('Más acciones'), findsOneWidget);
    });

    testWidgets('Más acciones (pendiente): sin "Marcar como pendiente"', (
      tester,
    ) async {
      await _abrir(tester, FakeCitaRepository(citas: [citaLunaHoy]));
      await tester.tap(find.byTooltip('Más acciones'));
      await tester.pumpAndSettle();

      expect(find.text('No asistió'), findsOneWidget);
      expect(find.text('Cancelar cita'), findsOneWidget);
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Marcar como pendiente'), findsNothing);
    });

    testWidgets('confirmada: Marcar como pendiente con Deshacer', (
      tester,
    ) async {
      final repo = FakeCitaRepository(citas: [citaRockyLunaHoy]);
      await _abrir(tester, repo);
      await tester.tap(find.byTooltip('Más acciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marcar como pendiente'));
      await tester.pumpAndSettle();
      await _snack(tester);

      expect(repo.estadosCambiados.single.estado, EstadoCita.pendiente);
      expect(find.text('Cita marcada como pendiente'), findsOneWidget);

      await tester.tap(find.text('Deshacer'));
      await _snack(tester);
      expect(repo.estadosCambiados.last.estado, EstadoCita.confirmada);
    });

    testWidgets('No asistió registra el estado y ofrece Deshacer', (
      tester,
    ) async {
      final repo = FakeCitaRepository(citas: [citaLunaHoy]);
      await _abrir(tester, repo);
      await tester.tap(find.byTooltip('Más acciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No asistió'));
      await tester.pumpAndSettle();
      await _snack(tester);

      expect(repo.estadosCambiados.single.estado, EstadoCita.noAsistio);
      expect(find.text('Marcada como no asistió'), findsOneWidget);
      expect(find.text('Deshacer'), findsOneWidget);
    });

    testWidgets('Cancelar cita pide confirmación; Volver no cambia nada', (
      tester,
    ) async {
      final repo = FakeCitaRepository(citas: [citaLunaHoy]);
      await _abrir(tester, repo);
      await tester.tap(find.byTooltip('Más acciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar cita'));
      await tester.pumpAndSettle();

      expect(find.text('¿Cancelar esta cita?'), findsOneWidget);
      expect(
        find.text(
          'Luna el mié 30/09 a las 10:30 a. m. '
          'La cita quedará como cancelada y no se borra.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect(repo.estadosCambiados, isEmpty);

      await tester.tap(find.byTooltip('Más acciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar cita'));
      await tester.pumpAndSettle();
      // Botón de confirmación del diálogo (el último 'Cancelar cita').
      await tester.tap(find.text('Cancelar cita').last);
      await tester.pumpAndSettle();
      await _snack(tester);

      expect(repo.estadosCambiados.single.estado, EstadoCita.cancelada);
      expect(find.text('Cita cancelada'), findsOneWidget);
      expect(find.text('Deshacer'), findsOneWidget);
    });

    testWidgets('un CitaFailure muestra el mensaje de estado', (tester) async {
      final repo = FakeCitaRepository(citas: [citaLunaHoy]);
      await _abrir(tester, repo);
      // La lectura ya cargó; vaciar el repositorio hace que escribir lance
      // "Esta cita ya no existe." (CitaFailure).
      repo.citas.clear();
      await tester.tap(find.text('Confirmar'));
      await _snack(tester);
      expect(
        find.text('No pudimos cambiar el estado. Intenta de nuevo.'),
        findsOneWidget,
      );
    });

    testWidgets('tocar la tarjeta abre /agenda/{id}', (tester) async {
      await _abrir(tester, FakeCitaRepository(citas: [citaLunaHoy]));
      await tester.tap(find.text('María Pérez · Consulta general'));
      await tester.pumpAndSettle();
      expect(find.text('detalle cita-1'), findsOneWidget);
    });

    testWidgets('tocar el banner Próxima abre el detalle', (tester) async {
      await _abrir(tester, FakeCitaRepository(citas: [citaLunaHoy]));
      await tester.tap(find.textContaining('Próxima:'));
      await tester.pumpAndSettle();
      expect(find.text('detalle cita-1'), findsOneWidget);
    });
  });

  test('CitaFailure es la excepción de dominio', () {
    expect(const CitaFailure('x'), isA<Exception>());
  });
}
