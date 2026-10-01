import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/core/widgets/buttons/app_button.dart';
import 'package:vetapp/features/appointments/presentation/providers/citas_providers.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/clinical_history/domain/consulta_failure.dart';
import 'package:vetapp/features/clinical_history/presentation/providers/consultas_providers.dart';
import 'package:vetapp/features/clinical_history/presentation/screens/consulta_form_screen.dart';
import 'package:vetapp/features/patients/presentation/providers/mascotas_providers.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_citas.dart';
import 'helpers/fake_consultas.dart';
import 'helpers/fake_mascotas.dart';
import 'helpers/router_harness.dart';

/// Field order rendered by [ConsultaFormScreen]: Diagnóstico (0), Tratamiento
/// (1), then — only once "Agregar más detalles" is expanded — Anamnesis (2),
/// Peso (3), Temperatura (4), Frecuencia cardíaca (5), Frecuencia
/// respiratoria (6), Mucosas (7), Evolución (8).
const _campoDiagnostico = 0;
const _campoTratamiento = 1;
const _campoPeso = 3;
const _campoTemperatura = 4;
const _campoFrecuenciaCardiaca = 5;

Widget _appUnderTest({
  required FakeConsultaRepository repo,
  FakeMascotaRepository? mascotaRepo,
  String initialLocation = '/pacientes/m-1/consultas/nueva',
  FakeCitaRepository? citaRepo,
  String? citaId,
}) {
  return routerHarness(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/pacientes/:id',
        builder: (_, state) => Text('FICHA ${state.pathParameters['id']}'),
        routes: [
          GoRoute(
            path: 'consultas/nueva',
            builder: (_, state) =>
                ConsultaFormScreen(
                  mascotaId: state.pathParameters['id']!,
                  citaId: citaId,
                ),
          ),
        ],
      ),
    ],
    overrides: [
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: vetProfile),
      ),
      consultaRepositoryProvider.overrideWithValue(repo),
      if (citaRepo != null) citaRepositoryProvider.overrideWithValue(citaRepo),
      mascotaRepositoryProvider.overrideWithValue(
        mascotaRepo ?? FakeMascotaRepository(mascotas: [mascotaRocky]),
      ),
    ],
  );
}

