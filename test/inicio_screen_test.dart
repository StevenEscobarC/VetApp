import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/features/inventory/domain/entities/producto.dart';
import 'package:vetapp/features/inventory/presentation/providers/inventario_providers.dart';
import 'package:vetapp/core/widgets/buttons/app_button.dart';
import 'package:vetapp/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:vetapp/features/auth/domain/auth_failure.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/plan/domain/mi_plan.dart';
import 'package:vetapp/features/home/domain/inicio_failure.dart';
import 'package:vetapp/features/home/domain/resumen_inicio.dart';
import 'package:vetapp/features/home/presentation/screens/inicio_screen.dart';
import 'package:vetapp/features/home/presentation/widgets/bloque_error.dart';
import 'package:vetapp/features/home/presentation/widgets/inicio_encabezado.dart';
import 'package:vetapp/features/home/presentation/widgets/metricas_mes.dart';
import 'package:vetapp/core/theme/app_spacing.dart';
import 'package:vetapp/core/widgets/app_bar/app_top_bar.dart';
import 'package:vetapp/features/patients/presentation/providers/mascota_foto_providers.dart';
import 'package:vetapp/features/patients/presentation/providers/mascotas_providers.dart';
import 'package:vetapp/features/vaccination/domain/entities/carne.dart';
import 'package:vetapp/features/vaccination/presentation/providers/vacuna_providers.dart';

import 'helpers/fake_inventario.dart';
import 'helpers/fake_auth.dart';
import 'helpers/fake_fotos.dart';
import 'helpers/fake_inicio.dart';
import 'helpers/fake_mascotas.dart';
import 'helpers/fake_plan.dart';
import 'helpers/fake_vacunas.dart';
import 'helpers/router_harness.dart';

Widget _appUnderTest({
  AuthProfile? profile,
  Object? error,
  FakeVacunaRepository? vacunas,
  FakeInicioRepository? inicio,
  FakeInventarioRepository? inventario,
  MiPlan? plan,
}) {
  return routerHarness(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const InicioScreen()),
      GoRoute(
        path: '/vacunas',
        builder: (_, _) => const Text('PANTALLA VACUNAS'),
      ),
      GoRoute(
        path: '/cobros',
        builder: (_, _) => const Text('PANTALLA COBROS'),
      ),
      GoRoute(
        path: '/pacientes',
        builder: (_, _) => const Text('PANTALLA PACIENTES'),
      ),
      GoRoute(
        path: '/dosis/nueva',
        builder: (_, state) =>
            Text('DOSIS ${state.uri.queryParameters['mascotaId']}'),
      ),
    ],
    overrides: [
      ...planOverrides(plan: plan),
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: profile, error: error),
      ),
      vacunaRepositoryProvider.overrideWithValue(
        vacunas ?? FakeVacunaRepository(),
      ),
      inventarioRepositoryProvider.overrideWithValue(
        inventario ?? FakeInventarioRepository(),
      ),
      mascotaRepositoryProvider.overrideWithValue(FakeMascotaRepository()),
      mascotaFotoDatasourceProvider.overrideWithValue(
        FakeMascotaFotoDatasource(),
      ),
      ...inicioOverrides(inicio: inicio),
    ],
  );
}

const _conVacunas = ResumenVacunas(
  vencidas: 3,
  proximas: 5,
  ocultasAntiguas: 0,
);

FakeInicioRepository _inicio42() => FakeInicioRepository(
  resumenData: const ResumenInicio(
    consultasMes: 42,
    ingresosMes: 3849999,
    pacientesNuevos: 7,
  ),
);

int _resumenes(List<({String metodo, Map<String, Object?> args})> l) =>
    l.where((c) => c.metodo == 'resumen').length;

