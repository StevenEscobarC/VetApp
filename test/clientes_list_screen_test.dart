import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/clients/domain/cliente_failure.dart';
import 'package:vetapp/features/clients/presentation/providers/clientes_providers.dart';
import 'package:vetapp/features/clients/presentation/screens/clientes_list_screen.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_clientes.dart';
import 'helpers/router_harness.dart';

Widget _appUnderTest({required FakeClienteRepository repo}) {
  return routerHarness(
    initialLocation: '/clientes',
    routes: [
      GoRoute(path: '/clientes', builder: (_, _) => const ClientesListScreen()),
    ],
    overrides: [
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: vetProfile),
      ),
      clienteRepositoryProvider.overrideWithValue(repo),
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
}
