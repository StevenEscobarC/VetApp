import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/core/utils/telefono_co.dart';
import 'package:vetapp/core/widgets/buttons/app_button.dart';
import 'package:vetapp/core/widgets/chips/app_filter_chip.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/clients/presentation/providers/clientes_providers.dart';
import 'package:vetapp/features/clients/presentation/screens/nuevo_cliente_mascota_screen.dart';
import 'package:vetapp/features/patients/domain/entities/mascota.dart';
import 'package:vetapp/features/patients/domain/mascota_failure.dart';
import 'package:vetapp/features/patients/presentation/providers/mascota_foto_providers.dart';
import 'package:vetapp/features/patients/presentation/providers/mascotas_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_clientes.dart';
import 'helpers/fake_fotos.dart';
import 'helpers/fake_mascotas.dart';
import 'helpers/router_harness.dart';

/// Field order rendered by [NuevoClienteMascotaScreen]: cliente nombre (0),
/// teléfono (1), mascota nombre (2), then — only once "Agregar más
/// detalles" is expanded — raza (3), fecha de nacimiento (4), peso (5).
const _campoClienteNombre = 0;
const _campoTelefono = 1;
const _campoMascotaNombre = 2;
const _campoFecha = 4;

Widget _appUnderTest({
  required FakeMascotaRepository mascotaRepo,
  FakeClienteRepository? clienteRepo,
  FakeMascotaFotoDatasource? fotoDatasource,
  Uint8List? fotoCapturada,
}) {
  return routerHarness(
    initialLocation: '/clientes/nuevo',
    routes: [
      GoRoute(
        path: '/clientes',
        builder: (_, _) => const Scaffold(body: Text('LISTA')),
        routes: [
          GoRoute(
            path: 'nuevo',
            builder: (_, _) => const NuevoClienteMascotaScreen(),
          ),
        ],
      ),
    ],
    overrides: [
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: vetProfile),
      ),
      mascotaRepositoryProvider.overrideWithValue(mascotaRepo),
      clienteRepositoryProvider.overrideWithValue(
        clienteRepo ?? FakeClienteRepository(),
      ),
      mascotaFotoDatasourceProvider.overrideWithValue(
        fotoDatasource ?? FakeMascotaFotoDatasource(),
      ),
      capturadorFotoProvider.overrideWithValue(
        capturadorFalso(fotoCapturada),
      ),
    ],
  );
}

Future<void> _llenarCamposRequeridos(WidgetTester tester) async {
  await tester.enterText(
    find.byType(TextFormField).at(_campoClienteNombre),
    'Rita Gómez',
  );
  await tester.enterText(
    find.byType(TextFormField).at(_campoTelefono),
    '3001234567',
  );
  await tester.enterText(
    find.byType(TextFormField).at(_campoMascotaNombre),
    'Rocky',
  );
  await tester.ensureVisible(find.text('Perro'));
  await tester.tap(find.text('Perro'));
  await tester.pump();
}

