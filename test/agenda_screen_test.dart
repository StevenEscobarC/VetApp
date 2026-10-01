import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/core/utils/zona_bogota.dart';
import 'package:vetapp/features/appointments/domain/cita_failure.dart';
import 'package:vetapp/features/appointments/domain/entities/cita.dart';
import 'package:vetapp/features/appointments/presentation/agenda_routes.dart';
import 'package:vetapp/features/appointments/presentation/providers/citas_providers.dart';
import 'package:vetapp/features/appointments/presentation/providers/recordatorios_providers.dart';
import 'package:vetapp/features/appointments/presentation/screens/agenda_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_citas.dart';
import 'helpers/fake_recordatorios.dart';
import 'helpers/router_harness.dart';

Widget _agenda(FakeCitaRepository repo, {DateTime? ahora}) => routerHarness(
  initialLocation: '/agenda',
  routes: [agendaRoute],
  overrides: [
    citaRepositoryProvider.overrideWithValue(repo),
    clockProvider.overrideWithValue(
      () => ahora ?? deBogota(2026, 9, 30, 9, 35),
    ),
  ],
);

Finder _celda(int y, int m, int d) => find.byKey(ValueKey('dia-$y-$m-$d'));

void main() {
  group('agendaSemanaProvider', () {
    test('consulta la semana Bogotá y ordena por fechaHora', () async {
      final repo = FakeCitaRepository(citas: citasSemanaFixture);
      final container = ProviderContainer(
        overrides: [citaRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final citas = await container.read(
        agendaSemanaProvider(DateTime.utc(2026, 9, 28)).future,
      );

      expect(repo.consultasEntre, hasLength(1));
      expect(repo.consultasEntre.single.inicio, DateTime.utc(2026, 9, 28, 5));
      expect(repo.consultasEntre.single.fin, DateTime.utc(2026, 10, 5, 5));
      final horas = citas.map((c) => c.fechaHora).toList();
      expect([...horas]..sort(), horas);
      expect(citas.first.id, citaLunaHoy.id);
    });
  });

  group('AgendaScreen', () {
    testWidgets('abre en hoy con conteos sin contar canceladas', (tester) async {
      await tester.pumpWidget(_agenda(FakeCitaRepository(citas: citasSemanaFixture)));
      await tester.pumpAndSettle();

      expect(find.text('Hoy, mié 30/09'), findsOneWidget);
      expect(find.text('3 citas'), findsOneWidget);
      expect(find.text('28 sep – 4 oct'), findsOneWidget);
      expect(
        find.descendant(of: _celda(2026, 9, 30), matching: find.text('3')),
        findsOneWidget,
      );
      expect(
        // Número del día + insignia de conteo.
        find.descendant(of: _celda(2026, 10, 1), matching: find.text('1')),
        findsNWidgets(2),
      );
    });

    testWidgets('lista las citas de hoy con su detalle', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_agenda(FakeCitaRepository(citas: citasSemanaFixture)));
      await tester.pumpAndSettle();

      expect(find.text('10:30 – 11:00 a. m.'), findsOneWidget);
      expect(find.text('Luna'), findsOneWidget);
      expect(find.text('María Pérez · Consulta general'), findsOneWidget);
      expect(find.text('En consultorio'), findsWidgets);
      expect(find.text('Calle 10 # 20-30'), findsOneWidget);
      expect(find.text('Cancelada'), findsOneWidget);
      // 23:30 Bogotá cae en hoy, no en mañana.
      expect(find.text('11:30 – 12:00 p. m.'), findsNothing);
      expect(find.text('11:30 p. m. – 12:00 a. m.'), findsOneWidget);
    });

    testWidgets('muestra el banner de próxima cita solo hoy', (tester) async {
      await tester.pumpWidget(_agenda(FakeCitaRepository(citas: citasSemanaFixture)));
      await tester.pumpAndSettle();

      expect(
        find.text('Próxima: Luna 10:30 a. m. · en 55 min'),
        findsOneWidget,
      );

      await tester.tap(_celda(2026, 10, 1));
      await tester.pumpAndSettle();
      expect(find.textContaining('Próxima:'), findsNothing);
      expect(find.text('Mañana, jue 01/10'), findsOneWidget);
    });

    testWidgets('navega de semana y vuelve con Hoy', (tester) async {
      await tester.pumpWidget(_agenda(FakeCitaRepository(citas: citasSemanaFixture)));
      await tester.pumpAndSettle();

      expect(find.text('Hoy'), findsNothing);
      await tester.tap(find.byTooltip('Semana siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('5 – 11 oct'), findsOneWidget);
      expect(find.text('Hoy'), findsOneWidget);

      await tester.tap(find.text('Hoy'));
      await tester.pumpAndSettle();
      expect(find.text('Hoy, mié 30/09'), findsOneWidget);
      expect(find.text('28 sep – 4 oct'), findsOneWidget);
    });

    testWidgets('día sin citas muestra el estado vacío', (tester) async {
      await tester.pumpWidget(_agenda(FakeCitaRepository(citas: citasSemanaFixture)));
      await tester.pumpAndSettle();

      await tester.tap(_celda(2026, 10, 2));
      await tester.pumpAndSettle();
      expect(find.text('Sin citas este día'), findsOneWidget);
      expect(
        find.text('Toca “Nueva cita” para agendar la primera.'),
        findsOneWidget,
      );

      await tester.tap(_celda(2026, 9, 29));
      await tester.pumpAndSettle();
      expect(find.text('No hubo citas este día.'), findsOneWidget);
    });

    testWidgets('error muestra mensaje y Reintentar re-consulta', (tester) async {
      final repo = FakeCitaRepository(
        error: const CitaFailure('No pudimos cargar la agenda. Intenta de nuevo.'),
      );
      await tester.pumpWidget(_agenda(repo));
      await tester.pumpAndSettle();

      expect(
        find.text('No pudimos cargar la agenda. Intenta de nuevo.'),
        findsOneWidget,
      );
      final antes = repo.consultasEntre.length;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(repo.consultasEntre.length, greaterThan(antes));
    });
  });

  group('AgendaScreen - nueva cita y cruces', () {
    testWidgets('Nueva cita abre el formulario con el día seleccionado', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _agenda(FakeCitaRepository(citas: citasSemanaFixture)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Nueva cita'));
      await tester.pumpAndSettle();

      expect(find.text('Guardar cita'), findsOneWidget);
      expect(find.text('mié 30/09/2026'), findsOneWidget);
    });

    testWidgets('/agenda?dia= abre con ese día seleccionado', (tester) async {
      await tester.pumpWidget(
        routerHarness(
          initialLocation: '/agenda?dia=2026-10-02',
          routes: [agendaRoute],
          overrides: [
            citaRepositoryProvider.overrideWithValue(
              FakeCitaRepository(citas: citasSemanaFixture),
            ),
            clockProvider.overrideWithValue(
              () => deBogota(2026, 9, 30, 9, 35),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('vie 02/10'), findsOneWidget);
    });

    testWidgets('marca "Se cruza con" en la cita pendiente que se solapa', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final maxCruce = citaCanceladaHoy.copyWith(
        fechaHora: deBogota(2026, 9, 30, 10, 45),
        estado: EstadoCita.pendiente,
      );
      await tester.pumpWidget(
        _agenda(FakeCitaRepository(citas: [citaLunaHoy, maxCruce])),
      );
      await tester.pumpAndSettle();

      expect(find.text('Se cruza con Luna'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
    });

    testWidgets('una cita cancelada que se solapa no muestra el cruce', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final maxCancelada = citaCanceladaHoy.copyWith(
        fechaHora: deBogota(2026, 9, 30, 10, 45),
      );
      await tester.pumpWidget(
        _agenda(FakeCitaRepository(citas: [citaLunaHoy, maxCancelada])),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Se cruza con'), findsNothing);
    });
  });

  group('AgendaScreen - banner de notificaciones', () {
    Widget conServicio(FakeRecordatoriosService fake) => routerHarness(
      initialLocation: '/agenda',
      routes: [agendaRoute],
      overrides: [
        citaRepositoryProvider.overrideWithValue(
          FakeCitaRepository(citas: citasSemanaFixture),
        ),
        clockProvider.overrideWithValue(() => deBogota(2026, 9, 30, 9, 35)),
        recordatoriosServiceProvider.overrideWithValue(fake),
      ],
    );

    setUp(
      () => SharedPreferences.setMockInitialValues({
        'permiso_notificaciones_explicado': true,
      }),
    );

    testWidgets('sin permiso y ya explicado muestra el banner persistente', (
      tester,
    ) async {
      await tester.pumpWidget(
        conServicio(FakeRecordatoriosService()..permiso = false),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recordatorios desactivados'), findsOneWidget);
      expect(
        find.text(
          'Activa las notificaciones para que te avisemos antes de cada cita.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Activar'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('con permiso no hay banner', (tester) async {
      await tester.pumpWidget(conServicio(FakeRecordatoriosService()));
      await tester.pumpAndSettle();
      expect(find.text('Recordatorios desactivados'), findsNothing);
    });

    testWidgets('sin explicar todavía no hay banner', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        conServicio(FakeRecordatoriosService()..permiso = false),
      );
      await tester.pumpAndSettle();
      expect(find.text('Recordatorios desactivados'), findsNothing);
    });

    testWidgets('Activar sin éxito abre ajustes una vez', (tester) async {
      final fake = FakeRecordatoriosService()
        ..permiso = false
        ..resultadoSolicitud = false;
      await tester.pumpWidget(conServicio(fake));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Activar'));
      await tester.pumpAndSettle();

      expect(fake.solicitudes, 1);
      expect(fake.ajustesAbiertos, 1);
      expect(find.text('Recordatorios desactivados'), findsOneWidget);
    });

    testWidgets('desaparece al conceder el permiso', (tester) async {
      final fake = FakeRecordatoriosService()..permiso = false;
      await tester.pumpWidget(conServicio(fake));
      await tester.pumpAndSettle();
      expect(find.text('Recordatorios desactivados'), findsOneWidget);

      fake.permiso = true;
      ProviderScope.containerOf(
        tester.element(find.byType(AgendaScreen)),
      ).invalidate(permisoNotificacionesProvider);
      await tester.pumpAndSettle();

      expect(find.text('Recordatorios desactivados'), findsNothing);
    });
  });
}
