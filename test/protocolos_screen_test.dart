import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetapp/features/appointments/presentation/providers/citas_providers.dart';
import 'package:vetapp/features/appointments/presentation/providers/recordatorios_providers.dart';
import 'package:vetapp/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/home/presentation/screens/mas_screen.dart';
import 'package:vetapp/features/team/presentation/providers/team_providers.dart';
import 'package:vetapp/features/vaccination/domain/entities/protocolo.dart';
import 'package:vetapp/features/vaccination/presentation/protocolos_routes.dart';
import 'package:vetapp/features/vaccination/presentation/providers/vacuna_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_citas.dart';
import 'helpers/fake_recordatorios.dart';
import 'helpers/fake_team.dart';
import 'helpers/fake_vacunas.dart';
import 'helpers/router_harness.dart';

const _polivalente = Protocolo(
  codigo: 'polivalente',
  nombre: 'Polivalente',
  tipo: TipoDosis.vacuna,
  especies: ['perro'],
  edadMinDias: 42,
  dosisSerie: 3,
  intervaloSerieDias: 21,
  intervaloRefuerzoDias: 365,
  opcionesDuracionDias: [365],
  personalizado: false,
  esSemilla: true,
  activo: true,
);

const _bordetella = Protocolo(
  codigo: 'bordetella',
  nombre: 'Bordetella',
  tipo: TipoDosis.vacuna,
  especies: ['perro'],
  dosisSerie: 1,
  intervaloRefuerzoDias: 180,
  opcionesDuracionDias: [180, 365],
  personalizado: true,
  esSemilla: true,
  activo: true,
);

const _giardia = Protocolo(
  codigo: 'custom:giardia',
  nombre: 'Giardia',
  tipo: TipoDosis.desparasitacionInterna,
  especies: ['perro'],
  dosisSerie: 1,
  opcionesDuracionDias: [90],
  personalizado: true,
  esSemilla: false,
  activo: true,
);

const _triple = Protocolo(
  codigo: 'triple_felina',
  nombre: 'Triple felina',
  tipo: TipoDosis.vacuna,
  especies: ['gato'],
  dosisSerie: 1,
  intervaloRefuerzoDias: 90,
  opcionesDuracionDias: [365],
  personalizado: false,
  esSemilla: true,
  activo: true,
);

const _catalogo = [_polivalente, _bordetella, _giardia, _triple];

List<Override> _overrides(
  FakeVacunaRepository repo, {
  AuthProfile perfil = vetAdminProfile,
}) {
  SharedPreferences.setMockInitialValues({});
  return [
    authProfileProvider.overrideWith(
      () => FakeAuthProfileNotifier(profile: perfil),
    ),
    vacunaRepositoryProvider.overrideWithValue(repo),
    teamRepositoryProvider.overrideWithValue(
      FakeTeamRepository(miembrosFixture: []),
    ),
    citaRepositoryProvider.overrideWithValue(FakeCitaRepository()),
    recordatoriosServiceProvider.overrideWithValue(FakeRecordatoriosService()),
  ];
}

Widget _app(
  FakeVacunaRepository repo, {
  AuthProfile perfil = vetAdminProfile,
  String initial = '/mas/protocolos',
}) => routerHarness(
  initialLocation: initial,
  routes: [
    GoRoute(
      path: '/mas',
      builder: (_, _) => const MasScreen(),
      routes: masProtocolosRoutes,
    ),
  ],
  overrides: _overrides(repo, perfil: perfil),
);

Future<void> _abrir(
  WidgetTester tester,
  FakeVacunaRepository repo, {
  AuthProfile perfil = vetAdminProfile,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(repo, perfil: perfil));
  await tester.pumpAndSettle();
}

