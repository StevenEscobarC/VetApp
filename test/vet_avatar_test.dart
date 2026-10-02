import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/core/theme/app_colors.dart';
import 'package:vetapp/core/widgets/inputs/app_text_field.dart';
import 'package:vetapp/core/widgets/status/vet_avatar.dart';

Color? _fill(WidgetTester tester) {
  final box = tester.widget<Container>(
    find.descendant(
      of: find.byType(VetAvatar),
      matching: find.byType(Container),
    ),
  );
  return (box.decoration as BoxDecoration).color;
}

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(home: Scaffold(body: Center(child: child))),
);

void main() {
  test('inicialesDe', () {
    expect(inicialesDe('Laura Gómez'), 'LG');
    expect(inicialesDe('ana'), 'A');
    expect(inicialesDe('  '), '?');
  });

  testWidgets('palette by index mod 4', (tester) async {
    await _pump(tester, const VetAvatar(nombre: 'Laura Gómez', indice: 1));
    expect(_fill(tester), const Color(0xFF3F5A73));
    await _pump(tester, const VetAvatar(nombre: 'Laura Gómez', indice: 0));
    expect(_fill(tester), AppColors.success);
    await _pump(tester, const VetAvatar(nombre: 'Laura Gómez', indice: 3));
    expect(_fill(tester), AppColors.primaryStrong);
    await _pump(tester, const VetAvatar(nombre: 'Laura Gómez', indice: 5));
    expect(_fill(tester), const Color(0xFF3F5A73));
  });

  testWidgets('semantics label and initials', (tester) async {
    await _pump(tester, const VetAvatar(nombre: 'Laura Gómez'));
    expect(find.bySemanticsLabel('Dr(a). Laura Gómez'), findsOneWidget);
    expect(find.text('LG'), findsOneWidget);
  });

  testWidgets('retirado is outlined with tooltip', (tester) async {
    await _pump(
      tester,
      const VetAvatar(nombre: 'Laura Gómez', retirado: true),
    );
    expect(_fill(tester), Colors.transparent);
    expect(find.byTooltip('Veterinario retirado'), findsOneWidget);
  });

  testWidgets('AppTextField prefixIcon and maxLength', (tester) async {
    final c = TextEditingController();
    await _pump(
      tester,
      AppTextField(
        label: 'Matrícula',
        controller: c,
        prefixIcon: Icons.badge_outlined,
        maxLength: 20,
      ),
    );
    expect(find.byIcon(Icons.badge_outlined), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'a' * 30);
    expect(c.text.length, 20);
  });
}
