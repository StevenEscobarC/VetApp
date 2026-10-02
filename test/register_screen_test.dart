import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vetapp/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:vetapp/features/auth/domain/auth_failure.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/auth/presentation/screens/register_screen.dart';

class _FakeAuthRepo implements SupabaseAuthRepository {
  _FakeAuthRepo({this.failure});

  final AuthFailure? failure;
  final calls = <Map<String, Object?>>[];

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String nombre,
    required String telefono,
    required String rol,
    String? clinicaNombre,
    String? ciudad,
    String? direccion,
    String? clinicaTelefono,
    String? codigoInvitacion,
  }) async {
    calls.add({
      'rol': rol,
      'clinicaNombre': clinicaNombre,
      'codigoInvitacion': codigoInvitacion,
    });
    if (failure != null) throw failure!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(WidgetTester tester, _FakeAuthRepo repo) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, _) => const RegisterScreen()),
          ],
        ),
      ),
    ),
  );
}

Future<void> _elegirVet(WidgetTester tester) async {
  await tester.tap(find.text('Veterinario'));
  await tester.pump();
}

Future<void> _llenarBasicos(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'Ana');
  await tester.enterText(fields.at(1), 'ana@vetapp.co');
  await tester.enterText(fields.at(3), 'password123');
}

void main() {
  testWidgets('Cliente no ve segmentos ni campo de código', (tester) async {
    await _pump(tester, _FakeAuthRepo());
    expect(find.text('Crear mi clínica'), findsNothing);
    expect(find.text('Tengo un código'), findsNothing);
  });

  testWidgets('Veterinario ve ambos segmentos y el nombre de clínica', (
    tester,
  ) async {
    await _pump(tester, _FakeAuthRepo());
    await _elegirVet(tester);
    expect(find.text('Crear mi clínica'), findsOneWidget);
    expect(find.text('Tengo un código'), findsOneWidget);
    expect(find.text('Nombre de la clínica'), findsOneWidget);
    expect(find.text('Código de invitación'), findsNothing);
  });

  testWidgets('Crear mi clínica no envía código', (tester) async {
    final repo = _FakeAuthRepo();
    await _pump(tester, repo);
    await _elegirVet(tester);
    await _llenarBasicos(tester);
    await tester.enterText(find.byType(TextFormField).at(4), 'Patitas');
    await tester.tap(find.text('Crear cuenta').last);
    await tester.pump();
    expect(repo.calls.single['codigoInvitacion'], isNull);
    expect(repo.calls.single['clinicaNombre'], 'Patitas');
  });

  testWidgets('Tengo un código muestra campo, oculta clínica y formatea', (
    tester,
  ) async {
    await _pump(tester, _FakeAuthRepo());
    await _elegirVet(tester);
    await tester.tap(find.text('Tengo un código'));
    await tester.pump();
    expect(find.text('Nombre de la clínica'), findsNothing);
    expect(find.text('Código de invitación'), findsOneWidget);
    expect(find.text('K7MQ-4P2X'), findsWidgets); // hint
    expect(
      find.text('Te lo envió el administrador de tu clínica.'),
      findsOneWidget,
    );
    final codigo = find.byType(TextFormField).at(4);
    await tester.enterText(codigo, 'k7mq4p2x');
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).at(4))
          .controller
          .text,
      'K7MQ-4P2X',
    );
    await tester.enterText(codigo, 'o0ab');
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).at(4))
          .controller
          .text,
      'AB',
    );
  });

  testWidgets('Código incompleto muestra error y no llama signUp', (
    tester,
  ) async {
    final repo = _FakeAuthRepo();
    await _pump(tester, repo);
    await _elegirVet(tester);
    await tester.tap(find.text('Tengo un código'));
    await tester.pump();
    await _llenarBasicos(tester);
    await tester.enterText(find.byType(TextFormField).at(4), 'K7MQ');
    await tester.tap(find.text('Crear cuenta').last);
    await tester.pump();
    expect(
      find.text('Ese código no es válido. Revísalo e inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(repo.calls, isEmpty);
  });

  testWidgets('Código válido se envía y AuthFailure va bajo el campo', (
    tester,
  ) async {
    final repo = _FakeAuthRepo(failure: const AuthFailure('Código vencido'));
    await _pump(tester, repo);
    await _elegirVet(tester);
    await tester.tap(find.text('Tengo un código'));
    await tester.pump();
    await _llenarBasicos(tester);
    await tester.enterText(find.byType(TextFormField).at(4), 'K7MQ4P2X');
    await tester.tap(find.text('Crear cuenta').last);
    await tester.pumpAndSettle();
    expect(repo.calls.single['codigoInvitacion'], 'K7MQ-4P2X');
    expect(repo.calls.single['clinicaNombre'], isNull);
    expect(find.text('Código vencido'), findsOneWidget);
  });

  testWidgets('Volver a Crear mi clínica limpia el código', (tester) async {
    await _pump(tester, _FakeAuthRepo());
    await _elegirVet(tester);
    await tester.tap(find.text('Tengo un código'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).at(4), 'K7MQ');
    await tester.tap(find.text('Crear mi clínica'));
    await tester.pump();
    await tester.tap(find.text('Tengo un código'));
    await tester.pump();
    final field = tester.widget<TextFormField>(
      find.byType(TextFormField).at(4),
    );
    expect(field.controller!.text, isEmpty);
  });
}
