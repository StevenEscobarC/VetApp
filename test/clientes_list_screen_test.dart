import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/clients/domain/cliente_failure.dart';
import 'package:vetapp/features/clients/presentation/providers/clientes_providers.dart';
import 'package:vetapp/features/clients/presentation/screens/clientes_list_screen.dart';
import 'package:vetapp/features/plan/domain/mi_plan.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_clientes.dart';
import 'helpers/fake_plan.dart';
import 'helpers/router_harness.dart';

Widget _appUnderTest({
  required FakeClienteRepository repo,
  MiPlan? plan,
  Object? planError,
}) {
  return routerHarness(
    initialLocation: '/clientes',
    routes: [
      GoRoute(path: '/clientes', builder: (_, _) => const ClientesListScreen()),
      GoRoute(
        path: '/clientes/nuevo',
        builder: (_, _) => const Scaffold(body: Text('NUEVO CLIENTE')),
      ),
    ],
    overrides: [
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: vetProfile),
      ),
      clienteRepositoryProvider.overrideWithValue(repo),
      ...planOverrides(plan: plan, error: planError),
    ],
  );
}

void main() {
  testWidgets('muestra los clientes reales con teléfono y conteo de '
      'mascotas', (tester) async {
    final repo = FakeClienteRepository(clientes: [clienteRita, clientePedro]);
    await tester.pumpWidget(_appUnderTest(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Rita Gómez'), findsOneWidget);
    expect(find.text('3001234567'), findsOneWidget);
    expect(find.text('2 mascotas'), findsOneWidget);
    expect(find.text('Pedro Ruiz'), findsOneWidget);
    expect(find.text('Sin mascotas'), findsOneWidget);
    expect(find.text('Buscar por nombre o teléfono'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Buscar'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Buscar'), findsNothing);
  });

  testWidgets('sin clientes muestra el estado vacío inicial', (tester) async {
    final repo = FakeClienteRepository();
    await tester.pumpWidget(_appUnderTest(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Aún no tienes clientes'), findsOneWidget);
    expect(
      find.text(
        'Registra tu primer cliente para empezar a llevar sus mascotas.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('escribir una búsqueda sin coincidencias muestra el estado '
      'vacío de búsqueda tras el debounce', (tester) async {
    final repo = FakeClienteRepository(clientes: [clienteRita, clientePedro]);
    await tester.pumpWidget(_appUnderTest(repo: repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'zz');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('No encontramos clientes con «zz»'), findsOneWidget);
    expect(
      find.text('Verifica el nombre o teléfono e intenta de nuevo.'),
      findsOneWidget,
    );
  });

  testWidgets('error del repositorio muestra el mensaje de error genérico', (
    tester,
  ) async {
    final repo = FakeClienteRepository(
      error: const ClienteFailure('No pudimos cargar la lista.'),
    );
    await tester.pumpWidget(_appUnderTest(repo: repo));
    await tester.pumpAndSettle();

    expect(
      find.text('No pudimos cargar la lista. Intenta de nuevo.'),
      findsOneWidget,
    );
  });

  group('límites del plan', () {
    testWidgets('Gratis con 50 pacientes: "Nuevo cliente" abre la hoja y no '
        'navega', (tester) async {
      await tester.pumpWidget(
        _appUnderTest(
          repo: FakeClienteRepository(clientes: [clienteRita]),
          plan: planGratisAlTope,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nuevo cliente'));
      await tester.pumpAndSettle();

      expect(find.text('Llegaste a los 50 pacientes'), findsOneWidget);
      expect(find.text('NUEVO CLIENTE'), findsNothing);
      // Límite del plan, no permiso: sin candado.
      expect(find.byIcon(Icons.lock_outline), findsNothing);
    });

    testWidgets('con plan Beta navega a /clientes/nuevo', (tester) async {
      await tester.pumpWidget(
        _appUnderTest(repo: FakeClienteRepository(clientes: [clienteRita])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nuevo cliente'));
      await tester.pumpAndSettle();

      expect(find.text('NUEVO CLIENTE'), findsOneWidget);
      expect(find.text('Llegaste a los 50 pacientes'), findsNothing);
    });

    testWidgets('en solo lectura muestra candado, semántica bloqueada y la '
        'hoja de solo lectura', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _appUnderTest(
          repo: FakeClienteRepository(clientes: [clienteRita]),
          plan: planSoloLectura,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(
        tester.getSemantics(find.byType(FloatingActionButton)).label,
        endsWith('bloqueado, solo lectura'),
      );

      await tester.tap(find.text('Nuevo cliente'));
      await tester.pumpAndSettle();

      expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
      expect(find.text('NUEVO CLIENTE'), findsNothing);
      semantics.dispose();
    });

    testWidgets('si el plan no se puede leer, el botón se comporta como '
        'siempre', (tester) async {
      await tester.pumpWidget(
        _appUnderTest(
          repo: FakeClienteRepository(clientes: [clienteRita]),
          planError: Exception('red'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add), findsOneWidget);
      await tester.tap(find.text('Nuevo cliente'));
      await tester.pumpAndSettle();

      expect(find.text('NUEVO CLIENTE'), findsOneWidget);
    });
  });
}
