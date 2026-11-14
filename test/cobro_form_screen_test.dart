import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/core/errors/limite_plan.dart';
import 'package:vetapp/features/billing/domain/cobro_failure.dart';
import 'package:vetapp/features/billing/domain/entities/cobro.dart';
import 'package:vetapp/features/billing/domain/entities/cobro_item.dart';
import 'package:vetapp/features/billing/domain/entities/servicio.dart';
import 'package:vetapp/features/billing/presentation/cobros_routes.dart';
import 'package:vetapp/features/billing/presentation/providers/borrador_cobro_provider.dart';
import 'package:vetapp/features/billing/presentation/providers/cobros_providers.dart';
import 'package:vetapp/features/billing/presentation/screens/cobro_detail_screen.dart';
import 'package:vetapp/features/billing/presentation/screens/cobro_form_screen.dart';
import 'package:vetapp/features/billing/presentation/widgets/linea_cobro_tile.dart';
import 'package:vetapp/features/billing/presentation/widgets/total_cobro_bar.dart';
import 'package:vetapp/features/clients/domain/entities/cliente.dart';
import 'package:vetapp/features/clients/presentation/providers/clientes_providers.dart';
import 'package:vetapp/features/patients/domain/entities/mascota.dart';
import 'package:vetapp/features/patients/presentation/providers/mascotas_providers.dart';
import 'package:vetapp/core/widgets/chips/app_filter_chip.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_clientes.dart';
import 'helpers/fake_cobros.dart';
import 'helpers/fake_mascotas.dart';
import 'helpers/fake_plan.dart';
import 'helpers/router_harness.dart';

const _laura = Cliente(
  id: 'cli1',
  clinicaId: 'cli-1',
  nombre: 'Laura Gómez',
  telefono: '3001112233',
);
const _pedro = Cliente(
  id: 'cli2',
  clinicaId: 'cli-1',
  nombre: 'Pedro Ruiz',
  telefono: '3109876543',
);
const _rocky = Mascota(
  id: 'm1',
  duenoId: 'cli1',
  clinicaId: 'cli-1',
  nombre: 'Rocky',
  especie: Especie.perro,
);
const _luna = Mascota(
  id: 'm2',
  duenoId: 'cli1',
  clinicaId: 'cli-1',
  nombre: 'Luna',
  especie: Especie.gato,
);

PrefillCobro _prefill({
  TipoCobro tipo = TipoCobro.cuentaCobro,
  String? clienteId,
  String? mascotaId,
  String? citaId,
}) => (
  modo: ModoFormCobro.nuevo,
  tipo: tipo,
  clienteId: clienteId,
  mascotaId: mascotaId,
  citaId: citaId,
  consultaId: null,
  origenId: null,
);

final _servicios = [
  servicioDePrueba(id: 's2', nombre: 'Vacuna', precioCop: 40000),
  servicioDePrueba(),
];

Widget _app({
  PrefillCobro? prefill,
  FakeCobrosRepository? repo,
  List<Servicio>? servicios,
  AuthProfile profile = vetProfile,
}) {
  final p = prefill ?? _prefill();
  return routerHarness(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => context.push('/form'),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/form',
        builder: (_, _) => CobroFormScreen(prefill: p),
      ),
      GoRoute(
        path: '/servicios',
        builder: (_, _) => const Scaffold(body: Text('Pantalla servicios')),
      ),
      GoRoute(
        path: '/cobros/:id',
        builder: (_, s) =>
            Scaffold(body: Text('Detalle ${s.pathParameters['id']}')),
      ),
    ],
    overrides: _overrides(repo: repo, servicios: servicios, profile: profile),
  );
}

List<Override> _overrides({
  FakeCobrosRepository? repo,
  List<Servicio>? servicios,
  AuthProfile profile = vetProfile,
}) {
  var n = 0;
  return [
    ...planOverrides(),
    authProfileProvider.overrideWith(
      () => FakeAuthProfileNotifier(profile: profile),
    ),
    cobrosRepositoryProvider.overrideWithValue(
      repo ?? FakeCobrosRepository(servicios: servicios ?? _servicios),
    ),
    clienteRepositoryProvider.overrideWithValue(
      FakeClienteRepository(clientes: [_laura, _pedro]),
    ),
    clientesProvider.overrideWith(
      () => FakeClientesNotifier(clientes: [_laura, _pedro]),
    ),
    mascotaRepositoryProvider.overrideWithValue(
      FakeMascotaRepository(mascotas: [_rocky, _luna]),
    ),
    claveIdempotenciaProvider.overrideWithValue(() => 'clave-${++n}'),
  ];
}

