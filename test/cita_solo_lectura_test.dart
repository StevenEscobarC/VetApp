import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/core/errors/limite_plan.dart';
import 'package:vetapp/core/utils/lanzador_externo.dart';
import 'package:vetapp/core/utils/zona_bogota.dart';
import 'package:vetapp/core/widgets/buttons/app_button.dart';
import 'package:vetapp/features/appointments/domain/cita_failure.dart';
import 'package:vetapp/features/appointments/domain/entities/cita.dart';
import 'package:vetapp/features/appointments/presentation/providers/citas_providers.dart';
import 'package:vetapp/features/appointments/presentation/screens/agenda_screen.dart';
import 'package:vetapp/features/appointments/presentation/screens/cita_detail_screen.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/billing/presentation/providers/cobros_providers.dart';
import 'package:vetapp/features/plan/domain/mi_plan.dart';
import 'package:vetapp/features/team/domain/miembro.dart';
import 'package:vetapp/features/team/presentation/providers/team_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_citas.dart';
import 'helpers/fake_cobros.dart';
import 'helpers/fake_plan.dart';
import 'helpers/fake_url_launcher.dart';
import 'helpers/router_harness.dart';

/// Solo lectura en la agenda y el detalle de cita (05.1-10, D-12 / D-02).
final _ahora = deBogota(2026, 9, 30, 9, 35);
const _hoja = 'Tu cuenta está en solo lectura';