Future<void> _expandirDetalles(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Agregar más detalles'));
  await tester.tap(find.text('Agregar más detalles'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    "'Guardar consulta' permanece deshabilitado hasta llenar Diagnóstico y "
    'Tratamiento; los campos opcionales están ocultos hasta expandir',
    (tester) async {
      final repo = FakeConsultaRepository();
      await tester.pumpWidget(_appUnderTest(repo: repo));
      await tester.pumpAndSettle();

      AppButton boton() => tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Guardar consulta'),
      );

      expect(boton().onPressed, isNull);

      await tester.enterText(
        find.byType(TextFormField).at(_campoDiagnostico),
        'Otitis',
      );
      await tester.pump();
      expect(boton().onPressed, isNull, reason: 'aún falta tratamiento');

      await tester.enterText(
        find.byType(TextFormField).at(_campoTratamiento),
        'Gotas',
      );
      await tester.pump();
      expect(boton().onPressed, isNotNull);

      for (final label in [
        'Anamnesis',
        'Peso (kg)',
        'Temperatura (°C)',
        'Frecuencia cardíaca (lpm)',
        'Frecuencia respiratoria (rpm)',
        'Mucosas',
        'Evolución',
      ]) {
        expect(find.text(label), findsNothing);
      }
    },
  );

  testWidgets(
    'guardar con solo los campos requeridos crea un registro con todo lo '
    'opcional en null, muestra el snackbar y regresa a la ficha',
    (tester) async {
      final repo = FakeConsultaRepository();
      await tester.pumpWidget(_appUnderTest(repo: repo));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(_campoDiagnostico),
        'Otitis',
      );
      await tester.enterText(
        find.byType(TextFormField).at(_campoTratamiento),
        'Gotas',
      );
      await tester.pump();

      await tester.ensureVisible(find.text('Guardar consulta'));
      await tester.tap(find.text('Guardar consulta'));
      await tester.pump();
      await tester.pump();

      expect(repo.registros, hasLength(1));
      final registro = repo.registros.single;
      expect(registro.diagnostico, 'Otitis');
      expect(registro.tratamiento, 'Gotas');
      expect(registro.anamnesis, isNull);
      expect(registro.pesoKg, isNull);

      expect(find.text('FICHA m-1'), findsOneWidget);
      expect(find.text('Consulta guardada'), findsOneWidget);

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'con Peso, Temperatura y Frecuencia cardíaca en detalles expandidos se '
    'registra un único registro con esos valores y pesosRegistrados queda '
    'vacío (D-02)',
    (tester) async {
      final mascotaRepo = FakeMascotaRepository(mascotas: [mascotaRocky]);
      final repo = FakeConsultaRepository(mascotas: mascotaRepo);
      await tester.pumpWidget(
        _appUnderTest(repo: repo, mascotaRepo: mascotaRepo),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(_campoDiagnostico),
        'Otitis',
      );
      await tester.enterText(
        find.byType(TextFormField).at(_campoTratamiento),
        'Gotas',
      );

      await _expandirDetalles(tester);

      await tester.enterText(
        find.byType(TextFormField).at(_campoPeso),
        '4,2',
      );
      await tester.enterText(
        find.byType(TextFormField).at(_campoTemperatura),
        '38,5',
      );
      await tester.enterText(
        find.byType(TextFormField).at(_campoFrecuenciaCardiaca),
        '90',
      );
      await tester.pump();

      await tester.ensureVisible(find.text('Guardar consulta'));
      await tester.tap(find.text('Guardar consulta'));
      await tester.pumpAndSettle();

      expect(repo.registros, hasLength(1));
      final registro = repo.registros.single;
      expect(registro.pesoKg, 4.2);
      expect(registro.temperaturaC, 38.5);
      expect(registro.frecuenciaCardiaca, 90);
      expect(mascotaRepo.pesosRegistrados, isEmpty);
    },
  );

  testWidgets(
    'un valor numérico inválido en temperatura, frecuencia cardíaca o peso '
    'muestra el error y no llama al repositorio',
    (tester) async {
      final repo = FakeConsultaRepository();
      await tester.pumpWidget(_appUnderTest(repo: repo));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(_campoDiagnostico),
        'Otitis',
      );
      await tester.enterText(
        find.byType(TextFormField).at(_campoTratamiento),
        'Gotas',
      );

      await _expandirDetalles(tester);

      await tester.enterText(
        find.byType(TextFormField).at(_campoTemperatura),
        'abc',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Guardar consulta'));
      await tester.tap(find.text('Guardar consulta'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa un valor numérico válido'), findsOneWidget);
      expect(repo.registros, isEmpty);

      await tester.enterText(
        find.byType(TextFormField).at(_campoTemperatura),
        '',
      );
      await tester.enterText(
        find.byType(TextFormField).at(_campoFrecuenciaCardiaca),
        '90,5',
      );
      await tester.pump();
      await tester.tap(find.text('Guardar consulta'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa un valor numérico válido'), findsWidgets);
      expect(repo.registros, isEmpty);

      await tester.enterText(
        find.byType(TextFormField).at(_campoFrecuenciaCardiaca),
        '',
      );
      await tester.enterText(find.byType(TextFormField).at(_campoPeso), '0');
      await tester.pump();
      await tester.tap(find.text('Guardar consulta'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa un valor numérico válido'), findsOneWidget);
      expect(repo.registros, isEmpty);
    },
  );

  testWidgets(
    'un fake que lanza ConsultaFailure mantiene el formulario abierto y '
    'muestra el mensaje',
    (tester) async {
      const falla = ConsultaFailure(
        'No pudimos guardar la consulta. Intenta de nuevo.',
      );
      final repo = FakeConsultaRepository(error: falla);
      await tester.pumpWidget(_appUnderTest(repo: repo));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(_campoDiagnostico),
        'Otitis',
      );
      await tester.enterText(
        find.byType(TextFormField).at(_campoTratamiento),
        'Gotas',
      );
      await tester.pump();

      await tester.ensureVisible(find.text('Guardar consulta'));
      await tester.tap(find.text('Guardar consulta'));
      await tester.pumpAndSettle();

      expect(
        find.text('No pudimos guardar la consulta. Intenta de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('Nueva consulta'), findsOneWidget);
    },
  );
  testWidgets(
    'con citaId: pill de la cita, anamnesis precargada editable y citaId '
    'enviado al guardar',
    (tester) async {
      final repo = FakeConsultaRepository();
      await tester.pumpWidget(
        _appUnderTest(
          repo: repo,
          citaRepo: FakeCitaRepository(citas: [citaLunaHoy]),
          citaId: citaLunaHoy.id,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cita del mié 30/09 · 10:30 a. m.'), findsOneWidget);
      // Detalles expandidos: Anamnesis es el campo 2.
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(2))
            .controller!
            .text,
        'Consulta general.',
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'Consulta general. Editada',
      );
      await tester.enterText(
        find.byType(TextFormField).at(_campoDiagnostico),
        'Dx',
      );
      await tester.enterText(
        find.byType(TextFormField).at(_campoTratamiento),
        'Tx',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Guardar consulta'));
      await tester.tap(find.text('Guardar consulta'));
      await tester.pump();
      await tester.pump();

      final registro = repo.registros.single;
      expect(registro.citaId, 'cita-1');
      expect(registro.anamnesis, 'Consulta general. Editada');
    },
  );

  testWidgets('con citaId y notas: anamnesis "{motivo}. {notas}"', (
    tester,
  ) async {
    final cita = citaRockyLunaHoy.copyWith(notas: 'Traer carné');
    await tester.pumpWidget(
      _appUnderTest(
        repo: FakeConsultaRepository(),
        citaRepo: FakeCitaRepository(citas: [cita]),
        citaId: cita.id,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(2))
          .controller!
          .text,
      'Vacunación. Traer carné',
    );
  });
}
