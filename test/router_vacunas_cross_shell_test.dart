import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/core/router/app_router.dart';
import 'package:vetapp/features/appointments/presentation/providers/citas_providers.dart';
import 'package:vetapp/features/appointments/presentation/providers/recordatorios_providers.dart';
import 'package:vetapp/features/appointments/presentation/screens/cita_form_screen.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/clients/domain/entities/cliente.dart';
import 'package:vetapp/features/clients/presentation/providers/clientes_providers.dart';
import 'package:vetapp/features/patients/domain/entities/mascota.dart';
import 'package:vetapp/features/patients/presentation/providers/mascotas_providers.dart';
import 'package:vetapp/features/team/domain/miembro.dart';
import 'package:vetapp/features/team/presentation/providers/team_providers.dart';
import 'package:vetapp/features/vaccination/domain/entities/carne.dart';
import 'package:vetapp/features/vaccination/domain/entities/protocolo.dart';
import 'package:vetapp/features/vaccination/presentation/providers/vacuna_providers.dart';
import 'package:vetapp/features/vaccination/presentation/screens/carne_screen.dart';
import 'package:vetapp/features/vaccination/presentation/screens/vacunas_pendientes_screen.dart';
import 'package:vetapp/main.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_citas.dart';
import 'helpers/fake_clientes.dart';
import 'helpers/fake_mascotas.dart';
import 'helpers/fake_recordatorios.dart';
import 'helpers/fake_team.dart';
import 'helpers/fake_vacunas.dart';

/// G5: `/vacunas` es una ruta raíz apilada sobre el `StatefulShellRoute`.
/// Empujar desde ahí una ruta de una rama del shell (`/agenda/nueva`,
/// `/pacientes/:id/carne`) duplicaba la página del shell en el Navigator raíz
/// (`'!keyReservation.contains(key)'`). Usa el `routerProvider` real (con
/// `AppShell`), no el `routerHarness` plano que ocultaba el fallo.

const _rita = Cliente(
  id: 'c-rocky',
  clinicaId: 'cli-1',
  nombre: 'Rita Gómez',
  telefono: '3001112222',
);
const _rockyMascota = Mascota(
  id: 'm-rocky',
  duenoId: 'c-rocky',
  clinicaId: 'cli-1',
  nombre: 'Rocky',
  especie: Especie.perro,
);

final _rocky = PendienteVacuna(
  mascotaId: 'm-rocky',
  mascotaNombre: 'Rocky',
  mascotaEspecie: 'perro',
  clienteId: 'c-rocky',
  clienteNombre: 'Rita Gómez',
  clienteTelefono: '3001112222',
  codigoProtocolo: 'polivalente',
  biologicoNombre: 'Polivalente',
  tipo: TipoDosis.vacuna,
  ultimaDosisId: 'd-rocky',
  posicion: 1,
  dosisSerie: 3,
  etiquetaProxima: 'Dosis 2 de 3',
  proximaFecha: DateTime.utc(2026, 9, 12),
  estado: EstadoCarne.vencida,
  diasVencida: 19,
);

Widget _app() {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: vetProfile),
      ),
      citaRepositoryProvider.overrideWithValue(FakeCitaRepository()),
      recordatoriosServiceProvider.overrideWithValue(
        FakeRecordatoriosService(),
      ),
      clienteRepositoryProvider.overrideWithValue(
        FakeClienteRepository(clientes: [_rita]),
      ),
      mascotaRepositoryProvider.overrideWithValue(
        FakeMascotaRepository(mascotas: [_rockyMascota]),
      ),
      teamRepositoryProvider.overrideWithValue(FakeTeamRepository()),
      esClinicaMultiVetProvider.overrideWithValue(false),
      miembrosActivosProvider.overrideWithValue(const <Miembro>[]),
      indicesColorVetProvider.overrideWithValue(const <String, int>{}),
      vacunaRepositoryProvider.overrideWithValue(
        FakeVacunaRepository(
          pendientesData: [_rocky],
          resumenData: const ResumenVacunas(
            vencidas: 1,
            proximas: 0,
            ocultasAntiguas: 0,
          ),
        ),
      ),
      clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 1, 17)),
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

/// Inicio (dentro del shell) -> empuja `/vacunas` (ruta raíz).
Future<void> _abrirPendientes(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
  expect(_ubicacion(tester), '/inicio');
  _container(tester).read(routerProvider).push('/vacunas');
  await tester.pumpAndSettle();
  expect(find.byType(VacunasPendientesScreen), findsOneWidget);
}

Finder _boton(String label) => find.descendant(
  of: find.ancestor(of: find.text('Rocky'), matching: find.byType(Card)).first,
  matching: find.text(label),
);

void main() {
  testWidgets('Agendar desde /vacunas abre Nueva cita prefijada sin romper '
      'el Navigator y Atrás vuelve a pendientes', (tester) async {
    await _abrirPendientes(tester);

    await tester.tap(_boton('Agendar'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_ubicacion(tester), '/citas/nueva');
    final form = tester.widget<CitaFormScreen>(find.byType(CitaFormScreen));
    expect(form.clienteIdInicial, 'c-rocky');
    expect(form.mascotaIdInicial, 'm-rocky');
    expect(form.motivoInicial, 'Vacunación');
    expect(form.rutaBase, '/citas/nueva');

    _container(tester).read(routerProvider).pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(VacunasPendientesScreen), findsOneWidget);
  });

  testWidgets('tocar la tarjeta desde /vacunas abre el carné sin romper', (
    tester,
  ) async {
    await _abrirPendientes(tester);

    await tester.tap(find.text('Polivalente · Dosis 2 de 3'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_ubicacion(tester), '/carne/m-rocky');
    expect(find.byType(CarneScreen), findsOneWidget);
  });

  testWidgets('tras guardar, ir a la agenda desde /citas/nueva no rompe', (
    tester,
  ) async {
    await _abrirPendientes(tester);
    await tester.tap(_boton('Agendar'));
    await tester.pumpAndSettle();

    // Lo que hace CitaFormScreen al guardar: `context.go('/agenda?dia=...')`.
    _container(tester).read(routerProvider).go('/agenda?dia=2026-10-01');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_ubicacion(tester), '/agenda');
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
