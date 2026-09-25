import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetapp/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/patients/data/repositories/supabase_mascota_repository.dart';
import 'package:vetapp/features/patients/presentation/providers/mascotas_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_mascotas.dart';

const _vetSinClinica = AuthProfile(
  id: 'vet-2',
  nombre: 'Sin Clínica',
  email: 'sinclinica@vetapp.co',
  rol: 'VETERINARIO',
  telefono: '',
);

ProviderContainer _containerWith({
  required FakeMascotaRepository repo,
  AuthProfile? profile = vetProfile,
}) {
  final container = ProviderContainer(
    // Same convention as clientes_providers_test.dart: disable Riverpod 3's
    // default exponential-backoff retry so an intentionally thrown
    // MascotaFailure settles into AsyncError immediately.
    retry: (retryCount, error) => null,
    overrides: [
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: profile),
      ),
      mascotaRepositoryProvider.overrideWithValue(repo),
    ],
  );
  return container;
}

void main() {
  group('buscarMascotasEnDosPasos', () {
    test('query vacía nunca llama resolverDuenos y llama consultar(null)', () async {
      final llamadas = <String>[];

      final resultado = await buscarMascotasEnDosPasos(
        query: '',
        resolverDuenos: (q) async {
          llamadas.add('resolverDuenos:$q');
          return [];
        },
        consultar: (filtro) async {
          llamadas.add('consultar:$filtro');
          return [];
        },
      );

      expect(resultado, isEmpty);
      expect(llamadas, ['consultar:null']);
    });

    test(
      "query 'rita' con resolverDuenos -> ['c-1']: orden de llamadas y "
      'filtro con in-clause',
      () async {
        final llamadas = <String>[];
        String? filtroCapturado;

        await buscarMascotasEnDosPasos(
          query: 'rita',
          resolverDuenos: (q) async {
            llamadas.add('resolverDuenos:$q');
            return ['c-1'];
          },
          consultar: (filtro) async {
            llamadas.add('consultar');
            filtroCapturado = filtro;
            return [];
          },
        );

        expect(llamadas, ['resolverDuenos:rita', 'consultar']);
        expect(
          filtroCapturado,
          'nombre.ilike.%rita%,especie.ilike.%rita%,dueno_id.in.(c-1)',
        );
      },
    );

    test('sin match de dueño no agrega in-clause', () async {
      String? filtroCapturado;

      await buscarMascotasEnDosPasos(
        query: 'luna',
        resolverDuenos: (q) async => [],
        consultar: (filtro) async {
          filtroCapturado = filtro;
          return [];
        },
      );

      expect(filtroCapturado, 'nombre.ilike.%luna%,especie.ilike.%luna%');
    });

    test(
      'la query se sanea (comas y paréntesis eliminados) antes de ambos '
      'pasos',
      () async {
        String? resolverQ;
        String? filtroCapturado;

        await buscarMascotasEnDosPasos(
          query: 'Rocky(),',
          resolverDuenos: (q) async {
            resolverQ = q;
            return [];
          },
          consultar: (filtro) async {
            filtroCapturado = filtro;
            return [];
          },
        );

        expect(resolverQ, 'Rocky');
        expect(filtroCapturado, 'nombre.ilike.%Rocky%,especie.ilike.%Rocky%');
      },
    );
  });

  group('mascotasProvider', () {
    test(
      'build carga las mascotas del repositorio y hace una búsqueda ('
      ") con el clinicaId del perfil",
      () async {
        final repo = FakeMascotaRepository(
          mascotas: [mascotaRocky, mascotaLuna, mascotaMichi],
        );
        final container = _containerWith(repo: repo);
        addTearDown(container.dispose);

        final mascotas = await container.read(mascotasProvider.future);

        expect(mascotas, hasLength(3));
        expect(repo.busquedas, [('', 'cli-1')]);
      },
    );

    test(
      'perfil sin clinicaId devuelve lista vacía sin llamar al repositorio',
      () async {
        final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
        final container = _containerWith(
          repo: repo,
          profile: _vetSinClinica,
        );
        addTearDown(container.dispose);

        final mascotas = await container.read(mascotasProvider.future);

        expect(mascotas, isEmpty);
        expect(repo.busquedas, isEmpty);
      },
    );

    testWidgets(
      'search hace debounce de tecleo rápido en una sola consulta a los '
      '350ms',
      (tester) async {
        final repo = FakeMascotaRepository(
          mascotas: [mascotaRocky, mascotaLuna, mascotaMichi],
        );
        final container = _containerWith(repo: repo);
        addTearDown(container.dispose);

        await container.read(mascotasProvider.future);
        expect(repo.busquedas, hasLength(1));

        container.read(mascotasProvider.notifier).search('r');
        await tester.pump(const Duration(milliseconds: 100));
        container.read(mascotasProvider.notifier).search('ro');
        await tester.pump(const Duration(milliseconds: 100));
        container.read(mascotasProvider.notifier).search('roc');

        await tester.pump(const Duration(milliseconds: 349));
        expect(repo.busquedas, hasLength(1));

        await tester.pump(const Duration(milliseconds: 2));
        expect(repo.busquedas, hasLength(2));
        expect(repo.busquedas.last, ('roc', 'cli-1'));
      },
    );
  });
}
