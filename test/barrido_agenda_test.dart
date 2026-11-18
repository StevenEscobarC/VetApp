import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/core/theme/app_theme.dart';
import 'package:vetapp/core/widgets/buttons/app_button.dart';
import 'package:vetapp/features/appointments/presentation/widgets/cita_acciones.dart';
import 'package:vetapp/features/appointments/presentation/widgets/time_stepper.dart';

import 'helpers/fake_citas.dart';

const _dir = 'lib/features/appointments/presentation';
const _archivos = [
  '$_dir/screens/agenda_screen.dart',
  '$_dir/screens/cita_form_screen.dart',
  '$_dir/screens/recordatorios_screen.dart',
  '$_dir/widgets/cita_acciones.dart',
  '$_dir/widgets/notificaciones_banner.dart',
  '$_dir/widgets/permiso_notificaciones.dart',
  '$_dir/widgets/time_stepper.dart',
  '$_dir/widgets/day_strip.dart',
];

final _prohibido = RegExp(
  r'\b(TextButton|OutlinedButton)(\(|\.icon\(|\.styleFrom\()',
);

String _sinComentarios(String fuente) =>
    fuente.split('\n').where((l) => !l.trimLeft().startsWith('//')).join('\n');

void main() {
  group('fuente', () {
    for (final ruta in _archivos) {
      test('$ruta no usa botones Material crudos', () {
        final fuente = _sinComentarios(File(ruta).readAsStringSync());
        final hallazgos = _prohibido
            .allMatches(fuente)
            .map((m) => m.group(0))
            .toList();
        expect(hallazgos, isEmpty, reason: ruta);
      });
    }
  });

  group('diálogo de cancelar cita', () {
    Future<bool>? resultado;

    Future<void> abrir(WidgetTester tester) async {
      resultado = null;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: _Disparador(
                onTap: () =>
                    resultado = confirmarCancelacion(context, citaLunaHoy),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('abrir')));
      await tester.pumpAndSettle();
      expect(resultado, isNotNull);
    }

    testWidgets('Volver es AppButton y devuelve false', (tester) async {
      await abrir(tester);
      expect(find.widgetWithText(AppButton, 'Volver'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Volver'));
      await tester.pumpAndSettle();
      expect(await resultado!, isFalse);
    });

    testWidgets('Cancelar cita es AppButton destructivo y devuelve true', (
      tester,
    ) async {
      await abrir(tester);
      final boton = find.widgetWithText(AppButton, 'Cancelar cita');
      expect(boton, findsOneWidget);
      final w = tester.widget<AppButton>(boton);
      expect(w.variant, AppButtonVariant.destructive);
      expect(w.expand, isFalse);
      await tester.tap(boton);
      await tester.pumpAndSettle();
      expect(await resultado!, isTrue);
    });
  });

  group('TimeStepper', () {
    testWidgets('botones 64x64 AppButton; tap y long press llaman onPaso', (
      tester,
    ) async {
      final cambios = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: TimeStepper(minutos: 9 * 60, onCambio: cambios.add),
          ),
        ),
      );
      final sumar = find.descendant(
        of: find.byTooltip('Sumar 15 minutos'),
        matching: find.byType(AppButton),
      );
      expect(sumar, findsOneWidget);
      expect(tester.getSize(sumar), const Size(64, 64));
      await tester.tap(sumar);
      await tester.pump();
      expect(cambios, [9 * 60 + 15]);

      cambios.clear();
      final gesto = await tester.startGesture(tester.getCenter(sumar));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 400));
      await gesto.up();
      await tester.pump();
      expect(cambios.length, greaterThanOrEqualTo(2));
    });
  });
}

/// Disparador mínimo para abrir el diálogo desde un contexto con Navigator.
class _Disparador extends StatelessWidget {
  const _Disparador({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const Key('abrir'),
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: const SizedBox(width: 100, height: 100),
  );
}
