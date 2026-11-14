import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/core/errors/limite_plan.dart';
import 'package:vetapp/core/utils/telefono_co.dart';
import 'package:vetapp/core/widgets/buttons/app_button.dart';
import 'package:vetapp/core/widgets/inputs/app_text_field.dart';
import 'package:vetapp/features/clients/data/repositories/supabase_cliente_repository.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/clients/domain/cliente_failure.dart';
import 'package:vetapp/features/clients/domain/entities/cliente.dart';
import 'package:vetapp/features/clients/presentation/providers/clientes_providers.dart';
import 'package:vetapp/features/clients/presentation/screens/cliente_detail_screen.dart';
import 'package:vetapp/features/clients/presentation/widgets/vinculacion_sheet.dart';
import 'package:vetapp/features/patients/presentation/providers/mascotas_providers.dart';
import 'package:vetapp/features/plan/domain/mi_plan.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_clientes.dart';
import 'helpers/fake_mascotas.dart';
import 'helpers/fake_plan.dart';
import 'helpers/router_harness.dart';

/// Field order rendered by [ClienteDetailScreen]: 'Nombre *' (0),
/// 'Teléfono *' (1), 'Correo' (2), 'Dirección' (3), 'Notas' (4).
const _campoNombre = 0;
const _campoTelefono = 1;

