import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/features/home/presentation/providers/inicio_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_inicio.dart';

/// Todo test que arranca el router real pinta /inicio; si el repositorio de
/// Inicio no está reemplazado, el test llegaría a `Supabase.instance`.
void main() {
  group('appUnderTest', () {
    testWidgets('reemplaza el repositorio de Inicio por el fake', (
      tester,
    ) async {
      await tester.pumpWidget(appUnderTest(profile: vetProfile));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      expect(
        container.read(inicioRepositoryProvider),
        isA<FakeInicioRepository>(),
      );
    });
  });

  group('fuente', () {
    const archivos = [
      'test/router_cobros_cross_shell_test.dart',
      'test/router_vacunas_cross_shell_test.dart',
      'test/router_inventario_cross_shell_test.dart',
      'test/servicios_screen_test.dart',
    ];

    for (final archivo in archivos) {
      test('$archivo usa inicioShellOverrides()', () {
        final fuente = File(archivo).readAsStringSync();
        expect(fuente, contains('inicioShellOverrides()'));
      });
    }
  });
}
