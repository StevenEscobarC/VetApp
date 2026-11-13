import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/core/theme/app_theme.dart';
import 'package:vetapp/core/widgets/inputs/app_text_field.dart';

Widget _envolver(Widget hijo) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: hijo));

void main() {
  testWidgets('defaults sin cambios para pantallas existentes', (tester) async {
    await tester.pumpWidget(_envolver(const AppTextField(label: 'Nombre')));
    final campo = tester.widget<TextField>(find.byType(TextField));
    expect(campo.textAlign, TextAlign.start);
    expect(campo.enabled, isTrue);
    expect(campo.textInputAction, isNull);
    expect(campo.decoration!.prefixText, isNull);
  });

  testWidgets('reenvía los parámetros nuevos', (tester) async {
    final foco = FocusNode();
    addTearDown(foco.dispose);
    String? enviado;
    await tester.pumpWidget(
      _envolver(
        AppTextField(
          label: 'Cantidad',
          textInputAction: TextInputAction.done,
          textAlign: TextAlign.center,
          prefixText: r'$ ',
          focusNode: foco,
          onFieldSubmitted: (v) => enviado = v,
        ),
      ),
    );
    final campo = tester.widget<TextField>(find.byType(TextField));
    expect(campo.textInputAction, TextInputAction.done);
    expect(campo.textAlign, TextAlign.center);
    expect(campo.decoration!.prefixText, r'$ ');
    expect(campo.focusNode, foco);

    await tester.enterText(find.byType(TextField), '5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(enviado, '5');
  });

  testWidgets('enabled false se propaga', (tester) async {
    await tester.pumpWidget(
      _envolver(const AppTextField(label: 'X', enabled: false)),
    );
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  });
}
