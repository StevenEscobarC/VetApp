import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/core/utils/telefono_co.dart';
import 'package:vetapp/core/widgets/buttons/app_button.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/clients/domain/cliente_failure.dart';
import 'package:vetapp/features/clients/domain/entities/cliente.dart';
import 'package:vetapp/features/clients/presentation/providers/clientes_providers.dart';
import 'package:vetapp/features/clients/presentation/screens/cliente_detail_screen.dart';
import 'package:vetapp/features/clients/presentation/widgets/vinculacion_sheet.dart';
import 'package:vetapp/features/patients/presentation/providers/mascotas_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_clientes.dart';
import 'helpers/fake_mascotas.dart';
import 'helpers/router_harness.dart';

/// Field order rendered by [ClienteDetailScreen]: 'Nombre *' (0),
/// 'Teléfono *' (1), 'Correo' (2), 'Dirección' (3), 'Notas' (4).
const _campoNombre = 0;
const _campoTelefono = 1;

Widget _appUnderTest({
  String initialLocation = '/clientes/c-1',
  FakeClienteRepository? clienteRepo,
  FakeMascotaRepository? mascotaRepo,
}) {
  return routerHarness(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/clientes',
        builder: (_, _) => const Scaffold(body: Text('LISTA')),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                ClienteDetailScreen(clienteId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
    overrides: [
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: vetProfile),
      ),
      clienteRepositoryProvider.overrideWithValue(
        clienteRepo ?? FakeClienteRepository(clientes: [clienteRita, clientePedro]),
      ),
      mascotaRepositoryProvider.overrideWithValue(
        mascotaRepo ??
            FakeMascotaRepository(
              mascotas: [mascotaRocky, mascotaLuna, mascotaMichi],
            ),
      ),
    ],
  );
}

