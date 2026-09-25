import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetapp/core/widgets/buttons/app_button.dart';
import 'package:vetapp/core/widgets/chips/app_filter_chip.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/clients/presentation/clientes_routes.dart';
import 'package:vetapp/features/clients/presentation/providers/clientes_providers.dart';
import 'package:vetapp/features/patients/domain/entities/mascota.dart';
import 'package:vetapp/features/patients/domain/mascota_failure.dart';
import 'package:vetapp/features/patients/presentation/pacientes_routes.dart';
import 'package:vetapp/features/patients/presentation/providers/mascota_foto_providers.dart';
import 'package:vetapp/features/patients/presentation/providers/mascotas_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_clientes.dart';
import 'helpers/fake_fotos.dart';
import 'helpers/fake_mascotas.dart';
import 'helpers/router_harness.dart';

/// Boots the real route trees (both entry points wire into
/// `MascotaFormScreen`, D-03 + PAT-02 edit) with every repo/datasource/
/// capturador faked — mirrors `nuevo_cliente_mascota_screen_test.dart`'s
/// `_appUnderTest` shape.
Widget _appUnderTest({
  required String initialLocation,
  FakeMascotaRepository? mascotaRepo,
  FakeClienteRepository? clienteRepo,
  FakeMascotaFotoDatasource? fotoDatasource,
  Uint8List? fotoCapturada,
}) {
  return routerHarness(
    initialLocation: initialLocation,
    routes: [clientesRoute, pacientesRoute],
    overrides: [
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: vetProfile),
      ),
      clienteRepositoryProvider.overrideWithValue(
        clienteRepo ?? FakeClienteRepository(clientes: [clienteRita]),
      ),
      mascotaRepositoryProvider.overrideWithValue(
        mascotaRepo ??
            FakeMascotaRepository(mascotas: [mascotaRocky, mascotaLuna]),
      ),
      mascotaFotoDatasourceProvider.overrideWithValue(
        fotoDatasource ?? FakeMascotaFotoDatasource(),
      ),
      capturadorFotoProvider.overrideWithValue(capturadorFalso(fotoCapturada)),
    ],
  );
}