Widget _appUnderTest({
  String initialLocation = '/clientes/c-1',
  FakeClienteRepository? clienteRepo,
  FakeMascotaRepository? mascotaRepo,
  MiPlan? plan,
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
            routes: [
              GoRoute(
                path: 'nueva-mascota',
                builder: (_, _) => const Scaffold(body: Text('NUEVA MASCOTA')),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/agenda/nueva',
        builder: (_, state) => Text('nueva-cita ${state.uri.query}'),
      ),
    ],
    overrides: [
      ...planOverrides(plan: plan),
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: vetProfile),
      ),
      clienteRepositoryProvider.overrideWithValue(
        clienteRepo ??
            FakeClienteRepository(clientes: [clienteRita, clientePedro]),
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
    '"Agendar cita" es outline y navega a /agenda/nueva con clienteId',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_appUnderTest());
      await tester.pumpAndSettle();

      final boton = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Agendar cita'),
      );
      expect(boton.variant, AppButtonVariant.outline);
      final primarios = tester
          .widgetList<AppButton>(find.byType(AppButton))
          .where((b) => b.variant == AppButtonVariant.primary);
      expect(primarios, hasLength(1));

      await tester.ensureVisible(find.text('Agendar cita'));
      await tester.tap(find.text('Agendar cita'));
      await tester.pumpAndSettle();

      expect(find.text('nueva-cita clienteId=c-1'), findsOneWidget);
    },
  );

  testWidgets('muestra el nombre como encabezado y el teléfono precargado', (
    tester,
  ) async {
    await tester.pumpWidget(_appUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Rita Gómez'), findsWidgets);
    final telefonoField = tester.widget<TextFormField>(
      find.byType(TextFormField).at(_campoTelefono),
    );
    expect(telefonoField.controller!.text, '3001234567');
  });

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

      await tester.enterText(find.byType(TextFormField).at(_campoNombre), '');
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

  testWidgets('editar el teléfono a "+57 300 123 4567" guarda 573001234567', (
    tester,
  ) async {
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
  });

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
            .widget<AppButton>(
              find.widgetWithText(AppButton, 'Guardar cambios'),
            )
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

  testWidgets('un cliente sin mascotas muestra el estado vacío', (
    tester,
  ) async {
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
  });

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

  testWidgets('reemplazoExpirado true muestra el aviso de código expirado', (
    tester,
  ) async {
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
  });

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
        _appUnderTest(
          initialLocation: '/clientes/c-3',
          clienteRepo: clienteRepo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cuenta vinculada'), findsOneWidget);
      expect(find.text('Vincular cuenta'), findsNothing);
    },
  );

  group('límites del plan', () {
    Future<void> abrir(WidgetTester tester, MiPlan plan) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_appUnderTest(plan: plan));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Nueva mascota'));
    }

    testWidgets('Gratis con 50 pacientes: "Nueva mascota" abre la hoja y no '
        'navega', (tester) async {
      await abrir(tester, planGratisAlTope);
      await tester.tap(find.text('Nueva mascota'));
      await tester.pumpAndSettle();

      expect(find.text('Llegaste a los 50 pacientes'), findsOneWidget);
      expect(find.text('NUEVA MASCOTA'), findsNothing);
    });

    testWidgets('con plan Beta navega al formulario de mascota', (
      tester,
    ) async {
      await abrir(tester, planBeta);
      await tester.tap(find.text('Nueva mascota'));
      await tester.pumpAndSettle();

      expect(find.text('NUEVA MASCOTA'), findsOneWidget);
    });

    testWidgets('en solo lectura muestra candado, semántica bloqueada y la '
        'hoja de solo lectura', (tester) async {
      final semantics = tester.ensureSemantics();
      await abrir(tester, planSoloLectura);

      final boton = find.widgetWithText(AppButton, 'Nueva mascota');
      expect(
        find.descendant(of: boton, matching: find.byIcon(Icons.lock_outline)),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(boton).label,
        contains('bloqueado, solo lectura'),
      );

      await tester.tap(find.text('Nueva mascota'));
      await tester.pumpAndSettle();

      expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
      expect(find.text('NUEVA MASCOTA'), findsNothing);
      semantics.dispose();
    });

    testWidgets('en solo lectura "Agendar cita" muestra candado y abre la '
        'hoja sin navegar', (tester) async {
      await abrir(tester, planSoloLectura);

      final boton = find.widgetWithText(AppButton, 'Agendar cita');
      expect(
        find.descendant(of: boton, matching: find.byIcon(Icons.lock_outline)),
        findsOneWidget,
      );
      expect(tester.widget<AppButton>(boton).variant, AppButtonVariant.outline);

      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();

      expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
      expect(find.textContaining('nueva-cita'), findsNothing);
    });

    testWidgets('en solo lectura "Guardar cambios" muestra candado, abre la '
        'hoja y no llama actualizar (aunque no haya cambios)', (tester) async {
      final semantics = tester.ensureSemantics();
      final repo = FakeClienteRepository(clientes: [clienteRita, clientePedro]);
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _appUnderTest(plan: planSoloLectura, clienteRepo: repo),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Guardar cambios'));

      final boton = find.widgetWithText(AppButton, 'Guardar cambios');
      expect(
        find.descendant(of: boton, matching: find.byIcon(Icons.lock_outline)),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(boton).label,
        contains('bloqueado, solo lectura'),
      );
      expect(tester.widget<AppButton>(boton).variant, AppButtonVariant.primary);

      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
      expect(repo.actualizados, isEmpty);
      semantics.dispose();
    });

    testWidgets('con plan Beta "Guardar cambios" no lleva candado y guarda '
        'como antes', (tester) async {
      final repo = FakeClienteRepository(clientes: [clienteRita, clientePedro]);
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_appUnderTest(plan: planBeta, clienteRepo: repo));
      await tester.pumpAndSettle();

      final boton = find.widgetWithText(AppButton, 'Guardar cambios');
      expect(
        find.descendant(of: boton, matching: find.byIcon(Icons.lock_outline)),
        findsNothing,
      );
      await tester.enterText(
        find.byType(TextFormField).at(_campoTelefono),
        '3005550000',
      );
      await tester.pump();
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();

      expect(repo.actualizados, hasLength(1));
      expect(find.text('Tu cuenta está en solo lectura'), findsNothing);
    });

    testWidgets('LP004 del servidor con bandera vencida abre la hoja y '
        'conserva lo escrito', (tester) async {
      final repo = FakeClienteRepository(
        clientes: [clienteRita, clientePedro],
        errorActualizar: const ClienteFailure(
          'Tu cuenta está en solo lectura. Pide al administrador que active '
          'el plan.',
          limite: LimitePlan.soloLectura,
        ),
      );
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_appUnderTest(plan: planBeta, clienteRepo: repo));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(_campoTelefono),
        '3005550000',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Guardar cambios'));
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
      expect(find.textContaining('Pide al administrador'), findsNothing);
      expect(
        tester
            .widget<TextFormField>(
              find.byType(TextFormField).at(_campoTelefono),
            )
            .controller!
            .text,
        '3005550000',
      );
    });
  });

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
        textoVigencia(ahora.add(const Duration(hours: 5, minutes: 10)), ahora),
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

  group('Cédula opcional del cliente (D-24)', () {
    const ritaConCedula = Cliente(
      id: 'c-1',
      clinicaId: 'cli-1',
      nombre: 'Rita Gómez',
      telefono: '3001234567',
      cedula: '1020304050',
      numeroMascotas: 2,
    );

    Finder campoCedula() => find.descendant(
      of: find.widgetWithText(AppTextField, 'Cédula (opcional)'),
      matching: find.byType(TextFormField),
    );

    String textoCedula(WidgetTester tester) =>
        tester.widget<TextFormField>(campoCedula()).controller!.text;

    AppButton botonGuardar(WidgetTester tester) => tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Guardar cambios'),
    );

    Future<void> abrir(WidgetTester tester, FakeClienteRepository repo) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_appUnderTest(clienteRepo: repo));
      await tester.pumpAndSettle();
    }

    Future<void> desenfocar(WidgetTester tester) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    }

    Future<void> guardar(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Guardar cambios'));
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'aparece entre Dirección y Notas con su ayuda; la pantalla rápida '
      'no se toca',
      (tester) async {
        await abrir(
          tester,
          FakeClienteRepository(clientes: [clienteRita, clientePedro]),
        );
        expect(find.text('Cédula (opcional)'), findsOneWidget);
        expect(
          find.text('Sale en las cuentas de cobro de este cliente.'),
          findsOneWidget,
        );
        final yDireccion = tester.getTopLeft(find.text('Dirección')).dy;
        final yCedula = tester.getTopLeft(find.text('Cédula (opcional)')).dy;
        final yNotas = tester.getTopLeft(find.text('Notas')).dy;
        expect(yDireccion < yCedula, isTrue);
        expect(yCedula < yNotas, isTrue);
        final campo = tester.widget<TextField>(
          find.descendant(of: campoCedula(), matching: find.byType(TextField)),
        );
        expect(campo.keyboardType, TextInputType.number);
        expect(campo.maxLength, 12);
      },
    );

    testWidgets(
      'escribir 1.020.304.050 y guardar envía solo dígitos; sin foco se ve '
      'con puntos',
      (tester) async {
        final repo = FakeClienteRepository(
          clientes: [clienteRita, clientePedro],
        );
        await abrir(tester, repo);
        await tester.enterText(campoCedula(), '1.020.304.050');
        await tester.pump();
        expect(botonGuardar(tester).onPressed, isNotNull);
        await guardar(tester);
        expect(repo.actualizados.single.cedula, '1020304050');
        await desenfocar(tester);
        expect(textoCedula(tester), '1.020.304.050');
      },
    );

    testWidgets('una cédula guardada se muestra con puntos', (tester) async {
      await abrir(
        tester,
        FakeClienteRepository(clientes: [ritaConCedula, clientePedro]),
      );
      expect(textoCedula(tester), '1.020.304.050');
      expect(botonGuardar(tester).onPressed, isNull);
    });

    testWidgets('1234 muestra el error y no guarda nada', (tester) async {
      final repo = FakeClienteRepository(clientes: [clienteRita, clientePedro]);
      await abrir(tester, repo);
      await tester.enterText(campoCedula(), '1234');
      await desenfocar(tester);
      expect(
        find.text('Revisa la cédula: debe tener entre 5 y 12 números.'),
        findsOneWidget,
      );
      expect(botonGuardar(tester).onPressed, isNull);
      await guardar(tester);
      expect(repo.actualizados, isEmpty);
    });

    testWidgets('vaciar la cédula marca el formulario y guarda null', (
      tester,
    ) async {
      final repo = FakeClienteRepository(
        clientes: [ritaConCedula, clientePedro],
      );
      await abrir(tester, repo);
      await tester.enterText(campoCedula(), '');
      await tester.pump();
      expect(botonGuardar(tester).onPressed, isNotNull);
      await guardar(tester);
      expect(repo.actualizados.single.cedula, isNull);
    });

    testWidgets('cambiar solo la cédula marca el formulario como sucio', (
      tester,
    ) async {
      await abrir(
        tester,
        FakeClienteRepository(clientes: [ritaConCedula, clientePedro]),
      );
      expect(botonGuardar(tester).onPressed, isNull);
      await tester.enterText(campoCedula(), '1020304051');
      await tester.pump();
      expect(botonGuardar(tester).onPressed, isNotNull);
      // Enfocar sin cambiar (solo quita los puntos) no ensucia el formulario.
      await tester.enterText(campoCedula(), '1020304050');
      await tester.pump();
      expect(botonGuardar(tester).onPressed, isNull);
    });

    test('desdeFila mapea cedula y deja en null la cadena vacía', () {
      Map<String, dynamic> fila(String? cedula) => {
        'id': 'c-1',
        'clinica_id': 'cli-1',
        'nombre': 'Rita Gómez',
        'telefono': '3001234567',
        'cedula': cedula,
        'mascotas': [
          {'count': 1},
        ],
      };
      expect(
        SupabaseClienteRepository.desdeFila(fila('1020304050')).cedula,
        '1020304050',
      );
      expect(SupabaseClienteRepository.desdeFila(fila('')).cedula, isNull);
      expect(SupabaseClienteRepository.desdeFila(fila(null)).cedula, isNull);
    });
  });
}
