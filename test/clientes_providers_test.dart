import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetapp/core/data/busqueda.dart';
import 'package:vetapp/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/clients/domain/cliente_failure.dart';
import 'package:vetapp/features/clients/presentation/providers/clientes_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_clientes.dart';

const _vetSinClinica = AuthProfile(
  id: 'vet-2',
  nombre: 'Sin Clínica',
  email: 'sinclinica@vetapp.co',
  rol: 'VETERINARIO',
  telefono: '',
);

ProviderContainer _containerWith({
  required FakeClienteRepository repo,
  AuthProfile? profile = vetProfile,
}) {
  final container = ProviderContainer(
    overrides: [
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: profile),
      ),
      clienteRepositoryProvider.overrideWithValue(repo),
    ],
  );
  return container;
}

void main() {
  group('sanitizarBusqueda', () {
    test('elimina comas y paréntesis, colapsa espacios y recorta', () {
      expect(sanitizarBusqueda(' Rita (Gómez), '), 'Rita Gómez');
    });

    test('texto solo de espacios queda vacío', () {
      expect(sanitizarBusqueda('   '), '');
    });
  });

  group('filtroOrIlike', () {
    test('combina columnas con ilike separadas por coma', () {
      expect(
        filtroOrIlike(columnas: ['nombre', 'telefono'], query: 'rita'),
        'nombre.ilike.%rita%,telefono.ilike.%rita%',
      );
    });

    test('query vacía o en blanco devuelve null', () {
      expect(filtroOrIlike(columnas: ['nombre'], query: ''), isNull);
      expect(filtroOrIlike(columnas: ['nombre'], query: '   '), isNull);
    });

    test('agrega columnaIn/valoresIn cuando valoresIn no está vacío', () {
      expect(
        filtroOrIlike(
          columnas: ['nombre', 'telefono'],
          query: 'rita',
          columnaIn: 'dueno_id',
          valoresIn: const ['a', 'b'],
        ),
        'nombre.ilike.%rita%,telefono.ilike.%rita%,dueno_id.in.(a,b)',
      );
    });

    test('valoresIn vacío no agrega nada', () {
      expect(
        filtroOrIlike(
          columnas: ['nombre'],
          query: 'rita',
          columnaIn: 'dueno_id',
          valoresIn: const [],
        ),
        'nombre.ilike.%rita%',
      );
    });
  });

  group('clientesProvider', () {
    test('build carga los clientes del repositorio y hace una búsqueda ('
        ') con el clinicaId del perfil', () async {
      final repo = FakeClienteRepository(
        clientes: [clienteRita, clientePedro],
      );
      final container = _containerWith(repo: repo);
      addTearDown(container.dispose);

      final clientes = await container.read(clientesProvider.future);

      expect(clientes, hasLength(2));
      expect(repo.busquedas, [('', 'cli-1')]);
    });

    test('perfil sin clinicaId devuelve lista vacía sin llamar al '
        'repositorio', () async {
      final repo = FakeClienteRepository(clientes: [clienteRita]);
      final container = _containerWith(repo: repo, profile: _vetSinClinica);
      addTearDown(container.dispose);

      final clientes = await container.read(clientesProvider.future);

      expect(clientes, isEmpty);
      expect(repo.busquedas, isEmpty);
    });

    test('cuando el repositorio lanza ClienteFailure el estado es '
        'AsyncError con esa falla', () async {
      const failure = ClienteFailure('No pudimos cargar la lista.');
      final repo = FakeClienteRepository(error: failure);
      final container = _containerWith(repo: repo);
      addTearDown(container.dispose);

      await expectLater(
        container.read(clientesProvider.future),
        throwsA(same(failure)),
      );
      expect(
        container.read(clientesProvider),
        isA<AsyncError<List<dynamic>>>(),
      );
    });

    testWidgets(
      'search hace debounce de tecleo rápido en una sola consulta a los '
      '350ms',
      (tester) async {
        final repo = FakeClienteRepository(
          clientes: [clienteRita, clientePedro],
        );
        final container = _containerWith(repo: repo);
        addTearDown(container.dispose);

        await container.read(clientesProvider.future);
        expect(repo.busquedas, hasLength(1));

        container.read(clientesProvider.notifier).search('r');
        await tester.pump(const Duration(milliseconds: 100));
        container.read(clientesProvider.notifier).search('ri');
        await tester.pump(const Duration(milliseconds: 100));
        container.read(clientesProvider.notifier).search('rit');

        await tester.pump(const Duration(milliseconds: 349));
        expect(repo.busquedas, hasLength(1));

        await tester.pump(const Duration(milliseconds: 2));
        expect(repo.busquedas, hasLength(2));
        expect(repo.busquedas.last, ('rit', 'cli-1'));
      },
    );
  });
}
