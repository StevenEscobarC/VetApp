import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vetapp/core/theme/app_colors.dart';
import 'package:vetapp/core/theme/app_spacing.dart';
import 'package:vetapp/core/theme/app_theme.dart';
import 'package:vetapp/core/widgets/buttons/app_button.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/auth/presentation/screens/auth_scaffold.dart';
import 'package:vetapp/features/auth/presentation/screens/client_home_screen.dart';
import 'package:vetapp/features/auth/presentation/screens/login_screen.dart';

import 'helpers/fake_auth.dart';
import 'helpers/router_harness.dart';

const _archivos = [
  'lib/features/auth/presentation/screens/login_screen.dart',
  'lib/features/auth/presentation/screens/reset_password_screen.dart',
  'lib/features/auth/presentation/screens/auth_scaffold.dart',
  'lib/features/auth/presentation/screens/client_home_screen.dart',
  'lib/main.dart',
];

/// Source without `//` comments, so doc text never trips the guard.
String _sinComentarios(String path) => File(
  path,
).readAsLinesSync().map((l) => l.replaceFirst(RegExp(r'//.*$'), '')).join('\n');

class _SignOutSpy extends FakeAuthProfileNotifier {
  _SignOutSpy() : super(profile: clienteProfile);

  int signOuts = 0;

  @override
  Future<void> signOut() async {
    signOuts++;
    await super.signOut();
  }
}

Widget _scaffold(ThemeData theme) => MaterialApp(
  theme: theme,
  home: const AuthScaffold(
    title: 'Título',
    subtitle: 'Subtítulo',
    success: 'Listo',
    children: [],
  ),
);

void main() {
  group('fuente', () {
    for (final path in _archivos) {
      test('$path sin TextButton, TextStyle ni números de espaciado', () {
        final src = _sinComentarios(path);
        expect(src.contains('TextButton('), isFalse, reason: 'TextButton(');
        expect(src.contains('TextStyle('), isFalse, reason: 'TextStyle(');
        expect(
          RegExp(r'SizedBox\((height|width): *[0-9]').hasMatch(src),
          isFalse,
          reason: 'SizedBox numérico',
        );
        expect(
          RegExp(r'EdgeInsets\.\w+\([^)]*[^a-zA-Z_.0-9][0-9]').hasMatch(src),
          isFalse,
          reason: 'EdgeInsets numérico',
        );
      });
    }
  });

  group('login', () {
    Widget harness() => routerHarness(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
        GoRoute(
          path: '/reset-password',
          builder: (_, _) => const Scaffold(body: Text('RUTA RESET')),
        ),
        GoRoute(
          path: '/register',
          builder: (_, _) => const Scaffold(body: Text('RUTA REGISTRO')),
        ),
      ],
    );

    for (final label in ['Olvidé mi contraseña', 'Crear cuenta']) {
      testWidgets('$label es AppButton de al menos 48 dp', (tester) async {
        tester.view.physicalSize = const Size(900, 2000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(harness());
        await tester.pumpAndSettle();
        final boton = find.widgetWithText(AppButton, label);
        expect(boton, findsOneWidget);
        expect(
          tester.getSize(boton).height,
          greaterThanOrEqualTo(AppSpacing.touchTarget),
        );
      });
    }

    testWidgets('Olvidé mi contraseña lleva a /reset-password', (tester) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Olvidé mi contraseña'));
      await tester.pumpAndSettle();
      expect(find.text('RUTA RESET'), findsOneWidget);
    });

    testWidgets('Crear cuenta lleva a /register', (tester) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Crear cuenta'));
      await tester.pumpAndSettle();
      expect(find.text('RUTA REGISTRO'), findsOneWidget);
    });

    testWidgets('éxito de auth_scaffold usa success en claro', (tester) async {
      await tester.pumpWidget(_scaffold(AppTheme.light));
      expect(
        tester.widget<Text>(find.text('Listo')).style?.color,
        AppColors.success,
      );
    });

    testWidgets('éxito de auth_scaffold usa successBg en oscuro', (
      tester,
    ) async {
      await tester.pumpWidget(_scaffold(AppTheme.dark));
      expect(
        tester.widget<Text>(find.text('Listo')).style?.color,
        AppColors.successBg,
      );
    });
  });

  group('cliente', () {
    testWidgets('sin CTAs muertos y con cerrar sesión intacto', (tester) async {
      final spy = _SignOutSpy();
      await tester.pumpWidget(
        ProviderScope(
          retry: (retryCount, error) => null,
          overrides: [authProfileProvider.overrideWith(() => spy)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const ClientHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mis mascotas'), findsOneWidget);
      expect(find.text('Aún no tienes mascotas registradas.'), findsOneWidget);
      expect(
        find.text(
          'Tu veterinario registra tus mascotas; aquí podrás consultar su '
          'historial.',
        ),
        findsOneWidget,
      );
      expect(find.text('Agregar mascota'), findsNothing);
      expect(find.text('Agendar cita'), findsNothing);
      expect(find.byType(AppButton), findsNothing);

      await tester.tap(find.byTooltip('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(spy.signOuts, 1);
    });
  });
}
