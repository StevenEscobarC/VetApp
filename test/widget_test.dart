import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth.dart';

void main() {
  testWidgets('sin sesión arranca en login', (WidgetTester tester) async {
    await tester.pumpWidget(appUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido a VetApp'), findsOneWidget);
    expect(
      find.text('Gestiona tu clínica o cuida la salud de tus mascotas.'),
      findsOneWidget,
    );
    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('Olvidé mi contraseña'), findsOneWidget);
  });

  testWidgets('veterinario aterriza en Inicio', (WidgetTester tester) async {
    await tester.pumpWidget(appUnderTest(profile: vetProfile));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Ana Ramírez'), findsOneWidget);
    expect(find.text('Clínica Patitas'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    final navigationBar = find.byType(NavigationBar);
    for (final label in ['Inicio', 'Pacientes', 'Agenda', 'Clientes', 'Más']) {
      expect(
        find.descendant(of: navigationBar, matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(find.text('Bienvenido a VetApp'), findsNothing);
  });

  testWidgets('cambiar de pestaña', (WidgetTester tester) async {
    await tester.pumpWidget(appUnderTest(profile: vetProfile));
    await tester.pumpAndSettle();

    final navigationBar = find.byType(NavigationBar);
    await tester.tap(
      find.descendant(of: navigationBar, matching: find.text('Agenda')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Próximamente'), findsOneWidget);

    await tester.tap(
      find.descendant(of: navigationBar, matching: find.text('Inicio')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hola, Ana Ramírez'), findsOneWidget);
  });

  testWidgets('cerrar sesión desde Más', (WidgetTester tester) async {
    await tester.pumpWidget(appUnderTest(profile: vetProfile));
    await tester.pumpAndSettle();

    final navigationBar = find.byType(NavigationBar);
    await tester.tap(
      find.descendant(of: navigationBar, matching: find.text('Más')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido a VetApp'), findsOneWidget);
  });

  testWidgets('cliente va a /cliente', (WidgetTester tester) async {
    await tester.pumpWidget(appUnderTest(profile: clienteProfile));
    await tester.pumpAndSettle();

    expect(find.text('Mis mascotas'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('login muestra el bloque de marca', (WidgetTester tester) async {
    await tester.pumpWidget(appUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('VetApp'), findsOneWidget);
    expect(
      find.text('Tu consultorio veterinario en el bolsillo'),
      findsOneWidget,
    );
  });

  testWidgets('crear cuenta navega y regresa a login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(appUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    expect(
      find.text('Solo necesitamos unos datos para comenzar.'),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido a VetApp'), findsOneWidget);
  });

  testWidgets('olvidé mi contraseña navega a reset', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(appUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Olvidé mi contraseña'));
    await tester.pumpAndSettle();
    expect(
      find.text('Te enviaremos un enlace seguro a tu correo.'),
      findsOneWidget,
    );
  });

  testWidgets('iniciar sesión con campos vacíos muestra validación', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(appUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa tu correo y contraseña.'), findsOneWidget);
  });

  testWidgets('cliente cierra sesión', (WidgetTester tester) async {
    await tester.pumpWidget(appUnderTest(profile: clienteProfile));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido a VetApp'), findsOneWidget);
  });
}
