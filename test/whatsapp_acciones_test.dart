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
import 'package:vetapp/features/appointments/presentation/screens/cita_detail_screen.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_citas.dart';
import 'helpers/fake_url_launcher.dart';
import 'helpers/router_harness.dart';

final _ahora = deBogota(2026, 9, 30, 9, 35);

List<Override> _overrides(FakeCitaRepository repo, FakeLanzadorExterno l) => [
  citaRepositoryProvider.overrideWithValue(repo),
  lanzadorExternoProvider.overrideWithValue(l),
  authProfileProvider.overrideWith(
    () => FakeAuthProfileNotifier(profile: vetProfile),
  ),
  clockProvider.overrideWithValue(() => _ahora),
];

Widget _app(String inicial, FakeCitaRepository repo, FakeLanzadorExterno l) =>
    routerHarness(
      initialLocation: inicial,
      routes: [
        GoRoute(
          path: '/agenda',
          builder: (_, _) => const AgendaScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, state) =>
                  CitaDetailScreen(citaId: state.pathParameters['id']!),
            ),
          ],
        ),
        GoRoute(
          path: '/clientes/:id',
          builder: (_, state) =>
              Scaffold(body: Text('cliente ${state.pathParameters['id']}')),
        ),
      ],
      overrides: _overrides(repo, l),
    );

Future<void> _abrir(
  WidgetTester tester,
  String inicial,
  FakeCitaRepository repo,
  FakeLanzadorExterno l,
) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(inicial, repo, l));
  await tester.pumpAndSettle();
}