Future<void> _expandirDetalles(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Agregar más detalles'));
  await tester.tap(find.text('Agregar más detalles'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'muestra ambas secciones en una sola pantalla continua, sin pasos',
    (tester) async {
      await tester.pumpWidget(
        _appUnderTest(mascotaRepo: FakeMascotaRepository()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Datos del dueño'), findsOneWidget);
      expect(find.text('Datos de la mascota'), findsOneWidget);
      expect(find.text('Siguiente'), findsNothing);
      expect(find.byType(PageView), findsNothing);
      expect(find.byType(Stepper), findsNothing);
    },
  );

  testWidgets(
    '"Guardar cliente y mascota" permanece deshabilitado hasta llenar los '
    'cuatro campos requeridos',
    (tester) async {
      await tester.pumpWidget(
        _appUnderTest(mascotaRepo: FakeMascotaRepository()),
      );
      await tester.pumpAndSettle();

      AppButton boton() => tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Guardar cliente y mascota'),
      );

      expect(boton().onPressed, isNull);

      await tester.enterText(
        find.byType(TextFormField).at(_campoClienteNombre),
        'Rita Gómez',
      );
      await tester.enterText(
        find.byType(TextFormField).at(_campoTelefono),
        '3001234567',
      );
      await tester.enterText(
        find.byType(TextFormField).at(_campoMascotaNombre),
        'Rocky',
      );
      await tester.pump();
      expect(boton().onPressed, isNull, reason: 'aún falta la especie');

      await tester.ensureVisible(find.text('Perro'));
      await tester.tap(find.text('Perro'));
      await tester.pump();
      expect(boton().onPressed, isNotNull);
    },
  );

  testWidgets(
    'el campo Raza permanece oculto hasta expandir "Agregar más detalles"',
    (tester) async {
      await tester.pumpWidget(
        _appUnderTest(mascotaRepo: FakeMascotaRepository()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Raza'), findsNothing);

      await _expandirDetalles(tester);

      expect(find.text('Raza'), findsOneWidget);
    },
  );

  testWidgets('seleccionar una especie deselecciona la anterior', (
    tester,
  ) async {
    await tester.pumpWidget(
      _appUnderTest(mascotaRepo: FakeMascotaRepository()),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Gato'));
    await tester.tap(find.text('Gato'));
    await tester.pump();
    var chipGato = tester.widget<AppFilterChip>(
      find.widgetWithText(AppFilterChip, 'Gato'),
    );
    expect(chipGato.selected, isTrue);

    await tester.ensureVisible(find.text('Perro'));
    await tester.tap(find.text('Perro'));
    await tester.pump();
    chipGato = tester.widget<AppFilterChip>(
      find.widgetWithText(AppFilterChip, 'Gato'),
    );
    final chipPerro = tester.widget<AppFilterChip>(
      find.widgetWithText(AppFilterChip, 'Perro'),
    );
    expect(chipGato.selected, isFalse);
    expect(chipPerro.selected, isTrue);
  });

  testWidgets(
    'enviar el formulario llama al repositorio una vez con los valores '
    'recortados y regresa a /clientes',
    (tester) async {
      final repo = FakeMascotaRepository();
      await tester.pumpWidget(_appUnderTest(mascotaRepo: repo));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(_campoClienteNombre),
        '  Rita Gómez ',
      );
      await tester.enterText(
        find.byType(TextFormField).at(_campoTelefono),
        '3001234567',
      );
      await tester.enterText(
        find.byType(TextFormField).at(_campoMascotaNombre),
        'Rocky',
      );
      await tester.ensureVisible(find.text('Perro'));
      await tester.tap(find.text('Perro'));
      await tester.pump();

      await tester.ensureVisible(find.text('Guardar cliente y mascota'));
      await tester.tap(find.text('Guardar cliente y mascota'));
      await tester.pumpAndSettle();

      expect(repo.registros, hasLength(1));
      final registro = repo.registros.single;
      expect(registro.clienteNombre, 'Rita Gómez');
      expect(registro.clienteTelefono, '573001234567');
      expect(registro.mascotaNombre, 'Rocky');
      expect(registro.mascotaEspecie, Especie.perro);

      expect(find.text('LISTA'), findsOneWidget);
    },
  );

  testWidgets(
    'una fecha con formato inválido muestra el error en línea y no llama '
    'al repositorio',
    (tester) async {
      final repo = FakeMascotaRepository();
      await tester.pumpWidget(_appUnderTest(mascotaRepo: repo));
      await tester.pumpAndSettle();

      await _llenarCamposRequeridos(tester);
      await _expandirDetalles(tester);

      await tester.enterText(
        find.byType(TextFormField).at(_campoFecha),
        '31/02/2020',
      );
      await tester.pump();

      await tester.ensureVisible(find.text('Guardar cliente y mascota'));
      await tester.tap(find.text('Guardar cliente y mascota'));
      await tester.pumpAndSettle();

      expect(find.text('Usa el formato dd/mm/aaaa'), findsOneWidget);
      expect(repo.registros, isEmpty);
    },
  );

  testWidgets(
    'si el repositorio lanza MascotaFailure se muestra el mensaje y se '
    'queda en el formulario',
    (tester) async {
      const falla = MascotaFailure(
        'No pudimos guardar los datos. Intenta de nuevo.',
      );
      final repo = FakeMascotaRepository(error: falla);
      await tester.pumpWidget(_appUnderTest(mascotaRepo: repo));
      await tester.pumpAndSettle();

      await _llenarCamposRequeridos(tester);

      await tester.ensureVisible(find.text('Guardar cliente y mascota'));
      await tester.tap(find.text('Guardar cliente y mascota'));
      await tester.pumpAndSettle();

      expect(
        find.text('No pudimos guardar los datos. Intenta de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('Datos del dueño'), findsOneWidget);
    },
  );

  testWidgets(
    'con foto: tocar el avatar muestra la vista previa y tras guardar sube '
    'la foto y actualiza foto_path',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = FakeMascotaRepository();
      final fotos = FakeMascotaFotoDatasource();
      await tester.pumpWidget(
        _appUnderTest(
          mascotaRepo: repo,
          fotoDatasource: fotos,
          fotoCapturada: kFotoPrueba,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.camera_alt_outlined));
      await tester.tap(find.byIcon(Icons.camera_alt_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);

      await _llenarCamposRequeridos(tester);

      await tester.ensureVisible(find.text('Guardar cliente y mascota'));
      await tester.tap(find.text('Guardar cliente y mascota'));
      await tester.pumpAndSettle();

      expect(fotos.uploads, [('cli-1', 'm-nuevo')]);
      expect(repo.fotoPathsActualizados['m-nuevo'], 'cli-1/m-nuevo/fake.jpg');
      expect(find.text('LISTA'), findsOneWidget);
    },
  );

  testWidgets('teléfono "300 123 4567" se envía normalizado una sola vez', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = FakeMascotaRepository();
    await tester.pumpWidget(_appUnderTest(mascotaRepo: repo));
    await tester.pumpAndSettle();

    await _llenarCamposRequeridos(tester);
    await tester.enterText(
      find.byType(TextFormField).at(_campoTelefono),
      '300 123 4567',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Guardar cliente y mascota'));
    await tester.tap(find.text('Guardar cliente y mascota'));
    await tester.pumpAndSettle();

    expect(repo.registros, hasLength(1));
    expect(repo.registros.single.clienteTelefono, '573001234567');
  });

  testWidgets(
    'un fijo muestra el aviso suave tras salir del campo y no bloquea el '
    'guardado',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = FakeMascotaRepository();
      await tester.pumpWidget(_appUnderTest(mascotaRepo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Ej. 300 123 4567'), findsOneWidget);
      expect(find.text(kAvisoTelefono), findsNothing);

      await tester.enterText(
        find.byType(TextFormField).at(_campoTelefono),
        '6012345678',
      );
      await tester.pump();
      expect(
        find.text(kAvisoTelefono),
        findsNothing,
        reason: 'el aviso aparece solo tras salir del campo',
      );

      await tester.tap(find.byType(TextFormField).at(_campoMascotaNombre));
      await tester.pump();

      expect(find.text(kAvisoTelefono), findsOneWidget);
      expect(find.text('Ej. 300 123 4567'), findsNothing);

      await tester.enterText(
        find.byType(TextFormField).at(_campoClienteNombre),
        'Rita Gómez',
      );
      await tester.enterText(
        find.byType(TextFormField).at(_campoMascotaNombre),
        'Rocky',
      );
      await tester.ensureVisible(find.text('Perro'));
      await tester.tap(find.text('Perro'));
      await tester.pump();
      expect(
        tester
            .widget<AppButton>(
              find.widgetWithText(AppButton, 'Guardar cliente y mascota'),
            )
            .onPressed,
        isNotNull,
      );

      await tester.ensureVisible(find.text('Guardar cliente y mascota'));
      await tester.tap(find.text('Guardar cliente y mascota'));
      await tester.pumpAndSettle();
      expect(repo.registros.single.clienteTelefono, '576012345678');
    },
  );

  testWidgets(
    'con devolverResultado, el llamador recibe (clienteId, mascotaId); sin '
    'la bandera solo se cierra',
    (tester) async {
      ({String clienteId, String mascotaId})? recibido;
      final repo = FakeMascotaRepository();
      await tester.pumpWidget(
        routerHarness(
          initialLocation: '/padre',
          routes: [
            GoRoute(
              path: '/padre',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    recibido = await context
                        .push<({String clienteId, String mascotaId})>(
                          '/hijo',
                        );
                  },
                  child: const Text('ABRIR'),
                ),
              ),
            ),
            GoRoute(
              path: '/hijo',
              builder: (_, _) =>
                  const NuevoClienteMascotaScreen(devolverResultado: true),
            ),
          ],
          overrides: [
            authProfileProvider.overrideWith(
              () => FakeAuthProfileNotifier(profile: vetProfile),
            ),
            mascotaRepositoryProvider.overrideWithValue(repo),
            clienteRepositoryProvider.overrideWithValue(
              FakeClienteRepository(),
            ),
            mascotaFotoDatasourceProvider.overrideWithValue(
              FakeMascotaFotoDatasource(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('ABRIR'));
      await tester.pumpAndSettle();

      await _llenarCamposRequeridos(tester);
      await tester.ensureVisible(find.text('Guardar cliente y mascota'));
      await tester.tap(find.text('Guardar cliente y mascota'));
      await tester.pumpAndSettle();

      expect(recibido, (clienteId: 'c-nuevo', mascotaId: 'm-nuevo'));
    },
  );

  testWidgets('sin foto nunca llama a upload', (tester) async {
    final repo = FakeMascotaRepository();
    final fotos = FakeMascotaFotoDatasource();
    await tester.pumpWidget(
      _appUnderTest(mascotaRepo: repo, fotoDatasource: fotos),
    );
    await tester.pumpAndSettle();

    await _llenarCamposRequeridos(tester);

    await tester.ensureVisible(find.text('Guardar cliente y mascota'));
    await tester.tap(find.text('Guardar cliente y mascota'));
    await tester.pumpAndSettle();

    expect(fotos.uploads, isEmpty);
    expect(find.text('LISTA'), findsOneWidget);
  });

  testWidgets(
    'si subir la foto falla se muestra el snackbar y de todos modos '
    'regresa a la lista porque los registros ya se guardaron',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = FakeMascotaRepository();
      const falla = MascotaFailure(
        'No pudimos subir la foto. Intenta de nuevo.',
      );
      final fotos = FakeMascotaFotoDatasource(error: falla);
      await tester.pumpWidget(
        _appUnderTest(
          mascotaRepo: repo,
          fotoDatasource: fotos,
          fotoCapturada: kFotoPrueba,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.camera_alt_outlined));
      await tester.tap(find.byIcon(Icons.camera_alt_outlined));
      await tester.pumpAndSettle();

      await _llenarCamposRequeridos(tester);

      await tester.ensureVisible(find.text('Guardar cliente y mascota'));
      await tester.tap(find.text('Guardar cliente y mascota'));
      await tester.pumpAndSettle();

      expect(
        find.text('No pudimos subir la foto. Intenta de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('LISTA'), findsOneWidget);
    },
  );
}
