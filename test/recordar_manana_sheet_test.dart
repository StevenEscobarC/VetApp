import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/core/utils/lanzador_externo.dart';
import 'package:vetapp/core/utils/zona_bogota.dart';
import 'package:vetapp/features/appointments/domain/entities/cita.dart';
import 'package:vetapp/features/appointments/presentation/providers/citas_providers.dart';
import 'package:vetapp/features/appointments/presentation/screens/agenda_screen.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/team/domain/miembro.dart';
import 'package:vetapp/features/team/presentation/providers/team_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_citas.dart';
import 'helpers/fake_team.dart';
import 'helpers/fake_url_launcher.dart';
import 'helpers/router_harness.dart';

final _ahora = deBogota(2026, 9, 30, 9, 35);
final _manana = DateTime.utc(2026, 10, 1);

Cita _cita(
  String id,
  int hora,
  String cliente,
  String? tel, {
  EstadoCita estado = EstadoCita.pendiente,
  DateTime? enviado,
}) => Cita(
  id: id,
  clinicaId: 'cli-1',
  clienteId: 'c-$id',
  veterinarioId: 'vet-1',
  fechaHora: deBogota(2026, 10, 1, hora, 0),
  duracionMin: 30,
  modalidad: ModalidadCita.consultorio,
  motivo: 'Control',
  estado: estado,
  clienteNombre: cliente,
  clienteTelefono: tel,
  recordatorioEnviadoAt: enviado,
  mascotas: const [
    MascotaDeCita(id: 'm-1', nombre: 'Luna', especie: 'perro'),
  ],
);

