import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:vetapp/features/auth/domain/auth_failure.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/home/presentation/screens/inicio_screen.dart';
import 'package:vetapp/features/patients/presentation/providers/mascota_foto_providers.dart';
import 'package:vetapp/features/patients/presentation/providers/mascotas_providers.dart';
import 'package:vetapp/features/vaccination/domain/entities/carne.dart';
import 'package:vetapp/features/vaccination/presentation/providers/vacuna_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_fotos.dart';
import 'helpers/fake_mascotas.dart';
import 'helpers/fake_vacunas.dart';
import 'helpers/router_harness.dart';

Widget _appUnderTest({
  AuthProfile? profile,
  Object? error,
  FakeVacunaRepository? vacunas,
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
        path: '/dosis/nueva',
        builder: (_, state) =>
            Text('DOSIS ${state.uri.queryParameters['mascotaId']}'),
      ),
    ],
    overrides: [
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: profile, error: error),
      ),
      vacunaRepositoryProvider.overrideWithValue(
        vacunas ?? FakeVacunaRepository(),
      ),
      mascotaRepositoryProvider.overrideWithValue(FakeMascotaRepository()),
      mascotaFotoDatasourceProvider.overrideWithValue(
        FakeMascotaFotoDatasource(),
      ),
    ],
  );
}

void main() {
  testWidgets('muestra nombre y clínica cuando hay perfil', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_appUnderTest(profile: vetProfile));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Ana Ramírez'), findsOneWidget);
    expect(find.text('Clínica Patitas'), findsOneWidget);
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

    expect(
      find.text('No pudimos cargar tu perfil. Intenta de nuevo.'),
      findsOneWidget,
    );
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

  testWidgets('tarjeta muestra Todo al día con 0/0', (tester) async {
    await tester.pumpWidget(_appUnderTest(profile: vetProfile));
    await tester.pumpAndSettle();

    expect(find.text('Vacunas pendientes'), findsOneWidget);
    expect(find.text('Todo al día'), findsOneWidget);
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
}
