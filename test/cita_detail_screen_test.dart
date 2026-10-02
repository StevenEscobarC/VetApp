import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vetapp/core/utils/zona_bogota.dart';
import 'package:vetapp/core/widgets/buttons/app_button.dart';
import 'package:vetapp/features/appointments/domain/cita_failure.dart';
import 'package:vetapp/features/appointments/domain/entities/cita.dart';
import 'package:vetapp/features/appointments/presentation/agenda_routes.dart';
import 'package:vetapp/features/appointments/presentation/providers/citas_providers.dart';
import 'package:vetapp/features/appointments/presentation/screens/cita_detail_screen.dart';

import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/team/domain/miembro.dart';
import 'package:vetapp/features/team/presentation/providers/team_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_citas.dart';
import 'helpers/fake_team.dart';
import 'helpers/router_harness.dart';

final _luisTorres = Miembro(
  id: 'vet-2',
  nombre: 'Luis Torres',
  rolClinica: 'veterinario',
  activo: true,
  createdAt: DateTime(2026, 2, 1),
);

Widget _detalle(
  FakeCitaRepository repo,
  String id, {
  bool multi = false,
}) => routerHarness(
  initialLocation: '/agenda/$id',
  routes: [
    GoRoute(
      path: '/agenda',
      builder: (_, _) => const Scaffold(body: Text('agenda-stub')),
      routes: [
        GoRoute(
          path: ':id',
          builder: (_, state) =>
              CitaDetailScreen(citaId: state.pathParameters['id']!),
          routes: [
            GoRoute(
              path: 'editar',
              builder: (_, state) =>
                  Scaffold(body: Text('editar ${state.pathParameters['id']}')),
            ),
            GoRoute(
              path: 'completar',
              builder: (_, state) => Scaffold(
                body: Text('completar ${state.pathParameters['id']}'),
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/pacientes/:id',
      builder: (_, state) =>
          Scaffold(body: Text('paciente ${state.pathParameters['id']}')),
    ),
  ],
  overrides: [
    citaRepositoryProvider.overrideWithValue(repo),
    authProfileProvider.overrideWith(
      () => FakeAuthProfileNotifier(profile: vetProfile),
    ),
    teamRepositoryProvider.overrideWithValue(
      FakeTeamRepository(miembrosFixture: multi ? [miembroAna, _luisTorres] : []),
    ),
  ],
);

Future<void> _abrir(
  WidgetTester tester,
  FakeCitaRepository repo,
  String id, {
  bool multi = false,
}) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_detalle(repo, id, multi: multi));
  await tester.pumpAndSettle();
}

Cita _conEstado(Cita c, EstadoCita e) => c.copyWith(estado: e);

void main() {
  testWidgets('muestra toda la información de una cita pendiente', (
    tester,
  ) async {
    await _abrir(tester, FakeCitaRepository(citas: [citaLunaHoy]), 'cita-1');

    // Encabezado + fila de mascota.
    expect(find.text('Luna'), findsNWidgets(2));
    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.text('mié 30/09/2026 · 10:30 – 11:00 a. m.'), findsOneWidget);
    expect(find.text('María Pérez'), findsOneWidget);
    expect(find.text('+57 300 123 4567'), findsOneWidget);
    expect(find.text('Consulta general'), findsOneWidget);
    expect(find.text('En consultorio'), findsOneWidget);
    expect(find.text('Sin registrar'), findsOneWidget);
    expect(find.text('Sin enviar'), findsOneWidget);
  });

  testWidgets('domicilio: dirección, dos mascotas y navegación a la ficha', (
    tester,
  ) async {
    await _abrir(
      tester,
      FakeCitaRepository(citas: [citaRockyLunaHoy]),
      'cita-2',
    );

    expect(find.text('Calle 10 # 20-30'), findsOneWidget);
    expect(find.text('Rocky'), findsOneWidget);
    await tester.tap(find.text('Rocky'));
    await tester.pumpAndSettle();
    expect(find.text('paciente m-rocky'), findsOneWidget);
  });

  testWidgets('pendiente: Confirmar, No asistió, Cancelar y editar', (
    tester,
  ) async {
    await _abrir(tester, FakeCitaRepository(citas: [citaLunaHoy]), 'cita-1');

    expect(find.text('Confirmar'), findsOneWidget);
    expect(find.text('No asistió'), findsOneWidget);
    expect(find.text('Cancelar cita'), findsOneWidget);
    await tester.tap(find.byTooltip('Editar cita'));
    await tester.pumpAndSettle();
    expect(find.text('editar cita-1'), findsOneWidget);
  });

  testWidgets('confirmada: sin Confirmar, con editar', (tester) async {
    await _abrir(
      tester,
      FakeCitaRepository(citas: [citaRockyLunaHoy]),
      'cita-2',
    );
    expect(find.text('Confirmar'), findsNothing);
    expect(find.text('No asistió'), findsOneWidget);
    expect(find.text('Cancelar cita'), findsOneWidget);
    expect(find.byTooltip('Editar cita'), findsOneWidget);
  });

  testWidgets('Confirmar desde el detalle registra el estado con Deshacer', (
    tester,
  ) async {
    final repo = FakeCitaRepository(citas: [citaLunaHoy]);
    await _abrir(tester, repo, 'cita-1');
    await tester.tap(find.text('Confirmar'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(repo.estadosCambiados.single.estado, EstadoCita.confirmada);
    expect(find.text('Cita confirmada'), findsOneWidget);
  });

  for (final e in [EstadoCita.cancelada, EstadoCita.noAsistio]) {
    testWidgets('${e.valor}: solo Reabrir cita, sin editar', (tester) async {
      final repo = FakeCitaRepository(citas: [_conEstado(citaLunaHoy, e)]);
      await _abrir(tester, repo, 'cita-1');

      expect(find.text('Reabrir cita'), findsOneWidget);
      expect(find.text('Confirmar'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'No asistió'), findsNothing);
      expect(find.byTooltip('Editar cita'), findsNothing);

      await tester.tap(find.text('Reabrir cita'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(repo.estadosCambiados.single.estado, EstadoCita.pendiente);
      expect(find.text('Cita reabierta'), findsOneWidget);
      expect(find.text('Deshacer'), findsOneWidget);
    });
  }

  testWidgets('completada: solo Ver historia clínica', (tester) async {
    await _abrir(
      tester,
      FakeCitaRepository(
        citas: [_conEstado(citaLunaHoy, EstadoCita.completada)],
      ),
      'cita-1',
    );
    expect(find.text('Ver historia clínica'), findsOneWidget);
    expect(find.text('Reabrir cita'), findsNothing);
    expect(find.byTooltip('Editar cita'), findsNothing);
    await tester.tap(find.text('Ver historia clínica'));
    await tester.pumpAndSettle();
    expect(find.text('paciente m-luna'), findsOneWidget);
  });

  testWidgets('pendiente: Completar cita es el único botón primario y navega', (
    tester,
  ) async {
    await _abrir(tester, FakeCitaRepository(citas: [citaLunaHoy]), 'cita-1');

    final primarios = tester
        .widgetList<AppButton>(find.byType(AppButton))
        .where((b) => b.variant == AppButtonVariant.primary);
    expect(primarios, hasLength(1));
    expect(primarios.single.label, 'Completar cita');

    await tester.tap(find.text('Completar cita'));
    await tester.pumpAndSettle();
    expect(find.text('completar cita-1'), findsOneWidget);
  });

  testWidgets('confirmada: también ofrece Completar cita', (tester) async {
    await _abrir(
      tester,
      FakeCitaRepository(citas: [citaRockyLunaHoy]),
      'cita-2',
    );
    expect(find.text('Completar cita'), findsOneWidget);
  });

  testWidgets('completada: Consulta registrada / Sin consulta por mascota y '
      'Registrar consulta pendiente', (tester) async {
    final cita = citaRockyLunaHoy.copyWith(
      estado: EstadoCita.completada,
      mascotasConConsulta: {'m-rocky'},
    );
    await _abrir(tester, FakeCitaRepository(citas: [cita]), 'cita-2');

    expect(find.text('Consulta registrada'), findsOneWidget);
    expect(find.text('Sin consulta'), findsOneWidget);
    expect(find.text('Completar cita'), findsNothing);
    expect(find.text('Ver historia clínica'), findsOneWidget);

    await tester.tap(find.text('Registrar consulta pendiente'));
    await tester.pumpAndSettle();
    expect(find.text('completar cita-2'), findsOneWidget);
  });

  testWidgets('completada con todas registradas: sin Registrar pendiente', (
    tester,
  ) async {
    final cita = citaLunaHoy.copyWith(
      estado: EstadoCita.completada,
      mascotasConConsulta: {'m-luna'},
    );
    await _abrir(tester, FakeCitaRepository(citas: [cita]), 'cita-1');
    expect(find.text('Registrar consulta pendiente'), findsNothing);
    expect(find.text('Consulta registrada'), findsOneWidget);
  });

  testWidgets('muestra el recordatorio enviado', (tester) async {
    final cita = Cita(
      id: 'cita-9',
      clinicaId: 'cli-1',
      clienteId: 'c-maria',
      veterinarioId: 'vet-1',
      fechaHora: deBogota(2026, 9, 30, 10, 30),
      duracionMin: 30,
      modalidad: ModalidadCita.consultorio,
      motivo: 'Control',
      estado: EstadoCita.confirmada,
      recordatorioEnviadoAt: deBogota(2026, 9, 29, 18, 15),
      clienteNombre: 'María Pérez',
      mascotas: citaLunaHoy.mascotas,
    );
    await _abrir(tester, FakeCitaRepository(citas: [cita]), 'cita-9');
    expect(find.text('Enviado 29/09 6:15 p. m.'), findsOneWidget);
  });

  testWidgets('cargando muestra un spinner', (tester) async {
    final nunca = Completer<Cita>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [citaProvider('cita-1').overrideWith((ref) => nunca.future)],
        child: const MaterialApp(home: CitaDetailScreen(citaId: 'cita-1')),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error genérico ofrece Reintentar', (tester) async {
    await _abrir(
      tester,
      FakeCitaRepository(
        error: const CitaFailure(
          'No pudimos cargar la cita. Intenta de nuevo.',
        ),
      ),
      'cita-1',
    );
    expect(
      find.text('No pudimos cargar la cita. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('cita inexistente ofrece Volver a la agenda', (tester) async {
    await _abrir(tester, FakeCitaRepository(citas: const []), 'nope');
    expect(find.text('Esta cita ya no existe.'), findsOneWidget);
    await tester.tap(find.text('Volver a la agenda'));
    await tester.pumpAndSettle();
    expect(find.text('agenda-stub'), findsOneWidget);
  });

  test('en agendaRoute nueva va antes que :id', () {
    final paths = agendaRoute.routes.whereType<GoRoute>().map((r) => r.path);
    expect(
      paths.toList().indexOf('nueva'),
      lessThan(paths.toList().indexOf(':id')),
    );
  });

  group('veterinario (04.1-08)', () {
    testWidgets('un solo vet: sin fila Veterinario ni Reasignar', (
      tester,
    ) async {
      await _abrir(tester, FakeCitaRepository(citas: [citaLunaHoy]), 'cita-1');
      expect(find.text('Veterinario'), findsNothing);
      expect(find.text('Reasignar cita'), findsNothing);
    });

    testWidgets('multi-vet: fila Veterinario, Reasignar y Deshacer', (
      tester,
    ) async {
      final repo = FakeCitaRepository(citas: [citaColegaFixture]);
      await _abrir(tester, repo, 'cita-colega', multi: true);

      expect(find.text('Veterinario'), findsOneWidget);
      expect(find.text('Dr(a). Luis Torres'), findsOneWidget);

      await tester.tap(find.text('Reasignar cita'));
      await tester.pumpAndSettle();
      expect(find.text('Asignar a'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Ana Ramírez'),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(repo.reasignadas.single.veterinarioId, 'vet-1');
      expect(find.text('Cita reasignada a Dr(a). Ana Ramírez'), findsOneWidget);

      await tester.tap(find.text('Deshacer'));
      await tester.pump();
      await tester.pump();
      expect(repo.reasignadas.last.veterinarioId, 'vet-2');
      expect(repo.reasignadas, hasLength(2));
    });

    testWidgets('cita terminal: muestra el vet pero no Reasignar', (
      tester,
    ) async {
      final repo = FakeCitaRepository(
        citas: [_conEstado(citaColegaFixture, EstadoCita.completada)],
      );
      await _abrir(tester, repo, 'cita-colega', multi: true);
      expect(find.text('Veterinario'), findsOneWidget);
      expect(find.text('Reasignar cita'), findsNothing);
    });
  });
}