double _top(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

void main() {
  testWidgets('muestra nombre y clínica cuando hay perfil', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_appUnderTest(profile: vetProfile));
    await tester.pumpAndSettle();

    expect(find.text('Hola,'), findsOneWidget);
    expect(find.text('Ana Ramírez'), findsOneWidget);
    expect(find.text('Clínica Patitas'), findsOneWidget);
    expect(find.byType(AppTopBar), findsNothing);
  });

  testWidgets('muestra mensaje de sin clínica cuando clinicaNombre es null', (
    WidgetTester tester,
  ) async {
    const profile = AuthProfile(
      id: 'vet-2',
      nombre: 'Ana Ramírez',
      email: 'ana@vetapp.co',
      rol: 'VETERINARIO',
      telefono: '',
      clinicaId: null,
      clinicaNombre: null,
    );
    await tester.pumpWidget(_appUnderTest(profile: profile));
    await tester.pumpAndSettle();

    expect(find.text('Sin clínica asignada'), findsOneWidget);
  });

  testWidgets('muestra estado sin sesión cuando el perfil es null', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_appUnderTest(profile: null));
    await tester.pumpAndSettle();

    expect(find.text('Sin sesión activa'), findsOneWidget);
    expect(
      find.text('Vuelve a iniciar sesión para ver tu información.'),
      findsOneWidget,
    );
  });

  testWidgets('muestra mensaje de error cuando build lanza AuthFailure', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _appUnderTest(error: const AuthFailure('No encontramos tu perfil.')),
    );
    await tester.pumpAndSettle();

    expect(find.text('No pudimos cargar tu perfil.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('tarjeta Vacunas pendientes con conteos y navega a /vacunas', (
    tester,
  ) async {
    final vacunas = FakeVacunaRepository(
      resumenData: const ResumenVacunas(
        vencidas: 3,
        proximas: 5,
        ocultasAntiguas: 0,
      ),
    );
    await tester.pumpWidget(
      _appUnderTest(profile: vetProfile, vacunas: vacunas),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vacunas pendientes'), findsOneWidget);
    expect(find.text('3 vencidas'), findsOneWidget);
    expect(find.text('5 próximas'), findsOneWidget);

    await tester.tap(find.text('Vacunas pendientes'));
    await tester.pumpAndSettle();
    expect(find.text('PANTALLA VACUNAS'), findsOneWidget);
  });

  testWidgets('en Inicio la tarjeta de vacunas se oculta con 0/0', (
    tester,
  ) async {
    await tester.pumpWidget(_appUnderTest(profile: vetProfile));
    await tester.pumpAndSettle();

    expect(find.text('Vacunas pendientes'), findsNothing);
    expect(find.text('Todo al día'), findsNothing);
  });

  testWidgets('error de la tarjeta muestra mensaje y Reintentar', (
    tester,
  ) async {
    await tester.pumpWidget(
      _appUnderTest(
        profile: vetProfile,
        vacunas: FakeVacunaRepository(error: Exception('boom')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No pudimos cargar las vacunas.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('acción Vacunar abre la hoja ¿A quién vacuna?', (tester) async {
    await tester.pumpWidget(_appUnderTest(profile: vetProfile));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vacunar'));
    await tester.pumpAndSettle();

    expect(find.text('¿A quién vacuna?'), findsOneWidget);
    expect(find.text('Buscar mascota o dueño'), findsOneWidget);
  });

  testWidgets('el aviso de plan va debajo del saludo y arriba de las cifras', (
    tester,
  ) async {
    await tester.pumpWidget(
      _appUnderTest(profile: vetProfile, plan: planGratisAlTope),
    );
    await tester.pumpAndSettle();

    final aviso = find.text('Llegaste a los 50 pacientes');
    expect(aviso, findsOneWidget);
    expect(
      _top(tester, aviso),
      greaterThan(_top(tester, find.text('Ana Ramírez'))),
    );
    expect(_top(tester, aviso), lessThan(_top(tester, find.text('Consultas'))));
  });

  testWidgets('sin aviso de plan Inicio queda igual', (tester) async {
    await tester.pumpWidget(_appUnderTest(profile: vetProfile));
    await tester.pumpAndSettle();
    expect(find.text('Ver mi plan'), findsNothing);
  });

  group('solo lectura (colega sin plan vigente)', () {
    testWidgets('"Vacunar" muestra candado y abre la hoja de solo lectura en '
        'vez del buscador', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _appUnderTest(profile: vetProfile, plan: planSoloLectura),
      );
      await tester.pumpAndSettle();

      final boton = find.widgetWithText(AppButton, 'Vacunar');
      expect(
        find.descendant(of: boton, matching: find.byIcon(Icons.lock_outline)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: boton,
          matching: find.byIcon(Icons.vaccines_outlined),
        ),
        findsNothing,
      );
      expect(
        tester.getSemantics(boton).label,
        contains('bloqueado, solo lectura'),
      );
      // Conserva el acento primario.
      expect(tester.widget<AppButton>(boton).variant, AppButtonVariant.primary);

      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();

      expect(find.text('¿A quién vacuna?'), findsNothing);
      // El aviso de Inicio y la hoja comparten el mismo título.
      expect(find.text('Tu cuenta está en solo lectura'), findsNWidgets(2));
      expect(find.text('Ahora no'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('el banner de solo lectura se muestra en Inicio', (
      tester,
    ) async {
      await tester.pumpWidget(
        _appUnderTest(profile: vetProfile, plan: planSoloLectura),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
    });

    testWidgets('con plan Beta "Vacunar" conserva el ícono y abre el '
        'buscador', (tester) async {
      await tester.pumpWidget(
        _appUnderTest(profile: vetProfile, plan: planBeta),
      );
      await tester.pumpAndSettle();

      final boton = find.widgetWithText(AppButton, 'Vacunar');
      expect(
        find.descendant(of: boton, matching: find.byIcon(Icons.lock_outline)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: boton,
          matching: find.byIcon(Icons.vaccines_outlined),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Vacunar'));
      await tester.pumpAndSettle();
      expect(find.text('¿A quién vacuna?'), findsOneWidget);
    });
  });

  group('Inicio fase 8 (slice 1)', () {
    testWidgets('orden: saludo, cifras, Vacunar, vacunas y stock', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _appUnderTest(
          profile: vetProfile,
          inicio: _inicio42(),
          vacunas: FakeVacunaRepository(resumenData: _conVacunas),
          inventario: FakeInventarioRepository(
            resumenData: const ResumenInventario(bajos: 2),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final orden = [
        find.byType(InicioEncabezado),
        find.byType(MetricasMes),
        find.widgetWithText(AppButton, 'Vacunar'),
        find.text('Vacunas pendientes'),
        find.text('2 productos con stock bajo'),
      ];
      for (var i = 1; i < orden.length; i++) {
        expect(_top(tester, orden[i]), greaterThan(_top(tester, orden[i - 1])));
      }
      expect(find.text('42'), findsOneWidget);
      expect(find.text('\$ 3,8 M'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('sin aviso de plan el hueco saludo-cifras es exactamente lg', (
      tester,
    ) async {
      await tester.pumpWidget(
        _appUnderTest(profile: vetProfile, inicio: _inicio42()),
      );
      await tester.pumpAndSettle();

      final finEncabezado = tester
          .getBottomLeft(find.byType(InicioEncabezado))
          .dy;
      expect(
        _top(tester, find.byType(MetricasMes)) - finEncabezado,
        AppSpacing.lg,
      );
    });

    testWidgets('las cifras navegan igual en solo lectura (D-06)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _appUnderTest(
          profile: vetProfile,
          plan: planSoloLectura,
          inicio: _inicio42(),
        ),
      );
      await tester.pumpAndSettle();
      // Las cifras no se bloquean: ningún candado dentro de ellas.
      expect(
        find.descendant(
          of: find.byType(MetricasMes),
          matching: find.byIcon(Icons.lock_outline),
        ),
        findsNothing,
      );
      await tester.tap(find.text('Ingresos'));
      await tester.pumpAndSettle();
      expect(find.text('PANTALLA COBROS'), findsOneWidget);
    });

    testWidgets('deslizar hacia abajo recarga resumen, vacunas y stock sin '
        'parpadeo de esqueleto', (tester) async {
      final inicio = _inicio42();
      final vacunas = FakeVacunaRepository(resumenData: _conVacunas);
      final inventario = FakeInventarioRepository(
        resumenData: const ResumenInventario(bajos: 2),
      );
      await tester.pumpWidget(
        _appUnderTest(
          profile: vetProfile,
          inicio: inicio,
          vacunas: vacunas,
          inventario: inventario,
        ),
      );
      await tester.pumpAndSettle();
      expect(inicio.llamadas, ['resumen']);
      final vacunasAntes = _resumenes(vacunas.llamadas);
      final stockAntes = _resumenes(inventario.llamadas);

      final bloqueo = Completer<void>();
      inicio.bloqueo = bloqueo;
      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(inicio.llamadas, ['resumen', 'resumen']);
      // Las cifras viejas siguen a la vista mientras recarga.
      expect(find.text('42'), findsOneWidget);
      expect(find.byKey(const ValueKey('metrica-esqueleto')), findsNothing);

      bloqueo.complete();
      await tester.pumpAndSettle();
      expect(_resumenes(vacunas.llamadas), greaterThan(vacunasAntes));
      expect(_resumenes(inventario.llamadas), greaterThan(stockAntes));
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('error del resumen: solo su bloque falla', (tester) async {
      await tester.pumpWidget(
        _appUnderTest(
          profile: vetProfile,
          inicio: FakeInicioRepository(
            error: const InicioFailure('No pudimos cargar el resumen del mes.'),
          ),
          vacunas: FakeVacunaRepository(resumenData: _conVacunas),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BloqueError), findsOneWidget);
      expect(
        find.text('No pudimos cargar el resumen del mes.'),
        findsOneWidget,
      );
      expect(find.text('Ana Ramírez'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Vacunar'), findsOneWidget);
      expect(find.text('Vacunas pendientes'), findsOneWidget);
    });

    testWidgets('error de vacunas no oculta las cifras', (tester) async {
      await tester.pumpWidget(
        _appUnderTest(
          profile: vetProfile,
          inicio: _inicio42(),
          vacunas: FakeVacunaRepository(error: Exception('boom')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No pudimos cargar las vacunas.'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.byType(BloqueError), findsNothing);
    });

    testWidgets('Reintentar del perfil vuelve a pedirlo', (tester) async {
      await tester.pumpWidget(
        _appUnderTest(error: const AuthFailure('No encontramos tu perfil.')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('No pudimos cargar tu perfil.'), findsOneWidget);
    });

    testWidgets('Inicio nunca dice Factura', (tester) async {
      await tester.pumpWidget(
        _appUnderTest(profile: vetProfile, inicio: _inicio42()),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(RegExp('[Ff]actur')), findsNothing);
    });
  });

  testWidgets('tarjeta de stock bajo en Inicio navega a Bajos', (tester) async {
    await tester.pumpWidget(
      _appInicioConInventario(
        FakeInventarioRepository(
          resumenData: const ResumenInventario(bajos: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 productos con stock bajo'), findsOneWidget);
    // Con 0/0 la tarjeta de vacunas no ocupa espacio en Inicio.
    expect(find.text('Vacunas pendientes'), findsNothing);

    await tester.tap(find.text('2 productos con stock bajo'));
    await tester.pumpAndSettle();
    expect(find.text('PANTALLA INVENTARIO bajos'), findsOneWidget);
  });

  testWidgets('sin bajos Inicio no muestra la tarjeta de stock', (
    tester,
  ) async {
    await tester.pumpWidget(
      _appInicioConInventario(FakeInventarioRepository()),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('stock bajo'), findsNothing);
  });
}

Widget _appInicioConInventario(FakeInventarioRepository inventario) {
  return routerHarness(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const InicioScreen()),
      GoRoute(
        path: '/inventario',
        builder: (_, state) =>
            Text('PANTALLA INVENTARIO ${state.uri.queryParameters['filtro']}'),
      ),
    ],
    overrides: [
      ...planOverrides(),
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: vetProfile),
      ),
      vacunaRepositoryProvider.overrideWithValue(FakeVacunaRepository()),
      inventarioRepositoryProvider.overrideWithValue(inventario),
      mascotaRepositoryProvider.overrideWithValue(FakeMascotaRepository()),
      mascotaFotoDatasourceProvider.overrideWithValue(
        FakeMascotaFotoDatasource(),
      ),
      ...inicioOverrides(),
    ],
  );
}
