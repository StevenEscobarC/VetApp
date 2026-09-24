import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetapp/core/theme/app_theme.dart';
import 'package:vetapp/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:vetapp/features/auth/domain/auth_failure.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/home/presentation/screens/inicio_screen.dart';

import 'helpers/fake_auth.dart';

Widget _appUnderTest({AuthProfile? profile, Object? error}) {
  return ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: profile, error: error),
      ),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const InicioScreen()),
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
}
