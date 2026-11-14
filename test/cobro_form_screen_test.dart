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
import 'package:vetapp/features/inventory/domain/entities/producto.dart';
import 'package:vetapp/features/inventory/presentation/providers/inventario_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_clientes.dart';
import 'helpers/fake_cobros.dart';
import 'helpers/fake_inventario.dart';
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
      // Las entradas están bloqueadas: el toque no debe llegar al chip.
      await tester.tap(find.text('Consulta · \$ 50.000'), warnIfMissed: false);
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

  group('productos (07-11)', () {
    List<({String metodo, Map<String, Object?> args})> crear(
      FakeCobrosRepository repo,
    ) => repo.llamadas.where((l) => l.metodo.startsWith('crear')).toList();

    Future<void> agregarProducto(WidgetTester tester, String nombre) async {
      await tester.ensureVisible(find.text('Agregar producto'));
      await tester.tap(find.text('Agregar producto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(nombre).last);
      await tester.pumpAndSettle();
    }

    Future<void> emitirCc(WidgetTester tester) async {
      await tester.tap(find.text('Emitir cuenta de cobro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Emitir'));
      await tester.pumpAndSettle();
    }

    testWidgets('Agregar producto (outline, inventory_2) en ambos tipos; la '
        'hoja sigue el tipo elegido', (tester) async {
      await _abrir(
        tester,
        _appInv(
          prefill: _prefill(clienteId: 'cli1'),
          productos: [_amox, _agotado],
        ),
      );
      expect(find.text('Agregar producto'), findsOneWidget);
      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);

      // CC: el agotado no se puede elegir.
      await tester.tap(find.text('Agregar producto'));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Suero, agotado, no disponible'),
        findsOneWidget,
      );
      await tester.tap(find.text('Suero'));
      await tester.pumpAndSettle();
      expect(find.byType(LineaCobroTile), findsNothing);
      await tester.tap(find.text('Amoxicilina').last);
      await tester.pumpAndSettle();
      expect(find.byType(LineaCobroTile), findsOneWidget);
      expect(find.text('Quedan 3 frascos'), findsOneWidget);

      // Cotización: el mismo agotado sí se agrega.
      await tester.tap(find.text('Cotización'));
      await tester.pumpAndSettle();
      expect(find.text('Agregar producto'), findsOneWidget);
      await agregarProducto(tester, 'Suero');
      expect(find.byType(LineaCobroTile), findsNWidgets(2));
      expect(find.text('Quedan 0 frascos'), findsOneWidget);
    });

    testWidgets('CC: "+" se detiene en el stock; escribir más muestra el '
        'error en línea', (tester) async {
      await _abrir(
        tester,
        _appInv(
          prefill: _prefill(clienteId: 'cli1'),
          productos: [_amox],
        ),
      );
      await agregarProducto(tester, 'Amoxicilina');
      final mas = find.bySemanticsLabel('Aumentar cantidad de Amoxicilina');
      await tester.tap(mas);
      await tester.pumpAndSettle();
      await tester.tap(mas);
      await tester.pumpAndSettle();
      expect(find.text('Subtotal \$ 255.000'), findsOneWidget);
      await tester.tap(mas);
      await tester.pumpAndSettle();
      expect(find.text('Subtotal \$ 255.000'), findsOneWidget);
      expect(find.text('Solo quedan 3 frascos de Amoxicilina.'), findsNothing);

      await tester.enterText(_campo('cantidad-l1'), '5');
      await tester.pumpAndSettle();
      expect(
        find.text('Solo quedan 3 frascos de Amoxicilina.'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(LineaCobroTile),
          matching: find.byIcon(Icons.error_outline),
        ),
        findsOneWidget,
      );
    });

    testWidgets('CC con stock 0: "{Producto} está agotado."', (tester) async {
      await _abrir(
        tester,
        _appInv(
          prefill: _prefill(clienteId: 'cli1', tipo: TipoCobro.cotizacion),
          productos: [productoDePrueba(cantidad: 0, precioVentaCop: 85000)],
        ),
      );
      await agregarProducto(tester, 'Amoxicilina');
      expect(find.text('Amoxicilina está agotado.'), findsNothing);
      await tester.tap(find.text('Cuenta de cobro'));
      await tester.pumpAndSettle();
      expect(find.text('Amoxicilina está agotado.'), findsOneWidget);
    });

    testWidgets('emitir con una línea inválida la muestra y no envía', (
      tester,
    ) async {
      final repo = FakeCobrosRepository(servicios: _servicios);
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _appInv(
          repo: repo,
          prefill: _prefill(clienteId: 'cli1'),
          productos: [_amox],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Consulta · \$ 50.000'));
      await tester.tap(find.text('Consulta · \$ 50.000'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Vacuna · \$ 40.000'));
      await tester.tap(find.text('Vacuna · \$ 40.000'));
      await tester.pumpAndSettle();
      await agregarProducto(tester, 'Amoxicilina');
      await tester.ensureVisible(_campo('cantidad-l3'));
      await tester.enterText(_campo('cantidad-l3'), '5');
      await tester.pumpAndSettle();

      // Volver arriba para que la línea quede fuera de la vista.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 3000),
      );
      await tester.pumpAndSettle();
      final barra = tester.getTopLeft(find.byType(TotalCobroBar)).dy;
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('l3'))).dy,
        greaterThan(barra),
      );

      await tester.tap(find.text('Emitir cuenta de cobro'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(crear(repo), isEmpty);
      final y = tester.getTopLeft(find.byKey(const ValueKey('l3'))).dy;
      expect(y, lessThan(barra));
      expect(y, greaterThanOrEqualTo(0));
    });

    testWidgets('cotización: sin tope ni error de stock', (tester) async {
      await _abrir(
        tester,
        _appInv(
          prefill: _prefill(clienteId: 'cli1', tipo: TipoCobro.cotizacion),
          productos: [_amox],
        ),
      );
      await agregarProducto(tester, 'Amoxicilina');
      expect(find.text('Quedan 3 frascos'), findsOneWidget);
      await tester.enterText(_campo('cantidad-l1'), '3');
      await tester.pumpAndSettle();
      await tester.tap(
        find.bySemanticsLabel('Aumentar cantidad de Amoxicilina'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Subtotal \$ 340.000'), findsOneWidget);
      expect(find.textContaining('Solo quedan'), findsNothing);
    });

    testWidgets('producto sin precio: precio enfocado con la ayuda', (
      tester,
    ) async {
      await _abrir(
        tester,
        _appInv(
          prefill: _prefill(clienteId: 'cli1'),
          productos: [productoDePrueba(nombre: 'Gasas', cantidad: 9)],
        ),
      );
      await agregarProducto(tester, 'Gasas');
      expect(
        find.text('Este producto no tiene precio de venta. Escribe el precio.'),
        findsOneWidget,
      );
      final campo = tester.widget<TextField>(_campo('precio-l1'));
      expect(campo.focusNode?.hasFocus, isTrue);
    });

    testWidgets('ayuda de inventario solo en CC con productos', (tester) async {
      const ayuda = 'Al emitirla se descuentan los productos del inventario.';
      await _abrir(
        tester,
        _appInv(
          prefill: _prefill(clienteId: 'cli1'),
          productos: [_amox],
        ),
      );
      await _agregarConsulta(tester);
      expect(find.text(ayuda), findsNothing);
      await agregarProducto(tester, 'Amoxicilina');
      expect(_enBarra(find.text(ayuda)), findsOneWidget);
      await tester.tap(find.text('Cotización'));
      await tester.pumpAndSettle();
      expect(find.text(ayuda), findsNothing);
    });

    testWidgets('IN001 del servidor marca la línea exacta, refresca la nota, '
        'conserva el borrador y el reintento usa la MISMA clave', (
      tester,
    ) async {
      final repo = FakeCobrosRepository(
        servicios: _servicios,
        errorCrear: const CobroFailure(
          'Solo quedan 2 frascos de Amoxicilina.',
          tipo: ErrorCobro.stockInsuficiente,
          productoId: 'p1',
          quedan: 2,
        ),
      );
      await _abrir(
        tester,
        _appInv(
          repo: repo,
          prefill: _prefill(clienteId: 'cli1'),
          productos: [_amox],
        ),
      );
      await _agregarConsulta(tester);
      await agregarProducto(tester, 'Amoxicilina');
      await tester.enterText(_campo('cantidad-l2'), '3');
      await tester.pumpAndSettle();
      await emitirCc(tester);

      expect(find.text('Revisa las cantidades marcadas.'), findsOneWidget);
      final linea = find.byKey(const ValueKey('l2'));
      expect(
        find.descendant(
          of: linea,
          matching: find.text('Solo quedan 2 frascos de Amoxicilina.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: linea, matching: find.text('Quedan 2 frascos')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('l1')),
          matching: find.textContaining('Solo quedan'),
        ),
        findsNothing,
      );
      expect(find.byType(LineaCobroTile), findsNWidgets(2));

      await tester.enterText(_campo('cantidad-l2'), '2');
      await tester.pumpAndSettle();
      await emitirCc(tester);
      final llamadas = crear(repo);
      expect(llamadas, hasLength(2));
      expect(llamadas[1].args['clave'], llamadas[0].args['clave']);
      final lineas = llamadas[1].args['lineas']! as List<LineaCobroNueva>;
      expect(lineas.last.productoId, 'p1');
      expect(lineas.last.cantidad, 2);
    });

    testWidgets('IN002 del servidor: "ya no está disponible" y pasos '
        'deshabilitados', (tester) async {
      final repo = FakeCobrosRepository(
        servicios: _servicios,
        errorCrear: const CobroFailure(
          'Gasas ya no está disponible. Quítalo del cobro.',
          tipo: ErrorCobro.productoNoDisponible,
          productoId: 'p9',
        ),
      );
      await _abrir(
        tester,
        _appInv(
          repo: repo,
          prefill: _prefill(clienteId: 'cli1'),
          productos: [
            productoDePrueba(
              id: 'p9',
              nombre: 'Gasas',
              unidad: Unidad.unidad,
              cantidad: 9,
              precioVentaCop: 2000,
            ),
          ],
        ),
      );
      await agregarProducto(tester, 'Gasas');
      await emitirCc(tester);
      expect(
        find.text('Gasas ya no está disponible. Quítalo del cobro.'),
        findsOneWidget,
      );
      await tester.tap(find.bySemanticsLabel('Aumentar cantidad de Gasas'));
      await tester.pumpAndSettle();
      expect(find.text('Subtotal \$ 2.000'), findsOneWidget);
      expect(find.bySemanticsLabel('Quitar Gasas'), findsOneWidget);
    });
  });

  group('modos editar / convertir / copiar (07-15)', () {
    const lineasCot = [
      CobroItem(
        orden: 1,
        tipo: TipoLinea.servicio,
        descripcion: 'Consulta',
        cantidad: 1,
        precioUnitarioCop: 50000,
        servicioId: 's1',
      ),
      CobroItem(
        orden: 2,
        tipo: TipoLinea.producto,
        descripcion: 'Amoxicilina',
        cantidad: 2,
        precioUnitarioCop: 85000,
        productoId: 'p1',
      ),
    ];

    Cobro cot({EstadoCobro estado = EstadoCobro.abierta}) => cobroDePrueba(
      id: 'q4',
      tipo: TipoCobro.cotizacion,
      numero: 4,
      estado: estado,
      items: lineasCot,
    );

    Cobro ccAnulada() => cobroDePrueba(
      id: 'c12',
      numero: 12,
      estado: EstadoCobro.anulada,
      citaId: 'cita1',
      items: lineasCot,
    );

    PrefillCobro modo(ModoFormCobro m, String origen) => (
      modo: m,
      tipo: m == ModoFormCobro.editarCotizacion
          ? TipoCobro.cotizacion
          : TipoCobro.cuentaCobro,
      clienteId: m == ModoFormCobro.copiar ? 'cli1' : null,
      mascotaId: m == ModoFormCobro.copiar ? 'm1' : null,
      citaId: m == ModoFormCobro.copiar ? 'cita1' : null,
      consultaId: null,
      origenId: origen,
    );

    List<({String metodo, Map<String, Object?> args})> llamadas(
      FakeCobrosRepository repo,
      String metodo,
    ) => repo.llamadas.where((l) => l.metodo == metodo).toList();

    Future<void> emitirCc(WidgetTester tester) async {
      await tester.tap(find.text('Emitir cuenta de cobro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Emitir'));
      await tester.pumpAndSettle();
    }

    const noDisponible =
        'Esta cotización ya no se puede usar. Actualiza '
        'la lista.';

    bool ctaHabilitada(WidgetTester tester) =>
        tester.widget<TotalCobroBar>(find.byType(TotalCobroBar)).habilitado;

    testWidgets('convertir: título, nota, sin Tipo, copia cliente, mascota y '
        'líneas editables', (tester) async {
      final repo = FakeCobrosRepository(servicios: _servicios, cobros: [cot()]);
      await _abrir(
        tester,
        _appInv(
          repo: repo,
          prefill: modo(ModoFormCobro.convertir, 'q4'),
          productos: [_amox],
        ),
      );
      expect(find.text('Convertir COT-0004'), findsOneWidget);
      expect(
        find.text(
          'Desde la cotización COT-0004. Revisa los precios y cantidades '
          'antes de emitir.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cotización'), findsNothing);
      expect(find.text('Cuenta de cobro'), findsNothing);
      expect(find.text('Laura Gómez'), findsOneWidget);
      expect(
        tester
            .widget<AppFilterChip>(find.widgetWithText(AppFilterChip, 'Rocky'))
            .selected,
        isTrue,
      );
      expect(find.byType(LineaCobroTile), findsNWidgets(2));
      expect(find.text('Quedan 3 frascos'), findsOneWidget);
      expect(_enBarra(find.text('Emitir cuenta de cobro')), findsOneWidget);
      expect(_enBarra(find.text('\$ 220.000')), findsOneWidget);

      // Editable y con el tope de stock de cualquier CC.
      await tester.enterText(_campo('cantidad-l2'), '5');
      await tester.pumpAndSettle();
      expect(
        find.text('Solo quedan 3 frascos de Amoxicilina.'),
        findsOneWidget,
      );
    });

    testWidgets('convertir: confirma y emite con p_cotizacion_id; reemplaza '
        'por el detalle de la CC nueva', (tester) async {
      final repo = FakeCobrosRepository(servicios: _servicios, cobros: [cot()]);
      await _abrir(
        tester,
        _appInv(
          repo: repo,
          prefill: modo(ModoFormCobro.convertir, 'q4'),
          productos: [_amox],
        ),
      );
      await tester.tap(find.text('Emitir cuenta de cobro'));
      await tester.pumpAndSettle();
      expect(find.text('¿Emitir la cuenta de cobro?'), findsOneWidget);
      await tester.tap(find.text('Emitir'));
      await tester.pumpAndSettle();

      final c = llamadas(repo, 'crearCuentaCobro').single.args;
      expect(c['cotizacionId'], 'q4');
      expect(c['clave'], 'clave-1');
      expect(c['clienteId'], 'cli1');
      expect(c['mascotaId'], 'm1');
      expect(c['citaId'], isNull);
      expect(c['lineas']! as List<LineaCobroNueva>, hasLength(2));
      expect(find.text('Detalle cobro-1'), findsOneWidget);
      expect(find.text('Cuenta de cobro CC-0001 emitida.'), findsOneWidget);
      final q = repo.guardados.firstWhere((x) => x.id == 'q4');
      expect(q.estado, EstadoCobro.convertida);
      expect(q.convertidaEnNumero, 1);
    });

    testWidgets('convertir: un producto archivado se marca al copiar', (
      tester,
    ) async {
      await _abrir(
        tester,
        _appInv(
          repo: FakeCobrosRepository(servicios: _servicios, cobros: [cot()]),
          prefill: modo(ModoFormCobro.convertir, 'q4'),
        ),
      );
      expect(
        find.text('Amoxicilina ya no está disponible. Quítalo del cobro.'),
        findsOneWidget,
      );
    });

    testWidgets('convertir: BC002 del servidor muestra el aviso, deshabilita '
        'el CTA y Volver regresa', (tester) async {
      final repo = FakeCobrosRepository(
        servicios: _servicios,
        cobros: [cot()],
        errorCrear: const CobroFailure(
          'Esta cotización ya no se puede usar. Actualiza la lista.',
          tipo: ErrorCobro.cotizacionNoDisponible,
        ),
      );
      await _abrir(
        tester,
        _appInv(
          repo: repo,
          prefill: modo(ModoFormCobro.convertir, 'q4'),
          productos: [_amox],
        ),
      );
      await emitirCc(tester);
      expect(find.text(noDisponible), findsOneWidget);
      expect(ctaHabilitada(tester), isFalse);
      expect(find.byType(LineaCobroTile), findsNWidgets(2));

      await tester.tap(find.widgetWithText(TextButton, 'Volver'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(CobroFormScreen), findsNothing);
      expect(find.text('Abrir'), findsOneWidget);
    });

    testWidgets('origen de otra clase: convertir una CC o editar una '
        'cotización convertida muestran el mismo aviso', (tester) async {
      for (final (m, origen) in [
        (ModoFormCobro.convertir, cobroDePrueba(id: 'q4')),
        (ModoFormCobro.editarCotizacion, cot(estado: EstadoCobro.convertida)),
      ]) {
        await tester.pumpWidget(const SizedBox());
        await _abrir(
          tester,
          _appInv(
            repo: FakeCobrosRepository(servicios: _servicios, cobros: [origen]),
            prefill: modo(m, 'q4'),
            productos: [_amox],
          ),
        );
        expect(find.text(noDisponible), findsOneWidget);
        expect(ctaHabilitada(tester), isFalse);
        expect(find.widgetWithText(TextButton, 'Volver'), findsOneWidget);
      }
    });

    testWidgets('mientras carga el origen: filas de esqueleto', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final pendiente = Completer<Cobro?>();
      await tester.pumpWidget(
        routerHarness(
          initialLocation: '/form',
          routes: [
            GoRoute(
              path: '/form',
              builder: (_, _) =>
                  CobroFormScreen(prefill: modo(ModoFormCobro.convertir, 'q4')),
            ),
          ],
          overrides: [
            ..._overrides(),
            cobroProvider.overrideWith((ref, id) => pendiente.future),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('esqueleto-origen')), findsOneWidget);
      expect(find.text('Elige el cliente'), findsNothing);
      expect(ctaHabilitada(tester), isFalse);
      pendiente.complete(null);
      await tester.pumpAndSettle();
    });

    testWidgets('editar: título, sin Tipo, cliente cambiable; Guardar '
        'cambios sin diálogo, vuelve y avisa', (tester) async {
      final repo = FakeCobrosRepository(servicios: _servicios, cobros: [cot()]);
      await _abrir(
        tester,
        _appInv(
          repo: repo,
          prefill: modo(ModoFormCobro.editarCotizacion, 'q4'),
          productos: [_amox],
        ),
      );
      expect(find.text('Editar cotización'), findsOneWidget);
      expect(find.text('Cotización'), findsNothing);
      expect(find.text('Cuenta de cobro'), findsNothing);
      expect(find.text('Cambiar'), findsOneWidget);
      expect(find.byType(LineaCobroTile), findsNWidgets(2));
      // Una cotización no tiene tope de stock.
      await tester.enterText(_campo('cantidad-l2'), '5');
      await tester.pumpAndSettle();
      expect(find.text('Solo quedan 3 frascos de Amoxicilina.'), findsNothing);

      await tester.tap(_enBarra(find.text('Guardar cambios')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      final e = llamadas(repo, 'editarCotizacion').single.args;
      expect(e['id'], 'q4');
      expect(e['clienteId'], 'cli1');
      expect(e['mascotaId'], 'm1');
      final ls = e['lineas']! as List<LineaCobroNueva>;
      expect(ls, hasLength(2));
      expect(ls[1].cantidad, 5);
      expect(llamadas(repo, 'crearCotizacion'), isEmpty);
      expect(find.byType(CobroFormScreen), findsNothing);
      expect(find.text('Abrir'), findsOneWidget);
      expect(find.text('Cambios guardados.'), findsOneWidget);
    });

    testWidgets('editar: un fallo conserva el formulario con el aviso de '
        'cotización', (tester) async {
      final repo = FakeCobrosRepository(
        servicios: _servicios,
        cobros: [cot()],
        errorEditar: const CobroFailure('x'),
      );
      await _abrir(
        tester,
        _appInv(
          repo: repo,
          prefill: modo(ModoFormCobro.editarCotizacion, 'q4'),
          productos: [_amox],
        ),
      );
      await tester.tap(_enBarra(find.text('Guardar cambios')));
      await tester.pumpAndSettle();
      expect(
        find.text('No pudimos guardar la cotización. Intenta de nuevo.'),
        findsOneWidget,
      );
      expect(find.byType(CobroFormScreen), findsOneWidget);
      expect(ctaHabilitada(tester), isTrue);
    });

    testWidgets('editar: BC002 del servidor deshabilita el CTA', (
      tester,
    ) async {
      final repo = FakeCobrosRepository(
        servicios: _servicios,
        cobros: [cot()],
        errorEditar: const CobroFailure(
          'Esta cotización ya no se puede usar. Actualiza la lista.',
          tipo: ErrorCobro.cotizacionNoDisponible,
        ),
      );
      await _abrir(
        tester,
        _appInv(
          repo: repo,
          prefill: modo(ModoFormCobro.editarCotizacion, 'q4'),
          productos: [_amox],
        ),
      );
      await tester.tap(_enBarra(find.text('Guardar cambios')));
      await tester.pumpAndSettle();
      expect(find.text(noDisponible), findsOneWidget);
      expect(ctaHabilitada(tester), isFalse);
    });

    testWidgets('copiar desde una CC anulada: Nueva cuenta de cobro, '
        'prellenada, emite con la cita y sin cotización', (tester) async {
      final repo = FakeCobrosRepository(
        servicios: _servicios,
        cobros: [ccAnulada()],
      );
      await _abrir(
        tester,
        _appInv(
          repo: repo,
          prefill: modo(ModoFormCobro.copiar, 'c12'),
          productos: [_amox],
        ),
      );
      expect(find.text('Nueva cuenta de cobro'), findsOneWidget);
      expect(find.text('Laura Gómez'), findsOneWidget);
      expect(find.text('Rocky'), findsOneWidget);
      expect(find.byType(LineaCobroTile), findsNWidgets(2));

      await emitirCc(tester);
      final c = llamadas(repo, 'crearCuentaCobro').single.args;
      expect(c['citaId'], 'cita1');
      expect(c['cotizacionId'], isNull);
      expect(c['clave'], 'clave-1');
      expect(c['lineas']! as List<LineaCobroNueva>, hasLength(2));
      expect(find.text('Detalle cobro-1'), findsOneWidget);
      expect(find.text('Cuenta de cobro CC-0001 emitida.'), findsOneWidget);
    });
  });
}

final _amox = productoDePrueba(cantidad: 3, precioVentaCop: 85000);
final _agotado = productoDePrueba(id: 'p2', nombre: 'Suero', cantidad: 0);

Widget _appInv({
  PrefillCobro? prefill,
  FakeCobrosRepository? repo,
  List<Producto> productos = const [],
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
        path: '/cobros/:id',
        builder: (_, s) =>
            Scaffold(body: Text('Detalle ${s.pathParameters['id']}')),
      ),
    ],
    overrides: [
      ..._overrides(repo: repo),
      inventarioRepositoryProvider.overrideWithValue(
        FakeInventarioRepository(productos: productos),
      ),
    ],
  );
}
