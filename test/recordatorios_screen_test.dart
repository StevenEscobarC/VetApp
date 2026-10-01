import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetapp/features/appointments/presentation/providers/recordatorios_providers.dart';
import 'package:vetapp/features/appointments/presentation/screens/recordatorios_screen.dart';

import 'helpers/fake_recordatorios.dart';
import 'helpers/router_harness.dart';

Widget _app(FakeRecordatoriosService fake, {List<Override> extra = const []}) =>
    routerHarness(
      initialLocation: '/mas/recordatorios',
      routes: [
        GoRoute(
          path: '/mas/recordatorios',
          builder: (_, _) => const RecordatoriosScreen(),
        ),
      ],
      overrides: [
        recordatoriosServiceProvider.overrideWithValue(fake),
        ...extra,
      ],
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('muestra textos y 1 hora antes seleccionada por defecto', (
    tester,
  ) async {
    await tester.pumpWidget(_app(FakeRecordatoriosService()));
    await tester.pumpAndSettle();

    expect(find.text('Recordatorios'), findsOneWidget);
    expect(find.text('Avisarme antes de cada cita'), findsOneWidget);
    expect(find.text('Se aplica a todas tus citas.'), findsOneWidget);
    for (final t in [
      '15 minutos antes',
      '30 minutos antes',
      '1 hora antes',
      '2 horas antes',
    ]) {
      expect(find.text(t), findsOneWidget);
    }
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text('Recordatorios desactivados'), findsNothing);
  });

  testWidgets('elegir 15 minutos persiste, confirma y marca la fila', (
    tester,
  ) async {
    await tester.pumpWidget(_app(FakeRecordatoriosService()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RecordatoriosScreen)),
    );

    await tester.tap(find.text('15 minutos antes'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('recordatorio_minutos_antes'), 15);
    expect(find.text('Recordatorio actualizado'), findsOneWidget);
    expect(container.read(anticipacionRecordatorioProvider).value, 15);
  });

  testWidgets('sin permiso muestra aviso y Abrir ajustes', (tester) async {
    final fake = FakeRecordatoriosService()..permiso = false;
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    expect(find.text('Recordatorios desactivados'), findsOneWidget);
    await tester.tap(find.text('Abrir ajustes'));
    await tester.pump();
    expect(fake.ajustesAbiertos, 1);
  });

  testWidgets('si guardar falla muestra el error', (tester) async {
    await tester.pumpWidget(
      _app(
        FakeRecordatoriosService(),
        extra: [
          sharedPreferencesProvider.overrideWith(
            (ref) async => _PrefsQueFalla(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 minutos antes'));
    await tester.pumpAndSettle();
    expect(
      find.text('No pudimos guardar el ajuste. Intenta de nuevo.'),
      findsOneWidget,
    );
  });
}

class _PrefsQueFalla implements SharedPreferences {
  @override
  int? getInt(String key) => null;

  @override
  Future<bool> setInt(String key, int value) => throw StateError('falla');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