Future<void> _tocar(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Más shows the entry and opens /mas/protocolos', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeVacunaRepository(protocolosData: _catalogo);
    await tester.pumpWidget(_app(repo, initial: '/mas'));
    await tester.pumpAndSettle();
    expect(find.text('Protocolos de vacunación'), findsOneWidget);
    expect(find.byIcon(Icons.tune), findsOneWidget);
    await tester.tap(find.text('Protocolos de vacunación'));
    await tester.pumpAndSettle();
    expect(find.text('Protocolos'), findsOneWidget);
    expect(find.text('Polivalente'), findsOneWidget);
  });

  testWidgets('lists dogs by default, summaries, Personalizado and banner', (
    tester,
  ) async {
    await _abrir(tester, FakeVacunaRepository(protocolosData: _catalogo));
    expect(find.text('Polivalente'), findsOneWidget);
    expect(find.text('Triple felina'), findsNothing);
    expect(find.text('3 dosis cada 21 días · refuerzo anual'), findsOneWidget);
    expect(
      find.text('1 dosis · refuerzo cada 6 meses'),
      findsOneWidget,
    );
    expect(find.text('1 dosis · sin refuerzo'), findsOneWidget);
    expect(find.text('Personalizado'), findsNWidgets(2));
    expect(
      find.text(
        'Los cambios aplican a las próximas dosis que registres. Las fechas '
        'próximas se recalculan con el nuevo protocolo.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Gatos'));
    await tester.pumpAndSettle();
    expect(find.text('Triple felina'), findsOneWidget);
    expect(find.text('Polivalente'), findsNothing);
  });

  testWidgets('admin edits interval and saves', (tester) async {
    final repo = FakeVacunaRepository(protocolosData: _catalogo);
    await _abrir(tester, repo);
    await tester.tap(find.text('Polivalente'));
    await tester.pumpAndSettle();
    await _tocar(tester, find.text('28 días'));
    await _tocar(tester, find.text('Guardar cambios'));
    final llamada = repo.llamadas.firstWhere(
      (l) => l.metodo == 'guardarProtocolo',
    );
    expect(llamada.args['codigo'], 'polivalente');
    expect(llamada.args['intervaloSerieDias'], 28);
    expect(llamada.args['dosisSerie'], 3);
    expect(find.text('Protocolo guardado'), findsOneWidget);
  });

  testWidgets('admin resets an overridden seed after confirming', (
    tester,
  ) async {
    final repo = FakeVacunaRepository(protocolosData: _catalogo);
    await _abrir(tester, repo);
    await tester.tap(find.text('Bordetella'));
    await tester.pumpAndSettle();
    expect(find.text('Desactivar'), findsNothing);
    await _tocar(tester, find.text('Restablecer valores estándar'));
    expect(find.text('¿Restablecer valores estándar?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Restablecer'));
    await tester.pumpAndSettle();
    expect(
      repo.llamadas.where((l) => l.metodo == 'restablecerProtocolo').single
          .args['codigo'],
      'bordetella',
    );
  });

  testWidgets('a pristine seed shows neither reset nor deactivate', (
    tester,
  ) async {
    await _abrir(tester, FakeVacunaRepository(protocolosData: _catalogo));
    await tester.tap(find.text('Polivalente'));
    await tester.pumpAndSettle();
    expect(find.text('Restablecer valores estándar'), findsNothing);
    expect(find.text('Desactivar'), findsNothing);
  });

  testWidgets('admin deactivates a custom biologico after confirming', (
    tester,
  ) async {
    final repo = FakeVacunaRepository(protocolosData: _catalogo);
    await _abrir(tester, repo);
    await tester.tap(find.text('Giardia'));
    await tester.pumpAndSettle();
    expect(find.text('Restablecer valores estándar'), findsNothing);
    await _tocar(tester, find.text('Desactivar'));
    expect(find.text('¿Desactivar Giardia?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Desactivar').last);
    await tester.pumpAndSettle();
    expect(
      repo.llamadas.where((l) => l.metodo == 'desactivarProtocolo').single
          .args['codigo'],
      'custom:giardia',
    );
  });

  testWidgets('Nuevo biológico creates with null codigo', (tester) async {
    final repo = FakeVacunaRepository(protocolosData: _catalogo);
    await _abrir(tester, repo);
    await tester.tap(find.text('Nuevo biológico'));
    await tester.pumpAndSettle();
    expect(find.text('Nombre'), findsOneWidget);
    expect(find.text('Especie'), findsOneWidget);
    for (final e in ['Perro', 'Gato', 'Ambos']) {
      expect(find.text(e), findsOneWidget);
    }
    await tester.enterText(find.byType(TextField), 'Leishmania');
    await _tocar(tester, find.text('Gato'));
    await _tocar(tester, find.text('Guardar cambios'));
    final llamada = repo.llamadas.firstWhere(
      (l) => l.metodo == 'guardarProtocolo',
    );
    expect(llamada.args['codigo'], isNull);
    expect(llamada.args['nombre'], 'Leishmania');
    expect(llamada.args['especies'], ['gato']);
    expect(find.text('Protocolo guardado'), findsOneWidget);
  });

  testWidgets('non-admin sees read-only tiles and the notice', (tester) async {
    final repo = FakeVacunaRepository(protocolosData: _catalogo);
    await _abrir(tester, repo, perfil: vetColegaProfile);
    expect(
      find.text('Solo los administradores pueden cambiar los protocolos.'),
      findsOneWidget,
    );
    expect(find.text('Nuevo biológico'), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    await tester.tap(find.text('Polivalente'));
    await tester.pumpAndSettle();
    expect(find.text('Guardar cambios'), findsNothing);
  });

  testWidgets('save error shows the mapped snackbar', (tester) async {
    final repo = FakeVacunaRepository(
      protocolosData: _catalogo,
      errorGuardarProtocolo: Exception('boom'),
    );
    await _abrir(tester, repo);
    await tester.tap(find.text('Polivalente'));
    await tester.pumpAndSettle();
    await _tocar(tester, find.text('Guardar cambios'));
    expect(
      find.text('No pudimos guardar el protocolo. Intenta de nuevo.'),
      findsOneWidget,
    );
  });

  testWidgets('load error shows the message', (tester) async {
    await _abrir(tester, FakeVacunaRepository(error: Exception('x')));
    expect(
      find.text('No pudimos cargar los protocolos. Intenta de nuevo.'),
      findsOneWidget,
    );
  });

  testWidgets('duraciones: un solo chip "3 meses" (84 y 90 días)', (
    tester,
  ) async {
    const despExterna = Protocolo(
      codigo: 'desp_externa',
      nombre: 'Desparasitación externa',
      tipo: TipoDosis.desparasitacionExterna,
      especies: ['perro', 'gato'],
      edadMinDias: 56,
      dosisSerie: 1,
      intervaloRefuerzoDias: 30,
      opcionesDuracionDias: [30, 35, 84],
      personalizado: false,
      esSemilla: true,
      activo: true,
    );
    final repo = FakeVacunaRepository(
      protocolosData: [..._catalogo, despExterna],
    );
    await _abrir(tester, repo);
    await tester.tap(find.text('Giardia'));
    await tester.pumpAndSettle();
    expect(find.text('3 meses'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Desparasitación externa'));
    await tester.pumpAndSettle();
    expect(find.text('3 meses'), findsOneWidget);
    // El chip visible es el de 84 días (seleccionado): desmarcarlo lo quita.
    await _tocar(tester, find.text('3 meses'));
    await _tocar(tester, find.text('Guardar cambios'));
    final llamada = repo.llamadas.firstWhere(
      (l) => l.metodo == 'guardarProtocolo',
    );
    expect(llamada.args['opcionesDuracionDias'], [30, 35]);
  });
}
