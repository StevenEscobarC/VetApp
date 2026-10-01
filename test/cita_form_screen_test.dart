import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/core/utils/zona_bogota.dart';
import 'package:vetapp/core/widgets/chips/app_filter_chip.dart';
import 'package:vetapp/features/appointments/domain/cita_failure.dart';
import 'package:vetapp/features/appointments/domain/entities/cita.dart';
import 'package:vetapp/features/appointments/presentation/agenda_routes.dart';
import 'package:vetapp/features/appointments/presentation/providers/citas_providers.dart';
import 'package:vetapp/features/appointments/presentation/screens/cita_form_screen.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/clients/domain/entities/cliente.dart';
import 'package:vetapp/features/clients/presentation/providers/clientes_providers.dart';
import 'package:vetapp/features/patients/domain/entities/mascota.dart';
import 'package:vetapp/features/patients/presentation/providers/mascotas_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_citas.dart';
import 'helpers/fake_clientes.dart';
import 'helpers/fake_mascotas.dart';
import 'helpers/router_harness.dart';

const _maria = Cliente(
  id: 'c-maria',
  clinicaId: 'cli-1',
  nombre: 'María Pérez',
  telefono: '3001234567',
  direccion: 'Calle 10 # 20-30',
);
const _nuevo = Cliente(
  id: 'c-nuevo',
  clinicaId: 'cli-1',
  nombre: 'Nuevo Dueño',
  telefono: '3109876543',
);

const _luna = Mascota(
  id: 'm-luna',
  duenoId: 'c-maria',
  clinicaId: 'cli-1',
  nombre: 'Luna',
  especie: Especie.perro,
);
const _rocky = Mascota(
  id: 'm-rocky',
  duenoId: 'c-maria',
  clinicaId: 'cli-1',
  nombre: 'Rocky',
  especie: Especie.perro,
);
const _bruno = Mascota(
  id: 'm-nuevo',
  duenoId: 'c-nuevo',
  clinicaId: 'cli-1',
  nombre: 'Bruno',
  especie: Especie.gato,
);

const _conFicha =
    '/agenda/nueva?fecha=2026-09-30&clienteId=c-maria&mascotaId=m-luna';

List<Override> _overrides(
  FakeCitaRepository repo,
  FakeMascotaRepository mascotas,
) => [
  citaRepositoryProvider.overrideWithValue(repo),
  clienteRepositoryProvider.overrideWithValue(
    FakeClienteRepository(clientes: [_maria, _nuevo]),
  ),
  mascotaRepositoryProvider.overrideWithValue(mascotas),
  authProfileProvider.overrideWith(
    () => FakeAuthProfileNotifier(profile: vetProfile),
  ),
  clockProvider.overrideWithValue(() => deBogota(2026, 9, 30, 9, 35)),
];

Widget _app({
  required FakeCitaRepository repo,
  FakeMascotaRepository? mascotas,
  String initial = '/agenda/nueva?fecha=2026-09-30',
  List<RouteBase>? routes,
}) => routerHarness(
  locale: const Locale('es', 'CO'),
  initialLocation: initial,
  routes: routes ?? [agendaRoute],
  overrides: _overrides(repo, mascotas ?? FakeMascotaRepository(mascotas: [_luna])),
);

