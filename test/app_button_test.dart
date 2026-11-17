import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetapp/core/theme/app_theme.dart';
import 'package:vetapp/core/widgets/buttons/app_button.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('AppButton modo cuadrado (08-02)', () {
    testWidgets('renders a 48x48 OutlinedButton with icon and semantics only', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          AppButton(
            label: 'Sumar',
            icon: Icons.add,
            variant: AppButtonVariant.outline,
            cuadrado: true,
            onPressed: () {},
          ),
        ),
      );
      expect(tester.getSize(find.byType(OutlinedButton)), const Size(48, 48));
      expect(
        find.descendant(
          of: find.byType(OutlinedButton),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.bySemanticsLabel('Sumar'), findsWidgets);
      semantics.dispose();
    });

    testWidgets('lado sets the square side', (tester) async {
      await tester.pumpWidget(
        _host(
          AppButton(
            label: 'Sumar',
            icon: Icons.add,
            variant: AppButtonVariant.outline,
            cuadrado: true,
            lado: 64,
            onPressed: () {},
          ),
        ),
      );
      expect(tester.getSize(find.byType(OutlinedButton)), const Size(64, 64));
    });

    testWidgets('contenido replaces the default icon child', (tester) async {
      await tester.pumpWidget(
        _host(
          AppButton(
            label: 'Sumar diez',
            icon: Icons.add,
            variant: AppButtonVariant.outline,
            cuadrado: true,
            contenido: const Text('+10'),
            onPressed: () {},
          ),
        ),
      );
      expect(find.text('+10'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('botonKey finds the inner OutlinedButton', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          AppButton(
            label: 'Sumar',
            icon: Icons.add,
            variant: AppButtonVariant.outline,
            cuadrado: true,
            botonKey: const Key('sumar'),
            onPressed: () => taps++,
          ),
        ),
      );
      final boton = tester.widget<OutlinedButton>(
        find.byKey(const Key('sumar')),
      );
      expect(boton.onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('sumar')));
      expect(taps, 1);
    });

    testWidgets('isLoading shows the 20px spinner and disables the button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          AppButton(
            label: 'Sumar',
            icon: Icons.add,
            variant: AppButtonVariant.outline,
            cuadrado: true,
            isLoading: true,
            onPressed: () {},
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.getSize(find.byType(CircularProgressIndicator)),
        const Size(20, 20),
      );
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
    });
  });

  group('AppButton modo normal sin cambios', () {
    testWidgets('primary expands and shows the label', (tester) async {
      await tester.pumpWidget(
        _host(AppButton(label: 'Guardar', onPressed: () {})),
      );
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);
      expect(tester.getSize(find.byType(ElevatedButton)).width, 800);
    });

    testWidgets('outline with icon shows icon and label', (tester) async {
      await tester.pumpWidget(
        _host(
          AppButton(
            label: 'Agregar',
            icon: Icons.add,
            variant: AppButtonVariant.outline,
            expand: false,
            onPressed: () {},
          ),
        ),
      );
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.text('Agregar'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('text and destructive render TextButton', (tester) async {
      await tester.pumpWidget(
        _host(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(
                label: 'Cancelar',
                variant: AppButtonVariant.text,
                expand: false,
                onPressed: () {},
              ),
              AppButton(
                label: 'Eliminar',
                variant: AppButtonVariant.destructive,
                expand: false,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      expect(find.byType(TextButton), findsNWidgets(2));
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);
    });
  });
}
