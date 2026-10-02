import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/core/widgets/status/dosis_estado_chip.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('vencida muestra texto e icono', (tester) async {
    await tester.pumpWidget(
      _wrap(const DosisEstadoChip(estado: DosisEstado.vencida)),
    );
    expect(find.text('Vencida'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('externa muestra Otra clínica', (tester) async {
    await tester.pumpWidget(
      _wrap(const DosisEstadoChip(estado: DosisEstado.externa, compact: true)),
    );
    expect(find.text('Otra clínica'), findsOneWidget);
    expect(find.byIcon(Icons.apartment_outlined), findsOneWidget);
  });

  testWidgets('etiquetas de los demás estados', (tester) async {
    for (final (e, t) in [
      (DosisEstado.alDia, 'Al día'),
      (DosisEstado.proxima, 'Próxima'),
      (DosisEstado.anulada, 'Anulada'),
    ]) {
      await tester.pumpWidget(_wrap(DosisEstadoChip(estado: e)));
      expect(find.text(t), findsOneWidget);
    }
  });
}
