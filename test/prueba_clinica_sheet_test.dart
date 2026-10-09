import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetapp/core/errors/limite_plan.dart';
import 'package:vetapp/core/theme/app_theme.dart';
import 'package:vetapp/features/plan/presentation/widgets/prueba_clinica_sheet.dart';
import 'package:vetapp/features/team/data/repositories/supabase_team_repository.dart';
import 'package:vetapp/features/team/domain/team_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _prohibidas = RegExp(
  r'precio|pagar|\bpago\b|factura|\$',
  caseSensitive: false,
);

/// Abre la hoja desde un botón y deja el resultado en [resultado].
class _Resultado {
  bool? valor;
  bool cerrado = false;
}

Widget _app({
  required Future<void> Function() activar,
  required _Resultado resultado,
  int miembros = 5,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async {
              resultado.valor = await mostrarPruebaClinicaSheet(
                context,
                miembros: miembros,
                activar: activar,
              );
              resultado.cerrado = true;
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _abrir(WidgetTester tester) async {
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the full offer copy without money wording', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(activar: () async {}, resultado: _Resultado()),
    );
    await _abrir(tester);
    expect(find.text('Plan Clínica 30 días gratis, sin tarjeta'), findsOneWidget);
    expect(
      find.text(
        'Invita a tus colegas y trabajen juntos con pacientes, agenda y '
        'carnés compartidos.',
      ),
      findsOneWidget,
    );
    expect(find.text('Hasta 5 veterinarios durante la prueba'), findsOneWidget);
    expect(find.text('Logo y protocolos propios'), findsOneWidget);
    expect(find.text('Sin tarjeta y sin cobro automático'), findsOneWidget);
    expect(
      find.text(
        'Si después no sigues con el plan Clínica, tus colegas pasan a solo '
        'lectura tras 15 días de gracia. No pierdes ningún dato.',
      ),
      findsOneWidget,
    );
    expect(find.text('Activar y generar código'), findsOneWidget);
    expect(find.text('Ahora no'), findsOneWidget);
    // "Sin tarjeta y sin cobro automático" es la excepción permitida; el
    // resto del texto visible no menciona dinero.
    final textos = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((s) => s.isNotEmpty && s != 'abrir');
    for (final s in textos) {
      expect(_prohibidas.hasMatch(s), isFalse, reason: s);
    }
  });

  testWidgets('seat count comes from the miembros argument', (tester) async {
    await tester.pumpWidget(
      _app(activar: () async {}, resultado: _Resultado(), miembros: 3),
    );
    await _abrir(tester);
    expect(find.text('Hasta 3 veterinarios durante la prueba'), findsOneWidget);
  });

  testWidgets('Activar calls activar once and returns true', (tester) async {
    var llamadas = 0;
    final r = _Resultado();
    await tester.pumpWidget(_app(activar: () async => llamadas++, resultado: r));
    await _abrir(tester);
    await tester.tap(find.text('Activar y generar código'));
    await tester.pumpAndSettle();
    expect(llamadas, 1);
    expect(r.cerrado, isTrue);
    expect(r.valor, isTrue);
    expect(find.text('Activar y generar código'), findsNothing);
  });

  testWidgets('Ahora no returns null without calling activar', (tester) async {
    var llamadas = 0;
    final r = _Resultado();
    await tester.pumpWidget(_app(activar: () async => llamadas++, resultado: r));
    await _abrir(tester);
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(llamadas, 0);
    expect(r.cerrado, isTrue);
    expect(r.valor, isNull);
  });

  testWidgets('while activating the button loads and Ahora no is disabled', (
    tester,
  ) async {
    final completer = Completer<void>();
    final r = _Resultado();
    await tester.pumpWidget(_app(activar: () => completer.future, resultado: r));
    await _abrir(tester);
    await tester.tap(find.text('Activar y generar código'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final ahoraNo = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Ahora no'),
    );
    expect(ahoraNo.onPressed, isNull);
    completer.complete();
    await tester.pumpAndSettle();
    expect(r.valor, isTrue);
  });

  testWidgets('a members-limit failure closes the sheet returning false', (
    tester,
  ) async {
    final r = _Resultado();
    await tester.pumpWidget(
      _app(
        activar: () async =>
            throw const TeamFailure('x', limite: LimitePlan.miembros),
        resultado: r,
      ),
    );
    await _abrir(tester);
    await tester.tap(find.text('Activar y generar código'));
    await tester.pumpAndSettle();
    expect(r.cerrado, isTrue);
    expect(r.valor, isFalse);
  });

  testWidgets('any other failure keeps the sheet open with a snackbar', (
    tester,
  ) async {
    final r = _Resultado();
    await tester.pumpWidget(
      _app(activar: () async => throw const TeamFailure('x'), resultado: r),
    );
    await _abrir(tester);
    await tester.tap(find.text('Activar y generar código'));
    await tester.pumpAndSettle();
    expect(r.cerrado, isFalse);
    expect(
      find.text('No pudimos activar la prueba. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(find.text('Activar y generar código'), findsOneWidget);
    final ahoraNo = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Ahora no'),
    );
    expect(ahoraNo.onPressed, isNotNull);
  });

  group('mensajeLimiteEquipo', () {
    const lp002 = PostgrestException(message: 'cupo', code: 'LP002');

    test('generar maps LP002 to the admin message', () {
      expect(
        SupabaseTeamRepository.mensajeLimiteEquipo(lp002, unirse: false),
        'Tu plan no tiene cupo para más veterinarios.',
      );
    });

    test('unirse maps LP002 to the joining vet message', () {
      expect(
        SupabaseTeamRepository.mensajeLimiteEquipo(lp002, unirse: true),
        'La clínica a la que intentas unirte no tiene cupo para más '
        'veterinarios. Pídele al administrador que active un plan con más '
        'cupos.',
      );
    });

    test('LP002 arriving only in the hint is also mapped', () {
      const e = PostgrestException(
        message: 'x',
        code: 'P0001',
        hint: 'LP002',
      );
      expect(SupabaseTeamRepository.mensajeLimiteEquipo(e, unirse: false),
          'Tu plan no tiene cupo para más veterinarios.');
    });

    test('other errors return null so the substring rules apply', () {
      const e = PostgrestException(message: 'Ese código ya venció');
      expect(
        SupabaseTeamRepository.mensajeLimiteEquipo(e, unirse: false),
        isNull,
      );
    });
  });

  test('TeamFailure carries the limit and is a ConLimitePlan', () {
    const f = TeamFailure('x', limite: LimitePlan.miembros);
    expect(limiteDe(f), LimitePlan.miembros);
    expect(limiteDe(const TeamFailure('x')), isNull);
  });
}
