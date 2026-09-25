import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/core/utils/captura_foto.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/patients/domain/entities/peso_registro.dart';
import 'package:vetapp/features/patients/presentation/providers/mascota_foto_providers.dart';
import 'package:vetapp/features/patients/presentation/providers/mascotas_providers.dart';
import 'package:vetapp/features/patients/presentation/screens/mascota_detail_screen.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_fotos.dart';
import 'helpers/fake_mascotas.dart';
import 'helpers/router_harness.dart';

/// Historial de peso de Rocky (m-1), seedeado deliberadamente fuera de
/// orden (enero, junio, marzo) — la pantalla es la que debe ordenar de
/// forma defensiva, no el fake.
final _pesosRocky = [
  PesoRegistro(
    id: 'p-1',
    mascotaId: 'm-1',
    pesoKg: 10,
    registradoEn: DateTime(2026, 1, 10),
  ),
  PesoRegistro(
    id: 'p-2',
    mascotaId: 'm-1',
    pesoKg: 12.5,
    registradoEn: DateTime(2026, 6, 1),
  ),
  PesoRegistro(
    id: 'p-3',
    mascotaId: 'm-1',
    pesoKg: 11,
    registradoEn: DateTime(2026, 3, 15),
  ),
];

Widget _appUnderTest({
  required FakeMascotaRepository repo,
  FakeMascotaFotoDatasource? fotos,
  CapturadorFoto? capturador,
  String initialLocation = '/pacientes/m-1',
}) {
  return routerHarness(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/pacientes',
        builder: (_, _) => const Text('LISTA PACIENTES'),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) => MascotaDetailScreen(
              mascotaId: state.pathParameters['id']!,
              rutaBase: state.uri.path,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/clientes/:id',
        builder: (_, state) =>
            Text('FICHA CLIENTE ${state.pathParameters['id']}'),
      ),
    ],
    overrides: [
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: vetProfile),
      ),
      mascotaRepositoryProvider.overrideWithValue(repo),
      mascotaFotoDatasourceProvider.overrideWithValue(
        fotos ?? FakeMascotaFotoDatasource(),
      ),
      capturadorFotoProvider.overrideWithValue(
        capturador ?? capturadorFalso(null),
      ),
    ],
  );
}

void main() {
  testWidgets('muestra los datos de la mascota y el nombre del dueño', (
    tester,
  ) async {
    final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
    await tester.pumpWidget(_appUnderTest(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Rocky'), findsOneWidget);
    expect(find.textContaining('Perro'), findsOneWidget);
    expect(find.textContaining('Labrador'), findsOneWidget);
    expect(find.text('Rita Gómez'), findsOneWidget);
  });

  testWidgets(
    'el historial de peso se muestra del más reciente al más antiguo',
    (tester) async {
      final repo = FakeMascotaRepository(
        mascotas: [mascotaRocky],
        pesosPorMascota: {'m-1': _pesosRocky},
      );
      await tester.pumpWidget(_appUnderTest(repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('01/06/2026'), findsOneWidget);
      expect(find.text('12,5 kg'), findsOneWidget);
      expect(find.text('11 kg'), findsOneWidget);
      expect(find.text('10 kg'), findsOneWidget);

      final y125 = tester.getTopLeft(find.text('12,5 kg')).dy;
      final y11 = tester.getTopLeft(find.text('11 kg')).dy;
      final y10 = tester.getTopLeft(find.text('10 kg')).dy;
      expect(y125, lessThan(y11));
      expect(y11, lessThan(y10));
    },
  );

  testWidgets('mascota sin pesos registrados muestra el estado vacío', (
    tester,
  ) async {
    final repo = FakeMascotaRepository(mascotas: [mascotaLuna]);
    await tester.pumpWidget(
      _appUnderTest(repo: repo, initialLocation: '/pacientes/m-2'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aún no hay pesos registrados'), findsOneWidget);
    expect(
      find.text('Usa “Registrar peso” para agregar el primero.'),
      findsOneWidget,
    );
  });

  testWidgets('no hay acciones de editar o borrar en el historial de peso', (
    tester,
  ) async {
    final repo = FakeMascotaRepository(
      mascotas: [mascotaRocky],
      pesosPorMascota: {'m-1': _pesosRocky},
    );
    await tester.pumpWidget(_appUnderTest(repo: repo));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byIcon(Icons.delete), findsNothing);
  });

  testWidgets(
    'Registrar peso valida un peso inválido sin llamar al repositorio, y '
    'guarda uno válido mostrándolo arriba del historial',
    (tester) async {
      final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      await tester.pumpWidget(_appUnderTest(repo: repo));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Registrar peso'));
      await tester.tap(find.text('Registrar peso'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '0');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa un peso válido en kg'), findsOneWidget);
      expect(repo.pesosRegistrados, isEmpty);

      await tester.enterText(find.byType(TextFormField), '13,2');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(repo.pesosRegistrados, [(mascotaId: 'm-1', pesoKg: 13.2)]);
      expect(find.text('13,2 kg'), findsOneWidget);
    },
  );

  testWidgets(
    'el AppPhotoPicker de la ficha recibe fotoPath y cacheKey coincidentes',
    (tester) async {
      final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      await tester.pumpWidget(_appUnderTest(repo: repo));
      await tester.pumpAndSettle();

      final img = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(img.cacheKey, 'cli-1/m-1/1.jpg');
    },
  );

  testWidgets(
    'tocar el avatar sube la nueva foto, actualiza foto_path y borra la '
    'anterior en segundo plano',
    (tester) async {
      final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      final fotos = FakeMascotaFotoDatasource();
      await tester.pumpWidget(
        _appUnderTest(
          repo: repo,
          fotos: fotos,
          capturador: capturadorFalso(kFotoPrueba),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.camera_alt_outlined));
      await tester.pumpAndSettle();

      expect(fotos.uploads, [('cli-1', 'm-1')]);
      expect(repo.fotoPathsActualizados['m-1'], 'cli-1/m-1/fake.jpg');
      expect(fotos.eliminados, ['cli-1/m-1/1.jpg']);
    },
  );

  testWidgets('tocar el nombre del dueño navega a su ficha de cliente', (
    tester,
  ) async {
    final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
    await tester.pumpWidget(_appUnderTest(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rita Gómez'));
    await tester.pumpAndSettle();

    expect(find.text('FICHA CLIENTE c-1'), findsOneWidget);
  });
}
