import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetapp/core/data/clock_provider.dart';
import 'package:vetapp/core/router/app_router.dart';
import 'package:vetapp/features/appointments/presentation/providers/citas_providers.dart';
import 'package:vetapp/features/appointments/presentation/providers/recordatorios_providers.dart';
import 'package:vetapp/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/billing/domain/cobro_failure.dart';
import 'package:vetapp/features/billing/domain/entities/servicio.dart';
import 'package:vetapp/features/billing/presentation/providers/cobros_providers.dart';
import 'package:vetapp/features/billing/presentation/screens/cobros_screen.dart';
import 'package:vetapp/features/billing/presentation/screens/servicios_screen.dart';
import 'package:vetapp/features/clients/presentation/providers/clientes_providers.dart';
import 'package:vetapp/features/home/presentation/app_shell.dart';
import 'package:vetapp/features/inventory/presentation/providers/inventario_providers.dart';
import 'package:vetapp/features/patients/presentation/providers/mascotas_providers.dart';
import 'package:vetapp/features/plan/domain/mi_plan.dart';
import 'package:vetapp/features/team/domain/miembro.dart';
import 'package:vetapp/features/team/presentation/providers/team_providers.dart';
import 'package:vetapp/features/vaccination/presentation/providers/vacuna_providers.dart';
import 'package:vetapp/main.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_citas.dart';
import 'helpers/fake_clientes.dart';
import 'helpers/fake_cobros.dart';
import 'helpers/fake_inventario.dart';
import 'helpers/fake_mascotas.dart';
import 'helpers/fake_plan.dart';
import 'helpers/fake_recordatorios.dart';
import 'helpers/fake_team.dart';
import 'helpers/fake_vacunas.dart';
import 'helpers/router_harness.dart';

/// App real con `routerProvider` (y `AppShell`), como
/// `router_cobros_cross_shell_test.dart`: el harness plano ocultaría una
/// página de shell duplicada (G5).
Widget _appReal() {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      ...planOverrides(),
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: vetProfile),
      ),
      citaRepositoryProvider.overrideWithValue(FakeCitaRepository()),
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
      cobrosRepositoryProvider.overrideWithValue(
        FakeCobrosRepository(
          cobros: [cobroDePrueba(id: 'c1')],
          servicios: [servicioDePrueba()],
        ),
      ),
      clockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 13, 17)),
    ],
    child: const VetApp(),
  );
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

String _ubicacion(WidgetTester tester) => _container(
  tester,
).read(routerProvider).routerDelegate.currentConfiguration.last.matchedLocation;

const _intro =
    'Los servicios que agregas con un toque al cobrar. En cada cobro puedes '
    'cambiar el precio.';
const _soloAdmin =
    'Solo el administrador puede cambiar los servicios y precios.';
const _ayudaPrecio =
    'En pesos, sin decimales. Es el precio sugerido; en cada cobro se puede '
    'cambiar.';

final _tres = [
  servicioDePrueba(id: 's1', nombre: 'Consulta', precioCop: 50000),
  servicioDePrueba(id: 's2', nombre: 'Vacunación', precioCop: 35000),
  servicioDePrueba(id: 's3', nombre: 'Baño', precioCop: 40000),
];

FakeCobrosRepository _repo({
  List<Servicio>? servicios,
  Object? errorServicios,
  Object? errorGuardarServicio,
}) => FakeCobrosRepository(
  servicios: servicios ?? _tres,
  errorServicios: errorServicios,
  errorGuardarServicio: errorGuardarServicio,
);

