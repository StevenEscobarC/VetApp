import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vetapp/core/errors/limite_plan.dart';
import 'package:vetapp/core/widgets/buttons/app_button.dart';
import 'package:vetapp/features/appointments/domain/entities/cita.dart';
import 'package:vetapp/features/appointments/presentation/providers/citas_providers.dart';
import 'package:vetapp/features/auth/presentation/providers/auth_providers.dart';
import 'package:vetapp/features/billing/presentation/providers/cobros_providers.dart';
import 'package:vetapp/features/clinical_history/domain/consulta_failure.dart';
import 'package:vetapp/features/clinical_history/presentation/providers/consultas_providers.dart';
import 'package:vetapp/features/clinical_history/presentation/screens/consulta_form_screen.dart';
import 'package:vetapp/features/patients/presentation/providers/mascotas_providers.dart';
import 'package:vetapp/features/plan/domain/mi_plan.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_citas.dart';
import 'helpers/fake_cobros.dart';
import 'helpers/fake_consultas.dart';
import 'helpers/fake_mascotas.dart';
import 'helpers/fake_plan.dart';
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
      GoRoute(
        path: '/cobros/nuevo',
        builder: (_, state) => Text('NUEVO ${state.uri.query}'),
      ),
    ],
    overrides: [
      ...planOverrides(),
      authProfileProvider.overrideWith(
        () => FakeAuthProfileNotifier(profile: vetProfile),
      ),
      consultaRepositoryProvider.overrideWithValue(repo),
      if (citaRepo != null) citaRepositoryProvider.overrideWithValue(citaRepo),
      mascotaRepositoryProvider.overrideWithValue(
        mascotaRepo ?? FakeMascotaRepository(mascotas: [mascotaRocky]),
      ),
      cobrosRepositoryProvider.overrideWithValue(FakeCobrosRepository()),
    ],
  );
}

/// La cita llega solo cuando el test completa [llegada] (red lenta).
class _CitaLenta extends FakeCitaRepository {
  _CitaLenta({super.citas});

  final llegada = Completer<void>();

  @override
  Future<Cita> obtener(String id) async {
    await llegada.future;
    return super.obtener(id);
  }
}

Future<void> _expandirDetalles(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Agregar más detalles'));
  await tester.tap(find.text('Agregar más detalles'));
  await tester.pumpAndSettle();
}

/// Formulario en un plan dado (solo lectura para los casos de cobro).
Widget _appConPlan({required FakeConsultaRepository repo, MiPlan? plan}) =>
    routerHarness(
      initialLocation: '/pacientes/m-1/consultas/nueva',
      routes: [
        GoRoute(
          path: '/pacientes/:id',
          builder: (_, state) => Text('FICHA ${state.pathParameters['id']}'),
          routes: [
            GoRoute(
              path: 'consultas/nueva',
              builder: (_, state) =>
                  ConsultaFormScreen(mascotaId: state.pathParameters['id']!),
            ),
          ],
        ),
      ],
      overrides: [
        ...planOverrides(plan: plan),
        authProfileProvider.overrideWith(
          () => FakeAuthProfileNotifier(profile: vetProfile),
        ),
        consultaRepositoryProvider.overrideWithValue(repo),
        mascotaRepositoryProvider.overrideWithValue(
          FakeMascotaRepository(mascotas: [mascotaRocky]),
        ),
        cobrosRepositoryProvider.overrideWithValue(FakeCobrosRepository()),
      ],
    );

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
    'LP004 del servidor (bandera vencida) abre la hoja de solo lectura, '
    'conserva lo escrito y no muestra el mensaje crudo',
    (tester) async {
      const falla = ConsultaFailure(
        'Tu cuenta está en solo lectura. Pide al administrador que active '
        'el plan.',
        limite: LimitePlan.soloLectura,
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

      expect(find.text('Tu cuenta está en solo lectura'), findsOneWidget);
      expect(find.textContaining('Pide al administrador'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(_campoDiagnostico))
            .controller!
            .text,
        'Otitis',
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(_campoTratamiento))
            .controller!
            .text,
        'Gotas',
      );
      // El botón vuelve a quedar disponible (el guardado terminó).
      expect(
        tester
            .widget<AppButton>(find.widgetWithText(AppButton, 'Guardar consulta'))
            .isLoading,
        isFalse,
      );
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

  testWidgets('la precarga no pisa la anamnesis escrita antes de que llegue '
      'la cita', (tester) async {
    final citaRepo = _CitaLenta(citas: [citaLunaHoy]);
    await tester.pumpWidget(
      _appUnderTest(
        repo: FakeConsultaRepository(),
        citaRepo: citaRepo,
        citaId: citaLunaHoy.id,
      ),
    );
    await tester.pump();
    await _expandirDetalles(tester);
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'Vómito desde ayer',
    );
    await tester.pump();

    citaRepo.llegada.complete();
    await tester.pumpAndSettle();

    expect(find.text('Cita del mié 30/09 · 10:30 a. m.'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(2))
          .controller!
          .text,
      'Vómito desde ayer',
    );
  });

  group('Cobrar desde el snackbar (D-05)', () {
    Future<void> guardar(WidgetTester tester) async {
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
    }

    testWidgets(
      '"Consulta guardada" ofrece "Cobrar" por 6 s; abre el formulario con '
      'el dueño, la mascota y la consulta nueva',
      (tester) async {
        final repo = FakeConsultaRepository(idResultado: 'con-77');
        await tester.pumpWidget(_appUnderTest(repo: repo));
        await tester.pumpAndSettle();
        await guardar(tester);

        expect(find.text('FICHA m-1'), findsOneWidget);
        final snack = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snack.duration, const Duration(seconds: 6));
        expect(snack.action?.label, 'Cobrar');

        // La ficha de este harness es un Text sin Scaffold: el snackbar no
        // sigue visible tras el pop, así que se dispara la acción capturada.
        snack.action!.onPressed();
        await tester.pumpAndSettle();
        final destino = tester
            .widget<Text>(find.textContaining('NUEVO '))
            .data!;
        final query = Uri.splitQueryString(destino.substring(6));
        expect(query['tipo'], 'cc');
        expect(query['clienteId'], 'c-1');
        expect(query['mascotaId'], 'm-1');
        expect(query['consultaId'], 'con-77');
      },
    );

    testWidgets('solo lectura: el snackbar no ofrece "Cobrar"', (
      tester,
    ) async {
      final repo = FakeConsultaRepository();
      await tester.pumpWidget(
        _appConPlan(repo: repo, plan: planSoloLectura),
      );
      await tester.pumpAndSettle();
      await guardar(tester);

      expect(find.text('Consulta guardada'), findsOneWidget);
      expect(find.byType(SnackBarAction), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('sin dueño conocido el snackbar no ofrece "Cobrar"', (
      tester,
    ) async {
      final repo = FakeConsultaRepository();
      await tester.pumpWidget(
        _appUnderTest(repo: repo, mascotaRepo: FakeMascotaRepository()),
      );
      await tester.pumpAndSettle();
      await guardar(tester);

      expect(find.text('Consulta guardada'), findsOneWidget);
      expect(find.byType(SnackBarAction), findsNothing);
      await tester.pumpAndSettle();
    });
  });
}
