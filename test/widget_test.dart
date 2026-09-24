import 'package:flutter_test/flutter_test.dart';

import 'package:vetapp/main.dart';

void main() {
  testWidgets('VetApp boots to the login screen and exposes account creation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VetApp());

    expect(find.text('Bienvenido a VetApp'), findsOneWidget);
    expect(
      find.text('Gestiona tu clínica o cuida la salud de tus mascotas.'),
      findsOneWidget,
    );

    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('Olvidé mi contraseña'), findsOneWidget);
  });
}
