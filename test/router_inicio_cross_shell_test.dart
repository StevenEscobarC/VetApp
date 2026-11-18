import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/core/router/app_router.dart';
import 'package:vetapp/core/utils/zona_bogota.dart';
import 'package:vetapp/features/appointments/domain/entities/cita.dart';
import 'package:vetapp/features/appointments/presentation/providers/recordatorios_providers.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/billing/presentation/providers/cobros_providers.dart';
import 'package:vetapp/features/clients/presentation/providers/clientes_providers.dart';
import 'package:vetapp/features/home/presentation/app_shell.dart';
import 'package:vetapp/features/home/presentation/screens/inicio_screen.dart';
import 'package:vetapp/features/home/presentation/widgets/accesos_rapidos.dart';
import 'package:vetapp/features/home/presentation/widgets/proximas_citas.dart';
import 'package:vetapp/features/inventory/presentation/providers/inventario_providers.dart';
import 'package:vetapp/features/patients/presentation/providers/mascotas_providers.dart';
import 'package:vetapp/features/team/domain/miembro.dart';
import 'package:vetapp/features/team/presentation/providers/team_providers.dart';
import 'package:vetapp/features/vaccination/presentation/providers/vacuna_providers.dart';
import 'package:vetapp/main.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_citas.dart';
import 'helpers/fake_clientes.dart';
import 'helpers/fake_cobros.dart';
import 'helpers/fake_inicio.dart';
import 'helpers/fake_inventario.dart';
import 'helpers/fake_mascotas.dart';
import 'helpers/fake_plan.dart';
import 'helpers/fake_recordatorios.dart';
import 'helpers/fake_team.dart';
import 'helpers/fake_vacunas.dart';

/// Inicio vive en la rama 0 del `StatefulShellRoute`. Sus accesos empujan
/// rutas raíz o de otra rama y sus filas cambian de rama con `go`: con el
/// `routerProvider` real (y `AppShell`) se prueba que nada dispara el assert
/// `!keyReservation.contains(key)` y que Atrás vuelve a Inicio.

final _proxima = Cita(
  id: 'cita-prox',
  clinicaId: 'cli-1',
  clienteId: 'c-maria',
  veterinarioId: 'vet-1',
  fechaHora: deBogota(2026, 11, 16, 10),
  duracionMin: 30,
  modalidad: ModalidadCita.consultorio,
  motivo: 'Control',
  estado: EstadoCita.confirmada,
  clienteNombre: 'María Pérez',
  mascotas: const [
    MascotaDeCita(id: 'm-luna', nombre: 'Luna', especie: 'perro'),
  ],
);

Widget _app() {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      ...planOverrides(),
      ...inicioOverrides(citas: FakeCitaRepository(citas: [_proxima])),
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: vetProfile),
      ),
      recordatoriosServiceProvider.overrideWithValue(
        FakeRecordatoriosService(),
      ),
      clienteRepositoryProvider.overrideWithValue(FakeClienteRepository()),
      mascotaRepositoryProvider.overrideWithValue(FakeMascotaRepository()),
      teamRepositoryProvider.overrideWithValue(FakeTeamRepository()),
      esClinicaMultiVetProvider.overrideWithValue(false),
      miembrosActivosProvider.overrideWithValue(const <Miembro>[]),
      indicesColorVetProvider.overrideWithValue(const <String, int>{}),
      inventarioRepositoryProvider.overrideWithValue(
        FakeInventarioRepository(),
      ),
      vacunaRepositoryProvider.overrideWithValue(FakeVacunaRepository()),
      cobrosRepositoryProvider.overrideWithValue(FakeCobrosRepository()),
      clockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 16, 14)),
    ],
    child: const VetApp(),
  );
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

/// Ubicación de la página superior (incluye las empujadas con `push`).
String _ubicacion(WidgetTester tester) => _container(
  tester,
).read(routerProvider).routerDelegate.currentConfiguration.last.matchedLocation;

Future<void> _abrirInicio(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
  _container(tester).read(routerProvider).go('/inicio');
  await tester.pumpAndSettle();
  expect(_ubicacion(tester), '/inicio');
  expect(find.byType(InicioScreen), findsOneWidget);
}

Future<void> _volver(WidgetTester tester) async {
  _container(tester).read(routerProvider).pop();
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  expect(_ubicacion(tester), '/inicio');
  expect(find.byType(InicioScreen), findsOneWidget);
}

Finder _acceso(String label) => find.widgetWithText(AccesoRapido, label);

void main() {
  for (final (label, ruta) in [
    ('Paciente', '/clientes/nuevo'),
    ('Cita', '/citas/nueva'),
    ('Cobro', '/cobros/nuevo'),
  ]) {
    testWidgets('el acceso $label abre $ruta con un solo AppShell y Atrás '
        'vuelve a Inicio', (tester) async {
      await _abrirInicio(tester);

      await tester.tap(_acceso(label));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_ubicacion(tester), ruta);
      expect(find.byType(AppShell, skipOffstage: false), findsOneWidget);

      await _volver(tester);
    });
  }

  testWidgets('el acceso Vacunar abre el buscador sobre Inicio', (
    tester,
  ) async {
    await _abrirInicio(tester);
    await tester.tap(_acceso('Vacunar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('¿A quién vacuna?'), findsOneWidget);
    expect(_ubicacion(tester), '/inicio');
  });

  testWidgets('una próxima cita cambia a la pestaña Agenda en su detalle', (
    tester,
  ) async {
    await _abrirInicio(tester);
    await tester.tap(find.byType(ProximaCitaFila));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_ubicacion(tester), '/agenda/cita-prox');
    expect(find.byType(AppShell, skipOffstage: false), findsOneWidget);
  });

  testWidgets('Ver agenda cambia a la pestaña Agenda', (tester) async {
    await _abrirInicio(tester);
    await tester.tap(find.text('Ver agenda'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_ubicacion(tester), '/agenda');
    expect(find.byType(AppShell, skipOffstage: false), findsOneWidget);
  });
}