Future<void> _abrir(
  WidgetTester tester,
  FakeCitaRepository repo,
  FakeLanzadorExterno l, {
  DateTime? dia,
  bool multiVet = false,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    routerHarness(
      initialLocation: '/agenda',
      routes: [
        GoRoute(
          path: '/agenda',
          builder: (_, _) => AgendaScreen(diaInicial: dia ?? _manana),
        ),
      ],
      overrides: <Override>[
        citaRepositoryProvider.overrideWithValue(repo),
        lanzadorExternoProvider.overrideWithValue(l),
        authProfileProvider.overrideWith(
          () => FakeAuthProfileNotifier(profile: vetProfile),
        ),
        clockProvider.overrideWithValue(() => _ahora),
        teamRepositoryProvider.overrideWithValue(FakeTeamRepository()),
        esClinicaMultiVetProvider.overrideWithValue(multiVet),
        miembrosActivosProvider.overrideWithValue(const <Miembro>[]),
        indicesColorVetProvider.overrideWithValue(const <String, int>{}),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _ida(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle();
}

void main() {
  final a = _cita('a', 9, 'Ana Uno', '3001234567');
  final b = _cita('b', 10, 'Beto Dos', '3109876543');

  group('botón en la agenda', () {
    testWidgets('mañana con 2 por enviar muestra el conteo', (tester) async {
      await _abrir(
        tester,
        FakeCitaRepository(citas: [a, b]),
        FakeLanzadorExterno(),
      );
      expect(find.text('Recordar a todos los de mañana (2)'), findsOneWidget);
    });

    testWidgets('hoy no lo muestra', (tester) async {
      await _abrir(
        tester,
        FakeCitaRepository(citas: [a, b, citaLunaHoy]),
        FakeLanzadorExterno(),
        dia: DateTime.utc(2026, 9, 30),
      );
      expect(find.textContaining('Recordar a todos'), findsNothing);
      expect(find.textContaining('recordatorios de mañana'), findsNothing);
    });

    testWidgets('todos enviados muestra la etiqueta', (tester) async {
      final enviado = _cita('a', 9, 'Ana Uno', '3001234567', enviado: _ahora);
      await _abrir(
        tester,
        FakeCitaRepository(citas: [enviado]),
        FakeLanzadorExterno(),
      );
      expect(find.textContaining('Recordar a todos'), findsNothing);
      expect(
        find.text('Todos los recordatorios de mañana enviados'),
        findsOneWidget,
      );
    });
  });

  group('hoja', () {
    Future<void> abrirHoja(WidgetTester tester) async {
      await tester.tap(find.textContaining('Recordar a todos'));
      await tester.pumpAndSettle();
    }

    testWidgets('recorre cliente por cliente con detección de retorno', (
      tester,
    ) async {
      final repo = FakeCitaRepository(citas: [a, b]);
      final l = FakeLanzadorExterno();
      await _abrir(tester, repo, l);
      await abrirHoja(tester);

      expect(find.text('Recordar a los de mañana'), findsOneWidget);
      expect(
        find.text(
          'Vamos de uno en uno: abre WhatsApp, envía el mensaje y vuelve aquí.',
        ),
        findsOneWidget,
      );
      expect(find.text('Pendiente de enviar'), findsNWidgets(2));

      await tester.tap(find.text('Enviar a Ana Uno'));
      await tester.pumpAndSettle();
      expect(l.abiertos.single.host, 'wa.me');
      expect(repo.recordatorios, isEmpty);

      await _ida(tester);
      expect(repo.recordatorios.single.citaId, 'a');
      expect(find.text('Enviar a Beto Dos'), findsOneWidget);

      await tester.tap(find.text('Enviar a Beto Dos'));
      await tester.pumpAndSettle();
      await _ida(tester);
      expect(repo.recordatorios.map((r) => r.citaId), ['a', 'b']);
      expect(find.text('Listo, recordaste a 2 clientes.'), findsOneWidget);
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('Recordar a los de mañana'), findsNothing);
    });

    testWidgets('resumed sin pausa previa no marca nada', (tester) async {
      final repo = FakeCitaRepository(citas: [a, b]);
      await _abrir(tester, repo, FakeLanzadorExterno());
      await abrirHoja(tester);
      await tester.tap(find.text('Enviar a Ana Uno'));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(repo.recordatorios, isEmpty);
    });

    testWidgets('Marcar como enviado es el respaldo manual', (tester) async {
      final repo = FakeCitaRepository(citas: [a, b]);
      await _abrir(tester, repo, FakeLanzadorExterno());
      await abrirHoja(tester);
      await tester.tap(find.text('Marcar como enviado'));
      await tester.pumpAndSettle();
      expect(repo.recordatorios.single.citaId, 'a');
      expect(find.text('Enviar a Beto Dos'), findsOneWidget);
    });

    testWidgets('un fijo se salta con "Sin WhatsApp"', (tester) async {
      final fijo = _cita('f', 8, 'Fijo Cero', '6012345678');
      final repo = FakeCitaRepository(citas: [fijo, a]);
      await _abrir(tester, repo, FakeLanzadorExterno());
      await abrirHoja(tester);
      expect(find.text('Sin WhatsApp'), findsOneWidget);
      expect(find.text('Enviar a Ana Uno'), findsOneWidget);
    });

    testWidgets('lanzador falla: queda pendiente y avisa', (tester) async {
      final repo = FakeCitaRepository(citas: [a, b]);
      final l = FakeLanzadorExterno()..resultado = false;
      await _abrir(tester, repo, l);
      await abrirHoja(tester);
      await tester.tap(find.text('Enviar a Ana Uno'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text('No pudimos abrir WhatsApp. ¿Está instalado?'),
        findsOneWidget,
      );
      // Un ciclo pausa/retorno posterior no marca: ya no se espera.
      await _ida(tester);
      expect(repo.recordatorios, isEmpty);
      expect(find.text('Enviar a Ana Uno'), findsOneWidget);
    });

    testWidgets('sin app de WhatsApp (solo navegador): no marca (VET-25)', (
      tester,
    ) async {
      final repo = FakeCitaRepository(citas: [a, b]);
      final l = FakeLanzadorExterno()
        ..resultado = true
        ..resultadoApp = false;
      await _abrir(tester, repo, l);
      await abrirHoja(tester);
      await tester.tap(find.text('Enviar a Ana Uno'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text('No pudimos abrir WhatsApp. ¿Está instalado?'),
        findsOneWidget,
      );
      expect(l.metodos, ['abrirEnApp']);
      await _ida(tester);
      expect(repo.recordatorios, isEmpty);
      expect(find.text('Pendiente de enviar'), findsNWidgets(2));
    });
  });

  group('firma por veterinario (D-10)', () {
    // Se mantiene veterinarioId vet-1 para esquivar el filtro "Mías" de la
    // agenda; la firma solo depende de veterinarioNombre.
    final deLuis = _cita(
      'l',
      11,
      'Lola Tres',
      '3201112233',
    ).copyWith(veterinarioNombre: 'Luis Torres');

    testWidgets('multi-vet: etiqueta por fila y firma de cada cita', (
      tester,
    ) async {
      final l = FakeLanzadorExterno();
      await _abrir(
        tester,
        FakeCitaRepository(citas: [deLuis]),
        l,
        multiVet: true,
      );
      await tester.tap(find.textContaining('Recordar a todos'));
      await tester.pumpAndSettle();
      expect(find.text('Luis'), findsOneWidget);

      await tester.tap(find.text('Enviar a Lola Tres'));
      await tester.pumpAndSettle();
      final texto = Uri.decodeComponent(
        l.abiertos.single.toString().split('text=').last,
      );
      expect(texto, contains('Dr(a). Luis Torres, Clínica Patitas'));
      expect(texto, isNot(contains('Ana Ramírez')));
    });

    testWidgets('un solo veterinario no muestra etiqueta', (tester) async {
      await _abrir(
        tester,
        FakeCitaRepository(citas: [deLuis]),
        FakeLanzadorExterno(),
      );
      await tester.tap(find.textContaining('Recordar a todos'));
      await tester.pumpAndSettle();
      expect(find.text('Luis'), findsNothing);
    });
  });
}
