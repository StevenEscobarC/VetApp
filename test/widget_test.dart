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
      find.descendant(of: navigationBar, matching: find.text('Pacientes')),
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
}