Future<void> _snack(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

const _fijo =
    'Este número parece un teléfono fijo; no se puede enviar WhatsApp.';

Cita _conTelefono(Cita c, String? tel) => Cita(
  id: c.id,
  clinicaId: c.clinicaId,
  clienteId: c.clienteId,
  veterinarioId: c.veterinarioId,
  fechaHora: c.fechaHora,
  duracionMin: c.duracionMin,
  modalidad: c.modalidad,
  direccion: c.direccion,
  motivo: c.motivo,
  estado: c.estado,
  clienteNombre: c.clienteNombre,
  clienteTelefono: tel,
  mascotas: c.mascotas,
);

void main() {
  group('CitaCard WhatsApp', () {
    testWidgets('abre wa.me, marca enviado y Deshacer restaura', (
      tester,
    ) async {
      final repo = FakeCitaRepository(citas: [citaLunaHoy]);
      final l = FakeLanzadorExterno();
      await _abrir(tester, '/agenda', repo, l);

      await tester.tap(find.text('WhatsApp'));
      await _snack(tester);

      expect(l.abiertos, hasLength(1));
      expect(
        l.abiertos.single.toString(),
        startsWith('https://wa.me/573001234567?text='),
      );
      expect(repo.recordatorios.single.citaId, 'cita-1');
      expect(repo.recordatorios.single.enviadoAt, _ahora);
      expect(find.text('Marcado como recordatorio enviado'), findsOneWidget);

      await tester.tap(find.text('Deshacer'));
      await _snack(tester);
      expect(repo.recordatorios.last.enviadoAt, isNull);
    });

    testWidgets('legacy sin normalizar sigue funcionando', (tester) async {
      final repo = FakeCitaRepository(
        citas: [_conTelefono(citaLunaHoy, '300 123 4567')],
      );
      final l = FakeLanzadorExterno();
      await _abrir(tester, '/agenda', repo, l);
      await tester.tap(find.text('WhatsApp'));
      await _snack(tester);
      expect(
        l.abiertos.single.toString(),
        startsWith('https://wa.me/573001234567?text='),
      );
    });

    testWidgets('lanzador falla: mensaje y no marca', (tester) async {
      final repo = FakeCitaRepository(citas: [citaLunaHoy]);
      final l = FakeLanzadorExterno()..resultado = false;
      await _abrir(tester, '/agenda', repo, l);
      await tester.tap(find.text('WhatsApp'));
      await _snack(tester);
      expect(
        find.text('No pudimos abrir WhatsApp. ¿Está instalado?'),
        findsOneWidget,
      );
      expect(repo.recordatorios, isEmpty);
    });

    testWidgets('sin app de WhatsApp (solo navegador): no marca (VET-25)', (
      tester,
    ) async {
      final repo = FakeCitaRepository(citas: [citaLunaHoy]);
      final l = FakeLanzadorExterno()
        ..resultado = true
        ..resultadoApp = false;
      await _abrir(tester, '/agenda', repo, l);
      await tester.tap(find.text('WhatsApp'));
      await _snack(tester);
      expect(
        find.text('No pudimos abrir WhatsApp. ¿Está instalado?'),
        findsOneWidget,
      );
      expect(find.text('Marcado como recordatorio enviado'), findsNothing);
      expect(repo.recordatorios, isEmpty);
      expect(l.metodos, ['abrirEnApp']);
      expect(l.abiertos.single.host, 'wa.me');
    });

    testWidgets('teléfono fijo: apagado, con motivo, no abre nada', (
      tester,
    ) async {
      final repo = FakeCitaRepository(
        citas: [_conTelefono(citaLunaHoy, '6012345678')],
      );
      final l = FakeLanzadorExterno();
      await _abrir(tester, '/agenda', repo, l);
      expect(find.text(_fijo), findsOneWidget);
      await tester.tap(find.text('WhatsApp'));
      await _snack(tester);
      expect(find.text(_fijo), findsNWidgets(2));
      expect(l.abiertos, isEmpty);
      expect(repo.recordatorios, isEmpty);
    });

    testWidgets('terminal: sin WhatsApp', (tester) async {
      await _abrir(
        tester,
        '/agenda',
        FakeCitaRepository(citas: [citaCanceladaHoy]),
        FakeLanzadorExterno(),
      );
      expect(find.text('WhatsApp'), findsNothing);
    });

    testWidgets('domicilio: Cómo llegar abre Maps; consultorio no lo tiene', (
      tester,
    ) async {
      final repo = FakeCitaRepository(citas: [citaLunaHoy, citaRockyLunaHoy]);
      final l = FakeLanzadorExterno();
      await _abrir(tester, '/agenda', repo, l);
      expect(find.text('Cómo llegar'), findsOneWidget);
      await tester.tap(find.text('Cómo llegar'));
      await _snack(tester);
      expect(l.metodos, ['abrir']);
      expect(
        l.abiertos.single.toString(),
        'https://www.google.com/maps/dir/?api=1'
        '&destination=Calle%2010%20%23%2020-30',
      );
    });

    testWidgets('Maps falla: mensaje', (tester) async {
      final l = FakeLanzadorExterno()..resultado = false;
      await _abrir(
        tester,
        '/agenda',
        FakeCitaRepository(citas: [citaRockyLunaHoy]),
        l,
      );
      await tester.tap(find.text('Cómo llegar'));
      await _snack(tester);
      expect(find.text('No pudimos abrir Google Maps.'), findsOneWidget);
    });
  });

  group('CitaDetailScreen WhatsApp', () {
    testWidgets('sin teléfono: motivo y Agregar teléfono navega', (
      tester,
    ) async {
      final repo = FakeCitaRepository(
        citas: [_conTelefono(citaLunaHoy, null)],
      );
      await _abrir(tester, '/agenda/cita-1', repo, FakeLanzadorExterno());
      expect(find.text('Este cliente no tiene teléfono.'), findsOneWidget);
      await tester.tap(find.text('Agregar teléfono'));
      await tester.pumpAndSettle();
      expect(find.text('cliente c-maria'), findsOneWidget);
    });

    testWidgets('WhatsApp y Cómo llegar desde el detalle', (tester) async {
      final repo = FakeCitaRepository(citas: [citaRockyLunaHoy]);
      final l = FakeLanzadorExterno();
      await _abrir(tester, '/agenda/cita-2', repo, l);
      await tester.ensureVisible(find.text('Cómo llegar'));
      await tester.tap(find.text('Cómo llegar'));
      await _snack(tester);
      expect(l.abiertos.single.host, 'www.google.com');

      await tester.ensureVisible(find.text('WhatsApp'));
      await tester.tap(find.text('WhatsApp'));
      await _snack(tester);
      expect(l.abiertos.last.host, 'wa.me');
      expect(repo.recordatorios.single.citaId, 'cita-2');
    });

    testWidgets('terminal: sin WhatsApp', (tester) async {
      await _abrir(
        tester,
        '/agenda/cita-3',
        FakeCitaRepository(citas: [citaCanceladaHoy]),
        FakeLanzadorExterno(),
      );
      expect(find.text('WhatsApp'), findsNothing);
    });
  });
}