void main() {
  testWidgets(
    'desde la ficha del cliente, "Nueva mascota" abre el formulario con el '
    'dueño de solo lectura y sin volver a pedir el teléfono',
    (tester) async {
      await tester.pumpWidget(_appUnderTest(initialLocation: '/clientes/c-1'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.widgetWithText(AppButton, 'Nueva mascota'),
      );
      await tester.tap(find.widgetWithText(AppButton, 'Nueva mascota'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Rita Gómez'), findsOneWidget);
      expect(find.text('Teléfono *'), findsNothing);
    },
  );

  testWidgets(
    '"Nueva mascota" permanece deshabilitado hasta llenar nombre y especie; '
    'al guardar llama a registrarMascota una vez con el dueño de la ruta y '
    'regresa a la ficha del cliente',
    (tester) async {
      final repo = FakeMascotaRepository(mascotas: [mascotaRocky, mascotaLuna]);
      await tester.pumpWidget(
        _appUnderTest(
          initialLocation: '/clientes/c-1/nueva-mascota',
          mascotaRepo: repo,
        ),
      );
      await tester.pumpAndSettle();

      AppButton boton() => tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Nueva mascota'),
      );

      expect(boton().onPressed, isNull);

      await tester.enterText(find.byType(TextFormField).first, 'Toby');
      await tester.pump();
      expect(boton().onPressed, isNull, reason: 'aún falta la especie');

      await tester.ensureVisible(find.text('Perro'));
      await tester.tap(find.text('Perro'));
      await tester.pump();
      expect(boton().onPressed, isNotNull);

      await tester.tap(find.widgetWithText(AppButton, 'Nueva mascota'));
      await tester.pumpAndSettle();

      expect(repo.registrosMascota, hasLength(1));
      final registro = repo.registrosMascota.single;
      expect(registro.duenoId, 'c-1');
      expect(registro.nombre, 'Toby');
      expect(registro.especie, Especie.perro);

      expect(find.text('Rita Gómez'), findsOneWidget);
    },
  );

  testWidgets(
    'con foto capturada: al crear sube la foto y actualiza foto_path de la '
    'mascota recién creada',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = FakeMascotaRepository();
      final fotos = FakeMascotaFotoDatasource();
      await tester.pumpWidget(
        _appUnderTest(
          initialLocation: '/clientes/c-1/nueva-mascota',
          mascotaRepo: repo,
          fotoDatasource: fotos,
          fotoCapturada: kFotoPrueba,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.camera_alt_outlined));
      await tester.tap(find.byIcon(Icons.camera_alt_outlined));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Toby');
      await tester.ensureVisible(find.text('Perro'));
      await tester.tap(find.text('Perro'));
      await tester.pump();

      await tester.ensureVisible(
        find.widgetWithText(AppButton, 'Nueva mascota'),
      );
      await tester.tap(find.widgetWithText(AppButton, 'Nueva mascota'));
      await tester.pumpAndSettle();

      expect(fotos.uploads, [('cli-1', 'm-creada')]);
      expect(repo.fotoPathsActualizados['m-creada'], 'cli-1/m-creada/fake.jpg');
    },
  );

  testWidgets(
    'desde la ficha del paciente, "Editar" abre el formulario prellenado '
    'sin campo de peso; "Guardar cambios" permanece deshabilitado hasta un '
    'cambio y al guardar llama a actualizar una vez',
    (tester) async {
      final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      await tester.pumpWidget(
        _appUnderTest(initialLocation: '/pacientes/m-1', mascotaRepo: repo),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.widgetWithText(AppButton, 'Editar'));
      await tester.tap(find.widgetWithText(AppButton, 'Editar'));
      await tester.pumpAndSettle();

      expect(find.text('Peso (kg)'), findsNothing);
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).at(0)).controller!.text,
        'Rocky',
      );
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).at(1)).controller!.text,
        'Labrador',
      );
      expect(
        tester
            .widget<AppFilterChip>(find.widgetWithText(AppFilterChip, 'Perro'))
            .selected,
        isTrue,
      );

      AppButton boton() => tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Guardar cambios'),
      );
      expect(boton().onPressed, isNull);

      await tester.enterText(find.byType(TextFormField).at(1), 'Golden');
      await tester.pump();
      expect(boton().onPressed, isNotNull);

      await tester.tap(find.widgetWithText(AppButton, 'Guardar cambios'));
      await tester.pumpAndSettle();

      expect(repo.actualizados, hasLength(1));
      expect(repo.actualizados.single.raza, 'Golden');

      expect(find.text('Rocky'), findsOneWidget);
    },
  );

  testWidgets(
    'abrir /clientes/c-1/mascotas/m-1/editar también renderiza el '
    'formulario de edición (ambos árboles de rutas quedan conectados)',
    (tester) async {
      final repo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      await tester.pumpWidget(
        _appUnderTest(
          initialLocation: '/clientes/c-1/mascotas/m-1/editar',
          mascotaRepo: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppButton, 'Guardar cambios'), findsOneWidget);
      expect(find.text('Peso (kg)'), findsNothing);
    },
  );

  testWidgets(
    'si registrarMascota lanza MascotaFailure se muestra el mensaje y se '
    'queda en el formulario',
    (tester) async {
      const falla = MascotaFailure(
        'No pudimos guardar los datos. Intenta de nuevo.',
      );
      final repo = FakeMascotaRepository(error: falla);
      await tester.pumpWidget(
        _appUnderTest(
          initialLocation: '/clientes/c-1/nueva-mascota',
          mascotaRepo: repo,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Toby');
      await tester.ensureVisible(find.text('Perro'));
      await tester.tap(find.text('Perro'));
      await tester.pump();

      await tester.ensureVisible(
        find.widgetWithText(AppButton, 'Nueva mascota'),
      );
      await tester.tap(find.widgetWithText(AppButton, 'Nueva mascota'));
      await tester.pumpAndSettle();

      expect(
        find.text('No pudimos guardar los datos. Intenta de nuevo.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(AppButton, 'Nueva mascota'), findsOneWidget);
    },
  );
}
