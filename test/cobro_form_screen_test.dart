import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/billing/domain/entities/cobro.dart';
import 'package:vetapp/features/billing/domain/entities/servicio.dart';
import 'package:vetapp/features/billing/presentation/providers/borrador_cobro_provider.dart';
import 'package:vetapp/features/billing/presentation/providers/cobros_providers.dart';
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
  var n = 0;
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
      GoRoute(path: '/form', builder: (_, _) => CobroFormScreen(prefill: p)),
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
    overrides: [
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
    ],
  );
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

Finder _campo(String key) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(TextField));

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
      AppFilterChip chip(String n) => tester.widget<AppFilterChip>(
        find.widgetWithText(AppFilterChip, n),
      );
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
        _app(repo: repo, prefill: _prefill(clienteId: 'cli1')),
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
      expect(_enBarra(find.text('El total es demasiado alto.')), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  testWidgets('sin descuento ni la palabra prohibida', (tester) async {
    await _abrir(tester, _app(prefill: _prefill(clienteId: 'cli1')));
    await _agregarConsulta(tester);
    expect(find.textContaining(RegExp('actura|escuento')), findsNothing);
  });
}