Future<void> _abrir(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

Finder _enBarra(Finder f) =>
    find.descendant(of: find.byType(TotalCobroBar), matching: f);

Finder _campo(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(TextField),
);

Future<void> _agregarConsulta(WidgetTester tester) async {
  await tester.tap(find.text('Consulta · \$ 50.000'));
  await tester.pumpAndSettle();
}

void main() {
  group('título y tipo', () {
    testWidgets('nueva cuenta de cobro; el toggle cambia título y CTA y '
        'conserva las líneas', (tester) async {
      await _abrir(tester, _app(prefill: _prefill(clienteId: 'cli1')));
      expect(find.text('Nueva cuenta de cobro'), findsOneWidget);
      expect(find.text('Emitir cuenta de cobro'), findsOneWidget);
      expect(find.text('Cotización'), findsOneWidget);
      expect(find.text('Cuenta de cobro'), findsOneWidget);

      await _agregarConsulta(tester);
      await tester.tap(find.text('Cotización'));
      await tester.pumpAndSettle();

      expect(find.text('Nueva cotización'), findsOneWidget);
      expect(find.text('Guardar cotización'), findsOneWidget);
      expect(find.byType(LineaCobroTile), findsOneWidget);
    });
  });

  group('cliente', () {
    testWidgets('vacío: la fila de 48dp abre la hoja, busca y elige', (
      tester,
    ) async {
      await _abrir(tester, _app());
      final fila = find.ancestor(
        of: find.text('Elige el cliente'),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(fila.first).height, greaterThanOrEqualTo(48));

      await tester.tap(find.text('Elige el cliente'));
      await tester.pumpAndSettle();
      expect(find.text('Elegir cliente'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'gom');
      await tester.pumpAndSettle();
      expect(find.text('Laura Gómez'), findsOneWidget);
      expect(find.text('Pedro Ruiz'), findsNothing);

      await tester.enterText(find.byType(TextField).last, 'xyz');
      await tester.pumpAndSettle();
      expect(find.text('No encontramos clientes con «xyz»'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'gom');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Laura Gómez'));
      await tester.pumpAndSettle();

      expect(find.text('Elegir cliente'), findsNothing);
      expect(find.text('Laura Gómez'), findsOneWidget);
      expect(find.text('Cambiar'), findsOneWidget);
    });

    testWidgets('prellenado sin vínculo: solo lectura con Cambiar', (
      tester,
    ) async {
      await _abrir(tester, _app(prefill: _prefill(clienteId: 'cli1')));
      expect(find.text('Laura Gómez'), findsOneWidget);
      expect(find.text('Cambiar'), findsOneWidget);
      expect(find.text('Elige el cliente'), findsNothing);
    });

    testWidgets('vinculado a una cita: sin Cambiar', (tester) async {
      await _abrir(
        tester,
        _app(
          prefill: _prefill(clienteId: 'cli1', mascotaId: 'm1', citaId: 'ci1'),
        ),
      );
      expect(find.text('Laura Gómez'), findsOneWidget);
      expect(find.text('Cambiar'), findsNothing);
      expect(find.text('Rocky'), findsOneWidget);
    });
  });

  group('mascota', () {
    testWidgets('chips de las mascotas del cliente; tocar la elegida la '
        'quita', (tester) async {
      await _abrir(tester, _app(prefill: _prefill(clienteId: 'cli1')));
      expect(find.text('Mascota (opcional)'), findsOneWidget);
      AppFilterChip chip(String n) =>
          tester.widget<AppFilterChip>(find.widgetWithText(AppFilterChip, n));
      expect(chip('Rocky').selected, isFalse);
      expect(chip('Luna').selected, isFalse);

      await tester.tap(find.text('Rocky'));
      await tester.pumpAndSettle();
      expect(chip('Rocky').selected, isTrue);

      await tester.tap(find.text('Rocky'));
      await tester.pumpAndSettle();
      expect(chip('Rocky').selected, isFalse);
    });

    testWidgets('un cliente sin mascotas oculta la sección', (tester) async {
      await _abrir(tester, _app(prefill: _prefill(clienteId: 'cli2')));
      expect(find.text('Pedro Ruiz'), findsOneWidget);
      expect(find.text('Mascota (opcional)'), findsNothing);
    });

    testWidgets('sin cliente no hay sección de mascota', (tester) async {
      await _abrir(tester, _app());
      expect(find.text('Mascota (opcional)'), findsNothing);
    });
  });

  group('servicios', () {
    testWidgets('chips A–Z seguidos de Otro; tocar agrega y repetir suma', (
      tester,
    ) async {
      await _abrir(tester, _app(prefill: _prefill(clienteId: 'cli1')));
      final xConsulta = tester.getTopLeft(find.text('Consulta · \$ 50.000')).dx;
      final xVacuna = tester.getTopLeft(find.text('Vacuna · \$ 40.000')).dx;
      final xOtro = tester.getTopLeft(find.text('Otro')).dx;
      expect(xConsulta, lessThan(xVacuna));
      expect(xVacuna, lessThan(xOtro));
      expect(
        find.bySemanticsLabel('Agregar Consulta, \$ 50.000'),
        findsOneWidget,
      );

      await _agregarConsulta(tester);
      expect(find.byType(LineaCobroTile), findsOneWidget);
      expect(find.text('Subtotal \$ 50.000'), findsOneWidget);

      await _agregarConsulta(tester);
      expect(find.byType(LineaCobroTile), findsOneWidget);
      expect(find.text('Subtotal \$ 100.000'), findsOneWidget);
      expect(_enBarra(find.text('\$ 100.000')), findsOneWidget);
    });

    testWidgets('sin servicios: aviso y Agregar servicios (admin) abre '
        '/servicios', (tester) async {
      await _abrir(tester, _app(servicios: const []));
      expect(find.text('Aún no hay servicios guardados.'), findsOneWidget);
      expect(find.text('Otro'), findsOneWidget);
      await tester.tap(find.text('Agregar servicios'));
      await tester.pumpAndSettle();
      expect(find.text('Pantalla servicios'), findsOneWidget);
    });

    testWidgets('sin servicios y sin ser admin: no hay Agregar servicios', (
      tester,
    ) async {
      await _abrir(
        tester,
        _app(servicios: const [], profile: vetColegaProfile),
      );
      expect(find.text('Aún no hay servicios guardados.'), findsOneWidget);
      expect(find.text('Agregar servicios'), findsNothing);
    });
  });

  testWidgets('Otro agrega una línea libre con la descripción enfocada', (
    tester,
  ) async {
    await _abrir(tester, _app(prefill: _prefill(clienteId: 'cli1')));
    await tester.tap(find.text('Otro'));
    await tester.pumpAndSettle();
    expect(find.byType(LineaCobroTile), findsOneWidget);
    expect(find.text('Ej. Baño medicado'), findsOneWidget);
    final campo = tester.widget<TextField>(_campo('descripcion-l1'));
    expect(campo.autofocus, isTrue);
    final editable = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('descripcion-l1')),
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.focusNode.hasFocus, isTrue);
  });

  group('LineaCobroTile', () {
    testWidgets('pasos, precio base, subtotal y semántica', (tester) async {
      await _abrir(tester, _app(prefill: _prefill(clienteId: 'cli1')));
      await _agregarConsulta(tester);

      final menos = find.bySemanticsLabel('Disminuir cantidad de Consulta');
      final mas = find.bySemanticsLabel('Aumentar cantidad de Consulta');
      expect(menos, findsOneWidget);
      expect(mas, findsOneWidget);
      expect(find.bySemanticsLabel('Quitar Consulta'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(LineaCobroTile),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );

      // En 1, "−" no hace nada.
      await tester.tap(menos);
      await tester.pumpAndSettle();
      expect(find.text('Subtotal \$ 50.000'), findsOneWidget);

      await tester.tap(mas);
      await tester.pumpAndSettle();
      expect(find.text('Subtotal \$ 100.000'), findsOneWidget);

      await tester.enterText(_campo('precio-l1'), '40000');
      await tester.pumpAndSettle();
      expect(find.text('Precio base \$ 50.000'), findsOneWidget);
      expect(find.text('Subtotal \$ 80.000'), findsOneWidget);
      expect(_enBarra(find.text('\$ 80.000')), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Quitar Consulta'));
      await tester.pumpAndSettle();
      expect(find.byType(LineaCobroTile), findsNothing);
    });

    testWidgets('la cantidad no pasa de 999', (tester) async {
      await _abrir(tester, _app(prefill: _prefill(clienteId: 'cli1')));
      await _agregarConsulta(tester);
      await tester.enterText(_campo('cantidad-l1'), '999');
      await tester.pumpAndSettle();
      expect(find.text('Subtotal \$ 49.950.000'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Aumentar cantidad de Consulta'));
      await tester.pumpAndSettle();
      expect(find.text('Subtotal \$ 49.950.000'), findsOneWidget);
    });
  });

  group('TotalCobroBar', () {
    testWidgets('sin cliente: deshabilitada, tocarla pide el cliente', (
      tester,
    ) async {
      final repo = FakeCobrosRepository(servicios: _servicios);
      await _abrir(tester, _app(repo: repo));
      expect(_enBarra(find.text('Total')), findsOneWidget);
      expect(_enBarra(find.text('\$ 0')), findsOneWidget);
      await _agregarConsulta(tester);
      expect(_enBarra(find.text('\$ 50.000')), findsOneWidget);

      await tester.tap(find.text('Emitir cuenta de cobro'));
      await tester.pumpAndSettle();
      expect(_enBarra(find.text('Elige el cliente.')), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(repo.llamadas.where((l) => l.metodo.startsWith('crear')), isEmpty);
    });

    testWidgets('sin líneas: deshabilitada, tocarla pide una línea', (
      tester,
    ) async {
      await _abrir(tester, _app(prefill: _prefill(clienteId: 'cli1')));
      await tester.tap(find.text('Emitir cuenta de cobro'));
      await tester.pumpAndSettle();
      expect(
        _enBarra(find.text('Agrega al menos un servicio o producto.')),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('validación de líneas', () {
    testWidgets('Otro vacío pide descripción y precio', (tester) async {
      final repo = FakeCobrosRepository(servicios: _servicios);
      await _abrir(
        tester,
        _app(
          repo: repo,
          prefill: _prefill(clienteId: 'cli1'),
        ),
      );
      await tester.tap(find.text('Otro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Emitir cuenta de cobro'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe la descripción.'), findsOneWidget);
      expect(find.text('Escribe el precio (puede ser 0).'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(repo.llamadas.where((l) => l.metodo.startsWith('crear')), isEmpty);
    });

    testWidgets('total 0', (tester) async {
      await _abrir(tester, _app(prefill: _prefill(clienteId: 'cli1')));
      await _agregarConsulta(tester);
      await tester.enterText(_campo('precio-l1'), '0');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Emitir cuenta de cobro'));
      await tester.pumpAndSettle();
      expect(
        _enBarra(find.text('El total debe ser mayor que \$ 0.')),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('total por encima de 999.999.999', (tester) async {
      await _abrir(tester, _app(prefill: _prefill(clienteId: 'cli1')));
      await _agregarConsulta(tester);
      await tester.enterText(_campo('precio-l1'), '100000000');
      await tester.enterText(_campo('cantidad-l1'), '10');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Emitir cuenta de cobro'));
      await tester.pumpAndSettle();
      expect(
        _enBarra(find.text('El total es demasiado alto.')),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  testWidgets('sin descuento ni la palabra prohibida', (tester) async {
    await _abrir(tester, _app(prefill: _prefill(clienteId: 'cli1')));
    await _agregarConsulta(tester);
    expect(find.textContaining(RegExp('actura|escuento')), findsNothing);
  });

  group('emitir', () {
    List<({String metodo, Map<String, Object?> args})> crear(
      FakeCobrosRepository repo,
    ) => repo.llamadas.where((l) => l.metodo.startsWith('crear')).toList();

    Future<void> emitirCc(WidgetTester tester) async {
      await tester.tap(find.text('Emitir cuenta de cobro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Emitir'));
      await tester.pumpAndSettle();
    }

    testWidgets('CC: confirma, Revisar no llama, Emitir llama una vez, abre '
        'el detalle y avisa', (tester) async {
      final repo = FakeCobrosRepository(servicios: _servicios);
      await _abrir(
        tester,
        _app(
          repo: repo,
          prefill: _prefill(clienteId: 'cli1'),
        ),
      );
      await _agregarConsulta(tester);

      await tester.tap(find.text('Emitir cuenta de cobro'));
      await tester.pumpAndSettle();
      expect(find.text('¿Emitir la cuenta de cobro?'), findsOneWidget);
      expect(
        find.text(
          'Total \$ 50.000 para Laura Gómez. Después no se puede editar: si '
          'hay un error, la anulas y emites otra.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Revisar'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(crear(repo), isEmpty);

      await emitirCc(tester);

      expect(crear(repo), hasLength(1));
      final args = crear(repo).single.args;
      expect(crear(repo).single.metodo, 'crearCuentaCobro');
      expect(args['clave'], 'clave-1');
      expect(args['clienteId'], 'cli1');
      final lineas = args['lineas']! as List<LineaCobroNueva>;
      expect(lineas.single.servicioId, 's1');
      expect(find.text('Detalle cobro-1'), findsOneWidget);
      expect(find.text('Cuenta de cobro CC-0001 emitida.'), findsOneWidget);
    });

    testWidgets('CC repetida (yaExistia) también avisa emitida', (
      tester,
    ) async {
      final repo = FakeCobrosRepository(servicios: _servicios);
      await repo.crearCuentaCobro(
        clave: 'clave-1',
        clienteId: 'cli1',
        lineas: const [],
      );
      await _abrir(
        tester,
        _app(
          repo: repo,
          prefill: _prefill(clienteId: 'cli1'),
        ),
      );
      await _agregarConsulta(tester);
      await emitirCc(tester);
      expect(find.text('Detalle cobro-1'), findsOneWidget);
      expect(find.text('Cuenta de cobro CC-0001 emitida.'), findsOneWidget);
    });

    testWidgets('cotización: se guarda sin diálogo', (tester) async {
      final repo = FakeCobrosRepository(servicios: _servicios);
      await _abrir(
        tester,
        _app(
          repo: repo,
          prefill: _prefill(clienteId: 'cli1', tipo: TipoCobro.cotizacion),
        ),
      );
      await _agregarConsulta(tester);
      await tester.tap(find.text('Guardar cotización'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(crear(repo).single.metodo, 'crearCotizacion');
      expect(find.text('Detalle cobro-1'), findsOneWidget);
      expect(find.text('Cotización COT-0001 guardada.'), findsOneWidget);
    });

    testWidgets('sin conexión: banner, conserva las líneas y el reintento '
        'usa la MISMA clave', (tester) async {
      final repo = FakeCobrosRepository(
        servicios: _servicios,
        errorCrear: const CobroFailure(
          'Sin conexión',
          tipo: ErrorCobro.sinConexion,
        ),
      );
      await _abrir(
        tester,
        _app(
          repo: repo,
          prefill: _prefill(clienteId: 'cli1'),
        ),
      );
      await _agregarConsulta(tester);
      await tester.tap(find.text('Otro'));
      await tester.pumpAndSettle();
      await tester.enterText(_campo('descripcion-l2'), 'Baño');
      await tester.enterText(_campo('precio-l2'), '20000');
      await tester.pumpAndSettle();

      await emitirCc(tester);
      expect(find.text('Sin conexión, el cobro no se creó.'), findsOneWidget);
      expect(
        find.text(
          'Tus datos siguen aquí. Inténtalo de nuevo cuando tengas señal.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      expect(find.byType(LineaCobroTile), findsNWidgets(2));
      expect(find.text('Emitir cuenta de cobro'), findsOneWidget);

      await emitirCc(tester);
      final llamadas = crear(repo);
      expect(llamadas, hasLength(2));
      expect(llamadas[0].args['clave'], 'clave-1');
      expect(llamadas[1].args['clave'], llamadas[0].args['clave']);
      expect(find.byType(LineaCobroTile), findsNWidgets(2));
    });

    testWidgets('otro fallo: banner genérico de cuenta de cobro', (
      tester,
    ) async {
      final repo = FakeCobrosRepository(
        servicios: _servicios,
        errorCrear: const CobroFailure('crudo'),
      );
      await _abrir(
        tester,
        _app(
          repo: repo,
          prefill: _prefill(clienteId: 'cli1'),
        ),
      );
      await _agregarConsulta(tester);
      await emitirCc(tester);
      expect(
        find.text('No pudimos crear el cobro. Intenta de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('crudo'), findsNothing);
      expect(find.byType(LineaCobroTile), findsOneWidget);
    });

    testWidgets('otro fallo: banner genérico de cotización', (tester) async {
      final repo = FakeCobrosRepository(
        servicios: _servicios,
        errorCotizacion: const CobroFailure('crudo'),
      );
      await _abrir(
        tester,
        _app(
          repo: repo,
          prefill: _prefill(clienteId: 'cli1', tipo: TipoCobro.cotizacion),
        ),
      );
      await _agregarConsulta(tester);
      await tester.tap(find.text('Guardar cotización'));
      await tester.pumpAndSettle();
      expect(
        find.text('No pudimos guardar la cotización. Intenta de nuevo.'),
        findsOneWidget,
      );
    });

    testWidgets('visita ya cobrada: el mensaje del fallo en el banner', (
      tester,
    ) async {
      final repo = FakeCobrosRepository(
        servicios: _servicios,
        errorCrear: const CobroFailure(
          'Esta visita ya tiene la cuenta de cobro CC-0003.',
          tipo: ErrorCobro.visitaYaCobrada,
        ),
      );
      await _abrir(
        tester,
        _app(
          repo: repo,
          prefill: _prefill(clienteId: 'cli1'),
        ),
      );
      await _agregarConsulta(tester);
      await emitirCc(tester);
      expect(
        find.text('Esta visita ya tiene la cuenta de cobro CC-0003.'),
        findsOneWidget,
      );
    });

    testWidgets('stock insuficiente: Revisa las cantidades marcadas.', (
      tester,
    ) async {
      final repo = FakeCobrosRepository(
        servicios: _servicios,
        errorCrear: const CobroFailure(
          'Solo quedan 2 frascos de Amoxicilina.',
          tipo: ErrorCobro.stockInsuficiente,
        ),
      );
      await _abrir(
        tester,
        _app(
          repo: repo,
          prefill: _prefill(clienteId: 'cli1'),
        ),
      );
      await _agregarConsulta(tester);
      await emitirCc(tester);
      expect(find.text('Revisa las cantidades marcadas.'), findsOneWidget);
    });

    testWidgets('LP004: abre la hoja de solo lectura y conserva el borrador', (
      tester,
    ) async {
      final repo = FakeCobrosRepository(
        servicios: _servicios,
        errorCrear: const CobroFailure(
          'Tu cuenta está en solo lectura. Pide al administrador que active '
          'el plan.',
          tipo: ErrorCobro.soloLectura,
          limite: LimitePlan.soloLectura,
        ),
      );
      await _abrir(
        tester,
        _app(
          repo: repo,
          prefill: _prefill(clienteId: 'cli1'),
        ),
      );
      await _agregarConsulta(tester);
      await emitirCc(tester);
      expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(CobroFormScreen), findsOneWidget);
      expect(find.byType(LineaCobroTile), findsOneWidget);
    });

    testWidgets('en vuelo: CTA cargando, entradas bloqueadas y un doble '
        'toque no hace otra llamada', (tester) async {
      final repo = FakeCobrosRepository(servicios: _servicios)
        ..bloqueoCrear = Completer<void>();
      await _abrir(
        tester,
        _app(
          repo: repo,
          prefill: _prefill(clienteId: 'cli1', tipo: TipoCobro.cotizacion),
        ),
      );
      await _agregarConsulta(tester);
      await tester.tap(find.text('Guardar cotización'));
      await tester.pump();

      expect(_enBarra(find.byType(CircularProgressIndicator)), findsOneWidget);
      expect(
        tester.widget<LineaCobroTile>(find.byType(LineaCobroTile)).habilitado,
        isFalse,
      );
      await tester.tap(_enBarra(find.byType(ElevatedButton)));
      await tester.pump();
      await tester.tap(find.text('Consulta · \$ 50.000'));
      await tester.pump();
      expect(crear(repo), hasLength(1));
      expect(find.text('Subtotal \$ 50.000'), findsOneWidget);

      repo.bloqueoCrear!.complete();
      await tester.pumpAndSettle();
      expect(crear(repo), hasLength(1));
      expect(find.text('Cotización COT-0001 guardada.'), findsOneWidget);
    });

    testWidgets('en vuelo (CC): doble toque tras Emitir no llama dos veces', (
      tester,
    ) async {
      final repo = FakeCobrosRepository(servicios: _servicios)
        ..bloqueoCrear = Completer<void>();
      await _abrir(
        tester,
        _app(
          repo: repo,
          prefill: _prefill(clienteId: 'cli1'),
        ),
      );
      await _agregarConsulta(tester);
      await tester.tap(find.text('Emitir cuenta de cobro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Emitir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(_enBarra(find.byType(ElevatedButton)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AlertDialog), findsNothing);
      expect(crear(repo), hasLength(1));
      repo.bloqueoCrear!.complete();
      await tester.pumpAndSettle();
      expect(crear(repo), hasLength(1));
    });
  });

  group('salir', () {
    testWidgets('con borrador sucio pregunta; Seguir editando se queda y '
        'Descartar sale', (tester) async {
      await _abrir(tester, _app(prefill: _prefill(clienteId: 'cli1')));
      await _agregarConsulta(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar este cobro?'), findsOneWidget);
      expect(
        find.text('Se perderán las líneas que agregaste.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();
      expect(find.byType(CobroFormScreen), findsOneWidget);
      expect(find.byType(LineaCobroTile), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(find.byType(CobroFormScreen), findsNothing);
      expect(find.text('Abrir'), findsOneWidget);
    });

    testWidgets('limpio sale sin diálogo', (tester) async {
      await _abrir(tester, _app(prefill: _prefill(clienteId: 'cli1')));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Abrir'), findsOneWidget);
    });
  });

  group('ruta /cobros/nuevo', () {
    Future<void> abrirRuta(WidgetTester tester, String ruta) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        routerHarness(
          initialLocation: ruta,
          routes: cobrosRoutes,
          overrides: _overrides(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('tipo=cot y clienteId prellenan la cotización', (tester) async {
      await abrirRuta(tester, '/cobros/nuevo?tipo=cot&clienteId=cli1');
      expect(find.byType(CobroDetailScreen), findsNothing);
      final f = tester.widget<CobroFormScreen>(find.byType(CobroFormScreen));
      expect(f.prefill.modo, ModoFormCobro.nuevo);
      expect(f.prefill.tipo, TipoCobro.cotizacion);
      expect(f.prefill.clienteId, 'cli1');
      expect(find.text('Nueva cotización'), findsOneWidget);
      expect(find.text('Laura Gómez'), findsOneWidget);
    });

    testWidgets('sin parámetros: cuenta de cobro nueva, nunca el detalle', (
      tester,
    ) async {
      await abrirRuta(tester, '/cobros/nuevo');
      expect(find.byType(CobroDetailScreen), findsNothing);
      expect(find.byType(CobroFormScreen), findsOneWidget);
      expect(find.text('Nueva cuenta de cobro'), findsOneWidget);
    });

    testWidgets('cita, consulta, mascota y desdeCobroId se leen de la ruta', (
      tester,
    ) async {
      await abrirRuta(
        tester,
        '/cobros/nuevo?clienteId=cli1&mascotaId=m1&citaId=ci1'
        '&consultaId=co1&desdeCobroId=q9',
      );
      final p = tester
          .widget<CobroFormScreen>(find.byType(CobroFormScreen))
          .prefill;
      expect(p.tipo, TipoCobro.cuentaCobro);
      expect(p.mascotaId, 'm1');
      expect(p.citaId, 'ci1');
      expect(p.consultaId, 'co1');
      expect(p.origenId, 'q9');
      expect(p.modo, ModoFormCobro.copiar);
    });
  });
}