Widget _app(
  String inicial,
  FakeCitaRepository repo, {
  required MiPlan plan,
  FakeLanzadorExterno? lanzador,
}) => routerHarness(
  initialLocation: inicial,
  routes: [
    GoRoute(
      path: '/agenda',
      builder: (_, _) => const AgendaScreen(),
      routes: [
        GoRoute(
          path: 'nueva',
          builder: (_, _) => const Scaffold(body: Text('nueva-stub')),
        ),
        GoRoute(
          path: ':id',
          builder: (_, state) =>
              CitaDetailScreen(citaId: state.pathParameters['id']!),
          routes: [
            GoRoute(
              path: 'editar',
              builder: (_, _) => const Scaffold(body: Text('editar-stub')),
            ),
            GoRoute(
              path: 'completar',
              builder: (_, _) => const Scaffold(body: Text('completar-stub')),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/cobros/nuevo',
      builder: (_, _) => const Scaffold(body: Text('cobro-stub')),
    ),
  ],
  overrides: <Override>[
    ...planOverrides(plan: plan),
    citaRepositoryProvider.overrideWithValue(repo),
    cobrosRepositoryProvider.overrideWithValue(FakeCobrosRepository()),
    lanzadorExternoProvider.overrideWithValue(
      lanzador ?? FakeLanzadorExterno(),
    ),
    authProfileProvider.overrideWith(
      () => FakeAuthProfileNotifier(profile: vetProfile),
    ),
    esClinicaMultiVetProvider.overrideWithValue(false),
    miembrosActivosProvider.overrideWithValue(const <Miembro>[]),
    indicesColorVetProvider.overrideWithValue(const <String, int>{}),
    clockProvider.overrideWithValue(() => _ahora),
  ],
);

Future<void> _abrir(
  WidgetTester tester,
  String inicial,
  FakeCitaRepository repo, {
  MiPlan? plan,
  FakeLanzadorExterno? lanzador,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _app(inicial, repo, plan: plan ?? planSoloLectura, lanzador: lanzador),
  );
  await tester.pumpAndSettle();
}

Finder _candadoEn(Finder f) =>
    find.descendant(of: f, matching: find.byIcon(Icons.lock_outline));

Finder _boton(String label) => find.widgetWithText(AppButton, label);

/// Toca [f], espera la hoja de solo lectura y la cierra.
Future<void> _bloqueado(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pumpAndSettle();
  expect(find.text(_hoja), findsOneWidget);
  await tester.tapAt(const Offset(5, 5));
  await tester.pumpAndSettle();
  expect(find.text(_hoja), findsNothing);
}

void main() {
  group('Agenda en solo lectura', () {
    testWidgets('Nueva cita y Vacunar llevan candado y abren la hoja', (
      tester,
    ) async {
      await _abrir(tester, '/agenda', FakeCitaRepository(citas: [citaLunaHoy]));

      expect(_candadoEn(_boton('Nueva cita')), findsOneWidget);
      expect(_candadoEn(find.byTooltip('Vacunar')), findsOneWidget);

      await _bloqueado(tester, _boton('Nueva cita'));
      await _bloqueado(tester, find.byTooltip('Vacunar'));
      expect(find.text('nueva-stub'), findsNothing);
    });

    testWidgets('con plan Beta Nueva cita navega como siempre', (tester) async {
      await _abrir(
        tester,
        '/agenda',
        FakeCitaRepository(citas: [citaLunaHoy]),
        plan: planBeta,
      );

      expect(_candadoEn(_boton('Nueva cita')), findsNothing);
      await tester.tap(_boton('Nueva cita'));
      await tester.pumpAndSettle();
      expect(find.text('nueva-stub'), findsOneWidget);
    });

    testWidgets('la tarjeta bloquea Completar y Confirmar, no WhatsApp', (
      tester,
    ) async {
      final repo = FakeCitaRepository(citas: [citaLunaHoy]);
      final lanzador = FakeLanzadorExterno();
      await _abrir(tester, '/agenda', repo, lanzador: lanzador);

      expect(_candadoEn(_boton('Completar')), findsOneWidget);
      expect(_candadoEn(_boton('Confirmar')), findsOneWidget);
      expect(_candadoEn(_boton('WhatsApp')), findsNothing);

      await _bloqueado(tester, _boton('Completar'));
      await _bloqueado(tester, _boton('Confirmar'));
      expect(find.text('completar-stub'), findsNothing);
      expect(repo.estadosCambiados, isEmpty);

      // D-02: el recordatorio sigue funcionando y se marca como enviado.
      await tester.tap(_boton('WhatsApp'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(lanzador.abiertos, hasLength(1));
      expect(repo.recordatorios.single.citaId, 'cita-1');
      expect(find.text(_hoja), findsNothing);
    });

    testWidgets('Más acciones bloquea Marcar, No asistió, Cancelar, Editar', (
      tester,
    ) async {
      final repo = FakeCitaRepository(
        citas: [citaRockyLunaHoy], // confirmada
      );
      await _abrir(tester, '/agenda', repo);

      Future<void> abrirMas() async {
        await tester.tap(find.byTooltip('Más acciones'));
        await tester.pumpAndSettle();
      }

      await abrirMas();
      expect(_candadoEn(_boton('Marcar como pendiente')), findsOneWidget);
      expect(_candadoEn(_boton('No asistió')), findsOneWidget);
      expect(_candadoEn(_boton('Editar')), findsOneWidget);
      await _bloqueado(tester, _boton('No asistió'));

      await abrirMas();
      await _bloqueado(tester, find.text('Cancelar cita'));
      await abrirMas();
      await _bloqueado(tester, _boton('Editar'));

      expect(repo.estadosCambiados, isEmpty);
      expect(find.text('editar-stub'), findsNothing);
    });

    testWidgets('un LP004 obsoleto al confirmar abre la hoja, sin SnackBar', (
      tester,
    ) async {
      final repo = FakeCitaRepository(
        citas: [citaLunaHoy],
        errorEstado: const CitaFailure(
          'Tu cuenta está en solo lectura. Pide al administrador que active '
          'el plan.',
          limite: LimitePlan.soloLectura,
        ),
      );
      await _abrir(tester, '/agenda', repo, plan: planBeta);

      await tester.tap(_boton('Confirmar'));
      await tester.pumpAndSettle();

      expect(find.text(_hoja), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('Recordar a todos los de mañana sigue usable (D-02)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = FakeCitaRepository(
        citas: [
          Cita(
            id: 'cita-m',
            clinicaId: 'cli-1',
            clienteId: 'c-m',
            veterinarioId: 'vet-1',
            fechaHora: deBogota(2026, 10, 1, 9, 0),
            duracionMin: 30,
            modalidad: ModalidadCita.consultorio,
            motivo: 'Control',
            estado: EstadoCita.pendiente,
            clienteNombre: 'Ana Uno',
            clienteTelefono: '3001234567',
            mascotas: const [
              MascotaDeCita(id: 'm-1', nombre: 'Luna', especie: 'perro'),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        routerHarness(
          initialLocation: '/agenda',
          routes: [
            GoRoute(
              path: '/agenda',
              builder: (_, _) =>
                  AgendaScreen(diaInicial: DateTime.utc(2026, 10, 1)),
            ),
          ],
          overrides: <Override>[
            ...planOverrides(plan: planSoloLectura),
            citaRepositoryProvider.overrideWithValue(repo),
            authProfileProvider.overrideWith(
              () => FakeAuthProfileNotifier(profile: vetProfile),
            ),
            esClinicaMultiVetProvider.overrideWithValue(false),
            miembrosActivosProvider.overrideWithValue(const <Miembro>[]),
            indicesColorVetProvider.overrideWithValue(const <String, int>{}),
            clockProvider.overrideWithValue(() => _ahora),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final boton = find.textContaining('Recordar a todos');
      expect(boton, findsOneWidget);
      expect(
        _candadoEn(_boton('Recordar a todos los de mañana (1)')),
        findsNothing,
      );
      await tester.tap(boton);
      await tester.pumpAndSettle();
      expect(find.text('Recordar a los de mañana'), findsOneWidget);
      expect(find.text(_hoja), findsNothing);
    });
  });

  group('Detalle de cita en solo lectura', () {
    testWidgets('pendiente: bloquea sus escrituras, no WhatsApp ni historia', (
      tester,
    ) async {
      final repo = FakeCitaRepository(citas: [citaLunaHoy]);
      final lanzador = FakeLanzadorExterno();
      await _abrir(tester, '/agenda/cita-1', repo, lanzador: lanzador);

      expect(_candadoEn(find.byTooltip('Editar cita')), findsOneWidget);
      for (final l in [
        'Completar cita',
        'Confirmar',
        'No asistió',
        'Cancelar cita',
      ]) {
        expect(_candadoEn(_boton(l)), findsOneWidget, reason: l);
      }

      await _bloqueado(tester, find.byTooltip('Editar cita'));
      await _bloqueado(tester, _boton('Completar cita'));
      await _bloqueado(tester, _boton('Confirmar'));
      await _bloqueado(tester, _boton('No asistió'));
      await _bloqueado(tester, _boton('Cancelar cita'));
      expect(repo.estadosCambiados, isEmpty);

      expect(_candadoEn(_boton('WhatsApp')), findsNothing);
      await tester.tap(_boton('WhatsApp'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(lanzador.abiertos, hasLength(1));
      expect(repo.recordatorios, hasLength(1));
    });

    testWidgets('cancelada: Reabrir cita bloqueado', (tester) async {
      final repo = FakeCitaRepository(citas: [citaCanceladaHoy]);
      await _abrir(tester, '/agenda/${citaCanceladaHoy.id}', repo);

      expect(_candadoEn(_boton('Reabrir cita')), findsOneWidget);
      await _bloqueado(tester, _boton('Reabrir cita'));
      expect(repo.estadosCambiados, isEmpty);
    });

    testWidgets('completada: consulta pendiente bloqueada, historia no', (
      tester,
    ) async {
      final repo = FakeCitaRepository(
        citas: [citaLunaHoy.copyWith(estado: EstadoCita.completada)],
      );
      await _abrir(tester, '/agenda/cita-1', repo);

      expect(
        _candadoEn(_boton('Registrar consulta pendiente')),
        findsOneWidget,
      );
      expect(_candadoEn(_boton('Ver historia clínica')), findsNothing);
      await _bloqueado(tester, _boton('Registrar consulta pendiente'));
      expect(find.text('completar-stub'), findsNothing);
    });

    testWidgets('completada: Cobrar lleva candado y abre la hoja (D-19)', (
      tester,
    ) async {
      final repo = FakeCitaRepository(
        citas: [citaLunaHoy.copyWith(estado: EstadoCita.completada)],
      );
      await _abrir(tester, '/agenda/cita-1', repo);

      expect(_candadoEn(_boton('Cobrar')), findsOneWidget);
      expect(
        find.bySemanticsLabel('Cobrar, bloqueado, solo lectura'),
        findsOneWidget,
      );
      await _bloqueado(tester, _boton('Cobrar'));
      expect(find.text('cobro-stub'), findsNothing);
    });

    testWidgets('completada con plan Beta: Cobrar sin candado navega', (
      tester,
    ) async {
      final repo = FakeCitaRepository(
        citas: [citaLunaHoy.copyWith(estado: EstadoCita.completada)],
      );
      await _abrir(tester, '/agenda/cita-1', repo, plan: planBeta);

      expect(_candadoEn(_boton('Cobrar')), findsNothing);
      await tester.tap(_boton('Cobrar'));
      await tester.pumpAndSettle();
      expect(find.text('cobro-stub'), findsOneWidget);
    });

    testWidgets('con plan Beta no hay candados', (tester) async {
      await _abrir(
        tester,
        '/agenda/cita-1',
        FakeCitaRepository(citas: [citaLunaHoy]),
        plan: planBeta,
      );

      expect(find.byIcon(Icons.lock_outline), findsNothing);
      await tester.tap(_boton('Completar cita'));
      await tester.pumpAndSettle();
      expect(find.text('completar-stub'), findsOneWidget);
    });
  });
}