void _grande(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

VoidCallback? _guardar(WidgetTester tester) => tester
    .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Guardar cita'))
    .onPressed;

bool _chipSel(WidgetTester tester, String label) => tester
    .widget<AppFilterChip>(find.widgetWithText(AppFilterChip, label))
    .selected;

Future<void> _tocarGuardar(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar cita'));
  await tester.pumpAndSettle();
}

Future<void> _sumar(WidgetTester tester, int veces) async {
  for (var i = 0; i < veces; i++) {
    await tester.tap(find.byTooltip('Sumar 15 minutos'));
    await tester.pump();
  }
}

/// Cita pendiente de Max a las 10:45 (30 min): se cruza con Luna 10:30.
final _maxCruce = citaCanceladaHoy.copyWith(
  fechaHora: deBogota(2026, 9, 30, 10, 45),
  estado: EstadoCita.pendiente,
);

void main() {
  group('CitaFormScreen - flujo básico', () {
    testWidgets('Guardar cita deshabilitado hasta elegir cliente y mascota', (
      tester,
    ) async {
      _grande(tester);
      await tester.pumpWidget(
        _app(repo: FakeCitaRepository(citas: citasSemanaFixture)),
      );
      await tester.pumpAndSettle();
      expect(_guardar(tester), isNull);
    });

    testWidgets('busca cliente, lo selecciona y preselecciona su única mascota', (
      tester,
    ) async {
      _grande(tester);
      await tester.pumpWidget(
        _app(repo: FakeCitaRepository(citas: citasSemanaFixture)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'Mar');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('María Pérez'), findsOneWidget);

      await tester.tap(find.text('María Pérez'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Quitar cliente'), findsOneWidget);
      expect(find.text('Luna'), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      expect(_guardar(tester), isNotNull);
    });

    testWidgets('sin coincidencias muestra el mensaje vacío', (tester) async {
      _grande(tester);
      await tester.pumpWidget(_app(repo: FakeCitaRepository()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'zzz');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('No encontramos a nadie con ese nombre.'), findsOneWidget);
    });

    testWidgets('el stepper sugiere el primer hueco y avanza de a 15 min', (
      tester,
    ) async {
      _grande(tester);
      await tester.pumpWidget(
        _app(
          repo: FakeCitaRepository(citas: citasSemanaFixture),
          initial: _conFicha,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('9:45 a. m.'), findsOneWidget);
      expect(find.text('Primer hueco libre sugerido'), findsOneWidget);
      await _sumar(tester, 1);
      expect(find.text('10:00 a. m.'), findsOneWidget);
      expect(find.text('Hora elegida'), findsOneWidget);
      expect(find.text('Termina a las 10:30 a. m.'), findsOneWidget);
    });

    testWidgets('guarda con los valores por defecto y vuelve a la agenda', (
      tester,
    ) async {
      _grande(tester);
      final repo = FakeCitaRepository(citas: citasSemanaFixture);
      await tester.pumpWidget(_app(repo: repo, initial: _conFicha));
      await tester.pumpAndSettle();

      await _tocarGuardar(tester);

      expect(repo.creadas, hasLength(1));
      final c = repo.creadas.single;
      expect(c.clienteId, 'c-maria');
      expect(c.mascotaIds, ['m-luna']);
      expect(c.fechaHora, deBogota(2026, 9, 30, 9, 45));
      expect(c.modalidad, ModalidadCita.consultorio);
      expect(c.direccion, '');
      expect(c.motivo, 'Consulta general');
      expect(c.duracionMin, 30);
      expect(find.text('Cita agendada'), findsOneWidget);
      expect(find.text('Hoy, mié 30/09'), findsOneWidget);
    });

    testWidgets('un CitaFailure se muestra y el botón se reactiva', (
      tester,
    ) async {
      _grande(tester);
      final repo = FakeCitaRepository(
        citas: citasSemanaFixture,
        errorCrear: const CitaFailure('Revisa los datos de la cita.'),
      );
      await tester.pumpWidget(_app(repo: repo, initial: _conFicha));
      await tester.pumpAndSettle();

      await _tocarGuardar(tester);

      expect(find.text('Revisa los datos de la cita.'), findsOneWidget);
      expect(_guardar(tester), isNotNull);
      expect(repo.creadas, isEmpty);
    });

    testWidgets('abierta desde una ficha preselecciona cliente y mascota', (
      tester,
    ) async {
      _grande(tester);
      await tester.pumpWidget(
        _app(
          repo: FakeCitaRepository(),
          mascotas: FakeMascotaRepository(mascotas: [_luna, _rocky]),
          initial: _conFicha,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('María Pérez'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      final marcas = tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .map((c) => c.value)
          .toList();
      expect(marcas, [true, false]);
    });
  });

  group('CitaFormScreen - motivo, duración, dónde', () {
    testWidgets('el motivo fija la duración y se puede sobrescribir', (
      tester,
    ) async {
      _grande(tester);
      final repo = FakeCitaRepository(citas: citasSemanaFixture);
      await tester.pumpWidget(_app(repo: repo, initial: _conFicha));
      await tester.pumpAndSettle();

      expect(_chipSel(tester, 'Consulta general'), isTrue);
      await tester.tap(find.text('Vacunación'));
      await tester.pump();
      expect(_chipSel(tester, '15 min'), isTrue);
      await tester.tap(find.text('Cirugía'));
      await tester.pump();
      expect(_chipSel(tester, '1 h 30 min'), isTrue);

      await tester.tap(find.text('45 min'));
      await tester.pump();
      await _tocarGuardar(tester);
      expect(repo.creadas.single.duracionMin, 45);
      expect(repo.creadas.single.motivo, 'Cirugía');
    });

    testWidgets('Otro pide el motivo y guarda el texto escrito', (tester) async {
      _grande(tester);
      final repo = FakeCitaRepository(citas: citasSemanaFixture);
      await tester.pumpWidget(_app(repo: repo, initial: _conFicha));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Otro'));
      await tester.pump();
      expect(find.text('¿Cuál es el motivo?'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Revisión de oído');
      await tester.pump();
      await _tocarGuardar(tester);
      expect(repo.creadas.single.motivo, 'Revisión de oído');
    });

    testWidgets('A domicilio precarga la dirección y la exige', (tester) async {
      _grande(tester);
      final repo = FakeCitaRepository(citas: citasSemanaFixture);
      await tester.pumpWidget(_app(repo: repo, initial: _conFicha));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(find.text('Calle 10 # 20-30'), findsOneWidget);
      expect(find.text('Solo para esta cita'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '');
      await tester.pump();
      expect(
        find.text('Escribe la dirección para la visita a domicilio.'),
        findsOneWidget,
      );
      expect(_guardar(tester), isNull);

      await tester.enterText(find.byType(TextFormField), '  Carrera 5 # 1-2 ');
      await tester.pump();
      await _tocarGuardar(tester);
      expect(repo.creadas.single.modalidad, ModalidadCita.domicilio);
      expect(repo.creadas.single.direccion, 'Carrera 5 # 1-2');
    });
  });

  group('CitaFormScreen - cruces (D-09)', () {
    testWidgets('advierte con una cita y permite cambiar hora o agendar igual', (
      tester,
    ) async {
      _grande(tester);
      final repo = FakeCitaRepository(citas: citasSemanaFixture);
      await tester.pumpWidget(_app(repo: repo, initial: _conFicha));
      await tester.pumpAndSettle();

      await _sumar(tester, 3); // 9:45 -> 10:30
      expect(find.text('10:30 a. m.'), findsWidgets);
      await _tocarGuardar(tester);

      expect(find.text('Se cruza con otra cita'), findsOneWidget);
      expect(
        find.text('Se cruza con Luna a las 10:30 a. m. ¿Agendar igual?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cambiar hora'));
      await tester.pumpAndSettle();
      expect(repo.creadas, isEmpty);

      await _tocarGuardar(tester);
      await tester.tap(find.text('Agendar igual'));
      await tester.pumpAndSettle();
      expect(repo.creadas, hasLength(1));
      expect(repo.creadas.single.fechaHora, deBogota(2026, 9, 30, 10, 30));
    });

    testWidgets('lista varias citas que se cruzan', (tester) async {
      _grande(tester);
      final repo = FakeCitaRepository(citas: [...citasSemanaFixture, _maxCruce]);
      await tester.pumpWidget(_app(repo: repo, initial: _conFicha));
      await tester.pumpAndSettle();

      await _sumar(tester, 3);
      await _tocarGuardar(tester);
      expect(
        find.text(
          'Se cruza con 2 citas: Luna 10:30 a. m., Max 10:45 a. m. '
          '¿Agendar igual?',
        ),
        findsOneWidget,
      );
    });
  });

  group('CitaFormScreen - retornos de alta', () {
    List<RouteBase> rutas() => [
      GoRoute(
        path: '/agenda',
        builder: (_, _) => const Text('AGENDA'),
        routes: [
          GoRoute(
            path: 'nueva',
            builder: (_, state) => CitaFormScreen(
              clienteIdInicial: state.uri.queryParameters['clienteId'],
              fechaInicial: DateTime.utc(2026, 9, 30),
            ),
            routes: [
              GoRoute(
                path: 'cliente',
                builder: (context, _) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () => context.pop((
                      clienteId: 'c-nuevo',
                      mascotaId: 'm-nuevo',
                    )),
                    child: const Text('Guardar stub'),
                  ),
                ),
              ),
              GoRoute(
                path: 'mascota',
                builder: (context, _) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Volver stub'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ];

    testWidgets('Nuevo cliente y mascota vuelve con ambos seleccionados', (
      tester,
    ) async {
      _grande(tester);
      final repo = FakeCitaRepository(citas: citasSemanaFixture);
      await tester.pumpWidget(
        _app(
          repo: repo,
          mascotas: FakeMascotaRepository(mascotas: [_luna, _bruno]),
          routes: rutas(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Vacunación'));
      await tester.pump();
      await tester.tap(find.text('+ Nuevo cliente y mascota'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar stub'));
      await tester.pumpAndSettle();

      expect(find.text('Nuevo Dueño'), findsOneWidget);
      expect(find.text('Bruno'), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      expect(_chipSel(tester, 'Vacunación'), isTrue);

      await _tocarGuardar(tester);
      expect(repo.creadas.single.clienteId, 'c-nuevo');
      expect(repo.creadas.single.mascotaIds, ['m-nuevo']);
      expect(repo.creadas.single.motivo, 'Vacunación');
    });

    testWidgets('Agregar mascota refresca la lista al volver', (tester) async {
      _grande(tester);
      final mascotas = FakeMascotaRepository(mascotas: [_luna]);
      await tester.pumpWidget(
        _app(
          repo: FakeCitaRepository(),
          mascotas: mascotas,
          routes: rutas(),
          initial: '/agenda/nueva?clienteId=c-maria',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rocky'), findsNothing);

      await tester.tap(find.text('+ Agregar mascota'));
      await tester.pumpAndSettle();
      mascotas.mascotas.add(_rocky);
      await tester.tap(find.text('Volver stub'));
      await tester.pumpAndSettle();

      expect(find.text('Rocky'), findsOneWidget);
    });
  });

  group('CitaFormScreen - edición', () {
    final mascotasDeMaria = FakeMascotaRepository(mascotas: [_luna, _rocky]);

    Widget editar(FakeCitaRepository repo, String id) => _app(
      repo: repo,
      mascotas: mascotasDeMaria,
      initial: '/agenda/$id/editar',
    );

    VoidCallback? guardarCambios(WidgetTester tester) => tester
        .widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Guardar cambios'),
        )
        .onPressed;

    testWidgets('precarga la cita con el cliente fijo', (tester) async {
      _grande(tester);
      final repo = FakeCitaRepository(citas: [citaRockyLunaHoy]);
      await tester.pumpWidget(editar(repo, 'cita-2'));
      await tester.pumpAndSettle();

      expect(find.text('Editar cita'), findsOneWidget);
      expect(find.text('María Pérez'), findsOneWidget);
      expect(find.byTooltip('Quitar cliente'), findsNothing);
      expect(find.text('Cambiar'), findsNothing);
      // Rocky y Luna, ambas marcadas.
      final marcas = tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .map((c) => c.value)
          .toList();
      expect(marcas, [true, true]);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(find.text('Calle 10 # 20-30'), findsOneWidget);
      expect(_chipSel(tester, '1 h'), isTrue);
      expect(find.text('3:00 p. m.'), findsWidgets);
      expect(find.text('Hora elegida'), findsOneWidget);
      expect(guardarCambios(tester), isNotNull);
    });

    testWidgets('guarda cambios con actualizar y vuelve a la agenda', (
      tester,
    ) async {
      _grande(tester);
      final repo = FakeCitaRepository(citas: [citaRockyLunaHoy]);
      await tester.pumpWidget(editar(repo, 'cita-2'));
      await tester.pumpAndSettle();

      await _sumar(tester, 1);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar cambios'));
      await tester.pumpAndSettle();

      expect(repo.actualizadas, hasLength(1));
      final a = repo.actualizadas.single;
      expect(a.citaId, 'cita-2');
      expect(a.fechaHora, deBogota(2026, 9, 30, 15, 15));
      expect(a.mascotaIds.toSet(), {'m-rocky', 'm-luna'});
      expect(repo.creadas, isEmpty);
      expect(find.text('Cita actualizada'), findsOneWidget);
      expect(find.text('Hoy, mié 30/09'), findsOneWidget);
    });

    testWidgets('la cita misma no dispara el cruce', (tester) async {
      _grande(tester);
      final repo = FakeCitaRepository(citas: [citaRockyLunaHoy]);
      await tester.pumpWidget(editar(repo, 'cita-2'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar cambios'));
      await tester.pumpAndSettle();

      expect(find.text('Se cruza con otra cita'), findsNothing);
      expect(repo.actualizadas, hasLength(1));
    });

    testWidgets('un cruce con otra cita ofrece Guardar igual', (tester) async {
      _grande(tester);
      final otra = citaCanceladaHoy.copyWith(
        fechaHora: deBogota(2026, 9, 30, 15, 30),
        estado: EstadoCita.pendiente,
      );
      final repo = FakeCitaRepository(citas: [citaRockyLunaHoy, otra]);
      await tester.pumpWidget(editar(repo, 'cita-2'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar cambios'));
      await tester.pumpAndSettle();
      expect(find.text('Se cruza con otra cita'), findsOneWidget);
      expect(find.text('Guardar igual'), findsOneWidget);
      expect(repo.actualizadas, isEmpty);

      await tester.tap(find.text('Guardar igual'));
      await tester.pumpAndSettle();
      expect(repo.actualizadas, hasLength(1));
    });

    testWidgets('un motivo fuera de la lista carga como Otro', (tester) async {
      _grande(tester);
      final cita = citaLunaHoy.copyWith(motivo: 'Revisión post-operatoria');
      await tester.pumpWidget(
        _app(
          repo: FakeCitaRepository(citas: [cita]),
          mascotas: mascotasDeMaria,
          initial: '/agenda/cita-1/editar',
        ),
      );
      await tester.pumpAndSettle();

      expect(_chipSel(tester, 'Otro'), isTrue);
      expect(find.text('Revisión post-operatoria'), findsOneWidget);
    });

    testWidgets('una cita terminal no se puede editar', (tester) async {
      _grande(tester);
      await tester.pumpWidget(
        editar(FakeCitaRepository(citas: [citaCanceladaHoy]), 'cita-3'),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Solo se pueden editar citas pendientes o confirmadas.'),
        findsOneWidget,
      );
      expect(find.text('Guardar cambios'), findsNothing);
    });
  });
}
