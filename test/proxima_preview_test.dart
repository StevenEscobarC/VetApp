import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetapp/core/theme/app_theme.dart';
import 'package:vetapp/features/vaccination/domain/entities/carne.dart';
import 'package:vetapp/features/vaccination/presentation/widgets/proxima_preview.dart';

PrevisualizacionDosis _p({DateTime? proxima, String etiquetaProxima = ''}) =>
    PrevisualizacionDosis(
      posicion: 1,
      dosisSerie: 3,
      etiquetaDosis: 'Dosis 1 de 3',
      proximaFecha: proxima,
      etiquetaProxima: etiquetaProxima,
      sugerirReiniciar: false,
    );

Future<void> _pump(WidgetTester tester, PrevisualizacionDosis p) =>
    tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ProximaPreview(
            preview: AsyncData(p),
            hoy: DateTime.utc(2026, 10, 2),
            iniciaSerie: false,
            onReiniciar: (_) {},
          ),
        ),
      ),
    );

void main() {
  testWidgets('contexto = etiqueta de la próxima dosis + días relativos', (
    tester,
  ) async {
    await _pump(
      tester,
      _p(proxima: DateTime.utc(2026, 10, 23), etiquetaProxima: 'Dosis 2 de 3'),
    );
    expect(find.text('Próxima: 23/10/2026'), findsOneWidget);
    expect(find.text('Dosis 2 de 3 · en 21 días'), findsOneWidget);
    expect(find.textContaining('Dosis 1 de 3'), findsNothing);
  });

  testWidgets('singular, hoy y fecha ya pasada (dosis histórica)', (
    tester,
  ) async {
    await _pump(
      tester,
      _p(proxima: DateTime.utc(2026, 10, 3), etiquetaProxima: 'Refuerzo'),
    );
    expect(find.text('Refuerzo · en 1 día'), findsOneWidget);

    await _pump(
      tester,
      _p(proxima: DateTime.utc(2026, 10, 2), etiquetaProxima: 'Refuerzo'),
    );
    expect(find.text('Refuerzo · hoy'), findsOneWidget);

    await _pump(
      tester,
      _p(proxima: DateTime.utc(2026, 9, 14), etiquetaProxima: 'Refuerzo'),
    );
    expect(find.text('Refuerzo · hace 18 días'), findsOneWidget);
  });

  testWidgets('sin refuerzo no muestra línea de contexto', (tester) async {
    await _pump(tester, _p(etiquetaProxima: 'Refuerzo'));
    expect(find.text('Sin refuerzo'), findsOneWidget);
    expect(find.textContaining('·'), findsNothing);
  });
}
