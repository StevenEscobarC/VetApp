import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/core/router/app_router.dart';
import 'package:vetapp/features/team/presentation/screens/acceso_revocado_screen.dart';

import 'helpers/fake_auth.dart';

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

String _ubicacion(WidgetTester tester) => _container(
  tester,
).read(routerProvider).routeInformationProvider.value.uri.path;

void _ir(WidgetTester tester, String path) =>
    _container(tester).read(routerProvider).go(path);

void main() {
  testWidgets('retired vet lands on /acceso-revocado and cannot leave', (
    tester,
  ) async {
    await tester.pumpWidget(appUnderTest(profile: vetRetiradoProfile));
    await tester.pumpAndSettle();
    expect(find.byType(AccesoRevocadoScreen), findsOneWidget);
    expect(_ubicacion(tester), '/acceso-revocado');

    _ir(tester, '/agenda');
    await tester.pumpAndSettle();
    expect(_ubicacion(tester), '/acceso-revocado');
    expect(find.byType(AccesoRevocadoScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('active vet never sees /acceso-revocado', (tester) async {
    await tester.pumpWidget(appUnderTest(profile: vetProfile));
    await tester.pumpAndSettle();
    expect(_ubicacion(tester), '/inicio');

    _ir(tester, '/acceso-revocado');
    await tester.pumpAndSettle();
    expect(_ubicacion(tester), '/inicio');
    expect(find.byType(AccesoRevocadoScreen), findsNothing);
  });

  testWidgets('cliente keeps its /cliente redirect', (tester) async {
    await tester.pumpWidget(appUnderTest(profile: clienteProfile));
    await tester.pumpAndSettle();
    expect(_ubicacion(tester), '/cliente');
    _ir(tester, '/acceso-revocado');
    await tester.pumpAndSettle();
    expect(_ubicacion(tester), '/cliente');
  });
}