Future<void> _abrirVinculacion(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Vincular cuenta'));
  await tester.tap(find.text('Vincular cuenta'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'muestra el nombre como encabezado y el teléfono precargado',
    (tester) async {
      await tester.pumpWidget(_appUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Rita Gómez'), findsWidgets);
      final telefonoField = tester.widget<TextFormField>(
        find.byType(TextFormField).at(_campoTelefono),
      );
      expect(telefonoField.controller!.text, '3001234567');
    },
  );

  testWidgets(
    '"Guardar cambios" se habilita solo cuando algo cambia y los campos '
    'requeridos no están vacíos; guardar llama actualizar una vez y muestra '
    'el snackbar de confirmación',
    (tester) async {
      final clienteRepo = FakeClienteRepository(
        clientes: [clienteRita, clientePedro],
      );
      await tester.pumpWidget(_appUnderTest(clienteRepo: clienteRepo));
      await tester.pumpAndSettle();

      AppButton boton() => tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Guardar cambios'),
      );
      expect(boton().onPressed, isNull);

      await tester.enterText(
        find.byType(TextFormField).at(_campoTelefono),
        '3005550000',
      );
      await tester.pump();
      expect(boton().onPressed, isNotNull);

      await tester.enterText(
        find.byType(TextFormField).at(_campoNombre),
        '',
      );
      await tester.pump();
      expect(
        boton().onPressed,
        isNull,
        reason: 'limpiar Nombre * lo deshabilita de nuevo',
      );

      await tester.enterText(
        find.byType(TextFormField).at(_campoNombre),
        'Rita Gómez',
      );
      await tester.pump();
      expect(boton().onPressed, isNotNull);

      await tester.ensureVisible(find.text('Guardar cambios'));
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(clienteRepo.actualizados, hasLength(1));
      expect(clienteRepo.actualizados.single.telefono, '573005550000');
      expect(find.text('Cambios guardados'), findsOneWidget);
    },
  );

  testWidgets(
    'editar el teléfono a "+57 300 123 4567" guarda 573001234567',
    (tester) async {
      final clienteRepo = FakeClienteRepository(
        clientes: [clienteRita, clientePedro],
      );
      await tester.pumpWidget(_appUnderTest(clienteRepo: clienteRepo));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(_campoTelefono),
        '+57 300 123 4567',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Guardar cambios'));
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(clienteRepo.actualizados.single.telefono, '573001234567');
    },
  );

  testWidgets(
    'un teléfono de 7 dígitos muestra el aviso suave tras salir del campo',
    (tester) async {
      await tester.pumpWidget(_appUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Ej. 300 123 4567'), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField).at(_campoTelefono),
        '2345678',
      );
      await tester.pump();
      expect(find.text(kAvisoTelefono), findsNothing);

      await tester.tap(find.byType(TextFormField).at(_campoNombre));
      await tester.pump();

      expect(find.text(kAvisoTelefono), findsOneWidget);
      expect(
        tester
            .widget<AppButton>(find.widgetWithText(AppButton, 'Guardar cambios'))
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'la sección Mascotas solo muestra las del cliente, nunca las de otro '
    'dueño',
    (tester) async {
      await tester.pumpWidget(_appUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Rocky'), findsOneWidget);
      expect(find.text('Luna'), findsOneWidget);
      expect(find.text('Michi'), findsNothing);
    },
  );

  testWidgets(
    'un cliente sin mascotas muestra el estado vacío',
    (tester) async {
      await tester.pumpWidget(_appUnderTest(initialLocation: '/clientes/c-2'));
      await tester.pumpAndSettle();

      expect(
        find.text('Este cliente no tiene mascotas registradas'),
        findsOneWidget,
      );
      expect(
        find.text('Usa “Nueva mascota” para agregar la primera.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'tocar "Vincular cuenta" abre la hoja con el código, la vigencia y '
    '"Copiar código"; tocar "Copiar código" copia el código al portapapeles',
    (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(_appUnderTest());
      await tester.pumpAndSettle();

      await _abrirVinculacion(tester);

      expect(find.text('482915'), findsOneWidget);
      expect(find.text('Válido por 24 horas'), findsOneWidget);
      expect(find.text('Copiar código'), findsOneWidget);

      await tester.tap(find.text('Copiar código'));
      await tester.pumpAndSettle();

      expect(calls.any((call) => call.method == 'Clipboard.setData'), isTrue);
      expect(find.text('Código copiado'), findsOneWidget);
    },
  );

  testWidgets(
    'reemplazoExpirado true muestra el aviso de código expirado',
    (tester) async {
      final clienteRepo = FakeClienteRepository(
        clientes: [clienteRita, clientePedro],
        codigoResultado: (
          codigo: '482915',
          expiraEn: DateTime.now().add(const Duration(hours: 24)),
          reemplazoExpirado: true,
        ),
      );
      await tester.pumpWidget(_appUnderTest(clienteRepo: clienteRepo));
      await tester.pumpAndSettle();

      await _abrirVinculacion(tester);

      expect(
        find.text('El código anterior expiró. Se generó uno nuevo.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'si generar el código falla, la hoja muestra el mensaje de error',
    (tester) async {
      final clienteRepo = FakeClienteRepository(
        clientes: [clienteRita, clientePedro],
        errorCodigo: const ClienteFailure(
          'No pudimos generar el código. Intenta de nuevo.',
        ),
      );
      await tester.pumpWidget(_appUnderTest(clienteRepo: clienteRepo));
      await tester.pumpAndSettle();

      await _abrirVinculacion(tester);

      expect(
        find.text('No pudimos generar el código. Intenta de nuevo.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'un cliente con perfilesId ya vinculado muestra "Cuenta vinculada" y no '
    'la acción "Vincular cuenta"',
    (tester) async {
      const clienteVinculado = Cliente(
        id: 'c-3',
        clinicaId: 'cli-1',
        nombre: 'Otra Persona',
        telefono: '3000000000',
        perfilesId: 'perfil-1',
      );
      final clienteRepo = FakeClienteRepository(clientes: [clienteVinculado]);
      await tester.pumpWidget(
        _appUnderTest(initialLocation: '/clientes/c-3', clienteRepo: clienteRepo),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cuenta vinculada'), findsOneWidget);
      expect(find.text('Vincular cuenta'), findsNothing);
    },
  );

  group('textoVigencia', () {
    test('24 horas exactas -> "Válido por 24 horas"', () {
      final ahora = DateTime(2026, 1, 1, 12, 0, 0);
      expect(
        textoVigencia(ahora.add(const Duration(hours: 24)), ahora),
        'Válido por 24 horas',
      );
    });

    test('5h10m restantes -> "Válido por 6 horas más"', () {
      final ahora = DateTime(2026, 1, 1, 12, 0, 0);
      expect(
        textoVigencia(
          ahora.add(const Duration(hours: 5, minutes: 10)),
          ahora,
        ),
        'Válido por 6 horas más',
      );
    });

    test('30 minutos restantes -> "Válido por menos de 1 hora"', () {
      final ahora = DateTime(2026, 1, 1, 12, 0, 0);
      expect(
        textoVigencia(ahora.add(const Duration(minutes: 30)), ahora),
        'Válido por menos de 1 hora',
      );
    });
  });
}