Future<void> _abrir(
  WidgetTester tester,
  FakeCobrosRepository repo, {
  AuthProfile perfil = vetAdminProfile,
  MiPlan? plan,
}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    routerHarness(
      initialLocation: '/servicios',
      routes: [
        GoRoute(path: '/servicios', builder: (_, _) => const ServiciosScreen()),
      ],
      overrides: [
        ...planOverrides(plan: plan),
        authProfileProvider.overrideWith(
          () => FakeAuthProfileNotifier(profile: perfil),
        ),
        cobrosRepositoryProvider.overrideWithValue(repo),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

Finder _campo(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
  matching: find.byType(EditableText),
);

EditableText _editable(WidgetTester tester, String label) =>
    tester.widget<EditableText>(_campo(label));

Future<void> _tocarFab(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

Future<void> _guardar(WidgetTester tester) async {
  await tester.tap(find.text('Guardar servicio'));
  await tester.pumpAndSettle();
}

List<Map<String, Object?>> _llamadas(FakeCobrosRepository repo, String m) => [
  for (final l in repo.llamadas)
    if (l.metodo == m) l.args,
];

void main() {
  group('lista del administrador', () {
    testWidgets('intro, filas A–Z con precio y chevron; tocar abre Editar '
        'servicio precargado', (tester) async {
      await _abrir(tester, _repo());

      expect(find.text('Servicios'), findsOneWidget);
      expect(find.text(_intro), findsOneWidget);
      expect(find.text(_soloAdmin), findsNothing);
      expect(find.text('\$ 50.000'), findsOneWidget);
      expect(find.text('\$ 35.000'), findsOneWidget);
      expect(find.text('\$ 40.000'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(3));

      double y(String t) => tester.getTopLeft(find.text(t)).dy;
      expect(y('Baño'), lessThan(y('Consulta')));
      expect(y('Consulta'), lessThan(y('Vacunación')));

      await tester.tap(find.text('Consulta'));
      await tester.pumpAndSettle();
      expect(find.text('Editar servicio'), findsOneWidget);
      expect(
        _editable(tester, 'Nombre del servicio').controller.text,
        'Consulta',
      );
      expect(_editable(tester, 'Precio').controller.text, '50000');
      expect(find.text('Quitar servicio'), findsOneWidget);
    });

    testWidgets('FAB Nuevo servicio: crea con id nulo y avisa', (tester) async {
      final repo = _repo(servicios: const []);
      await _abrir(tester, repo);
      expect(
        find.widgetWithText(FloatingActionButton, 'Nuevo servicio'),
        findsOneWidget,
      );

      await _tocarFab(tester);
      // Encabezado de la hoja + FAB.
      expect(find.text('Nuevo servicio'), findsNWidgets(2));
      expect(find.text('Nombre del servicio'), findsOneWidget);
      expect(find.text('Precio'), findsOneWidget);
      expect(find.text(_ayudaPrecio), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Quitar servicio'), findsNothing);
      expect(
        _editable(tester, 'Nombre del servicio').focusNode.hasFocus,
        isTrue,
      );
      expect(_editable(tester, 'Nombre del servicio').maxLines, 1);

      await tester.enterText(_campo('Nombre del servicio'), ' Consulta ');
      await tester.enterText(_campo('Precio'), '50000');
      await _guardar(tester);

      final g = _llamadas(repo, 'guardarServicio');
      expect(g, hasLength(1));
      expect(g.single['id'], isNull);
      expect(g.single['nombre'], 'Consulta');
      expect(g.single['precioCop'], 50000);
      expect(find.text('«Consulta» guardado.'), findsOneWidget);
      expect(find.text('Guardar servicio'), findsNothing);
      // La lista se refresca tras invalidar serviciosProvider.
      expect(find.text('\$ 50.000'), findsOneWidget);
    });

    testWidgets('el precio solo acepta dígitos (máx. 9) y el 0 es válido', (
      tester,
    ) async {
      final repo = _repo(servicios: const []);
      await _abrir(tester, repo);
      await _tocarFab(tester);
      await tester.enterText(_campo('Precio'), '12a.3,4');
      expect(_editable(tester, 'Precio').controller.text, '1234');
      await tester.enterText(_campo('Precio'), '12345678901');
      expect(_editable(tester, 'Precio').controller.text.length, 9);

      await tester.enterText(_campo('Nombre del servicio'), 'Control');
      await tester.enterText(_campo('Precio'), '0');
      await _guardar(tester);
      expect(_llamadas(repo, 'guardarServicio').single['precioCop'], 0);
    });

    testWidgets('editar guarda con el id del servicio', (tester) async {
      final repo = _repo();
      await _abrir(tester, repo);
      await tester.tap(find.text('Consulta'));
      await tester.pumpAndSettle();
      await tester.enterText(_campo('Precio'), '55000');
      await _guardar(tester);
      final g = _llamadas(repo, 'guardarServicio').single;
      expect(g['id'], 's1');
      expect(g['precioCop'], 55000);
      expect(find.text('«Consulta» guardado.'), findsOneWidget);
      expect(find.text('\$ 55.000'), findsOneWidget);
    });
  });

  group('validación', () {
    testWidgets('nombre y precio vacíos', (tester) async {
      final repo = _repo(servicios: const []);
      await _abrir(tester, repo);
      await _tocarFab(tester);
      await _guardar(tester);
      expect(find.text('Escribe el nombre del servicio.'), findsOneWidget);
      expect(find.text('Escribe el precio (puede ser 0).'), findsOneWidget);
      expect(_llamadas(repo, 'guardarServicio'), isEmpty);
    });

    testWidgets('precio demasiado alto (máx. \$ 100.000.000)', (tester) async {
      final repo = _repo(servicios: const []);
      await _abrir(tester, repo);
      await _tocarFab(tester);
      await tester.enterText(_campo('Nombre del servicio'), 'Cirugía');
      // '1000000000' se recorta a 9 dígitos; el mayor que cabe excede el
      // tope del servidor.
      await tester.enterText(_campo('Precio'), '1000000000');
      await tester.enterText(_campo('Precio'), '999999999');
      await _guardar(tester);
      expect(find.text('El valor es demasiado alto.'), findsOneWidget);
      expect(_llamadas(repo, 'guardarServicio'), isEmpty);
    });

    testWidgets('nombre duplicado: mensaje en línea y la hoja sigue', (
      tester,
    ) async {
      final repo = _repo(
        servicios: const [],
        errorGuardarServicio: const CobroFailure(
          'Ya existe',
          tipo: ErrorCobro.nombreDuplicado,
        ),
      );
      await _abrir(tester, repo);
      await _tocarFab(tester);
      await tester.enterText(_campo('Nombre del servicio'), 'Consulta');
      await tester.enterText(_campo('Precio'), '50000');
      await _guardar(tester);
      expect(
        find.text('Ya tienes un servicio con ese nombre.'),
        findsOneWidget,
      );
      expect(find.text('Guardar servicio'), findsOneWidget);
      expect(find.text('«Consulta» guardado.'), findsNothing);
    });

    testWidgets('sin permiso (42501): mensaje del administrador', (
      tester,
    ) async {
      final repo = _repo(
        servicios: const [],
        errorGuardarServicio: const CobroFailure(
          'x',
          tipo: ErrorCobro.sinPermiso,
        ),
      );
      await _abrir(tester, repo);
      await _tocarFab(tester);
      await tester.enterText(_campo('Nombre del servicio'), 'Consulta');
      await tester.enterText(_campo('Precio'), '50000');
      await _guardar(tester);
      expect(
        find.text('Solo el administrador de la clínica puede hacer esto.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('Quitar servicio: confirma, archiva y avisa', (tester) async {
    final repo = _repo();
    await _abrir(tester, repo);
    await tester.tap(find.text('Consulta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitar servicio'));
    await tester.pumpAndSettle();

    expect(find.text('¿Quitar «Consulta»?'), findsOneWidget);
    expect(
      find.text('Ya no aparecerá al cobrar. Los cobros anteriores no cambian.'),
      findsOneWidget,
    );

    // Cancelar del diálogo no archiva.
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancelar'),
      ),
    );
    await tester.pumpAndSettle();
    expect(_llamadas(repo, 'archivarServicio'), isEmpty);
    expect(find.text('Editar servicio'), findsOneWidget);

    await tester.tap(find.text('Quitar servicio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitar'));
    await tester.pumpAndSettle();

    expect(_llamadas(repo, 'archivarServicio').single['id'], 's1');
    expect(_llamadas(repo, 'guardarServicio'), isEmpty);
    expect(find.text('«Consulta» quitado.'), findsOneWidget);
    expect(find.text('Editar servicio'), findsNothing);
    expect(find.text('\$ 50.000'), findsNothing);
  });

  group('no administrador', () {
    testWidgets('solo lectura: ayuda extra, sin chevron, sin FAB y las filas '
        'no abren', (tester) async {
      await _abrir(tester, _repo(), perfil: vetColegaProfile);
      expect(find.text(_intro), findsOneWidget);
      expect(find.text(_soloAdmin), findsOneWidget);
      expect(find.text('\$ 50.000'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.tap(find.text('Consulta'));
      await tester.pumpAndSettle();
      expect(find.text('Editar servicio'), findsNothing);
    });

    testWidgets('vacío: sin sugerencias', (tester) async {
      await _abrir(
        tester,
        _repo(servicios: const []),
        perfil: vetColegaProfile,
      );
      expect(find.text('Aún no hay servicios'), findsOneWidget);
      expect(
        find.text('El administrador de la clínica todavía no los ha agregado.'),
        findsOneWidget,
      );
      expect(find.text('Desparasitación'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  group('vacío del administrador', () {
    testWidgets('4 sugerencias; Vacunación prellena el nombre, sin precio y '
        'con el precio enfocado', (tester) async {
      final repo = _repo(servicios: const []);
      await _abrir(tester, repo);
      expect(find.text('Aún no tienes servicios'), findsOneWidget);
      expect(
        find.text('Agrega los que más cobras para cobrarlos con un toque.'),
        findsOneWidget,
      );
      for (final s in [
        'Consulta',
        'Vacunación',
        'Desparasitación',
        'Cirugía',
      ]) {
        expect(find.text(s), findsOneWidget);
      }

      await tester.tap(find.text('Vacunación'));
      await tester.pumpAndSettle();
      expect(find.text('Nuevo servicio'), findsNWidgets(2));
      expect(
        _editable(tester, 'Nombre del servicio').controller.text,
        'Vacunación',
      );
      expect(_editable(tester, 'Precio').controller.text, isEmpty);
      expect(_editable(tester, 'Precio').focusNode.hasFocus, isTrue);
      // Sin precio inventado: guardar pide el precio.
      await _guardar(tester);
      expect(find.text('Escribe el precio (puede ser 0).'), findsOneWidget);
      expect(_llamadas(repo, 'guardarServicio'), isEmpty);
    });
  });

  testWidgets('plan en solo lectura: FAB con candado abre la hoja del plan; '
      'la lista sigue visible', (tester) async {
    final semantics = tester.ensureSemantics();
    await _abrir(tester, _repo(), plan: planSoloLectura);
    final fab = find.byType(FloatingActionButton);
    expect(
      find.descendant(of: fab, matching: find.byIcon(Icons.lock_outline)),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(fab).label,
      'Nuevo servicio, bloqueado, solo lectura',
    );
    expect(find.text('\$ 50.000'), findsOneWidget);

    await _tocarFab(tester);
    expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
    expect(find.text('Guardar servicio'), findsNothing);
    semantics.dispose();
  });

  testWidgets('error de carga: mensaje y Reintentar vuelve a pedir', (
    tester,
  ) async {
    final repo = _repo(errorServicios: const CobroFailure('x'));
    await _abrir(tester, repo);
    expect(find.text('No pudimos cargar los servicios.'), findsOneWidget);
    final antes = _llamadas(repo, 'servicios').length;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(_llamadas(repo, 'servicios').length, greaterThan(antes));
  });

  group('ruta /servicios (router real)', () {
    Future<void> abrirCobros(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_appReal());
      await tester.pumpAndSettle();
      _container(tester).read(routerProvider).go('/mas');
      await tester.pumpAndSettle();
      _container(tester).read(routerProvider).push('/cobros');
      await tester.pumpAndSettle();
      expect(_ubicacion(tester), '/cobros');
    }

    testWidgets('Cobros > Servicios y precios abre una sola ServiciosScreen '
        'sin duplicar el shell; Atrás vuelve a Cobros', (tester) async {
      await abrirCobros(tester);

      await tester.tap(find.byTooltip('Servicios y precios'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_ubicacion(tester), '/servicios');
      expect(find.byType(ServiciosScreen), findsOneWidget);
      expect(find.byType(AppShell, skipOffstage: false), findsOneWidget);
      expect(find.text('\$ 50.000'), findsOneWidget);

      _container(tester).read(routerProvider).pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_ubicacion(tester), '/cobros');
      expect(find.byType(CobrosScreen), findsOneWidget);
      expect(find.byType(ServiciosScreen), findsNothing);
    });

    testWidgets('/servicios directo (como desde «Agregar servicios» del '
        'formulario) es de primer nivel', (tester) async {
      await abrirCobros(tester);
      _container(tester).read(routerProvider).push('/servicios');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ServiciosScreen), findsOneWidget);
      expect(find.byType(AppShell, skipOffstage: false), findsOneWidget);
    });
  });
}
