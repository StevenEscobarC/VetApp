import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/features/clinic/domain/clinica_failure.dart';
import 'package:vetapp/features/clinic/presentation/providers/clinica_providers.dart';
import 'package:vetapp/features/clinic/presentation/widgets/clinica_logo.dart';

import 'helpers/fake_clinica.dart';
import 'helpers/fake_fotos.dart';

Widget _app(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: Scaffold(body: Center(child: child))),
    );

void main() {
  const path = 'c1/logo-1700000000000.jpg';
  final logo = find.byKey(const Key('logo-clinica'));

  testWidgets('sin logo no renderiza nada', (tester) async {
    await tester.pumpWidget(_app(const ClinicaLogo(logoPath: null)));
    expect(logo, findsNothing);
    await tester.pumpWidget(_app(const ClinicaLogo(logoPath: '')));
    expect(logo, findsNothing);
  });

  testWidgets('localBytes renderiza Image.memory', (tester) async {
    await tester.pumpWidget(_app(ClinicaLogo(localBytes: kFotoPrueba)));
    expect(logo, findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('error del provider degrada a nada sin excepción', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const ClinicaLogo(logoPath: path),
        overrides: [
          clinicaLogoUrlProvider(path).overrideWith(
            (ref) => throw const ClinicaFailure('No pudimos cargar el logo.'),
          ),
        ],
      ),
    );
    await tester.pump();
    expect(logo, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('con URL renderiza el logo con Semantics', (tester) async {
    await tester.pumpWidget(
      _app(
        const ClinicaLogo(logoPath: path),
        overrides: [
          clinicaLogoUrlProvider(
            path,
          ).overrideWith((ref) async => 'https://example.test/y'),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(logo, findsOneWidget);
    expect(find.bySemanticsLabel('Logo de la clínica'), findsOneWidget);
  });

  test('fakes exponen datos de prueba', () {
    expect(clinicaDePrueba.logoPath, isNull);
    expect(FakeClinicaRepository().llamadasActualizar, isEmpty);
    expect(FakeClinicaLogoDatasource().subidas, isEmpty);
  });
}
