import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/core/theme/app_theme.dart';
import 'package:vetapp/features/vaccination/domain/entities/carne.dart';
import 'package:vetapp/features/vaccination/presentation/providers/alertas_providers.dart';
import 'package:vetapp/features/vaccination/presentation/widgets/vacunas_pendientes_card.dart';

const _cero = ResumenVacunas(vencidas: 0, proximas: 0, ocultasAntiguas: 0);
const _tresCinco = ResumenVacunas(vencidas: 3, proximas: 5, ocultasAntiguas: 0);

Widget _app(
  Future<ResumenVacunas> Function() resumen, {
  bool? mostrarSiVacia,
}) => ProviderScope(
  overrides: [resumenVacunasProvider.overrideWith((ref) => resumen())],
  child: MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Center(
        child: mostrarSiVacia == null
            ? const VacunasPendientesCard()
            : VacunasPendientesCard(mostrarSiVacia: mostrarSiVacia),
      ),
    ),
  ),
);

void main() {
  testWidgets('default shows Todo al día at 0/0', (tester) async {
    await tester.pumpWidget(_app(() async => _cero));
    await tester.pumpAndSettle();
    expect(find.text('Vacunas pendientes'), findsOneWidget);
    expect(find.text('Todo al día'), findsOneWidget);
  });

  testWidgets('mostrarSiVacia true behaves like the default', (tester) async {
    await tester.pumpWidget(_app(() async => _cero, mostrarSiVacia: true));
    await tester.pumpAndSettle();
    expect(find.text('Todo al día'), findsOneWidget);
  });

  testWidgets('mostrarSiVacia false renders nothing at 0/0', (tester) async {
    await tester.pumpWidget(_app(() async => _cero, mostrarSiVacia: false));
    await tester.pumpAndSettle();
    expect(find.text('Vacunas pendientes'), findsNothing);
    expect(find.text('Todo al día'), findsNothing);
    expect(tester.getSize(find.byType(VacunasPendientesCard)).height, 0);
  });

  testWidgets('mostrarSiVacia false still shows counts', (tester) async {
    await tester.pumpWidget(
      _app(() async => _tresCinco, mostrarSiVacia: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('Vacunas pendientes'), findsOneWidget);
    expect(find.text('3 vencidas'), findsOneWidget);
    expect(find.text('5 próximas'), findsOneWidget);
  });

  testWidgets('mostrarSiVacia false keeps the skeleton while loading', (
    tester,
  ) async {
    final pendiente = Completer<ResumenVacunas>();
    await tester.pumpWidget(
      _app(() => pendiente.future, mostrarSiVacia: false),
    );
    await tester.pump();
    expect(find.text('Vacunas pendientes'), findsOneWidget);
    expect(find.text('Todo al día'), findsNothing);
    expect(
      tester.getSize(find.byType(VacunasPendientesCard)).height,
      greaterThan(0),
    );
  });

  testWidgets('mostrarSiVacia false keeps the error and Reintentar', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(() async => throw Exception('x'), mostrarSiVacia: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('No pudimos cargar las vacunas.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
